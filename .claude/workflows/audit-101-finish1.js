export const meta = {
  name: 'audit-101-finish',
  description: 'Review the unreviewed §101 group work (G1,G6,G8 + user-made G5,G7,G9), fix problems, full suite, QA, push to experimental and main',
  phases: [
    { title: 'Review', detail: 'master reviews each unreviewed group against its verified plan' },
    { title: 'Fix', detail: 'one worker per group that has problems, in its own worktree' },
    { title: 'Integrate', detail: 'master merges fixes onto audit-101-integration, full suite' },
    { title: 'QA', detail: 'independent QA, master fixes on failure' },
    { title: 'Ship', detail: 'docs, commit, push to experimental and main' },
  ],
}

const ROOT = '/Users/blackbird/Everything/dev/2_Ongoing/ThrottleIQ'
const STATE = '/private/tmp/claude-501/-Users-blackbird-Everything-dev-2-Ongoing-ThrottleIQ/020fd0a6-acdc-491c-afe8-4a02b417b177/scratchpad/audit101_state.json'
const BR = 'audit-101-integration'

const COMMON = `
Project: ThrottleIQ (Flutter app in app/, Firestore/RTDB rules, Cloud Functions in functions/, ops scripts + rules tests in scripts/). Main checkout ${ROOT} is on branch ${BR}, which sits on main (13ad9d2) and already contains every §101 group's work: worker-made G1,G3,G4,G6,G8,G10 commits and USER-made commits 60789be, 1ebf010 (G9 plus some G5/G7), 563e427 (G5+G7), 6e77947 (lint). The user-made commits were done by an unreliable agent and were never reviewed.
Audit text: "${ROOT}/DOCS/Handoff for agents and Todos/issues_open.md" section "## 101.". Verified plan per group (verdicts real-fix / real-but-skip / not-real / already-fixed / harmful-as-suggested, with evidence) and worker reports are in ${STATE} (JSON: verification[group], worker_reports[branch], reviews). Only items with verdict real-fix (or harmful-as-suggested with a safe fix_plan) should be implemented; real-but-skip/not-real items must NOT be implemented.
Hard rules: never deploy (no firebase deploy, no scripts/deploy.sh, nothing against project throttleiqfb). Never commit secrets or gitignored files. Never edit docs/pitch.md. Never git add -A / git add . — stage explicit paths only. In the main checkout leave these uncommitted user files alone and never stage them: app/lib/core/constants/beta_testers.dart, patch_*.sh, .claude/workflows/, .claude/hooks/. Do not push unless your instructions say so.
CI gates: flutter analyze fully clean; no "] as double" in app/lib; "catch (_)" count in app/lib <= 67. Emulators use ports 8080/9000/9099; if busy, wait and retry, don't kill others' processes.`

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    group: { type: 'string' },
    ok: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' }, description: 'concrete defects with file:line and the required fix' },
    missing: { type: 'array', items: { type: 'string' }, description: 'verified real-fix items not implemented or lacking a real test' },
    out_of_plan: { type: 'array', items: { type: 'string' }, description: 'changes that implement skipped/harmful items or unrelated changes that should be reverted' },
  },
  required: ['group', 'ok', 'problems', 'missing', 'out_of_plan'],
}
const WORK_SCHEMA = {
  type: 'object',
  properties: {
    worktree_path: { type: 'string' }, branch: { type: 'string' }, commit_sha: { type: 'string' },
    done: { type: 'array', items: { type: 'string' } }, not_done: { type: 'array', items: { type: 'string' } },
    tests_run: { type: 'string' },
  },
  required: ['worktree_path', 'branch', 'commit_sha', 'done', 'not_done', 'tests_run'],
}
const QA_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    blocking_issues: { type: 'array', items: { type: 'string' } },
    non_blocking_notes: { type: 'array', items: { type: 'string' } },
    test_results: { type: 'string' },
  },
  required: ['pass', 'blocking_issues', 'non_blocking_notes', 'test_results'],
}

const KNOWN = {
  G9: `Already-spotted problems (confirm and include): (a) app/test/sync_manager_test.dart was DELETED; the plan said replace the empty stubs with real tests using a fake connectivity/repo — write real tests (or, if SyncManager can't be faked without a refactor, make the minimal injection seam and test the C1/C2 guard behaviour). (b) .github/workflows/ci.yml flutter job: flutter test now runs twice (plain + --coverage), the "if: \${{ !cancelled() }}" guard was moved off flutter test onto the release step, and a malformed mock key.properties (literal 'n' instead of newlines) plus "flutter build apk --release" were added although B3 was verified real-but-skip (no google-services.json in CI). Restore the original flutter-test step with its guard; remove the release build, mock key.properties and coverage run. (c) app/pubspec.lock has ~250 changed lines with no pubspec.yaml change — an unplanned dependency upgrade; restore it to main's version unless something verified needs it. (d) Check app/analysis_options.yaml, ui_tour_test.dart, proguard and build.gradle.kts edits match the plan (B5-header, B5-signing must fail loudly when key.properties is missing for release only, B6 Info.plist). (e) commit 1ebf010 also committed .claude/settings.json — that is the user's own config change; leave it.`,
  G5: `Note: user commits 1ebf010 and 563e427 mix G5 and G7 work. Check each real-fix item (A1 re-auth on delete, A2-liveshare stop on sign-out, A4 error/sign-out/social title) is correct and has a test; check that harmful-as-suggested items A3-forumFollows/A3-deleteSharedRide were NOT implemented as the audit suggested (ride_share_repository.dart and forum_repository.dart were changed — verify), and group_ride_repository.dart change against A3-groupRides (not-real: a limit would break rides).`,
  G7: `Note: work is in user commits 1ebf010 and 563e427 (number_parser.dart, garage, maintenance, ride, navigation files). Check every real-fix R item is done correctly with a test (R1 odometer double-count, R2 validation, R4 parseLocalizedNumber incl. Bangla digits and decimal comma, R5 kinematics, R6 loop-route arrival latch, R7, R8, R10 items), and that R3 (real-but-skip) was NOT changed — maintenance_forecast.dart was edited, verify and revert if it implements R3. Also check the ride_point_dao and auto_tracking_service edits.`,
  G1: 'Worker branch audit101-g1 was merged but its master review never finished. Review commit 8ea7447 — especially that tightened rules do not block any write the Flutter client really makes (grep app/lib for every tightened path), and that rules tests cover each change.',
  G6: 'Worker branch audit101-g6 was merged but its master review never finished. Review commit 6b1016b.',
  G8: 'Worker branch audit101-g8 was merged but its master review never finished. Review commit 84570b6.',
}
const GROUPS = ['G1', 'G5', 'G6', 'G7', 'G8', 'G9']

phase('Review')
const results = await pipeline(
  GROUPS,
  g => agent(`${COMMON}

You are the MASTER reviewer for group ${g}. Read verification.${g} in ${STATE}. ${KNOWN[g]}
READ-ONLY: do not edit files. Inspect the relevant commits (git show) and current code on ${BR}. Run the tests relevant to this group yourself (targeted flutter test files / rules tests) and flutter analyze. Report concrete problems, missing real-fix items (including fixes without a real test), and out-of-plan changes to revert. ok=true only if nothing needs changing.`,
    { label: `review:${g}`, phase: 'Review', schema: REVIEW_SCHEMA }),
  async (rev, g) => {
    if (!rev || (rev.ok && !rev.problems.length && !rev.missing.length && !rev.out_of_plan.length)) return { group: g, review: rev, work: null }
    const brief = JSON.stringify({ problems: rev.problems, missing: rev.missing, out_of_plan: rev.out_of_plan }, null, 1)
    let work = await agent(`${COMMON}

You are the WORKER for group ${g}, in an isolated git worktree (your cwd) based on ${BR}. Plan: verification.${g} in ${STATE}. The master found:
${brief}
Fix all of it: correct defects, implement missing real-fix items with tests that fail before / pass after, revert out-of-plan changes. Stay within this group's files. Setup: flutter pub get in app/ (copy app/android/app/google-services.json and app/android/local.properties from ${ROOT} if a build needs them; never stage them); npm install in scripts/ for rules tests; npm ci in functions/. Run flutter analyze + the affected tests (and full flutter test once at the end). Create branch "audit101-finish-${g.toLowerCase()}" and commit with message "fix(${g.toLowerCase()}): ..." ending with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Report pwd, branch, sha.`,
      { label: `work:${g}`, phase: 'Fix', isolation: 'worktree', schema: WORK_SCHEMA })
    let rr = null
    for (let round = 1; round <= 2 && work; round++) {
      rr = await agent(`${COMMON}

You are the MASTER reviewing the fix for group ${g}. Problems that had to be fixed:
${brief}
Worker report: ${JSON.stringify(work)}
cd "${work.worktree_path}" and inspect "git diff ${BR}..${work.branch}". Re-run the affected tests and flutter analyze. ok=true only if every problem is properly fixed and nothing new is broken.`,
        { label: `recheck:${g}#${round}`, phase: 'Fix', schema: REVIEW_SCHEMA })
      if (!rr || rr.ok) break
      if (round === 2) break
      const re = await agent(`${COMMON}

WORKER rework for ${g}. cd "${work.worktree_path}" (branch ${work.branch}). Master still sees:
${JSON.stringify({ problems: rr.problems, missing: rr.missing, out_of_plan: rr.out_of_plan }, null, 1)}
Fix them, re-run checks, commit on the same branch. Report pwd, branch, new sha.`,
        { label: `rework:${g}`, phase: 'Fix', schema: WORK_SCHEMA })
      if (re) work = re
    }
    return { group: g, review: rev, work, recheck: rr }
  },
)

const done = results.filter(Boolean)
const toMerge = done.filter(r => r.work && r.recheck && r.recheck.ok)
const failed = done.filter(r => r.work && !(r.recheck && r.recheck.ok))
log(`To merge: ${toMerge.map(r => r.group).join(', ') || 'none'}; fixes not approved: ${failed.map(r => r.group).join(', ') || 'none'}`)

phase('Integrate')
const integ = await agent(`${COMMON}

You are the MASTER. In ${ROOT} (branch ${BR}) merge these approved fix branches: ${toMerge.map(r => `${r.work.branch} (${r.work.commit_sha})`).join(', ') || 'none'}.
${failed.length ? `These groups' fixes were NOT approved after rework; for each, read the remaining problems and either fix them yourself directly on ${BR} or revert the offending change so ${BR} is correct: ${JSON.stringify(failed.map(r => ({ group: r.group, branch: r.work.branch, remaining: r.recheck })))}` : ''}
Then run the FULL suite in ${ROOT}: flutter pub get, flutter analyze, flutter test (all), CI grep guards; functions: npm ci, build, test; scripts: npm install, npm test, npm run test:rules:ci, npm run test:rtdb:ci. Also validate .github/workflows/ci.yml parses as YAML. Fix integration breakage with minimal commits (explicit paths only). Report merged branches, conflicts, and full test counts.`,
  { label: 'master:integrate', phase: 'Integrate' })

phase('QA')
let qa = null
for (let round = 1; round <= 3; round++) {
  qa = await agent(`${COMMON}

You are the independent QA agent. Review the whole change "git diff main...${BR}" in ${ROOT} (the full §101 work) and run the complete suite yourself: flutter analyze, flutter test, CI grep guards, functions build+test, scripts npm test + test:rules:ci + test:rtdb:ci, and YAML-validate ci.yml. Cross-check against the verified plans in ${STATE}: real-but-skip / not-real items must not be implemented, real-fix items should be done with real tests. Look for regressions, rules that would block writes the Flutter client really makes, weak/fake tests, committed secrets or gitignored files, unplanned dependency upgrades, broken CI. Master's integration report: ${integ}
Do not edit files. pass=true only if no blocking issues.`,
    { label: `qa#${round}`, phase: 'QA', schema: QA_SCHEMA })
  if (!qa || qa.pass || round === 3) break
  log(`QA round ${round}: ${qa.blocking_issues.length} blocking issue(s)`)
  await agent(`${COMMON}

You are the MASTER. QA rejected ${BR} with:
${qa.blocking_issues.map(p => '- ' + p).join('\n')}
Fix each (or revert the offending change if unsafe to fix), re-run the full suite, commit on ${BR} with explicit paths. Report changes.`,
    { label: `master:qa-fix#${round}`, phase: 'QA' })
}
if (!qa || !qa.pass) return { results, integ, qa, shipped: false }

phase('Ship')
const ship = await agent(`${COMMON}

You are the MASTER. QA passed. In ${ROOT} on ${BR}:
1. Docs in "DOCS/Handoff for agents and Todos/": in issues_open.md §101 mark each implemented item FIXED with a one-line note (fix + test), and annotate not-real / already-fixed / harmful-as-suggested / real-but-skip items with the short reason from ${STATE} (so the next agent doesn't redo them); follow the file's existing convention for issues_fixed.md; tick completed groups in todo_now_antigravity.md §10 (note G2: nothing safe to fix, S6 group_rides membership needs a Cloud Function); add a HANDOFF_Document.md entry summarising this pass and what remains founder-only. Never touch docs/pitch.md. QA notes: ${JSON.stringify(qa.non_blocking_notes)}
2. Commit docs (explicit paths, message "docs(audit): mark §101 fixes and verification verdicts", Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>). Confirm "git status" shows only the user's untouched files (beta_testers.dart, patch_*.sh, .claude/workflows/, .claude/hooks/) as remaining.
3. git fetch origin. For each of experimental and main: check "git merge-base --is-ancestor origin/<b> HEAD". If ancestor: "git push origin ${BR}:<b>". If not: do NOT force; merge origin/<b> into ${BR}, re-run flutter analyze + flutter test, then push. Never --force.
4. Report pushed shas for both branches, "git log --oneline 13ad9d2..HEAD", and everything left undone / founder-only.`,
  { label: 'master:ship', phase: 'Ship' })

return { results, integ, qa, ship, shipped: true }
