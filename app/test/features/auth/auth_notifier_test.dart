import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';

/// issues §101.A1 (re-auth on delete) and §101.A2 (revoke live share before
/// the uid disappears at sign-out).
class _FakeUser extends Fake implements User {
  _FakeUser({this.deleteError});

  final FirebaseAuthException? deleteError;
  final List<String> providers = const ['password'];
  final List<String> log = [];
  AuthCredential? reauthCredential;

  @override
  String get uid => 'u1';
  @override
  String? get email => 'rider@example.com';
  @override
  List<UserInfo> get providerData => [for (final p in providers) _FakeInfo(p)];

  @override
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential) async {
    log.add('reauth');
    reauthCredential = credential;
    return _FakeCred();
  }

  @override
  Future<void> delete() async {
    log.add('delete');
    if (deleteError != null && reauthCredential == null) throw deleteError!;
  }
}

class _FakeCred extends Fake implements UserCredential {}

/// An email/password user for CrtiQue_Oct15 N3: reload() picks up a click
/// on the verification link when [clickedLink] is set.
class _VerifyUser extends Fake implements User {
  _VerifyUser({this.verified = false, this.clickedLink = false});
  bool verified;
  final bool clickedLink;
  final List<String> log = [];

  @override
  String get uid => 'u1';
  @override
  String? get email => 'rider@example.com';
  @override
  bool get emailVerified => verified;
  @override
  Future<void> reload() async {
    log.add('reload');
    if (clickedLink) verified = true;
  }

  @override
  Future<void> sendEmailVerification(
      [ActionCodeSettings? actionCodeSettings]) async {
    log.add('sendVerification');
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    log.add('getIdToken($forceRefresh)');
    return 'token';
  }
}

class _FakeInfo extends Fake implements UserInfo {
  _FakeInfo(this._id);
  final String _id;
  @override
  String get providerId => _id;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this._user, this.events);
  final User? _user;
  final List<String> events;
  @override
  User? get currentUser => _user;
  @override
  Future<void> signOut() async => events.add('authSignOut');
}

void main() {
  group('completeEmailVerification (Oct15 N3)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('an unverified rider gets the link once, not on every start',
        () async {
      final user = _VerifyUser();
      final n = AuthNotifier(_FakeAuth(user, []));
      await n.completeEmailVerification();
      await n.completeEmailVerification();
      expect(user.log, ['reload', 'sendVerification', 'reload']);
    });

    test('after the click, the token is refreshed before the lookup write',
        () async {
      final user = _VerifyUser(clickedLink: true);
      final n = AuthNotifier(_FakeAuth(user, []));
      // ensureProfile then fails without Firebase; the step never throws.
      await n.completeEmailVerification();
      expect(user.log, ['reload', 'getIdToken(true)']);
    });

    test('a verified rider costs nothing', () async {
      final user = _VerifyUser(verified: true);
      await AuthNotifier(_FakeAuth(user, [])).completeEmailVerification();
      expect(user.log, isEmpty);
    });
  });

  group('signOut pre-sign-out hook (A2)', () {
    test('runs while still signed in, before FirebaseAuth.signOut', () async {
      final events = <String>[];
      final n = AuthNotifier(_FakeAuth(_FakeUser(), events),
          beforeSignOut: () async => events.add('revokeLiveShare'));
      await n.signOut();
      expect(events, ['revokeLiveShare', 'authSignOut']);
    });

    test('a failing hook never blocks sign-out', () async {
      final events = <String>[];
      final n = AuthNotifier(_FakeAuth(_FakeUser(), events),
          beforeSignOut: () async => throw Exception('rtdb down'));
      await n.signOut();
      expect(events, ['authSignOut']);
    });

    testWidgets('a hanging hook is abandoned after the timeout (offline phone)',
        (tester) async {
      final events = <String>[];
      final n = AuthNotifier(_FakeAuth(_FakeUser(), events),
          beforeSignOut: () => Completer<void>().future);
      unawaited(n.signOut());
      await tester.pump(const Duration(seconds: 1));
      expect(events, isEmpty); // still waiting on the hook
      await tester.pump(AuthNotifier.beforeSignOutTimeout);
      await tester.pump();
      expect(events, ['authSignOut']);
    });
  });

  group('deleteAccount / reauthenticate (A1)', () {
    FirebaseAuthException needsLogin() =>
        FirebaseAuthException(code: 'requires-recent-login');

    test('requires-recent-login is rethrown for the UI to handle', () async {
      final user = _FakeUser(deleteError: needsLogin());
      final n = AuthNotifier(_FakeAuth(user, []));
      await expectLater(
        n.deleteAccount(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'requires-recent-login')),
      );
      expect(user.log, ['delete']);
    });

    test('reauthenticate(password) then retry delete succeeds', () async {
      final user = _FakeUser(deleteError: needsLogin());
      final n = AuthNotifier(_FakeAuth(user, []));
      await expectLater(
          n.deleteAccount(), throwsA(isA<FirebaseAuthException>()));
      expect(await n.reauthenticate(password: 'hunter2'), isTrue);
      expect(user.reauthCredential, isA<EmailAuthCredential>());
      await n.deleteAccount();
      expect(user.log, ['delete', 'reauth', 'delete']);
    });

    test('reauthenticate without a password for an email user throws',
        () async {
      final user = _FakeUser();
      final n = AuthNotifier(_FakeAuth(user, []));
      await expectLater(
          n.reauthenticate(), throwsA(isA<FirebaseAuthException>()));
      expect(user.log, isEmpty);
    });
  });
}
