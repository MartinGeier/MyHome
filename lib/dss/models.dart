/// Domain model for the parts of a digitalSTROM installation the app shows:
/// rooms, dimmable lights, venetian blinds and power meters.
library;

enum DeviceKind { light, blind }

/// A controllable device. `id` is the dsDevice dSUID, `fbId` the function block
/// whose outputs we read and write (for all devices seen so far fbId == id).
sealed class Device {
  Device({required this.id, required this.fbId, required this.name, required this.zoneId});

  final String id;
  final String fbId;
  final String name;
  final String zoneId;

  DeviceKind get kind;
  Device copy();
  Map<String, dynamic> toJson();

  static Device fromJson(Map<String, dynamic> j) => switch (j['kind']) {
        'light' => Light(id: j['id'], fbId: j['fbId'], name: j['name'], zoneId: j['zoneId'])
          ..brightness = (j['brightness'] as num).toDouble(),
        _ => Blind(id: j['id'], fbId: j['fbId'], name: j['name'], zoneId: j['zoneId'])
          ..position = (j['position'] as num).toDouble()
          ..angle = (j['angle'] as num).toDouble(),
      };
}

class Light extends Device {
  Light({required super.id, required super.fbId, required super.name, required super.zoneId});

  /// 0..100 %. 0 = off.
  double brightness = 0;

  /// Last brightness above 0, used when switching on again.
  double lastOn = 100;

  bool get isOn => brightness > 0;

  @override
  DeviceKind get kind => DeviceKind.light;

  @override
  Light copy() => Light(id: id, fbId: fbId, name: name, zoneId: zoneId)
    ..brightness = brightness
    ..lastOn = lastOn;

  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'light', 'id': id, 'fbId': fbId, 'name': name, 'zoneId': zoneId, 'brightness': brightness};
}

class Blind extends Device {
  Blind({required super.id, required super.fbId, required super.name, required super.zoneId});

  /// 0 = closed (down), 100 = fully open (up).
  double position = 100;

  /// Slat opening angle, 0 = closed, 100 = open. Shown as 0–90°.
  double angle = 100;

  /// True while the dSS reports no value (blind is travelling).
  bool moving = false;

  int get degrees => (angle * 0.9).round();

  @override
  DeviceKind get kind => DeviceKind.blind;

  @override
  Blind copy() => Blind(id: id, fbId: fbId, name: name, zoneId: zoneId)
    ..position = position
    ..angle = angle
    ..moving = moving;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'blind', 'id': id, 'fbId': fbId, 'name': name, 'zoneId': zoneId,
        'position': position, 'angle': angle,
      };
}

class Room {
  Room({required this.id, required this.name, required this.order});

  final String id;
  final String name;
  final double order;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'order': order};
  static Room fromJson(Map<String, dynamic> j) =>
      Room(id: j['id'], name: j['name'], order: (j['order'] as num).toDouble());
}

class Meter {
  Meter({required this.id, required this.name, required this.watts});

  final String id;
  final String name;
  final double watts;
}

/// Everything the UI renders. Devices are kept in a map by id; rooms in display order.
class Apartment {
  Apartment({required this.rooms, required this.devices});

  final List<Room> rooms;
  final Map<String, Device> devices;

  List<Device> devicesIn(String zoneId) => devices.values.where((d) => d.zoneId == zoneId).toList()
    ..sort((a, b) => sortKey(a.name).compareTo(sortKey(b.name)));

  Map<String, dynamic> toJson() => {
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'devices': devices.values.map((d) => d.toJson()).toList(),
      };

  static Apartment fromJson(Map<String, dynamic> j) => Apartment(
        rooms: [for (final r in j['rooms'] as List) Room.fromJson(r)],
        devices: {
          for (final d in j['devices'] as List)
            (d as Map<String, dynamic>)['id'] as String: Device.fromJson(d),
        },
      );
}

/// Parses `GET /api/v1/apartment` (which includes zones, dsDevices and functionBlocks).
Apartment parseApartment(Map<String, dynamic> body) {
  final inc = (body['data'] as Map<String, dynamic>)['included'] as Map<String, dynamic>;
  final fbs = {
    for (final f in inc['functionBlocks'] as List) f['id'] as String: f['attributes'] as Map<String, dynamic>,
  };
  final submodules = {
    for (final s in inc['submodules'] as List) s['id'] as String: s['attributes'] as Map<String, dynamic>,
  };

  final devices = <String, Device>{};
  for (final d in inc['dsDevices'] as List) {
    final id = d['id'] as String;
    final a = d['attributes'] as Map<String, dynamic>;
    if (a['present'] == false) continue;
    final zone = '${a['zone']}';
    for (final sm in (a['submodules'] as List? ?? const [])) {
      for (final fbId in (submodules[sm]?['functionBlocks'] as List? ?? const [])) {
        final outputs = {for (final o in (fbs[fbId]?['outputs'] as List? ?? const [])) o['id'] as String};
        final name = (a['name'] as String?)?.trim().isNotEmpty == true ? a['name'] as String : id;
        if (outputs.contains('brightness')) {
          devices[id] = Light(id: id, fbId: fbId as String, name: name, zoneId: zone);
        } else if (outputs.contains('shadePositionOutside')) {
          devices[id] = Blind(id: id, fbId: fbId as String, name: name, zoneId: zone);
        }
      }
    }
  }

  final usedZones = devices.values.map((d) => d.zoneId).toSet();
  final rooms = <Room>[];
  for (final z in inc['zones'] as List) {
    final id = '${z['id']}';
    final a = z['attributes'] as Map<String, dynamic>;
    final name = (a['name'] as String?) ?? '';
    if (name.isEmpty || !usedZones.contains(id)) continue;
    rooms.add(Room(id: id, name: name, order: (a['orderId'] as num?)?.toDouble() ?? 0));
  }
  rooms.sort((a, b) => sortKey(a.name).compareTo(sortKey(b.name)));
  return Apartment(rooms: rooms, devices: devices);
}

/// Case- and umlaut-insensitive key for German alphabetical order ("Büro" sorts as "buro").
String sortKey(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss');

/// Applies `GET /api/v1/apartment/dsDevices/status` to the devices. Returns true if anything changed.
/// Devices in [skip] are left alone (a local command for them is still in flight).
bool applyStatus(Apartment apt, Map<String, dynamic> body, {Set<String> skip = const {}}) {
  var changed = false;
  for (final s in body['data'] as List) {
    final dev = apt.devices[s['id']];
    if (dev == null || skip.contains(dev.id)) continue;
    final fbs = (s['attributes']['functionBlocks'] as List?) ?? const [];
    for (final fb in fbs) {
      if (fb['id'] != dev.fbId) continue;
      final outs = {for (final o in (fb['outputs'] as List? ?? const [])) o['id'] as String: o as Map<String, dynamic>};
      double? val(String k) => (outs[k]?['value'] as num?)?.toDouble();
      switch (dev) {
        case Light l:
          final b = val('brightness');
          if (b != null && b != l.brightness) {
            l.brightness = b;
            if (b > 0) l.lastOn = b;
            changed = true;
          }
        case Blind bl:
          final p = val('shadePositionOutside');
          final a = val('shadeOpeningAngleOutside');
          final moving = p == null && outs.containsKey('shadePositionOutside');
          if (moving != bl.moving) {
            bl.moving = moving;
            changed = true;
          }
          if (p != null && p != bl.position) {
            bl.position = p;
            changed = true;
          }
          if (a != null && a != bl.angle) {
            bl.angle = a;
            changed = true;
          }
      }
    }
  }
  return changed;
}

/// Parses meterings: names come from the controllers (dSMs), values from `meterings/values`.
({double total, List<Meter> circuits}) parseMeterings(
    Map<String, dynamic> values, Map<String, String> controllerNames) {
  double total = 0;
  final circuits = <Meter>[];
  for (final v in values['data']['values'] as List) {
    final id = v['id'] as String;
    final w = ((v['attributes'] as Map)['value'] as num).toDouble();
    if (id == 'apartment-power') total = w;
    final m = RegExp(r'^dsm-(.+)-power$').firstMatch(id);
    if (m != null) circuits.add(Meter(id: m.group(1)!, name: controllerNames[m.group(1)] ?? m.group(1)!, watts: w));
  }
  circuits.sort((a, b) => b.watts.compareTo(a.watts));
  return (total: total, circuits: circuits);
}
