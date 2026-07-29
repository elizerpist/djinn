import assert from 'node:assert/strict';
import * as THREE from '../assets/vendor/three.module.min.js?cosmic-environment-test';
import {
  COSMIC_MODES,
  CosmicEnvironment,
} from '../assets/cosmic-environment.js?cosmic-environment-test';

function createCamera() {
  const camera = new THREE.PerspectiveCamera(45, 1, .1, 20000);
  camera.position.set(0, 0, 900);
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld(true);
  return camera;
}

function createEnvironment(planetId = 'planet-oxygen') {
  const scene = new THREE.Scene();
  const camera = createCamera();
  const environment = new CosmicEnvironment({
    THREE,
    scene,
    getCamera: () => camera,
    getPlanetCenter: () => new THREE.Vector3(),
    getPlanetRadius: () => 100,
    getWorldSunDirection: (target) => target.set(.16, .12, -1).normalize(),
    getLensFlareController: () => null,
    planetId,
  });
  environment.initialize();
  environment.resume();
  environment.updateFrame(0);
  return { scene, camera, environment };
}

assert.ok(COSMIC_MODES.includes('cosmic-production'));
assert.ok(COSMIC_MODES.includes('three-depth-shells'));

const first = createEnvironment();
const firstSnapshot = first.environment.getDebugSnapshot();
assert.deepEqual(firstSnapshot.starCounts, [720, 110, 14], 'production stars must stay sparse enough to remain quiet background texture');
assert.equal(firstSnapshot.pointsObjectCount, 3, 'all stars must render through exactly three batched Points objects');
assert.equal(first.environment.root.parent, first.scene, 'cosmic root must be a direct world-scene child');
assert.equal(first.environment.root.position.length(), 0, 'cosmic root must not follow the camera or globe');
assert.equal(first.environment.sunRoot, null, 'V6/V7 production must not retain any visual sun root');
assert.equal(first.scene.children.some((child) => /^Sun|^VirtualSun/.test(child.name || '')), false, 'the scene must have no visual sun body, corona, proxy, or flare object');

const layers = [first.environment.starLayers.far, first.environment.starLayers.mid, first.environment.starLayers.near];
layers.forEach((layer) => {
  assert.ok(layer.points.isPoints, 'each depth shell must remain a single Points draw object');
  assert.ok(layer.material.isPointsMaterial, 'visible stars must use Three.js native PointsMaterial rather than the disappearing custom shader path');
  assert.ok(layer.material.map?.isTexture, 'native points need the shared soft-star texture');
  assert.equal(layer.material.sizeAttenuation, false, 'star dots need screen-stable mobile sizing rather than sub-pixel perspective attenuation');
  assert.ok(layer.material.size >= 2, 'each visible star layer must have at least a two-pixel native point size');
});
assert.ok(firstSnapshot.starOpacities.every((opacity) => opacity >= .1), 'all three star shells must be visible in the default production LOD');

const firstFarPositions = Array.from(first.environment.starLayers.far.geometry.getAttribute('position').array.slice(0, 24));
const second = createEnvironment();
const secondFarPositions = Array.from(second.environment.starLayers.far.geometry.getAttribute('position').array.slice(0, 24));
assert.deepEqual(firstFarPositions, secondFarPositions, 'the same planet seed must recreate the same 3D star field');

const beforeOrbit = Array.from(first.environment.starLayers.near.geometry.getAttribute('position').array.slice(0, 24));
first.camera.position.set(420, 180, 640);
first.camera.lookAt(0, 0, 0);
first.camera.updateMatrixWorld(true);
first.environment.updateFrame(160);
assert.deepEqual(
  Array.from(first.environment.starLayers.near.geometry.getAttribute('position').array.slice(0, 24)),
  beforeOrbit,
  'camera orbit must not rewrite world-star positions to fake parallax',
);

const offOriginScene = new THREE.Scene();
const offOriginCamera = createCamera();
offOriginCamera.position.set(1350, 0, 900);
offOriginCamera.lookAt(1350, 0, 0);
offOriginCamera.updateMatrixWorld(true);
const offOriginEnvironment = new CosmicEnvironment({
  THREE,
  scene: offOriginScene,
  getCamera: () => offOriginCamera,
  getPlanetCenter: (target) => target.set(1350, 0, 0),
  getPlanetRadius: () => 100,
  planetId: 'off-origin-planet',
});
offOriginEnvironment.initialize();
offOriginEnvironment.resume();
offOriginEnvironment.updateFrame(0);
assert.deepEqual(
  offOriginEnvironment.root.position.toArray(),
  [1350, 0, 0],
  'the world-space star shells must be centred on the focused planet, not the scene origin',
);
offOriginEnvironment.dispose();

first.environment.setReducedEffects(true);
first.environment.updateFrame(1000);
const reduced = first.environment.getDebugSnapshot();
assert.ok(reduced.starOpacities[0] > .1, 'reduced effects must keep the far star field');
assert.ok(reduced.starOpacities[1] < .05 && reduced.starOpacities[2] < .05, 'reduced effects must suppress mid and near star layers');

const cosmicRoot = first.environment.root;
const rootBeforeDispose = first.scene.children.includes(cosmicRoot);
first.environment.dispose();
assert.equal(rootBeforeDispose, true);
assert.equal(first.scene.children.includes(cosmicRoot), false, 'dispose must remove the cosmic root without duplicating route resources');
second.environment.dispose();

console.log('cosmic environment OK');
