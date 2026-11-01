# ThrottleIQ: portfolio video script

_Written 2026-11-01. Runs about 4:40 at a calm pace (~670 spoken words). Facts are taken from `DOCS/Handoff for agents and Todos/` as of this date; re-check the numbers if you record later._

**What it has to prove, in order:** I ship a real product end to end. I think about users and constraints before code. I design systems that hold under limits. I use AI agents like an engineering team, with tests and honesty kept.

**Format:** face cam for the hook, the judgment beats and the close; screen and phone recordings everywhere else. `SAY` is the voice-over, word for word. `SHOW` is what's on screen.

---

## 1. Hook (0:00–0:20)

**SAY**
> On the fourteenth of October I came off my motorcycle at a rail crossing in Dhaka. I was recording the ride in my own app, and it didn't notice. What I did next is the best way to show you how I build software.

**SHOW**
- Face cam, 2 s. Then cut to `DOCS/General/CRASH TESTING/Screenshot Taken from Throlle IQ app minutes-seconds after the crash.jpeg`, then `crash site from app ride histroy screenshot zoomed.jpeg`.
- Back to face on "how I build software".

## 2. What it is (0:20–0:50)

**SAY**
> I'm Abraar. This is ThrottleIQ, a motorcycle app for Bangladesh that I've built solo since July. It records rides and scores how smoothly you ride, tracks your bike's maintenance and fuel cost, and connects riders through forums, group rides and live location sharing, in English and Bangla. About a thousand commits, two and a half thousand tests, and real riders on the beta.

**SHOW** (fast montage, ~3 s per shot, phone screen recording)
1. Record tab: hold the start ring.
2. Active ride: speed-coloured trail on the map.
3. Ride summary: riding score, speed bands, Ride cost card.
4. Garage → Maintenance: the "Up next" card.
5. Social feed, then a group-ride map.
6. Settings → Language → বাংলা, same screen in Bangla.
7. Year in Review story playing (best eye candy; keep it for the end of the montage).

## 3. Product thinking (0:50–1:35)

**SAY**
> Three decisions shaped it.
> One: Dhaka's mobile signal is unreliable, so the phone is the source of truth. Rides, bikes and fuel live on the device and sync when they can.
> Two: maintenance is predicted, not scheduled. It projects each part's due date from how far you actually ride, and wears parts faster if you ride in stop-and-go traffic or brake hard. And if it doesn't know when you last changed the oil, it says "unknown", never "overdue" by guesswork.
> Three: I cut things that weren't honest. Badge rarity went, because the numbers could be gamed. And crash detection came off the store listing until it actually works.

**SHOW**
- Phone: put it in airplane mode, end a ride, it saves at once. (Rehearse first: the offline flow has never been run on a device.)
- Maintenance page scrolled slowly: "Needs attention / Coming up / Not known yet" groups, then the "Adapt to my riding" switch.
- Settings → Advanced → Your ThrottleIQ: turn Community to "Forums only" and show the nav change live (one beat: "riders choose how much app they want").

## 4. System design (1:35–2:30)

**SAY**
> The backend is Firebase on the free plan, and I designed around that limit. I wrote a load test that replays the app's real queries against the emulator, rules on. The free reads run out at about eighteen daily riders, and group-ride positions cost N-squared reads.
> So: one shared positions document per group ride, and a places cache on the phone that only pulls what changed. And an outage mode. When the quota runs out, sync pauses, riders are told their data is safe on the phone, and everything resumes after the reset. I rehearsed that on a throwaway project before trusting it.
> Privacy is enforced on the server: about twenty-seven hundred lines of security rules for followers, mutuals and blocks, with over four hundred tests, and every rules change ships with an attacker test.

**SHOW**
- A simple diagram (draw it once in Excalidraw):
  `Phone: SQLite + durable outbox` → `Firestore (rules)` / `Cloudinary (photos)` / `Hosting (live-share viewer)`. Label the arrow "sync when online".
- `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`: highlight "about **18 daily active riders**" and the row `Group ride, per 20 s broadcast tick | N² + N`.
- `firestore.rules`: a fast scroll, then one attacker test in `scripts/test/rules/` (a blocked rider or someone else's doc being denied).
- Optional 3 s cutaway: the Year in Review video export, with the caption "native video encoders on iOS and Android, no FFmpeg".

## 5. How I use AI (2:30–3:35)

**SAY**
> I build with AI coding agents, but I run them like a team, not a chat box.
> The repo is written for them: a handoff document, an issues list with permanent numbers, and rule files that hold lessons learned. "Never mock the database in tests" is there because a mock once hid a real deadlock.
> Every change passes one gate, a single script: formatting, the analyzer, the full test suite, the rules and the functions. CI runs the same script.
> For big pushes I fan out. On the thirtieth of October a security scan found twenty-five issues. I filed each one on GitHub, split them into four lanes (dependencies, rules, functions and the app), and ran four agents in parallel, each in its own worktree, each fix with a test that failed first. I merged them one lane at a time and ran the gate once at the end. One day.

**SHOW**
- `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`, then the `.agents/rules/` folder, zoom on `qa-gate.md` rule 5 ("Never mock DAOs").
- Terminal: `scripts/check.sh` running, sped up 10x, ending on the green summary.
- GitHub: PR #98 and its linked issues (#65–#97), then `git log --graph --oneline` around 2026-10-29/30 to show the lanes merging.
- Optional: a split screen of four agent sessions working (re-enact one if you have no recording).

## 6. Back to the crash: judgment (3:35–4:15)

**SAY**
> Back to the crash. The tempting move was to tune a few thresholds and ship an alarm. I didn't. I pulled the ride's GPS and sensor log, published the analysis, and built crash detection in shadow mode: fifty-hertz sensors, a tiered detector, and a twelve-second sensor window saved around every impact. After the ride, the app asks: did you fall? Those answers become labelled data. The alarm stays off until it's calibrated on real rides, because a false alarm to your family is a bug, and a missed crash is worse.

**SHOW**
- `DOCS/General/CRASH TESTING/crash_analysis_and_detection_plan.html` open in a browser, scroll to the detection plan.
- The public write-up: blankframe.tech/throttleiq/crash/1.
- Phone: ride summary → "Report a crash or fall" sheet (easy to reach on any ride; the "Did you fall?" card only appears after a real impact).
- Back to face cam for the last sentence.

## 7. Close (4:15–4:40)

**SAY**
> So that's what I bring. I ship a whole product: mobile, backend, security and release. I find the limits before they find my users. And I use AI to multiply what I can build, without giving up the tests, the reviews, or honesty about what isn't done yet. AI is the force multiplier, never the crutch. The code is public. The link is below. Thanks for watching.

**SHOW**
- Face cam. Lower third: `github.com/blankframe-tech/ThrottleIQ`.
- End card: app icon, repo link, your email.

---

## Before you record

**Capture list**
- [ ] Phone screen recordings: the montage (section 2), airplane-mode ride end, maintenance scroll, modules toggle, "Report a crash or fall" sheet, Year in Review playing. Use the phone's own screen recorder, and record in dark mode for one consistent look.
- [ ] A seeded account with a few real rides, one bike with maintenance set up, some forum posts. Hide your email and phone number.
- [ ] Screen captures: the HANDOFF doc, `.agents/rules/`, the load-test file, `firestore.rules`, one rules test, a `check.sh` run, PR #98, the git graph, the crash analysis page.
- [ ] One diagram (section 4).
- [ ] Face cam: hook, section 6 ending, close. Eye level, window light.

**Keep it honest (interviewers will open the repo)**
- Crash alerts are **off**. Never say the app detects crashes or alerts anyone; say it records, asks and learns.
- No public Play Store listing yet: say "beta" or "Google Play test track", not "on the Play Store". No App Store build.
- Cloud Functions are written but not deployed (free plan). Don't present server jobs or push notifications as live.
- "Real riders on the beta" is true (about 50 accounts in production on 2026-10-27). Don't inflate it.
- Don't name the B2B pilot partner or mention pricing: the repo is public and that report is kept out of git on purpose.
- Offline end, ride restore, route following and the quota bar have only passed tests, not a phone. Rehearse any of them on the phone before filming, or swap the shot.

**Pacing**
- Read the `SAY` blocks aloud with a timer before filming. If you pass 4:50, cut the modules beat in section 3 and the optional cutaways first.
- One idea per shot. Cut on every sentence; no shot over 6 s unless it's your face.
- Subtitles on (many reviewers watch muted).
