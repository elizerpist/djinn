import assert from 'node:assert/strict';
import {
  PIXEL_MATCH_TOLERANCES,
  validatePixelMatch,
} from '../assets/universe4/universe4-pixel-match.js';

assert.deepEqual(PIXEL_MATCH_TOLERANCES, {
  centerPx: 1,
  radiusPercent: .75,
  landmarkRmsPx: 2,
  landmarkPx: 3,
});

const matching = validatePixelMatch({
  inline: {
    center: { x: 200, y: 300 },
    radius: 100,
    landmarks: [
      { id: 'north', x: 200, y: 200 },
      { id: 'east', x: 300, y: 300 },
      { id: 'south', x: 200, y: 400 },
    ],
  },
  globe: {
    center: { x: 201, y: 300 },
    radius: 100.75,
    landmarks: [
      { id: 'north', x: 202, y: 200 },
      { id: 'east', x: 300, y: 302 },
      { id: 'south', x: 198, y: 400 },
    ],
  },
});

assert.equal(matching.valid, true);
assert.equal(matching.centerDeltaPx, 1);
assert.equal(matching.radiusDeltaPercent, .75);
assert.equal(matching.maxLandmarkDeltaPx, 2);
assert.equal(matching.landmarkRmsDeltaPx, 2);
assert.deepEqual(matching.failures, []);

const rmsMismatch = validatePixelMatch({
  inline: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [
      { id: 'one', x: 0, y: 0 },
      { id: 'two', x: 10, y: 0 },
      { id: 'three', x: 20, y: 0 },
    ],
  },
  globe: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [
      { id: 'one', x: 2.1, y: 0 },
      { id: 'two', x: 12.1, y: 0 },
      { id: 'three', x: 22.1, y: 0 },
    ],
  },
});
assert.equal(rmsMismatch.valid, false);
assert.equal(rmsMismatch.landmarkRmsDeltaPx, 2.1);
assert.deepEqual(rmsMismatch.failures, ['landmark-rms']);

const insufficientLandmarks = validatePixelMatch({
  inline: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [{ id: 'one', x: 0, y: 0 }, { id: 'two', x: 4, y: 0 }],
  },
  globe: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [{ id: 'one', x: 0, y: 0 }, { id: 'two', x: 4, y: 0 }],
  },
});
assert.equal(insufficientLandmarks.valid, false);
assert.deepEqual(insufficientLandmarks.failures, ['landmark-count']);

const landmarkMismatch = validatePixelMatch({
  inline: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [
      { id: 'stable', x: 0, y: 0 },
      { id: 'other-one', x: 10, y: 0 },
      { id: 'other-two', x: 20, y: 0 },
    ],
  },
  globe: {
    center: { x: 0, y: 0 },
    radius: 100,
    landmarks: [
      { id: 'stable', x: 3.01, y: 0 },
      { id: 'other-one', x: 10, y: 0 },
      { id: 'other-two', x: 20, y: 0 },
    ],
  },
});

assert.equal(landmarkMismatch.valid, false);
assert.equal(landmarkMismatch.maxLandmarkDeltaPx, 3.01);
assert.deepEqual(landmarkMismatch.failures, ['landmark:stable']);

console.log('universe4 pixel match OK');
