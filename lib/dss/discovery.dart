import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import 'dss_client.dart';

class FoundServer {
  FoundServer({required this.host, required this.version, required this.fingerprint});

  final String host;
  final String version;
  final String fingerprint;
}

/// Finds the dSS on the local network, fastest method first:
///  1. hostnames `dss.local` / `dss` (works where the OS resolves them, e.g. Windows, iOS),
///  2. mDNS lookup of `dss.local` (often filtered on Android without a multicast lock),
///  3. a scan of the phone's own /24 subnet for port 8080 (always works on a flat home LAN).
/// Every candidate is confirmed with a dSS version call.
Future<FoundServer?> discoverDss() async {
  for (final host in await _nameCandidates()) {
    final s = await probeDss(host);
    if (s != null) return s;
  }
  return scanForDss();
}

Future<Set<String>> _nameCandidates() async {
  final candidates = <String>{};
  for (final name in ['dss.local', 'dss']) {
    try {
      final r = await InternetAddress.lookup(name, type: InternetAddressType.IPv4)
          .timeout(const Duration(seconds: 2));
      candidates.addAll(r.map((a) => a.address));
    } catch (_) {}
  }
  if (candidates.isNotEmpty) return candidates;

  // Android does not support SO_REUSEPORT, so bind without it.
  final mdns = MDnsClient(
    rawDatagramSocketFactory: (host, int port, {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) =>
        RawDatagramSocket.bind(host, port, reuseAddress: true, reusePort: false, ttl: ttl),
  );
  try {
    await mdns.start();
    await for (final a in mdns
        .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4('dss.local'))
        .timeout(const Duration(seconds: 2), onTimeout: (s) => s.close())) {
      candidates.add(a.address.address);
    }
  } catch (_) {
  } finally {
    mdns.stop();
  }
  return candidates;
}

/// Tries every address of each local private /24 network on port 8080.
Future<FoundServer?> scanForDss() async {
  final prefixes = <String>{};
  try {
    for (final nif in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in nif.addresses) {
        final p = a.address.split('.');
        final private = p[0] == '10' ||
            (p[0] == '192' && p[1] == '168') ||
            (p[0] == '172' && int.parse(p[1]) >= 16 && int.parse(p[1]) <= 31);
        if (private) prefixes.add('${p[0]}.${p[1]}.${p[2]}');
      }
    }
  } catch (_) {}

  for (final prefix in prefixes) {
    final open = <String>[];
    // 254 hosts in batches, short connect timeout: ~2 s per subnet.
    for (var start = 1; start < 255; start += 64) {
      final batch = [for (var i = start; i < start + 64 && i < 255; i++) '$prefix.$i'];
      final results = await Future.wait(batch.map(_portOpen));
      for (var i = 0; i < batch.length; i++) {
        if (results[i]) open.add(batch[i]);
      }
    }
    for (final host in open) {
      final s = await probeDss(host);
      if (s != null) return s;
    }
  }
  return null;
}

Future<bool> _portOpen(String host) async {
  try {
    final s = await Socket.connect(host, 8080, timeout: const Duration(milliseconds: 450));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// Checks that [host] answers like a dSS and returns its certificate fingerprint.
Future<FoundServer?> probeDss(String host) async {
  final c = DssClient(host: host);
  try {
    final v = await c.serverVersion();
    final fp = c.seenFingerprint;
    if (fp == null) return null;
    return FoundServer(host: host, version: v, fingerprint: fp);
  } catch (_) {
    return null;
  } finally {
    c.close();
  }
}
