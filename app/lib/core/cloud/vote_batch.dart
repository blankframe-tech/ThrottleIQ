import 'package:cloud_firestore/cloud_firestore.dart';

import 'write_ack.dart';

/// How [castVote] moves a parent's `upvotes`/`downvotes`: the same formula
/// as `voteBumpValid` in firestore.rules. Pressing the rider's [previous]
/// vote again clears it, so the result is one of three shapes: a new vote
/// (+1 on its tally), a toggle off (-1 on it), or a flip (+1 / -1).
Map<String, int> voteTallyDelta(int? previous, int value) {
  final after = previous == value ? null : value;
  final up = (after == 1 ? 1 : 0) - (previous == 1 ? 1 : 0);
  final down = (after == -1 ? 1 : 0) - (previous == -1 ? 1 : 0);
  return {if (up != 0) 'upvotes': up, if (down != 0) 'downvotes': down};
}

/// Casts, flips or clears [uid]'s vote ([value]: 1 up, -1 down) on [parent]
/// (a shared ride or a forum post), writing `votes/{uid}` and the tally in
/// one batch (issue #154).
///
/// Not a transaction: those fail offline and once the Spark quota is spent,
/// while a batch is queued by the SDK and lands later. If the previous vote
/// read here is stale, `voteTallied` in firestore.rules refuses the write,
/// so a tally never miscounts.
Future<void> castVote(
  DocumentReference<Map<String, dynamic>> parent,
  String uid,
  int value,
) async {
  assert(value == 1 || value == -1);
  final voteRef = parent.collection('votes').doc(uid);
  int? previous;
  try {
    previous = (await voteRef.get()).data()?['value'] as int?;
  } on FirebaseException catch (e) {
    // Offline with the vote doc not cached, or reads spent: assume no vote;
    // the rules refuse the write if that guess is wrong.
    if (e.code != 'unavailable' && e.code != 'resource-exhausted') rethrow;
  }

  final batch = parent.firestore.batch();
  if (previous == value) {
    batch.delete(voteRef);
  } else {
    batch.set(voteRef, {'value': value, 'uid': uid});
  }
  batch.update(parent, {
    for (final e in voteTallyDelta(previous, value).entries)
      e.key: FieldValue.increment(e.value),
  });
  await ackOrQueued(batch.commit());
}
