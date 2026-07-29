import assert from 'node:assert/strict';
import { prepareInvisibleGlobeMatch } from '../assets/universe4/universe4-handoff-matcher.js';

const forceFrame = {
  center: { x: 150, y: 210 },
  radius: 80,
  landmarks: [
    { id: 'one', lat: 1, lng: 2, altitude: .01, x: 140, y: 190 },
    { id: 'two', lat: 3, lng: 4, altitude: .01, x: 160, y: 220 },
    { id: 'three', lat: 5, lng: 6, altitude: .01, x: 155, y: 235 },
  ],
};

let passedLandmarks;
let renderedFrames = 0;
const globeStage = {
  applyHandoffPose(frame) {
    assert.equal(frame, forceFrame);
    return { pointOfView: { lat: 12, lng: 28, altitude: 2.1 }, globeOffset: [2, -1] };
  },
  async waitForRenderedFrames(count) {
    renderedFrames = count;
    return count;
  },
  captureHandoffFrame({ landmarks }) {
    passedLandmarks = landmarks;
    return {
      center: { x: 150.5, y: 210 },
      radius: 80.4,
      landmarks: landmarks.map(({ id, x, y }) => ({ id, x: x + 1, y })),
    };
  },
};

const accepted = await prepareInvisibleGlobeMatch({
  forceFrame,
  globeStage,
});
assert.equal(accepted.valid, true);
assert.equal(renderedFrames, 3);
assert.equal(passedLandmarks, forceFrame.landmarks);
assert.equal(accepted.match.centerDeltaPx, .5);
assert.equal(Number(accepted.match.radiusDeltaPercent.toFixed(3)), .5);
assert.equal(accepted.match.landmarkRmsDeltaPx, 1);

const rejected = await prepareInvisibleGlobeMatch({
  forceFrame,
  globeStage: {
    ...globeStage,
    captureHandoffFrame: ({ landmarks }) => ({
      center: { x: 190, y: 210 },
      radius: 80,
      landmarks: landmarks.map(({ id, x, y }) => ({ id, x, y })),
    }),
  },
});
assert.equal(rejected.valid, false);
assert.deepEqual(rejected.match.failures, ['center']);

console.log('universe4 handoff matcher OK');
