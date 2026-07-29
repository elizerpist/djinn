import assert from 'node:assert/strict';
import { createPlanetInputRouter } from '../assets/explore/planet-input-router.js';

const trace = [];
const activated = [];
let emptyTapCount = 0;
let now = 0;
const gestures = new Map();
const canvas = {
  captured: new Set(),
  setPointerCapture(pointerId) { this.captured.add(pointerId); },
  hasPointerCapture(pointerId) { return this.captured.has(pointerId); },
  releasePointerCapture(pointerId) { this.captured.delete(pointerId); },
};
const router = createPlanetInputRouter({
  canvas,
  runtimeFor: () => ({ gestures }),
  isEnabled: () => true,
  now: () => now,
  pick: () => 'pao2',
  activate: (cityId) => activated.push(cityId),
  onEmptyTap: () => { emptyTapCount += 1; },
  trace: (event, payload) => trace.push({ event, ...payload }),
});

router.onPointerDown({ pointerId: 1, clientX: 4, clientY: 6, button: 0 });
now = 120;
router.onPointerUp({ pointerId: 1, clientX: 4, clientY: 6 });
assert.deepEqual(activated, ['pao2']);
assert.equal(gestures.size, 0);
assert.ok(trace.some((entry) => entry.event === 'pointer.tap'));

router.onPointerDown({ pointerId: 11, clientX: 4, clientY: 6, button: 0 });
now = 150;
router.onPointerUp({ pointerId: 11, clientX: 4, clientY: 6 });
assert.equal(emptyTapCount, 0, 'a city hit must not clear the selection');
assert.deepEqual(activated, ['pao2', 'pao2'], 'a second valid city tap must remain available for repeat-tap dehighlight');

const missRouter = createPlanetInputRouter({
  canvas,
  runtimeFor: () => ({ gestures }),
  isEnabled: () => true,
  now: () => now,
  pick: () => null,
  activate: () => { throw new Error('a miss must not activate a city'); },
  onEmptyTap: () => { emptyTapCount += 1; },
  trace: (event, payload) => trace.push({ event, ...payload }),
});
missRouter.onPointerDown({ pointerId: 12, clientX: 7, clientY: 8, button: 0 });
now = 180;
missRouter.onPointerUp({ pointerId: 12, clientX: 7, clientY: 8 });
assert.equal(emptyTapCount, 1, 'a short blank-globe tap must clear a selected city context');

const deferredRouter = createPlanetInputRouter({
  canvas,
  runtimeFor: () => ({ gestures }),
  isEnabled: () => true,
  now: () => now,
  pick: () => undefined,
  activate: () => { throw new Error('a not-ready pick must not activate a city'); },
  onEmptyTap: () => { throw new Error('a not-ready pick must not clear the current city context'); },
  trace: (event, payload) => trace.push({ event, ...payload }),
});
deferredRouter.onPointerDown({ pointerId: 13, clientX: 7, clientY: 8, button: 0 });
now = 210;
deferredRouter.onPointerUp({ pointerId: 13, clientX: 7, clientY: 8 });
assert.ok(trace.some((entry) => entry.event === 'pointer.tap.defer'),
  'a temporary empty hit-target registry must defer the tap instead of clearing selection');

router.onPointerDown({ pointerId: 2, clientX: 1, clientY: 1, button: 0 });
router.onPointerMove({ pointerId: 2, clientX: 20, clientY: 1 });
now = 180;
router.onPointerUp({ pointerId: 2, clientX: 20, clientY: 1 });
assert.deepEqual(activated, ['pao2', 'pao2'], 'a drag must never become a city tap');
assert.ok(trace.some((entry) => entry.event === 'pointer.tap.reject'));

router.onPointerDown({ pointerId: 3, clientX: 1, clientY: 1, button: 0 });
router.onPointerDown({ pointerId: 4, clientX: 1, clientY: 1, button: 0 });
now = 220;
router.onPointerUp({ pointerId: 3, clientX: 1, clientY: 1 });
assert.deepEqual(activated, ['pao2', 'pao2'], 'a pinch cycle must never become a city tap');
router.clear();
assert.equal(gestures.size, 0);

console.log('planet input router OK');
