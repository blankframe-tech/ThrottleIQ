> DRAFT for owner review, 2026-10-22

# Signed Cloudinary uploads: design options

Tracks `issues_open.md` §33.5 (the canonical entry; §63.3 and §83.16 point
to it), §107.3, and architect to-do item 6
(`DOCS/agent_rooms/architect_todo.md`). Nothing here is built. Claims about
the code cite file:line; anything not found in the repo is marked
`[PLACEHOLDER: ...]`.

## 1. How uploads work today

### The one upload path

All uploads go through `CloudinaryUploadService`
(`app/lib/core/services/cloudinary_upload_service.dart`):

- Cloud name `vjvcigkt` and unsigned preset `throttleiq_unsigned` are
  constants in the binary (`:62-63`).
- Images POST to `.../image/upload` (`:64-65`); audio POSTs to
  `.../video/upload` (`:72-73`), because Cloudinary routes audio through the
  `video` resource type (`:67-71`).
- `_post` (`:90-115`) sends `file`, `upload_preset` and `folder` as
  multipart form data with Dio. The client picks `folder`; Cloudinary
  generates the rest of the `public_id`. No fixed `public_id`, no overwrite
  (`:22-26`).
- After a successful upload, `_recordAsset` (`:118-145`) writes a ledger row
  to `users/{uid}/cloudinaryAssets/{docId}` with `publicId`,
  `resourceType`, `folder`, `secureUrl`, `createdAt`. Fire-and-forget: a
  failed ledger write never fails the upload (`:41-45`, `:106-108`).

### Callers and folders (the current "kinds")

| Kind | Folder string | Call site |
|---|---|---|
| `avatars` | `avatars/$uid` | `app/lib/features/profile/data/repositories/profile_repository.dart:336` |
| `bikes` | `bikes/$uid` | `app/lib/features/garage/presentation/screens/add_edit_bike_screen.dart:210`; `app/lib/core/cloud/cloud_repository.dart:364-366` (sync of a local bike photo) |
| `rideShares` | `rideShares/$uid` | `app/lib/features/social/data/repositories/ride_share_repository.dart:37` |
| `places` | `places/$uid` | `app/lib/features/poi_directory/data/repositories/place_repository.dart:31` |
| `forumPhotos` | `forumPhotos/$uid` | `app/lib/features/forums/data/repositories/forum_repository.dart:490` |
| `voiceNotes` (audio) | `voiceNotes/$uid/$groupRideId` | `app/lib/features/social/presentation/screens/group_ride_map_screen.dart:537-543` |

No other upload calls exist in `app/lib`. Each caller builds its own
`CloudinaryUploadService()` (`cloud_repository.dart:39`,
`forum_repository.dart:146`, `ride_share_repository.dart:26`,
`group_ride_map_screen.dart:87`, `profile_repository.dart:33`,
`place_repository.dart:18`, `add_edit_bike_screen.dart:209`), so changing
`_post` changes every path at once. Ride-share photos also go through the
outbox (`app/lib/core/cloud/outbox_service.dart:568`), which treats a
Cloudinary failure as transient and retries (`:93`).

### Where the `<kind>/<uid>/...` convention is already enforced

- Ledger rule: `firestore.rules:623-631`. A row's `publicId` must match
  `^[A-Za-z_]+/<uid>/.+`, contain no `..`, resource type in
  `image|video|raw`; create-only (§90.D2).
- Forum photo URLs: `forumImageUrlValid` (`firestore.rules:292-295`) only
  accepts `.../image/upload/(.*/)?forumPhotos/<uid>/...`.
- Avatar and media hosts: `photoUrlAllowed()` (`firestore.rules:44-51`) and
  its client mirror `app/lib/core/utils/photo_url_policy.dart:5-6` accept only
  `res.cloudinary.com/vjvcigkt/` and Google avatar hosts.
- Server side: `isOwnedPublicId` (`functions/src/cloudinary-ownership.ts:25-38`)
  requires `<kind>/<uid>/<rest>`, kind `^[A-Za-z_]+$`, no `..`, no empty
  segments.

These checks only cover what the app writes to Firestore. Cloudinary itself
accepts any `folder` from anyone holding the preset name, so nothing stops a
third party from uploading into `avatars/<someone-else's-uid>/` or anywhere
else (§33.5).

### Deletion today

- No delete or destroy call exists in `app/lib`. An unsigned preset cannot
  authorize a destroy (`cloudinary_upload_service.dart:28-32`). A replaced
  avatar or photo is orphaned (`:24-26`).
- Account deletion: `destroyCloudinaryAssets`
  (`functions/src/account-erasure.ts:528` onward) reads the ledger, skips any
  row that fails `isOwnedPublicId` (`:563-568`), and destroys the rest with
  `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` from Secret Manager
  (`functions/src/account-deletion.ts:11-12`, `:91-98`). Without credentials
  it records a skip (`account-erasure.ts:551-555`). There is no folder
  sweep; a missed ledger row has to be found by hand (`:522-523`).
- None of this runs yet: Functions have never been deployed (Spark,
  `HANDOFF_Document.md:62`). Setup steps: `SECURITY.md` step 5.

### Current mitigation

`SECURITY.md` step 7: in the Cloudinary console, restrict
`throttleiq_unsigned` to `jpg,jpeg,png,webp,heic,aac,m4a`, 5 MB, no
overwrite, no "use filename", plus a usage alert. Owner item #11, marked
"partly done" in §33.5. [PLACEHOLDER: which of these settings are applied
today.]

## 2. What every signed design shares

1. The app gets a Firebase ID token (`FirebaseAuth.instance.currentUser`).
2. The app asks a signer for permission to upload one asset of a given
   `kind` and resource type.
3. The signer verifies the token, takes `uid` from it (never from the
   request body), checks `kind` against an allow-list, and builds the
   folder or `public_id` itself as `<kind>/<uid>/<asset_id>`.
4. The signer returns the signed parameters (timestamp, folder or
   public_id, signature, API key). The API secret never leaves the signer.
5. The app POSTs the file to Cloudinary with exactly those parameters.
   Changing any signed parameter breaks the signature, so the client cannot
   pick another rider's folder.
6. The ledger write stays as it is.

[PLACEHOLDER: Cloudinary's exact signature algorithm, which parameters must
be signed, and how long a signed timestamp stays valid. Confirm against
Cloudinary's upload API docs before building.]

Change in the app (both options): only `_post` in
`cloudinary_upload_service.dart:90-115` changes. It fetches a signature
first, then sends `signature`, `timestamp`, `api_key` and the signer's
folder or `public_id` instead of `upload_preset`. The seven call sites
already pass `<kind>/<uid>` folders; they would pass `kind` (and, for voice
notes, the group ride id) instead. A signer failure should throw an error
the outbox treats as transient, like a Cloudinary hiccup today.

## 3. Option A: edge signing proxy (no Blaze)

The route `issues_open.md` §107.3 and `backend_options.md` Option B
(`:137-166`) describe: a small function on a free edge platform such as a
Cloudflare Worker.

**Flow.** App → `POST https://<worker>/sign` with
`Authorization: Bearer <ID token>` and `{kind, resourceType, groupRideId?}`
→ the worker verifies the token's signature against Google's public keys,
plus issuer and audience `throttleiqfb` and expiry → returns signed params
→ app uploads to Cloudinary directly.

**App changes.** `_post` as in §2. Dio is already a dependency
(`app/pubspec.yaml:52`); no new package. The worker URL becomes a new
constant or remote config value.

**Secrets.** `CLOUDINARY_API_SECRET` (and the key) stored as worker
secrets on the edge platform. That is a second copy next to Secret Manager
(`SECURITY.md` step 5), and both must change together when the secret
rotates. The worker needs no Firebase service account just to verify ID
tokens. [PLACEHOLDER: confirm the chosen platform's secret storage and
JWT-verification library.]

**Cost.** `backend_options.md:254` puts this route at "~$0 (both
platforms' free tiers)" without figures. [PLACEHOLDER: the edge platform's
free-tier request limits and what happens past them.] Cloudinary's own free
plan: "~25GB/month across storage + bandwidth"
(`cloudinary_upload_service.dart:13-14`), unchanged by either option.

**Risks.**
- New vendor, account and dashboard to own, monitor and keep paid-up; one
  more thing in the privacy policy and data-safety form. [PLACEHOLDER:
  whether `public/privacy.html` must list the edge platform as a processor.]
- Token verification is hand-written or library code on a non-Google
  runtime: a bug there re-opens the endpoint. Needs its own tests.
- No App Check unless the worker also verifies App Check tokens
  (`firebase_app_check` is in `app/pubspec.yaml:166`; enforcement is owner
  items #17 and #32).
- If Blaze comes later, the work is either thrown away or kept as a second
  platform (`backend_options.md:162-166`).

**Migration.**
1. Create the worker and its secrets; deploy; test with a real ID token.
2. Ship an app build whose `_post` signs.
3. Raise `config/app.minBuild` to that build (`SECURITY.md` step 2).
4. Only then stop unsigned uploads: switch `throttleiq_unsigned` to signed
   or disable it. Switching before the build ships breaks every upload
   (`SECURITY.md:107-111`, §33.5). [PLACEHOLDER: whether signed uploads can
   use a new signed preset or no preset, so the unsigned one can stay alive
   during rollout.]
5. Watch the usage alert for unsigned uploads that still arrive.

## 4. Option B: Cloud Function on Blaze

The route §33.5 and `SECURITY.md` step 7 already name as the real fix.

**Flow.** App → callable function (or an HTTPS function with the ID token
in the header) → Firebase checks `request.auth` → function builds
`<kind>/<uid>/<asset_id>`, signs with `CLOUDINARY_API_SECRET` → app uploads
to Cloudinary.

**App changes.** `_post` as in §2. A callable needs the `cloud_functions`
Flutter package, which `app/pubspec.yaml` does not list today; an HTTPS
function with the ID token in a header works with Dio and no new package.
No callable or HTTPS function exists in `functions/src` yet; `index.ts:17-21`
exports only background triggers.

**Secrets.** The same `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET`
Secret Manager entries the deletion sweep already expects
(`functions/src/account-deletion.ts:11-12`, `SECURITY.md` step 5). One copy,
one place to rotate.

**Cost.** Blaze has no base fee (`backend_options.md:60-64`). Cloud
Functions free tier quoted as 2,000,000 invocations/month
(`backend_options.md:115-118`, written 2026-08-23; it says to verify current
rates). One call per upload. `SECURITY.md` step 5 suggests a budget alert
(example $5; alerts do not cap spend). [PLACEHOLDER: monthly upload count
at current rider numbers.]

**Risks.**
- Needs Blaze (owner item #3) and a card on the Google Cloud account.
- Functions have never been deployed on this project; the first deploy
  carries its own setup risk (`architect_todo.md` item 5, Node 22
  readiness).
- Cold starts add latency before an upload. [PLACEHOLDER: measured cold
  start in `asia-south1`.]
- Server-side code fixes nothing until deployed (proposed deploy rule 3,
  `DOCS/agent_rooms/drafts/proposed_deploy_test_rules.md`).

**Migration.** Same five steps as Option A, with the function instead of
the worker. It can ship in the same Blaze rollout as
`onUserAccountDeleted`, which uses the same secrets.

## 5. Public-id convention: `<kind>/<uid>/<asset_id>`

**Kinds that exist today** (§1 table): `avatars`, `bikes`, `rideShares`,
`places`, `forumPhotos` (image) and `voiceNotes` (video/audio). The comments
at `firestore.rules:616-617` and `functions/src/cloudinary-ownership.ts:11-12`
list five kinds and leave out `forumPhotos`. Both regexes still accept it,
so this is a comment fix, not a bug.

**What the signer enforces.**
- `uid` comes only from the verified token. A request naming a different
  uid is not possible; there is no uid field to send.
- `kind` must be one of the six above, with the matching resource type
  (`voiceNotes` → `video`; the rest → `image`). Unknown kind → refuse.
- `asset_id`: generated by the signer (random), or accepted from the client
  only if it matches a tight pattern such as `^[A-Za-z0-9_-]{1,64}$`.
  Voice notes today add a group-ride segment (`voiceNotes/<uid>/<groupRideId>`);
  keep it as `voiceNotes/<uid>/<groupRideId>/<asset_id>`, which
  `isOwnedPublicId` already allows (`parts.slice(2)`,
  `cloudinary-ownership.ts:36`). Whether the signer should also check that
  the rider is a member of that group ride is open (§7).
- The signer could also sign the format and size limits now set on the
  preset. [PLACEHOLDER: whether Cloudinary lets signed parameters carry
  those limits.]

**Ownership-based deletion.**
- Account deletion keeps using the ledger plus `isOwnedPublicId`. Once
  uploads are signed, only the owner can create assets under
  `<kind>/<uid>/`, so a delete-by-prefix sweep over the six kinds for that
  uid becomes safe. It would also catch assets whose ledger row never landed
  (`cloudinary_upload_service.dart:41-45`), closing the gap noted at
  `account-erasure.ts:522-523`. [PLACEHOLDER: Cloudinary's
  delete-by-prefix API and its rate limits.]
- Single-asset deletion (a replaced avatar, a deleted ride photo) could use
  the same signer: it verifies the token, checks the `public_id` starts with
  `<kind>/<uid>/`, and calls destroy itself. Not needed for the first
  version.
- Assets uploaded before the switch keep whatever `public_id` they got.
  Callers already used `<kind>/<uid>`, so they fit the prefix sweep too.
  [PLACEHOLDER: whether anything was uploaded before the `<kind>/<uid>`
  folders became the rule (§90.D2), e.g. old `avatars/` uploads without a
  uid segment. The doc comment at `cloudinary_upload_service.dart:75-76`
  still shows plain `avatars` as an example folder.]

## 6. Recommendation (the agent's, not the owner's)

Option B, shipped together with Blaze. It reuses secrets the deletion sweep
already needs, keeps one vendor and one place to rotate keys, and Blaze
already blocks other work (account deletion, TTL, GPS retention,
`backend_options.md` recommends it). Choose Option A only if Blaze stays off
for months and the preset limits in `SECURITY.md` step 7 turn out not to be
enough. Either way:

- Finish the preset limits and the usage alert now (owner #11).
- Build the signed `_post` behind a switch so it can be tested against the
  real signer before release.
- Do not disable the unsigned preset until the signing build is the
  `minBuild`.
- Set voice-note auto-expiry (§107.3). [PLACEHOLDER: expiry length, and
  whether that is a preset setting, a signed parameter or a scheduled
  delete.]

## 7. Open questions for the owner

1. Blaze: yes, and when (owner #3)? This decides A or B.
2. Which preset limits from `SECURITY.md` step 7 are applied today?
3. If Option A: which edge platform, under whose account, and is a new
   processor acceptable in the privacy policy?
4. Must the signer require App Check, given enforcement is still pending
   (owner #17, #32)?
5. Should voice-note signing check group-ride membership, or is the uid
   prefix enough?
6. Should replaced avatars and photos be deleted (single-asset destroy), or
   keep orphaning them?
7. Voice-note expiry: how long?
8. Any per-rider upload rate limit at the signer (counts per uid per day)?
   §62.12 notes there is no rate limiting anywhere today.

Out of scope: the blocking design half of §107.3 (§83.18).
