import 'package:flutter/material.dart';

import 'state/home_store.dart';
import 'state/settings.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(MyHomeApp(settings: settings));
}

class MyHomeApp extends StatefulWidget {
  const MyHomeApp({super.key, required this.settings});

  final Settings settings;

  @override
  State<MyHomeApp> createState() => _MyHomeAppState();
}

class _MyHomeAppState extends State<MyHomeApp> {
  HomeStore? _store;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    if (widget.settings.isConnected) _startStore();
    _lifecycle = AppLifecycleListener(onResume: () => _store?.onResumed());
  }

  void _startStore() {
    final store = HomeStore(widget.settings);
    _store = store;
    store.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final app = MaterialApp(
      title: 'MyHome',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: store == null
          ? SetupScreen(settings: widget.settings, onConnected: () => setState(_startStore))
          : const Shell(),
    );
    return store == null ? app : StoreScope(store: store, child: app);
  }
}
