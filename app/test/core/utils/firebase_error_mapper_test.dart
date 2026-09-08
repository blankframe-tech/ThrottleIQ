import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/firebase_error_mapper.dart';

void main() {
  group('mapLocationError', () {
    test('maps location services disabled to friendly prompt', () {
      final msg = mapLocationError(Exception('Location services are disabled. Please enable GPS.'));
      expect(msg, contains('Location is turned off'));
      expect(msg, contains('Enable GPS'));
    });

    test('maps permission denied to settings prompt', () {
      final msg = mapLocationError(Exception('Location permission is denied by user'));
      expect(msg, contains('Location permission is needed'));
      expect(msg, contains('Settings'));
    });

    test('maps unknown location error to fallback message', () {
      final msg = mapLocationError(Exception('Timeout fetching position fix'));
      expect(msg, contains('Could not get your location'));
      expect(msg, contains('Check that GPS is on'));
    });
  });

  group('isLocationServicesError', () {
    test('identifies location services off errors', () {
      expect(
        isLocationServicesError(Exception('Location services are disabled')),
        isTrue,
      );
      expect(
        isLocationServicesError(Exception('location services are off')),
        isTrue,
      );
      expect(
        isLocationServicesError(Exception('permission denied')),
        isFalse,
      );
    });
  });

  group('isLocationPermissionError', () {
    test('identifies location permission errors', () {
      expect(
        isLocationPermissionError(Exception('Permission denied')),
        isTrue,
      );
      expect(
        isLocationPermissionError(Exception('location permission denied forever')),
        isTrue,
      );
      expect(
        isLocationPermissionError(Exception('network error')),
        isFalse,
      );
    });
  });

  group('mapFirestoreError', () {
    test('maps network errors to offline message', () {
      expect(
        mapFirestoreError(Exception('SocketException: OS Error: Connection refused')),
        contains("You're offline"),
      );
      expect(
        mapFirestoreError(Exception('Failed host lookup')),
        contains("You're offline"),
      );
    });

    test('maps generic error to friendly message', () {
      expect(
        mapFirestoreError(Exception('internal error 500')),
        equals('Something went wrong loading this. Please try again.'),
      );
    });
  });

  group('mapFirebaseAuthError', () {
    test('maps null to unknown error', () {
      expect(mapFirebaseAuthError(null), equals('An unknown error occurred'));
    });

    test('maps network string to connection message', () {
      expect(
        mapFirebaseAuthError('network connection lost'),
        contains('Network connection failed'),
      );
    });

    test('maps permission string to settings message', () {
      expect(
        mapFirebaseAuthError('permission denied on endpoint'),
        contains('Permission denied'),
      );
    });

    test('maps generic string to clean fallback without leaking internals', () {
      expect(
        mapFirebaseAuthError('some internal database error [code 42]'),
        equals('Something went wrong. Please try again.'),
      );
    });
  });
}
