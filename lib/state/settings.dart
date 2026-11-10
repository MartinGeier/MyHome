import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dss/models.dart';

/// Connection data (secure storage) and app preferences (favourites, cached state).
class Settings {
  Settings._(this._prefs);

  static const _secure = FlutterSecureStorage();
  final SharedPreferences _prefs;

  String? host;
  String? appToken;
  String? fingerprint;

  /// For tests: preferences only, no secure storage.
  static Future<Settings> inMemory() async => Settings._(await SharedPreferences.getInstance());

  static Future<Settings> load() async {
    final s = Settings._(await SharedPreferences.getInstance());
    s.host = await _secure.read(key: 'host');
    s.appToken = await _secure.read(key: 'appToken');
    s.fingerprint = await _secure.read(key: 'fingerprint');
    return s;
  }

  bool get isConnected => host != null && appToken != null && fingerprint != null;

  Future<void> saveConnection({required String host, required String token, required String fingerprint}) async {
    this.host = host;
    appToken = token;
    this.fingerprint = fingerprint;
    await _secure.write(key: 'host', value: host);
    await _secure.write(key: 'appToken', value: token);
    await _secure.write(key: 'fingerprint', value: fingerprint);
  }

  Future<void> clearConnection() async {
    host = appToken = fingerprint = null;
    await _secure.deleteAll();
    await _prefs.remove('cache');
  }

  /// A token requested but not yet approved survives an app restart.
  String? get pendingToken => _prefs.getString('pendingToken');
  Future<void> setPendingToken(String? t) =>
      t == null ? _prefs.remove('pendingToken') : _prefs.setString('pendingToken', t);

  List<String> get favorites => _prefs.getStringList('favorites') ?? const [];
  Future<void> setFavorites(List<String> ids) => _prefs.setStringList('favorites', ids);

  /// Last known apartment, so the app paints instantly on start.
  Apartment? get cachedApartment {
    final raw = _prefs.getString('cache');
    if (raw == null) return null;
    try {
      return Apartment.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheApartment(Apartment a) => _prefs.setString('cache', jsonEncode(a.toJson()));
}
