// Tests the subnet-scan fallback of the dSS discovery on this machine.
//   dart run tool/scan.dart
// ignore_for_file: avoid_print
import 'package:myhome/dss/discovery.dart';

Future<void> main() async {
  final sw = Stopwatch()..start();
  final s = await scanForDss();
  print(s == null ? 'not found (${sw.elapsedMilliseconds} ms)' : 'found ${s.host} dSS ${s.version} in ${sw.elapsedMilliseconds} ms');
}
