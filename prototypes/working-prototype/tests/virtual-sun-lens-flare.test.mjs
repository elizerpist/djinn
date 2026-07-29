import assert from 'node:assert/strict';
import * as THREE from '../assets/vendor/three.module.min.js?virtual-sun-flare-test';
import {
  FLARE_MODES,
  VirtualSunLensFlareController,
} from '../assets/virtual-sun-lens-flare.js?virtual-sun-flare-test';

function createCamera() {
  const camera = new THREE.PerspectiveCamera(45, 1, .1, 2000);
  camera.position.set(0, 0, 1000);
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld(true);
  return camera;
}

function createController({ sunDirection = new THREE.Vector3(0, 0, 1), renderer = 'webgl' } = {}) {
  const scene = new THREE.Scene();
  const camera = createCamera();
  const controller = new VirtualSunLensFlareController({
    THREE,
    scene,
    getRenderer: () => (renderer === 'webgpu' ? { isWebGPURenderer: true } : { isWebGLRenderer: true }),
    getCamera: () => camera,
    getPlanetCenter: () => new THREE.Vector3(),
    getPlanetRadius: () => 100,
    getWorldSunDirection: (target) => target.copy(sunDirection),
    getUiAttenuation: () => 1,
  });
  controller.initialize();
  controller.resume();
  return { scene, camera, controller };
}

assert.ok(FLARE_MODES.includes('production-cinematic'));
assert.ok(FLARE_MODES.includes('occlusion-proof'));
assert.ok(FLARE_MODES.includes('optical-axis-proof'));
assert.ok(FLARE_MODES.includes('flare-isolation-proof'));

const visible = createController({ sunDirection: new THREE.Vector3(.25, 0, -1) });
await visible.controller.whenReady();
visible.controller.updateFrame(0);
const visibleSnapshot = visible.controller.getDebugSnapshot();
assert.equal(visibleSnapshot.rendererKind, 'webgl');
assert.equal(visibleSnapshot.adapter, 'Lensflare', 'WebGL must use the official Lensflare addon');
assert.equal(visibleSnapshot.activeElements, 5, 'production flare must use the five distinct optical elements');
assert.deepEqual(
  visibleSnapshot.elementDistances.map((value) => Number(value.toFixed(2))),
  [0, 0, .3, .52, .76],
  'core, streak and ghost chain must share the native lensflare optical axis',
);
assert.deepEqual(
  visibleSnapshot.elementKinds,
  ['sun-core', 'anamorphic-streak', 'inner-ghost', 'aperture-ring', 'far-ghost'],
  'each flare element needs a distinct optical role rather than the same blue blur',
);
assert.equal(visibleSnapshot.raySphereOccluded, false, 'a world sun on the camera side must remain visible');
assert.ok(visibleSnapshot.targetVisibility > .15, 'a visible sun needs a non-zero production flare target');
assert.ok(visibleSnapshot.targetVisibility < .5, 'the production lens flare must remain secondary to the visible 3D sun body');

const hidden = createController({ sunDirection: new THREE.Vector3(0, 0, -1) });
hidden.controller.updateFrame(0);
hidden.controller.updateFrame(180);
const hiddenSnapshot = hidden.controller.getDebugSnapshot();
assert.equal(hiddenSnapshot.raySphereOccluded, true, 'the planet must occlude a virtual sun behind it');
assert.ok(hiddenSnapshot.targetVisibility < .001, 'a fully occluded sun must not keep a visible flare');
assert.ok(hiddenSnapshot.occlusionFade < .001, 'the shared sun/corona controller needs explicit occlusion strength');

const beforeOrbit = visible.controller.getDebugSnapshot().proxyWorldPosition;
visible.camera.position.set(96, 0, 82);
visible.camera.lookAt(0, 0, 0);
visible.camera.updateMatrixWorld(true);
visible.controller.updateFrame(260);
assert.deepEqual(
  visible.controller.getDebugSnapshot().proxyWorldPosition.map((value) => Number(value.toFixed(6))),
  beforeOrbit.map((value) => Number(value.toFixed(6))),
  'camera orbit must not move the world-fixed virtual sun proxy',
);

const beforeDispose = visible.scene.children.length;
visible.controller.dispose();
assert.ok(visible.scene.children.length < beforeDispose, 'dispose must remove the virtual-sun proxy from the scene');

const webGpu = createController({ sunDirection: new THREE.Vector3(.25, 0, -1), renderer: 'webgpu' });
// A WebGPU renderer must not be handed the WebGL Lensflare class. This is a
// constructor/lifecycle smoke test; rendering itself remains Globe.gl-owned.
await webGpu.controller.whenReady();
webGpu.controller.updateFrame(0);
assert.equal(webGpu.controller.getDebugSnapshot().adapter, 'LensflareMesh', 'WebGPU must use LensflareMesh');
webGpu.controller.dispose();

console.log('virtual sun lens flare controller OK');
