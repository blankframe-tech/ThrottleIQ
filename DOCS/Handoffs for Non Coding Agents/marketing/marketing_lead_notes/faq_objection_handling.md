# Objection-handling FAQ — for comment replies in BD moto Facebook groups

`marketing.md` §5 calls these communities "close-knit and ad-skeptical."
This is the set of objections a post recruiting testers or announcing
launch will actually draw in the comments — answers are meant to be
adapted to your own voice, not copy-pasted verbatim as a wall of text (a
templated-sounding reply reads exactly as templated in a skeptical group).

---

**"Another app asking for my location? No thanks."**
Fair to be skeptical. Location is only used for ride tracking and the
optional nearby-places search — it's never sent anywhere without you
starting a ride or tapping "find nearby." No background selling of
location data; there's no ad network or data broker involved because
there's no monetization at all right now. `public/privacy.html` has the
actual data table if you want specifics, not just my word for it.

**"Is this just another side project that gets abandoned in 3 months?"**
Can't prove the future, only show the present: it's had a real
security-hardening pass (16 of 18 findings closed), 862 automated tests
passing, and active weekly commits — check the GitHub history yourself,
it's public. If it stalls, you'll see the commits stop, same as you'd
notice with any project.

**"Does it drain my battery running in the background?"**
It uses adaptive GPS accuracy tiers, not maximum precision the whole
time — tuned specifically because most testers ride on prepaid data and
budget phones where battery matters more than lab-perfect GPS. Genuinely
want to know if it doesn't hold up on your specific phone — that's exactly
the kind of feedback closed testing exists for.

**"Strava already does ride tracking, why do I need another app?"**
Strava's built for cyclists/runners — no crash detection, no
distance-based maintenance tracking, no motorcycle-specific event
detection (hard-braking, overspeed, highway fatigue). If you just want a
route map, Strava's fine. If you want your bike's actual dashboard —
maintenance due, crash alerts, offline recording through dead zones — this
does things Strava doesn't.

**"Will it call the police / hospital automatically if I crash?"**
No — and don't want to overclaim this, it matters too much to get wrong.
It detects a likely crash and starts a cancellable countdown; if you don't
cancel, it lets you share your live location with emergency contacts *you*
choose. No automatic call to anyone, no automatic SMS yet either — that's
honestly not built yet. It's a faster way for someone who cares about you
to find out, not a 911 replacement.

**"Is it actually free, or is there a catch later?"**
Free today, no premium tier exists yet — the roadmap mentions one someday
but nothing is priced or built. If/when that happens, core ride recording
and maintenance tracking are not the kind of thing that would go behind a
paywall retroactively; that's a promise about intent, not a
Play-Store-enforced guarantee, so judge it by whether it holds when the
premium tier actually ships.

**"Why should I trust a solo developer with my ride data?"**
Legitimate question, no scripted answer beats just being direct about it:
it's one person, not a company, and that cuts both ways — faster fixes
when you report something, but also no support team if something goes
wrong. The Firestore security rules and data-handling are public in the
repo if you want to actually check rather than take it on trust.
