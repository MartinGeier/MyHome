import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dss/models.dart';
import '../state/home_store.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

/// Favourite tile for a light.
/// Tap = on/off · drag sideways = dim · ⋯ = detail sheet · long-press = reorder (home screen).
class LightTile extends StatefulWidget {
  const LightTile({super.key, required this.light});

  final Light light;

  @override
  State<LightTile> createState() => _LightTileState();
}

class _LightTileState extends State<LightTile> {
  double _start = 0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final l = widget.light;
    final on = l.isOn;
    final room = StoreScope.of(context).room(l.zoneId)?.name ?? '';
    return Semantics(
      button: true,
      toggled: on,
      label: '${l.name}, $room',
      value: on ? '${l.brightness.round()} %' : 'aus',
      child: LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            store.toggleLight(l.id);
          },
          onHorizontalDragStart: (_) {
            _start = l.brightness;
            _dx = 0;
          },
          onHorizontalDragUpdate: (d) {
            _dx += d.delta.dx;
            store.setBrightness(l.id, (_start + _dx / c.maxWidth * 100).clamp(0, 100));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: on ? AppColors.lightBase : AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: on ? AppColors.lightBorder : AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: c.maxWidth * (on ? l.brightness : 0) / 100,
                color: AppColors.lightFill,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: on ? Colors.white : AppColors.ground,
                    child: Icon(on ? Icons.lightbulb : Icons.lightbulb_outline,
                        size: 20, color: on ? AppColors.lightIcon : AppColors.text2),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 100,
                    child: Text(l.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2)),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$room · '),
                      TextSpan(
                          text: on ? '${l.brightness.round()} %' : 'Aus',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.text2),
                  ),
                ]),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: 'Helligkeit einstellen',
                  onPressed: () => showDeviceSheet(context, l),
                  icon: const Icon(Icons.more_horiz, color: AppColors.text2),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

/// Favourite tile for a blind.
/// ▲/▼ = move right away · drag up/down = position · tap = detail sheet · long-press = reorder (home screen).
class BlindTile extends StatefulWidget {
  const BlindTile({super.key, required this.blind});

  final Blind blind;

  @override
  State<BlindTile> createState() => _BlindTileState();
}

class _BlindTileState extends State<BlindTile> {
  double _start = 0;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final b = widget.blind;
    final room = StoreScope.of(context).room(b.zoneId)?.name ?? '';
    final state = blindStateText(b.position, b.degrees, moving: b.moving);
    return Semantics(
      label: '${b.name}, $room',
      value: state,
      child: LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          onTap: () => showDeviceSheet(context, b),
          onVerticalDragStart: (_) {
            _start = b.position;
            _dy = 0;
          },
          onVerticalDragUpdate: (d) {
            _dy += d.delta.dy;
            store.setBlind(b.id, position: (_start - _dy / c.maxHeight * 100).clamp(0, 100));
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: c.maxHeight * (100 - b.position) / 100,
                width: double.infinity,
                child: const CustomPaint(painter: _StripePainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 60, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blindBorder),
                    ),
                    child: const Icon(Icons.blinds, size: 20, color: AppColors.blind),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 100,
                    child: Text(b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2)),
                  ),
                  Text(state,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              Positioned(
                right: 8,
                top: 8,
                bottom: 8,
                child: Column(children: [
                  Expanded(
                    child: _TileButton(
                        icon: Icons.keyboard_arrow_up_rounded, tip: 'Auffahren', onTap: () => store.blindUp(b.id)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _TileButton(
                        icon: Icons.keyboard_arrow_down_rounded, tip: 'Abfahren', onTap: () => store.blindDown(b.id)),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({required this.icon, required this.tip, required this.onTap});

  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.blindBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: SizedBox(width: 44, child: Icon(icon, color: AppColors.blind)),
          ),
        ),
      );
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.slatGap);
    final p = Paint()..color = AppColors.slat;
    for (double y = 0; y < size.height; y += 10) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 7), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}

/// Picks the tile for a device.
Widget deviceTile(Device d) => switch (d) {
      Light l => LightTile(key: ValueKey(l.id), light: l),
      Blind b => BlindTile(key: ValueKey(b.id), blind: b),
    };
