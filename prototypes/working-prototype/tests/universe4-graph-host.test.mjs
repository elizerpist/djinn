import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const universe = await readFile(new URL('../screens/universe.html', import.meta.url), 'utf8');
const globe = await readFile(new URL('../assets/universe4/universe4-globe-stage.js', import.meta.url), 'utf8');
const sourceStage = await readFile(new URL('../assets/universe4/universe4-v7-source-stage.js', import.meta.url), 'utf8');
const forceStage = await readFile(new URL('../assets/universe4/universe4-force-controller.js', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');

assert.match(index, /data-route="explore"/);
assert.match(index, /assets\/explore-discovery\.css\?rev=5/);
assert.match(app, /explore: 'screens\/explore\.html'/);
assert.match(app, /initExploreDiscovery/);
assert.doesNotMatch(index, /explore-galaxy-orb-root|explore-galaxy-inline/);
assert.doesNotMatch(app, /initExpandableGalaxyOrb|galaxyOrb|initKnowledgeMap/);
assert.doesNotMatch(universe, /Explore|explore/);
assert.match(index, /assets\/vendor\/g6\.min\.js\?rev=92/);
assert.match(index, /assets\/vendor\/globe\.gl\.min\.js\?rev=92/);
assert.match(index, /assets\/vendor\/3d-force-graph\.min\.js\?rev=92/);
assert.match(universe, /data-universe4-force-stage/);
assert.match(universe, /data-universe4-globe-stage/);
assert.match(universe, /data-universe4-g6-stage/);
assert.match(runtime, /createUniverse4G6FocusedMapStage/);
assert.match(runtime, /createUniverse4V7SourceStage/);
assert.match(runtime, /createUniverse4U3Stage/);
assert.match(sourceStage, /universe4-globe-stage\.js\?rev=1/);
assert.match(sourceStage, /controller\.setRoute\('universe'\)/);
assert.match(forceStage, /universe4-globe-stage\.js\?rev=1/);
assert.match(globe, /export function initUniverse4GlobeStage/);
assert.match(globe, /const visible = route === 'universe'/);

console.log('Universe is the sole graph visualization host (Force, Globe.gl, G6)');
