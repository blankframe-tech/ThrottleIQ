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
class BrandModelAutocompleteField extends StatefulWidget {
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
  State<BrandModelAutocompleteField> createState() =>
      _BrandModelAutocompleteFieldState();
}

class _BrandModelAutocompleteFieldState
    extends State<BrandModelAutocompleteField> {
  // RawAutocomplete asserts that textEditingController and focusNode are
  // either both supplied or both left null — passing a controller alone
  // (as this field used to) fails that assertion as soon as the widget
  // builds.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final options = widget.optionsBuilder(value.text);
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
          decoration: InputDecoration(
              labelText: widget.labelText, hintText: widget.hintText),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        );
      },
    );
  }
}
