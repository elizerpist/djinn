import assert from 'node:assert/strict';
import * as THREE from '../assets/vendor/three.module.min.js?edge-test';
import { DjinnEdgeLayer, __djinnEdgeLayerTest } from '../assets/djinn-edge-layer.js?edge-test';

assert.deepEqual(__djinnEdgeLayerTest.PASS_NAMES, ['background', 'structure', 'bridge']);
assert.equal(__djinnEdgeLayerTest.PASS_CONFIG.structure.segmentsMin, 8);

const nodes = [
  { id: 'a', lat: 0, lng: 0, v3Community: 0 },
  { id: 'b', lat: 12, lng: 36, v3Community: 0 },
  { id: 'c', lat: -20, lng: 150, v3Community: 1 },
  { id: 'd', lat: 35, lng: -110, v3Community: 1 },
];
const edges = [
  { id: 'ab', source: 'a', target: 'b', weight: .32, arcPass: 'background' },
  { id: 'ac', source: 'a', target: 'c', weight: .88, arcPass: 'structure' },
  { id: 'bd', source: 'b', target: 'd', weight: .72, arcPass: 'bridge' },
  { id: 'cd', source: 'c', target: 'd', weight: .55, arcPass: 'structure' },
  { id: 'missing', source: 'a', target: 'not-present', weight: .8, arcPass: 'bridge' },
];
const scene = new THREE.Scene();
const layer = new DjinnEdgeLayer({ scene, planetRadius: 100, forceLinkCount: 5 });
const stats = layer.setEdges(edges, nodes);

assert.equal(stats.forceLinkCount, 5);
assert.equal(stats.forceVisibleLinkCount, 0);
assert.equal(stats.inputEdgeCount, 5);
assert.equal(stats.validEdgeCount, 4);
assert.equal(stats.invalidEndpointCount, 1);
assert.equal(stats.renderedEdgeCount, 4);
assert.ok(stats.geometryCount >= 2);
assert.equal(stats.drawCallCount, stats.geometryCount);
assert.ok(stats.geodesicSegments >= 24);
assert.equal(scene.children.includes(layer.planetGraphRoot), true);
assert.equal(layer.planetGraphRoot.children.includes(layer.group), true);

const firstRebuildCount = stats.rebuildCount;
assert.equal(layer.setEdges(edges, nodes).rebuildCount, firstRebuildCount);
layer.setEdgeVisibility({ local: false, remote: true });
assert.equal(layer.localEdgesVisible, false);
assert.equal(layer.remoteEdgesVisible, true);
layer.setEdgeVisibility({ local: true, remote: true });
layer.setDiagnostics('white');
assert.equal(layer.getDebugStats().diagnosticMode, 'white');
layer.setFocus('a');
assert.ok(layer.getDebugStats().rebuildCount > firstRebuildCount);

const halfway = __djinnEdgeLayerTest.slerpDirection(
  new THREE.Vector3(1, 0, 0),
  new THREE.Vector3(0, 1, 0),
  .5,
);
assert.ok(Math.abs(halfway.length() - 1) < 1e-6);
assert.ok(halfway.x > .6 && halfway.y > .6);

layer.dispose();
assert.equal(scene.children.includes(layer.group), false);

const registryRoot = new THREE.Group();
scene.add(registryRoot);
const registry = new Map();
nodes.forEach((node, index) => {
  const object = new THREE.Group();
  const angle = (index / nodes.length) * Math.PI * 2;
  object.position.set(Math.cos(angle), Math.sin(angle) * 0.35, Math.sin(angle));
  object.position.normalize().multiplyScalar(100);
  object.userData.baseRadius = 1;
  registryRoot.add(object);
  registry.set(node.id, object);
});
const registryLayer = new DjinnEdgeLayer({ scene, planetRadius: 100, nodeObjects: registry, planetGraphRoot: registryRoot });
const registryStats = registryLayer.setEdges(edges, nodes);
assert.equal(registryStats.missingNodeCount, 0);
assert.equal(registryStats.endpointMaxError, 0);
assert.equal(registryStats.radiusInsideCount, 0);
assert.ok(registryStats.bridgeMaxRadius > 100);
assert.equal(__djinnEdgeLayerTest.PASS_CONFIG.structure.width, 0.62);
assert.equal(__djinnEdgeLayerTest.PASS_CONFIG.bridge.width, 0.66);
const bridgeProfiles = registryLayer.getBridgeEdges();
assert.ok(bridgeProfiles.length >= 1);
assert.ok(bridgeProfiles.every((edge) => edge.peakAltitude >= 0.004 && edge.peakAltitude <= __djinnEdgeLayerTest.NATIVE_WEIGHTED_MAX_ALTITUDE && edge.apexPosition === 0.5));
assert.ok(bridgeProfiles.every((edge) => Number.isFinite(edge.nativeAutoAltitude)));
assert.ok(bridgeProfiles.every((edge) => edge.trajectoryShape === 'globe-native-cubic'));
assert.ok(bridgeProfiles.every((edge) => edge.nativeAutoAltitude <= __djinnEdgeLayerTest.NATIVE_AUTO_MAX_ALTITUDE + 1e-9), 'Native Auto bridges must stay below the restrained altitude cap');
assert.ok(bridgeProfiles.every((edge) => edge.peakAltitude <= __djinnEdgeLayerTest.NATIVE_WEIGHTED_MAX_ALTITUDE + 1e-9), 'Native Weighted bridges must stay below the restrained altitude cap');
const profile = __djinnEdgeLayerTest.bridgeProfile(
  { id: 'high-bridge', source: 'a', target: 'c', weight: .9, isSelected: true },
  new THREE.Vector3(100, 0, 0),
  new THREE.Vector3(0, 100, 0),
);
assert.ok(profile.peakAltitude >= .004 && profile.peakAltitude <= __djinnEdgeLayerTest.NATIVE_WEIGHTED_MAX_ALTITUDE);
assert.ok(profile.nativeAutoAltitude >= 0);
const expectedAutoAltitude = (profile.angularDistance / 2) * profile.autoScale;
assert.ok(Math.abs(profile.nativeAutoAltitude - expectedAutoAltitude) < 1e-9);
const autoProfile = __djinnEdgeLayerTest.bridgeProfile(
  { id: 'auto-bridge', source: 'a', target: 'c', weight: .9 },
  new THREE.Vector3(101.4, 0, 0),
  new THREE.Vector3(0, 101.4, 0),
  100,
  'native-auto',
);
assert.equal(autoProfile.nativePeakAltitude, autoProfile.nativeAutoAltitude);
assert.ok(autoProfile.nativeAutoAltitude <= __djinnEdgeLayerTest.NATIVE_AUTO_MAX_ALTITUDE + 1e-9);
assert.ok(autoProfile.autoScale < 0.2, 'Native Auto must use a restrained scale instead of the old high default');
const nativeTrajectory = __djinnEdgeLayerTest.nativeArcPoints(
  new THREE.Vector3(100, 0, 0),
  new THREE.Vector3(0, 100, 0),
  100,
  profile.peakAltitude,
  32,
);
assert.equal(nativeTrajectory.length, 33);
assert.ok(nativeTrajectory[0].distanceTo(new THREE.Vector3(100, 0, 0)) < 1e-9);
assert.ok(nativeTrajectory.at(-1).distanceTo(new THREE.Vector3(0, 100, 0)) < 1e-9);
assert.ok(Math.max(...nativeTrajectory.map((point) => point.length())) > 100.5);
registryLayer.setDiagnostics('endpoint');
assert.ok(registryLayer.endpointMarkers);
registryLayer.setDiagnostics('radius');
assert.equal(registryLayer.getDebugStats().diagnosticMode, 'radius');
registryLayer.dispose();
registryRoot.removeFromParent();
console.log(`Djinn edge layer OK (${stats.geometryCount} batched passes, geodesic ribbons)`);
