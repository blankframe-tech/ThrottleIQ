'use strict';

/**
 * One CSV cell for the admin exporters. Rider-written strings that start
 * with = + - @ tab or CR get a leading ' so Excel/Sheets show them as text
 * instead of running them as a formula. Numbers (negative ones too) pass
 * through unchanged.
 */
function csvCell(v) {
  let s = v === undefined || v === null ? '' : String(v);
  if (typeof v !== 'number' && /^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

module.exports = { csvCell };
