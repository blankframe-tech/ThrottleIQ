import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Wraps the application or screen widget tree so that tapping anywhere
/// outside the currently focused text field automatically unfocuses it,
/// dismissing the soft keyboard.
class KeyboardDismissWrapper extends StatelessWidget {
  final Widget child;

  const KeyboardDismissWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return;
    if (_hitsTextFieldTapRegion(event)) return;

    final focusContext = currentFocus.context;
    if (focusContext == null || !focusContext.mounted) {
      currentFocus.unfocus();
      return;
    }

    final renderObject = focusContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final localPosition = renderObject.globalToLocal(event.position);
      if (!renderObject.paintBounds.contains(localPosition)) {
        currentFocus.unfocus();
      }
    } else {
      currentFocus.unfocus();
    }
  }

  // Text-field popups (Autocomplete options, selection handles) render in the
  // overlay outside the field's bounds but sit in a TextFieldTapRegion;
  // unfocusing on their pointer-down closes them before a tap or scroll lands.
  bool _hitsTextFieldTapRegion(PointerDownEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    return result.path.any((entry) =>
        entry.target is RenderTapRegion &&
        (entry.target as RenderTapRegion).groupId == EditableText);
  }
}
