import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/jam_label_entity.dart';

/// Writes beta jam labels to `users/{uid}/rides/{rideId}/jamLabels/{id}`.
///
/// Straight to Firestore rather than through SQLite + the outbox: this is
/// internal-only research data for a couple of beta testers, and the
/// Firestore SDK's own offline persistence already queues the write on disk
/// until there's signal. Sitting under the ride doc (whose id is the local
/// ride id — see CloudRepository.uploadRides) keeps each label next to the
/// ride's `track` chunks it will be analysed against; a `jamLabels`
/// collection-group query pulls every label across riders.
///
/// Writes are fire-and-forget: a Firestore write future only completes on
/// server ack, and the ride screen must never wait on the network.
class JamLabelRepository {
  JamLabelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  void save(String uid, JamLabel label) {
    _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .doc(label.rideId)
        .collection('jamLabels')
        .doc(label.id)
        .set({
      ...label.toMap(),
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('JamLabelRepository: save ${label.id} failed: $e');
    });
  }
}
