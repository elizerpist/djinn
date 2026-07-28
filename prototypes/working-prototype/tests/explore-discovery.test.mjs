import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const discovery = await readFile(new URL('../assets/explore-discovery.js', import.meta.url), 'utf8');
const screen = await readFile(new URL('../screens/explore.html', import.meta.url), 'utf8');
const inlineCss = await readFile(new URL('../assets/explore-galaxy-inline.css', import.meta.url), 'utf8');

assert.match(discovery, /\['overview', 'Áttekintés'\]/);
assert.match(discovery, /\['concepts', 'Fogalmak'\]/);
assert.match(discovery, /\['connections', 'Kapcsolatok'\]/);
assert.match(discovery, /tab\.dataset\.exploreTab = id/);
assert.match(discovery, /activate\('overview'\)/);
assert.doesNotMatch(discovery, /insertAdjacentHTML\('afterend', DISCOVERY_TEMPLATE\)/);
assert.match(screen, /data-explore-discovery/);
assert.doesNotMatch(screen, /data-galaxy-anchor/);
assert.match(screen, /data-explore-panel="overview"/);
assert.match(screen, /data-explore-panel="concepts"/);
assert.match(screen, /data-explore-panel="connections"/);
assert.match(screen, /Mai felfedezés/);
assert.match(screen, /Folytasd, ahol abbahagytad/);
assert.match(screen, /Érdekes kapcsolatok/);
assert.match(screen, /Tudásutak/);
assert.match(screen, /Növekvő témák/);
assert.match(screen, /Fogalmak, amelyek most összeérnek/);
assert.match(screen, /Kapcsolatok, amelyek új kontextust nyitnak/);
assert.match(screen, /Legerősebb/);
assert.match(screen, /Közösségek között/);
assert.match(screen, /data-route="workspace-topic-connections"/);

const overview = screen.slice(
  screen.indexOf('data-explore-panel="overview"'),
  screen.indexOf('data-explore-panel="concepts"'),
);
const concepts = screen.slice(
  screen.indexOf('data-explore-panel="concepts"'),
  screen.indexOf('data-explore-panel="connections"'),
);
const connections = screen.slice(screen.indexOf('data-explore-panel="connections"'));
assert.doesNotMatch(overview, /Érdekes kapcsolatok|Növekvő témák/);
assert.match(overview, /id="explore-featured-path"/);
assert.match(concepts, /id="explore-growing-topics"/);
assert.match(connections, /id="explore-knowledge-paths"/);
assert.match(index, /assets\/explore-discovery\.css\?rev=2/);
assert.match(index, /assets\/explore-galaxy-inline\.css\?rev=3/);
assert.match(index, /assets\/app\.js\?rev=142/);
assert.match(app, /initExpandableGalaxyOrb \} from '\.\/explore-galaxy-orb\.js\?rev=143';/);
assert.match(app, /import \{ initExploreDiscovery \} from '\.\/explore-discovery\.js\?rev=2';/);
assert.match(app, /normalized === 'explore'[\s\S]*initExploreDiscovery\(root\)/);
assert.match(app, /galaxySlot\?\.replaceChildren\(galaxyRoot\)/);
assert.match(inlineCss, /#explore-galaxy-orb-root\.is-inline/);

console.log('explore discovery dashboard OK');
