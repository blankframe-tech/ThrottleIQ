> DRAFT for owner review, 2026-10-22

# Badge-tier physical prize: fulfilment SOP (PM item 8)

Idea (`marketing.md` §6): "First to a badge tier wins a maintenance kit". Status: **idea, not built, owner decision pending, do not announce** (`marketing.md` §6, `needs_attention.md` "Smaller calls", throttleiq-marketing skill no-overclaim rule).

## 1. Launch gate

Do not start, tease or announce the promotion until **all** of these are true:

1. **100 active organic riders** (PM item 8). Definition: [PLACEHOLDER: owner to define "active", e.g. recorded at least one ride in the last 7 days; and "organic", e.g. excludes QA-seeded accounts (`scripts/oneoff/seed_qa_test_riders.js`), `BetaTesters` handles (`app/lib/core/constants/beta_testers.dart`), the owner and family]. Measure from Play Console cohorts or the `ride_started` analytics event (`analytics_service.dart`), which riders can switch off, so it under-counts.
2. The eligibility check in section 3 exists as a script and has been run once on a test account.
3. Privacy policy and Data Safety cover collecting a postal address and phone number (section 5).
4. Terms are written and lawyer-reviewed (section 8).
5. Budget is approved (section 7).
6. The Record screen and every asset pass the copy check in section 9.

## 2. Which badge

Badge families and tiers live in `app/lib/core/utils/badges.dart` (Bronze to Diamond; families include first ride, rides, distance, long ride, saddle time, night, early, streak, smooth).

- [PLACEHOLDER: owner picks one family and one tier]
- Prefer a family that takes many separate rides over many days (for example distance or ride count at a higher tier). They are harder to fake than a single long ride or "first ride".
- One prize per family-tier, first verified claimant only. Say in advance what happens if the first claimant fails verification (the next verified claimant wins).

## 3. Eligibility check: what telemetry actually exists

**Badges are not proof on their own.** Earned badges are computed on the phone from local ride history and synced to `users/{uid}/earnedBadges`. The rules only check that the id is in the catalog and that the counter moves with it. `features.md` §3 states it plainly: "riders can award themselves badges". The rider can also write their own `users/{uid}/rides/{rideId}` and `/track/{chunkId}` documents (owner-only read and write in `firestore.rules`), so the ride history can be forged by a determined claimant. The check below raises the cost of faking; it does not make faking impossible.

**Check, from the Firebase console or a read-only Admin SDK script** [PLACEHOLDER: script not written; it should be read-only and run by the owner]:

1. The claimed badge doc exists in `users/{uid}/earnedBadges`, with its earned date.
2. Recompute the badge from `users/{uid}/rides`: sum of distance, ride count, longest ride, etc., against the threshold in `badges.dart`. The synced total must reach it without counting deleted or archived-bike rides twice.
3. Every ride counted has a GPS trail in `/track` chunks. No trail, no credit.
4. Plausibility of each counted ride:
   - Point spacing and speeds consistent with a motorcycle (no teleport jumps, no sustained speeds no 100-160cc bike reaches).
   - Rides spread over separate days and times, not dozens recorded in one evening.
   - Start and end times consistent with the distance.
   - Fields that only the real recorder writes are present where they sync (for example `imu_rate_hz`, `phone_placement`, hard-brake and acceleration event counts) [VERIFY: which of these sync to Firestore].
   - Routes on real roads (spot-check a few on the map).
5. Account checks: email verified; account age before the promotion start date [PLACEHOLDER: minimum age]; not a QA, beta or owner account; no other winning account with the same phone, address or name.
6. Two people sign off: the owner plus [PLACEHOLDER: second reviewer]. Record the decision and reasons in a private log, not in the repo.

## 4. Anti-fraud rules (publish in the terms)

- One prize per person, per phone number, per postal address, across all accounts.
- The organiser can ask for a short call and for a photo of the claimant with their bike and the app open.
- Any sign of edited ride data, shared accounts or GPS spoofing disqualifies the claim. The organiser's decision is final [LAWYER REVIEW].
- Rides recorded before the promotion start date [PLACEHOLDER: count or do not count] toward the badge.
- No prize for badges earned by auto-tracking alone: detected trips go to the daily summary and are not saved as rides (`features.md` §2), so they should not count anyway. Confirm this in the recompute step.

## 5. Address verification and data handling

- **Collect outside the app** (phone call or email to hello@blankframe.tech). The app has no address field and none should be added for this.
- Collect only: recipient name, phone, full address with district, upazila or thana, and a landmark.
- Confirm by a phone call to the same number before dispatch. The name should match the account's display name or the claimant explains why not.
- **Privacy gap:** `public/privacy.html` does not mention postal addresses, prizes or promotions. Add a section and update the Data Safety form (Personal info → Address, Phone number) before collecting anything [LAWYER REVIEW].
- Keep the address only until delivery is confirmed plus [PLACEHOLDER: number of days] for disputes, then delete it. Never store it in Firestore or the repo.

## 6. Courier logistics (Bangladesh)

No courier is named or priced anywhere in the repo.

| Item | Value |
|---|---|
| Courier | [PLACEHOLDER: BD courier name(s), with a Dhaka and an outside-Dhaka option] |
| Price per parcel, inside Dhaka | [PLACEHOLDER: quote] |
| Price per parcel, outside Dhaka | [PLACEHOLDER: quote] |
| Delivery time | [PLACEHOLDER] |
| Payment | Prepaid by ThrottleIQ. **No cash on delivery**: the winner must never pay anything |
| Tracking | Share the tracking number with the winner by SMS or email |
| Proof of delivery | Courier's delivery confirmation plus a photo from the winner (optional) |
| Failed delivery | Two attempts, then contact the winner; if unreachable for [PLACEHOLDER: days], the prize is forfeit |
| Damaged or lost | [PLACEHOLDER: replace or not; courier claim process] |

Alternative for Dhaka winners: hand over in person at a ride meet, with permission to post a photo (optional, never a condition).

## 7. Budget

| Line | Amount |
|---|---|
| Prize contents ("maintenance kit") | [PLACEHOLDER: what is in the kit, and its cost] |
| Courier | [PLACEHOLDER] |
| Packaging | [PLACEHOLDER] |
| Contingency (lost parcel, replacement) | [PLACEHOLDER] |
| **Total per prize** | [PLACEHOLDER] |
| Number of prizes | [PLACEHOLDER] |

Sponsored kit (an oil or parts brand) is possible but changes the terms and adds a disclosure; treat it as a separate decision. There is no parts partner today (issues §95.11).

## 8. Legal and terms

[LAWYER REVIEW for all of this]

- Written promotion terms: who can enter (age, residence in Bangladesh), start and end dates, the exact badge and tier, one prize per person, what the prize is, verification steps, disqualification, data use, and the organiser's right to end the promotion.
- Whether a "first to reach" promotion needs any permission or registration in Bangladesh, and whether it counts as a lottery or a contest.
- Tax or customs implications of the prize, if any.
- Play policy on in-app promotions and contests, if the promotion is mentioned inside the app or the store listing.
- No Terms of Service exist for the app yet (issues §109.14); the promotion terms can be standalone.
- [PLACEHOLDER: where the terms are published, e.g. a page under `public/`]

## 9. Copy caution (PM item 2, Call E)

- Never say or imply **"all badges = free engine oil"** or that badges in general earn rewards. That reward is an open owner call (`HANDOFF_Document.md`, owner item 23); nothing promises it today.
- Checked 2026-10-22: the 16 Record-screen quotes (`quote0`-`quote15` in `app/lib/l10n/app_en.arb`) contain no prize, oil or badge-reward claim. Re-check them before launch.
- Promotion copy names the one badge, the one tier, "first verified rider", the end date and "terms apply" with a link.
- No rarity or "X% of riders" claims: that UI was removed because riders can award themselves badges (`features.md` §3).
- Do not run the promotion in the same post as crash detection or live-share safety copy.

## 10. Step-by-step SOP (once the gate in section 1 is met)

1. Owner approves badge, tier, prize, budget, terms and dates.
2. Publish terms; post the announcement (EN + BN, Bangla native-reviewed).
3. Claimant emails hello@blankframe.tech with their @username.
4. Run the eligibility check (section 3); two sign-offs.
5. If eligible: call the claimant, collect and confirm the address (section 5).
6. Book the courier, prepaid (section 6). Send tracking.
7. Confirm delivery. Delete the address after the retention window.
8. Announce the winner by @username only, with their consent.
9. Log cost, time spent and any fraud attempts for the post-mortem.
