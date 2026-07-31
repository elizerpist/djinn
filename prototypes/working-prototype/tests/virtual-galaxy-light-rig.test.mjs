import assert from 'node:assert/strict';
import * as THREE from '../assets/vendor/three.module.min.js?virtual-light-rig-test';
import {
  V7_LIGHT_MODES,
  VirtualGalaxyLightingRig,
} from '../assets/virtual-galaxy-light-rig.js?virtual-light-rig-test';

function createCamera() {
  const camera = new THREE.PerspectiveCamera(45, 1, .1, 2000);
  camera.position.set(0, 32, 126);
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld(true);
  return camera;
}

function createRig(planetId = 'planet-oxygenation') {
  const scene = new THREE.Scene();
  const camera = createCamera();
  const rig = new VirtualGalaxyLightingRig({
    THREE,
    scene,
    getCamera: () => camera,
    getPlanetCenter: () => new THREE.Vector3(0, 0, 0),
    planetId,
  });
  rig.initialize();
  rig.captureEntryFrame();
  rig.resume();
  return { scene, camera, rig };
}

assert.ok(V7_LIGHT_MODES.includes('hybrid-cinematic'));
assert.ok(V7_LIGHT_MODES.includes('camera-headlight'));
assert.ok(V7_LIGHT_MODES.includes('fixed-galaxy-sun'));
assert.ok(V7_LIGHT_MODES.includes('specular-proof'));
assert.ok(!V7_LIGHT_MODES.includes('no-rim'), 'V7 production must not expose a side/rim light mode');
assert.ok(V7_LIGHT_MODES.includes('universe-v3-reference'), 'V7 must expose the Universe V3 reference lighting preset');

const first = createRig();
const second = createRig();
assert.deepEqual(
  first.rig.getDebugSnapshot().worldSunDirection.map((value) => Number(value.toFixed(6))),
  second.rig.getDebugSnapshot().worldSunDirection.map((value) => Number(value.toFixed(6))),
  'the virtual galaxy sun must be stable for the same planet seed',
);
assert.deepEqual(
  first.rig.copyWorldSunDirection(new THREE.Vector3()).toArray().map((value) => Number(value.toFixed(6))),
  first.rig.getDebugSnapshot().worldSunDirection.map((value) => Number(value.toFixed(6))),
  'the flare must read the pure world sun rather than the camera-cinematic key direction',
);

first.rig.setMode('fixed-galaxy-sun');
first.rig.updateTargetFromCamera();
first.rig.updateFrame(0);
const fixedBefore = first.rig.getDebugSnapshot().targetKeyDirection;
first.camera.position.set(118, 18, 42);
first.camera.lookAt(0, 0, 0);
first.camera.updateMatrixWorld(true);
first.rig.updateTargetFromCamera();
first.rig.updateFrame(240);
assert.deepEqual(
  first.rig.getDebugSnapshot().targetKeyDirection.map((value) => Number(value.toFixed(6))),
  fixedBefore.map((value) => Number(value.toFixed(6))),
  'fixed galaxy sun must not rotate with camera orbit',
);

first.rig.setMode('camera-headlight');
first.rig.updateTargetFromCamera();
first.rig.updateFrame(500);
const headlight = new THREE.Vector3(...first.rig.getDebugSnapshot().blendedKeyDirection);
const cameraDirection = first.camera.position.clone().normalize();
assert.ok(headlight.dot(cameraDirection) > .995, 'headlight mode must follow the camera direction');

first.rig.setMode('hybrid-cinematic');
first.rig.setCinematicBlend(.15);
first.rig.updateTargetFromCamera();
first.rig.updateFrame(760);
const hybrid = new THREE.Vector3(...first.rig.getDebugSnapshot().targetKeyDirection);
const worldSun = new THREE.Vector3(...first.rig.getDebugSnapshot().worldSunDirection);
assert.ok(hybrid.angleTo(worldSun) > .001, 'hybrid mode needs a visible cinematic camera contribution');
assert.ok(hybrid.angleTo(worldSun) < headlight.angleTo(worldSun), 'hybrid must stay much closer to the world sun than headlight');

const soft = createRig('planet-soft-violet-light');
soft.rig.setMode('hybrid-cinematic');
soft.rig.updateTargetFromCamera();
soft.rig.updateFrame(0);
soft.rig.updateFrame(1200);
const softMaterial = soft.rig.getMaterialSettings();
assert.equal(softMaterial.color, '#2a1a57', 'Hybrid Cinematic must use the same solid violet body as Universe V3 Reference');
assert.equal(softMaterial.specular, '#382848', 'V7 default needs a weaker, wider violet lobe rather than a sharp magenta division');
assert.equal(soft.rig.galaxyKeyLight.color.getHexString(), 'c86ed1', 'the V7 key must be weaker and less magenta than the previous direct key');
assert.equal(soft.rig.galaxyFillLight.color.getHexString(), '654a88', 'V7 fill must be broad violet so the coloured field extends farther around the globe');
assert.equal(soft.rig.galaxyFillLight.groundColor.getHexString(), '332047', 'V7 fill ground must keep the far side violet rather than near-black');
assert.ok(!('cameraRimLight' in soft.rig), 'V7 must not create the blue-debugged side/rim light');
assert.equal(soft.rig.getLights().length, 3, 'V7 production must use only ambient, key and Hemisphere fill lights');
assert.ok(softMaterial.shininess <= 13, 'V7 needs a much broader soft highlight rather than a tight flashlight hotspot');
assert.equal(softMaterial.emissive, '#241044', 'Hybrid Cinematic must reuse the Universe V3 Reference violet body lift');
assert.equal(softMaterial.emissiveIntensity, .14, 'Hybrid Cinematic must reuse the solid V3-reference body without changing its own lights');
assert.ok(soft.rig.getDebugSnapshot().keyIntensity >= 1.2 && soft.rig.getDebugSnapshot().keyIntensity <= 1.3, 'V7 direct magenta must be materially softer than the previous key');
assert.ok(soft.rig.getDebugSnapshot().fillIntensity >= .79 && soft.rig.getDebugSnapshot().fillIntensity <= .84, 'V7 fill must widen the violet field and reduce the black back-side area');
assert.ok(soft.rig.getDebugSnapshot().ambientIntensity >= .26 && soft.rig.getDebugSnapshot().ambientIntensity <= .30, 'V7 production must retain enough uniform violet ambient for a smooth terminator');
assert.ok(!('rimIntensity' in soft.rig.getDebugSnapshot()), 'V7 debug output must not report a removed production rim light');

const universeV3 = createRig('planet-universe-v3-reference');
universeV3.rig.setMode('universe-v3-reference');
universeV3.rig.captureEntryFrame({ planetId: 'planet-universe-v3-reference' });
universeV3.rig.updateTargetFromCamera();
universeV3.rig.updateFrame(0);
universeV3.rig.updateFrame(1200);
const universeV3Material = universeV3.rig.getMaterialSettings();
const universeV3Snapshot = universeV3.rig.getDebugSnapshot();
const expectedUniverseV3Sun = new THREE.Vector3(-.62, .54, .57).normalize();
const actualUniverseV3Sun = new THREE.Vector3(...universeV3Snapshot.worldSunDirection);
assert.ok(
  actualUniverseV3Sun.angleTo(expectedUniverseV3Sun) < 1e-7,
  'Universe V3 reference must begin from the shared camera-independent sun direction so the Force inline globe and V7 shade the same hemisphere',
);
assert.equal(universeV3.rig.galaxyKeyLight.color.getHexString(), 'f5d8ff', 'Universe V3 reference key must show a clearly readable magenta-white tint without becoming solid magenta');
assert.equal(universeV3.rig.galaxyFillLight.color.getHexString(), '40305e', 'Universe V3 reference upper fill must match the real V3 fill');
assert.equal(universeV3.rig.galaxyFillLight.groundColor.getHexString(), '2a1a4d', 'Universe V3 reference must retain a deep-violet far-side floor instead of collapsing into transparent black');
assert.equal(universeV3.rig.defaultAmbientLight.color.getHexString(), '211640', 'Universe V3 reference ambient must preserve an opaque violet body after the V3 baseline');
assert.ok(universeV3Snapshot.keyIntensity >= 1.39 && universeV3Snapshot.keyIntensity <= 1.41, 'Universe V3 reference key must retain its magenta-white tone at the reduced requested brightness');
assert.ok(universeV3Snapshot.fillIntensity >= .77 && universeV3Snapshot.fillIntensity <= .79, 'Universe V3 reference must broaden its violet hemisphere enough to make the globe body solid');
assert.ok(universeV3Snapshot.ambientIntensity >= .45 && universeV3Snapshot.ambientIntensity <= .47, 'Universe V3 reference must keep a solid violet floor across the back quarter');
assert.equal(universeV3Material.color, '#2a1a57', 'Universe V3 reference must use a fuller violet Phong body rather than the darker default V7 body');
assert.equal(universeV3Material.specular, '#c68bd7', 'Universe V3 reference must carry the stronger magenta-white tint through the soft specular lobe');
assert.equal(universeV3Material.shininess, 9, 'Universe V3 reference highlight must spread into the violet field rather than forming a sharp hotspot');
assert.equal(universeV3Material.emissive, '#241044', 'Universe V3 reference material must use a restrained violet floor rather than a blue-black backside');
assert.equal(universeV3Material.emissiveIntensity, .14, 'Universe V3 reference far-side violet floor must remain visible without turning into neon');

const frontSun = soft.rig.copyWorldSunDirection(new THREE.Vector3());
soft.camera.position.copy(frontSun).multiplyScalar(126);
soft.camera.lookAt(0, 0, 0);
soft.camera.updateMatrixWorld(true);
soft.rig.updateTargetFromCamera();
soft.rig.updateFrame(2400);
soft.rig.updateFrame(4800);
const frontLit = soft.rig.getDebugSnapshot();
assert.ok(frontLit.cameraFacingKey > .75, 'the rig must detect when the world sun approaches the camera axis');
assert.ok(frontLit.keyIntensity < 1.4, 'a camera-facing key must soften instead of burning out the globe center');

first.rig.setMode('no-fill');
first.rig.updateFrame(3020);
assert.ok(first.rig.getDebugSnapshot().fillIntensity < .002, 'no-fill must decay the fill to effectively zero');
assert.equal(first.rig.setMode('no-rim'), false, 'V7 must reject the removed side/rim-light diagnostic mode');

const beforeDispose = first.scene.children.length;
first.rig.dispose();
soft.rig.dispose();
universeV3.rig.dispose();
assert.ok(first.scene.children.length < beforeDispose, 'dispose must remove the virtual target and light helpers from the scene');

console.log('virtual galaxy light rig OK');
