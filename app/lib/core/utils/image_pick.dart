import 'package:flutter/services.dart';

/// Awaits an image_picker call, treating `already_active` (a second tap while
/// the picker is still open) as "nothing picked" rather than an error.
Future<T?> ignoreActivePicker<T>(Future<T> pick) async {
  try {
    return await pick;
  } on PlatformException catch (e) {
    if (e.code == 'already_active') return null;
    rethrow;
  }
}
