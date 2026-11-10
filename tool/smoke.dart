// Read-only smoke test of the dSS client against a real server.
//
//   DSS_HOST=192.168.10.11 DSS_TOKEN=<app token> dart run tool/smoke.dart
//
// Sends no commands; only reads structure, status, meterings and listens to
// the notification WebSocket for 10 seconds.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:myhome/dss/discovery.dart';
import 'package:myhome/dss/dss_client.dart';
import 'package:myhome/dss/dss_notifications.dart';
import 'package:myhome/dss/models.dart';

Future<void> main() async {
  final host = Platform.environment['DSS_HOST'] ?? 'dss.local';
  final token = Platform.environment['DSS_TOKEN'];
  if (token == null) {
    stderr.writeln('Set DSS_TOKEN');
    exit(2);
  }

  final sw = Stopwatch()..start();
  final found = await probeDss(host);
  print('probe: ${found?.host} version=${found?.version} fp=${found?.fingerprint.substring(0, 16)}… '
      '(${sw.elapsedMilliseconds} ms)');
  if (found == null) exit(1);

  final c = DssClient(host: host, appToken: token, pinnedFingerprint: found.fingerprint);
  sw.reset();
  final aptBody = await c.apartment();
  final apt = parseApartment(aptBody);
  print('apartment: ${apt.rooms.length} rooms, ${apt.devices.length} devices (${sw.elapsedMilliseconds} ms)');
  sw.reset();
  applyStatus(apt, await c.deviceStatus());
  print('status: (${sw.elapsedMilliseconds} ms)');
  for (final r in apt.rooms) {
    final ds = apt.devicesIn(r.id).map((d) => switch (d) {
          Light l => '${l.name}=${l.brightness.round()}%',
          Blind b => '${b.name}=${b.position.round()}%/${b.degrees}°',
        });
    print('  ${r.name}: ${ds.join(', ')}');
  }
  final names = {
    for (final x in (aptBody['data']['included']['controllers'] as List)) x['id'] as String: x['attributes']['name'] as String,
  };
  final m = parseMeterings(await c.meteringValues(), names);
  print('power: ${m.total} W  ${m.circuits.map((x) => '${x.name}=${x.watts}').join(', ')}');

  final wrong = DssClient(host: host, appToken: token, pinnedFingerprint: 'deadbeef');
  try {
    await wrong.deviceStatus();
    print('PIN CHECK FAILED: wrong fingerprint accepted');
  } on DssException catch (e) {
    print('pin check ok: ${e.message}');
  }
  wrong.close();

  final n = DssNotifications(host: host, appToken: token);
  final sub1 = n.connected.listen((up) => print('ws connected=$up'));
  final sub2 = n.events.listen((e) => print('ws event: $e'));
  n.start();
  await Future<void>.delayed(const Duration(seconds: 10));
  await sub1.cancel();
  await sub2.cancel();
  await n.stop();
  c.close();
  exit(0);
}
