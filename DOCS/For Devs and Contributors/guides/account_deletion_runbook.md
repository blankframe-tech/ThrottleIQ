# Account deletion runbook (manual, owner only)

_Written 2026-10-14 (critique `CrtiQue_Oct14.md` B1)._

**Why this is manual:** the project is on the Spark plan, so the
`onUserAccountDeleted` trigger (`functions/src/account-erasure.ts`) never
deploys. In-app "Delete account" removes only the Firebase Auth user, the
phone's SQLite data and the Google session. Every cloud record stays until
you delete it by hand. The privacy page (§9) and the in-app delete dialog both
promise this: **cloud data is deleted by hand within 30 days of the request.**
Retire this runbook once the trigger is live on Blaze with the three
`userId` collection-group index overrides (posts, replies, comments).

## 1. Take the request

- Requests arrive at **hello@blankframe.tech**, from the address the rider
  signed up with. That match is the identity check. If the address does not
  match any account, reply and ask them to write from their signup address.
- Log the request in a **private** list outside this repo (the repo is
  public): date received, uid, deadline (received + 30 days), date done.
- Reply the same week to confirm receipt.

## 2. Find the uid

1. Firebase console → Authentication → search the email. The uid is in the
   "User UID" column.
2. If the rider already deleted the account in the app, Auth has no record.
   Look in Firestore → `users` for a doc whose `email` field matches (after
   the B2 fix, look where the email moved to), or ask the rider for their
   username and read `usernames/{handle}.uid`.
3. Before deleting anything, note the profile's `username` and open
   `users/{uid}/cloudinaryAssets`: copy every `publicId`. Both are gone once
   the profile is deleted.

**Monthly sweep (recommended):** riders can delete in the app without
emailing. Once a month, list `users` doc ids that have no Auth user (Admin
SDK `getUsers` in batches of 100, or compare against an Auth export) and
treat each one as a request received on the sweep date.

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
| `livePointers/{uid}` | Pointer to the current live session |
| `crashNotifications` where `uid == uid` | Crash alert records |
| `follows` where `followerUid == uid`, and where `followeeUid == uid` | Follow edges both ways |
| `forum_follows` where `userId == uid` | Forum follows; take 1 off `forums/{forumId}.followerCount` for each |
| `chats` where `participants` array-contains `uid` (recursive) | Direct messages. Default: delete the whole thread with its `messages`; the other rider loses a thread with an account that no longer exists |
| Collection group `likes` and `votes`, doc id `== uid` | The rider's likes and votes on other riders' shared rides; adjust that ride's like/vote counter |
| `reports` where `reporterId == uid`, and where `reportedId == uid` | Moderation reports filed by or about the rider |
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

**Cloudinary:** delete every `publicId` copied in step 2.3 (Media Library,
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
