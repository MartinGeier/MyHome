import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Listens to the dSS notification WebSocket (`ws://<host>:8090/api/v1/apartment/notifications`).
///
/// The protocol is SignalR-like: after connecting we send `{"protocol":"json","version":1}`,
/// the server answers `{}`, then pushes `{"type":1,"target":…,"arguments":[{"type":"apartmentStatusChanged"}]}`.
/// Frames may contain several records separated by 0x1E.
///
/// We only need to know *that* something changed; the store then re-reads the status.
class DssNotifications {
  DssNotifications({required this.host, required this.appToken, this.port = 8090});

  final String host;
  final String appToken;
  final int port;

  final _events = StreamController<String>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  WebSocket? _ws;
  bool _running = false;
  int _attempt = 0;

  /// Notification types such as `apartmentStatusChanged`.
  Stream<String> get events => _events.stream;

  /// Connection state changes (for the polling fallback).
  Stream<bool> get connected => _connected.stream;

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  Future<void> stop() async {
    _running = false;
    await _ws?.close();
    _ws = null;
  }

  Future<void> _connect() async {
    while (_running) {
      try {
        final ws = await WebSocket.connect('ws://$host:$port/api/v1/apartment/notifications',
                headers: {HttpHeaders.authorizationHeader: 'Bearer $appToken'})
            .timeout(const Duration(seconds: 5));
        ws.pingInterval = const Duration(seconds: 20);
        ws.add(jsonEncode({'protocol': 'json', 'version': 1}));
        _ws = ws;
        _attempt = 0;
        _connected.add(true);
        await for (final frame in ws) {
          if (frame is String) _handle(frame);
        }
      } catch (_) {
        // fall through to reconnect
      }
      _ws = null;
      _connected.add(false);
      if (!_running) break;
      _attempt++;
      final delay = Duration(seconds: _attempt < 5 ? 1 << (_attempt - 1) : 20);
      await Future<void>.delayed(delay);
    }
  }

  void _handle(String frame) {
    for (final record in frame.split('\u001e')) {
      if (record.trim().isEmpty) continue;
      try {
        final msg = jsonDecode(record);
        if (msg is! Map) continue;
        final args = msg['arguments'];
        if (args is List && args.isNotEmpty) {
          for (final a in args) {
            final t = a is Map ? a['type'] : null;
            _events.add(t is String ? t : 'changed');
          }
        } else if (msg['type'] == 1) {
          _events.add('changed');
        }
      } catch (_) {
        // ignore malformed records
      }
    }
  }
}
