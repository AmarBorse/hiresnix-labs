// assertBrandedPage(html): the one definition of "this page has the Hiresnix Labs chrome".
// The integration tests call it on every page, so header drift fails CI.
const assert = require('node:assert/strict');

function assertBrandedPage(html, where = '') {
  assert.match(html, /<link rel="stylesheet" href="\/app.css" \/>/, `${where}: app.css not linked`);
  assert.match(html, /<img class="logo-mark" src="\/logo\/hiresnix-logo\.svg"/, `${where}: logo missing`);
  assert.match(html, /<span class="logo-word">Hiresnix <span class="accent">Labs<\/span><\/span>/, `${where}: name missing`);
  assert.ok(!/<nav class="tabs"/.test(html), `${where}: the header has no tabs`);
  // The site link is optional (SITE_URL); when present it must open safely in a new tab.
  const site = html.match(/<a class="btn-site"[^>]*>/);
  if (site) assert.match(site[0], /rel="noopener noreferrer"/, `${where}: site link must be noopener`);
}

module.exports = { assertBrandedPage };
