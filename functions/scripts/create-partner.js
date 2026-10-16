#!/usr/bin/env node
'use strict';

/**
 * create-partner.js: issue a partner (e.g. Maya Ride) an API key and a
 * webhook signing secret for the partner API (src/partner-api).
 *
 * Writes partners/{id} and partnerKeys/{sha256(key)}. The key itself is
 * printed ONCE and never stored; lose it and you issue a new one. To revoke a
 * key, set partnerKeys/{hash}.active = false (live within 5 minutes).
 *
 * Usage (from functions/, after `npm run build`):
 *   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/throttleiqfb-admin.json
 *   node scripts/create-partner.js --project=throttleiqfb --id=maya --name="Maya Ride" \
 *     --webhook=https://ops.mayaride.com.bd/throttleiq-alerts      # dry run
 *   ... --yes-i-really-mean-it                                       # writes
 *
 * --webhook is optional (alerts are then stored only); it must be https.
 * Re-running for an existing id adds another key and keeps the old ones.
 */

const { randomBytes } = require('node:crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { sha256 } = require('../lib/partner-api/core');

function arg(name) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : undefined;
}

async function main() {
  const project = arg('project');
  const id = arg('id');
  const name = arg('name') ?? id;
  const webhook = arg('webhook');
  const write = process.argv.includes('--yes-i-really-mean-it');
  if (!project) throw new Error('--project is required');
  if (!id || !/^[a-z0-9-]{2,32}$/.test(id)) throw new Error('--id must be 2-32 of a-z 0-9 -');
  if (webhook && !/^https:\/\/[^\s]+$/.test(webhook)) throw new Error('--webhook must be an https URL');

  const key = `tiq_${id}_${randomBytes(24).toString('base64url')}`;
  const secret = randomBytes(32).toString('base64url');
  console.log(`partner ${id} (${name}) on ${project}; webhook: ${webhook ?? 'none'}`);
  if (!write) {
    console.log('Dry run. Add --yes-i-really-mean-it to write.');
    return;
  }
  const db = getFirestore(initializeApp({ projectId: project }));
  const partner = db.doc(`partners/${id}`);
  const existing = await partner.get();
  await partner.set(
    {
      name,
      active: true,
      ...(webhook ? { webhookUrl: webhook, webhookSecret: existing.get('webhookSecret') ?? secret } : {}),
      createdAt: existing.get('createdAt') ?? new Date(),
    },
    { merge: true },
  );
  await db.doc(`partnerKeys/${sha256(key)}`).create({ partnerId: id, active: true, createdAt: new Date() });
  console.log('\nGive these to the partner over a private channel. They are not stored and will not be shown again.');
  console.log(`  API key:         ${key}`);
  if (webhook) console.log(`  Webhook secret:  ${existing.get('webhookSecret') ?? secret}`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
