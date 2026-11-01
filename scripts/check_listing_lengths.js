#!/usr/bin/env node
'use strict';
// Fails if a Play listing field is over Google's limit.
// Usage: node scripts/check_listing_lengths.js [file.md ...]
// Default: every *.md with field markers in the play_listing_v1 pack.
// Fields are the text between <!-- name --> and <!-- /name --> markers.

const fs = require('node:fs');
const path = require('node:path');

const LIMITS = { title: 30, short: 80, full: 4000, whatsnew: 500 };
const PACK = path.join(__dirname, '..', 'DOCS', 'General', 'Files for Stores',
  'store_listing', 'play_listing_v1');

// shortcut: counts Unicode code points; Play may count Bangla graphemes (fewer), so this errs strict.
const length = (s) => [...s].length;

function checkText(text, label) {
  const problems = [];
  for (const [field, limit] of Object.entries(LIMITS)) {
    const m = text.match(new RegExp(`<!-- ${field} -->\\n([\\s\\S]*?)\\n<!-- /${field} -->`));
    if (!m) { problems.push(`${label}: missing field "${field}"`); continue; }
    const n = length(m[1].trim());
    if (n === 0) problems.push(`${label}: "${field}" is empty`);
    if (n > limit) problems.push(`${label}: "${field}" is ${n} chars, limit ${limit}`);
  }
  return problems;
}

function main(files) {
  if (files.length === 0) {
    files = fs.readdirSync(PACK).filter((f) => f.endsWith('.md'))
      .map((f) => path.join(PACK, f))
      .filter((f) => fs.readFileSync(f, 'utf8').includes('<!-- title -->'));
  }
  let problems = [];
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    const found = checkText(text, path.basename(f));
    problems = problems.concat(found);
    if (found.length === 0) {
      const sizes = Object.keys(LIMITS).map((k) => {
        const m = text.match(new RegExp(`<!-- ${k} -->\\n([\\s\\S]*?)\\n<!-- /${k} -->`));
        return `${k} ${length(m[1].trim())}/${LIMITS[k]}`;
      });
      console.log(`ok ${path.basename(f)}: ${sizes.join(', ')}`);
    }
  }
  problems.forEach((p) => console.error(`FAIL ${p}`));
  return problems.length === 0 && files.length > 0 ? 0 : 1;
}

if (require.main === module) process.exit(main(process.argv.slice(2)));
module.exports = { checkText, LIMITS };
