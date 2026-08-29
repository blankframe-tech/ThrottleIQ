import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A free-text field that also offers a dropdown of suggestions as the rider
/// types — used for the Brand and Model fields on Add/Edit Bike and
/// onboarding's first-bike step.
///
/// Deliberately just a thin wrapper around Flutter's own `Autocomplete`: the
/// underlying field is always plain free text (via [controller]), so typing
/// something that isn't in [optionsBuilder]'s list — a "custom" brand/model —
/// works exactly as it did before this existed. The dropdown is a shortcut
/// for the common case, not a constraint.
class BrandModelAutocompleteField extends StatelessWidget {
  const BrandModelAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.optionsBuilder,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;

  /// Re-evaluated on every keystroke, so a model field can read the
  /// currently-typed brand live (see add_edit_bike_screen.dart's usage) and
  /// stay in sync without needing its own rebuild trigger.
  final List<String> Function(String typed) optionsBuilder;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      textEditingController: controller,
      optionsBuilder: (value) {
        final options = optionsBuilder(value.text);
        if (value.text.isEmpty) return options;
        final query = value.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          onEditingComplete: onFieldSubmitted,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(labelText: labelText, hintText: hintText),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }
}
