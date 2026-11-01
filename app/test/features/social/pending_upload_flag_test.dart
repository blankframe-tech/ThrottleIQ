import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/forums/data/models/forum_post_model.dart';
import 'package:throttleiq/features/forums/data/models/forum_reply_model.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';

/// Issue #158: a ride comment, forum post or reply still queued on this phone
/// carries Firestore's `hasPendingWrites` into its entity, so the UI can say
/// "Waiting to upload". fake_cloud_firestore always reports false, hence the
/// hand-made snapshots.
class _Meta extends Fake implements SnapshotMetadata {
  _Meta(this.hasPendingWrites);
  @override
  final bool hasPendingWrites;
}

// Test-only stand-in: the SDK has no public constructor for a snapshot with
// pending writes, and fake_cloud_firestore always reports none.
// ignore: subtype_of_sealed_class
class _Doc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data, {required bool pending})
      : metadata = _Meta(pending);
  @override
  final String id;
  final Map<String, dynamic> _data;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic> data() => _data;
}

void main() {
  final fields = <String, dynamic>{
    'userId': 'u1',
    'userName': 'Rider',
    'userPhotoUrl': '',
    'text': 'nice ride',
    'title': 't',
    'body': 'b',
    'postId': 'p1',
    'forumId': 'f1',
    'createdAt': null, // a queued write has no server time yet
  };

  for (final pending in [true, false]) {
    test('comment, post and reply mappers carry hasPendingWrites=$pending', () {
      final doc = _Doc('d1', fields, pending: pending);

      expect(RideShareRepository.commentFromDoc('r1', doc).hasPendingWrites,
          pending);
      expect(ForumPostModel.fromFirestore(doc).toEntity().hasPendingWrites,
          pending);
      expect(ForumReplyModel.fromFirestore(doc).toEntity().hasPendingWrites,
          pending);
    });
  }

  test('copyWith keeps the flag (vote hydration must not drop it)', () {
    final post = ForumPostModel.fromFirestore(_Doc('d1', fields, pending: true))
        .toEntity()
        .copyWith(myVote: 1);
    expect(post.hasPendingWrites, isTrue);
  });
}
