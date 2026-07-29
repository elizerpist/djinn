import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const prototypeUrl = new URL('./djinn-navigation-prototype.html', import.meta.url);

test('a Djinn prototípus minden referencia szerinti fő- és Query-gyermeknézetet deklarál', async () => {
  const html = await readFile(prototypeUrl, 'utf8');

  const routes = [
    'home',
    'explore-overview',
    'query-start',
    'query-scope',
    'query-ready',
    'query-thinking',
    'query-answer',
    'query-chunks',
    'query-related',
    'query-contradictions',
    'query-compare',
    'query-flowchart',
    'workspace',
  ];

  for (const route of routes) {
    assert.match(
      html,
      new RegExp(`data-screen=["']${route}["']`),
      `Hiányzó nézet: ${route}`,
    );
  }

  assert.match(html, /history\.pushState/);
  assert.match(html, /hashchange/);
  assert.match(html, /aria-label=/);
});
