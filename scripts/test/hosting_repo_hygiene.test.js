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
  // frame-ancestors only here; the live viewer gets a full CSP of its own.
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

test('live viewer loads every CDN script and stylesheet with SRI (security sweep D4)', () => {
  const tags = read('public/live-viewer.html').match(/<(?:script|link)\b[^>]*(?:src|href)="https?:[^>]*>/g) || [];
  const urlOf = (t) => new URL(t.match(/(?:src|href)="(https?:[^"]+)"/)[1]);
  assert.equal(tags.filter((t) => urlOf(t).host === 'unpkg.com').length, 2, 'expected the Leaflet css and js tags');
  assert.equal(tags.filter((t) => urlOf(t).host === 'www.gstatic.com' && urlOf(t).pathname.startsWith('/firebasejs/')).length,
    4, 'expected the four Firebase SDK tags');
  for (const tag of tags) {
    assert.match(tag, /integrity="sha384-[A-Za-z0-9+/=]+"/, tag);
    assert.match(tag, /crossorigin="anonymous"/, tag);
  }
});

// The CSP Hosting sends for a path: every header rule that matches it.
function cspFor(urlPath) {
  const { headers = [] } = JSON.parse(read('firebase.json')).hosting;
  return headers
    .filter((h) => h.regex && new RegExp(h.regex).test(urlPath))
    .flatMap((h) => h.headers)
    .filter((h) => h.key.toLowerCase() === 'content-security-policy')
    .map((h) => Object.fromEntries(h.value.split(';').map((d) => d.trim()).filter(Boolean)
      .map((d) => { const [name, ...srcs] = d.split(/\s+/); return [name, srcs]; })));
}

test('live viewer paths get a script/connect CSP that still lets the page run (WL-04)', () => {
  for (const urlPath of ['/live-viewer.html', '/live/abc123def456', '/r/some_rider']) {
    const policies = cspFor(urlPath);
    assert.equal(policies.length, 1, `${urlPath}: expected one viewer CSP rule`);
    const csp = policies[0];
    assert.deepEqual(csp['frame-ancestors'], ["'none'"]);
    assert.deepEqual(csp['object-src'], ["'none'"]);
    assert.deepEqual(csp['base-uri'], ["'none'"]);
    for (const banned of ["'unsafe-inline'", "'unsafe-eval'", '*', 'https:', 'data:']) {
      assert.ok(!csp['script-src'].includes(banned), `script-src must not allow ${banned}`);
    }
    // App Check loads reCAPTCHA Enterprise at runtime; without these every live link breaks.
    for (const src of ["'self'", 'https://www.gstatic.com', 'https://unpkg.com',
      'https://www.google.com/recaptcha/', 'https://www.gstatic.com/recaptcha/']) {
      assert.ok(csp['script-src'].includes(src), `script-src needs ${src}`);
    }
    for (const src of ['https://www.google.com/recaptcha/', 'https://recaptcha.google.com/recaptcha/']) {
      assert.ok(csp['frame-src'].includes(src), `frame-src needs ${src}`);
    }
    for (const src of ["'self'", 'https://*.googleapis.com', 'https://*.firebaseio.com', 'wss://*.firebaseio.com']) {
      assert.ok(csp['connect-src'].includes(src), `connect-src needs ${src}`);
    }
    // The tile URL the viewer actually uses (live-viewer.js).
    for (const [dir, src] of [['img-src', 'https://tile.openstreetmap.org'], ['style-src', 'https://unpkg.com']]) {
      assert.ok(csp[dir].includes(src), `${dir} needs ${src}`);
    }
  }
  assert.equal(cspFor('/privacy.html').length, 0, 'the viewer CSP is scoped to the viewer');
  assert.equal(cspFor('/install').length, 0);
});

test('live viewer has no inline script or inline event handler the CSP would block', () => {
  const html = read('public/live-viewer.html');
  for (const [, attrs, body] of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\b[^>]*>/gi)) {
    assert.match(attrs, /\bsrc="/, 'inline <script> blocks are blocked by script-src');
    assert.equal(body.trim(), '');
  }
  assert.doesNotMatch(html, /<[^>]+\son[a-z]+\s*=/i, 'inline on*= handlers are blocked by script-src');
  assert.doesNotMatch(html, /javascript:/i);
  // Every same-origin script the page loads must exist.
  for (const [, src] of html.matchAll(/<script\b[^>]*src="\/([^"]+)"/g)) {
    assert.ok(fs.existsSync(path.join(ROOT, 'public', src)), `missing public/${src}`);
  }
  const js = read('public/live-viewer.js');
  assert.match(js, /https:\/\/tile\.openstreetmap\.org\//);
});

test('the bare hosting root redirects to /install instead of a 404 (WL-08)', () => {
  const { redirects = [] } = JSON.parse(read('firebase.json')).hosting;
  assert.ok(redirects.some((r) => r.source === '/' && r.destination === '/install' && r.type === 302));
});

test('privacy policy describes the permanent /r/ password link (WL-09)', () => {
  const html = read('public/privacy.html');
  const s6 = html.slice(html.indexOf('<h2>6.'), html.indexOf('<h2>7.'));
  assert.match(s6, /\/r\/@?&lt;handle&gt;/);
  assert.match(s6, /password link/i);
  assert.match(s6, /off by default/i);
  assert.match(s6, /last ride ended/i);
  assert.match(s6, /Privacy &amp; Safety/);
  // Old claims the code does not back.
  assert.doesNotMatch(html, /Bike photos stay on your phone only/);
  assert.doesNotMatch(html, /Cloudinary does not receive your rides, your location/);
  assert.doesNotMatch(html, /cannot be linked back to you or your account, by us or by anyone else/);
});

test('install page claims only what is true (CrtiQue_Oct15 N4)', () => {
  const html = read('public/install/index.html');
  // The old iOS "waitlist" kept emails in the visitor's own browser and said
  // "You're on the list"; nothing reached the owner.
  assert.doesNotMatch(html, /localStorage|sessionStorage/);
  assert.doesNotMatch(html, /on the list/i);
  // "Download tracking" that was only console.log.
  assert.doesNotMatch(html, /console\.log|trackDownload/);
  // The personal Apple team cannot use TestFlight; crash alerts are off.
  assert.doesNotMatch(html, /TestFlight/i);
  assert.doesNotMatch(html, /crash alert/i);
  assert.match(html, /mailto:hello@blankframe\.tech\?subject=ThrottleIQ%20for%20iPhone/);
});

function stagingBlock() {
  const sh = read('scripts/deploy.sh');
  assert.doesNotMatch(sh, /git add -A\b/, 'deploy.sh must not stage untracked files');
  assert.doesNotMatch(sh, /git add (\.|--all)(\s|$)/);
  const start = sh.indexOf('UNTRACKED_FILES=');
  assert.ok(start >= 0, 'deploy.sh must check for untracked files before committing');
  const end = sh.indexOf('\nfi\n', sh.indexOf('git add app/pubspec.yaml', start));
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
  fs.mkdirSync(path.join(dir, 'app'));
  fs.writeFileSync(path.join(dir, 'app/pubspec.yaml'), 'version: 1\n');
  fs.writeFileSync(path.join(dir, 'README.md'), 'x\n');
  git('add', '.');
  git('commit', '-qm', 'init');
  return { dir, git };
}

test('deploy.sh staging aborts when there are untracked files', () => {
  const block = stagingBlock();
  const { dir, git } = scratchRepo();
  fs.writeFileSync(path.join(dir, 'app/pubspec.yaml'), 'version: 2\n');
  fs.writeFileSync(path.join(dir, '.env.production'), 'SECRET=1\n');
  const r = spawnSync('bash', ['-euo', 'pipefail', '-c', block], { cwd: dir, encoding: 'utf8' });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /\.env\.production/);
  assert.equal(git('diff', '--cached', '--name-only').trim(), '');
});

test('deploy.sh staging aborts when other tracked files are dirty', () => {
  const block = stagingBlock();
  const { dir, git } = scratchRepo();
  fs.writeFileSync(path.join(dir, 'app/pubspec.yaml'), 'version: 2\n');
  fs.writeFileSync(path.join(dir, 'README.md'), 'changed\n');
  const r = spawnSync('bash', ['-euo', 'pipefail', '-c', block], { cwd: dir, encoding: 'utf8' });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /README\.md/);
  assert.equal(git('diff', '--cached', '--name-only').trim(), '');
});

test('deploy.sh staging stages only the version bump', () => {
  const block = stagingBlock();
  const { dir, git } = scratchRepo();
  fs.writeFileSync(path.join(dir, 'app/pubspec.yaml'), 'version: 2\n');
  const r = spawnSync('bash', ['-euo', 'pipefail', '-c', block], { cwd: dir, encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(git('diff', '--cached', '--name-only').trim(), 'app/pubspec.yaml');
});

test('deploy.sh stops if the gate changed the tree, before pushing or building (TIQ-DELTA-04)', () => {
  const sh = read('scripts/deploy.sh');
  const gate = sh.indexOf('bash "${REPO_ROOT}/scripts/check.sh"');
  const guard = sh.indexOf('git diff --quiet HEAD ||', gate);
  assert.ok(gate >= 0 && guard > gate, 'tree check must follow check.sh');
  assert.ok(guard < sh.indexOf('git push'), 'tree check must come before the push');
  assert.ok(guard < sh.indexOf('flutter build appbundle'), 'tree check must come before the AAB build');
});

// A clone whose origin is a local bare repo, with a fake npx on PATH that
// records its arguments instead of deploying anything.
function hostingRepo() {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'deploy-hosting-'));
  const origin = path.join(base, 'origin.git');
  const dir = path.join(base, 'work');
  const bin = path.join(base, 'bin');
  const run = (cwd, ...args) => execFileSync('git', args, { cwd, stdio: 'pipe' }).toString();
  run(base, 'init', '-q', '--bare', '-b', 'main', origin);
  run(base, 'clone', '-q', origin, dir);
  const git = (...args) => run(dir, ...args);
  git('config', 'user.email', 't@example.com');
  git('config', 'user.name', 't');
  git('checkout', '-q', '-b', 'main');
  fs.mkdirSync(path.join(dir, 'public'));
  fs.mkdirSync(path.join(dir, 'scripts'));
  fs.copyFileSync(path.join(ROOT, 'scripts/deploy_hosting.sh'), path.join(dir, 'scripts/deploy_hosting.sh'));
  fs.writeFileSync(path.join(dir, 'public/index.html'), 'x\n');
  fs.writeFileSync(path.join(dir, 'firebase.json'), '{}\n');
  git('add', '.');
  git('commit', '-qm', 'init');
  git('push', '-q', 'origin', 'main');
  fs.mkdirSync(bin);
  const log = path.join(base, 'npx.log');
  fs.writeFileSync(path.join(bin, 'npx'), `#!/bin/sh\necho "$@" > "${log}"\n`, { mode: 0o755 });
  const deploy = () => spawnSync('bash', ['scripts/deploy_hosting.sh'], {
    cwd: dir, encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}` },
  });
  return { dir, git, log, deploy };
}

test('deploy_hosting.sh deploys a clean tree whose HEAD is on origin/main', () => {
  const { log, deploy } = hostingRepo();
  const r = deploy();
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(fs.readFileSync(log, 'utf8').trim(),
    'firebase-tools@15 deploy --only hosting --project throttleiqfb');
});

test('deploy_hosting.sh refuses uncommitted public/ or firebase.json changes', () => {
  for (const [file, body] of [['public/index.html', 'changed\n'], ['public/new.html', 'new\n'], ['firebase.json', '{"x":1}\n']]) {
    const { dir, log, deploy } = hostingRepo();
    fs.writeFileSync(path.join(dir, file), body);
    const r = deploy();
    assert.equal(r.status, 1, `${file}: ${r.stdout}${r.stderr}`);
    assert.ok(!fs.existsSync(log), `${file}: must not reach firebase`);
  }
});

test('deploy_hosting.sh refuses a commit that is not on origin/main', () => {
  const { dir, git, log, deploy } = hostingRepo();
  fs.writeFileSync(path.join(dir, 'public/index.html'), 'local only\n');
  git('commit', '-qam', 'unpushed');
  const r = deploy();
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.ok(!fs.existsSync(log));
});

test('CI workflow is read-only and pins firebase-tools', () => {
  const yml = read('.github/workflows/ci.yml');
  assert.match(yml, /^permissions:\n {2}contents: read\n/m);
  assert.doesNotMatch(yml, /npm install -g firebase-tools\s*$/m);
  assert.match(yml, /npm install -g firebase-tools@\d+/);
});

test('workflows pin every action to a commit SHA and run once per PR (#53)', () => {
  const dir = path.join(ROOT, '.github/workflows');
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.yml'))) {
    const yml = read(`.github/workflows/${f}`);
    for (const [, ref] of yml.matchAll(/^\s*(?:- )?uses:\s*(\S+)/gm)) {
      assert.match(ref, /@[0-9a-f]{40}$/, `${f}: ${ref} must be pinned to a full SHA`);
    }
  }
  for (const f of ['ci.yml', 'security.yml']) {
    assert.match(read(`.github/workflows/${f}`), /^ {2}push:\n {4}branches: \[main\]$/m, f);
  }
});

test('pre-push hook drops git env vars before the gate (#55)', () => {
  const hook = read('.githooks/pre-push');
  const unset = hook.indexOf('unset $(git rev-parse --local-env-vars)');
  assert.ok(unset >= 0 && unset < hook.indexOf('scripts/check.sh"'), 'unset must come before check.sh');
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

test('every literal key in public/live-viewer.js is allow-listed in .gitleaks.toml', () => {
  // Google API keys and reCAPTCHA site keys; the config lists exact keys only.
  const keys = read('public/live-viewer.js').match(/AIza[\w-]{35}|6L[\w-]{38}/g) || [];
  assert.ok(keys.length >= 2, 'expected the web API key and the reCAPTCHA site key');
  const allow = read('.gitleaks.toml');
  for (const k of keys) assert.ok(allow.includes(`'''${k}'''`), `${k.slice(0, 6)}... missing from .gitleaks.toml`);
});
