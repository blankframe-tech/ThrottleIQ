import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/shared/widgets/keyboard_dismiss_wrapper.dart';

void main() {
  group('KeyboardDismissWrapper', () {
    testWidgets('unfocuses when tapping outside text field', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('text_field'),
                    focusNode: focusNode,
                  ),
                  Container(
                    key: const ValueKey('outside_area'),
                    height: 150,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Focus the text field
      await tester.tap(find.byKey(const ValueKey('text_field')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap outside the text field
      await tester.tap(find.byKey(const ValueKey('outside_area')));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('keeps focus when tapping inside the focused text field', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('text_field'),
                    focusNode: focusNode,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('text_field')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap inside the same text field again
      await tester.tap(find.byKey(const ValueKey('text_field')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('shifts focus when tapping from one text field to another', (tester) async {
      final focusNode1 = FocusNode();
      final focusNode2 = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('field1'),
                    focusNode: focusNode1,
                  ),
                  TextField(
                    key: const ValueKey('field2'),
                    focusNode: focusNode2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('field1')));
      await tester.pump();
      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);

      // Tap second field
      await tester.tap(find.byKey(const ValueKey('field2')));
      await tester.pump();
      expect(focusNode1.hasFocus, isFalse);
      expect(focusNode2.hasFocus, isTrue);
    });

    testWidgets('dismisses keyboard and executes button callback when button is tapped', (tester) async {
      final focusNode = FocusNode();
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('field'),
                    focusNode: focusNode,
                  ),
                  ElevatedButton(
                    key: const ValueKey('submit_btn'),
                    onPressed: () {
                      buttonPressed = true;
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(const ValueKey('submit_btn')));
      await tester.pump();
      expect(buttonPressed, isTrue);
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('dismisses keyboard when scrolling/dragging list view', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: ListView(
              children: [
                TextField(
                  key: const ValueKey('field'),
                  focusNode: focusNode,
                ),
                for (int i = 0; i < 20; i++)
                  ListTile(
                    key: ValueKey('item_$i'),
                    title: Text('Item $i'),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Scroll the list
      await tester.drag(find.byKey(const ValueKey('item_5')), const Offset(0, -100));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('handles dialog overlay taps', (tester) async {
      final dialogFocusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_dialog'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Dialog'),
                      content: TextField(
                        key: const ValueKey('dialog_field'),
                        focusNode: dialogFocusNode,
                      ),
                      actions: [
                        TextButton(
                          key: const ValueKey('dialog_cancel'),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open_dialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dialog_field')));
      await tester.pump();
      expect(dialogFocusNode.hasFocus, isTrue);

      // Tap on the dialog title area outside the textfield
      await tester.tap(find.text('Dialog'));
      await tester.pump();
      expect(dialogFocusNode.hasFocus, isFalse);
    });

    testWidgets('safely does nothing when no focus node is active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KeyboardDismissWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(
            body: Text('Hello'),
          ),
        ),
      );

      // Tap anywhere without errors
      await tester.tap(find.text('Hello'));
      await tester.pump();
    });
  });
}
