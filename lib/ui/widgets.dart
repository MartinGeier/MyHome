import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// A tall, full-width slider: the whole bar is the touch target and the fill
/// shows the value. Calls [onChanged] continuously while dragging.
class FatSlider extends StatelessWidget {
  const FatSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.color,
    required this.trackColor,
    required this.semanticLabel,
    this.height = 56,
  });

  final double value; // 0..100
  final ValueChanged<double> onChanged;
  final Color color;
  final Color trackColor;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      void at(double dx) => onChanged((dx / w * 100).clamp(0, 100).roundToDouble());
      return Semantics(
        label: semanticLabel,
        value: '${value.round()} %',
        increasedValue: '${(value + 10).clamp(0, 100).round()} %',
        decreasedValue: '${(value - 10).clamp(0, 100).round()} %',
        onIncrease: () => onChanged((value + 10).clamp(0, 100)),
        onDecrease: () => onChanged((value - 10).clamp(0, 100)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.selectionClick();
            at(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
          child: Container(
            height: height,
            decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(height * 0.3)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.centerLeft,
            child: Stack(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: w * value / 100,
                color: color,
              ),
              Positioned(
                left: (w * value / 100 - 10).clamp(4, w - 10),
                top: height * 0.22,
                bottom: height * 0.22,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

/// Round icon button with a 44 px touch target.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background = AppColors.blindSoft,
    this.foreground = AppColors.blind,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox(width: size, height: size, child: Icon(icon, color: foreground, size: 22)),
        ),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: isFavorite ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
        onPressed: onPressed,
        icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFavorite ? AppColors.favStar : AppColors.text2, size: 26),
      );
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label, this.onTap, this.highlight = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.lightChip : AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: highlight ? AppColors.lightBorder : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: highlight ? AppColors.lightIcon : AppColors.text),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class Card2 extends StatelessWidget {
  const Card2({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

String blindStateText(double position, int degrees, {bool moving = false}) {
  if (moving) return 'Fährt …';
  if (position >= 100) return 'Offen';
  if (position <= 0) return 'Geschlossen';
  return '${position.round()} % offen · $degrees°';
}
