'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const S = require('../oneoff/strip_cloudinary_exif.js');

const seg = (marker, payload) => {
  const len = Buffer.alloc(2);
  len.writeUInt16BE(payload.length + 2);
  return Buffer.concat([Buffer.from([0xff, marker]), len, payload]);
};
const SOI = Buffer.from([0xff, 0xd8]);
const SOS = Buffer.from([0xff, 0xda, 0x00, 0x02, 0x11, 0x22]);
const jfif = seg(0xe0, Buffer.from('JFIF\0\x01\x01'));

const chunk = (type, data = Buffer.alloc(0)) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  return Buffer.concat([len, Buffer.from(type, 'latin1'), data, Buffer.alloc(4)]);
};
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

test('a JPEG with an EXIF or IPTC segment needs stripping; a clean one does not', () => {
  assert.equal(S.hasMetadata(Buffer.concat([SOI, jfif, seg(0xe1, Buffer.from('Exif\0\0GPS')), SOS])), true);
  assert.equal(S.hasMetadata(Buffer.concat([SOI, jfif, seg(0xed, Buffer.from('Photoshop 3.0')), SOS])), true);
  assert.equal(S.hasMetadata(Buffer.concat([SOI, jfif, SOS])), false);
  // Bytes after the scan starts are pixel data, even if they look like a marker.
  assert.equal(S.hasMetadata(Buffer.concat([SOI, jfif, SOS, Buffer.from([0xff, 0xe1, 0, 4, 1, 2])])), false);
});

test('a PNG with eXIf or text chunks needs stripping; a clean one does not', () => {
  assert.equal(S.hasMetadata(Buffer.concat([PNG, chunk('IHDR', Buffer.alloc(13)), chunk('eXIf', Buffer.from('MM')), chunk('IEND')])), true);
  assert.equal(S.hasMetadata(Buffer.concat([PNG, chunk('IHDR', Buffer.alloc(13)), chunk('tEXt', Buffer.from('a\0b')), chunk('IEND')])), true);
  assert.equal(S.hasMetadata(Buffer.concat([PNG, chunk('IHDR', Buffer.alloc(13)), chunk('IDAT', Buffer.alloc(5)), chunk('IEND')])), false);
});

test('an unknown format is re-encoded rather than skipped', () => {
  assert.equal(S.hasMetadata(Buffer.from('RIFF....WEBPVP8X')), true);
});

test('the re-upload is signed over its params, not over file or api_key', () => {
  const form = S.reuploadForm({
    publicId: 'avatars/u1/abc', secureUrl: 'https://res.cloudinary.com/x/image/upload/v1/avatars/u1/abc.jpg',
    apiKey: 'k', apiSecret: 's', timestamp: 1700000000,
  });
  assert.equal(form.transformation, 'fl_force_strip');
  assert.equal(form.overwrite, 'true');
  assert.equal(form.invalidate, 'true');
  assert.equal(form.public_id, 'avatars/u1/abc');
  const expected = crypto.createHash('sha256')
    .update('invalidate=true&overwrite=true&public_id=avatars/u1/abc&timestamp=1700000000&transformation=fl_force_strip' + 's')
    .digest('hex');
  assert.equal(form.signature, expected);
});

test('avatars go first; dry run is the default; --folder is checked', () => {
  assert.equal(S.FOLDERS[0], 'avatars');
  assert.equal(S.parseArgs([]).apply, false);
  assert.deepEqual(S.parseArgs(['--folder=bikes']).folders, ['bikes']);
  assert.throws(() => S.parseArgs(['--folder=voice']), /--folder/);
  assert.throws(() => S.parseArgs(['--aply']), /Unknown argument/);
});
