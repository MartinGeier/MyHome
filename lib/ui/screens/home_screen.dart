import 'package:flutter/material.dart';

import '../../dss/models.dart';
import '../../state/home_store.dart';
import '../theme.dart';
import '../tiles.dart';
import '../widgets.dart';
import 'edit_favorites_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenEnergy, required this.onOpenRooms});

  final VoidCallback onOpenEnergy;
  final VoidCallback onOpenRooms;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final favs = store.favoriteDevices;
    final on = store.lightsOn;
    return RefreshIndicator(
      onRefresh: store.refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Zuhause', style: bigTitle)),
                    if (!store.online)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Tooltip(message: 'Keine Verbindung', child: Icon(Icons.cloud_off, color: AppColors.danger)),
                      ),
                    IconButton.outlined(
                      tooltip: 'Favoriten bearbeiten',
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const EditFavoritesScreen())),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (store.outdoorTemp != null)
                      InfoChip(icon: Icons.thermostat, label: '${store.outdoorTemp!.toStringAsFixed(1)} °C'),
                    if (store.totalWatts != null)
                      InfoChip(icon: Icons.bolt, label: '${store.totalWatts!.round()} W', onTap: onOpenEnergy),
                    InfoChip(
                      icon: Icons.lightbulb_outline,
                      label: on == 0 ? 'Alle Lichter aus' : on == 1 ? '1 Licht an' : '$on Lichter an',
                      highlight: on > 0,
                      onTap: on > 0 ? () => _confirmAllOff(context, store) : null,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
          if (store.apartment == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (favs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.star_outline_rounded, size: 48, color: AppColors.text2),
                  const SizedBox(height: 12),
                  const Text('Noch keine Favoriten',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Tippe in einem Raum auf den Stern, um Lichter und Raffstoren hierher zu holen.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.text2)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onOpenRooms, child: const Text('Zu den Räumen')),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 118,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                // Keyed builder so tiles keep their state while being reordered.
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ReorderableFavorite(key: ValueKey(favs[i].id), device: favs[i], index: i),
                  childCount: favs.length,
                  findChildIndexCallback: (key) {
                    final i = favs.indexWhere((d) => ValueKey(d.id) == key);
                    return i < 0 ? null : i;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAllOff(BuildContext context, HomeStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Alle Lichter ausschalten?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Alle aus')),
        ],
      ),
    );
    if (ok == true) store.allLightsOff();
  }
}

/// A favourite tile that can be long-pressed and dragged to a new position.
/// Tiles move out of the way live while dragging; the order is saved immediately.
class _ReorderableFavorite extends StatelessWidget {
  const _ReorderableFavorite({super.key, required this.device, required this.index});

  final Device device;
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return DragTarget<String>(
        onWillAcceptWithDetails: (d) {
          if (d.data != device.id) store.moveFavorite(d.data, index);
          return true;
        },
        builder: (context, _, _) => LongPressDraggable<String>(
          data: device.id,
          hapticFeedbackOnStart: true,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox.fromSize(
              size: size,
              child: Transform.scale(
                scale: 1.05,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: deviceTile(device),
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border, width: 2),
              color: AppColors.ground,
            ),
          ),
          child: deviceTile(device),
        ),
      );
    });
  }
}
