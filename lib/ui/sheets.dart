import 'package:flutter/material.dart';

import '../dss/models.dart';
import '../state/home_store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showDeviceSheet(BuildContext context, Device d) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: d is Light ? LightPanel(id: d.id) : BlindPanel(id: d.id),
        ),
      ),
    );

class _Header extends StatelessWidget {
  const _Header({required this.device, required this.subtitle, this.leading});

  final Device device;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final room = store.room(device.zoneId)?.name ?? '';
    return Row(children: [
      if (leading != null) ...[leading!, const SizedBox(width: 12)],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('$room · $subtitle', style: const TextStyle(fontSize: 14, color: AppColors.text2)),
        ]),
      ),
      FavoriteButton(isFavorite: store.isFavorite(device.id), onPressed: () => store.toggleFavorite(device.id)),
    ]);
  }
}

class LightPanel extends StatelessWidget {
  const LightPanel({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = store.device<Light>(id);
    if (l == null) return const SizedBox.shrink();
    final on = l.isOn;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header(
        device: l,
        subtitle: 'Dimmer',
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: on ? AppColors.lightChip : AppColors.ground,
          child: Icon(on ? Icons.lightbulb : Icons.lightbulb_outline,
              color: on ? AppColors.lightIcon : AppColors.text2),
        ),
      ),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Text(on ? '${l.brightness.round()} %' : 'Aus',
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1.5)),
        ),
        Transform.scale(
          scale: 1.25,
          child: Switch(
            value: on,
            onChanged: (_) => store.toggleLight(id),
            activeTrackColor: AppColors.text,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      FatSlider(
        value: l.brightness,
        onChanged: (v) => store.setBrightness(id, v),
        color: AppColors.lightBar,
        trackColor: AppColors.track,
        semanticLabel: 'Helligkeit',
        height: 76,
      ),
      const SizedBox(height: 16),
      Row(children: [
        for (final p in const [25, 50, 75, 100]) ...[
          if (p != 25) const SizedBox(width: 8),
          Expanded(
            child: _PresetButton(
              label: '$p %',
              active: l.brightness.round() == p,
              onTap: () => store.setBrightness(id, p.toDouble()),
            ),
          ),
        ],
      ]),
    ]);
  }
}

class BlindPanel extends StatelessWidget {
  const BlindPanel({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = store.device<Blind>(id);
    if (b == null) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header(device: b, subtitle: 'Raffstore'),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BlindPicture(position: b.position, angle: b.angle, width: 120, height: 160),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Position', style: sectionLabel),
            Text(
              b.moving ? 'Fährt …' : b.position >= 100 ? 'Offen' : b.position <= 0 ? 'Zu' : '${b.position.round()} %',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -1),
            ),
            Text('Lamellen ${b.degrees}°', style: const TextStyle(fontSize: 15, color: AppColors.text2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Wide(icon: Icons.keyboard_arrow_up_rounded, tip: 'Ganz auf', onTap: () => store.blindUp(id))),
              const SizedBox(width: 8),
              Expanded(child: _Wide(icon: Icons.stop_rounded, tip: 'Stopp', onTap: () => store.blindStop(id))),
              const SizedBox(width: 8),
              Expanded(child: _Wide(icon: Icons.keyboard_arrow_down_rounded, tip: 'Ganz zu', onTap: () => store.blindDown(id))),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      const Row(children: [
        Text('Geschlossen', style: sectionLabel),
        Spacer(),
        Text('Offen', style: sectionLabel),
      ]),
      const SizedBox(height: 6),
      FatSlider(
        value: b.position,
        onChanged: (v) => store.setBlind(id, position: v),
        color: AppColors.blind,
        trackColor: AppColors.blindTrack,
        semanticLabel: 'Position in Prozent offen',
      ),
      const SizedBox(height: 18),
      const Text('Lamellenwinkel', style: sectionLabel),
      const SizedBox(height: 8),
      Row(children: [
        for (final (label, v) in const [('Zu', 0.0), ('45°', 50.0), ('90°', 100.0)]) ...[
          if (v != 0) const SizedBox(width: 8),
          Expanded(
            child: _PresetButton(
              label: label,
              active: b.angle.round() == v.round(),
              activeColor: AppColors.blind,
              onTap: () => store.setBlind(id, angle: v),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      FatSlider(
        value: b.angle,
        onChanged: (v) => store.setBlind(id, angle: v),
        color: AppColors.blind,
        trackColor: AppColors.blindTrack,
        semanticLabel: 'Lamellenwinkel',
        height: 44,
      ),
    ]);
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.icon, required this.tip, required this.onTap});

  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SquareIconButton(icon: icon, tooltip: tip, onPressed: onTap, size: c.maxWidth),
      );
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.active, required this.onTap, this.activeColor = AppColors.text});

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? activeColor : AppColors.ground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.text)),
            ),
          ),
        ),
      );
}

/// A window with the blind drawn at its position; slat thickness follows the angle.
class BlindPicture extends StatelessWidget {
  const BlindPicture({super.key, required this.position, required this.angle, this.width = 120, this.height = 160});

  final double position;
  final double angle;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Raffstore ${position.round()} Prozent offen, Lamellen ${(angle * 0.9).round()} Grad',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFCFE3F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 6),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(painter: _SlatsPainter(closed: (100 - position) / 100, angle: angle / 100)),
        ),
      );
}

class _SlatsPainter extends CustomPainter {
  _SlatsPainter({required this.closed, required this.angle});

  final double closed;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * closed;
    if (h <= 0) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h), Paint()..color = AppColors.slatGap);
    final slat = Paint()..color = const Color(0xFF9AA6C8);
    final thick = 3 + (1 - angle) * 7;
    for (double y = 0; y < h; y += 11) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, thick.clamp(0, h - y)), slat);
    }
    canvas.drawRect(Rect.fromLTWH(0, h - 4, size.width, 4), Paint()..color = const Color(0xFF8C97B8));
  }

  @override
  bool shouldRepaint(_SlatsPainter old) => old.closed != closed || old.angle != angle;
}
