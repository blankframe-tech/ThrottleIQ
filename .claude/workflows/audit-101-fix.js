export const meta = {
  name: 'audit-101-fix',
  description: 'Verify audit §101 findings, fix verified ones per group under a master reviewer, QA, then commit+push to experimental',
  phases: [
    { title: 'Verify', detail: 'skeptical check of each group: real? helpful? harmful?' },
    { title: 'Fix', detail: 'one worker per group in its own worktree, master reviews each' },
    { title: 'Integrate', detail: 'master merges group branches and runs the full suite' },
    { title: 'QA', detail: 'independent QA pass; master fixes and re-QA on failure' },
    { title: 'Ship', detail: 'master updates docs, commits, pushes to experimental' },
  ],
}

const ROOT = '/Users/blackbird/Everything/dev/2_Ongoing/ThrottleIQ'
const DOCS = `${ROOT}/DOCS/Handoff for agents and Todos`
const INT = '/Users/blackbird/Everything/dev/2_Ongoing/ThrottleIQ-audit101'
const INT_BRANCH = 'audit-101-integration'

const GROUPS = [
  { id: 'G1', items: '101.S1, 101.S3, 101.S11', files: 'firestore.rules, firestore.indexes.json, scripts/test/rules/' },
  { id: 'G2', items: '101.S6', files: 'database.rules.json, app/lib/core/realtime/, scripts/test/rtdb/' },
  { id: 'G3', items: '101.S2 (the index fieldOverrides themselves belong to G1 only if G1 owns firestore.indexes.json — G3 must NOT edit firestore.indexes.json; instead document exactly which overrides are needed in its report), 101.S4, 101.S5', files: 'functions/' },
  { id: 'G4', items: '101.S7, 101.S8, 101.S9, 101.S10, 101.D3 (.gitignore part only)', files: 'firebase.json (headers only), public/, scripts/deploy.sh and scripts/*.js guards, .github/, .gitignore' },
  { id: 'G5', items: '101.A1, 101.A2, 101.A3, 101.A4 (non-a11y parts)', files: 'app/lib/features/auth, social, chat, forums, settings and their tests' },
  { id: 'G6', items: '101.C1, 101.C2, 101.C3, 101.C5, 101.C7, 101.C8, 101.C9', files: 'app/lib/core (sync, database, notifications, app.dart, main.dart, router, auto_tracking_service) and their tests' },
  { id: 'G7', items: '101.R1-R8, 101.R10 (includes a shared parseLocalizedNumber)', files: 'app/lib/features ride, routes, navigation, maintenance, garage, stats and their tests' },
  { id: 'G8', items: '101.P1, 101.P2, 101.P3, 101.P5, 101.P6, 101.P7, 101.R9, 101.A4 (a11y/tap-target parts)', files: 'app/lib/features/places, app/lib/core/theme, app/lib/shared/widgets, a11y-only edits elsewhere, and their tests' },
  { id: 'G9', items: '101.B1, 101.B3, 101.B5, 101.B6, 101.B8 (not B2, B4, B7)', files: 'app/test/sync_manager_test.dart, .github/workflows (release-build job only; coordinate: G4 also edits ci.yml — G9 adds ONLY a new job, G4 edits existing jobs/top-level keys), app/android, app/ios/Runner/Info.plist, app/analysis_options.yaml, app/pubspec.yaml' },
  { id: 'G10', items: '101.D2, 101.D3 (doc parts only, not .gitignore)', files: 'README.md, DOCS/ (except docs/pitch.md, which is off-limits). Do NOT edit issues_open.md §101 entries or todo §10 — the master updates those at the end.' },
]

const COMMON = `
Project: ThrottleIQ, a Flutter app (app/), Firebase rules (firestore.rules, database.rules.json), Cloud Functions (functions/), ops scripts and rules tests (scripts/).
Main checkout: ${ROOT}. The audit is in "${DOCS}/issues_open.md" section "## 101." (read the entries for your group there; line numbers in it are approximate).
IMPORTANT CONTEXT: this audit and the fix list came from an UNRELIABLE agent. Its claims may be wrong, already fixed, unnecessary, or its suggested fix may be harmful (e.g. a rules tightening that would break writes the real client makes, a CI change that breaks the pipeline, a colour change that is really a design decision, deleting tests that should be fixed instead). Trust the code, not the audit.
Hard rules: NEVER deploy anything (no firebase deploy, no scripts/deploy.sh, no *:execute scripts, nothing touching the live project throttleiqfb). Never commit secrets or gitignored files (google-services.json, key.properties, secret/, secrets/, keystores, qa_seed_passwords*). Never edit docs/pitch.md. Do not push. Founder-only items (101.B2, B4, B7, C4, C6, C10, P4, S12-S14, D1, A5) are out of scope.
Emulators: firebase.json uses firestore 8080, database 9000, auth 9099. Other agents may be running emulators at the same time; if a port is busy, wait a minute and retry rather than killing someone else's process.
CI constraints to respect: flutter analyze must be fully clean (info lints too); no raw "] as double" casts in app/lib; count of "catch (_)" in app/lib must not go above 67.`

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    group: { type: 'string' },
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          verdict: { type: 'string', enum: ['real-fix', 'real-but-skip', 'not-real', 'already-fixed', 'harmful-as-suggested'] },
          evidence: { type: 'string', description: 'file:line and what the code actually does' },
          fix_plan: { type: 'string', description: 'safe concrete fix and the test that proves it; empty if not fixing' },
          skip_reason: { type: 'string' },
        },
        required: ['id', 'verdict', 'evidence', 'fix_plan', 'skip_reason'],
      },
    },
  },
  required: ['group', 'items'],
}

const WORK_SCHEMA = {
  type: 'object',
  properties: {
    worktree_path: { type: 'string' },
    branch: { type: 'string' },
    commit_sha: { type: 'string' },
    fixed: { type: 'array', items: { type: 'string' }, description: 'item id + one-line description of fix and test' },
    not_done: { type: 'array', items: { type: 'string' }, description: 'planned items not completed, with reason' },
    tests_run: { type: 'string', description: 'exact commands and pass/fail counts' },
    notes_for_master: { type: 'string' },
  },
  required: ['worktree_path', 'branch', 'commit_sha', 'fixed', 'not_done', 'tests_run', 'notes_for_master'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    approved: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['approved', 'problems', 'summary'],
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

// ---------- Phase 1+2: verify then fix, pipelined per group ----------
phase('Verify')

const results = await pipeline(
  GROUPS,
  // Stage 1: skeptical verification (read-only)
  g => agent(`${COMMON}

You are the VERIFIER for audit group ${g.id}: items ${g.items}. Expected files: ${g.files}.
READ-ONLY: do not edit any file. Work in ${ROOT}.
For every item (split batch items like C9/R10 into sub-items, e.g. "101.C9-dst", where useful), open the actual code and decide:
- real-fix: the problem is real, fixing it clearly helps, and you have a safe fix plan with a test.
- real-but-skip: real but needs a founder/design decision, a device, a deploy, or is too risky for an unattended change.
- not-real / already-fixed: the claim is wrong or already handled (give evidence).
- harmful-as-suggested: the suggested fix would break something; if a safe alternative exists put it in fix_plan and still mark this verdict.
For rules changes, check every write the Flutter client actually makes to that path (grep app/lib) so tightening can't break the app. Be skeptical and concrete.`,
    { label: `verify:${g.id}`, phase: 'Verify', schema: VERIFY_SCHEMA }),

  // Stage 2: worker fixes in its own worktree, then master review loop
  async (ver, g) => {
    const toFix = ver.items.filter(i => i.fix_plan && (i.verdict === 'real-fix' || i.verdict === 'harmful-as-suggested'))
    if (!toFix.length) { log(`${g.id}: nothing verified to fix`); return { group: g.id, verification: ver, work: null, review: null } }
    const plan = JSON.stringify(toFix, null, 1)
    let work = await agent(`${COMMON}

You are the WORKER for audit group ${g.id}. You are running in an isolated git worktree (your current directory). Stay inside your group's files: ${g.files}.
Implement ONLY these verified fixes (the verifier already checked them against the code):
${plan}

For each fix add or update a test that fails before and passes after. Setup in a fresh worktree: for app work run "flutter pub get" in app/ (if a build needs app/android/app/google-services.json or app/android/local.properties, copy them from ${ROOT} but never git add them); for functions run "npm ci" in functions/; for rules tests run "npm install" in scripts/.
Run the relevant checks for your area: app → "flutter analyze" (must be clean) and the affected test files (run the full "flutter test" once at the end if time allows); functions → its build + tests; rules → "npm run test:rules:ci" / "npm run test:rtdb:ci" in scripts/.
Do NOT edit DOCS/Handoff for agents and Todos/issues_open.md or todo_now_antigravity.md (the master does that) unless you are G10, and even then not the §101 entries or todo §10.
When done, create a branch named "audit101-${g.id.toLowerCase()}" in your worktree and commit your changes there with a conventional message like "fix(${g.id.toLowerCase()}): ..." ending with the line "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Do not push. Report the absolute worktree path (pwd), branch and commit sha.`,
      { label: `work:${g.id}`, phase: 'Fix', isolation: 'worktree', schema: WORK_SCHEMA })
    if (!work) return { group: g.id, verification: ver, work: null, review: null }

    let review = null
    for (let round = 1; round <= 3; round++) {
      review = await agent(`${COMMON}

You are the MASTER reviewer overseeing worker ${g.id}. Verified plan the worker had to implement:
${plan}

Worker report:
${JSON.stringify(work, null, 1)}

Inspect the worker's commit in its worktree (cd "${work.worktree_path}"; git log/show ${work.branch}). Check: every planned item is done or has a valid reason; each fix is correct and does not break other behaviour; tests really assert the fix; it stays inside ${g.files}; no secrets or gitignored files committed; no deploys; analyze/tests actually pass (re-run the relevant ones yourself). Approve only if it is genuinely right.`,
        { label: `master-review:${g.id}#${round}`, phase: 'Fix', schema: REVIEW_SCHEMA })
      if (!review || review.approved) break
      if (round === 3) break
      log(`${g.id}: master sent back ${review.problems.length} problem(s), rework round ${round}`)
      const re = await agent(`${COMMON}

You are the WORKER for audit group ${g.id}, doing rework. Work in the existing worktree: cd "${work.worktree_path}" (branch ${work.branch}). The master reviewer rejected the change with these problems:
${review.problems.map(p => '- ' + p).join('\n')}

Original verified plan:
${plan}

Fix every problem, re-run the relevant checks, and commit on the same branch (new commit, same message style and Co-Authored-By line). Do not push. Report worktree path, branch and the new head sha.`,
        { label: `rework:${g.id}#${round}`, phase: 'Fix', schema: WORK_SCHEMA })
      if (re) work = re
    }
    return { group: g.id, verification: ver, work, review }
  },
)

const done = results.filter(Boolean)
const approved = done.filter(r => r.work && r.review && r.review.approved)
const unapproved = done.filter(r => r.work && !(r.review && r.review.approved))
log(`Approved groups: ${approved.map(r => r.group).join(', ') || 'none'}; not approved: ${unapproved.map(r => r.group).join(', ') || 'none'}`)

if (!approved.length) return { results, shipped: false, reason: 'no approved groups' }

// ---------- Phase 3: master integrates ----------
phase('Integrate')
const branches = approved.map(r => `${r.group}: branch ${r.work.branch} (worktree ${r.work.worktree_path}, head ${r.work.commit_sha})`).join('\n')
const integ = await agent(`${COMMON}

You are the MASTER. Integrate the approved group branches into one integration branch.
1. In ${ROOT}: run "git worktree add ${INT} -b ${INT_BRANCH} main" (if the path or branch exists from a prior attempt, inspect it and reuse it sensibly). Do all work in ${INT}. Do NOT touch the main checkout's uncommitted .claude/ changes.
2. Merge each approved branch (they live in this repo's refs since worktrees share the object store):
${branches}
   Resolve conflicts carefully (likely spots: .github/workflows/ci.yml between G4 and G9, firebase.json, shared test helpers). Do NOT merge these unapproved groups: ${unapproved.map(r => r.group).join(', ') || 'none'}.
3. Setup and run the FULL suite in ${INT}: app → flutter pub get, flutter analyze (clean), flutter test (all), plus the CI grep guards (no "] as double" in app/lib, catch (_) count <= 67); functions → npm ci, build, test; scripts → npm install, npm test, npm run test:rules:ci, npm run test:rtdb:ci. (Copy google-services.json/local.properties from ${ROOT} if needed, never commit them.)
4. Fix any integration breakage with minimal commits.
Report: merged groups, conflicts and how resolved, full test results with counts, and any remaining failures.`,
  { label: 'master:integrate', phase: 'Integrate' })

// ---------- Phase 4: QA loop ----------
phase('QA')
const groupSummary = approved.map(r => ({ group: r.group, fixed: r.work.fixed, not_done: r.work.not_done, plan: r.verification.items.filter(i => i.fix_plan).map(i => i.id) }))
let qa = null
for (let round = 1; round <= 3; round++) {
  qa = await agent(`${COMMON}

You are the independent QA agent. The master integrated audit §101 fixes on branch ${INT_BRANCH} in worktree ${INT} (base: main). Review "git diff main...${INT_BRANCH}" in full and run the complete suite yourself there: flutter analyze, flutter test, the CI grep guards, functions build+tests, scripts npm test + test:rules:ci + test:rtdb:ci.
What each group claims to have fixed:
${JSON.stringify(groupSummary, null, 1)}
Master's integration report:
${integ}
Check for: regressions, rules changes that would block writes the Flutter client really makes (grep app/lib for each tightened path), behaviour changes nobody asked for, weak or fake tests, committed secrets/gitignored files, anything deploy-related, CI YAML validity. Do not edit files. pass=true only if there are no blocking issues.`,
    { label: `qa#${round}`, phase: 'QA', schema: QA_SCHEMA })
  if (!qa || qa.pass) break
  if (round === 3) break
  log(`QA round ${round} failed with ${qa.blocking_issues.length} blocking issue(s); master fixing`)
  await agent(`${COMMON}

You are the MASTER. QA rejected the integration branch ${INT_BRANCH} (worktree ${INT}) with these blocking issues:
${qa.blocking_issues.map(p => '- ' + p).join('\n')}
Fix each one (or revert the offending change if it can't be fixed safely), re-run the full suite, and commit on ${INT_BRANCH}. Do not push. Report what you changed.`,
    { label: `master:qa-fix#${round}`, phase: 'QA' })
}

if (!qa || !qa.pass) return { results, integ, qa, shipped: false, reason: 'QA did not pass' }

// ---------- Phase 5: ship ----------
phase('Ship')
const skipped = done.flatMap(r => r.verification.items.filter(i => !(i.fix_plan && (i.verdict === 'real-fix' || i.verdict === 'harmful-as-suggested'))).map(i => ({ id: i.id, verdict: i.verdict, why: i.skip_reason || i.evidence })))
const ship = await agent(`${COMMON}

You are the MASTER. QA passed. Final steps, all in worktree ${INT} on branch ${INT_BRANCH}:
1. Update docs in "DOCS/Handoff for agents and Todos/": in issues_open.md §101 mark each fixed item FIXED (short note on fix + test) and annotate items found not-real/already-fixed/harmful with the evidence; move fully fixed items to issues_fixed.md if that is the file's convention; tick the done groups in todo_now_antigravity.md §10; add a short HANDOFF_Document.md entry. Do not touch docs/pitch.md.
   Fixed per group: ${JSON.stringify(groupSummary, null, 1)}
   Not fixed / rejected by verification: ${JSON.stringify(skipped, null, 1)}
   Groups not approved by master review: ${unapproved.map(r => r.group).join(', ') || 'none'}
   QA non-blocking notes: ${JSON.stringify(qa.non_blocking_notes)}
2. Commit the docs ("docs(audit): mark §101 fixes ..." with the Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com> line). Check "git status" shows nothing secret or gitignored staged.
3. Push to the remote experimental branch: "git fetch origin experimental" then confirm origin/experimental is an ancestor of HEAD ("git merge-base --is-ancestor origin/experimental HEAD"). If yes: "git push origin ${INT_BRANCH}:experimental". If NOT an ancestor, do NOT force-push: merge origin/experimental into ${INT_BRANCH}, re-run flutter analyze + flutter test, then push normally. Never use --force.
4. Leave the worktrees in place (do not delete branches). Report the pushed sha, the commit list (git log --oneline origin/main..HEAD) and anything left undone.`,
  { label: 'master:ship', phase: 'Ship' })

return { results, integ, qa, ship, shipped: true }
