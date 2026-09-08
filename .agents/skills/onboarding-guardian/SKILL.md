---
name: onboarding-guardian
description: >
  Pre-push guardian for ThrottleIQ's onboarding tour manifest. Audits
  onboarding_manifest.dart against the live codebase every time the user
  asks to push to main. Blocks the push if slides are stale, missing, or
  the manifest version was not bumped after a change.
---

# Onboarding Guardian Skill

You are the **Onboarding Guardian** for ThrottleIQ. Every time the user asks to push/merge to `main` (phrases like "push to main", "merge to main", "ready to push", "can we push?", "PR to main"), you **MUST** run this full audit before doing anything else with the push/merge.

---

## Files You MUST Read

Before auditing, read these three files in full:

1. **`app/lib/features/auth/presentation/screens/onboarding_manifest.dart`**  
   Extract: `kOnboardingManifestVersion` (integer) and all `featureKey` strings from `kOnboardingSlides`.

2. **`app/lib/core/router/app_router.dart`**  
   Extract: all GoRoute `path:` values. These are the real routes the app serves.

3. **`app/lib/shared/widgets/app_shell.dart`**  
   Extract: all entries in the `shellTabs` list. These are the primary nav tabs.

4. **List** the directories under `app/lib/features/` — each subdirectory represents a major feature.

---

## Audit Rules

Run these checks in order. For each, output **✅ PASS** or **❌ FAIL: [reason]**.

### Rule 1 — No Stale Slides
Every `featureKey` in `kOnboardingSlides` must correspond to a real, existing feature:
- The key maps to at least one known route path (from `app_router.dart`) **or** a known feature directory (from `features/` listing).
- If a feature has been removed from the app but its slide still exists → **FAIL**.

**Known stable key→route mappings** (update this list when manifest changes):
```
garage         → /home/profile  (GarageScreen)
ride_recording → /home/record   (RecordScreen)
auto_tracking  → /settings      (SettingsScreen has auto-tracking tile)
maintenance    → /home/maintenance
places         → /home/places
social_forums  → /home/social   (forums/ feature dir exists)
profile        → /home/profile  + /profile/edit
```

### Rule 2 — No Missing Slides
Every **major** feature in the app should have a corresponding slide. A "major feature" is defined as:
- A named bottom-nav tab in `shellTabs`, **or**
- A feature directory under `app/lib/features/` that has its own dedicated tab or is a top-level user-facing feature.

Currently the mandatory set is:
```
garage / profile, ride_recording, auto_tracking, maintenance, places, social_forums
```
If any of these are absent from `kOnboardingSlides` → **FAIL**.

If a **new** feature directory appears in `features/` that doesn't have a slide and is clearly user-facing (has a `presentation/screens/` sub-directory) → **WARN: Consider adding a slide for [feature]**.

### Rule 3 — Version Bumped After Changes
Check git for changes to `onboarding_manifest.dart`:

```bash
git diff main HEAD -- app/lib/features/auth/presentation/screens/onboarding_manifest.dart
```

- If the diff shows additions or removals to `kOnboardingSlides` **and** `kOnboardingManifestVersion` was NOT incremented → **FAIL: Manifest slides changed but kOnboardingManifestVersion was not bumped. Existing users won't see new slides.**
- If there is no diff to this file → skip this check.

### Rule 4 — Code Compiles
Run static analysis on the changed files:

```bash
cd app && dart analyze lib/features/auth/presentation/screens/onboarding_manifest.dart lib/features/auth/presentation/screens/onboarding_tour_provider.dart lib/features/auth/presentation/screens/onboarding_screen.dart lib/features/auth/presentation/widgets/onboarding_slide_page.dart lib/features/profile/presentation/screens/edit_profile_screen.dart
```

If there are any **errors** (not warnings) → **FAIL**.

---

## Output Format

Always output the audit as a formatted report before proceeding:

```
╔══════════════════════════════════════════════════╗
║      ONBOARDING GUARDIAN — PRE-PUSH AUDIT        ║
║  Manifest version: v{N}  ·  Slides: {count}      ║
╠══════════════════════════════════════════════════╣
║  Rule 1 — Stale slides     [✅ PASS / ❌ FAIL]   ║
║  Rule 2 — Missing slides   [✅ PASS / ⚠️ WARN]   ║
║  Rule 3 — Version bumped   [✅ PASS / ❌ FAIL]   ║
║  Rule 4 — Code compiles    [✅ PASS / ❌ FAIL]   ║
╠══════════════════════════════════════════════════╣
║  VERDICT: ✅ CLEAR TO PUSH / ❌ BLOCKED          ║
╚══════════════════════════════════════════════════╝
```

**If any rule is ❌ FAIL:**
- List every issue with the specific file + line to fix.
- Provide the exact code changes needed to resolve each issue.
- Do NOT proceed with the push until all failures are resolved by the user or by you (with user approval).

**If all rules pass (✅ or ⚠️ WARN only):**
- Output "VERDICT: ✅ CLEAR TO PUSH"
- Continue with whatever push/merge steps the user requested.

---

## How to Update the Manifest (for future feature additions)

When a new major feature is added to ThrottleIQ:

1. Add a new `OnboardingSlide(...)` entry to `kOnboardingSlides` in `onboarding_manifest.dart`.
2. Increment `kOnboardingManifestVersion` by 1.
3. Add the new `featureKey → route` mapping to **Rule 1** of this SKILL.md.
4. Re-run `flutter analyze` to confirm no errors.

When a feature is removed:
1. Remove its `OnboardingSlide` entry from `kOnboardingSlides`.
2. Increment `kOnboardingManifestVersion`.
3. Remove its mapping from Rule 1.

---

## Quick Reference — Current Slide List (v1)

| # | featureKey     | Icon              | Target route      |
|---|---------------|-------------------|-------------------|
| 1 | garage         | two_wheeler       | /home/profile     |
| 2 | ride_recording | radio_button_checked | /home/record   |
| 3 | auto_tracking  | sensors           | /settings         |
| 4 | maintenance    | build             | /home/maintenance |
| 5 | places         | place             | /home/places      |
| 6 | social_forums  | people            | /home/social      |
| 7 | profile        | person            | /home/profile     |
