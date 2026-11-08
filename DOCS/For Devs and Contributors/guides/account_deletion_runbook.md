# Account deletion runbook (manual, owner only)

_Written 2026-10-14 (critique `CrtiQue_Oct14.md` B1). Identity check changed
2026-11-08: a code sent to the account's own address, not the sender's._

**Why this is manual:** the project is on the Spark plan, so the
`onUserAccountDeleted` trigger (`functions/src/account-erasure.ts`) never
deploys. In-app "Delete account" removes only the Firebase Auth user, the
phone's SQLite data and the Google session. Every cloud record stays until
you delete it by hand. The privacy page (§9) and the in-app delete dialog both
promise this: **cloud data is deleted by hand within 30 days of the request.**
Retire this runbook once the trigger is live on Blaze with the three
`userId` collection-group index overrides (posts, replies, comments).

## 1. Take the request

- Requests arrive at **hello@blankframe.tech**. The sender's address is
  **not** proof of identity: a From header can be forged, and a username is
  public. Never delete on the strength of the From address or a username.
- Log the request in a **private** list outside this repo (the repo is
  public): date received, uid, confirmation code, date confirmed, deadline
  (confirmed + 30 days), date done.
- Reply the same week to confirm receipt, and send the confirmation in step 2.

## 2. Find the uid and confirm with the account's own mailbox

1. Find the uid from the address in the request: Firebase console →
   Authentication → search the email ("User UID" column). If Auth has no
   record, read `emailLookup/{sha256(lowercased email)}` → `uid` (only
   verified addresses have one). If the request gives only a username,
   `usernames/{handle}.uid` tells you which account to write to, nothing
   more: a username is never enough to act on.
2. Read the account's stored address: the Auth user's email, or, if Auth has
   no user for that uid, `users/{uid}/private/account`. That is the only
   address the confirmation goes to, even when the request came from
   somewhere else. If neither holds an address, do not delete on request;
   the rider can delete in the app (it asks them to sign in again) and the
   monthly sweep below picks the data up.
3. Send a confirmation to that stored address, as a **new** email (not a
   reply to the request, which goes to the From address). Include a random
   single-use code (`openssl rand -hex 4`), the account's username, and
   "Reply with this code to confirm the deletion. If you did not ask for
   this, ignore this email and nothing will be deleted." Log the code.
4. Act only on a reply written from the stored address that carries that
   exact code: only that mailbox received the code. A bounce, delivery
   notice or auto-reply that quotes the code is not a confirmation; neither
   is a reply without the code, whatever its From address says, nor a reply
   with the code from any other address. In those cases send a new code to
   the stored address. If no valid reply arrives within 14 days, close the
   request without deleting anything.
5. Before deleting anything, note the profile's `username` and open
   `users/{uid}/cloudinaryAssets`: copy every `publicId`. Both are gone once
   the profile is deleted.

**Already deleted in the app:** that path signed the rider in again, so an
orphaned `users/{uid}` doc (no Auth user for that uid, checked with Admin SDK
`getUser` or the console) needs no email confirmation. A request that only
*claims* the app account is gone still goes through steps 2.2 to 2.4: check
Auth yourself and confirm with `users/{uid}/private/account`.

**Monthly sweep (required until the trigger is live):** riders can delete
in the app without emailing, and nothing else finds those accounts. On the
**1st of every month** (the next working day if you are away; put it in your
calendar as a repeating event), list `users` doc ids that have no Auth user
(Admin SDK `getUsers` in batches of 100, or compare against an Auth export)
and treat each one as a request received on the sweep date. Record every
run in the same private list as the requests, even when it finds nothing:
sweep date, number of orphaned uids found, date each was finished.

## 3. Delete

Use `npx firebase-tools@15 firestore:delete --recursive <path>` for anything
with subcollections (a plain console delete leaves subcollections behind).
Filters below are console query-builder filters.

**Firestore, delete outright**

| Path | What it holds |
|---|---|
| `users/{uid}` (recursive) | Profile, email, and the subcollections `rides` (with `track` GPS points and `jamLabels`), `bikes`, `maintenance`, `fuelLogs`, `emergencyContacts` (third-party phone numbers), `private`, `cloudinaryAssets`, `routes`, `falseCrashPositives`, `earnedBadges`, `notifications`, `blocks`, `challengeProgress` (old builds) |
| `usernames/{handle}` | Username reservation (handle = lowercased username) |
| `rides` where `userId == uid` (recursive) | Shared feed rides with their `likes`, `votes`, `comments` |
| `liveSessions` where `uid == uid` | Live-share sessions (note each doc id: it is the RTDB token) |
| `livePointers/{uid}` | Pointer to the current live session (legacy, owner-only) |
| `handleLinks/{hash}` (where `uid` matches) | Password `/r/@handle` link: current session + last known location |
| `crashNotifications` where `uid == uid` | Crash alert records |
| `follows` where `followerUid == uid`, and where `followeeUid == uid` | Follow edges both ways |
| `forum_follows` where `userId == uid` | Forum follows; take 1 off `forums/{forumId}.followerCount` for each |
| Collection group `likes` and `votes`, doc id `== uid` | The rider's likes and votes on other riders' shared rides; adjust that ride's like/vote counter |
| `reports` where `reporterId == uid` | Moderation reports the rider filed |
| `groupRides/{id}/members/{uid}`, `memberLocations/{uid}`, `invitations/{uid}` | For every group ride where `memberIds` or `invitedIds` contains `uid`; also remove `uid` from those arrays |
| `groupRides/{id}/voiceNotes` where `senderId == uid` | Push-to-talk clips (the audio is on Cloudinary, below) |
| `groupRides` where `creatorId == uid` | End it (`status: 'ended'`) if other riders are in it, otherwise delete it (recursive) and its `groupRideJoinCodes/{code}` |

**Firestore, anonymise unless the rider asked for deletion**

Set `userId: ""`, `userName: "Deleted rider"`, `userPhotoUrl: ""` (the same
tombstone the function writes), or delete the doc if the email asks for it:

| Path | Filter |
|---|---|
| Collection group `posts` (forum posts) | `userId == uid` |
| Collection group `replies` (forum replies) | `userId == uid` |
| Collection group `comments` (ride comments) | `userId == uid` |
| `reviews` | `userId == uid` → set `userId: ""` |
| `places` | `createdBy == uid` → set `createdBy: ""` |
| `reports` | `reportedId == uid` (any `contentType`). Still `pending` (or no `status`): change nothing but set `reportedAccountDeleted: true`, even if the rider asked for deletion: evidence, kept until review. Closed (`actioned`/`dismissed`): set `reportedId: ""`, `originalText: ""`, `snapshot.senderId: "deleted-rider"`; the copied text goes 90 days after review (owner decision 2026-10-21, `DOCS/General/Files for Stores/moderation_policy.md` §5) |
| `chats` | `participants` array-contains `uid` → in `participants` and `lastMessage.senderId` replace `uid` with `deleted-rider`; remove `participantNames.<uid>` / `participantPhotos.<uid>`; in `messages` where `senderId == uid` set `senderId: "deleted-rider"`, `text: ""`. If no real uid is left in `participants`, delete the chat (recursive). Owner decision 2026-10-21: the other rider keeps the thread; the rider's text is always deleted (privacy.html §9), even without a request |

The three collection-group queries need a COLLECTION_GROUP single-field
index on `userId`. Without it the console query fails; add the exemption in
Firestore → Indexes → Single field, or deploy the overrides from
`firestore.indexes.json`.

**Leave alone:** `stats/badges` and `roadSpeedSamples` (counts and anonymous
speed samples, no uid), `forums` themselves, `config/app`.

**Realtime Database:** only if an RTDB instance exists (none as of
2026-10-14). Delete `live_shares/{token}` for each `liveSessions` id noted
above, `chat_presence/{chatId}/{uid}` for each chat, and
`group_rides/{rideId}` (rides they created) or
`group_rides/{rideId}/locations/{uid}` (rides they joined).

**Cloudinary:** delete every `publicId` copied in step 2.5 (Media Library,
or the Admin API with the account key). Public ids follow
`<folder>/<uid>/...`, so also search the Media Library for the uid to catch
uploads missing from the ledger: avatars, bike and ride photos, forum
images, voice clips.

**Firebase Auth:** if the user still exists, delete it (Authentication →
the user's menu → Delete account).

**Nothing to do:** Analytics events are tied to an installation id, not the
account. Crashlytics reports carry no account id.

## 4. Close

- Re-run the step-3 queries; each should return nothing.
- Reply to the rider that deletion is complete, and log the date.
- If anything could not be removed (a photo only the rider can identify,
  say), say so in the reply.
