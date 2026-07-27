import * as THREE from './vendor/three.module.min.js?rev=92';
import {
  TEST_SEED,
  UNIVERSE_LEVEL,
  classifyPointerTap,
  createUniverseMockData,
  easeInOutCubic,
  focusCameraTarget,
  galaxyNodeRadius,
} from './universe-morph-model.js?rev=1';

const PLANET_COLORS = [0x6b3ef6, 0x8a63e8, 0x7c4dff, 0x9b7bff];
let threeGlobePromise;

function loadThreeGlobe() {
  if (window.ThreeGlobe) return Promise.resolve(window.ThreeGlobe);
  if (threeGlobePromise) return threeGlobePromise;
  threeGlobePromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.async = true;
    script.src = new URL('./vendor/three-globe.min.js?rev=3', import.meta.url).href;
    script.addEventListener('load', () => window.ThreeGlobe ? resolve(window.ThreeGlobe) : reject(new Error('ThreeGlobe globális export hiányzik.')), { once: true });
    script.addEventListener('error', () => reject(new Error('A ThreeGlobe vendor nem tölthető be.')), { once: true });
    document.head.append(script);
  });
  return threeGlobePromise;
}

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
  const nodeViews = new Map();
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
  let transitionFrame = 0;
  let pointerStart;
  let destroyed = false;
  let sceneLights = [];
  let detailGlobe;
  const state = {
    level: UNIVERSE_LEVEL.GALAXY,
    selectedGalaxyNodeId: null,
    selectedPlanetNodeId: null,
    transitionProgress: 0,
    interactionLocked: false,
    savedGalaxyCamera: null,
    savedPlanetCamera: null,
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
    nodeViews.set(node.id, { root: rootGroup, proxySphere, glow, hitSphere, ring, radius });
    if (node.isPlanet) planetViews.set(node.id, { root: rootGroup, proxySphere, glow, hitSphere, ring, radius });
    return rootGroup;
  }

  function tween(duration, render) {
    return new Promise((resolve) => {
      const startedAt = performance.now();
      const frame = (now) => {
        if (destroyed) {
          resolve(false);
          return;
        }
        const progress = Math.min(1, (now - startedAt) / duration);
        render(easeInOutCubic(progress), progress);
        if (progress < 1) {
          transitionFrame = window.requestAnimationFrame(frame);
          return;
        }
        transitionFrame = 0;
        resolve(true);
      };
      transitionFrame = window.requestAnimationFrame(frame);
    });
  }

  function setObjectOpacity(object, opacity) {
    object.traverse((child) => {
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      materials.filter(Boolean).forEach((material) => {
        material.transparent = true;
        material.opacity = opacity;
      });
    });
  }

  function configureDetailGlobe(ThreeGlobe, view) {
    if (!detailGlobe) {
      detailGlobe = new ThreeGlobe({ animateIn: false, waitForGlobeReady: false })
        .showGlobe(true)
        .showAtmosphere(true)
        .atmosphereColor('#8f6bff')
        .atmosphereAltitude(.12)
        .globeImageUrl(null);
      detailGlobe.globeMaterial(new THREE.MeshStandardMaterial({
        color: 0x6337d5,
        roughness: .72,
        metalness: .04,
        emissive: 0x25104e,
        emissiveIntensity: .18,
        transparent: true,
      }));
    }
    detailGlobe.removeFromParent?.();
    view.root.add(detailGlobe);
    detailGlobe.position.set(0, 0, 0);
    const scale = view.radius / (detailGlobe.getGlobeRadius?.() || 100);
    detailGlobe.scale.setScalar(scale * .92);
    detailGlobe.visible = true;
    setObjectOpacity(detailGlobe, 0);
    return scale;
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

  async function requestPlanetEntry(nodeId) {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.GALAXY || !planetViews.has(nodeId)) return;
    const view = planetViews.get(nodeId);
    const camera = graph.camera();
    const controls = graph.controls();
    state.level = UNIVERSE_LEVEL.GALAXY_TO_PLANET;
    state.selectedGalaxyNodeId = nodeId;
    state.interactionLocked = true;
    state.savedGalaxyCamera = { position: camera.position.clone(), target: controls.target.clone() };
    nodeViews.forEach((candidate, id) => {
      candidate.ring.visible = id === nodeId;
      candidate.glow.material.opacity = id === nodeId ? .34 : .045;
      candidate.proxySphere.material.opacity = id === nodeId ? 1 : .16;
    });
    graph.linkOpacity(.07);
    updateDebug();

    controls.enabled = false;
    graph.scene().updateMatrixWorld(true);
    const nodePosition = view.root.getWorldPosition(new THREE.Vector3());
    const targetCamera = focusCameraTarget(nodePosition, camera.position, controls.target, view.radius * 6);
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const cameraEnd = new THREE.Vector3(targetCamera.x, targetCamera.y, targetCamera.z);
    const focused = await tween(560, (eased, raw) => {
      state.transitionProgress = raw * .5;
      camera.position.lerpVectors(cameraStart, cameraEnd, eased);
      controls.target.lerpVectors(targetStart, nodePosition, eased);
      controls.update();
      updateDebug();
    });
    if (!focused || destroyed) return;

    try {
      const ThreeGlobe = await loadThreeGlobe();
      if (destroyed) return;
      const detailScale = configureDetailGlobe(ThreeGlobe, view);
      const morphed = await tween(520, (eased, raw) => {
        state.transitionProgress = .5 + raw * .5;
        view.proxySphere.material.opacity = 1 - eased;
        detailGlobe.scale.setScalar(detailScale * (.92 + eased * .08));
        setObjectOpacity(detailGlobe, eased);
        nodeViews.forEach((candidate, id) => {
          if (id !== nodeId) candidate.proxySphere.material.opacity = .16 - eased * .06;
        });
        graph.linkOpacity(.07 - eased * .04);
        updateDebug();
      });
      if (!morphed || destroyed) return;
      state.level = UNIVERSE_LEVEL.PLANET;
      state.transitionProgress = 1;
      state.interactionLocked = false;
      controls.enabled = true;
      updateDebug();
    } catch (error) {
      state.level = UNIVERSE_LEVEL.GALAXY;
      state.transitionProgress = 0;
      state.interactionLocked = false;
      controls.enabled = true;
      nodeViews.forEach((candidate) => { candidate.proxySphere.material.opacity = 1; });
      graph.linkOpacity(.34);
      helpers.showToast?.(error.message || 'A részletes bolygó nem tölthető be.');
      updateDebug();
    }
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
    window.cancelAnimationFrame(transitionFrame);
    resizeObserver?.disconnect();
    galaxyMount.removeEventListener('pointerdown', onPointerDown);
    galaxyMount.removeEventListener('pointerup', onPointerUp);
    sceneLights.forEach((light) => light.removeFromParent());
    detailGlobe?.removeFromParent?.();
    nodeViews.forEach((view) => view.root.traverse((object) => object.geometry?.dispose?.()));
    ownedMaterials.forEach((material) => material.dispose());
    selectedRingMaterial.dispose();
    invisibleHitMaterial.dispose();
    sharedSphereGeometry.dispose();
    try { graph?._destructor?.(); } catch { /* ForceGraph cleanup must not block routing. */ }
    galaxyMount.replaceChildren();
  };
}
