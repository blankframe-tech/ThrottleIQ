# 🏍️ ThrottleIQ — Machine Memory for Motorcycles

**ThrottleIQ** is an offline-first ride tracker, garage and rider community for motorcycles. It records every ride (speed, braking, cornering, elevation, route), remembers what each bike needs next, and connects riders with each other. Built in Bangladesh, in English and Bangla.

![License](https://img.shields.io/badge/license-TSAL-blue) ![Flutter](https://img.shields.io/badge/Flutter-Dart%203-blue) ![Firebase](https://img.shields.io/badge/Firebase-Firestore-orange)

> **Status:** pre-launch beta `1.0.0-beta.4.5.0+26`, tagged
> [`beta-v4.5`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v4.5).
> Real riders are testing a signed Android build from GitHub Releases and a Play
> Console internal-testing track. There is no public Play Store or App Store
> listing yet. App id: `com.bft.throttleiq`.
> Current state, open issues and the feature map:
> [`HANDOFF_Document.md`](DOCS/Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md).

> ⚠️ **Crash detection and emergency alerting are NOT live.** Do not rely on
> ThrottleIQ to detect a crash or contact anyone for you. The detector is built
> but switched off pending field calibration, and no SMS or email provider is
> wired up. See `issues_open.md` §78.1 and §81.

---

## ✨ What it does

- **Ride recording**: background GPS plus 20 Hz accelerometer and gyroscope, with live speed, alerts for overspeed, hard braking and fatigue, and an idle/moving split. Works fully offline.
- **Rides tab analytics**: score, per-ride and lifetime charts (basics, time, riding behaviour, cornering and elevation, activity patterns, per-bike, fuel), badges and streaks.
- **Garage and maintenance**: multiple bikes, per-model service schedules, "what's due next" by km or date, service visits with receipts, paperwork expiry, PDF service record.
- **Places and routes**: fuel, garage and spare-parts directory with reviews; saved routes; Dhaka-focused seed data.
- **Social**: ride feed with privacy zones, forums, direct messages, group rides with live positions, challenges, QR follow.
- **Safety (shipped parts)**: revocable 24 h live-share link, emergency contacts and a SafeQR medical card.
- **Data**: JSON, CSV and GPX export; Firestore sync on resume and every 5 min; in-app account deletion.
- **Bilingual**: full English and Bangla.

## 📹 Indriyo — the hardware side

**Indriyo** is a low-cost, safety-first dash cam built for motorcycles (a digital rearview mirror with ADAS). It pairs with ThrottleIQ. Experimental integration lives on the [`indriyo`](https://github.com/blankframe-tech/ThrottleIQ/tree/indriyo) branch. More at **[blankframe.tech/indriyo](https://blankframe.tech/indriyo)**.

---

## 🚀 Quick start

```bash
git clone https://github.com/blankframe-tech/ThrottleIQ.git
cd ThrottleIQ/app
flutter pub get
flutter run
```

You need your own Firebase project and Cloudinary account (photo uploads; Firebase Storage is not used). Full steps, Android signing and iOS certificates: [`SETUP.md`](DOCS/For%20Devs%20and%20Contributors/guides/SETUP.md).

## 🏗️ Architecture

- **App**: Flutter, Riverpod, go_router, Material 3, flutter_map. Feature-first layout under `app/lib/features/`.
- **Local**: SQLite is the source of truth. Recording never needs internet; unsynced rows upload incrementally.
- **Cloud**: Firestore + Auth (email and Google) + Cloudinary. Cloud Functions (`functions/`) are written for account cleanup, ride identity and chat moderation; deploying them needs the Blaze plan.
- Deeper write-up: [`arch.md`](arch.md).

## 🧪 Quality gate

One command runs everything (translations, format, CI checks, `flutter analyze`, all tests, and the Firestore rules and Functions tests when they changed):

```bash
scripts/check.sh
```

It runs once per commit, and git runs it before every push. CI calls the same script, so local and CI checks match. Currently 2100+ tests, with DAOs tested against real in-memory SQLite.

## 🔒 Privacy

Private data lives under `/users/{uid}/...`, owner-only per `firestore.rules`. Shared data has per-feature rules. Shared rides clip the start and end inside a 200–349 m privacy zone. There is no ad or behavioural-analytics SDK; Crashlytics collects crash diagnostics only. See [`public/privacy.html`](public/privacy.html) and [`SECURITY.md`](SECURITY.md).

## 📚 Documentation

Everything is under [`DOCS/`](DOCS/README.md). Start with [`HANDOFF_Document.md`](DOCS/Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md), then [`features.md`](DOCS/Handoff%20for%20agents%20and%20Todos/features.md) and [`issues_open.md`](DOCS/Handoff%20for%20agents%20and%20Todos/issues_open.md).

## 🗺️ Roadmap

- **Now**: Play Store and App Store submission, growing the real-rider beta, marketing launch in Bangladesh.
- **Next**: crash detection field calibration, then real alert delivery (needs an SMS/email provider and Blaze).
- **Later**: lean-angle tracking, clubs and events, weekly reports, curvy-route planner, Indriyo hardware integration in the main app.

## 🤝 Contributing

Branch from `experimental`, keep commits focused, write tests for new logic, never commit secrets, and run `scripts/check.sh` before pushing.

## 📄 License

**ThrottleIQ Source-Available License (TSAL) v1.0** — see [LICENSE](LICENSE). You can view and audit the source, but not copy, fork or build a competing app.

---

*Built for riders. Ride safe. 🏍️ · Last updated: 2026-10-09*
