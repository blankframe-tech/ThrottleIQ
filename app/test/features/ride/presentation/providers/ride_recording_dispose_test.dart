import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(Firebase.initializeApp);

  // E2E 2026-10-21: dispose() created the live-share coordinator for the
  // first time, and its initialiser read a provider from a container that
  // was already disposing ("ProviderContainer already disposed").
  test('disposing without ever using live share does not throw', () {
    var realtimeReads = 0;
    final container = ProviderContainer(overrides: [
      realtimeServicesProvider.overrideWith((ref) {
        realtimeReads++;
        return RealtimeServices.disabled();
      }),
    ]);
    container.read(rideRecordingProvider);
    expect(container.dispose, returnsNormally);
    expect(realtimeReads, 0, reason: 'live share was never used');
  });
}
