# Coding standards (review rules)

Source: `.agents/rules/` and the guards in `scripts/check.sh`.

- Run `scripts/check.sh` once per change set; never delete or skip a failing test.
- No raw `x['k'] as double`; use `asDouble`/`asDoubleOrNull` (`core/utils/num_cast.dart`).
- No new bare `catch (_)`; the count only goes down (`CATCH_MAX`). Use `reportNonFatal` or a logged `catch (e)`.
- No paid-only iOS entitlements (associated-domains, iCloud, Sign in with Apple, push) in `app/ios/*/*.entitlements`.
- New public methods in calculators, DAOs, services need a happy-path and an edge-case test.
- Database tests use real in-memory SQLite, never mocked DAOs. Never call another DAO inside a transaction.
- No `// ignore:` in production code without a reason comment.
- Format only files you changed; edit ARBs with targeted inserts, then `flutter gen-l10n`.
- Parallel agents: one git worktree and branch each.
- Always use ponytail and caveman.
