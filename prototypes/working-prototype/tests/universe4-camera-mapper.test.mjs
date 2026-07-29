import assert from 'node:assert/strict';
import {
  mapForceCameraSnapshotToGlobePov,
  mapForceCameraToGlobePov,
  mapGlobeCameraSnapshotToForceCamera,
  measureCssRadius,
  projectWorldToCss,
  solveAltitudeForCssRadius,
} from '../assets/universe4/universe4-camera-mapper.js';

const converterCalls = [];
const mapped = mapForceCameraToGlobePov({
  forceCamera: {
    worldPosition: { x: 10, y: 5, z: 0 },
    fov: 37,
    aspect: 1.5,
    near: 0.1,
    far: 500,
  },
  planet: {
    worldPosition: { x: 10, y: 0, z: 0 },
    // 90° around Z: local +X is world +Y.
    worldQuaternion: { x: 0, y: 0, z: Math.SQRT1_2, w: Math.SQRT1_2 },
    visualRadius: 5,
  },
  globeRadius: 100,
  toGeoCoords(position) {
    converterCalls.push(position);
    return { lat: 14, lng: -38, altitude: .5 };
  },
});

assert.deepEqual(mapped.forceRelativeCameraPosition, { x: 0, y: 5, z: 0 });
assert.deepEqual(mapped.planetLocalCameraPosition, { x: 5, y: 0, z: 0 });
assert.deepEqual(mapped.globeLocalCameraPosition, { x: 100, y: 0, z: 0 });
assert.deepEqual(converterCalls, [{ x: 100, y: 0, z: 0 }]);
assert.deepEqual(mapped.pointOfView, { lat: 14, lng: -38, altitude: .5 });
assert.deepEqual(mapped.camera, { fov: 37, aspect: 1.5, near: .1, far: 500 });

const capturedMapping = mapForceCameraSnapshotToGlobePov({
  forceCameraSnapshot: {
    cameraPosition: { x: 10, y: 5, z: 0 },
    planetWorldCenter: { x: 10, y: 0, z: 0 },
    planetWorldQuaternion: { x: 0, y: 0, z: Math.SQRT1_2, w: Math.SQRT1_2 },
    planetVisualRadius: 5,
    fov: 37,
    aspect: 1.5,
    near: .1,
    far: 500,
  },
  globeRadius: 100,
  toGeoCoords: () => ({ lat: 14, lng: -38, altitude: .5 }),
});
assert.deepEqual(capturedMapping.planetLocalCameraPosition, { x: 5, y: 0, z: 0 });

const returnedForceCamera = mapGlobeCameraSnapshotToForceCamera({
  globeCameraSnapshot: {
    cameraPosition: { x: 40, y: -20, z: 160 },
    cameraQuaternion: { x: 0, y: 0, z: 0, w: 1 },
    cameraUp: { x: 0, y: 1, z: 0 },
    fov: 42,
    aspect: 1.2,
    near: .4,
    far: 1400,
    controlsTarget: { x: 0, y: 0, z: 0 },
    globeRadius: 100,
  },
  planet: {
    worldPosition: { x: 10, y: 20, z: 30 },
    worldQuaternion: { x: 0, y: 0, z: 0, w: 1 },
    visualRadius: 20,
  },
});
assert.deepEqual(returnedForceCamera.cameraPosition, { x: 18, y: 16, z: 62 });
assert.deepEqual(returnedForceCamera.controlsTarget, { x: 10, y: 20, z: 30 });
assert.deepEqual(returnedForceCamera.cameraQuaternion, { x: 0, y: 0, z: 0, w: 1 });
assert.equal(returnedForceCamera.fov, 42);

const cssPoint = projectWorldToCss({
  worldPosition: { x: 2, y: -1, z: .5 },
  viewport: { width: 400, height: 200 },
  project: () => ({ x: .25, y: -.5, z: .2 }),
});
assert.deepEqual(cssPoint, { x: 250, y: 150, ndcZ: .2, visible: true });
assert.equal(measureCssRadius({ x: 100, y: 100 }, { x: 160, y: 180 }), 100);

const altitudeMatch = solveAltitudeForCssRadius({
  targetRadius: 125,
  minAltitude: .2,
  maxAltitude: 4,
  // The exact visual function is irrelevant to the solver; it only relies on
  // the monotonic Globe.gl fact that a higher altitude makes the globe smaller.
  measureRadius: (altitude) => 500 / (1 + altitude),
  iterations: 18,
});
assert.ok(Math.abs(altitudeMatch.altitude - 3) < .001);
assert.ok(Math.abs(altitudeMatch.radius - 125) < .05);
assert.ok(altitudeMatch.deltaPercent < .05);

assert.throws(() => solveAltitudeForCssRadius({
  targetRadius: 0,
  minAltitude: .2,
  maxAltitude: 4,
  measureRadius: () => 1,
}), /targetRadius/);

console.log('universe4 camera mapper OK');
