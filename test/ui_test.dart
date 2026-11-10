import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhome/dss/models.dart';
import 'package:myhome/state/home_store.dart';
import 'package:myhome/state/settings.dart';
import 'package:myhome/ui/shell.dart';
import 'package:myhome/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real screens with the captured apartment (no network).
Future<HomeStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = HomeStore(await Settings.inMemory());
  final apt = parseApartment(jsonDecode(File('samples/rest_apartment_include.json').readAsStringSync()));
  applyStatus(apt, jsonDecode(File('samples/rest_dev_status_all.json').readAsStringSync()));
  store.apartment = apt;
  String id(String name) => apt.devices.values.firstWhere((d) => d.name == name).id;
  store.favorites = [id('Strahler Wohnzimmer'), id('Strahler Esszimmer'), id('Büro Fenster'), id('Wohnzimmer Glaseck Süd')];
  store.totalWatts = 317;
  store.outdoorTemp = 10.1;
  return store;
}

Widget _app(HomeStore s) => StoreScope(store: s, child: MaterialApp(theme: buildTheme(), home: const Shell()));

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
  });

  testWidgets('home shows favourites and tap toggles a light', (t) async {
    final s = await _store();
    await t.pumpWidget(_app(s));
    expect(find.text('Zuhause'), findsOneWidget);
    expect(find.text('Strahler Wohnzimmer'), findsOneWidget);
    expect(find.text('Büro Fenster'), findsOneWidget);
    expect(find.text('317 W'), findsOneWidget);

    final light = s.apartment!.devices.values.whereType<Light>().firstWhere((l) => l.name == 'Strahler Wohnzimmer');
    expect(light.isOn, isFalse);
    await t.tap(find.text('Strahler Wohnzimmer'));
    await t.pump(const Duration(milliseconds: 300));
    expect(light.isOn, isTrue);
  });

  testWidgets('long-press and drag reorders favourites', (t) async {
    final s = await _store();
    await t.pumpWidget(_app(s));
    final first = s.favorites.first;
    final from = t.getCenter(find.text('Strahler Wohnzimmer'));
    final to = t.getCenter(find.text('Büro Fenster'));
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 600)); // long press
    await g.moveTo(Offset.lerp(from, to, 0.5)!);
    await t.pump();
    await g.moveTo(to);
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(s.favorites.first, isNot(first));
    expect(s.favorites.indexOf(first), 2);
  });

  testWidgets('rooms → room detail → blind sheet', (t) async {
    final s = await _store();
    await t.pumpWidget(_app(s));
    await t.tap(find.widgetWithText(NavigationDestination, 'Räume'));
    await t.pumpAndSettle();
    expect(find.text('Wohnzimmer'), findsWidgets);
    await t.tap(find.text('Büro').first);
    await t.pumpAndSettle();
    expect(find.text('Büro Fenster'), findsOneWidget);
    expect(find.text('40 % offen · 45°'), findsOneWidget);

    await t.tap(find.text('Büro Fenster'));
    await t.pumpAndSettle();
    expect(find.text('Lamellenwinkel'), findsOneWidget);
    await t.tap(find.text('90°'));
    await t.pump();
    final b = s.apartment!.devices.values.whereType<Blind>().firstWhere((b) => b.name == 'Büro Fenster');
    expect(b.angle, 100);
  });

  testWidgets('light sheet presets set brightness', (t) async {
    final s = await _store();
    await t.pumpWidget(_app(s));
    await t.tap(find.byTooltip('Helligkeit einstellen').first);
    await t.pumpAndSettle();
    await t.tap(find.text('50 %'));
    await t.pump();
    final l = s.apartment!.devices.values.whereType<Light>().firstWhere((l) => l.name == 'Strahler Wohnzimmer');
    expect(l.brightness, 50);
  });

  testWidgets('energy and empty favourites render', (t) async {
    final s = await _store();
    s.favorites = [];
    await t.pumpWidget(_app(s));
    expect(find.text('Noch keine Favoriten'), findsOneWidget);
    await t.tap(find.widgetWithText(NavigationDestination, 'Energie'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('317'), findsOneWidget);
  });
}
