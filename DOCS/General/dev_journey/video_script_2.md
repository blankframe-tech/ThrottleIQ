# ThrottleIQ: portfolio video script, v2

_Written 2026-11-01. Replaces `video_script_1.md` and answers every point in `video_script_1_critique.md`. Each claim was checked against the repo, git and GitHub on this date (sources at the end). Re-check the numbers if you record after a release._

**Thesis:** one crash, and what I did about it, shows how I work. Every later section is more evidence for the same habit: **find the limit, measure it, and don't claim more than you can back up.**

**Length:** about 610 spoken words, so 4:30–4:45 at a calm 130 words a minute. The timecodes below assume that pace.

**Format:** `SAY` is the voice-over, word for word. `SHOW` is what's on screen. Big numbers go **on screen as captions**, so the voice can say fewer of them.

---

## 1. Hook (0:00–0:20)

**SAY**
> On the fourteenth of October I came off my motorcycle at a rail crossing in Dhaka. A slow fall, and I was fine. I was recording the ride in my own app, and it didn't notice. What I did next is the best way to show you how I build software.

**SHOW**
- Face cam for the first sentence.
- Full-screen photo: `DOCS/General/CRASH TESTING/Screenshot Taken from Throlle IQ app minutes-seconds after the crash.jpeg`, then `crash site from app ride histroy screenshot zoomed.jpeg`. Open them full screen in Preview; never show the file names (they have typos).
- Face cam again on "how I build software".

## 2. What it is (0:20–0:42)

**SAY**
> I'm Abraar. This is ThrottleIQ, a motorcycle app for Bangladesh that I've built alone since July. It records and scores your rides, predicts what your bike needs next, and lets riders ride together. In English and Bangla, with about fifty riders on the beta.

**SHOW** (montage, about 3 s a shot, phone screen recording, dark mode)
1. Record tab: hold the start ring.
2. Ride summary: riding score and the speed-coloured map.
3. Garage → Maintenance: the "Up next" card.
4. A group-ride map with several riders.
5. Settings → Language → বাংলা: the same screen in Bangla.
- Caption over shot 5: `~50 beta accounts · 2,400+ app tests · 400+ security-rule tests · public repo`.

## 3. The crash (0:42–1:40)

**SAY**
> So I pulled the ride's data off my phone and published the analysis.
> Crash detection was switched off on purpose, because it had never been calibrated. That part was right. What was wrong: while it was off, it saved nothing. I couldn't even measure my own crash.
> So I split detecting from alarming. Detection now runs silently, in shadow mode: sensors at fifty hertz, up from twenty, a tiered detector, and twelve seconds of raw sensor data kept around every likely impact. After the ride, the app asks one question: did you fall? Every answer is a labelled example, and my own crash is now a replay test.
> The alarm stays off until it's calibrated on real rides. An alarm that cries wolf gets switched off, and then it misses the crash that matters.

**SHOW**
- Browser: `https://blankframe.tech/throttle-iq/crash/1/` (the canonical URL; `/throttleiq/` flashes a redirect). Scroll to the section "The phone saw it. The app didn't."
- On "split detecting from alarming": a two-box caption, `DETECT: on, silent` | `ALARM: off`.
- On "tiered detector": `DOCS/General/CRASH TESTING/crash_analysis_and_detection_plan.html`, the tier table (0 Impact, 1 Possible fall, 2 Likely crash).
- Phone: a ride summary → "Report a crash or fall" sheet, tap through to the "Rail crossing" surface option. (The "Did you fall?" card only appears after a real impact, so use this sheet.)
- On "replay test": `app/test/calculators/crash_2026_10_14_replay_test.dart` in the editor, then that one test passing in the terminal.
- Face cam for the last two sentences.

## 4. Same habit in the product (1:40–2:10)

**SAY**
> The same habit runs through the product.
> Maintenance is predicted from how far you actually ride. If it doesn't know when you last changed the oil, it says "unknown", never "overdue" by guesswork.
> I cut top-speed badges, because a safety app shouldn't reward speed. And I took the crash-detection claim out of everything we publish.

**SHOW**
- Maintenance page scrolled slowly, stopping on the "Not known yet" group and a "Set last done" row.
- Badges grid on the Rides tab (no speed family).
- Caption: `Crash claim removed: 14 Oct 2026 · alarm still off`.

## 5. System design (2:10–3:05)

**SAY**
> I find the limits before they find my users.
> The backend runs on Firebase's free plan. So I wrote a load test that replays the app's real queries against a local copy of the backend, with the security rules switched on. The free reads run out at about eighteen daily riders. The worst part was group rides: the cost grew with the square of the group.
> Now each phone polls one shared document, and the cost grows in a straight line. The trade-off: writes double until older app versions are retired.
> If the quota still runs out, sync pauses, riders are told their data is safe on the phone, and everything resumes after the reset. I rehearsed that on a throwaway project first.

**SHOW**
- Diagram (Excalidraw, drawn once): `Phone: SQLite + outbox` → `Firestore + security rules` / `Cloudinary (photos)` / `Hosting (live-share page)`. Arrow label: "syncs when online".
- `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`: highlight "about **18 daily active riders**" only. Don't linger on the page: its point 2 describes the *pushed* single-document design that doesn't help; the fix works because phones poll.
- Caption on "straight line": `Group ride, per tick: N² + N reads → 3N reads (measured, quota_sim.js)`.
- Caption on "trade-off": `Writes: N → 2N until old builds are retired`.
- The "data is safe" quota strip, from its widget test or a golden (it has never shown on a real phone). If you can't capture it cleanly, keep the diagram on screen.

## 6. How I work with AI (3:05–4:05)

**SAY**
> I build with AI coding agents, run like a team. My part is the judgment: I decide what gets built, write the plan and the rules the agents follow, and nothing merges or deploys without my go-ahead.
> Every change passes one gate, a script that runs the analyzer and every test suite. CI runs the same script.
> On the thirtieth of October, scanners and three reviewer agents found twenty-six security problems. I filed each as an issue, split them into four lanes, and ran four agents in parallel, each in its own copy of the repo. Every rules and backend fix came with a test that failed first. Twenty-five were fixed. I held one back on purpose, because older app versions still depend on it. Written plan to merged pull request: about an hour.

**SHOW**
- `.agents/rules/qa-gate.md`, zoom on rule 5 ("Never mock DAOs") for 3 s: the rules are lessons, not boilerplate.
- Terminal: `scripts/check.sh` sped up 10x, ending on the green summary.
- `DOCS/Handoff for agents and Todos/security_sweep_2026-10-30.md`: the four tables A–D, with the one `[-] C6 skipped` row highlighted.
- Terminal: `git log --graph --oneline 31bd0b41~1..31bd0b41` (only the four `sec/` lanes; a wider range also shows the eleven lanes of 29 Oct).
- GitHub: PR #98, scrolled to its closing list, issues #65–#90.
- Caption on the last sentence: `Plan committed 04:00 · PR #98 merged 05:08 (30 Oct)`.

## 7. Close (4:05–4:30)

**SAY**
> So that's what I bring: a whole product, built alone, from the phone to the backend to the release pipeline. Limits found before users hit them. And AI that multiplies the work without lowering the bar, or the honesty about what isn't done yet. The code is public. The link is below. Thanks for watching.

**SHOW**
- Face cam. Lower third: `github.com/blankframe-tech/ThrottleIQ`.
- End card: app icon, repo link, your email.

---

## 100-second cut (LinkedIn, cold applications)

Same footage, about 220 words in all. Use sections 1 and 7 word for word, and replace 2–6 with:

> I'm Abraar, and ThrottleIQ is the motorcycle app I've built alone since July. Its crash detection was off on purpose, because it was uncalibrated. But while it was off, it saved nothing, so I couldn't measure my own crash. Now detection runs silently, the app asks after every ride whether you fell, and the alarm stays off until real rides calibrate it.
> Same habit everywhere: a load test showed group rides cost the square of the group, so now they cost a straight line. And I run AI agents like a team: in one morning they fixed twenty-five security problems in parallel, every rules and backend fix with a test that failed first.

---

## Before you record

**Capture list**
- [ ] Seeded account: a few real rides around Dhaka (not an obviously fake location), one bike with maintenance set up and one check left "Not known yet", a group ride with two or three riders. Hide your email and phone number.
- [ ] Phone recordings (dark mode): the section 2 montage, the maintenance scroll, the badges grid, the "Report a crash or fall" sheet.
- [ ] Screen recordings: the crash write-up page, the detection plan's tier table, the replay test passing, the load-test file, `qa-gate.md`, a `check.sh` run, the sweep doc, the scoped git graph, PR #98.
- [ ] The diagram and the captions listed above.
- [ ] Face cam: hook, end of section 3, close. Eye level, window light.

**Keep it honest (interviewers will open the repo)**
- **Check the one claim the repo can't prove:** "nothing merges or deploys without my go-ahead" in section 6. Say it only if it's literally true for you; otherwise change it to what is.
- Crash alerts are **off**. Never say the app detects crashes or alerts anyone. It records, asks and learns.
- No public store listing yet: say "beta". Android testers get it through the Google Play test track; there's no iPhone build for testers.
- Say "public repo" or "source-available", **not "open source"**: the licence is TSAL v1.1, not an open-source licence.
- Don't say the group-ride fix or the sweep is "in production". Say "measured" and "merged". Cloud Functions are written but not deployed (free plan).
- Don't name the B2B pilot partner or mention pricing: that report is kept out of the public repo on purpose.
- Don't quote "~78 riders" for the quota after the fixes. That number assumes no places refetch at all; it was never re-run.

**Production**
- Burn the subtitles in. Auto-captions garble "ThrottleIQ", "Abraar", "Dhaka" and "Firebase".
- Check that Year in Review isn't in the montage unless its story colours read as the same app.
- Read every `SAY` block aloud with a timer before filming. Over 4:50? Cut the badges sentence in section 4 first, then the replay-test clause in section 3.
- One idea per shot. No shot over 6 s unless it's your face.

## Sources for every claim

| Claim | Source |
|---|---|
| Fall on 14 Oct at a rail crossing, about 12.7 km/h | `DOCS/General/CRASH TESTING/crash_analysis_2026-10-14.md` |
| Detection was off on purpose; nothing was saved | same file, "Why ThrottleIQ did not detect the crash" (points 1 and 3) |
| 50 Hz up from 20 Hz, 12 s window for likely impacts (tier 1+, or a 10% sample) | `crash_analysis_and_detection_plan.html`; `app/lib/core/constants/sensor_constants.dart` |
| Crash replay test | `app/test/calculators/crash_2026_10_14_replay_test.dart` |
| Alarm off | `SensorConstants.crashAlertsEnabled = false`; HANDOFF "Known limitations" |
| Built alone since July | first commit 2026-07-12; two outside contributors have one commit each |
| About 50 beta accounts | 53 profiles in the 2026-10-27 email migration (HANDOFF "Production backend") |
| 2,400+ app tests, 400+ rule tests | 2,424 Dart tests and 420 rules tests (critique count, 2026-11-01); `check.sh` reported 2,515 on 2026-10-31 |
| "Unknown", never overdue by guesswork | `features.md` §5, "Baselines" |
| Top-speed badges cut for safety | `app/test/core/utils/badges_test.dart`: "Rewarding top speed contradicts the safety story" |
| Crash claim removed | HANDOFF 2026-10-14: "Crash and SOS claims removed from the listing and pitch" |
| ~18 daily riders | `load_test/load-test-2026-10-15.md` |
| N² + N → 3N reads, writes N → 2N during the dual write | `issues_open.md` §104.2 (measured in `quota_sim.js`) |
| Quota outage mode, rehearsed | `load_test/quota-rehearsal-2026-10-21.md`; `features.md` "Firestore quota outage mode" |
| 26 found, 25 fixed, C6 held back for old builds | `security_sweep_2026-10-30.md`, tables A–D and "Result" |
| Scanners plus three reviewer agents | same file, "Source" line |
| Rules and backend fixes test-first | same file: "Every rules and functions fix has a test that failed before the fix" |
| About an hour | git: `2a1ca4be` plan 04:00, `31bd0b41` merge 05:08 (+06:00, 30 Oct) |
| Four lanes, one worktree each | `.agents/rules/parallel-agents.md`; merges `sec/a`–`sec/d` |
| Public repo | `gh repo view`: PUBLIC |
