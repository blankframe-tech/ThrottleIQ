import 'package:flutter/material.dart';
import '../../core/theme/app_theme_context.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// Editorial BW design-system primitives.
///
/// Warm paper base, bold solid-black "ink" panels, big rounded white cards
/// with hairline borders, Space Grotesk display type, and a single accent pop
/// (blue) plus an attention color (orange).

/// Display text for headings and big numbers, in whichever face the current
/// skin uses — see [AppTypography.display]. Kept as a bare top-level function
/// because dozens of call sites already read `display(context, 18)`.
TextStyle display(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w700,
  Color? color,
  double letterSpacing = -0.5,
  double? height,
}) =>
    AppTypography.display(
      context,
      size,
      weight: weight,
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
        color: color ?? context.palette.textTertiary,
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

  /// Corner radius, or null to follow the active skin's card radius. Nullable
  /// rather than defaulted because `context.shape.radiusXl` is per-skin now
  /// (see [AppShapeProfile]) and so can't be a `const` default value.
  final double? radius;

  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingLg),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? context.shape.radiusXl;
    return Material(
      color: color ?? context.palette.surface,
      borderRadius: BorderRadius.circular(r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: borderColor ?? context.palette.border),
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

  /// Corner radius, or null to follow the active skin — see
  /// [EditorialCard.radius].
  final double? radius;
  const InkPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingLg),
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.ink,
        borderRadius: BorderRadius.circular(radius ?? context.shape.radiusXl),
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
        color: context.palette.ink,
        borderRadius: BorderRadius.circular(context.shape.radiusLg),
      ),
      child: Icon(icon, color: context.palette.onInk, size: iconSize),
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
        fg = filled ? Colors.white : context.palette.primary;
        bg = filled ? context.palette.primary : Colors.transparent;
        line = context.palette.primary;
        break;
      case PillTone.attention:
      case PillTone.dueSoon:
        fg = filled ? Colors.white : context.palette.attention;
        bg = filled ? context.palette.attention : Colors.transparent;
        line = context.palette.attention;
        break;
      case PillTone.overdue:
        fg = filled ? Colors.white : context.palette.danger;
        bg = filled ? context.palette.danger : Colors.transparent;
        line = context.palette.danger;
        break;
      case PillTone.ok:
        fg = context.palette.success;
        bg = Colors.transparent;
        line = context.palette.success;
        break;
      case PillTone.onInk:
        fg = context.palette.ink;
        bg = context.palette.onInk;
        line = context.palette.onInk;
        break;
      case PillTone.neutral:
        fg = context.palette.textSecondary;
        bg = Colors.transparent;
        line = context.palette.border;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.shape.radiusFull),
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
            style: display(context, valueSize, color: valueColor ?? context.palette.textPrimary),
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: display(context, valueSize * 0.5,
                      weight: FontWeight.w500, color: context.palette.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
      ],
    );
  }
}

/// Dashed-look outlined "+ label" button (log a service, add a bike).
class DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const DashedAddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.shape.radiusLg),
          border: Border.all(color: context.palette.primary.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: context.palette.primary),
            const SizedBox(width: 8),
            Text(label,
                style: display(context, 14, letterSpacing: 0, color: context.palette.primary)),
          ],
        ),
      ),
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
      borderRadius: BorderRadius.circular(context.shape.radiusFull),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: context.palette.border,
        valueColor: AlwaysStoppedAnimation(color ?? context.palette.primary),
      ),
    );
  }
}
