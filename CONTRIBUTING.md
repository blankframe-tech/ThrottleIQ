# Contributing to ThrottleIQ

Thanks for helping. ThrottleIQ is a motorcycle ride tracker built in
Bangladesh, in English and বাংলা. Real riders test it every week, so
small, careful fixes help a lot.

## Before you start

- **License.** ThrottleIQ is source-available, not open source. [LICENSE](LICENSE)
  Section 1A lets you fork, change and run the code on your own devices
  only to send a pull request here. You can't publish or release your
  fork.
- **CLA.** Before we can merge your first pull request, you sign the
  [Contributor License Agreement](CLA.md). A bot comments on the PR with
  the sentence to post. It takes a minute and covers all your later PRs.
  You keep the copyright in your work.
- **Code of conduct.** Be kind: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- **Security bugs** go by email, never in a public issue: see [SECURITY.md](SECURITY.md).

## What to work on

- Issues labelled [`good first issue`](https://github.com/blankframe-tech/ThrottleIQ/labels/good%20first%20issue)
  are small and self-contained.
- [`help wanted`](https://github.com/blankframe-tech/ThrottleIQ/labels/help%20wanted)
  issues are bigger.
- **Bangla speakers:** reviewing machine-drafted Bangla strings is one of the most
  useful things you can do, and it needs no coding. See the issue
  labelled `translation`.
- Got an idea or a question? Start a [Discussion](https://github.com/blankframe-tech/ThrottleIQ/discussions)
  before you write a big change, so we can agree on the approach first.

Comment on an issue to claim it, so two people don't build the same thing.

## Set up

You need Flutter 3.44.9 (the version CI uses), and for the full gate
also Node 22 and Java 21.

```bash
git clone https://github.com/<you>/ThrottleIQ.git
cd ThrottleIQ/app
flutter pub get
flutter test
```

The tests need no Firebase account. To run the app on a phone, create
your **own** Firebase project and Cloudinary account and follow
[SETUP.md](DOCS/For%20Devs%20and%20Contributors/guides/SETUP.md). Don't
point a dev build at the production project, and don't commit your
Firebase or Cloudinary config.

Useful reading: [architecture overview](DOCS/For%20Devs%20and%20Contributors/architecture/arch.md)
and [CODING_STANDARDS.md](CODING_STANDARDS.md).

## Making a change

1. Branch from `main` in your fork.
2. Keep the change focused: one fix or feature per pull request.
3. Add or update tests for any new logic.
4. Every user-facing string goes in `app/lib/l10n/app_en.arb`
   **and** `app_bn.arb`. If you can't write the Bangla, copy the English
   and say so in the PR; we'll translate it.
5. Run the quality gate from the repo root:

   ```bash
   scripts/check.sh
   ```

   It runs formatting, analysis, the app tests, the Firestore rules tests
   and the Cloud Functions build. If you only touched the app, `cd app &&
   flutter analyze && flutter test` is enough locally; CI runs everything.
6. Open a pull request against `main` and fill in the template. Include
   screenshots for anything visible.

## Review

A maintainer reviews pull requests, usually within a week. CI must be
green and the CLA signed before merge. We may ask for changes, or
decline a change that doesn't fit the product; that is about the
change, not about you.
