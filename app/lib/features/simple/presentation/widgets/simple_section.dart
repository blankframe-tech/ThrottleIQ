import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';

/// The one section heading on every Simple tab, with an optional action on
/// the right ("+ Add fuel"). Same height with or without the action.
class SimpleSectionHeader extends StatelessWidget {
  const SimpleSectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 18)),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

/// A big number with what it is under it: "12.4 km" / "Distance".
class SimpleStatTile extends StatelessWidget {
  const SimpleStatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => EditorialCard(
        radius: context.shape.radiusLg,
        padding: const EdgeInsets.all(14),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A number shrinks to fit rather than break mid-number.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: display(context, 26)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(color: context.palette.textSecondary)),
            ],
          ),
        ),
      );
}

/// [children] two to a row, each row as tall as its taller tile.
class SimpleTileGrid extends StatelessWidget {
  const SimpleTileGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < children.length; i += 2)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[i]),
                    if (i + 1 < children.length) ...[
                      const SizedBox(width: 12),
                      Expanded(child: children[i + 1]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
}
