import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const styles = await readFile(new URL('assets/styles.css', root), 'utf8');
const exploreStyles = await readFile(new URL('assets/explore-discovery.css', root), 'utf8');
const universeGraphData = await readFile(new URL('assets/universe4/universe4-graph-data.js', root), 'utf8');
const universeGlobeStage = await readFile(new URL('assets/universe4/universe4-globe-stage.js', root), 'utf8');
const screenFiles = [
  'screens/home.html',
  'screens/profile.html',
  'screens/djinn.html',
  'screens/query-answer.html',
  'screens/query-evidence.html',
  'screens/query-process.html',
  'screens/query-sources.html',
  'screens/query.html',
  'screens/workspace-library.html',
  'screens/workspace-note-detail.html',
  'screens/workspace-notes.html',
  'screens/workspace-source-detail.html',
  'screens/workspace-topic-files.html',
  'screens/workspace-topic-notes.html',
  'screens/workspace-topic-overview.html',
  'screens/workspace-topics.html',
  'screens/partials/explore-concepts.html',
  'screens/partials/explore-connections.html',
  'screens/partials/explore-overview.html',
];
const markup = (await Promise.all(screenFiles.map((path) => readFile(new URL(path, root), 'utf8')))).join('\n');
const classesFor = (className) => [...markup.matchAll(/class="([^"]*)"/g)].map((match) => match[1]).filter((classAttribute) => classAttribute.split(/\s+/).includes(className));

assert.match(styles, /\.card\s*\{[^}]*padding:\s*var\(--card-block-padding\)\s+var\(--card-padding\)/s);
assert.match(styles, /\.card\s*\{[^}]*border-radius:\s*var\(--card-radius\)/s);
assert.match(styles, /\.card\s*\{[^}]*gap:\s*var\(--card-gap\)/s);
assert.match(styles, /--card-padding:\s*12px/);
assert.match(styles, /--card-radius:\s*15px/);
assert.match(styles, /--card-height-scale:\s*1\.1/);
assert.match(styles, /--card-block-padding:\s*calc\(var\(--card-padding\) \* var\(--card-height-scale\)\)/);
assert.match(styles, /--type-card-title-size:\s*var\(--type-size-11\)/);
assert.match(styles, /--type-card-body-size:\s*var\(--type-size-10\)/);
assert.match(styles, /--type-card-meta-size:\s*var\(--type-size-9\)/);
assert.match(styles, /--type-card-caption-size:\s*var\(--type-size-8\)/);
assert.match(styles, /--type-label-size:\s*var\(--type-size-8\)/);
assert.match(styles, /--type-menu-header-size:\s*var\(--type-size-19\)/);
assert.match(styles, /--type-menu-subheader-size:\s*var\(--type-size-15\)/);
assert.match(styles, /--type-menu-child-size:\s*var\(--type-size-10\)/);
assert.match(styles, /--type-menu-child-meta-size:\s*var\(--type-size-8\)/);
assert.match(styles, /--icon-card-size:\s*34px/);
assert.match(styles, /--icon-card-glyph-size:\s*18px/);
assert.match(styles, /--icon-action-size:\s*35px/);
assert.match(styles, /--icon-navigation-size:\s*34px/);
assert.match(styles, /\.topic-card strong, \.source-card strong, \.note-card strong, \.info-card strong\s*\{[^}]*font-size:\s*var\(--type-card-title-size\)/s);
assert.match(styles, /\.topic-card small, \.source-card small, \.note-card small, \.info-card small\s*\{[^}]*font-size:\s*var\(--type-card-meta-size\)/s);
assert.match(styles, /\.top-bar h1, \.top-bar h2\s*\{[^}]*font-size:\s*var\(--type-menu-header-size\)/s);
assert.match(styles, /\.card-icon\s*\{[^}]*width:\s*var\(--icon-card-size\)[^}]*height:\s*var\(--icon-card-size\)[^}]*font-size:\s*var\(--icon-card-glyph-size\)/s);
assert.match(styles, /\.shortcut\s*\{[^}]*min-height:\s*calc\(61px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.topic-quick-actions button\s*\{[^}]*min-height:\s*calc\(62px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.query-shortcut-grid \.shortcut\s*\{[^}]*min-height:\s*calc\(66px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.query-suggestion-list button\s*\{[^}]*min-height:\s*calc\(40px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.query-answer-actions button\s*\{[^}]*min-height:\s*calc\(54px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.query-source-compare article\s*\{[^}]*min-height:\s*calc\(153px \* var\(--card-height-scale\)\)/s);
assert.match(styles, /\.djinn-command\s*\{[^}]*min-height:\s*calc\(59px \* var\(--card-height-scale\)\)/s);
assert.match(exploreStyles, /\.explore-route-card, \.explore-concept-list > button\s*\{[^}]*min-height:\s*calc\(59px \* var\(--card-height-scale\)\)/s);
assert.match(exploreStyles, /explore-spotlight/);
assert.doesNotMatch(markup.match(/class="[^"]*explore-spotlight[^"]*"/)?.[0] ?? '', /\bcard\b/);
assert.match(universeGraphData, /class="card map-world-card/);
assert.match(universeGraphData, /class="card map-note-card/);
assert.match(universeGlobeStage, /class="card galaxy-node-morph-overlay/);

for (const className of [
  'topic-card',
  'source-card',
  'note-card',
  'info-card',
  'djinn-context-card',
  'topic-summary',
  'metric-grid',
  'shortcut',
  'topic-quick-action',
  'djinn-command',
  'query-evidence-card',
  'query-source-card',
  'query-answer-summary',
  'query-answer-action',
  'query-process-note',
  'query-compare-table',
  'query-suggestion-card',
  'answer',
  'explore-path',
  'explore-route-card',
  'explore-concept-card',
  'explore-connection-card',
]) {
  assert.match(markup, new RegExp(`class="[^"]*\\bcard\\b[^"]*\\b${className}\\b`), `${className} must use the shared card primitive`);
}

for (const className of ['shortcut', 'topic-quick-action', 'djinn-command']) {
  for (const classAttribute of classesFor(className)) {
    assert.match(classAttribute, /\bcard\b/, `${className} must use the shared card primitive in every occurrence`);
  }
}

console.log('shared card style contract OK');
