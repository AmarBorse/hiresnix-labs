// The command guide: which commands a step's text mentions, and that every shipped glossary entry is usable.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const { loadCatalog, commandsFor } = require('../../src/loader');

const G = {
  ls: { what: 'lists', how: 'h', example: 'ls -la' }, wc: { what: 'counts', how: 'h', example: '' },
  git: { what: 'git', how: 'h', example: '' }, 'git commit': { what: 'saves', how: 'h', example: '' },
  'runs-on': { what: 'runner', how: 'h', example: '' }, FROM: { what: 'base', how: 'h', example: '' },
};

test('commandsFor finds commands in inline code and fences, every part of a pipeline, in order, without duplicates', () => {
  const names = (t) => commandsFor(t, G).map((c) => c.name);
  assert.deepEqual(names('Run `ls | wc -l`, then `ls` again.'), ['ls', 'wc']);
  assert.deepEqual(names('```\n$ git commit -m x\ngit log\n```'), ['git commit', 'git']);
  assert.deepEqual(names('Set `runs-on: ubuntu-latest` and start with `FROM`.'), ['runs-on', 'FROM']);
  assert.deepEqual(names('Plain words like ls or wc do not count, nor `unknowncmd`.'), []);
  assert.equal(commandsFor('`ls`', G)[0].example, 'ls -la');
});

test('every lab step gets a command guide from the shipped glossaries, and the glossaries load without problems', () => {
  const catalog = loadCatalog(path.join(__dirname, '..', '..', 'labs'));
  assert.deepEqual(catalog.problems, []);
  const steps = catalog.tracks.flatMap((t) => t.labs.flatMap((l) => l.steps));
  assert.ok(steps.every((s) => Array.isArray(s.commands)));
  assert.ok(steps.filter((s) => s.commands.length).length > steps.length / 2, 'most steps explain at least one command');
  for (const c of steps.flatMap((s) => s.commands)) {
    assert.ok(c.what.length > 10 && c.how.length > 10, `${c.name}: what and how are filled in`);
  }
  const nav = catalog.tracks.find((t) => t.id === 'linux-fundamentals').labs.find((l) => l.id === 'navigating').steps[0];
  assert.deepEqual(nav.commands.map((c) => c.name), ['pwd', 'ls', 'cd', 'cat']);
});
