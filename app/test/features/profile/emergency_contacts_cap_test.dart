import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/presentation/providers/emergency_contacts_provider.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// issues §123 C5: the crash-alert function texts only the first 5 contacts.
void main() {
  test('the sixth contact is refused and nothing is written', () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection('users').doc('u').collection('emergencyContacts');
    for (var i = 0; i < maxEmergencyContacts - 1; i++) {
      await col.add({
        'name': 'c$i',
        'phone': '01$i',
        'email': null,
        'createdAt': Timestamp.now(),
      });
    }
    final n = EmergencyContactsNotifier('u', db);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await n.addContact(name: 'fifth', phone: '015'), isTrue);
    expect(await n.addContact(name: 'sixth', phone: '016'), isFalse);
    expect((await col.get()).docs.length, maxEmergencyContacts);
  });

  test('new strings render their arguments', () {
    final en = AppLocalizationsEn();
    expect(en.emergencyContactsLimitReached(5), contains('5'));
    expect(en.liveGroupRideCardSemantics('Dhaka', 3), contains('Dhaka'));
  });
}
