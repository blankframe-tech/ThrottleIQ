// Ratchet (issues §83.13): direct FirebaseFirestore.instance / FirebaseAuth.instance
// in lib/ may only shrink. Code with a Ref reads firestoreProvider /
// firebaseAuthProvider / currentUidProvider (core/cloud/firebase_providers.dart).
// What remains: `x ?? .instance` constructor defaults, singleton repositories
// with no Ref, and background/no-container code. Converting one? Lower the
// baseline.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/firebase_providers.dart';

const _directInstanceBaseline = 33;

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  @override
  User? currentUser;
  @override
  Stream<User?> authStateChanges() => changes.stream;
}

void main() {
  test('direct Firebase .instance count in lib/ does not grow', () {
    final pattern = RegExp(r'Firebase(Firestore|Auth)\.instance\b');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('core/cloud/firebase_providers.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (pattern.hasMatch(line)) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_directInstanceBaseline),
      reason: 'New direct .instance. Read firestoreProvider / '
          'firebaseAuthProvider / currentUidProvider instead:\n'
          '${hits.join('\n')}',
    );
  });

  test('currentUidProvider follows sign-in and sign-out', () async {
    final auth = _FakeAuth();
    final container = ProviderContainer(
      overrides: [firebaseAuthProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    final seen = <String?>[];
    container.listen(currentUidProvider, (_, uid) => seen.add(uid),
        fireImmediately: true);

    auth.currentUser = _FakeUser('a');
    auth.changes.add(auth.currentUser);
    await Future<void>.delayed(Duration.zero);
    container.read(currentUidProvider);

    auth.currentUser = null;
    auth.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    container.read(currentUidProvider);

    expect(seen, [null, 'a', null]);
  });
}
