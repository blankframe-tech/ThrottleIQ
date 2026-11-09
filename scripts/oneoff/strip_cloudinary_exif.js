#!/usr/bin/env node
'use strict';

/**
 * strip_cloudinary_exif.js — one-off: remove EXIF/XMP/IPTC metadata (GPS
 * position, camera serial, timestamp) from images already on Cloudinary.
 *
 * Builds before the metadata-stripping upload path sent photos as picked, and
 * Cloudinary serves an original exactly as uploaded at its secure_url. This
 * lists every image in the app's folders (avatars first), downloads each
 * original, and re-uploads the ones that still carry metadata in place: the
 * same public_id, `overwrite` + `invalidate`, with the incoming
 * transformation `fl_force_strip`, which clears all metadata from the stored
 * file. URLs already in Firestore keep working.
 *
 * Credentials come from the environment and are never printed:
 *   CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET (Cloudinary console >
 *   Settings > API Keys; the same pair the account-erasure function uses).
 *
 * Safety:
 *   - Dry run is the DEFAULT: lists and downloads only, prints counts.
 *   - Writes need --apply plus a typed confirmation.
 *   - Idempotent: an image with no metadata left is skipped.
 *   - Only the image folders the app writes are touched; voice notes
 *     (video/upload) are not.
 *
 * Usage (from scripts/):
 *   CLOUDINARY_API_KEY=... CLOUDINARY_API_SECRET=... node oneoff/strip_cloudinary_exif.js
 *   CLOUDINARY_API_KEY=... CLOUDINARY_API_SECRET=... node oneoff/strip_cloudinary_exif.js --apply
 *   Add --folder=avatars to do one folder at a time.
 */

const crypto = require('node:crypto');
const fs = require('node:fs');

const CLOUD = 'vjvcigkt';
const CONFIRMATION_PHRASE = 'STRIP EXIF';
/** Folders the app uploads images to (<kind>/<uid>), most exposed first. */
const FOLDERS = ['avatars', 'rideShares', 'forumPhotos', 'bikes', 'places'];

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

/** Cloudinary signature: sorted `k=v` pairs joined by `&`, secret appended, SHA-256 (Cloudinary accepts it alongside SHA-1 by default, no account setting needed). */
function sign(params, secret) {
  const base = Object.keys(params).sort().map((k) => `${k}=${params[k]}`).join('&');
  return crypto.createHash('sha256').update(base + secret).digest('hex');
}

/**
 * True when an image still carries metadata worth stripping: a JPEG APP1
 * (EXIF or XMP) or APP13 (IPTC) segment, or a PNG eXIf/iTXt/tEXt/zTXt chunk.
 * Unknown formats count as "yes", so they get re-encoded rather than skipped.
 */
function hasMetadata(buf) {
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i + 4 <= buf.length && buf[i] === 0xff) {
      const marker = buf[i + 1];
      if (marker === 0xda || marker === 0xd9) return false; // image data starts
      if (marker === 0xe1 || marker === 0xed) return true;
      i += 2 + buf.readUInt16BE(i + 2);
    }
    return false;
  }
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (buf.length > 8 && buf.subarray(0, 8).equals(png)) {
    let i = 8;
    while (i + 8 <= buf.length) {
      const len = buf.readUInt32BE(i);
      const type = buf.toString('latin1', i + 4, i + 8);
      if (['eXIf', 'iTXt', 'tEXt', 'zTXt'].includes(type)) return true;
      if (type === 'IEND') return false;
      i += 12 + len;
    }
    return false;
  }
  return true;
}

/** The signed form fields that re-upload `publicId` from its own URL, stripped. */
function reuploadForm({ publicId, secureUrl, apiKey, apiSecret, timestamp }) {
  const params = {
    invalidate: 'true',
    overwrite: 'true',
    public_id: publicId,
    timestamp: String(timestamp),
    transformation: 'fl_force_strip',
  };
  return { ...params, file: secureUrl, api_key: apiKey, signature: sign(params, apiSecret) };
}

function parseArgs(argv) {
  const opts = { apply: false, folders: FOLDERS, nonInteractive: false, help: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--apply') opts.apply = true;
    else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg === '--dry-run') { /* the default */ }
    else if (arg.startsWith('--folder=')) {
      const f = arg.slice('--folder='.length);
      if (!FOLDERS.includes(f)) throw new Error(`--folder must be one of ${FOLDERS.join(', ')}.`);
      opts.folders = [f];
    } else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  return opts;
}

async function listFolder(folder, auth) {
  const out = [];
  let cursor = null;
  do {
    const qs = new URLSearchParams({ prefix: `${folder}/`, max_results: '500', ...(cursor ? { next_cursor: cursor } : {}) });
    const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD}/resources/image/upload?${qs}`, {
      headers: { Authorization: `Basic ${auth}` },
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error(`Listing ${folder} returned ${res.status}`);
    const json = await res.json();
    out.push(...(json.resources ?? []));
    cursor = json.next_cursor ?? null;
  } while (cursor);
  return out;
}

async function confirm(nonInteractive) {
  if (nonInteractive) return;
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(`  Type "${CONFIRMATION_PHRASE}" to continue: `);
  rl.close();
  if (answer.trim() !== CONFIRMATION_PHRASE) fail('Confirmation did not match. Nothing was changed.');
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
    return;
  }
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!apiKey || !apiSecret) fail('Set CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET.');
  const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');

  const todo = [];
  for (const folder of opts.folders) {
    const assets = await listFolder(folder, auth);
    let tagged = 0;
    for (const a of assets) {
      const res = await fetch(a.secure_url, { signal: AbortSignal.timeout(30000) });
      if (!res.ok) { console.log(`  skip ${a.public_id}: download returned ${res.status}`); continue; }
      if (hasMetadata(Buffer.from(await res.arrayBuffer()))) {
        tagged++;
        todo.push(a);
      }
    }
    console.log(`  ${folder}: ${assets.length} images, ${tagged} still carry metadata.`);
  }
  if (!opts.apply) {
    console.log(`  Dry run: nothing changed. Re-run with --apply to strip ${todo.length} images.`);
    return;
  }
  if (todo.length === 0) return;
  await confirm(opts.nonInteractive);

  let failed = 0;
  for (const [i, a] of todo.entries()) {
    const form = reuploadForm({
      publicId: a.public_id, secureUrl: a.secure_url, apiKey, apiSecret, timestamp: Math.floor(Date.now() / 1000),
    });
    const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD}/image/upload`, {
      method: 'POST', body: new URLSearchParams(form), signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) { failed++; console.log(`  failed ${a.public_id}: ${res.status}`); }
    if ((i + 1) % 25 === 0 || i + 1 === todo.length) console.log(`  Stripped ${i + 1 - failed}/${todo.length}`);
  }
  console.log(failed ? `  Done with ${failed} failures; re-run to retry them.` : '  Done. A dry run should now report 0.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = { sign, hasMetadata, reuploadForm, parseArgs, FOLDERS };
