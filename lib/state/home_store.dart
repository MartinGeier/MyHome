import 'dart:async';

import 'package:flutter/widgets.dart';

import '../dss/dss_client.dart';
import '../dss/dss_notifications.dart';
import '../dss/models.dart';
import 'settings.dart';

/// App state. The UI reads from here and calls the command methods.
///
/// Speed rules:
///  * start paints the cached apartment immediately, then refreshes;
///  * commands update local state first (optimistic) and are sent in the background;
///  * slider drags send only the latest value per device ("latest wins");
///  * live updates come from the notification WebSocket, with polling as fallback.
class HomeStore extends ChangeNotifier {
  HomeStore(this.settings);

  final Settings settings;
  DssClient? _client;
  DssNotifications? _notifications;

  Apartment? apartment;
  List<String> favorites = [];
  double? totalWatts;
  List<Meter> circuits = [];
  double? outdoorTemp;
  bool online = false;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  Map<String, String> _controllerNames = {};
  final Map<String, Map<String, double>> _pending = {};
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _settleUntil = {};
  Timer? _refreshDebounce;
  Timer? _poll;
  Timer? _energyTimer;
  bool _wsUp = false;
  StreamSubscription<String>? _evSub;
  StreamSubscription<bool>? _connSub;

  // ---------------- lifecycle ----------------

  Future<void> start() async {
    favorites = List.of(settings.favorites);
    apartment = settings.cachedApartment;
    notifyListeners();

    _client = DssClient(host: settings.host!, appToken: settings.appToken, pinnedFingerprint: settings.fingerprint);
    _notifications = DssNotifications(host: settings.host!, appToken: settings.appToken!);
    _evSub = _notifications!.events.listen((_) => _scheduleRefresh());
    _connSub = _notifications!.connected.listen((up) {
      _wsUp = up;
      _updatePolling();
      if (up) _scheduleRefresh(); // catch up on anything missed while disconnected
    });
    _notifications!.start();
    _updatePolling();
    await refreshAll();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _retryAll?.cancel();
    _poll?.cancel();
    _energyTimer?.cancel();
    _evSub?.cancel();
    _connSub?.cancel();
    _notifications?.stop();
    _client?.close();
    _errors.close();
    super.dispose();
  }

  /// Called when the app returns to the foreground.
  void onResumed() => refreshStatus();

  void _updatePolling() {
    _poll?.cancel();
    if (!_wsUp) _poll = Timer.periodic(const Duration(seconds: 10), (_) => refreshStatus());
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), refreshStatus);
  }

  // ---------------- reading ----------------

  Future<void> refreshAll() async {
    final c = _client;
    if (c == null) return;
    try {
      final body = await c.apartment();
      final fresh = parseApartment(body);
      _controllerNames = _parseControllerNames(body);
      // keep local values for devices with commands in flight
      final old = apartment;
      if (old != null) {
        for (final id in _busyIds()) {
          final d = old.devices[id];
          if (d != null && fresh.devices.containsKey(id)) fresh.devices[id] = d.copy();
        }
      }
      applyStatus(fresh, await c.deviceStatus(), skip: _busyIds());
      apartment = fresh;
      _setOnline(true);
      notifyListeners();
      _structureLoaded = true;
      unawaited(settings.cacheApartment(fresh));
      unawaited(_refreshWeather());
      unawaited(refreshEnergy());
    } on DssException catch (e) {
      _fail(e);
      // The cached apartment keeps the UI usable; try the full load again shortly.
      _retryAll?.cancel();
      _retryAll = Timer(const Duration(seconds: 5), refreshAll);
    }
  }

  bool _structureLoaded = false;
  Timer? _retryAll;

  Future<void> refreshStatus() async {
    final c = _client;
    final apt = apartment;
    if (c == null) return;
    if (apt == null || apt.devices.isEmpty) return refreshAll();
    try {
      final changed = applyStatus(apt, await c.deviceStatus(), skip: _busyIds());
      _setOnline(true);
      if (!_structureLoaded) unawaited(refreshAll());
      if (changed) {
        notifyListeners();
        unawaited(settings.cacheApartment(apt));
      }
    } on DssException catch (e) {
      _fail(e);
    }
  }

  Future<void> refreshEnergy() async {
    final c = _client;
    if (c == null) return;
    try {
      final m = parseMeterings(await c.meteringValues(), _controllerNames);
      totalWatts = m.total;
      circuits = m.circuits;
      notifyListeners();
    } on DssException catch (e) {
      _fail(e);
    }
  }

  /// Energy is polled every 5 s only while its screen is visible.
  void watchEnergy(bool visible) {
    _energyTimer?.cancel();
    if (visible) {
      refreshEnergy();
      _energyTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshEnergy());
    }
  }

  Future<void> _refreshWeather() async {
    try {
      final s = await _client!.apartmentStatus();
      final t = s['data']?['attributes']?['measurements']?['temperature'];
      if (t is num) {
        outdoorTemp = t.toDouble();
        notifyListeners();
      }
    } catch (_) {}
  }

  Map<String, String> _parseControllerNames(Map<String, dynamic> body) {
    final list = (body['data']?['included']?['controllers'] as List?) ?? const [];
    return {for (final c in list) c['id'] as String: (c['attributes']?['name'] as String?) ?? c['id'] as String};
  }

  Set<String> _busyIds() {
    final now = DateTime.now();
    _settleUntil.removeWhere((_, t) => t.isBefore(now));
    return {..._inFlight, ..._pending.keys, ..._settleUntil.keys};
  }

  void _setOnline(bool v) {
    if (online != v) {
      online = v;
      notifyListeners();
    }
  }

  void _fail(DssException e) {
    _setOnline(false);
    _errors.add(e.unauthorized ? 'Zugriff verweigert – Token im Konfigurator prüfen' : e.message);
  }

  // ---------------- lookups for the UI ----------------

  T? device<T extends Device>(String id) {
    final d = apartment?.devices[id];
    return d is T ? d : null;
  }

  List<Device> get favoriteDevices =>
      [for (final id in favorites) if (apartment?.devices[id] != null) apartment!.devices[id]!];

  List<Device> devicesIn(String zoneId) => apartment?.devicesIn(zoneId) ?? const [];

  Room? room(String zoneId) => apartment?.rooms.where((r) => r.id == zoneId).firstOrNull;

  int get lightsOn => apartment?.devices.values.whereType<Light>().where((l) => l.isOn).length ?? 0;

  // ---------------- favourites ----------------

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    favorites = isFavorite(id) ? (List.of(favorites)..remove(id)) : [...favorites, id];
    settings.setFavorites(favorites);
    notifyListeners();
  }

  /// Moves favourite [id] to position [toIndex] (used while dragging on the home screen).
  void moveFavorite(String id, int toIndex) {
    final from = favorites.indexOf(id);
    if (from < 0 || from == toIndex) return;
    reorderFavorites(from, toIndex);
  }

  /// [newIndex] is the final position after removing the item (onReorderItem semantics).
  void reorderFavorites(int oldIndex, int newIndex) {
    final list = List.of(favorites);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    favorites = list;
    settings.setFavorites(favorites);
    notifyListeners();
  }

  // ---------------- commands ----------------

  void toggleLight(String id) {
    final l = device<Light>(id);
    if (l == null) return;
    setBrightness(id, l.isOn ? 0 : l.lastOn);
  }

  void setBrightness(String id, double value) {
    final l = device<Light>(id);
    if (l == null) return;
    l.brightness = value.clamp(0, 100).roundToDouble();
    if (l.brightness > 0) l.lastOn = l.brightness;
    notifyListeners();
    _queue(l, {'brightness': l.brightness});
  }

  void setBlind(String id, {double? position, double? angle}) {
    final b = device<Blind>(id);
    if (b == null) return;
    final out = <String, double>{};
    if (position != null) out['shadePositionOutside'] = b.position = position.clamp(0, 100).roundToDouble();
    if (angle != null) out['shadeOpeningAngleOutside'] = b.angle = angle.clamp(0, 100).roundToDouble();
    notifyListeners();
    _queue(b, out);
  }

  void blindUp(String id) => setBlind(id, position: 100, angle: 100);
  void blindDown(String id) => setBlind(id, position: 0, angle: 0);

  Future<void> blindStop(String id) async {
    _pending.remove(id);
    try {
      await _client?.invokeScenario('device-$id-std.stop');
      _settleUntil.remove(id);
      _scheduleRefresh();
    } on DssException catch (e) {
      _fail(e);
    }
  }

  void roomLightsOff(String zoneId) {
    for (final l in devicesIn(zoneId).whereType<Light>()) {
      if (l.isOn) setBrightness(l.id, 0);
    }
  }

  void allLightsOff() {
    for (final l in apartment?.devices.values.whereType<Light>().toList() ?? const <Light>[]) {
      if (l.isOn) setBrightness(l.id, 0);
    }
  }

  void roomBlinds(String zoneId, {required bool up}) {
    for (final b in devicesIn(zoneId).whereType<Blind>()) {
      up ? blindUp(b.id) : blindDown(b.id);
    }
  }

  /// Latest-wins sender: at most one request per device in flight; values that
  /// arrive meanwhile are merged and sent when it returns.
  void _queue(Device d, Map<String, double> values) {
    _pending[d.id] = {...?_pending[d.id], ...values};
    _settleUntil[d.id] = DateTime.now().add(const Duration(seconds: 2));
    if (!_inFlight.contains(d.id)) _drain(d);
  }

  Future<void> _drain(Device d) async {
    if (_client == null) {
      _pending.remove(d.id); // not connected (tests): keep the local state only
      return;
    }
    _inFlight.add(d.id);
    try {
      while (_pending.containsKey(d.id)) {
        final values = _pending.remove(d.id)!;
        try {
          await _client!.setOutputs(d.id, d.fbId, values);
          _setOnline(true);
        } on DssException catch (e) {
          _fail(e);
          _settleUntil.remove(d.id);
          _scheduleRefresh(); // roll back to the real state
        }
      }
    } finally {
      _inFlight.remove(d.id);
      _settleUntil[d.id] = DateTime.now().add(const Duration(milliseconds: 1500));
    }
  }
}

/// Makes the store available to the widget tree.
class StoreScope extends InheritedNotifier<HomeStore> {
  const StoreScope({super.key, required HomeStore store, required super.child}) : super(notifier: store);

  static HomeStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static HomeStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
