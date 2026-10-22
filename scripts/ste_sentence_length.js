#!/usr/bin/env node
'use strict';

/**
 * ste_sentence_length.js — ASD-STE100 sentence-length check for a Markdown doc.
 *
 * Limits (STE rules 5.1 and 6.1): a procedural sentence (an instruction that
 * starts with an imperative verb) has 20 words or fewer; a descriptive sentence
 * has 25 or fewer. Code blocks, headings and table separator rows are skipped;
 * each table cell and each prose line is split into sentences on . ? or ! followed by a space (a
 * semicolon or colon does not end a sentence).
 *
 * shortcut: "procedural" = first word is in IMPERATIVES below; add verbs there
 * when a doc uses a new one.
 *
 * Usage:  node scripts/ste_sentence_length.js "DOCS/For Devs and Contributors/architecture/PRD.md"
 *         (exit 1 on a violation)
 */

const fs = require('node:fs');

const IMPERATIVES = new Set(['add', 'build', 'call', 'check', 'choose', 'confirm', 'decide', 'do',
  'install', 'keep', 'make', 'open', 'remove', 'replace', 'run', 'set', 'start', 'stop', 'turn', 'use']);
const LIMIT = { procedural: 20, descriptive: 25 };

/** Words in a sentence: whitespace tokens that contain a letter or digit. */
function words(sentence) {
  return sentence.split(/\s+/).filter((w) => /[\p{L}\p{N}]/u.test(w));
}

function kind(sentence) {
  const first = (words(sentence)[0] || '').toLowerCase().replace(/[^\p{L}-]+$/u, ''); // 'SET-1' is not 'set'
  return IMPERATIVES.has(first) ? 'procedural' : 'descriptive';
}

/** Plain-text units (prose lines and table cells) with their line numbers. */
function units(markdown) {
  const out = [];
  let fence = false;
  markdown.split('\n').forEach((raw, i) => {
    const line = raw.trim();
    if (line.startsWith('```')) { fence = !fence; return; }
    if (fence || !line || line.startsWith('#') || /^\|?[\s:|-]+\|?$/.test(line) || line === '---') return;
    const cells = line.startsWith('|') ? line.split('|').slice(1, -1) : [line];
    for (const c of cells) {
      const text = c.replace(/[*_`>]/g, '').replace(/^\s*(-|\d+\.)\s+/, '').trim();
      if (text) out.push({ line: i + 1, text });
    }
  });
  return out;
}

/** Every sentence over its limit: { line, kind, count, limit, sentence }. */
function violations(markdown) {
  const found = [];
  for (const { line, text } of units(markdown)) {
    for (const s of text.split(/(?<=[.?!])\s+(?=[A-Z0-9"(])/)) {
      const k = kind(s);
      const count = words(s).length;
      if (count > LIMIT[k]) found.push({ line, kind: k, count, limit: LIMIT[k], sentence: s });
    }
  }
  return found;
}

if (require.main === module) {
  const file = process.argv[2];
  if (!file) { console.error('Usage: node ste_sentence_length.js <file.md>'); process.exit(2); }
  const v = violations(fs.readFileSync(file, 'utf8'));
  for (const x of v) console.log(`${file}:${x.line} ${x.kind} ${x.count}/${x.limit}: ${x.sentence}`);
  console.log(`${v.length} sentence(s) over the STE limit.`);
  process.exit(v.length ? 1 : 0);
}

module.exports = { words, kind, units, violations };
