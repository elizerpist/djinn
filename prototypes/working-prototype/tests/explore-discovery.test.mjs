import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const discovery = await readFile(new URL('../assets/explore-discovery.js', import.meta.url), 'utf8');

assert.match(discovery, /data-explore-discovery/);
assert.match(discovery, /\['overview', 'Áttekintés'\]/);
assert.match(discovery, /\['concepts', 'Fogalmak'\]/);
assert.match(discovery, /\['connections', 'Kapcsolatok'\]/);
assert.match(discovery, /tab\.dataset\.exploreTab = id/);
assert.match(discovery, /Mai felfedezés/);
assert.match(discovery, /Folytasd, ahol abbahagytad/);
assert.match(discovery, /Érdekes kapcsolatok/);
assert.match(discovery, /Tudásutak/);
assert.match(discovery, /Növekvő témák/);
assert.match(discovery, /data-route="workspace-topic-connections"/);
assert.match(discovery, /insertAdjacentHTML\('afterend', DISCOVERY_TEMPLATE\)/);
assert.match(index, /assets\/explore-discovery\.css\?rev=1/);
assert.match(app, /import \{ initExploreDiscovery \} from '\.\/explore-discovery\.js\?rev=1';/);
assert.match(app, /normalized === 'explore'[\s\S]*initExploreDiscovery\(root\)/);

console.log('explore discovery dashboard OK');
