import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/error_reporter.dart';

/// Parses each doc of a list every rider reads (the social feed, comments,
/// All People, the forum feeds) with [parse], dropping a doc that throws and
/// reporting it once under [where]. Any account can write into those lists,
/// so one malformed doc must cost only itself, never the whole page.
List<T> parseEachDoc<T, D extends DocumentSnapshot<Map<String, dynamic>>>(
  Iterable<D> docs,
  T Function(D doc) parse, {
  required String where,
}) {
  final out = <T>[];
  for (final doc in docs) {
    try {
      out.add(parse(doc));
    } catch (e, st) {
      reportSilently(e, st, where: where, onceKey: doc.reference.path);
    }
  }
  return out;
}
