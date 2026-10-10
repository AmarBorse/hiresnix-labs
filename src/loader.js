// Reads the community-contributed content in labs/ and validates its shape.
//   labs/<track>/track.yaml                  title, description, labs: [lab ids in order]
//   labs/<track>/<lab>/lab.yaml              title, level, minutes, summary, steps: [...]
//   labs/<track>/<lab>/setup.sh              optional: seeds the learner's fresh home
//   labs/<track>/<lab>/checks/<step>.sh      grading script for a task step
//   labs/<track>/<lab>/solutions/<step>.sh   one command per line; proves the lab is solvable
//   labs/glossary.yaml, labs/<track>/glossary.yaml   the command guide shown under each step (see commandsFor)
const fs = require('fs');
const path = require('path');
const { httpsUrl, readYaml } = require('./util');
const { renderMarkdown } = require('./markdown');

const ID_RE = /^[a-z0-9][a-z0-9-]{0,48}$/;
const LEVELS = ['beginner', 'intermediate', 'advanced'];

function loadLab(labsDir, trackId, labId, problems) {
  const dir = path.join(labsDir, trackId, labId);
  const file = path.join(dir, 'lab.yaml');
  const raw = readYaml(file, problems);
  if (!raw) return null;
  const where = `${trackId}/${labId}`;
  const bad = (msg) => { problems.push(`${where}: ${msg}`); return null; };

  if (typeof raw.title !== 'string' || !raw.title.trim()) return bad('title is required');
  if (!LEVELS.includes(raw.level)) return bad(`level must be one of ${LEVELS.join(', ')}`);
  if (!Array.isArray(raw.steps) || raw.steps.length === 0) return bad('steps must be a non-empty list');

  const seen = new Set();
  const steps = [];
  for (const [n, s] of raw.steps.entries()) {
    const tag = `step ${n + 1}`;
    if (!s || !ID_RE.test(s.id || '')) return bad(`${tag}: id must match ${ID_RE}`);
    if (seen.has(s.id)) return bad(`${tag}: duplicate id "${s.id}"`);
    seen.add(s.id);
    if (s.type !== 'lesson' && s.type !== 'task') return bad(`step "${s.id}": type must be lesson or task`);
    if (typeof s.title !== 'string' || typeof s.body !== 'string') return bad(`step "${s.id}": title and body are required`);
    if (s.local_body !== undefined && typeof s.local_body !== 'string') return bad(`step "${s.id}": local_body must be text`);
    if (s.success !== undefined && (typeof s.success !== 'string' || s.success.length > 100)) return bad(`step "${s.id}": success must be text of at most 100 characters`);
    const step = {
      id: s.id, type: s.type, title: s.title, body: s.body, bodyHtml: renderMarkdown(s.body), hint: s.hint || '',
      // Optional confirmation shown in green when the task's check passes (default: "Correct. Step complete.").
      success: s.success || '',
      // Optional wording for the laptop profile (e.g. "there is no cluster here"); same checks.
      localBodyHtml: s.local_body ? renderMarkdown(s.local_body) : null, localBody: s.local_body || '',
    };
    if (s.type === 'task') {
      step.checkFile = path.join(dir, 'checks', `${s.id}.sh`);
      step.solutionFile = path.join(dir, 'solutions', `${s.id}.sh`);
      if (!fs.existsSync(step.checkFile)) return bad(`task "${s.id}": missing checks/${s.id}.sh`);
      if (!fs.existsSync(step.solutionFile)) return bad(`task "${s.id}": missing solutions/${s.id}.sh`);
    }
    steps.push(step);
  }
  const links = [];
  for (const l of Array.isArray(raw.links) ? raw.links : []) {
    if (!l || typeof l.title !== 'string' || !httpsUrl(l.url)) return bad('links[] need a title and an https:// url');
    links.push({ title: l.title, url: l.url });
  }
  const resources = [];
  for (const r of Array.isArray(raw.resources) ? raw.resources : []) {
    if (!r || typeof r.title !== 'string' || !httpsUrl(r.url)) return bad('resources[] need a title and an https:// url');
    resources.push({ title: r.title, url: r.url, desc: r.desc || '' });
  }
  return {
    track: trackId, id: labId, dir, title: raw.title, level: raw.level,
    minutes: Number(raw.minutes) || 10, summary: raw.summary || '', steps, links, resources,
  };
}

// --- Command guide -----------------------------------------------------------------
// glossary.yaml maps a command (or "git commit", or a Dockerfile/workflow word) to { what, how, example } in simple
// English. A track's own glossary.yaml adds to or overrides the shared one.
const GLOSSARY_KEY = /^[A-Za-z.][A-Za-z0-9._+-]*( [a-z-]+)?$/;
function loadGlossary(file, problems) {
  if (!fs.existsSync(file)) return {};
  const raw = readYaml(file, problems);
  if (!raw || typeof raw !== 'object') return {};
  const out = {};
  for (const [key, e] of Object.entries(raw)) {
    const where = `${path.basename(path.dirname(file))}/glossary.yaml: "${key}"`;
    if (!GLOSSARY_KEY.test(key)) { problems.push(`${where}: not a valid command name`); continue; }
    if (!e || typeof e.what !== 'string' || typeof e.how !== 'string') { problems.push(`${where}: needs "what" and "how" text`); continue; }
    out[key] = { what: e.what.trim(), how: e.how.trim(), example: typeof e.example === 'string' ? e.example.trim() : '' };
  }
  return out;
}

// The commands a step's text mentions in `code` (inline or fenced) that the glossary explains, in order, at most 8.
// Pipelines and chains count every part (`ls | wc -l` -> ls, wc); "git commit" beats "git"; a trailing ':' is ignored
// so workflow keys like `runs-on:` match.
const MULTI = new Set(['git', 'docker', 'npm']);
function commandsFor(text, glossary) {
  const snippets = [];
  for (const m of String(text).matchAll(/```[^\n]*\n([\s\S]*?)```/g)) snippets.push(...m[1].split('\n'));
  for (const m of String(text).replace(/```[\s\S]*?```/g, '').matchAll(/`([^`\n]+)`/g)) snippets.push(m[1]);
  const found = [];
  for (const snip of snippets) {
    for (const part of snip.split(/\|\||&&|\||;|\$\(/)) {
      const words = part.trim().replace(/^\$\s+/, '').replace(/^sudo\s+/, '').split(/\s+/);
      const first = (words[0] || '').replace(/:$/, '');
      if (!first) continue;
      const two = MULTI.has(first) && words[1] ? `${first} ${words[1]}` : '';
      const key = two && glossary[two] ? two : (glossary[first] ? first : '');
      if (key && !found.includes(key)) found.push(key);
    }
  }
  return found.slice(0, 8).map((name) => ({ name, ...glossary[name] }));
}

function loadCatalog(labsDir) {
  const problems = [];
  const tracks = [];
  const shared = loadGlossary(path.join(labsDir, 'glossary.yaml'), problems);
  let entries = [];
  try { entries = fs.readdirSync(labsDir, { withFileTypes: true }); } catch (e) { problems.push(`${labsDir}: ${e.message}`); }
  for (const ent of entries.filter((e) => e.isDirectory()).sort((a, b) => a.name.localeCompare(b.name))) {
    if (!ID_RE.test(ent.name)) { problems.push(`${ent.name}: track folder name must match ${ID_RE}`); continue; }
    const raw = readYaml(path.join(labsDir, ent.name, 'track.yaml'), problems);
    if (!raw) continue;
    if (typeof raw.title !== 'string' || !Array.isArray(raw.labs)) { problems.push(`${ent.name}/track.yaml: title and labs[] are required`); continue; }
    const labs = [];
    for (const labId of raw.labs) {
      if (!ID_RE.test(String(labId))) { problems.push(`${ent.name}/track.yaml: bad lab id "${labId}"`); continue; }
      const lab = loadLab(labsDir, ent.name, String(labId), problems);
      if (lab) labs.push(lab);
    }
    const glossary = { ...shared, ...loadGlossary(path.join(labsDir, ent.name, 'glossary.yaml'), problems) };
    for (const lab of labs) for (const step of lab.steps) step.commands = commandsFor(`${step.body}\n${step.localBody || ''}`, glossary);
    tracks.push({ id: ent.name, order: Number.isFinite(raw.order) ? raw.order : 100, title: raw.title, description: raw.description || '', labs });
  }
  // Learning order first (track.yaml `order:`), then alphabetical.
  tracks.sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
  return { tracks, problems };
}

module.exports = { loadCatalog, commandsFor, ID_RE, LEVELS };
