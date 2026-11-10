import 'package:flutter/material.dart';

import '../../dss/models.dart';
import '../../state/home_store.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.zoneId});

  final String zoneId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final room = store.room(zoneId);
    final devices = store.devicesIn(zoneId);
    final lights = devices.whereType<Light>().toList();
    final blinds = devices.whereType<Blind>().toList();
    return Scaffold(
      appBar: AppBar(title: Text(room?.name ?? '')),
      body: RefreshIndicator(
        onRefresh: store.refreshStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Row(children: [
              if (lights.isNotEmpty)
                Expanded(
                  child: _RoomAction(
                      icon: Icons.lightbulb_outline, label: 'Licht aus', onTap: () => store.roomLightsOff(zoneId)),
                ),
              if (lights.isNotEmpty && blinds.isNotEmpty) const SizedBox(width: 8),
              if (blinds.isNotEmpty) ...[
                Expanded(
                  child: _RoomAction(
                      icon: Icons.keyboard_arrow_up_rounded,
                      color: AppColors.blind,
                      label: 'Alle auf',
                      onTap: () => store.roomBlinds(zoneId, up: true)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RoomAction(
                      icon: Icons.keyboard_arrow_down_rounded,
                      color: AppColors.blind,
                      label: 'Alle zu',
                      onTap: () => store.roomBlinds(zoneId, up: false)),
                ),
              ],
            ]),
            if (lights.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(4, 20, 0, 8), child: Text('LICHT', style: sectionLabel)),
              for (final l in lights) Padding(padding: const EdgeInsets.only(bottom: 10), child: _LightRow(light: l)),
            ],
            if (blinds.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(4, 14, 0, 8), child: Text('RAFFSTOREN', style: sectionLabel)),
              for (final b in blinds) Padding(padding: const EdgeInsets.only(bottom: 10), child: _BlindRow(blind: b)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomAction extends StatelessWidget {
  const _RoomAction({required this.icon, required this.label, required this.onTap, this.color = AppColors.text2});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: color),
              Text(label, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _LightRow extends StatelessWidget {
  const _LightRow({required this.light});

  final Light light;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = light;
    return Card2(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 14),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: l.isOn ? AppColors.lightChip : AppColors.ground,
            child: Icon(l.isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                size: 20, color: l.isOn ? AppColors.lightIcon : AppColors.text2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => showDeviceSheet(context, l),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(l.isOn ? 'An · ${l.brightness.round()} %' : 'Aus',
                      style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                ]),
              ),
            ),
          ),
          FavoriteButton(isFavorite: store.isFavorite(l.id), onPressed: () => store.toggleFavorite(l.id)),
          Switch(value: l.isOn, onChanged: (_) => store.toggleLight(l.id), activeTrackColor: AppColors.text),
        ]),
        const SizedBox(height: 8),
        FatSlider(
          value: l.brightness,
          onChanged: (v) => store.setBrightness(l.id, v),
          color: AppColors.lightBar,
          trackColor: AppColors.track,
          semanticLabel: '${l.name} Helligkeit',
          height: 48,
        ),
      ]),
    );
  }
}

class _BlindRow extends StatelessWidget {
  const _BlindRow({required this.blind});

  final Blind blind;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = blind;
    return Card2(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () => showDeviceSheet(context, b),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(b.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(blindStateText(b.position, b.degrees, moving: b.moving),
                      style: const TextStyle(fontSize: 13, color: AppColors.text2)),
                ]),
              ),
            ),
          ),
          FavoriteButton(isFavorite: store.isFavorite(b.id), onPressed: () => store.toggleFavorite(b.id)),
          SquareIconButton(icon: Icons.keyboard_arrow_up_rounded, tooltip: 'Auffahren', onPressed: () => store.blindUp(b.id)),
          const SizedBox(width: 6),
          SquareIconButton(icon: Icons.stop_rounded, tooltip: 'Stopp', onPressed: () => store.blindStop(b.id)),
          const SizedBox(width: 6),
          SquareIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'Abfahren', onPressed: () => store.blindDown(b.id)),
        ]),
        const SizedBox(height: 10),
        FatSlider(
          value: b.position,
          onChanged: (v) => store.setBlind(b.id, position: v),
          color: AppColors.blind,
          trackColor: AppColors.blindTrack,
          semanticLabel: '${b.name} Position',
          height: 48,
        ),
      ]),
    );
  }
}
