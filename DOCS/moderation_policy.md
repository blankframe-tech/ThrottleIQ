# Moderation policy and admin runbook

Owner decision 2026-10-21: reports plus manual admin review, with a written
response time. This meets Apple guideline 1.2 and Google Play's UGC policy
(report, block, timely action).

- **Rider-facing rules:** `public/community.html`, hosted at
  `https://throttleiqfb.web.app/community.html`. The in-app report sheet links
  to it (`kCommunityRulesUrl` in
  `app/lib/features/moderation/presentation/widgets/report_bottom_sheet.dart`).
  Change the rules there, not here.
- **Response time: first review within 24 hours** of the report's
  `createdAt`. The app shows this in the report sheet (`reportReviewPromise`
  in the ARBs). If you change it, change all three: this file, the page and
  the two ARB strings.

## Summary of the policy

| | |
|---|---|
| Not allowed | Harassment and threats, hate speech, sexual content (any involving a minor goes to the authorities), doxxing, spam/scams/impersonation, encouraging self-harm or street racing, illegal content. |
| How riders report | Long-press a chat message; profile ⋮ → Report User (in a chat, tap the name at the top); ⋮ on a forum post or shared ride. |
| Block | Profile ⋮ → Block User. Unblock in Settings → Privacy & Safety. |
| Review | A person reads every report within 24 hours. The reported rider is never told who reported. |
| Actions | none, warn, remove content, suspend (default 7 days), ban. Threats, sexual content involving a minor, or a repeat after a suspension: ban. |
| Appeals | hello@blankframe.tech |

## Where reports live

Collection `reports/{autoId}`. Riders can only create (`firestore.rules`,
`match /reports/{reportId}`); only the admin reads and updates them. Fields
written by the app (`ReportModel.toFirestore`):

| Field | Meaning |
|---|---|
| `reporterId` | uid of the rider who reported, or `system` for the automatic filter |
| `reportedId` | uid of the rider reported |
| `contentType` | `chat`, `post`, `ride` or `user` |
| `contentId` | `chat`: `chats/{chatId}/messages/{messageId}`; `post`: `forums/{forumId}/posts/{postId}`; `ride`: id in `rides/`; `user`: the uid. Builds before this change sent only the bare message or post id. |
| `reason` | One of the English reasons in the report sheet |
| `additionalDetails` | Optional free text, up to 2000 characters |
| `createdAt` | Server time; the 24-hour clock starts here |
| `status` | Always `pending` when filed |
| `snapshot` | `chat` only, builds from 2026-10-21 on: `{text, senderId, sentAt}`, a copy of the reported message. The rules accept it only if it equals the stored message and the reporter is in that chat, so it is not the reporter's word. It stays when the sender's message or account goes. Missing on old builds, or if the copy couldn't be read. |

`functions/src/chat-moderation.ts` (`onMessageCreate`, **not deployed**) also
files `system` reports with `chatId`, `contentPath` and `originalText`. Before
you deploy it, add the automatic filter to `public/privacy.html` (the DM row
says only reported messages are read).

## Runbook

### 1. Check for new reports (at least once a day)

There is no alert: no mail provider is set up and Cloud Functions need Blaze.
Firebase console → Firestore → Data → `reports` → **Filter**: `status` `==`
`pending`. The list is every report still waiting. Open each one and look at
`createdAt`: anything older than 24 hours has missed the promise; do it first.

Your account needs the `admin` custom claim (`scripts/set_admin_claim.js`)
only for the app; the console works with your Google login.

### 2. Review

1. For a chat report, read `snapshot` first: it is what the message said
   when it was reported. Then open the content by `contentId` (paste the path
   into the console's path bar). For an old-build `chat` report with a bare message id, the chat id is
   the two uids sorted and joined with `_` (`ChatRepository.dmId`), so
   `chats/{smallerUid}_{largerUid}/messages/{messageId}`.
2. For chat, read the messages just before and after the reported one, and
   nothing else in that conversation.
3. Open `users/{reportedId}` and earlier reports against the same rider
   (filter `reportedId` `==` the uid) to see if it is a repeat.
4. Decide against the rules on `public/community.html`. If the content is
   already gone (deleted or account erased), decide on what the report says
   and the rider's history.

### 3. Act

| Action | How |
|---|---|
| No action | Nothing; record it (step 4). |
| Warn | Email the rider from hello@blankframe.tech. Their address is in `users/{uid}/private/account`. Quote the rule, not the reporter. |
| Remove content | Delete the document in the console: the message, `forums/{f}/posts/{p}`, or `rides/{id}`. For a profile photo or name, edit `users/{uid}`. |
| Suspend | Authentication → Users → the uid → ⋮ → **Disable account**. Note the end date in the report. Re-enable it on that date. Their current session can last up to an hour (ID token lifetime). |
| Ban | Disable the account and leave it disabled. Remove the offending content. Report sexual content involving a minor to the authorities; do not delete it before you have reported it. |

### 4. Record the outcome

Edit the report document in the console:

| Field | Value |
|---|---|
| `status` | `actioned` (something was done) or `dismissed` (no violation) |
| `action` | `none`, `warn`, `remove`, `suspend` or `ban` |
| `reviewedAt` | timestamp of the review (type **timestamp**, not string: the snapshot retention below counts from it) |
| `reviewedBy` | your name or email |
| `note` | one line: what you saw and why; suspension end date |

The app ignores these fields. They are the audit trail if a store reviewer or
an appeal asks what happened. Keep resolved reports; the time between
`createdAt` and `reviewedAt` is the response-time record.

### 5. Retention of the message copy

Default **180 days after review** (`reviewedAt`), set 2026-10-21; the owner
can change it. Then `snapshot` is removed and the rest of the report stays
as the audit trail. A report still `pending` keeps it. Account deletion does
not remove the snapshot from reports about the deleted rider (evidence);
it blanks `reportedId` and `originalText` as before
(`functions/src/account-erasure.ts`). Reports the rider filed: the function
leaves them, the manual runbook deletes them (open owner decision).

`purgeReportSnapshots` (`functions/src/report-retention.ts`) does this daily
once deployed (Blaze). Until then, do it by hand monthly: filter `reviewedAt`
`<` 180 days ago, delete the `snapshot` field. To change the period, change
`REPORT_SNAPSHOT_RETENTION_DAYS`, this section and `public/privacy.html` §8.

### 6. Appeals

Appeals arrive at hello@blankframe.tech. Reread the content and the report
note, answer within 7 days, and record the result in the same report's
`note`.

## Gaps left on purpose

- No alert on a new report. Upgrade path: a Firestore-triggered function on
  `reports/{id}` that emails hello@blankframe.tech; needs Blaze and a mail
  provider secret (none in the repo today).
- No dedupe: one rider can file many reports on the same thing.
- Only chat reports carry a message copy. Forum posts, rides and profiles
  are reviewed from the live document, so their author's edit or deletion
  still removes the evidence.
- Reporting does not block. Riders do both from the profile menu.
