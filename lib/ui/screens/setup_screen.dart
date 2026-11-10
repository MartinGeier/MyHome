import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dss/discovery.dart';
import '../../dss/dss_client.dart';
import '../../state/settings.dart';
import '../theme.dart';

enum _Step { searching, notFound, requesting, waiting, failed }

/// First run: find the dSS, request an app token, wait until the user enables
/// it in the dS Konfigurator (System → Zugriffsberechtigung).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.settings, required this.onConnected});

  final Settings settings;
  final VoidCallback onConnected;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  _Step _step = _Step.searching;
  FoundServer? _server;
  String? _error;
  Timer? _poll;
  final _manual = TextEditingController();

  static final _appName = 'MyHome (${Platform.isIOS ? 'iPhone' : Platform.isAndroid ? 'Android' : Platform.operatingSystem})';

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _step = _Step.searching);
    final s = await discoverDss();
    if (!mounted) return;
    if (s == null) {
      setState(() => _step = _Step.notFound);
    } else {
      _server = s;
      await _requestToken();
    }
  }

  Future<void> _useManual() async {
    final host = _manual.text.trim();
    if (host.isEmpty) return;
    setState(() => _step = _Step.searching);
    final s = await probeDss(host);
    if (!mounted) return;
    if (s == null) {
      setState(() {
        _step = _Step.notFound;
        _error = 'Unter „$host“ antwortet kein digitalSTROM-Server.';
      });
    } else {
      _server = s;
      await _requestToken();
    }
  }

  Future<void> _requestToken() async {
    final s = _server!;
    setState(() => _step = _Step.requesting);
    final client = DssClient(host: s.host, pinnedFingerprint: s.fingerprint);
    try {
      var token = widget.settings.pendingToken;
      token ??= await client.requestApplicationToken(_appName);
      await widget.settings.setPendingToken(token);
      if (!mounted) return;
      setState(() => _step = _Step.waiting);
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check(client, token!));
      unawaited(_check(client, token));
    } on DssException catch (e) {
      client.close();
      setState(() {
        _step = _Step.failed;
        _error = e.message;
      });
    }
  }

  bool _checking = false;

  Future<void> _check(DssClient client, String token) async {
    if (_checking) return;
    _checking = true;
    try {
      if (await client.isTokenApproved(token)) {
        _poll?.cancel();
        client.close();
        await widget.settings.saveConnection(host: _server!.host, token: token, fingerprint: _server!.fingerprint);
        await widget.settings.setPendingToken(null);
        widget.onConnected();
      }
    } catch (_) {
      // keep waiting
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _server;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.home_outlined, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Mit digitalSTROM verbinden', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Einmalig: Die App bittet den Server um Zugriff. Du gibst ihn im dS Konfigurator frei.',
                style: TextStyle(fontSize: 15, color: AppColors.text2, height: 1.4)),
            const SizedBox(height: 24),
            _StepCard(
              done: s != null,
              active: _step == _Step.searching,
              title: s != null ? 'Server gefunden' : 'Server suchen',
              subtitle: s != null ? '${s.host} · dSS ${s.version}' : 'Suche im WLAN …',
            ),
            if (_step == _Step.notFound) ...[
              const SizedBox(height: 10),
              Text(
                  _error ??
                      'Kein Server gefunden. Ist das Handy im Heim-WLAN? In einem Gäste-WLAN ist der '
                          'digitalSTROM-Server nicht erreichbar. Oder gib Adresse bzw. IP ein:',
                  style: const TextStyle(color: AppColors.text2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'z. B. 192.168.10.11', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                    onSubmitted: (_) => _useManual(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _useManual, child: const Text('Verbinden')),
              ]),
              TextButton(onPressed: _search, child: const Text('Erneut suchen')),
            ],
            const SizedBox(height: 10),
            _StepCard(
              done: _step == _Step.waiting,
              active: _step == _Step.requesting,
              title: 'Zugriff anfragen',
              subtitle: 'als „$_appName“',
            ),
            const SizedBox(height: 10),
            _StepCard(
              done: false,
              active: _step == _Step.waiting,
              title: 'Im dS Konfigurator freigeben',
              subtitle: 'System → Zugriffsberechtigung → bei „$_appName“ das Häkchen setzen.',
              extra: _step == _Step.waiting ? 'Warte auf Freigabe …' : null,
            ),
            if (_step == _Step.failed) ...[
              const SizedBox(height: 12),
              Text(_error ?? 'Fehler', style: const TextStyle(color: AppColors.danger)),
              TextButton(onPressed: _search, child: const Text('Nochmal versuchen')),
            ],
            const Spacer(),
            if (_step == _Step.waiting && s != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => launchUrl(Uri.parse('https://${s.host}/'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Konfigurator öffnen'),
              ),
              const SizedBox(height: 8),
              const Text('Die App prüft alle 3 Sekunden und startet automatisch.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.text2)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.done, required this.active, required this.title, required this.subtitle, this.extra});

  final bool done;
  final bool active;
  final String title;
  final String subtitle;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.blind : AppColors.border, width: active ? 2 : 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          height: 28,
          child: done
              ? const CircleAvatar(backgroundColor: AppColors.ok, child: Icon(Icons.check, size: 16, color: Colors.white))
              : active
                  ? const CircularProgressIndicator(strokeWidth: 3, color: AppColors.blind)
                  : const CircleAvatar(backgroundColor: AppColors.ground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4)),
            if (extra != null) ...[
              const SizedBox(height: 4),
              Text(extra!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blind)),
            ],
          ]),
        ),
      ]),
    );
  }
}
