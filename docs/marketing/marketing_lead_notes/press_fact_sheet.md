# ThrottleIQ — reviewer / press fact sheet

Backs the reviewer-outreach template in `outreach_templates.md` §3 — hand
this alongside (or instead of repeating) the DM itself, so a reviewer has
something concrete to reference while writing about the app. Every claim
here is checked against the current codebase/handoff status as of
2026-09-05; update the status block whenever it materially changes.

---

**What it is:** ThrottleIQ turns a rider's phone into a motorcycle's black
box — ride recording, crash detection with live location sharing,
distance-based maintenance tracking, and a rider community. Built solo, not
by a company.

**Status (2026-09-05):** Pre-launch beta, `1.0.0-beta.2.2+7`. Signed
Android APK available now
([GitHub releases](https://github.com/blankframe-tech/ThrottleIQ/releases/latest));
Play Console internal testing exists but is not yet publicly open. No App
Store listing yet — iOS runs on real devices today but isn't distributed
outside direct installs.

**What's actually built and working:**
- Offline-first ride recording — GPS + accelerometer, records with zero
  signal, syncs on reconnect
- Crash detection: impact + speed-drop signature triggers a cancellable
  countdown, plus a manual live-location share link
- Maintenance tracking by real distance ridden, not a memory-based log
- POI directory (fuel, garages, parts) with rider ratings
- Social: follow, audience-tiered ride sharing, brand/model forums, group
  rides with live positions
- Bangla localization (partial, in progress)
- 862 automated Flutter tests + 73 Firestore security-rule tests, green

**What's explicitly NOT live yet (say this plainly if asked, don't let a
reviewer assume otherwise):**
- Automatic SMS/email escalation to emergency contacts if they don't
  respond — the countdown and manual live-share work today; the automated
  follow-up is built in code but not deployed (blocked on a Firebase
  billing-plan decision)
- Public Play Store / App Store listings
- Any monetization — the app is free, no premium tier exists yet

**Why it's different from Strava/Komoot-style trackers:** those are built
for cyclists/runners and applied to motorcycles as an afterthought — no
crash detection, no distance-based maintenance tracking, no motorcycle-
specific event detection (hard-braking, rapid acceleration, highway
fatigue). ThrottleIQ is rider-first by design. (Real competitors exist
internationally in this specific category — Rever, Calimoto, Detecht,
Tonit, EatSleepRide — the honest differentiation is being the
Bangladesh-specific, Bangla-localized, BD-road-context option, not
inventing the category.)

**Who it's for:** daily BD commuters (100-160cc bikes, price-sensitive,
prepaid data), enthusiast/touring riders (bigger bikes, riding clubs), and
the families of both who care about the safety features.

**Built by:** a solo developer, Bangladesh. App id: `com.bft.throttleiq`.

**Links:**
- Source / releases: https://github.com/blankframe-tech/ThrottleIQ
- Landing page: `website_demo/index.html` (deployed URL — fill in once
  Hosting is confirmed live)

**Assets available on request:** app icon (light/dark), feature graphic,
in-app screenshots, a short demo video/screen recording if requested —
none of these should be sent as mockups of unbuilt features, only the
real current UI.

**Contact:** route through whichever channel the reviewer was reached on
(FB group DM, etc.) — no separate press email exists yet; add one here
once you designate it.
