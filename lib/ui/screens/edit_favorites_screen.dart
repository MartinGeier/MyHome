import 'package:flutter/material.dart';

import '../../dss/models.dart';
import '../../state/home_store.dart';
import '../theme.dart';

class EditFavoritesScreen extends StatelessWidget {
  const EditFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final favs = store.favoriteDevices;
    final rooms = store.apartment?.rooms ?? const <Room>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoriten'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        onReorderItem: store.reorderFavorites,
        header: const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text('Ziehen zum Sortieren, Minus zum Entfernen.', style: TextStyle(color: AppColors.text2)),
        ),
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 24, 0, 6), child: Text('HINZUFÜGEN', style: sectionLabel)),
          for (final r in rooms)
            for (final d in store.devicesIn(r.id))
              if (!store.isFavorite(d.id))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: _KindIcon(device: d),
                  title: Text(d.name),
                  subtitle: Text(r.name),
                  trailing: IconButton(
                    tooltip: '${d.name} hinzufügen',
                    icon: const Icon(Icons.add_circle, color: AppColors.ok, size: 28),
                    onPressed: () => store.toggleFavorite(d.id),
                  ),
                ),
        ]),
        children: [
          for (final (i, d) in favs.indexed)
            Container(
              key: ValueKey(d.id),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: IconButton(
                  tooltip: '${d.name} entfernen',
                  icon: const Icon(Icons.remove_circle, color: AppColors.danger, size: 28),
                  onPressed: () => store.toggleFavorite(d.id),
                ),
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(store.room(d.zoneId)?.name ?? ''),
                trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: AppColors.ground,
        child: device is Light
            ? const Icon(Icons.lightbulb_outline, color: AppColors.lightIcon)
            : const Icon(Icons.blinds, color: AppColors.blind),
      );
}
