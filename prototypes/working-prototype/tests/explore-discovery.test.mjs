import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const discovery = await readFile(new URL('../assets/explore-discovery.js', import.meta.url), 'utf8');
const screen = await readFile(new URL('../screens/explore.html', import.meta.url), 'utf8');

assert.match(index, /data-route="explore"/);
assert.match(index, /assets\/explore-discovery\.css\?rev=5/);
assert.match(app, /explore: 'screens\/explore\.html'/);
assert.match(app, /initExploreDiscovery\(root\)/);
assert.match(discovery, /data-explore-tab/);
assert.match(discovery, /activate\('overview'\)/);
assert.match(screen, /data-explore-discovery/);
assert.match(screen, /data-explore-panel="overview"/);
assert.match(screen, /data-explore-panel="concepts"/);
assert.match(screen, /data-explore-panel="connections"/);
assert.match(screen, /data-explore-focus="oxygen_delivery"/);
assert.match(screen, /data-route="universe"/);
assert.doesNotMatch(screen, /explore-galaxy-slot|data-galaxy-anchor|explore-galaxy-orb/);
assert.doesNotMatch(index, /explore-galaxy-orb-root|explore-galaxy-inline/);
assert.doesNotMatch(app, /initExpandableGalaxyOrb|galaxyOrb|knowledge-map/);

console.log('Explore discovery menu OK');
