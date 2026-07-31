import assert from 'node:assert/strict';
import {
  createUniverse4TangentPlane,
  interpolateUniverse4SurfacePoint,
} from '../assets/universe4/universe4-tangent-plane.js';

const projector = createUniverse4TangentPlane({ lat: 0, lng: 0 });
const anchor = projector.project({ id: 'anchor', lat: 0, lng: 0 });
assert.deepEqual(anchor.plane, { x: 0, y: 0 });

const east = projector.project({ id: 'east', lat: 0, lng: 10 });
const north = projector.project({ id: 'north', lat: 10, lng: 0 });
assert.ok(east.plane.x > 0, 'east must remain on the right of the local map');
assert.ok(north.plane.y < 0, 'north must remain above the local map');

const sphere = { x: 1, y: 2, z: 3 };
const plane = { x: 4, y: 6, z: 8 };
assert.deepEqual(interpolateUniverse4SurfacePoint(sphere, plane, 0), sphere);
assert.deepEqual(interpolateUniverse4SurfacePoint(sphere, plane, 1), plane);
assert.deepEqual(interpolateUniverse4SurfacePoint(sphere, plane, .5), { x: 2.5, y: 4, z: 5.5 });

console.log('universe4 tangent plane OK');
