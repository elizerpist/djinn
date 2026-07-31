import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import * as THREE from '../assets/vendor/three.module.min.js?universe-cosmic-integration-test';
import { CosmicEnvironment } from '../assets/cosmic-environment.js?universe-cosmic-integration-test';

function createCamera() {
  const camera = new THREE.PerspectiveCamera(45, 1, .1, 3000);
  camera.position.set(0, 0, 480);
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld(true);
  return camera;
}

const scene = new THREE.Scene();
const camera = createCamera();
const universeEnvironment = new CosmicEnvironment({
  THREE,
  scene,
  getCamera: () => camera,
  getPlanetCenter: (target) => target.set(0, 0, 0),
  getPlanetRadius: () => 18,
  // The universe lighting may keep this virtual direction, but production no
  // longer renders a visible sun object or depends on a Lensflare proxy.
  getWorldSunDirection: (target) => target.set(.58, .31, .75).normalize(),
  getLensFlareController: () => null,
  planetId: 'universe-v3-visible-sun',
});
universeEnvironment.initialize();
universeEnvironment.resume();
universeEnvironment.updateFrame(0);

const snapshot = universeEnvironment.getDebugSnapshot();
assert.equal(snapshot.pointsObjectCount, 3, 'Universe needs three batched, world-space star layers');
assert.equal(universeEnvironment.sunRoot, null, 'Universe production must not render a visible sun object');
assert.ok(Object.values(universeEnvironment.starLayers).every((layer) => layer.material.isPointsMaterial), 'Universe stars need the reliable native PointsMaterial path');
universeEnvironment.dispose();

const universeSource = await readFile(new URL('../assets/universe4/universe4-force-controller.js', import.meta.url), 'utf8');
assert.match(universeSource, /import\s+\{\s*CosmicEnvironment\s*\}/, 'the real Universe renderer must import the shared cosmic environment');
assert.match(universeSource, /let\s+universeCosmicEnvironment\b/, 'the real Universe renderer needs one owned cosmic environment instance');
assert.match(universeSource, /ensureUniverseCosmicEnvironment/, 'Universe must construct the environment in its ForceGraph scene');
assert.match(universeSource, /universeCosmicEnvironment\?\.updateFrame\(now\)/, 'Universe must update cosmic visibility in its existing frame loop');
assert.match(universeSource, /universeCosmicEnvironment\?\.dispose\(\)/, 'Universe route disposal must free the cosmic scene objects');
assert.doesNotMatch(universeSource, /VirtualSunLensFlareController/, 'Universe must render stars without a flare controller');

console.log('universe cosmic integration OK');
