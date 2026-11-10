import 'dart:async';

import 'package:flutter/material.dart';

import '../state/home_store.dart';
import 'screens/energy_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rooms_screen.dart';

/// Bottom navigation with Favoriten / Räume / Energie. Tabs stay alive
/// (IndexedStack) so switching is instant.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  StreamSubscription<String>? _errSub;
  final _roomsNav = GlobalKey<NavigatorState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _errSub ??= StoreScope.read(context).errors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    });
  }

  @override
  void dispose() {
    _errSub?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab && i == 1) _roomsNav.currentState?.popUntil((r) => r.isFirst);
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0 && !(_roomsNav.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab == 1 && (_roomsNav.currentState?.canPop() ?? false)) {
          _roomsNav.currentState!.pop();
        } else {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: [
          HomeScreen(onOpenEnergy: () => _select(2), onOpenRooms: () => _select(1)),
          // Rooms get their own navigator so the room detail keeps the tab bar.
          Navigator(
            key: _roomsNav,
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: RoomsScreen())),
          ),
          EnergyScreen(active: _tab == 2),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Favoriten'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Räume'),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Energie'),
          ],
        ),
      ),
    );
  }
}
