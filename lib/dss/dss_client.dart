import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Thrown for non-2xx answers or transport problems.
class DssException implements Exception {
  DssException(this.message, {this.status});

  final String message;
  final int? status;

  bool get unauthorized => status == 401 || status == 403;

  @override
  String toString() => 'DssException($status): $message';
}

class _StaleConnection implements Exception {}

/// SHA-256 fingerprint of a certificate, hex encoded.
String certFingerprint(X509Certificate c) => sha256.convert(c.der).toString();

/// Talks to the dSS: the REST API (`/api/v1`, Bearer app token) and the few
/// legacy JSON calls needed for the token handshake.
///
/// The dSS uses a self-signed certificate. We pin it: the fingerprint seen
/// during setup is stored, and any other certificate is rejected later.
class DssClient {
  DssClient({required this.host, this.appToken, this.pinnedFingerprint, this.port = 8080}) {
    _http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      // The dSS closes idle keep-alive connections quickly; don't reuse stale ones.
      ..idleTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = _acceptCert;
  }

  final String host;
  final int port;
  String? appToken;

  /// Pinned certificate fingerprint. When null (first contact) any certificate
  /// is accepted and recorded in [seenFingerprint].
  final String? pinnedFingerprint;
  String? seenFingerprint;

  late final HttpClient _http;

  bool _acceptCert(X509Certificate cert, String h, int p) {
    final fp = certFingerprint(cert);
    seenFingerprint = fp;
    return pinnedFingerprint == null || pinnedFingerprint == fp;
  }

  void close() => _http.close(force: true);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri(scheme: 'https', host: host, port: port, path: path, queryParameters: query);

  Future<(int, String)> _send(String method, Uri uri, {Object? body, bool auth = true}) async {
    try {
      return await _sendOnce(method, uri, body: body, auth: auth);
    } on _StaleConnection {
      // A reused keep-alive connection was closed by the dSS. Reads are safe to
      // repeat on a fresh connection; commands are not repeated blindly.
      if (method != 'GET') throw DssException('Verbindung unterbrochen – bitte nochmal');
      try {
        return await _sendOnce(method, uri, body: body, auth: auth);
      } on _StaleConnection {
        throw DssException('Verbindung zu $host unterbrochen');
      }
    }
  }

  Future<(int, String)> _sendOnce(String method, Uri uri, {Object? body, bool auth = true}) async {
    try {
      final req = await _http.openUrl(method, uri).timeout(const Duration(seconds: 5));
      if (auth && appToken != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $appToken');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.headers.contentType = ContentType.json;
        req.contentLength = bytes.length; // the dSS waits for a body length on POST
        req.add(bytes);
      }
      final res = await req.close().timeout(const Duration(seconds: 8));
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text);
    } on TimeoutException {
      throw DssException('Zeitüberschreitung bei $host');
    } on SocketException catch (e) {
      throw DssException('Keine Verbindung zu $host (${e.osError?.message ?? e.message})');
    } on HandshakeException {
      throw DssException('Zertifikat des Servers hat sich geändert');
    } on HttpException {
      throw _StaleConnection();
    } on IOException catch (e) {
      throw DssException('Netzwerkfehler: $e');
    }
  }

  Future<Map<String, dynamic>> _getJson(String path, {Map<String, String>? query, bool auth = true}) async {
    final (status, text) = await _send('GET', _uri(path, query), auth: auth);
    if (status >= 300) throw DssException('GET $path', status: status);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ---------- Setup / token handshake (legacy JSON API, no auth) ----------

  /// Quick reachability check that also captures the certificate fingerprint.
  Future<String> serverVersion() async {
    final j = await _getJson('/json/system/version', auth: false);
    return (j['result']?['distroVersion'] ?? j['result']?['version'] ?? '?').toString();
  }

  /// Asks the dSS for a new application token. The user must then enable it in
  /// the dS Konfigurator under System → Zugriffsberechtigung.
  Future<String> requestApplicationToken(String applicationName) async {
    final j = await _getJson('/json/system/requestApplicationToken',
        query: {'applicationName': applicationName}, auth: false);
    final t = j['result']?['applicationToken'] as String?;
    if (j['ok'] != true || t == null) throw DssException('Token-Anfrage abgelehnt');
    return t;
  }

  /// True once the user has enabled [token] in the Konfigurator.
  Future<bool> isTokenApproved(String token) async {
    final j = await _getJson('/json/system/loginApplication', query: {'loginToken': token}, auth: false);
    return j['ok'] == true;
  }

  // ---------- REST API ----------

  /// Whole structure: zones, devices, function blocks, controllers, meterings.
  Future<Map<String, dynamic>> apartment() => _getJson('/api/v1/apartment');

  /// Live output values of every device in one call.
  Future<Map<String, dynamic>> deviceStatus() => _getJson('/api/v1/apartment/dsDevices/status');

  Future<Map<String, dynamic>> apartmentStatus() => _getJson('/api/v1/apartment/status');

  Future<Map<String, dynamic>> meteringValues() => _getJson('/api/v1/apartment/meterings/values');

  /// Sets output values, e.g. `{'brightness': 50}` or
  /// `{'shadePositionOutside': 40, 'shadeOpeningAngleOutside': 50}`.
  Future<void> setOutputs(String deviceId, String fbId, Map<String, double> values) async {
    final body = [
      for (final e in values.entries)
        {'op': 'replace', 'path': '/functionBlocks/$fbId/outputs/${e.key}/value', 'value': e.value.round().toString()},
    ];
    final (status, _) = await _send('PATCH', _uri('/api/v1/apartment/dsDevices/$deviceId/status'), body: body);
    if (status >= 300) throw DssException('Befehl abgelehnt', status: status);
  }

  /// Runs a scenario, e.g. `device-<dsuid>-std.stop`.
  Future<void> invokeScenario(String scenarioId) async {
    final (status, _) = await _send(
        'POST', _uri('/api/v1/apartment/scenarios/${Uri.encodeComponent(scenarioId)}/invoke'),
        body: const <String, Object>{});
    if (status >= 300) throw DssException('Szenario abgelehnt', status: status);
  }
}
