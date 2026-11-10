import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myhome/dss/models.dart';

/// Parsing tests against real responses captured from the dSS (see samples/).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('samples/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Apartment apt;

  setUp(() {
    apt = parseApartment(_load('rest_apartment_include.json'));
    applyStatus(apt, _load('rest_dev_status_all.json'));
  });

  test('finds lights and blinds, skips buttons and sensors', () {
    final lights = apt.devices.values.whereType<Light>().toList();
    final blinds = apt.devices.values.whereType<Blind>().toList();
    expect(lights, hasLength(7));
    expect(blinds, hasLength(22));
    expect(lights.map((l) => l.name), contains('Strahler Wohnzimmer'));
  });

  test('rooms are named, non-empty zones only', () {
    final names = apt.rooms.map((r) => r.name).toList();
    expect(names, containsAll(['Wohnzimmer', 'Büro', 'Küche', 'Terrasse West']));
    expect(names.every((n) => n.isNotEmpty), isTrue);
    for (final r in apt.rooms) {
      expect(apt.devicesIn(r.id), isNotEmpty);
    }
  });

  test('rooms are sorted alphabetically, umlauts folded', () {
    final names = apt.rooms.map((r) => r.name).toList();
    expect(names.first, 'Büro');
    expect(names, orderedEquals([...names]..sort((a, b) => sortKey(a).compareTo(sortKey(b)))));
    expect(names.indexOf('Küche'), lessThan(names.indexOf('Schrankraum')));
  });

  test('status values are applied', () {
    final buero = apt.devices.values.whereType<Blind>().firstWhere((b) => b.name == 'Büro Fenster');
    expect(buero.position, 40);
    expect(buero.angle, closeTo(50, 1));
    expect(buero.degrees, 45);
  });

  test('a blind without value is reported as moving', () {
    final b = apt.devices.values.whereType<Blind>().first;
    final changed = applyStatus(apt, {
      'data': [
        {
          'id': b.id,
          'attributes': {
            'functionBlocks': [
              {
                'id': b.fbId,
                'outputs': [
                  {'id': 'shadePositionOutside', 'status': 'moving'},
                  {'id': 'shadeOpeningAngleOutside', 'status': 'moving'},
                ],
              },
            ],
          },
        },
      ],
    });
    expect(changed, isTrue);
    expect(b.moving, isTrue);
  });

  test('skip set protects devices with commands in flight', () {
    final l = apt.devices.values.whereType<Light>().firstWhere((l) => l.name == 'Strahler Esszimmer');
    l.brightness = 33;
    applyStatus(apt, _load('rest_dev_status_all.json'), skip: {l.id});
    expect(l.brightness, 33);
  });

  test('apartment round-trips through the cache format', () {
    final copy = Apartment.fromJson(jsonDecode(jsonEncode(apt.toJson())) as Map<String, dynamic>);
    expect(copy.rooms.map((r) => r.id), apt.rooms.map((r) => r.id));
    expect(copy.devices.length, apt.devices.length);
  });

  test('meterings: total and per circuit', () {
    final m = parseMeterings(_load('rest_metering_values.json'), {'302ed89f43f0000000000e400001010600': 'Garten'});
    expect(m.total, greaterThan(0));
    expect(m.circuits, hasLength(4));
    expect(m.circuits.map((c) => c.name), contains('Garten'));
    expect(m.circuits.first.watts, greaterThanOrEqualTo(m.circuits.last.watts));
  });
}
