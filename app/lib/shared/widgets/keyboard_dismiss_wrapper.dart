import 'package:flutter/material.dart';

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
}
