import * as THREE from './vendor/three.module.min.js?rev=92';
import {
  TEST_SEED,
  UNIVERSE_LEVEL,
  classifyPointerTap,
  createUniverseMockData,
  galaxyNodeRadius,
} from './universe-morph-model.js?rev=1';

const PLANET_COLORS = [0x6b3ef6, 0x8a63e8, 0x7c4dff, 0x9b7bff];

function degreeById(nodes, links) {
  const degrees = new Map(nodes.map((node) => [node.id, 0]));
  links.forEach((link) => {
    degrees.set(link.source, (degrees.get(link.source) || 0) + 1);
    degrees.set(link.target, (degrees.get(link.target) || 0) + 1);
  });
  return degrees;
}

function waitForForceGraph(onReady, onError) {
  let attempts = 0;
  let frame = 0;
  const check = () => {
    if (window.ForceGraph3D) {
      onReady();
      return;
    }
    attempts += 1;
    if (attempts >= 60) {
      onError();
      return;
    }
    frame = window.requestAnimationFrame(check);
  };
  check();
  return () => window.cancelAnimationFrame(frame);
}

export function initUniverseMorphTest(root, helpers = {}) {
  const stage = root.querySelector('[data-universe-stage]');
  const galaxyMount = root.querySelector('[data-universe-galaxy]');
  const debug = root.querySelector('[data-universe-debug]');
  if (!stage || !galaxyMount) return () => {};

  window.THREE = THREE;

  const mock = createUniverseMockData(TEST_SEED);
  const degrees = degreeById(mock.galaxy.nodes, mock.galaxy.links);
  const degreeValues = [...degrees.values()];
  const minDegree = Math.min(...degreeValues);
  const maxDegree = Math.max(...degreeValues);
  const planetViews = new Map();
  const ownedMaterials = new Set();
  const sharedSphereGeometry = new THREE.SphereGeometry(1, 16, 12);
  const selectedRingMaterial = new THREE.MeshBasicMaterial({
    color: 0xf1eaff,
    transparent: true,
    opacity: .9,
    depthWrite: false,
  });
  const invisibleHitMaterial = new THREE.MeshBasicMaterial({
    transparent: true,
    opacity: 0,
    depthWrite: false,
  });
  let graph;
  let resizeObserver;
  let removeWaiter = () => {};
  let pointerStart;
  let destroyed = false;
  let sceneLights = [];
  const state = {
    level: UNIVERSE_LEVEL.GALAXY,
    selectedGalaxyNodeId: null,
    selectedPlanetNodeId: null,
    transitionProgress: 0,
    interactionLocked: false,
  };

  function updateDebug() {
    if (!debug) return;
    debug.innerHTML = `<strong>Universe test</strong><br>Level: ${state.level}<br>Planet: ${state.selectedGalaxyNodeId || '—'}<br>Progress: ${state.transitionProgress.toFixed(2)}`;
  }

  function createPlanetMaterial(node) {
    const material = new THREE.MeshStandardMaterial({
      color: PLANET_COLORS[node.isPlanet ? Number(node.id.slice(-1)) % PLANET_COLORS.length : 1],
      roughness: .65,
      metalness: .05,
      transparent: true,
      depthTest: true,
      depthWrite: true,
    });
    ownedMaterials.add(material);
    return material;
  }

  function createGalaxyNodeRoot(node) {
    const degree = degrees.get(node.id) || 0;
    const baseRadius = galaxyNodeRadius(degree, minDegree, maxDegree);
    const radius = node.isPlanet ? baseRadius * 1.5 : baseRadius * .76;
    const rootGroup = new THREE.Group();
    const proxySphere = new THREE.Mesh(sharedSphereGeometry, createPlanetMaterial(node));
    const glowMaterial = new THREE.MeshBasicMaterial({
      color: 0x8f6bff,
      transparent: true,
      opacity: node.isPlanet ? .16 : .045,
      depthWrite: false,
      side: THREE.BackSide,
    });
    ownedMaterials.add(glowMaterial);
    const glow = new THREE.Mesh(sharedSphereGeometry, glowMaterial);
    const hitSphere = new THREE.Mesh(sharedSphereGeometry, invisibleHitMaterial);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.22, Math.max(.09, radius * .045), 8, 30), selectedRingMaterial);
    proxySphere.scale.setScalar(radius);
    glow.scale.setScalar(radius * 1.23);
    hitSphere.scale.setScalar(radius * 1.32);
    ring.rotation.x = Math.PI / 2;
    ring.visible = false;
    rootGroup.userData = { nodeId: node.id, isPlanet: node.isPlanet, radius, proxySphere, glow, hitSphere, ring };
    rootGroup.add(proxySphere, glow, hitSphere, ring);
    if (node.isPlanet) planetViews.set(node.id, { root: rootGroup, proxySphere, glow, hitSphere, ring, radius });
    return rootGroup;
  }

  function resize() {
    if (!graph || destroyed) return;
    graph.width(Math.max(1, galaxyMount.clientWidth));
    graph.height(Math.max(1, galaxyMount.clientHeight));
  }

  function selectedPlanetAt(event) {
    if (!graph || !planetViews.size) return null;
    const rect = galaxyMount.getBoundingClientRect();
    if (!rect.width || !rect.height) return null;
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(pointer, graph.camera());
    const hits = raycaster.intersectObjects([...planetViews.values()].map((view) => view.root), true);
    const root = hits.map((hit) => {
      let object = hit.object;
      while (object && !object.userData?.nodeId) object = object.parent;
      return object;
    }).find(Boolean);
    return root?.userData?.nodeId || null;
  }

  function requestPlanetEntry(nodeId) {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.GALAXY || !planetViews.has(nodeId)) return;
    state.selectedGalaxyNodeId = nodeId;
    state.interactionLocked = true;
    planetViews.forEach((view, id) => {
      view.ring.visible = id === nodeId;
      view.glow.material.opacity = id === nodeId ? .32 : .08;
    });
    updateDebug();
    helpers.showToast?.('Bolygó fókusz kijelölve – a morph a következő lépésben érkezik.');
  }

  function onPointerDown(event) {
    pointerStart = { x: event.clientX, y: event.clientY, startedAt: performance.now() };
  }

  function onPointerUp(event) {
    if (!pointerStart || state.interactionLocked) return;
    const validTap = classifyPointerTap(pointerStart, { x: event.clientX, y: event.clientY, endedAt: performance.now() });
    pointerStart = undefined;
    if (!validTap) return;
    const nodeId = selectedPlanetAt(event);
    if (nodeId) requestPlanetEntry(nodeId);
  }

  function startGraph() {
    if (destroyed) return;
    graph = new window.ForceGraph3D(galaxyMount, { controlType: 'orbit' })
      .graphData(mock.galaxy)
      .backgroundColor('#0b0a17')
      .nodeThreeObject(createGalaxyNodeRoot)
      .nodeLabel(() => '')
      .linkColor(() => 'rgba(201,196,255,.28)')
      .linkOpacity(.34)
      .linkWidth(.42)
      .cooldownTicks(90)
      .cooldownTime(900);

    const scene = graph.scene();
    const ambient = new THREE.AmbientLight(0x6d4ca4, .9);
    const key = new THREE.PointLight(0xe9e0ff, 1.7, 420);
    key.position.set(55, 72, 120);
    scene.add(ambient, key);
    sceneLights = [ambient, key];
    resize();
    resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(galaxyMount);
    galaxyMount.addEventListener('pointerdown', onPointerDown);
    galaxyMount.addEventListener('pointerup', onPointerUp);
    updateDebug();
  }

  removeWaiter = waitForForceGraph(startGraph, () => {
    galaxyMount.innerHTML = '<p class="empty">A 3D Force Graph motor nem tölthető be.</p>';
    helpers.showToast?.('A 3D Force Graph motor nem tölthető be.');
  });

  return () => {
    destroyed = true;
    removeWaiter();
    resizeObserver?.disconnect();
    galaxyMount.removeEventListener('pointerdown', onPointerDown);
    galaxyMount.removeEventListener('pointerup', onPointerUp);
    sceneLights.forEach((light) => light.removeFromParent());
    planetViews.forEach((view) => view.root.traverse((object) => object.geometry?.dispose?.()));
    ownedMaterials.forEach((material) => material.dispose());
    selectedRingMaterial.dispose();
    invisibleHitMaterial.dispose();
    sharedSphereGeometry.dispose();
    try { graph?._destructor?.(); } catch { /* ForceGraph cleanup must not block routing. */ }
    galaxyMount.replaceChildren();
  };
}
