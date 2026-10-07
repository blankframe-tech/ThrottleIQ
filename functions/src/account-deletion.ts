import * as functionsV1 from "firebase-functions/v1";
import { getFirestore } from "firebase-admin/firestore";
import { deleteUserData } from "./account-erasure";

/**
 * Cleans up a rider's Firestore profile once their Firebase Auth account is
 * actually gone.
 *
 * issues §62 (follow-up audit): `AuthNotifier.deleteAccount()` used
 * to delete the Firestore profile + username claim from the CLIENT, then
 * wipe every local SQLite record, and only THEN attempt `user.delete()` —
 * the one step most likely to fail (`FirebaseAuthException` with
 * `'requires-recent-login'`, which fires whenever the session is more than
 * ~5 minutes old, describing almost any real "open Settings and delete my
 * account" flow). That failure was silently swallowed by `AsyncValue.guard`
 * (it stores the error in `state` but doesn't rethrow), so the app already
 * destroyed the Firestore profile and all local ride/bike/maintenance
 * history, then reported success and navigated to the login screen, while
 * the Auth account — now with no error surfaced — was left intact and able
 * to sign back in to what looks like a normal, empty account.
 *
 * The client fix (auth_provider.dart) now deletes the Auth account FIRST —
 * if that fails, nothing else has been touched — and only wipes local data
 * once it succeeds. But once `user.delete()` succeeds the client is no
 * longer authenticated as that uid, and firestore.rules requires exactly
 * that to delete `users/{uid}`/`usernames/{handle}` — so the client
 * structurally cannot reliably clean those up itself anymore. This trigger
 * takes over that job server-side, with Admin SDK privileges (which bypass
 * firestore.rules entirely), running exactly when — and only when — the
 * Auth account is actually deleted, regardless of what the client's own
 * connectivity/timing looked like.
 *
 * Uses the v1 `functions.auth.user().onDelete()` trigger rather than a v2
 * blocking `identity` function deliberately: it needs no Identity Platform
 * upgrade (a project-level change this pass has no way to make or verify),
 * and "clean up after the fact" is exactly this trigger's designed purpose.
 *
 * Community content the rider authored inside other people's spaces — forum
 * posts and replies, place reviews, places they contributed, comments on other
 * riders' rides — is ANONYMIZED rather than deleted (product decision,
 * 2026-09-20, issues §83.15): the identifying fields are cleared and the body
 * is kept, so a forum thread other riders are mid-conversation in doesn't grow
 * holes and a POI nobody else can re-add doesn't vanish from the directory.
 * That erases the personal data while leaving the community artefact, which is
 * the same trade Reddit and Discourse make.
 *
 * Group rides (issues §101.S4): on someone else's ride the rider is removed
 * the way the client's leaveGroupRide does it (roster row, invitation, live
 * location, memberIds/invitedIds); a ride they created is ENDED, not deleted,
 * because other riders are in it. Their forum follows are deleted and the
 * forums' followerCount decremented. Their RTDB nodes (live_shares tokens,
 * group_rides locations, chat_presence) are removed too.
 *
 * Every step's outcome is recorded at `accountDeletions/{uid}`
 * ({completedAt, failedSteps, ok, rtdbSkipped}), so a partial erasure is
 * visible after the fact and not only in the logs.
 *
 * Still NOT covered, and still needing a decision: chat messages the rider
 * sent (a 1:1 DM is arguably the other participant's record too).
 *
 * The body lives in account-erasure.ts (`deleteUserData`) so the emulator
 * suite in test/emulator/ can run it directly.
 *
 * NOT yet deployed by this pass — requires `firebase deploy --only
 * functions` before it actually runs. Until deployed, a successful account
 * deletion leaves the Firestore profile/username claim orphaned (a lesser,
 * non-destructive regression versus the CRITICAL bug this fixes — the
 * rider's own data is gone either way once they've confirmed deletion, and
 * an orphaned profile doc is a cleanup gap, not a false "your data is
 * gone" that turned out to be true only for the parts that didn't need to
 * be).
 */
export const onUserAccountDeleted = functionsV1.auth.user().onDelete(async (user) => {
  await deleteUserData(getFirestore(), user.uid);
});
