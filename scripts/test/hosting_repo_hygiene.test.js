// Static guards for hosting headers, public/ pages, deploy.sh staging, CI
// workflow and .gitignore (issues §101.S7-S10, §101.D3). No emulator or
// network needed; runs under `npm test`.
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8');

test('hosting serves nosniff, anti-framing and referrer headers on every path', () => {
  const hosting = JSON.parse(read('firebase.json')).hosting;
  const all = (hosting.headers || []).find((h) => h.source === '**');
  assert.ok(all, 'hosting.headers needs a "**" entry');
  const byKey = Object.fromEntries(all.headers.map((h) => [h.key.toLowerCase(), h.value]));
  assert.equal(byKey['x-content-type-options'], 'nosniff');
  assert.equal(byKey['x-frame-options'], 'DENY');
  // frame-ancestors only: a full CSP would need auditing every CDN the live
  // viewer loads (unpkg, gstatic, OSM tiles).
  assert.equal(byKey['content-security-policy'], "frame-ancestors 'none'");
  // Not no-referrer: the OSM tile policy needs a Referer. This one sends only
  // the origin cross-site, so the /live/<token> path never leaks.
  assert.equal(byKey['referrer-policy'], 'strict-origin-when-cross-origin');
});

test('public/install.html is a redirect to /install, not a second copy', () => {
  const html = read('public/install.html');
  assert.match(html, /http-equiv="refresh"[^>]*url=\/install"/);
  assert.ok(html.length < 3000, 'install.html should be a small redirect stub');
});

test('install page has no links to files public/ does not have', () => {
  const html = read('public/install/index.html');
  assert.doesNotMatch(html, /\.\.\/assets\//);
  assert.doesNotMatch(html, /\.\.\/index\.html/);
  // Every root-relative / parent-relative local href or src must exist.
  const refs = [...html.matchAll(/(?:href|src)="((?:\/|\.\.\/)[^"#?]*)"/g)].map((m) => m[1]);
  const rewrites = new Set(['/install', '/install/']);
  for (const ref of refs) {
    if (rewrites.has(ref)) continue;
    const rel = ref.replace(/^(\.\.\/|\/)/, '');
    assert.ok(fs.existsSync(path.join(ROOT, 'public', rel)), `missing public/${rel} (from ${ref})`);
  }
  assert.ok(fs.existsSync(path.join(ROOT, 'public', 'icon-dark.svg')));
});

function stagingBlock() {
  const sh = read('scripts/deploy.sh');
  assert.doesNotMatch(sh, /git add -A\b/, 'deploy.sh must not stage untracked files');
  assert.doesNotMatch(sh, /git add (\.|--all)(\s|$)/);
  const start = sh.indexOf('UNTRACKED_FILES=');
  assert.ok(start >= 0, 'deploy.sh must check for untracked files before committing');
  const end = sh.indexOf('\nfi\n', sh.indexOf('git add -u', start));
  assert.ok(end > start, 'staging block not found');
  // Stop before the commit so the test never creates commits.
  return sh.slice(start, end).replace(/\n\s*git commit[^\n]*/, '') + '\nfi\n';
}

function scratchRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'deploy-stage-'));
  const git = (...args) => execFileSync('git', args, { cwd: dir, stdio: 'pipe' }).toString();
  git('init', '-q');
  git('config', 'user.email', 't@example.com');
  git('config', 'user.name', 't');
  fs.writeFileSync(path.join(dir, 'pubspec.yaml'), 'version: 1\n');
  git('add', 'pubspec.yaml');
  git('commit', '-qm', 'init');
  return { dir, git };
}

test('deploy.sh staging aborts when there are untracked files', () => {
  const block = stagingBlock();
  const { dir, git } = scratchRepo();
  fs.writeFileSync(path.join(dir, 'pubspec.yaml'), 'version: 2\n');
  fs.writeFileSync(path.join(dir, '.env.production'), 'SECRET=1\n');
  const r = spawnSync('bash', ['-euo', 'pipefail', '-c', block], { cwd: dir, encoding: 'utf8' });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /\.env\.production/);
  assert.equal(git('diff', '--cached', '--name-only').trim(), '');
});

test('deploy.sh staging stages only tracked changes on a clean-untracked tree', () => {
  const block = stagingBlock();
  const { dir, git } = scratchRepo();
  fs.writeFileSync(path.join(dir, 'pubspec.yaml'), 'version: 2\n');
  const r = spawnSync('bash', ['-euo', 'pipefail', '-c', block], { cwd: dir, encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(git('diff', '--cached', '--name-only').trim(), 'pubspec.yaml');
});

test('CI workflow is read-only and pins firebase-tools', () => {
  const yml = read('.github/workflows/ci.yml');
  assert.match(yml, /^permissions:\n {2}contents: read\n/m);
  assert.doesNotMatch(yml, /npm install -g firebase-tools\s*$/m);
  assert.match(yml, /npm install -g firebase-tools@\d+/);
});

test('.gitignore covers worktrees, .env variants and .p12 keys', () => {
  // check-ignore also reads the unshared .git/info/exclude, so assert the
  // shared file itself carries the worktrees pattern.
  assert.match(read('.gitignore'), /^\.claude\/worktrees\/$/m);
  const ignored = ['.claude/worktrees/x', '.env.production', 'a.p12', 'app/android/upload.p12'];
  for (const p of ignored) {
    const r = spawnSync('git', ['check-ignore', '-q', '--no-index', p], { cwd: ROOT });
    assert.equal(r.status, 0, `${p} should be ignored`);
  }
  const r = spawnSync('git', ['check-ignore', '-q', '--no-index', '.env.example'], { cwd: ROOT });
  assert.equal(r.status, 1, '.env.example must stay committable');
});
