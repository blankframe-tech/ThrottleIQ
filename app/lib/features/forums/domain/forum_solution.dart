import 'entities/forum_post_entity.dart';
import 'entities/forum_reply_entity.dart';

/// Solved-state rules for troubleshooting posts. Pure, so the UI and the
/// tests agree on them; firestore.rules enforces the same shape
/// independently (author only, troubleshoot posts only, a solution reply
/// must exist).

/// Only the post's author may mark it solved or accept a reply, and only on
/// a [ForumPostType.troubleshoot] post.
bool canMarkSolution(ForumPostEntity post, String? uid) =>
    uid != null && post.userId == uid && post.isTroubleshoot;

/// The solved state after the author taps "Accept as solution" on
/// [replyId]: accepting the already-accepted reply un-accepts it (and
/// reopens the post); accepting any other reply moves the solution there.
({bool isSolved, String? solutionReplyId}) toggleAcceptedReply(
  ForumPostEntity post,
  String replyId,
) {
  if (post.solutionReplyId == replyId) {
    return (isSolved: false, solutionReplyId: null);
  }
  return (isSolved: true, solutionReplyId: replyId);
}

/// The solved state after the author taps "Mark solved" / "Reopen" on the
/// post itself. Reopening also drops any accepted reply — a reopened post
/// with a highlighted "solution" would contradict itself.
({bool isSolved, String? solutionReplyId}) toggleSolvedFlag(ForumPostEntity post) {
  if (post.isSolved) return (isSolved: false, solutionReplyId: null);
  return (isSolved: true, solutionReplyId: post.solutionReplyId);
}

/// [replies] with the accepted solution (if it still exists) moved to the
/// front, the rest left in their original (oldest-first) order.
List<ForumReplyEntity> orderRepliesWithSolutionFirst(
  List<ForumReplyEntity> replies,
  String? solutionReplyId,
) {
  if (solutionReplyId == null) return replies;
  final solution = replies.where((r) => r.id == solutionReplyId).firstOrNull;
  if (solution == null) return replies;
  return [solution, for (final r in replies) if (r.id != solutionReplyId) r];
}
