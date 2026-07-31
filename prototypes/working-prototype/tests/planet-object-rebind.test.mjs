import assert from 'node:assert/strict';
import { rebindPlanetObjects } from '../assets/universe4/globe/planet-object-rebind.js';

const calls = [];
const points = [{ id: 'a' }, { id: 'b' }];
const globe = {
  objectsData(value) { calls.push(['objectsData', value]); },
  objectThreeObject(factory) { calls.push(['objectThreeObject', factory]); },
};
let clearCount = 0;
const trace = [];

const result = rebindPlanetObjects({
  globe,
  points,
  clearRegistry: () => { clearCount += 1; },
  createObject: (point) => ({ id: point.id }),
  trace: (event, payload) => trace.push({ event, ...payload }),
  reason: 'variant-rebind',
});

assert.equal(clearCount, 1);
assert.deepEqual(calls.slice(0, 1), [['objectsData', []]],
  'the old Globe.gl object data must be cleared before replacing the registry');
assert.equal(calls[1][0], 'objectThreeObject',
  'a new object factory identity must invalidate the ThreeGlobe object cache');
assert.deepEqual(calls[2], ['objectsData', points],
  'the active points must be committed after the new factory is installed');
assert.deepEqual(result, { expectedTargetCount: 2, reason: 'variant-rebind' });
assert.deepEqual(trace, [{ event: 'node.registry.rebind', reason: 'variant-rebind', expectedTargetCount: 2 }]);

console.log('planet object rebind OK');
