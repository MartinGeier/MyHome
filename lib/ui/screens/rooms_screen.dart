import 'package:flutter/material.dart';

import '../../dss/models.dart';
import '../../state/home_store.dart';
import '../theme.dart';
import 'room_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rooms = store.apartment?.rooms ?? const <Room>[];
    final on = store.lightsOn;
    return RefreshIndicator(
      onRefresh: store.refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(child: SizedBox(height: 48, child: Text('Räume', style: bigTitle))),
            ),
          ),
          if (on > 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightChip,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lightbulb, color: AppColors.lightIcon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(on == 1 ? '1 Licht an' : '$on Lichter an',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    FilledButton(onPressed: store.allLightsOff, child: const Text('Alle aus')),
                  ]),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 88,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildListDelegate([
                for (final r in rooms) _RoomCard(room: r, devices: store.devicesIn(r.id)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.devices});

  final Room room;
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final lightsOn = devices.whereType<Light>().where((l) => l.isOn).length;
    final hasLights = devices.any((d) => d is Light);
    final blinds = devices.whereType<Blind>().toList();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RoomScreen(zoneId: room.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(children: [
              if (lightsOn > 0)
                const _Pill(icon: Icons.lightbulb, text: 'An', bg: AppColors.lightChip, fg: Color(0xFF7A4700))
              else if (hasLights && blinds.isEmpty)
                const Text('Licht aus', style: TextStyle(fontSize: 12, color: AppColors.text2)),
              if (lightsOn > 0 && blinds.isNotEmpty) const SizedBox(width: 6),
              if (blinds.isNotEmpty)
                Flexible(
                  child: _Pill(
                      icon: Icons.blinds, text: _blindSummary(blinds), bg: AppColors.blindSoft, fg: const Color(0xFF2A49B0)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _blindSummary(List<Blind> blinds) {
    final open = blinds.where((b) => b.position >= 100).length;
    final closed = blinds.where((b) => b.position <= 0).length;
    final partial = blinds.length - open - closed;
    if (blinds.length == 1) {
      final b = blinds.first;
      return b.position >= 100 ? 'offen' : b.position <= 0 ? 'zu' : '${b.position.round()} % offen';
    }
    final parts = [if (open > 0) '$open offen', if (partial > 0) '$partial halb', if (closed > 0) '$closed zu'];
    return parts.join(' · ');
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.bg, required this.fg});

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ),
        ]),
      );
}
