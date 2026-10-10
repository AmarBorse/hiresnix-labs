#!/usr/bin/env node
// Brand hygiene gate (npm run check:hygiene, also run in CI): the project was forked and rebranded, so the
// upstream product's name, domain and repo must not creep back into code, docs or comments. The attribution
// that the MIT license requires lives in LICENSE and NOTICE.md, which are exempt.
// The banned names are assembled from fragments so this file passes its own check.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const J = (...parts) => parts.join('');
const BANNED = [J('de', 'bo[ -]?labs'), J('de', 'bo', 'istech'), J('de', 'bois-tech'), J('\\bde', 'bo\\b')].map((p) => new RegExp(p, 'i'));
const EXEMPT = new Set(['LICENSE', 'NOTICE.md', 'package-lock.json']);
const SKIP_EXT = new Set(['.png', '.jpg', '.jpeg', '.gif', '.ico', '.woff', '.woff2']);
const SKIP_DIRS = new Set(['.git', 'node_modules']);
const root = path.join(__dirname, '..');
const hits = [];

// Tracked + untracked-but-not-ignored files when this is a git checkout; otherwise (a ZIP download) walk the tree.
function listFiles() {
  try {
    return execFileSync('git', ['ls-files', '-co', '--exclude-standard'], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
      .split('\n').filter(Boolean);
  } catch {
    const out = [];
    (function walk(dir) {
      for (const e of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
        const rel = dir ? `${dir}/${e.name}` : e.name;
        if (e.isDirectory()) { if (!SKIP_DIRS.has(e.name)) walk(rel); } else out.push(rel);
      }
    })('');
    return out;
  }
}

function scan(label, text) {
  text.split('\n').forEach((line, i) => {
    for (const re of BANNED) if (re.test(line)) hits.push(`${label}:${i + 1}: matches /${re.source}/i`);
  });
}

const files = listFiles();
for (const f of files) {
  if (EXEMPT.has(f) || SKIP_EXT.has(path.extname(f).toLowerCase()) || f.includes('/fixture/image/')) continue;
  let text;
  try { text = fs.readFileSync(path.join(root, f), 'utf8'); } catch { continue; }
  scan(f, text);
}

const mi = process.argv.indexOf('--message');
if (mi > -1) scan(`commit message (${process.argv[mi + 1]})`, fs.readFileSync(process.argv[mi + 1], 'utf8'));

if (hits.length) {
  console.error('Brand hygiene check failed - the upstream name must not appear outside LICENSE/NOTICE.md:\n  ' + hits.join('\n  '));
  process.exit(1);
}
console.log(`Brand hygiene OK (${files.length} files checked).`);
