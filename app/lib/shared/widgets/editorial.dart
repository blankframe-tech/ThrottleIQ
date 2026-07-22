import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// Editorial BW design-system primitives.
///
/// Warm paper base, bold solid-black "ink" panels, big rounded white cards
/// with hairline borders, Space Grotesk display type, and a single accent pop
/// (blue) plus an attention color (orange).

/// Space Grotesk display text — used for headings and big numbers.
TextStyle display(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.textPrimary,
  double letterSpacing = -0.5,
  double? height,
}) =>
    GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

/// Small uppercase tracked section label, e.g. "01 · START RIDE", "BADGES".
class EditorialLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const EditorialLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color ?? AppColors.textTertiary,
      ),
    );
  }
}

/// Big rounded white card with a warm hairline border.
class EditorialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingLg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bold solid-black panel with paper-colored content (hero, headers).
class InkPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const InkPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingLg),
    this.radius = AppDimensions.radiusXl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Solid-black rounded icon tile (safety check, badge score).
class InkIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const InkIconTile(this.icon, {super.key, this.size = 64, this.iconSize = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Icon(icon, color: AppColors.onInk, size: iconSize),
    );
  }
}

enum PillTone { accent, attention, ok, dueSoon, overdue, neutral, onInk }

/// Small rounded status/label pill (streak badge, OK / DUE SOON / OVERDUE).
class EditorialPill extends StatelessWidget {
  final String text;
  final PillTone tone;
  final bool filled;
  const EditorialPill(this.text, {super.key, this.tone = PillTone.accent, this.filled = true});

  @override
  Widget build(BuildContext context) {
    late Color fg;
    late Color bg;
    late Color line;
    switch (tone) {
      case PillTone.accent:
        fg = filled ? Colors.white : AppColors.primary;
        bg = filled ? AppColors.primary : Colors.transparent;
        line = AppColors.primary;
        break;
      case PillTone.attention:
      case PillTone.dueSoon:
        fg = filled ? Colors.white : AppColors.attention;
        bg = filled ? AppColors.attention : Colors.transparent;
        line = AppColors.attention;
        break;
      case PillTone.overdue:
        fg = filled ? Colors.white : AppColors.danger;
        bg = filled ? AppColors.danger : Colors.transparent;
        line = AppColors.danger;
        break;
      case PillTone.ok:
        fg = AppColors.success;
        bg = Colors.transparent;
        line = AppColors.success;
        break;
      case PillTone.onInk:
        fg = AppColors.ink;
        bg = AppColors.onInk;
        line = AppColors.onInk;
        break;
      case PillTone.neutral:
        fg = AppColors.textSecondary;
        bg = Colors.transparent;
        line = AppColors.border;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: filled && tone != PillTone.ok && tone != PillTone.neutral
            ? null
            : Border.all(color: line, width: 1.2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

/// A single stat: big Space Grotesk value + small label beneath.
class StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  final Color? valueColor;
  final CrossAxisAlignment align;
  final double valueSize;
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
    this.valueSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: align == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            text: value,
            style: display(valueSize, color: valueColor ?? AppColors.textPrimary),
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: display(valueSize * 0.5,
                      weight: FontWeight.w500, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Thin rounded progress bar (checking-in, maintenance interval).
class EditorialProgress extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  const EditorialProgress(this.value, {super.key, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
      ),
    );
  }
}
