# Critique: `video_script_1.md`

_Written 2026-11-01. Every claim in the script was checked against the repo, git history, GitHub and `DOCS/Handoff for agents and Todos/` on this date._

## Verdict

Strong draft. The crash hook is a real story most portfolio videos don't have, and the "Keep it honest" section shows the right instincts. Three problems hold it back:

1. **Four lines don't match the repo**, and the script says interviewers will open it. One of them breaks its own honesty rules (details below).
2. **The best part comes too late.** The hook makes a promise at 0:15 and doesn't pay it off until 3:35. The crash section, the strongest material, is also the most rushed.
3. **It claims more than it shows.** System design gives the problem without the measured result. The AI section never says what *you* did, and that is the first thing a 2026 interviewer will ask.

---

## Must fix: accuracy

| # | Script says | Repo says | Fix |
|---|---|---|---|
| 1 | §3: "crash detection came off the **store listing**" | No public store listing exists (HANDOFF line 36; the script's own honesty list says so). | "came out of the app's description" or "I took the claim out of everything we publish". |
| 2 | §4: "one shared positions document per group ride" fixes N² | The load-test file you put on screen says, in point 2, *"Moving the payload into one doc does not help, because each write still reaches N listeners."* The fix only works because phones **poll** the doc (issues_open §104.2). | Say "one shared positions document **that each phone polls**", and give the measured result: **3N reads per tick instead of N² + N** (`quota_sim.js`). Don't zoom in on the line that contradicts you. |
| 3 | §5: "a security scan found **twenty-five** issues" | 26 rows: 25 fixed, 1 skipped (C6) with a reason (issues_fixed §123). | "found twenty-six problems. Agents fixed twenty-five; I skipped one on purpose." That is more honest and sounds better. |
| 4 | §5: "One day" | Git (Dhaka time): sweep plan committed 04:00 on 30 Oct, PR #98 merged 05:08. | If the scan wasn't much earlier, "about an hour" is the stronger claim, and git backs it up. Check when the scan ran before you change it. Also: the sweep's rules and functions are **merged, not deployed**. Say "fixed and merged", never "fixed in production". |
| 5 | §6: "a twelve-second sensor window saved around **every** impact" | A tier-0 impact keeps a ~1 KB summary. The 12 s window is kept only from tier 1 up, or for a random 10% sample (detection plan, tier table). | "around every likely impact". |

Smaller ones:
- "About a thousand commits": it's 967. Fine as spoken rounding, but commit counts are a vanity metric. Swap the time for something reviewers value.
- "Two and a half thousand tests" counts only the 2,424 Dart tests. With the 420 rules tests it's about 2,850. Either keep it (it undersells, which is safe) or say "nearly three thousand".
- "Built solo": 2 outside contributors have one commit each, and there's a CLA. "Solo" is fair. "Solo, open source, with outside contributors" is a better signal if you have 3 more seconds.
- "Real riders on the beta": 53 profile accounts. Say "about fifty", because a specific number sounds more believable than "real riders".

## Logic gap in the payoff line (§6)

> "a false alarm to your family is a bug, and a missed crash is worse."

If a missed crash is *worse*, a sharp listener asks why the alarm is off, since that guarantees misses. The line argues against your own decision. Reframe it so false alarms *cause* misses:

> "An alarm that cries wolf gets switched off, and then it misses the crash that matters. So it stays off until it's calibrated on real rides."

## Structure

**The hook's payoff is 3 minutes away.** Many reviewers decide in the first 60–90 seconds, and by 3:35 the hook has faded. Two options:

- **Recommended:** move §6 to right after §2 (about 0:50). The flow becomes: crash → what I did → the same judgment applied everywhere (product decisions, quota, security sweep) → close. The crash becomes the thesis, and the other sections become evidence for it.
- If you keep the bookend, add a one-line tease at the end of §2 ("I'll come back to that crash.") so the viewer knows it's coming.

**Time doesn't match value.** The AI section gets 65 s and 151 words. The crash section, which shows the most judgment, gets 40 s and 91 words, the tightest ratio in the script. Move about 20 s from §5 to §6.

**§2 is a feature dump.** Eight features in one sentence won't be remembered. The montage already shows them. Say three (record and score rides, predict maintenance, ride together) and let the pictures carry the rest.

**Say what happened after the fix.** Each technical beat states a problem and a fix but no result:
- Quota: "runs out at ~18 daily riders" is the *before* number. With the places cache, the load test estimates about 78 (an estimate, not a re-run; say "roughly four times the headroom" or re-run `scripts/loadtest/` and quote the real number).
- Group rides: N² + N → 3N (measured).
- Sweep: 26 found, 25 fixed, 1 skipped with a reason, deny-test suite 402 → 416.

**Missing trade-off.** The positions doc doubles writes during the dual-write period, so in a big burst writes now run out before reads (issues_open §104.2). One sentence on that ("it moved the bottleneck to writes, and I know when that goes away") is the kind of honesty the script is trying to show.

## Section notes

**§1 Hook.** Strong. Add "I was fine" (two words). Otherwise viewers spend the next minute wondering whether you were hurt.

**§3 Product thinking.**
- Offline-first is the weakest of the three decisions, because every app claims it. Its demo shot has also never run on a device. If the rehearsal fails, drop the shot *and* the claim, not only the shot.
- The "unknown, never overdue by guesswork" line is excellent. Keep it word for word.
- The modules toggle ("Forums only") is a fourth idea under a "three decisions" heading, and its line isn't in the SAY block. Cut it now rather than as the first pacing cut.

**§4 System design.**
- "against the emulator, rules on" is Firebase jargon. Say "against a local copy of the backend, with the security rules switched on".
- Three numbers in two sentences (eighteen, N-squared, twenty-seven hundred, four hundred) at 147 wpm, the fastest section, is too dense to follow by ear. Put the numbers on screen and say fewer of them.
- Scrolling fast through `firestore.rules` shows nothing. Show one rule and its attacker test side by side for 5 s instead.

**§5 AI.**
- **Add your role.** One line, for example: "I write the plan and the tests' intent, review every diff, and own every deploy. The agents type." Without it, "four agents fixed 25 issues" makes the reviewer ask what *you* did.
- "each fix with a test that failed first" is backed by the sweep doc for rules and functions fixes ("Every rules and functions fix has a test that failed before the fix"). It isn't true for dependency bumps or doc redactions, so say "each security fix".
- **Git graph shot:** `git log --graph` around 29–30 Oct also shows the 11 lanes (A–K) of the 29 Oct integration branch, so the "four lanes" claim will look wrong on screen. Scope it: `git log --graph --oneline 31bd0b41~1..31bd0b41`, or grep for `sec/`.
- PR #98 closes issues #65–#90 (25). #91–#97 are follow-ups. Show the closing list, not the full range.

**§6 Crash.**
- **Say why it missed.** "I pulled the log and published the analysis" is a claim without a finding. One sentence of diagnosis makes it believable. For example: a 12.7 km/h fall, the sensors sampled at 20 Hz and could step over the impact peak, and the "jerk" values came from GPS speed, not the accelerometer. That sentence turns "I'm careful" into "here's what I found".
- On screen, use the canonical URL `blankframe.tech/throttle-iq/crash/1/`. `/throttleiq/` goes through the 404 router and flashes a redirect.

**§7 Close.** "I find the limits before they find my users" is the best line in the script. Consider opening §4 with it as well, so the close calls back to it.

## Pacing

Measured: **651 spoken words**, not ~670. 651 words in 4:40 is **140 wpm**, which is brisk, not calm (calm is ~120–130). Read calmly, it runs about 5:00–5:25, past the 4:50 cut line before you start.

| Section | Words | Seconds | wpm |
|---|---|---|---|
| 1 Hook | 44 | 20 | 132 |
| 2 What it is | 63 | 30 | 126 |
| 3 Product | 108 | 45 | 144 |
| 4 System | 135 | 55 | **147** |
| 5 AI | 151 | 65 | 139 |
| 6 Crash | 91 | 40 | 137 |
| 7 Close | 59 | 25 | 142 |

Cut about 60 words: the §2 feature list (–25), the commit count (–5), the §4 rules line-count (–10), and the "rule files that hold lessons learned" setup in §5 (keep the deadlock example, cut the framing; –20). Spend part of the saving on the §6 diagnosis sentence and your-role line.

Also consider a 60–90 s cut (hook → crash → one line each on quota, security, AI → close) for LinkedIn and cold applications. The 4:40 version is for people who already clicked.

## Production

- Crash screenshot filenames contain typos ("Throlle", "histroy"). Open the images full screen; don't show them in Finder.
- §2: recording the montage in dark mode is right, but Year in Review's story palette may clash. Check that it reads as the same app.
- Subtitles: burn them in. Platform auto-captions will garble "ThrottleIQ", "Dhaka" and "Firestore".
- The seeded account needs real-looking rides near Dhaka. Rides at an obviously fake location undercut the "real product" claim.

## Verified as accurate

First commit 2026-07-12 ("since July"). `firestore.rules` is 2,681 lines. 420 rules tests, 2,424 Dart tests. Load test: about 18 riders, N² + N row. Quota rehearsal on a throwaway project. `qa-gate.md` rule 5 and the deadlock reference. PR #98 title and the four lanes. 50 Hz IMU, tiered `ImpactDetector`, `crashAlertsEnabled = false`. Badge rarity removed (`12209669`) because riders can award themselves badges. All UI strings named in SHOW exist in `app/lib`. Repo is public.
