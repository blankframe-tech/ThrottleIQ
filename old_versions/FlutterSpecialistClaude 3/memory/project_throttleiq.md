---
name: ThrottleIQ Flutter App
description: Full motorcycle tracking Flutter app built from PRD — location, package, architecture summary
type: project
---

ThrottleIQ is a complete Flutter app at `throttleiq/` built from Goal.md PRD. V1 MVP is complete.

**Why:** User wants a motorcycle tracking app with GPS ride recording, maintenance tracking, and AI chatbot.

**Stack:** Flutter + Riverpod + go_router + Firebase Auth + Google Maps + SQLite (sqflite) + geolocator + sensors_plus

**Key locations:**
- Entry: `lib/main.dart`, `lib/app.dart`
- Theme: `lib/core/theme/app_theme.dart` + `lib/core/constants/app_colors.dart`
- Router: `lib/core/router/app_router.dart`
- DB schema: `lib/core/database/database_helper.dart`
- Physics engine: `lib/features/ride/domain/calculators/motion_calculator.dart`
- Ride state machine: `lib/features/ride/presentation/providers/ride_recording_provider.dart`
- Event detection: `lib/features/ride/domain/calculators/event_detector.dart`

**Setup needed before running:**
1. Firebase project + `google-services.json` in `android/app/`
2. Google Maps API key in `AndroidManifest.xml`
3. See `SETUP.md`

**How to apply:** When working on ThrottleIQ features, the architecture is offline-first (SQLite → REST sync). Providers follow AsyncNotifier pattern. No codegen (no build_runner) — kept simple.
