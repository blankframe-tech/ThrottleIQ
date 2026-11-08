import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/social/data/repositories/group_ride_repository.dart';
import 'package:throttleiq/features/social/data/repositories/notification_repository.dart';
import 'package:throttleiq/features/social/domain/entities/app_notification_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/group_ride_providers.dart';
import 'package:throttleiq/features/social/presentation/providers/notification_providers.dart';
import 'package:throttleiq/features/social/presentation/screens/notifications_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'victim';
  @override
  String? get displayName => 'Victim';
  @override
  String? get photoURL => null;
}

class _FakeRides extends Fake implements GroupRideRepository {
  final accepted = <String>[];

  @override
  Future<void> acceptInvitation({
    required String groupRideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
  }) async =>
      accepted.add(groupRideId);
}

class _FakeNotifications extends Fake implements NotificationRepository {
  @override
  Future<void> notifyGroupRideJoined({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String groupRideId,
    String? fromPhotoUrl,
  }) async {}
}

/// Anyone can send a group-ride invite, and joining shares live location,
/// so the tap asks first and names the inviter.
void main() {
  final invite = AppNotificationEntity(
    id: 'n1',
    type: NotificationType.groupRideInvite,
    fromUid: 'stranger',
    fromName: 'Stranger',
    createdAt: DateTime.now(),
    read: true,
    groupRideId: 'G1',
  );

  Future<(_FakeRides, List<String>, ProviderContainer)> pump(
      WidgetTester tester) async {
    final rides = _FakeRides();
    final landed = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/group-ride/:id',
          builder: (_, s) {
            landed.add(s.pathParameters['id']!);
            return const Scaffold();
          }),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_FakeUser()),
        notificationsProvider.overrideWith((ref) => Stream.value([invite])),
        groupRideRepositoryProvider.overrideWithValue(rides),
        notificationRepositoryProvider.overrideWithValue(_FakeNotifications()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsScreen)));
    return (rides, landed, container);
  }

  testWidgets('tapping an invite asks first; Cancel joins nothing',
      (tester) async {
    final (rides, landed, container) = await pump(tester);

    await tester.tap(find.text('Stranger invited you to ride together'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text("Join Stranger's ride?"), findsOneWidget);
    expect(find.textContaining('live location'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(rides.accepted, isEmpty);
    expect(landed, isEmpty);
    expect(container.read(groupRideLocationConsentProvider), isEmpty);
  });

  testWidgets('Join accepts, records location consent and opens the map',
      (tester) async {
    final (rides, landed, container) = await pump(tester);

    await tester.tap(find.text('Stranger invited you to ride together'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Join'));
    await tester.pumpAndSettle();

    expect(rides.accepted, ['G1']);
    expect(landed, ['G1']);
    expect(container.read(groupRideLocationConsentProvider), {'G1'});
  });
}
