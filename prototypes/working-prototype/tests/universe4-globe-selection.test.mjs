import assert from 'node:assert/strict';
import { GLOBE_CITY_ROLE, resolveUniverse4GlobeTap } from '../assets/universe4/universe4-globe-selection.js';

const selection = {
  selectedCityId: 'root',
  selectedCityArcData: [
    { sourceCityId: 'root', targetCityId: 'sibling-a' },
    { sourceCityId: 'sibling-b', targetCityId: 'root' },
  ],
};

const idle = resolveUniverse4GlobeTap({ cityId: 'foreign', selection: { selectedCityId: null, selectedCityArcData: [] } });
assert.deepEqual(idle, { action: 'select-root', role: GLOBE_CITY_ROLE.FOREIGN, cityId: 'foreign', rootCityId: null, contextCityIds: [] });

const root = resolveUniverse4GlobeTap({ cityId: 'root', selection });
assert.equal(root.action, 'enter-map', 'a second tap on the selected mother city must enter the focused map, never dehighlight');
assert.equal(root.role, GLOBE_CITY_ROLE.ROOT);
assert.deepEqual(root.contextCityIds, ['sibling-a', 'sibling-b']);

const sibling = resolveUniverse4GlobeTap({ cityId: 'sibling-a', selection });
assert.equal(sibling.action, 'enter-map');
assert.equal(sibling.role, GLOBE_CITY_ROLE.CONTEXT);
assert.equal(sibling.rootCityId, 'root');

const foreign = resolveUniverse4GlobeTap({ cityId: 'foreign', selection });
assert.equal(foreign.action, 'clear-context');
assert.equal(foreign.role, GLOBE_CITY_ROLE.FOREIGN);
assert.equal(foreign.consume, true, 'first foreign tap must not fall through into a replacement selection');

const blank = resolveUniverse4GlobeTap({ cityId: null, selection });
assert.equal(blank.action, 'clear-context');
assert.equal(blank.role, GLOBE_CITY_ROLE.BACKGROUND);

console.log('universe4 globe selection OK');
