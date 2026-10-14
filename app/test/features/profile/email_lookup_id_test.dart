import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/profile/data/repositories/profile_repository.dart';

/// `emailLookup/{id}` (B2, critique 2026-10-14): the app, firestore.rules
/// (`hashing.sha256(token.email.lower()).toHexString().lower()`), the rules
/// tests and scripts/migrate_emails_private.js must all derive the same id.
void main() {
  test('is the lowercase hex SHA-256 of the lowercased email', () {
    // node -e "require('crypto').createHash('sha256').update('alice@example.com').digest('hex')"
    expect(
      emailLookupId('alice@example.com'),
      'ff8d9819fc0e12bf0d24892e45987e249a28dce836a85cad60e28eaaa8c6d976',
    );
  });

  test('ignores case and surrounding whitespace, as search input may carry',
      () {
    expect(emailLookupId('  Alice@Example.COM '),
        emailLookupId('alice@example.com'));
  });

  test('different addresses get different ids', () {
    expect(emailLookupId('alice@example.com'),
        isNot(emailLookupId('bob@example.com')));
  });
}
