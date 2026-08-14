/**
 * Cloud Functions entry point.
 *
 * This file did not exist before this change — `package.json` had no `main`
 * field, and there was no `index.ts` for `tsc` to compile into one. Node's
 * default `main` resolution is `./index.js` at the package root, which
 * doesn't exist (compiled output lands in `./lib`, per `tsconfig.json`'s
 * `outDir`), and nothing re-exported `crash-notifications.ts`'s functions
 * from anywhere `firebase deploy --only functions` would look. In practice
 * this meant NOTHING in `functions/` could have deployed as-is — found
 * while fixing docs/Issues.md §24.8 and worth closing in the same pass,
 * since a PII fix in a function that can't deploy doesn't do anything.
 *
 * Re-export every trigger from every module here; this is the only file
 * `firebase deploy --only functions` needs to find them all.
 */
export * from './crash-notifications';
export * from './ride-identity';
