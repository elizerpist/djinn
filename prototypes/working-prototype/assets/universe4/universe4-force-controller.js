import * as THREE from '../vendor/three.module.min.js?rev=92';
import { CosmicEnvironment } from '../cosmic-environment.js?rev=6';
import {
  createUniverseV3ReferenceSunDirection,
  UNIVERSE_V3_REFERENCE_LIGHTING,
} from '../virtual-galaxy-light-rig.js?rev=24';
// Import the V5 visual snapshot, not its Globe.gl UI wrapper.  V3 places
// this immutable node data inside the already-existing ForceGraph3D scene.
import { getV5PlanetVisualSnapshot } from './universe4-globe-stage.js?rev=1';
import {
  TEST_SEED,
  UNIVERSE_FOCUS_STATE,
  UNIVERSE_LEVEL,
  clampOrbitDistance,
  classifyPointerTap,
  createUniverseMockData,
  easeInOutCubic,
  focusDistanceForBoundingRadius,
  focusCameraTarget,
  focusTargetDelta,
  galaxyNodeRadius,
  fibonacciSpherePoint,
  projectPointToScreen,
  reverseTransition,
  surfaceArcPoints,
} from './universe4-force-model.js?rev=1';

const PLANET_COLORS = [0x6b3ef6, 0x8a63e8, 0x7c4dff, 0x9b7bff];
const DJINN_V2 = Object.freeze({
  spaceStart: '#102C6B',
  spaceEnd: '#06163F',
  planet: 0x3d2a9a,
  planetGlow: 0x9b7bff,
  atom: 0x43e7f8,
  atomGlow: 0x75f1fa,
  structure: 0xa18bf7,
  focus: 0xffd45a,
  focusGlow: 0xffe783,
});

// In V3 the visual detail lives inside a ForceGraph node, but interaction
// ownership deliberately does not. The graph owns overview selection; the
// shared OrbitControls own the focused planet; our raycaster owns atom taps.
const UNIVERSE_INTERACTION_OWNER = Object.freeze({
  GALAXY_INTERACTION: 'GALAXY_INTERACTION',
  PLANET_TRANSITION: 'PLANET_TRANSITION',
  PLANET_INTERACTION: 'PLANET_INTERACTION',
});

const POINTER_GESTURE = Object.freeze({
  IDLE: 'IDLE',
  TAP_CANDIDATE: 'TAP_CANDIDATE',
  CAMERA_ORBIT: 'CAMERA_ORBIT',
  CAMERA_PINCH: 'CAMERA_PINCH',
  PICKING: 'PICKING',
  CANCELLED: 'CANCELLED',
});

const PLANET_TAP_MOVE_THRESHOLD_PX = 8;
const PLANET_TAP_DURATION_THRESHOLD_MS = 320;
const UNIVERSE_V5_LABEL_POOL_LIMIT = 15;
// The U3 handoff must end noticeably closer than the former .52 framing.
// Its actual final camera frame is what U4 maps to Globe.gl, so this one
// value enlarges both sides without introducing a second Globe-only zoom.
const UNIVERSE_V3_ENTRY_VIEWPORT_FILL = .56;
// ThreeGlobe's body reads optically smaller than the ForceGraph proxy at the
// same mathematical radius (its city field has a tighter silhouette). Keep a
// single static calibration across the whole inline phase instead of hiding
// the discrepancy with an animated size correction.
const UNIVERSE_V3_INLINE_GLOBE_VISUAL_RADIUS_MULTIPLIER = 1.18;
let threeGlobePromise;

function loadThreeGlobe() {
  if (window.ThreeGlobe) return Promise.resolve(window.ThreeGlobe);
  if (threeGlobePromise) return threeGlobePromise;
  threeGlobePromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.async = true;
    script.src = new URL('../vendor/three-globe.min.js?rev=3', import.meta.url).href;
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

export function initUniverse4ForceController(root, helpers = {}) {
  const isBrandV2 = Boolean(root.querySelector('.universe4-u3-brand-v2'));
  const isFocusV3 = Boolean(root.querySelector('.universe4-u3-screen'));
  const suppressInlineCityLabels = Boolean(helpers.suppressInlineCityLabels);
  const stage = root.querySelector('[data-universe-stage]');
  const galaxyMount = root.querySelector('[data-universe-galaxy]');
  const mapMount = root.querySelector('[data-universe-map]');
  const proxy = root.querySelector('[data-universe-proxy]');
  const corridor = root.querySelector('[data-universe-corridor]');
  const debug = root.querySelector('[data-universe-debug]');
  const fullscreenButton = root.querySelector('[data-universe-fullscreen]');
  const cityContext = root.querySelector('[data-universe-city-context]');
  if (!stage || !galaxyMount || !mapMount || !proxy) return () => {};

  window.THREE = THREE;

  const mock = createUniverseMockData(TEST_SEED);
  const universeV5Planet = isFocusV3 ? getV5PlanetVisualSnapshot() : null;
  const degrees = degreeById(mock.galaxy.nodes, mock.galaxy.links);
  const degreeValues = [...degrees.values()];
  const minDegree = Math.min(...degreeValues);
  const maxDegree = Math.max(...degreeValues);
  const planetViews = new Map();
  const nodeViews = new Map();
  const ownedMaterials = new Set();
  // All ForceGraph planet proxies share this geometry.  The former 16×12
  // shell was visibly faceted while a focused planet filled the viewport;
  // 32×24 retains a single shared allocation but gives the body a smooth
  // silhouette close to the canonical Globe.gl sphere.
  const sharedSphereGeometry = new THREE.SphereGeometry(1, 32, 24);
  const selectedRingMaterial = new THREE.MeshBasicMaterial({
    color: isBrandV2 ? DJINN_V2.focusGlow : 0xf1eaff,
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
  let mapResizeObserver;
  let removeWaiter = () => {};
  let transitionFrame = 0;
  let hudFrame = 0;
  // ForceGraph3D owns one renderer loop, but U3 also owns this small HUD and
  // cosmic-maintenance loop. U4 must be able to suspend both while V7 owns
  // the screen; otherwise the hidden Force stage continues doing frame work.
  let universeRenderRuntimePaused = false;
  let lastHudUpdate = 0;
  let fpsStartedAt = performance.now();
  let fpsFrameCount = 0;
  let fps = 0;
  let pointerStart;
  const planetPointerGesture = {
    activePointers: new Map(),
    mode: POINTER_GESTURE.IDLE,
    hadMultiPointer: false,
    suppressedClicks: 0,
    pinchCount: 0,
    orbitCount: 0,
  };
  let destroyed = false;
  let universeRendererBackgroundColor = isBrandV2 ? DJINN_V2.spaceEnd : '#0B0A17';
  let sceneLights = [];
  let universeCosmicEnvironment;
  let universeCosmicLightTarget;
  let universeCosmicKeyLight;
  let detailGlobe;
  let mapGraph;
  let planetContentGroup;
  let corridorLayer;
  let corridorStrand;
  let corridorStrandHit;
  let corridorTargetView;
  let corridorNeighborPlanetId = null;
  let planetFocusAnchor;
  let focusProofGroup;
  let focusTargetMarker;
  let focusAnchorMarker;
  let focusTargetLine;
  let orbitProof;
  let focusBoundsProof;
  let controlsChangeListener;
  let focusLockMutating = false;
  let frozenGalaxyPositions = null;
  let detailPovUpdates = 0;
  let v3ControlRefreshFrame = 0;
  let v3VisualRefreshFrame = 0;
  let debugExpanded = false;
  let fullscreenFallbackActive = false;
  const detailRendererSize = new THREE.Vector2();
  const v3PlanetCenter = new THREE.Vector3();
  const v3PlanetNodeWorld = new THREE.Vector3();
  const v3CameraDirection = new THREE.Vector3();
  const universeCosmicSunDirection = new THREE.Vector3(.58, .31, .75).normalize();
  const universeV5LabelSprites = new Map();
  const universeV5LabelPool = [];
  const universeV5LabelTextureCache = new Map();
  let universeV5LabelTextureRebuilds = 0;
  let universeV5ActiveLabelCount = 0;
  const v3Debug = {
    targetLock: true,
    forceFreeze: true,
    backgroundPlanets: true,
    galaxyLinks: true,
    targetProof: false,
    orbitProof: false,
    boundsProof: false,
  };
  const planetNodeViews = new Map();
  const planetLinkViews = [];
  const planetOrbitViews = [];
  const state = {
    level: UNIVERSE_LEVEL.GALAXY,
    selectedGalaxyNodeId: null,
    selectedPlanetNodeId: null,
    selectedPlanetEdgeId: null,
    corridorExpanded: false,
    transitionProgress: 0,
    interactionLocked: false,
    savedGalaxyCamera: null,
    savedPlanetCamera: null,
    savedCorridorCamera: null,
    focusMode: UNIVERSE_FOCUS_STATE.GALAXY_OVERVIEW,
    focusLimits: null,
    interactionOwner: UNIVERSE_INTERACTION_OWNER.GALAXY_INTERACTION,
  };

  function focusedPlanetBodyDiagnostics(view) {
    if (!isFocusV3 || !view) return null;
    const detailActive = detailGlobe?.parent === view.detailMount && detailGlobe.visible;
    const overviewActive = view.proxySphere.visible && view.proxySphere.material.opacity > .015;
    const glowActive = view.glow.visible && view.glow.material.opacity > .015;
    return {
      rootChildren: view.root.children.length,
      overviewActive: Number(overviewActive),
      glowActive: Number(glowActive),
      detailGlobes: Number(detailActive),
      visibleBodies: Number(overviewActive) + Number(detailActive),
    };
  }

  function updateDebug() {
    if (!debug) return;
    const now = performance.now();
    if (now - lastHudUpdate < 100) return;
    lastHudUpdate = now;
    const camera = graph?.camera?.();
    const distance = camera && graph?.controls?.()
      ? camera.position.distanceTo(graph.controls().target).toFixed(1)
      : '—';
    const controls = graph?.controls?.();
    const selectedView = planetViews.get(state.selectedGalaxyNodeId);
    const focusCenter = selectedView && graph
      ? selectedView.root.getWorldPosition(new THREE.Vector3())
      : null;
    const targetDelta = focusCenter && controls
      ? focusTargetDelta(controls.target, focusCenter).toFixed(4)
      : '—';
    const bodyDiagnostics = focusedPlanetBodyDiagnostics(selectedView);
    debugExpanded = Boolean(debug.querySelector('details')?.open);
    const v3Controls = isFocusV3 && controls ? `
      <output data-universe-v3-mode>Focus mode: ${state.focusMode}</output>
      <output data-universe-v3-target>Target Δ: ${targetDelta} · pan: ${controls.enablePan ? 'on' : 'off'} · freeze: ${frozenGalaxyPositions ? 'on' : 'off'}</output>
      <output data-universe-v3-limits>Orbit: ${state.focusLimits ? `${state.focusLimits.min.toFixed(1)}–${state.focusLimits.max.toFixed(1)}` : '—'} · POV: ${detailPovUpdates}</output>
      <output data-universe-v3-interaction>Input: ${state.interactionOwner} · ${planetPointerGesture.mode} · ptr: ${planetPointerGesture.activePointers.size} · pinch: ${planetPointerGesture.pinchCount} · blocked: ${planetPointerGesture.suppressedClicks}</output>
      <output data-universe-v3-labels>Labels: Sprite/WebGL · active: ${universeV5ActiveLabelCount} · textures: ${universeV5LabelTextureRebuilds} · DOM: 0</output>
      <output data-universe-v3-body>Root: ${bodyDiagnostics?.rootChildren ?? '—'} · overview: ${bodyDiagnostics?.overviewActive ?? '—'} · globe: ${bodyDiagnostics?.detailGlobes ?? '—'} · body: ${bodyDiagnostics?.visibleBodies ?? '—'}</output>
      <div class="universe-morph-debug-toggles" data-universe-v3-toggles>
        <label><input type="checkbox" data-universe-v3-toggle="target-lock" ${v3Debug.targetLock ? 'checked' : ''}> target lock</label>
        <label><input type="checkbox" data-universe-v3-toggle="force-freeze" ${v3Debug.forceFreeze ? 'checked' : ''}> force freeze</label>
        <label><input type="checkbox" data-universe-v3-toggle="background-planets" ${v3Debug.backgroundPlanets ? 'checked' : ''}> háttér</label>
        <label><input type="checkbox" data-universe-v3-toggle="galaxy-links" ${v3Debug.galaxyLinks ? 'checked' : ''}> galaxy links</label>
        <label><input type="checkbox" data-universe-v3-toggle="target-proof" ${v3Debug.targetProof ? 'checked' : ''}> target proof</label>
        <label><input type="checkbox" data-universe-v3-toggle="orbit-proof" ${v3Debug.orbitProof ? 'checked' : ''}> orbit proof</label>
      </div>` : '';
    debug.innerHTML = `
      <div class="universe-morph-debug-summary">
        <strong>Universe</strong>
        <output data-universe-level>${state.level.replaceAll('_', ' ')}</output>
        <output data-universe-camera>${distance}u · ${fps} FPS</output>
      </div>
      <details class="universe-morph-debug-details" ${debugExpanded ? 'open' : ''}>
        <summary>Debug</summary>
        <div class="universe-morph-debug-details-body">
          <output data-universe-progress>Progress: ${state.transitionProgress.toFixed(2)}</output>
          <output data-universe-selection>Galaxy: ${state.selectedGalaxyNodeId || '—'} · Planet: ${state.selectedPlanetNodeId || '—'} · Edge: ${state.selectedPlanetEdgeId || '—'}</output>
          <output data-universe-corridor-state>Corridor: ${state.corridorExpanded ? 'expanded' : state.level === UNIVERSE_LEVEL.CORRIDOR ? 'preview' : '—'} · Neighbor: ${corridorNeighborPlanetId || '—'}</output>
          ${v3Controls}
          <div class="universe-morph-debug-actions">
            <button type="button" data-universe-action="galaxy">Galaxy</button>
            <button type="button" data-universe-action="planet">Planet</button>
            <button type="button" data-universe-action="map">Map</button>
            <button type="button" data-universe-action="corridor">Folyosó</button>
            <button type="button" data-universe-action="reverse">Reverse</button>
            <button type="button" data-universe-action="replay">Replay</button>
          </div>
        </div>
      </details>`;
  }

  function syncUniverseFullscreenState() {
    const active = document.fullscreenElement === stage || fullscreenFallbackActive;
    stage.classList.toggle('is-universe-fullscreen-fallback', fullscreenFallbackActive && !document.fullscreenElement);
    fullscreenButton?.classList.toggle('is-active', active);
    fullscreenButton?.setAttribute('aria-pressed', String(active));
    fullscreenButton?.setAttribute('aria-label', active ? 'Universe teljes képernyő bezárása' : 'Universe teljes képernyőre kapcsolása');
    window.requestAnimationFrame(() => {
      resize();
    });
  }

  async function toggleUniverseFullscreen() {
    if (document.fullscreenElement === stage) {
      await document.exitFullscreen?.();
      return;
    }
    if (fullscreenFallbackActive) {
      fullscreenFallbackActive = false;
      syncUniverseFullscreenState();
      return;
    }
    try {
      if (document.fullscreenElement) await document.exitFullscreen?.();
      if (stage.requestFullscreen) {
        await stage.requestFullscreen({ navigationUI: 'hide' });
      } else {
        fullscreenFallbackActive = true;
        syncUniverseFullscreenState();
      }
    } catch {
      // Android WebViews may not expose the Fullscreen API.  The fallback
      // keeps the same live renderer and simply promotes the existing stage.
      fullscreenFallbackActive = true;
      syncUniverseFullscreenState();
    }
  }

  function onUniverseFullscreenChange() {
    if (document.fullscreenElement !== stage) fullscreenFallbackActive = false;
    syncUniverseFullscreenState();
  }

  function startHudLoop() {
    if (destroyed || universeRenderRuntimePaused || hudFrame) return;
    const loop = (now) => {
      hudFrame = 0;
      if (destroyed || universeRenderRuntimePaused) return;
      fpsFrameCount += 1;
      if (now - fpsStartedAt >= 1000) {
        fps = Math.round(fpsFrameCount * 1000 / (now - fpsStartedAt));
        fpsFrameCount = 0;
        fpsStartedAt = now;
      }
      // Reuse the Universe's existing frame loop. There is no second
      // renderer, camera or cosmic animation loop.
      updateUniverseCosmicLightRig();
      universeCosmicEnvironment?.updateFrame(now);
      updateDebug();
      if (!destroyed && !universeRenderRuntimePaused) hudFrame = window.requestAnimationFrame(loop);
    };
    hudFrame = window.requestAnimationFrame(loop);
  }

  function pauseUniverseRenderRuntime() {
    if (destroyed || universeRenderRuntimePaused) return;
    universeRenderRuntimePaused = true;
    if (hudFrame) window.cancelAnimationFrame(hudFrame);
    hudFrame = 0;
    universeCosmicEnvironment?.suspend?.();
    graph?.pauseAnimation?.();
  }

  function resumeUniverseRenderRuntime() {
    if (destroyed || !universeRenderRuntimePaused) return;
    universeRenderRuntimePaused = false;
    graph?.resumeAnimation?.();
    universeCosmicEnvironment?.resume?.();
    startHudLoop();
    updateDebug();
  }

  function createPlanetMaterial(node) {
    const planetColor = isFocusV3 && node.isPlanet
      ? UNIVERSE_V3_REFERENCE_LIGHTING.color
      : isBrandV2
      ? (node.isPlanet ? DJINN_V2.planet : DJINN_V2.atom)
      : PLANET_COLORS[node.isPlanet ? Number(node.id.slice(-1)) % PLANET_COLORS.length : 1];
    if (isFocusV3 && node.isPlanet) {
      // The inline proxy remains visible during the first part of the entry
      // morph. It therefore needs the same Phong response as the canonical
      // V7 Globe.gl body, not merely the same hexadecimal colour token.
      const material = new THREE.MeshPhongMaterial({
        color: planetColor,
        specular: UNIVERSE_V3_REFERENCE_LIGHTING.specular,
        shininess: UNIVERSE_V3_REFERENCE_LIGHTING.shininess,
        emissive: UNIVERSE_V3_REFERENCE_LIGHTING.emissive,
        emissiveIntensity: UNIVERSE_V3_REFERENCE_LIGHTING.emissiveIntensity,
        transparent: true,
        depthTest: true,
        depthWrite: true,
      });
      ownedMaterials.add(material);
      return material;
    }
    const material = new THREE.MeshStandardMaterial({
      color: planetColor,
      roughness: isFocusV3 && node.isPlanet ? .54 : .65,
      metalness: .05,
      emissive: isFocusV3 && node.isPlanet ? UNIVERSE_V3_REFERENCE_LIGHTING.emissive : 0x000000,
      emissiveIntensity: isFocusV3 && node.isPlanet ? UNIVERSE_V3_REFERENCE_LIGHTING.emissiveIntensity : 0,
      transparent: true,
      depthTest: true,
      depthWrite: true,
    });
    ownedMaterials.add(material);
    return material;
  }

  function planetRadiusFromAtomCount(atomCount) {
    const count = Math.max(1, Number(atomCount) || 1);
    const minAtoms = Math.cbrt(8);
    const maxAtoms = Math.cbrt(150);
    const normalized = Math.max(0, Math.min(1, (Math.cbrt(count) - minAtoms) / (maxAtoms - minAtoms)));
    return 3.6 + normalized * 4.8;
  }

  function createGalaxyNodeRoot(node) {
    const existing = nodeViews.get(node.id);
    // ForceGraph may ask for the object again after a data refresh. Reuse the
    // stable root so it cannot leave a second placeholder or detail globe in
    // the scene.
    if (existing) return existing.root;
    const degree = degrees.get(node.id) || 0;
    const baseRadius = galaxyNodeRadius(degree, minDegree, maxDegree);
    const radius = isBrandV2 && node.isPlanet
      ? planetRadiusFromAtomCount(node.atomCount)
      : node.isPlanet ? baseRadius * (isFocusV3 ? 3 : 1.5) : baseRadius * .76;
    const rootGroup = new THREE.Group();
    const proxySphere = new THREE.Mesh(sharedSphereGeometry, createPlanetMaterial(node));
    const glowMaterial = new THREE.MeshBasicMaterial({
      color: isFocusV3 && node.isPlanet
        ? UNIVERSE_V3_REFERENCE_LIGHTING.glowColor
        : isBrandV2 ? (node.isPlanet ? DJINN_V2.planetGlow : DJINN_V2.atomGlow) : 0x8f6bff,
      transparent: true,
      opacity: node.isPlanet ? .16 : .045,
      depthWrite: false,
      side: THREE.BackSide,
    });
    ownedMaterials.add(glowMaterial);
    const glow = new THREE.Mesh(sharedSphereGeometry, glowMaterial);
    const hitSphere = new THREE.Mesh(sharedSphereGeometry, invisibleHitMaterial);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.22, Math.max(.09, radius * .045), 8, 30), selectedRingMaterial);
    const detailMount = new THREE.Group();
    detailMount.name = `planet-detail-mount:${node.id}`;
    detailMount.userData.nodeId = node.id;
    proxySphere.scale.setScalar(radius);
    // The V3/U4 source proxy crossfades into an equal-radius ThreeGlobe.
    // Keep only this focused planet's visible glow on the body radius; the
    // old 1.23 shell made the Force source read as a larger sphere before
    // the actual Globe body had appeared. Other universe node glows retain
    // their wider overview character.
    glow.scale.setScalar(radius * (isFocusV3 && node.isPlanet ? 1 : 1.23));
    hitSphere.scale.setScalar(radius * 1.32);
    ring.rotation.x = Math.PI / 2;
    ring.visible = false;
    rootGroup.userData = { nodeId: node.id, isPlanet: node.isPlanet, radius, proxySphere, glow, hitSphere, ring };
    rootGroup.add(proxySphere, glow, hitSphere, ring, detailMount);
    nodeViews.set(node.id, { root: rootGroup, proxySphere, glow, hitSphere, ring, detailMount, radius });
    if (node.isPlanet) planetViews.set(node.id, { root: rootGroup, proxySphere, glow, hitSphere, ring, detailMount, radius });
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
    const globeMaterial = detailGlobe?.globeMaterial?.();
    object.traverse((child) => {
      if (child.userData?.isInvisibleHitTarget) return;
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      materials.filter(Boolean).forEach((material) => {
        // The transition needs alpha while it is revealing, but leaving the
        // body transparent after opacity reaches one makes its render path
        // differ from the canonical V7 solid Globe.gl body.  Keep atom/glow
        // materials untouched; only the real ThreeGlobe surface returns to
        // its opaque Phong state at the final inline frame.
        if (material === globeMaterial && opacity >= .999) {
          material.transparent = false;
          material.opacity = 1;
          return;
        }
        material.transparent = true;
        material.opacity = opacity;
      });
    });
  }

  function colorHex(color) {
    return color?.getHexString?.() ? `#${color.getHexString()}` : null;
  }

  function numberOrNull(value) {
    return Number.isFinite(value) ? value : null;
  }

  // The U4 trace needs the properties that actually reach Three.js, not only
  // the intended V3 token set.  In particular this exposes forgotten vendor
  // lights nested below the ForceGraph scene and renderer colour transforms.
  function captureRendererRenderProfile(renderer, material = null) {
    const clearColor = material?.color?.clone?.() || new THREE.Color();
    try {
      renderer?.getClearColor?.(clearColor);
    } catch {
      // Diagnostic capture must never interrupt a valid handoff when a
      // vendor renderer does not implement the optional getter.
    }
    let contextAttributes = null;
    try {
      contextAttributes = renderer?.getContext?.()?.getContextAttributes?.() || null;
    } catch {
      contextAttributes = null;
    }
    return Object.freeze({
      type: renderer?.constructor?.name || null,
      outputColorSpace: renderer?.outputColorSpace || null,
      outputEncoding: renderer?.outputEncoding ?? null,
      toneMapping: renderer?.toneMapping ?? null,
      toneMappingExposure: numberOrNull(renderer?.toneMappingExposure),
      physicallyCorrectLights: Boolean(renderer?.physicallyCorrectLights),
      clearColor: colorHex(clearColor),
      clearAlpha: numberOrNull(renderer?.getClearAlpha?.()),
      premultipliedAlpha: contextAttributes?.premultipliedAlpha ?? null,
      alpha: contextAttributes?.alpha ?? null,
    });
  }

  function captureSceneLightProfile(scene) {
    const lights = [];
    scene?.traverse?.((object) => {
      if (!object?.isLight) return;
      lights.push({
        name: object.name || null,
        type: object.type || object.constructor?.name || null,
        visible: object.visible !== false,
        color: colorHex(object.color),
        groundColor: colorHex(object.groundColor),
        intensity: numberOrNull(object.intensity),
        parent: object.parent?.name || object.parent?.type || null,
      });
    });
    return Object.freeze(lights.sort((left, right) => `${left.type}:${left.name}`.localeCompare(`${right.type}:${right.name}`)));
  }

  function captureMaterialRenderProfile(material) {
    if (!material) return null;
    return Object.freeze({
      type: material.type || material.constructor?.name || null,
      transparent: Boolean(material.transparent),
      opacity: numberOrNull(material.opacity),
      depthTest: material.depthTest !== false,
      depthWrite: material.depthWrite !== false,
      color: colorHex(material.color),
      specular: colorHex(material.specular),
      shininess: numberOrNull(material.shininess),
      emissive: colorHex(material.emissive),
      emissiveIntensity: numberOrNull(material.emissiveIntensity),
    });
  }

  function getPlanetWorldPosition(view) {
    graph?.scene?.().updateMatrixWorld(true);
    return view.root.getWorldPosition(new THREE.Vector3());
  }

  // The galaxy view and the detailed V5 planet share the same ForceGraph
  // scene.  The cosmic environment therefore reads the actual rendered
  // planet center, never an unrelated Globe.gl scene or a screen-space proxy.
  function getUniverseCosmicCenter(target) {
    const selectedView = planetViews.get(state.selectedGalaxyNodeId);
    if (selectedView && graph) {
      graph.scene().updateMatrixWorld(true);
      return selectedView.root.getWorldPosition(target);
    }
    return target.set(0, 0, 0);
  }

  function getUniverseCosmicRadius() {
    const selectedView = planetViews.get(state.selectedGalaxyNodeId);
    // The overview still needs a spacious but bounded cosmic shell before a
    // planet is selected. In planet focus it scales from the actual root.
    return Math.max(18, selectedView?.radius || 18);
  }

  function seedUniverseCosmicSunDirection() {
    // U3 is the Force-side half of the V3-reference handoff.  It must not
    // derive a second, camera-biased key direction: that hid the dark
    // hemisphere that the canonical V7 Globe.gl correctly shows.
    universeCosmicSunDirection.copy(createUniverseV3ReferenceSunDirection(THREE));
  }

  function updateUniverseCosmicLightRig() {
    if (!isFocusV3 || !graph || !universeCosmicLightTarget || !universeCosmicKeyLight) return;
    const center = getUniverseCosmicCenter(v3PlanetCenter);
    universeCosmicLightTarget.position.copy(center);
    universeCosmicKeyLight.position
      .copy(center)
      .addScaledVector(universeCosmicSunDirection, getUniverseCosmicRadius() * 34);
    universeCosmicLightTarget.updateMatrixWorld(true);
  }

  // ForceGraph3D creates its own default ambient/directional lights. Leaving
  // those in the scene makes U3's selected planet receive an additive rig
  // that V7 never sees, even when both paths share the V3 reference tokens.
  // Strip them before this U3 instance installs its explicit reference rig.
  function stripForceGraphDefaultLights(scene) {
    if (!scene) return;
    // ForceGraph versions may mount their inherited rig inside a helper
    // group. Removing only direct scene children leaves that hidden rig
    // active and brightens the inline globe relative to the standalone V7
    // renderer. Collect first, then detach: mutating during `traverse` can
    // skip siblings on some Three.js versions.
    const lights = [];
    scene.traverse?.((object) => {
      if (object?.isLight) lights.push(object);
    });
    lights.forEach((light) => light.removeFromParent());
  }

  function ensureUniverseCosmicEnvironment() {
    if (!isFocusV3 || !graph) return null;
    if (!universeCosmicEnvironment) {
      universeCosmicEnvironment = new CosmicEnvironment({
        THREE,
        scene: graph.scene(),
        getRenderer: () => graph.renderer(),
        getCamera: () => graph.camera(),
        getPlanetCenter: getUniverseCosmicCenter,
        getPlanetRadius: getUniverseCosmicRadius,
        getWorldSunDirection: (target) => target.copy(universeCosmicSunDirection),
        // The actual Universe scene intentionally has no lens flare. The
        // Quiet 3D star shells are the spatial references; the light remains
        // virtual and the old visible sun/optical overlay is not recreated.
        getLensFlareController: () => null,
        planetId: 'universe-v3-cosmic-frame',
      });
      universeCosmicEnvironment.initialize();
    }
    return universeCosmicEnvironment;
  }

  function resumeUniverseCosmicEnvironment({ reseedSun = false } = {}) {
    const cosmic = ensureUniverseCosmicEnvironment();
    if (!cosmic) return;
    if (reseedSun) seedUniverseCosmicSunDirection();
    cosmic.captureEntryFrame();
    cosmic.resume();
    updateUniverseCosmicLightRig();
  }

  function snapshotControls(controls) {
    return {
      target: controls.target.clone(),
      minDistance: controls.minDistance,
      maxDistance: controls.maxDistance,
      enablePan: controls.enablePan,
      enableRotate: controls.enableRotate,
      enableZoom: controls.enableZoom,
      enabled: controls.enabled,
      enableDamping: controls.enableDamping,
      dampingFactor: controls.dampingFactor,
      rotateSpeed: controls.rotateSpeed,
      zoomSpeed: controls.zoomSpeed,
    };
  }

  function restoreControls(controls, snapshot) {
    if (!snapshot) return;
    controls.target.copy(snapshot.target);
    controls.minDistance = snapshot.minDistance;
    controls.maxDistance = snapshot.maxDistance;
    controls.enablePan = snapshot.enablePan;
    controls.enableRotate = snapshot.enableRotate;
    controls.enableZoom = snapshot.enableZoom;
    controls.enableDamping = snapshot.enableDamping;
    controls.dampingFactor = snapshot.dampingFactor;
    controls.rotateSpeed = snapshot.rotateSpeed;
    controls.zoomSpeed = snapshot.zoomSpeed;
    controls.enabled = snapshot.enabled;
    controls.update();
  }

  function resetPlanetPointerGesture(mode = POINTER_GESTURE.IDLE) {
    planetPointerGesture.activePointers.clear();
    planetPointerGesture.mode = mode;
    planetPointerGesture.hadMultiPointer = false;
  }

  function applyUniverseInteractionPolicy(owner) {
    state.interactionOwner = owner;
    if (!isFocusV3 || !graph) return;
    const controls = graph.controls();
    const isPlanetInteraction = owner === UNIVERSE_INTERACTION_OWNER.PLANET_INTERACTION;
    const isTransition = owner === UNIVERSE_INTERACTION_OWNER.PLANET_TRANSITION;

    // ForceGraph's pointer tracker sees the whole custom ThreeGlobe node as a
    // graph node. It must be off while the planet is active, otherwise it
    // wins the gesture race before the shared camera controls can orbit.
    if (typeof graph.enableNodeDrag === 'function') graph.enableNodeDrag(false);
    if (typeof graph.enablePointerInteraction === 'function') {
      if (isPlanetInteraction || isTransition) graph.enablePointerInteraction(false);
      else graph.enablePointerInteraction(true);
    }
    if (typeof graph.enableNavigationControls === 'function') {
      if (isTransition) graph.enableNavigationControls(false);
      else graph.enableNavigationControls(true);
    }

    if (isTransition) {
      controls.enabled = false;
      resetPlanetPointerGesture(POINTER_GESTURE.CANCELLED);
      return;
    }

    controls.enabled = true;
    if (isPlanetInteraction) {
      controls.enableRotate = true;
      controls.enableZoom = true;
      controls.enablePan = false;
      resetPlanetPointerGesture();
      return;
    }

    // Production overview keeps planet nodes fixed as well: planets are
    // navigable places, not draggable graph objects.
    resetPlanetPointerGesture();
  }

  function ensureFocusInfrastructure() {
    if (!isFocusV3 || !graph || planetFocusAnchor) return;
    const scene = graph.scene();
    planetFocusAnchor = new THREE.Object3D();
    planetFocusAnchor.name = 'planet-focus-anchor';
    planetFocusAnchor.visible = false;
    scene.add(planetFocusAnchor);

    focusProofGroup = new THREE.Group();
    focusProofGroup.name = 'planet-focus-proof';
    const anchorMaterial = new THREE.MeshBasicMaterial({ color: 0x53ff9a, depthTest: false, depthWrite: false });
    const targetMaterial = new THREE.MeshBasicMaterial({ color: 0xffffff, depthTest: false, depthWrite: false });
    const lineMaterial = new THREE.LineBasicMaterial({ color: 0x82f7ff, transparent: true, opacity: .88, depthTest: false, depthWrite: false });
    const proofMaterial = new THREE.MeshBasicMaterial({ color: 0x8b7cff, transparent: true, opacity: .18, wireframe: true, depthWrite: false });
    ownedMaterials.add(anchorMaterial);
    ownedMaterials.add(targetMaterial);
    ownedMaterials.add(lineMaterial);
    ownedMaterials.add(proofMaterial);
    focusAnchorMarker = new THREE.Mesh(new THREE.SphereGeometry(.42, 10, 8), anchorMaterial);
    focusTargetMarker = new THREE.Mesh(new THREE.SphereGeometry(.3, 10, 8), targetMaterial);
    focusTargetLine = new THREE.Line(new THREE.BufferGeometry(), lineMaterial);
    focusBoundsProof = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), proofMaterial);
    focusBoundsProof.visible = false;
    orbitProof = new THREE.Mesh(
      new THREE.TorusGeometry(1, .045, 5, 72),
      new THREE.MeshBasicMaterial({ color: 0x6eefff, transparent: true, opacity: .24, depthTest: false, depthWrite: false }),
    );
    ownedMaterials.add(orbitProof.material);
    orbitProof.visible = false;
    focusProofGroup.add(focusAnchorMarker, focusTargetMarker, focusTargetLine, focusBoundsProof, orbitProof);
    focusProofGroup.visible = false;
    scene.add(focusProofGroup);
  }

  function syncFocusAnchor(view) {
    if (!isFocusV3 || !planetFocusAnchor || !view) return null;
    const position = getPlanetWorldPosition(view);
    planetFocusAnchor.position.copy(position);
    planetFocusAnchor.updateMatrixWorld(true);
    return position;
  }

  function focusLimitsFor(view) {
    const camera = graph.camera();
    const radius = Math.max(.1, view.radius * 1.08);
    const ideal = focusDistanceForBoundingRadius(radius, camera.fov || 50, camera.aspect || 1, UNIVERSE_V3_ENTRY_VIEWPORT_FILL);
    return {
      // V3 continues from planet overview down to city scale.  At this
      // distance the decorative violet shell fades away, leaving only the
      // local node field rather than switching to a separate map view.
      min: radius * .28,
      ideal: Math.max(radius * 2.5, ideal),
      max: Math.max(radius * 11, ideal * 2.8),
      radius,
    };
  }

  function freezeGalaxyLayout() {
    if (!isFocusV3 || !v3Debug.forceFreeze || frozenGalaxyPositions) return;
    frozenGalaxyPositions = mock.galaxy.nodes.map((node) => ({ id: node.id, fx: node.fx, fy: node.fy, fz: node.fz }));
    mock.galaxy.nodes.forEach((node) => {
      node.fx = node.x;
      node.fy = node.y;
      node.fz = node.z;
    });
    graph?.d3AlphaTarget?.(0);
  }

  function restoreGalaxyLayout() {
    if (!frozenGalaxyPositions) return;
    const savedById = new Map(frozenGalaxyPositions.map((entry) => [entry.id, entry]));
    mock.galaxy.nodes.forEach((node) => {
      const saved = savedById.get(node.id);
      if (!saved) return;
      node.fx = saved.fx;
      node.fy = saved.fy;
      node.fz = saved.fz;
    });
    frozenGalaxyPositions = null;
  }

  function setV3BackgroundFocus(nodeId, progress = 1) {
    if (!isFocusV3) return;
    const adjacent = new Set();
    mock.galaxy.links.forEach((link) => {
      if (link.source === nodeId) adjacent.add(link.target);
      if (link.target === nodeId) adjacent.add(link.source);
    });
    nodeViews.forEach((candidate, id) => {
      const isSelected = id === nodeId;
      const isNeighbor = adjacent.has(id);
      if (isSelected && state.level === UNIVERSE_LEVEL.PLANET && detailGlobe?.parent === candidate.detailMount) {
        hideFocusedOverviewVisual(candidate);
        return;
      }
      const baseOpacity = isSelected ? 1 : isNeighbor ? .62 : candidate.root.userData.isPlanet ? .38 : .22;
      const visibleOpacity = v3Debug.backgroundPlanets || isSelected ? baseOpacity : isSelected ? 1 : .04;
      candidate.proxySphere.material.opacity = 1 + (visibleOpacity - 1) * progress;
      candidate.glow.material.opacity = isSelected ? .44 : visibleOpacity * .08;
    });
    graph.linkOpacity(v3Debug.galaxyLinks ? .28 * (1 - progress * .35) : .02);
  }

  function hideFocusedOverviewVisual(view) {
    if (!view) return;
    view.proxySphere.material.transparent = true;
    view.proxySphere.material.opacity = 0;
    view.proxySphere.material.depthWrite = false;
    view.proxySphere.visible = false;
    view.glow.material.opacity = 0;
    view.glow.visible = false;
    view.ring.visible = false;
  }

  function prepareFocusedOverviewReturn(view) {
    if (!view) return;
    view.proxySphere.visible = true;
    view.proxySphere.material.transparent = true;
    view.proxySphere.material.opacity = 0;
    view.proxySphere.material.depthWrite = false;
    view.glow.visible = true;
    view.glow.material.opacity = 0;
  }

  function scheduleV3VisualRefresh() {
    if (!isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || v3VisualRefreshFrame) return;
    v3VisualRefreshFrame = window.requestAnimationFrame(() => {
      v3VisualRefreshFrame = 0;
      if (destroyed || state.level !== UNIVERSE_LEVEL.PLANET) return;
      refreshUniverseV5PlanetVisuals();
    });
  }

  function syncDetailGlobeView() {
    if (!isFocusV3 || !detailGlobe || !graph) return;
    const renderer = graph.renderer?.();
    renderer?.getSize?.(detailRendererSize);
    detailGlobe.rendererSize?.(detailRendererSize);
    detailGlobe.setPointOfView?.(graph.camera());
    detailPovUpdates += 1;
    if (state.level === UNIVERSE_LEVEL.PLANET) scheduleV3VisualRefresh();
  }

  function finalizeV5PlanetBody() {
    if (!isFocusV3 || !detailGlobe) return;
    const material = detailGlobe.globeMaterial?.();
    if (!material) return;
    material.visible = true;
    material.transparent = false;
    material.opacity = 1;
    material.depthWrite = true;
  }

  function refreshUniverseV5PlanetShell() {
    if (!isFocusV3 || !detailGlobe || !graph || state.level !== UNIVERSE_LEVEL.PLANET) return;
    const selectedPlanet = planetViews.get(state.selectedGalaxyNodeId);
    const material = detailGlobe.globeMaterial?.();
    if (!selectedPlanet || !material) return;
    const distanceInRadii = graph.camera().position.distanceTo(getPlanetWorldPosition(selectedPlanet))
      / Math.max(selectedPlanet.radius, .001);
    // The shell belongs to the planet overview.  It dissolves before the
    // user reaches the city layer, without hiding the atom children.
    // Once a city is selected the shell would only occlude the city context.
    // The city field remains in the exact same ThreeGlobe/ForceGraph scene.
    const shellOpacity = state.selectedPlanetNodeId
      ? 0
      : Math.max(0, Math.min(1, (distanceInRadii - 1.8) / .65));
    material.visible = shellOpacity > .015;
    material.transparent = shellOpacity < .995;
    material.opacity = shellOpacity;
    material.depthWrite = shellOpacity > .12;
  }

  function refreshFocusProof() {
    if (!isFocusV3 || !focusProofGroup || !planetFocusAnchor || !graph) return;
    const controls = graph.controls();
    const activeView = planetViews.get(state.selectedGalaxyNodeId);
    const active = state.level === UNIVERSE_LEVEL.PLANET && Boolean(activeView);
    const proofVisible = active && (v3Debug.targetProof || v3Debug.orbitProof || v3Debug.boundsProof);
    focusProofGroup.visible = proofVisible;
    if (!proofVisible) return;
    const center = syncFocusAnchor(activeView);
    focusAnchorMarker.position.copy(center);
    focusTargetMarker.position.copy(controls.target);
    focusTargetLine.geometry.dispose();
    focusTargetLine.geometry = new THREE.BufferGeometry().setFromPoints([center, controls.target.clone()]);
    const limits = state.focusLimits || focusLimitsFor(activeView);
    focusBoundsProof.position.copy(center);
    focusBoundsProof.scale.setScalar(limits.radius);
    focusBoundsProof.visible = Boolean(v3Debug.boundsProof);
    orbitProof.position.copy(center);
    orbitProof.scale.setScalar(cameraDistanceToAnchor() || limits.ideal);
    orbitProof.quaternion.copy(graph.camera().quaternion);
    orbitProof.visible = Boolean(v3Debug.orbitProof);
    focusAnchorMarker.visible = Boolean(v3Debug.targetProof);
    focusTargetMarker.visible = Boolean(v3Debug.targetProof);
    focusTargetLine.visible = Boolean(v3Debug.targetProof);
  }

  function cameraDistanceToAnchor() {
    if (!planetFocusAnchor || !graph) return 0;
    return graph.camera().position.distanceTo(planetFocusAnchor.position);
  }

  function enforcePlanetFocusLock() {
    if (!isFocusV3 || !v3Debug.targetLock || !graph || focusLockMutating || state.level !== UNIVERSE_LEVEL.PLANET) return;
    const activeView = planetViews.get(state.selectedGalaxyNodeId);
    if (!activeView) return;
    const controls = graph.controls();
    const camera = graph.camera();
    const anchor = syncFocusAnchor(activeView);
    const limits = state.focusLimits || focusLimitsFor(activeView);
    const clamped = clampOrbitDistance(camera.position, anchor, limits.min, limits.max);
    const targetNeedsUpdate = controls.target.distanceToSquared(anchor) > 1e-8;
    const cameraNeedsUpdate = camera.position.distanceToSquared(clamped) > 1e-8;
    if (!targetNeedsUpdate && !cameraNeedsUpdate) return;
    focusLockMutating = true;
    if (targetNeedsUpdate) controls.target.copy(anchor);
    if (cameraNeedsUpdate) camera.position.set(clamped.x, clamped.y, clamped.z);
    controls.update();
    focusLockMutating = false;
  }

  function scheduleV3ControlRefresh() {
    if (!isFocusV3 || destroyed || v3ControlRefreshFrame) return;
    v3ControlRefreshFrame = window.requestAnimationFrame(() => {
      v3ControlRefreshFrame = 0;
      if (destroyed || !graph) return;
      if (v3Debug.targetLock) enforcePlanetFocusLock();
      syncDetailGlobeView();
      refreshFocusProof();
    });
  }

  function applyPlanetFocusControls(view) {
    if (!isFocusV3) return;
    ensureFocusInfrastructure();
    const controls = graph.controls();
    const anchor = syncFocusAnchor(view);
    state.focusLimits = focusLimitsFor(view);
    controls.target.copy(anchor);
    controls.enablePan = false;
    controls.enableRotate = true;
    controls.enableZoom = true;
    controls.enableDamping = true;
    controls.dampingFactor = .085;
    controls.rotateSpeed = .58;
    controls.zoomSpeed = .72;
    controls.minDistance = state.focusLimits.min;
    controls.maxDistance = state.focusLimits.max;
    const camera = graph.camera();
    camera.near = Math.max(.008, view.radius * .003);
    camera.far = Math.max(camera.far, 1200);
    camera.updateProjectionMatrix();
    controls.update();
    applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.PLANET_INTERACTION);
    syncDetailGlobeView();
    refreshFocusProof();
  }

  function configureDetailGlobe(ThreeGlobe, view) {
    if (!detailGlobe) {
      detailGlobe = new ThreeGlobe({ animateIn: false, waitForGlobeReady: false })
        .showGlobe(true)
        .showAtmosphere(!isFocusV3)
        .atmosphereColor(isFocusV3 ? '#8AF2FF' : (isBrandV2 ? '#43e7f8' : '#8f6bff'))
        .atmosphereAltitude(isFocusV3 ? .06 : .12)
        .globeImageUrl(null);
      const material = isFocusV3
        ? new THREE.MeshPhongMaterial({
          // The inline ThreeGlobe must have the same material model and V3
          // reference response as the standalone V7 Globe.gl endpoint.
          color: UNIVERSE_V3_REFERENCE_LIGHTING.color,
          specular: UNIVERSE_V3_REFERENCE_LIGHTING.specular,
          shininess: UNIVERSE_V3_REFERENCE_LIGHTING.shininess,
          emissive: UNIVERSE_V3_REFERENCE_LIGHTING.emissive,
          emissiveIntensity: UNIVERSE_V3_REFERENCE_LIGHTING.emissiveIntensity,
          transparent: false,
          opacity: 1,
          depthWrite: true,
        })
        : new THREE.MeshStandardMaterial({
        // The V4 inline Force stage reuses V5's deep-violet, glass-like planet body.  The
        // cyan atoms are separate child meshes and remain the visual focus.
        color: isBrandV2 ? 0x3a237c : 0x6337d5,
        roughness: .72,
        metalness: .04,
        emissive: isBrandV2 ? 0x102c6b : 0x25104e,
        emissiveIntensity: .18,
        transparent: true,
        opacity: 1,
        depthWrite: true,
      });
      ownedMaterials.add(material);
      detailGlobe.globeMaterial(material);
    }
    detailGlobe.removeFromParent?.();
    view.detailMount.add(detailGlobe);
    detailGlobe.position.set(0, 0, 0);
    const scale = (view.radius / (detailGlobe.getGlobeRadius?.() || 100)) * UNIVERSE_V3_INLINE_GLOBE_VISUAL_RADIUS_MULTIPLIER;
    // Start at the same calibrated visual radius used by every entry frame.
    // There is no scale tween during the morph.
    detailGlobe.scale.setScalar(scale);
    detailGlobe.visible = true;
    setObjectOpacity(detailGlobe, 0);
    configurePlanetContent();
    return scale;
  }

  function configurePlanetContent() {
    if (!detailGlobe || planetContentGroup) return;
    if (isFocusV3) {
      configureV5PlanetContent();
      return;
    }
    const detailRadius = detailGlobe.getGlobeRadius?.() || 100;
    const visibleGeometry = new THREE.SphereGeometry(1, 12, 10);
    const hitGeometry = new THREE.SphereGeometry(1, 10, 8);
    const glowGeometry = new THREE.SphereGeometry(1, 12, 10);
    const hitMaterial = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
    const edgeMaterial = new THREE.LineBasicMaterial({
      color: isBrandV2 ? DJINN_V2.structure : 0xddd1ff,
      transparent: true,
      opacity: 0,
    });
    ownedMaterials.add(hitMaterial);
    ownedMaterials.add(edgeMaterial);
    planetContentGroup = new THREE.Group();
    planetContentGroup.name = 'planet-content';
    planetContentGroup.visible = false;
    const pointById = new Map();

    mock.planet.nodes.forEach((node, index) => {
      const point = fibonacciSpherePoint(index, mock.planet.nodes.length, detailRadius, .025);
      const rootGroup = new THREE.Group();
      const isBridge = isBrandV2 && [0, 7, 11].includes(index);
      const visibleMaterial = new THREE.MeshStandardMaterial({
        color: isBridge ? DJINN_V2.focus : (isBrandV2 ? DJINN_V2.atom : 0xf6d76b),
        roughness: .5,
        metalness: .06,
        transparent: true,
        opacity: 0,
      });
      const glowMaterial = new THREE.MeshBasicMaterial({
        color: isBridge ? DJINN_V2.focusGlow : (isBrandV2 ? DJINN_V2.atomGlow : 0xffe786),
        transparent: true,
        opacity: 0,
        depthWrite: false,
        side: THREE.BackSide,
      });
      ownedMaterials.add(visibleMaterial);
      ownedMaterials.add(glowMaterial);
      const visibleSphere = new THREE.Mesh(visibleGeometry, visibleMaterial);
      const glow = new THREE.Mesh(glowGeometry, glowMaterial);
      const hitSphere = new THREE.Mesh(hitGeometry, hitMaterial);
      hitSphere.userData.isInvisibleHitTarget = true;
      // Raycaster can still intersect this explicitly supplied mesh while it
      // stays out of the render list. Rendering 700 transparent hit meshes is
      // especially expensive on Android WebView.
      hitSphere.visible = false;
      const baseScale = 2.5 + node.importance * 2.6;
      visibleSphere.scale.setScalar(baseScale);
      glow.scale.setScalar(baseScale * 1.52);
      hitSphere.scale.setScalar(baseScale * 2.1);
      rootGroup.position.set(point.x, point.y, point.z);
      rootGroup.userData = { planetNodeId: node.id };
      rootGroup.add(visibleSphere, glow, hitSphere);
      const normal = new THREE.Vector3(point.x, point.y, point.z).normalize();
      planetContentGroup.add(rootGroup);
      const baseOpacity = isBrandV2 && index >= 12 ? .28 : 1;
      planetNodeViews.set(node.id, {
        id: node.id,
        root: rootGroup,
        visibleSphere,
        glow,
        hitSphere,
        normal,
        baseScale,
        baseOpacity,
        baseColor: visibleMaterial.color.clone(),
        baseGlowColor: glowMaterial.color.clone(),
      });
      pointById.set(node.id, point);
    });

    mock.planet.links.forEach((link) => {
      const source = pointById.get(link.source);
      const target = pointById.get(link.target);
      if (!source || !target) return;
      const angularDot = new THREE.Vector3(source.x, source.y, source.z).normalize().dot(new THREE.Vector3(target.x, target.y, target.z).normalize());
      const lift = angularDot < .2 ? .08 : .035;
      const points = surfaceArcPoints(source, target, detailRadius, 8, lift).map((point) => new THREE.Vector3(point.x, point.y, point.z));
      const geometry = new THREE.BufferGeometry().setFromPoints(points);
      const material = edgeMaterial.clone();
      ownedMaterials.add(material);
      const line = new THREE.Line(geometry, material);
      planetContentGroup.add(line);
      planetLinkViews.push({ source: link.source, target: link.target, line, material });
    });

    if (isBrandV2) {
      [0, Math.PI / 3, -Math.PI / 3, Math.PI / 2].forEach((rotationY, index) => {
        const orbit = new THREE.Mesh(
          new THREE.TorusGeometry(detailRadius * (1.08 + index * .035), .34, 6, 72),
          new THREE.MeshBasicMaterial({
            color: index === 3 ? DJINN_V2.atom : DJINN_V2.structure,
            transparent: true,
            opacity: 0,
            depthWrite: false,
          }),
        );
        orbit.rotation.y = rotationY;
        orbit.rotation.x = index % 2 ? .42 : -.28;
        orbit.userData.isDjinnOrbit = true;
        ownedMaterials.add(orbit.material);
        planetContentGroup.add(orbit);
        planetOrbitViews.push(orbit);
      });
    }

    detailGlobe.add(planetContentGroup);
  }

  function v5PlanetPoint(atom, detailRadius, index) {
    const fromGlobe = detailGlobe?.getCoords?.(atom.lat, atom.lng, atom.altitude);
    if (fromGlobe && Number.isFinite(fromGlobe.x) && Number.isFinite(fromGlobe.y) && Number.isFinite(fromGlobe.z)) {
      return new THREE.Vector3(fromGlobe.x, fromGlobe.y, fromGlobe.z);
    }
    // The fallback preserves the deterministic V5 order should an older
    // three-globe vendor omit getCoords().
    const point = fibonacciSpherePoint(index, universeV5Planet.atoms.length, detailRadius, atom.altitude || .014);
    return new THREE.Vector3(point.x, point.y, point.z);
  }

  function configureV5PlanetContent() {
    if (!detailGlobe || planetContentGroup || !universeV5Planet) return;
    const detailRadius = detailGlobe.getGlobeRadius?.() || 100;
    const visibleGeometry = new THREE.SphereGeometry(1, 24, 18);
    const glowGeometry = new THREE.SphereGeometry(1, 16, 12);
    const hitGeometry = new THREE.SphereGeometry(1, 12, 10);
    const ringGeometry = new THREE.TorusGeometry(1, .035, 7, 24);
    const hitMaterial = new THREE.MeshBasicMaterial({
      transparent: true,
      opacity: 0,
      depthTest: false,
      depthWrite: false,
    });
    ownedMaterials.add(hitMaterial);

    planetContentGroup = new THREE.Group();
    planetContentGroup.name = 'universe-v3-v5-planet-content';
    planetContentGroup.visible = false;

    universeV5Planet.atoms.forEach((atom, index) => {
      const point = v5PlanetPoint(atom, detailRadius, index);
      const normal = point.clone().normalize();
      const rootGroup = new THREE.Group();
      const visibleMaterial = new THREE.MeshStandardMaterial({
        color: atom.color,
        emissive: atom.glow,
        emissiveIntensity: .42,
        roughness: .65,
        metalness: .05,
        transparent: true,
        opacity: 0,
        depthTest: false,
        depthWrite: false,
      });
      const glowMaterial = new THREE.MeshBasicMaterial({
        color: atom.glow,
        transparent: true,
        opacity: 0,
        depthTest: false,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      });
      ownedMaterials.add(visibleMaterial);
      ownedMaterials.add(glowMaterial);
      const visibleSphere = new THREE.Mesh(visibleGeometry, visibleMaterial);
      const glow = new THREE.Mesh(glowGeometry, glowMaterial);
      const hitSphere = new THREE.Mesh(hitGeometry, hitMaterial);
      hitSphere.userData.isInvisibleHitTarget = true;
      // Raycasting receives this mesh explicitly, so it need not consume a
      // draw call merely to provide a generous mobile hit target.
      hitSphere.visible = false;
      const labelAnchor = new THREE.Group();
      labelAnchor.name = `universe-v5-label-anchor:${atom.id}`;
      const baseScale = atom.visualRadius;
      visibleSphere.scale.setScalar(baseScale);
      visibleSphere.renderOrder = 3;
      glow.scale.setScalar(baseScale * 1.58);
      glow.renderOrder = 4;
      hitSphere.scale.setScalar(Math.max(baseScale * 1.5, 3.5));
      rootGroup.position.copy(point);
      labelAnchor.position.copy(normal).multiplyScalar(Math.max(baseScale * 3.1, detailRadius * .035));
      labelAnchor.visible = false;
      rootGroup.userData = { planetNodeId: atom.id, v5Atom: true };
      rootGroup.add(visibleSphere, glow, hitSphere, labelAnchor);

      let bridgeRing = null;
      if (atom.hasBridgeRing) {
        const ringMaterial = new THREE.MeshBasicMaterial({
          color: 0xBFEFFF,
          transparent: true,
          opacity: 0,
          depthTest: false,
          depthWrite: false,
          blending: THREE.AdditiveBlending,
        });
        ownedMaterials.add(ringMaterial);
        bridgeRing = new THREE.Mesh(ringGeometry, ringMaterial);
        bridgeRing.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal);
        bridgeRing.scale.setScalar(baseScale * 1.18);
        bridgeRing.renderOrder = 5;
        rootGroup.add(bridgeRing);
      }

      planetContentGroup.add(rootGroup);
      planetNodeViews.set(atom.id, {
        id: atom.id,
        atom,
        root: rootGroup,
        visibleSphere,
        glow,
        hitSphere,
        bridgeRing,
        labelAnchor,
        labelSprite: null,
        normal,
        baseScale,
        baseOpacity: 1,
        baseColor: visibleMaterial.color.clone(),
        baseGlowColor: glowMaterial.color.clone(),
        v5: true,
      });
    });
    detailGlobe.add(planetContentGroup);
  }

  function universeV5RelatedCityIds(nodeId) {
    if (!nodeId || !universeV5Planet) return new Set();
    const related = new Set();
    universeV5Planet.physicsEdges.forEach((edge) => {
      if (edge.source === nodeId) related.add(edge.target);
      if (edge.target === nodeId) related.add(edge.source);
    });
    return related;
  }

  function updateUniverseV5FocusArcs(nodeId) {
    if (!isFocusV3 || !detailGlobe || !universeV5Planet) return;
    const atomsById = new Map(universeV5Planet.atoms.map((atom) => [atom.id, atom]));
    const arcs = (nodeId ? universeV5Planet.physicsEdges : [])
      .filter((edge) => edge.source === nodeId || edge.target === nodeId)
      .map((edge) => {
        const source = atomsById.get(edge.source);
        const target = atomsById.get(edge.target);
        if (!source || !target) return null;
        return {
          id: `universe-v5-focus-${edge.source}-${edge.target}`,
          source: edge.source,
          target: edge.target,
          startLat: source.lat,
          startLng: source.lng,
          startAltitude: source.altitude + .022,
          endLat: target.lat,
          endLng: target.lng,
          endAltitude: target.altitude + .022,
        };
      })
      .filter(Boolean);
    detailGlobe
      .arcsData(arcs)
      .arcStartLat((arc) => arc.startLat)
      .arcStartLng((arc) => arc.startLng)
      .arcStartAltitude((arc) => arc.startAltitude)
      .arcEndLat((arc) => arc.endLat)
      .arcEndLng((arc) => arc.endLng)
      .arcEndAltitude((arc) => arc.endAltitude)
      .arcAltitude(() => .026)
      .arcStroke((arc) => state.selectedPlanetEdgeId === arc.id ? .17 : .14)
      .arcColor((arc) => state.selectedPlanetEdgeId === arc.id ? '#FFE8A4' : '#FFD45A')
      .arcDashLength(1)
      .arcDashGap(0)
      .arcsTransitionDuration(0);
  }

  function refreshUniverseV5CityContext() {
    if (!cityContext) return;
    const selected = planetNodeViews.get(state.selectedPlanetNodeId);
    if (!isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || !selected?.v5) {
      cityContext.hidden = true;
      cityContext.replaceChildren();
      return;
    }
    const connections = universeV5RelatedCityIds(selected.id).size;
    cityContext.hidden = false;
    cityContext.innerHTML = `
      <span><strong>${String(selected.atom.label || selected.id)}</strong><small>${connections} kapcsolat · city context</small></span>
      <button type="button" data-universe-city-action="street-map">Street Map</button>
      <button type="button" data-universe-city-action="clear" aria-label="City kijelölés törlése">×</button>`;
  }

  function selectUniverseV5City(nodeId) {
    if (!isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || !planetNodeViews.get(nodeId)?.v5) return;
    state.selectedPlanetNodeId = state.selectedPlanetNodeId === nodeId ? null : nodeId;
    state.selectedPlanetEdgeId = null;
    updateUniverseV5FocusArcs(state.selectedPlanetNodeId);
    refreshUniverseV5PlanetVisuals();
    refreshUniverseV5CityContext();
    updateDebug();
  }

  function selectUniverseV5Edge(edgeId) {
    if (!isFocusV3 || !state.selectedPlanetNodeId) return;
    state.selectedPlanetEdgeId = state.selectedPlanetEdgeId === edgeId ? null : edgeId;
    updateUniverseV5FocusArcs(state.selectedPlanetNodeId);
    updateDebug();
  }

  function refreshUniverseV5PlanetVisuals(masterOpacity = 1) {
    if (!isFocusV3 || !planetContentGroup || !graph) return;
    const selectedPlanet = planetViews.get(state.selectedGalaxyNodeId);
    if (!selectedPlanet) return;
    graph.scene().updateMatrixWorld(true);
    const center = selectedPlanet.root.getWorldPosition(v3PlanetCenter);
    const controls = graph.controls();
    const cameraDirection = v3CameraDirection.copy(graph.camera().position).sub(controls.target).normalize();
    const selectedCityId = state.selectedPlanetNodeId;
    const relatedCities = universeV5RelatedCityIds(selectedCityId);
    planetNodeViews.forEach((view) => {
      if (!view.v5) return;
      const world = view.root.getWorldPosition(v3PlanetNodeWorld);
      const facing = world.sub(center).normalize().dot(cameraDirection);
      const smooth = Math.max(0, Math.min(1, (facing + .42) / 1.42));
      const isSelected = selectedCityId === view.id;
      const isRelated = relatedCities.has(view.id);
      const contextOpacity = !selectedCityId ? 1 : (isSelected ? 1 : (isRelated ? .86 : .12));
      const sphereOpacity = masterOpacity * (.44 + .56 * smooth) * contextOpacity;
      view.visibleSphere.material.color.set(isSelected ? '#FFD45A' : (!selectedCityId || isRelated ? view.atom.color : '#0A4264'));
      view.visibleSphere.material.emissive.set(isSelected ? '#FFE69A' : (!selectedCityId || isRelated ? view.atom.glow : '#062239'));
      view.visibleSphere.material.emissiveIntensity = isSelected ? .98 : (!selectedCityId ? .42 : (isRelated ? .62 : .06));
      view.visibleSphere.material.opacity = sphereOpacity;
      view.visibleSphere.scale.setScalar(view.baseScale * (isSelected ? 1.16 : (isRelated ? 1.035 : 1)));
      view.glow.material.color.set(isSelected ? '#FFE69A' : view.atom.glow);
      const glowOpacity = masterOpacity * (.06 + .10 * smooth) * (isSelected ? 2.8 : (isRelated ? 1.5 : (selectedCityId ? .25 : 1)));
      view.glow.material.opacity = glowOpacity;
      // Back-facing additive glows create the costliest overdraw but add
      // almost nothing to the city-level reading of the globe.
      view.glow.visible = glowOpacity > .02 && smooth > .08;
      view.glow.scale.setScalar(view.baseScale * 1.58 * (1.92 - .42 * smooth) * (isSelected ? 1.18 : 1));
      view.hitSphere.scale.setScalar(Math.max(view.baseScale * 1.5, 3.5));
      if (view.bridgeRing) {
        view.bridgeRing.visible = masterOpacity > 0;
        view.bridgeRing.material.opacity = masterOpacity * (.22 + .16 * smooth) * (isSelected ? 1 : (selectedCityId && !isRelated ? .25 : 1));
        view.bridgeRing.scale.setScalar(view.baseScale * 1.18);
      }
      view.root.visible = masterOpacity > 0;
    });
    refreshUniverseV5PlanetShell();
    refreshUniverseV5LabelSprites(masterOpacity);
  }

  function universeLabelDistance() {
    const selectedPlanet = planetViews.get(state.selectedGalaxyNodeId);
    if (!selectedPlanet || !graph) return Infinity;
    return graph.camera().position.distanceTo(getPlanetWorldPosition(selectedPlanet)) / Math.max(selectedPlanet.radius, .001);
  }

  function universeLabelLimit() {
    const distance = universeLabelDistance();
    if (distance > 5.2) return 3;
    if (distance < 2.6) return 8;
    return 5;
  }

  function universeV5LabelCandidates() {
    const compare = (a, b) => (b.atom.weightedDegree - a.atom.weightedDegree) || a.id.localeCompare(b.id);
    const views = [...planetNodeViews.values()].filter((view) => view.v5).sort(compare);
    const byCommunity = new Map();
    views.forEach((view) => {
      const key = view.atom.community ?? 'global';
      const current = byCommunity.get(key);
      if (!current || compare(view, current) < 0) byCommunity.set(key, view);
    });
    const seen = new Set();
    const selected = planetNodeViews.get(state.selectedPlanetNodeId);
    return [selected, ...byCommunity.values(), ...views].filter((view) => {
      if (!view?.v5) return false;
      if (seen.has(view.id)) return false;
      seen.add(view.id);
      return true;
    });
  }

  function universeV5LabelText(view) {
    return String(view?.atom?.label || view?.id || '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 28);
  }

  function roundedLabelRect(context, x, y, width, height, radius) {
    const corner = Math.min(radius, width / 2, height / 2);
    context.beginPath();
    context.moveTo(x + corner, y);
    context.arcTo(x + width, y, x + width, y + height, corner);
    context.arcTo(x + width, y + height, x, y + height, corner);
    context.arcTo(x, y + height, x, y, corner);
    context.arcTo(x, y, x + width, y, corner);
    context.closePath();
  }

  function universeV5LabelTexture(text, focused) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const key = `${focused ? 'focus' : 'landmark'}:${dpr}:${text}`;
    const cached = universeV5LabelTextureCache.get(key);
    if (cached) return cached;

    const logicalHeight = 23;
    const logicalWidth = Math.min(148, Math.max(48, Math.ceil(text.length * 6.6 + 20)));
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(logicalWidth * dpr);
    canvas.height = Math.ceil(logicalHeight * dpr);
    const context = canvas.getContext('2d');
    context.scale(dpr, dpr);
    context.clearRect(0, 0, logicalWidth, logicalHeight);
    context.shadowColor = focused ? 'rgba(255, 210, 90, .42)' : 'rgba(67, 231, 248, .18)';
    context.shadowBlur = focused ? 8 : 6;
    roundedLabelRect(context, .75, .75, logicalWidth - 1.5, logicalHeight - 1.5, logicalHeight / 2);
    context.fillStyle = focused ? 'rgba(103, 62, 19, .86)' : 'rgba(7, 31, 67, .82)';
    context.fill();
    context.shadowBlur = 0;
    context.lineWidth = 1;
    context.strokeStyle = focused ? 'rgba(255, 231, 131, .96)' : 'rgba(117, 241, 250, .54)';
    context.stroke();
    context.fillStyle = focused ? '#fff7d0' : 'rgba(236, 252, 255, .94)';
    context.font = '750 10px system-ui, sans-serif';
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(text, logicalWidth / 2, logicalHeight / 2 + .25, logicalWidth - 18);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.generateMipmaps = false;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    const entry = { texture, aspect: logicalWidth / logicalHeight };
    universeV5LabelTextureCache.set(key, entry);
    universeV5LabelTextureRebuilds += 1;
    return entry;
  }

  function releaseUniverseV5LabelSprite(sprite) {
    const ownerId = sprite?.userData?.labelOwnerId;
    if (!ownerId) return;
    universeV5LabelSprites.delete(ownerId);
    const owner = planetNodeViews.get(ownerId);
    if (owner) owner.labelSprite = null;
    sprite.removeFromParent();
    sprite.userData.labelOwnerId = null;
  }

  function createUniverseV5LabelSprite(view, reservedIds = new Set()) {
    if (!view?.v5 || !view.labelAnchor) return null;
    const existing = universeV5LabelSprites.get(view.id);
    if (existing) return existing;
    let sprite = universeV5LabelPool.find((entry) => !reservedIds.has(entry.userData.labelOwnerId));
    if (sprite) releaseUniverseV5LabelSprite(sprite);
    if (!sprite && universeV5LabelPool.length < UNIVERSE_V5_LABEL_POOL_LIMIT) {
      const material = new THREE.SpriteMaterial({
        transparent: true,
        opacity: 0,
        depthTest: false,
        depthWrite: false,
        color: 0xffffff,
      });
      sprite = new THREE.Sprite(material);
      sprite.name = `universe-v5-label-sprite:${universeV5LabelPool.length}`;
      sprite.center.set(.5, 0);
      sprite.renderOrder = 12;
      sprite.visible = false;
      ownedMaterials.add(material);
      universeV5LabelPool.push(sprite);
    }
    // A current LOD uses at most eight labels and the pool contains fifteen.
    // This fallback only guards corrupted/partial state without creating an
    // unbounded collection during an extended camera orbit.
    if (!sprite) return null;
    view.labelAnchor.add(sprite);
    view.labelSprite = sprite;
    sprite.userData.labelOwnerId = view.id;
    universeV5LabelSprites.set(view.id, sprite);
    return sprite;
  }

  function hideUniverseV5LabelSprites() {
    universeV5LabelSprites.forEach((sprite) => {
      sprite.visible = false;
      sprite.material.opacity = 0;
      if (sprite.parent) sprite.parent.visible = false;
    });
    universeV5ActiveLabelCount = 0;
  }

  function refreshUniverseV5LabelSprites(masterOpacity = 1) {
    if (suppressInlineCityLabels) {
      hideUniverseV5LabelSprites();
      return;
    }
    const active = isFocusV3
      && state.level === UNIVERSE_LEVEL.PLANET
      && planetContentGroup?.visible
      && planetNodeViews.size > 0;
    if (!active || !graph) {
      hideUniverseV5LabelSprites();
      return;
    }
    const selectedPlanet = planetViews.get(state.selectedGalaxyNodeId);
    if (!selectedPlanet) {
      hideUniverseV5LabelSprites();
      return;
    }
    graph.scene().updateMatrixWorld(true);
    const camera = graph.camera();
    const center = getPlanetWorldPosition(selectedPlanet);
    const cameraDirection = camera.position.clone().sub(center).normalize();
    const detailWorldScale = Math.max(.001, detailGlobe?.getWorldScale(new THREE.Vector3()).x || 1);
    const selectedId = state.selectedPlanetNodeId;
    const acceptedDirections = [];
    const labelEntries = [];
    const limit = universeLabelLimit();

    for (const view of universeV5LabelCandidates()) {
      if (labelEntries.length >= limit) break;
      const text = universeV5LabelText(view);
      if (!text) continue;
      const world = view.root.getWorldPosition(new THREE.Vector3());
      const direction = world.clone().sub(center).normalize();
      const facing = direction.dot(cameraDirection);
      const focused = selectedId === view.id;
      // Sprite position is inherited from LabelAnchor inside the atom group.
      // Camera movement therefore needs no DOM projection, layout read, timer,
      // throttle or separate requestAnimationFrame to keep labels in sync.
      if (facing < (focused ? -.16 : -.035)) continue;
      if (acceptedDirections.some((other) => direction.dot(other) > .972)) continue;
      labelEntries.push({ view, text, world, facing, focused, direction });
      acceptedDirections.push(direction);
    }

    const visibleIds = new Set(labelEntries.map(({ view }) => view.id));
    labelEntries.forEach(({ view, text, world, facing, focused }) => {
      const sprite = createUniverseV5LabelSprite(view, visibleIds);
      if (!sprite) {
        visibleIds.delete(view.id);
        return;
      }
      const texture = universeV5LabelTexture(text, focused);
      if (sprite.material.map !== texture.texture) {
        sprite.material.map = texture.texture;
        sprite.material.needsUpdate = true;
      }
      const distance = camera.position.distanceTo(world);
      const localHeight = worldUnitsForPlanetHitPixels(distance, focused ? 15 : 12) / detailWorldScale;
      const horizonOpacity = Math.max(0, Math.min(1, (facing + .08) / .34));
      view.labelAnchor.visible = true;
      sprite.visible = horizonOpacity > .015 && masterOpacity > 0;
      sprite.material.opacity = masterOpacity * horizonOpacity;
      sprite.scale.set(localHeight * texture.aspect, localHeight, 1);
    });

    universeV5LabelSprites.forEach((sprite, id) => {
      if (visibleIds.has(id)) return;
      sprite.visible = false;
      sprite.material.opacity = 0;
      if (sprite.parent) sprite.parent.visible = false;
    });
    universeV5ActiveLabelCount = visibleIds.size;
  }

  // Existing selection/morph call sites keep this semantic API; labels are
  // now Sprite scene objects, not manually projected HTML chips.
  function refreshUniverseV5Labels() {
    refreshUniverseV5LabelSprites();
  }

  function setPlanetContentOpacity(opacity) {
    if (!planetContentGroup) return;
    planetContentGroup.visible = opacity > 0;
    if (isFocusV3) {
      refreshUniverseV5PlanetVisuals(opacity);
      return;
    }
    planetNodeViews.forEach((view) => {
      view.visibleSphere.material.opacity = opacity * view.baseOpacity;
      view.glow.material.opacity = opacity * .17 * view.baseOpacity;
    });
    planetLinkViews.forEach((edge) => { edge.material.opacity = opacity * .24; });
    planetOrbitViews.forEach((orbit) => { orbit.material.opacity = opacity * .42; });
  }

  // The U3 focused planet is not a follow-up effect after the Force camera
  // arrives. Camera travel and the inline ThreeGlobe reveal consume this same
  // eased value on every frame, so one tap reads as one continuous approach.
  function applyInlinePlanetEntryMorph(view, detailScale, eased, nodeId) {
    if (!isFocusV3 || !detailGlobe || !Number.isFinite(detailScale)) return;
    const overviewOpacity = 1 - eased;
    view.proxySphere.visible = overviewOpacity > .01;
    view.proxySphere.material.transparent = true;
    view.proxySphere.material.opacity = overviewOpacity;
    view.proxySphere.material.depthWrite = overviewOpacity > .04;
    view.glow.visible = overviewOpacity > .01;
    view.glow.material.opacity = .44 * overviewOpacity;
    // Do not tween geometry scale here. The proxy and ThreeGlobe have the
    // same measured world radius; opacity/content is the morph, not shrink.
    detailGlobe.scale.setScalar(detailScale);
    setObjectOpacity(detailGlobe, eased);
    setPlanetContentOpacity(Math.max(0, (eased - .32) / .68));
    setV3BackgroundFocus(nodeId, eased);
    syncDetailGlobeView();
  }

  function ensureCorridorLayer() {
    if (corridorLayer) return;
    corridorLayer = new THREE.Group();
    corridorLayer.name = 'planet-corridor-layer';
    corridorTargetView = new THREE.Group();
    const targetSphere = new THREE.Mesh(sharedSphereGeometry, new THREE.MeshStandardMaterial({
      color: 0x8a63e8,
      roughness: .62,
      metalness: .05,
      transparent: true,
      opacity: 0,
      depthTest: true,
      depthWrite: true,
    }));
    const targetGlow = new THREE.Mesh(sharedSphereGeometry, new THREE.MeshBasicMaterial({
      color: 0x9b7bff,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      side: THREE.BackSide,
    }));
    ownedMaterials.add(targetSphere.material);
    ownedMaterials.add(targetGlow.material);
    targetGlow.scale.setScalar(1.2);
    corridorTargetView.add(targetSphere, targetGlow);
    corridorTargetView.userData = { targetSphere, targetGlow };
    corridorLayer.add(corridorTargetView);
    corridorStrand = new THREE.Line(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({
      color: 0xc9c4ff,
      transparent: true,
      opacity: 0,
      depthTest: false,
      depthWrite: false,
    }));
    corridorStrand.name = 'planet-corridor-strand';
    corridorStrand.renderOrder = 20;
    corridorStrandHit = new THREE.Line(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({
      transparent: true,
      opacity: 0,
      depthTest: false,
      depthWrite: false,
    }));
    corridorStrandHit.name = 'planet-corridor-strand-hit';
    corridorStrandHit.renderOrder = 21;
    ownedMaterials.add(corridorStrand.material);
    ownedMaterials.add(corridorStrandHit.material);
    corridorLayer.add(corridorStrand, corridorStrandHit);
    corridorLayer.visible = false;
    graph.scene().add(corridorLayer);
  }

  function positionCorridorLayer(selectedView, neighborId) {
    ensureCorridorLayer();
    const camera = graph.camera();
    graph.scene().updateMatrixWorld(true);
    const source = selectedView.root.getWorldPosition(new THREE.Vector3());
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(camera.quaternion).normalize();
    const up = new THREE.Vector3(0, 1, 0).applyQuaternion(camera.quaternion).normalize();
    const separation = selectedView.radius * 3.25;
    const target = source.clone().add(right.multiplyScalar(separation)).add(up.multiplyScalar(selectedView.radius * .08));
    const targetRadius = selectedView.radius * .72;
    corridorTargetView.position.copy(target);
    corridorTargetView.scale.setScalar(targetRadius);
    corridorTargetView.userData.baseScale = targetRadius;
    corridorTargetView.userData.targetSphere.material.opacity = 0;
    corridorTargetView.userData.targetGlow.material.opacity = 0;
    const midpoint = source.clone().lerp(target, .5).add(camera.position.clone().sub(source).normalize().multiplyScalar(selectedView.radius * .45));
    const curve = new THREE.CatmullRomCurve3([source, midpoint, target]);
    const points = curve.getPoints(24);
    corridorStrand.geometry.dispose();
    corridorStrand.geometry = new THREE.BufferGeometry().setFromPoints(points);
    corridorStrandHit.geometry.dispose();
    corridorStrandHit.geometry = new THREE.BufferGeometry().setFromPoints(points);
    corridorStrand.userData = { source, target, neighborId };
    corridorStrandHit.userData = { source, target, neighborId };
    corridorNeighborPlanetId = neighborId;
    corridorLayer.visible = true;
  }

  function setCorridorLayerProgress(progress) {
    if (!corridorLayer) return;
    const eased = easeInOutCubic(progress);
    corridorTargetView.userData.targetSphere.material.opacity = eased;
    corridorTargetView.userData.targetGlow.material.opacity = eased * .2;
    corridorStrand.material.opacity = eased * .72;
    corridorStrandHit.visible = progress > .08;
  }

  function hideCorridorLayer() {
    if (!corridorLayer) return;
    corridorLayer.visible = false;
    corridorStrandHit.visible = false;
    corridorTargetView.userData.targetSphere.material.opacity = 0;
    corridorTargetView.userData.targetGlow.material.opacity = 0;
    corridorNeighborPlanetId = null;
  }

  function selectedCorridorAt(event) {
    if (state.level !== UNIVERSE_LEVEL.PLANET || !corridorStrandHit?.visible || !corridorNeighborPlanetId) return null;
    const rect = galaxyMount.getBoundingClientRect();
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    const raycaster = new THREE.Raycaster();
    raycaster.params.Line.threshold = Math.max(1.4, (planetViews.get(state.selectedGalaxyNodeId)?.radius || 10) * .16);
    raycaster.setFromCamera(pointer, graph.camera());
    return raycaster.intersectObject(corridorStrandHit, false).length ? corridorNeighborPlanetId : null;
  }

  function resize() {
    if (!graph || destroyed) return;
    graph.width(Math.max(1, galaxyMount.clientWidth));
    graph.height(Math.max(1, galaxyMount.clientHeight));
    universeCosmicEnvironment?.resize();
    syncDetailGlobeView();
    refreshFocusProof();
  }

  function mapPosition(index, width, height) {
    if (index === 0) return { x: width / 2, y: height / 2 };
    const angle = (index - 1) * Math.PI * (3 - Math.sqrt(5));
    const radius = 78 + Math.sqrt(index) * 34;
    return {
      x: width / 2 + Math.cos(angle) * radius,
      y: height / 2 + Math.sin(angle) * radius * .74,
    };
  }

  function toMapG6Data(focusId) {
    const replacementId = new Map([[mock.map.nodes[0].id, focusId]]);
    const width = Math.max(stage.clientWidth, 320);
    const height = Math.max(stage.clientHeight, 420);
    const nodes = mock.map.nodes.map((node, index) => {
      const id = replacementId.get(node.id) || node.id;
      const position = mapPosition(index, width, height);
      const focused = index === 0;
      return {
        id,
        type: 'rect',
        style: {
          x: position.x,
          y: position.y,
          size: focused ? [148, 56] : [96, 40],
          radius: focused ? 16 : 12,
          fill: focused ? (isBrandV2 ? '#7C4DFF' : '#8b65fa') : (isBrandV2 ? '#162c72' : '#302153'),
          stroke: focused ? (isBrandV2 ? '#FFE783' : '#d9ccff') : (isBrandV2 ? '#43E7F8' : '#8068a7'),
          lineWidth: focused ? 1.8 : 1,
          shadowColor: focused ? '#7c4dff' : '#150d2b',
          shadowBlur: focused ? 18 : 8,
          shadowOffsetY: focused ? 6 : 3,
          labelText: focused ? 'Fókuszpont' : node.label,
          labelPlacement: 'center',
          labelFill: isBrandV2 ? '#F4FBFF' : '#f1ecff',
          labelFontSize: focused ? 11 : 8.5,
          labelFontWeight: focused ? 760 : 640,
        },
      };
    });
    const replaceEndpoint = (id) => replacementId.get(id) || id;
    return {
      nodes,
      edges: mock.map.links.map((link, index) => ({
        id: `map-edge-${index}`,
        type: 'quadratic',
        source: replaceEndpoint(link.source),
        target: replaceEndpoint(link.target),
        style: { stroke: '#c9c4ff', lineWidth: 1.25, opacity: .48 },
      })),
    };
  }

  async function ensureMapGraph(focusId) {
    if (!window.G6?.Graph) throw new Error('A G6 térképmotor nem tölthető be.');
    mapMount.hidden = false;
    const data = toMapG6Data(focusId);
    if (!mapGraph) {
      mapGraph = new window.G6.Graph({
        container: mapMount,
        width: Math.max(stage.clientWidth, 320),
        height: Math.max(stage.clientHeight, 420),
        data,
        animation: { duration: 0 },
        behaviors: [{ type: 'drag-canvas' }, { type: 'zoom-canvas', enableOptimize: true }],
      });
      mapResizeObserver = new ResizeObserver(() => {
        if (!mapGraph || state.level !== UNIVERSE_LEVEL.MAP) return;
        mapGraph.resize?.(Math.max(stage.clientWidth, 320), Math.max(stage.clientHeight, 420));
      });
      mapResizeObserver.observe(stage);
    } else {
      mapGraph.setData(data);
    }
    await Promise.resolve(mapGraph.render());
  }

  function setProxyFrame({ x, y, width, height, radius, opacity, background }) {
    proxy.style.left = `${x}px`;
    proxy.style.top = `${y}px`;
    proxy.style.width = `${width}px`;
    proxy.style.height = `${height}px`;
    proxy.style.borderRadius = radius;
    proxy.style.opacity = String(opacity);
    proxy.style.background = background;
  }

  async function requestPlanetCorridor(neighborId = null) {
    if (!corridor || state.interactionLocked || state.level !== UNIVERSE_LEVEL.PLANET || !state.selectedGalaxyNodeId) return;
    const selectedView = planetViews.get(state.selectedGalaxyNodeId);
    if (!selectedView) return;
    const nextNeighbor = neighborId || mock.galaxy.planetIds.find((id) => id !== state.selectedGalaxyNodeId);
    if (!nextNeighbor) return;
    state.level = UNIVERSE_LEVEL.CORRIDOR;
    state.interactionLocked = true;
    state.corridorExpanded = true;
    corridor.hidden = false;
    corridor.classList.remove('is-closing');
    corridor.classList.add('is-open');
    controlsForCorridor().enabled = false;
    positionCorridorLayer(selectedView, nextNeighbor);
    setCorridorLayerProgress(0);
    const camera = graph.camera();
    const controls = graph.controls();
    const source = selectedView.root.getWorldPosition(new THREE.Vector3());
    const target = corridorStrand.userData.target.clone();
    const midpoint = source.clone().lerp(target, .5);
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    state.savedCorridorCamera = { position: cameraStart.clone(), target: targetStart.clone() };
    const cameraOffset = camera.position.clone().sub(controls.target);
    const corridorSpan = source.distanceTo(target);
    const desiredDistance = Math.max(cameraOffset.length(), corridorSpan * 1.35);
    const cameraEnd = midpoint.clone().add(cameraOffset.normalize().multiplyScalar(desiredDistance));
    const opened = await tween(720, (eased, raw) => {
      state.transitionProgress = raw;
      camera.position.lerpVectors(cameraStart, cameraEnd, eased);
      controls.target.lerpVectors(targetStart, midpoint, eased);
      controls.update();
      setCorridorLayerProgress(eased);
      updateDebug();
    });
    if (!opened || destroyed) return;
    state.transitionProgress = 1;
    state.interactionLocked = false;
    controls.enabled = true;
    updateDebug();
  }

  function controlsForCorridor() {
    return graph.controls();
  }

  async function closeCorridor() {
    if (!corridor || state.interactionLocked || state.level !== UNIVERSE_LEVEL.CORRIDOR) return;
    const controls = graph.controls();
    const camera = graph.camera();
    const saved = state.savedCorridorCamera;
    state.interactionLocked = true;
    controls.enabled = false;
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const closed = await tween(560, (eased, raw) => {
      state.transitionProgress = 1 - raw;
      if (saved) {
        camera.position.lerpVectors(cameraStart, saved.position, eased);
        controls.target.lerpVectors(targetStart, saved.target, eased);
        controls.update();
      }
      setCorridorLayerProgress(1 - eased);
      updateDebug();
    });
    if (!closed || destroyed) return;
    hideCorridorLayer();
    const restoredView = planetViews.get(state.selectedGalaxyNodeId);
    const restoredNeighborId = mock.galaxy.planetIds.find((id) => id !== state.selectedGalaxyNodeId);
    if (restoredView && restoredNeighborId) {
      positionCorridorLayer(restoredView, restoredNeighborId);
      corridorStrand.material.opacity = .66;
      corridorStrandHit.visible = true;
    }
    corridor.hidden = true;
    corridor.classList.remove('is-open');
    state.corridorExpanded = false;
    state.savedCorridorCamera = null;
    state.level = UNIVERSE_LEVEL.PLANET;
    state.transitionProgress = 1;
    state.interactionLocked = false;
    controls.enabled = true;
    updateDebug();
  }

  function onCorridorClick(event) {
    if (event.target.closest('[data-universe-corridor-close]')) void closeCorridor();
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
    state.savedGalaxyCamera = {
      position: camera.position.clone(),
      target: controls.target.clone(),
      quaternion: camera.quaternion.clone(),
      near: camera.near,
      far: camera.far,
      controls: isFocusV3 ? snapshotControls(controls) : null,
    };
    if (isFocusV3) {
      ensureFocusInfrastructure();
      state.focusMode = UNIVERSE_FOCUS_STATE.PLANET_FOCUS_ENTER;
      applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.PLANET_TRANSITION);
      freezeGalaxyLayout();
      setV3BackgroundFocus(nodeId, 0);
      // Keep the already-seeded virtual sun world-fixed while moving its
      // stable reference center from galaxy overview to this real node root.
      resumeUniverseCosmicEnvironment();
    } else {
      nodeViews.forEach((candidate, id) => {
        candidate.ring.visible = id === nodeId;
        candidate.glow.material.opacity = id === nodeId ? (isBrandV2 ? .48 : .34) : (isBrandV2 ? .012 : .045);
        candidate.proxySphere.material.opacity = id === nodeId ? 1 : (isBrandV2 ? .05 : .16);
      });
      graph.linkOpacity(.07);
    }
    updateDebug();

    controls.enabled = false;
    graph.scene().updateMatrixWorld(true);
    const nodePosition = view.root.getWorldPosition(new THREE.Vector3());
    const focusLimits = isFocusV3 ? focusLimitsFor(view) : null;
    if (isFocusV3) {
      syncFocusAnchor(view);
      state.focusLimits = focusLimits;
    }
    const targetCamera = focusCameraTarget(nodePosition, camera.position, controls.target, focusLimits?.ideal || view.radius * 6);
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const cameraEnd = new THREE.Vector3(targetCamera.x, targetCamera.y, targetCamera.z);
    let detailScale = null;
    let entryMorphEased = 0;
    let entryMorphSetupError = null;
    // Start resolving the concrete ThreeGlobe immediately. In the normal
    // prewarmed case it is ready before the first zoom frame; if a cold vendor
    // load takes longer, the same timeline simply catches it up at its current
    // progress instead of adding a second post-zoom animation.
    const v3MorphSetup = isFocusV3
      ? loadThreeGlobe()
        .then((ThreeGlobe) => {
          if (destroyed || state.level !== UNIVERSE_LEVEL.GALAXY_TO_PLANET) return null;
          detailScale = configureDetailGlobe(ThreeGlobe, view);
          applyInlinePlanetEntryMorph(view, detailScale, entryMorphEased, nodeId);
          return detailScale;
        })
        .catch((error) => {
          entryMorphSetupError = error;
          return null;
        })
      : null;
    const focused = await tween(isFocusV3 ? 920 : 560, (eased, raw) => {
      entryMorphEased = eased;
      state.transitionProgress = isFocusV3 ? raw : raw * .5;
      camera.position.lerpVectors(cameraStart, cameraEnd, eased);
      controls.target.lerpVectors(targetStart, nodePosition, eased);
      controls.update();
      if (isFocusV3 && detailScale != null) {
        applyInlinePlanetEntryMorph(view, detailScale, eased, nodeId);
      } else if (isFocusV3) {
        setV3BackgroundFocus(nodeId, eased);
      }
      updateDebug();
    });
    if (!focused || destroyed) return;

    try {
      if (isFocusV3) {
        const preparedDetailScale = await v3MorphSetup;
        if (entryMorphSetupError) throw entryMorphSetupError;
        if (destroyed || !Number.isFinite(preparedDetailScale)) return;
        detailScale = preparedDetailScale;
        applyInlinePlanetEntryMorph(view, detailScale, 1, nodeId);
      } else {
        const ThreeGlobe = await loadThreeGlobe();
        if (destroyed) return;
        detailScale = configureDetailGlobe(ThreeGlobe, view);
        const morphed = await tween(520, (eased, raw) => {
        state.transitionProgress = .5 + raw * .5;
        const overviewOpacity = 1 - eased;
        view.proxySphere.visible = overviewOpacity > .01;
        view.proxySphere.material.transparent = true;
        view.proxySphere.material.opacity = overviewOpacity;
        view.proxySphere.material.depthWrite = overviewOpacity > .04;
        view.glow.visible = overviewOpacity > .01;
        view.glow.material.opacity = (isFocusV3 ? .44 : .34) * overviewOpacity;
        detailGlobe.scale.setScalar(detailScale * (.92 + eased * .08));
        setObjectOpacity(detailGlobe, eased);
        setPlanetContentOpacity(Math.max(0, (eased - .32) / .68));
        if (isFocusV3) {
          setV3BackgroundFocus(nodeId, 1);
          view.proxySphere.visible = overviewOpacity > .01;
          view.proxySphere.material.opacity = overviewOpacity;
          view.proxySphere.material.depthWrite = overviewOpacity > .04;
          view.glow.visible = overviewOpacity > .01;
          view.glow.material.opacity = .44 * overviewOpacity;
          syncDetailGlobeView();
        } else {
          nodeViews.forEach((candidate, id) => {
            if (id !== nodeId) candidate.proxySphere.material.opacity = (isBrandV2 ? .05 : .16) - eased * (isBrandV2 ? .02 : .06);
          });
          graph.linkOpacity(.07 - eased * .04);
        }
        updateDebug();
        });
        if (!morphed || destroyed) return;
      }
      const neighborPlanetId = !isFocusV3 && mock.galaxy.planetIds.find((id) => id !== nodeId);
      if (neighborPlanetId) {
        positionCorridorLayer(view, neighborPlanetId);
        corridorStrand.material.opacity = .66;
        corridorStrandHit.visible = true;
      }
      state.level = UNIVERSE_LEVEL.PLANET;
      state.transitionProgress = 1;
      if (isFocusV3) {
        finalizeV5PlanetBody();
        hideFocusedOverviewVisual(view);
        state.focusMode = UNIVERSE_FOCUS_STATE.PLANET_FOCUS;
        // Universe 4 waits until this exact U3 inline morph is complete, then
        // hands the same planet to the canonical Universe V7 Globe.gl
        // controller. Keeping this narrow lifecycle seam here means U4 never
        // recreates or approximates the ForceGraph entry animation.
        const handoff = await helpers.onPlanetReady?.({
          nodeId,
          graph,
          detailGlobe,
          planetView: view,
          state: { ...state },
        });
        if (handoff?.claimed) {
          state.interactionLocked = true;
          controls.enabled = false;
          updateDebug();
          return;
        }
        applyPlanetFocusControls(view);
        enforcePlanetFocusLock();
        refreshUniverseV5Labels();
      }
      state.interactionLocked = false;
      controls.enabled = true;
      updateDebug();
    } catch (error) {
      state.level = UNIVERSE_LEVEL.GALAXY;
      state.transitionProgress = 0;
      state.interactionLocked = false;
      state.focusMode = UNIVERSE_FOCUS_STATE.GALAXY_OVERVIEW;
      if (isFocusV3) {
        restoreGalaxyLayout();
        restoreControls(controls, state.savedGalaxyCamera?.controls);
        applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.GALAXY_INTERACTION);
        focusProofGroup && (focusProofGroup.visible = false);
      }
      controls.enabled = true;
      nodeViews.forEach((candidate) => { candidate.proxySphere.material.opacity = 1; });
      graph.linkOpacity(.34);
      helpers.showToast?.(error.message || 'A részletes bolygó nem tölthető be.');
      updateDebug();
    }
  }

  function isFocusedPlanetInteraction() {
    return isFocusV3
      && state.level === UNIVERSE_LEVEL.PLANET
      && state.interactionOwner === UNIVERSE_INTERACTION_OWNER.PLANET_INTERACTION
      && !state.interactionLocked;
  }

  function beginPlanetPointerGesture(event) {
    const now = performance.now();
    planetPointerGesture.activePointers.set(event.pointerId, {
      x: event.clientX,
      y: event.clientY,
      startedAt: now,
      currentX: event.clientX,
      currentY: event.clientY,
    });
    if (planetPointerGesture.activePointers.size >= 2) {
      planetPointerGesture.hadMultiPointer = true;
      planetPointerGesture.mode = POINTER_GESTURE.CAMERA_PINCH;
      planetPointerGesture.pinchCount += 1;
      return;
    }
    planetPointerGesture.mode = POINTER_GESTURE.TAP_CANDIDATE;
  }

  function movePlanetPointerGesture(event) {
    const pointer = planetPointerGesture.activePointers.get(event.pointerId);
    if (!pointer) return;
    pointer.currentX = event.clientX;
    pointer.currentY = event.clientY;
    if (planetPointerGesture.activePointers.size >= 2) {
      planetPointerGesture.hadMultiPointer = true;
      planetPointerGesture.mode = POINTER_GESTURE.CAMERA_PINCH;
      return;
    }
    const moved = Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y);
    if (moved > PLANET_TAP_MOVE_THRESHOLD_PX && planetPointerGesture.mode === POINTER_GESTURE.TAP_CANDIDATE) {
      planetPointerGesture.mode = POINTER_GESTURE.CAMERA_ORBIT;
      planetPointerGesture.orbitCount += 1;
    }
  }

  function isPlanetTap(event, pointer) {
    if (!pointer || planetPointerGesture.hadMultiPointer || planetPointerGesture.mode !== POINTER_GESTURE.TAP_CANDIDATE) return false;
    return Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y) <= PLANET_TAP_MOVE_THRESHOLD_PX
      && performance.now() - pointer.startedAt <= PLANET_TAP_DURATION_THRESHOLD_MS;
  }

  function onPointerDown(event) {
    if (isFocusedPlanetInteraction()) {
      beginPlanetPointerGesture(event);
      return;
    }
    pointerStart = { x: event.clientX, y: event.clientY, startedAt: performance.now() };
  }

  function onPointerMove(event) {
    if (isFocusedPlanetInteraction()) movePlanetPointerGesture(event);
  }

  function onPointerCancel(event) {
    if (!isFocusV3) return;
    planetPointerGesture.activePointers.delete(event.pointerId);
    planetPointerGesture.mode = POINTER_GESTURE.CANCELLED;
    planetPointerGesture.hadMultiPointer = true;
    pointerStart = undefined;
  }

  function onPointerUp(event) {
    if (isFocusedPlanetInteraction()) {
      const pointer = planetPointerGesture.activePointers.get(event.pointerId);
      const validTap = isPlanetTap(event, pointer);
      planetPointerGesture.activePointers.delete(event.pointerId);
      if (planetPointerGesture.activePointers.size) return;
      if (!validTap) {
        planetPointerGesture.suppressedClicks += 1;
        resetPlanetPointerGesture();
        updateDebug();
        return;
      }
      planetPointerGesture.mode = POINTER_GESTURE.PICKING;
      const nodeId = selectedPlanetSurfaceNodeAt(event);
      if (nodeId) {
        selectUniverseV5City(nodeId);
      } else {
        const edgeId = selectedPlanetFocusEdgeAt(event);
        if (edgeId) selectUniverseV5Edge(edgeId);
      }
      resetPlanetPointerGesture();
      return;
    }
    if (!pointerStart || state.interactionLocked) return;
    const validTap = classifyPointerTap(pointerStart, { x: event.clientX, y: event.clientY, endedAt: performance.now() });
    pointerStart = undefined;
    if (!validTap) return;
    if (state.level === UNIVERSE_LEVEL.GALAXY) {
      const nodeId = selectedPlanetAt(event);
      if (nodeId) requestPlanetEntry(nodeId);
      return;
    }
    if (state.level === UNIVERSE_LEVEL.PLANET) {
      const corridorNodeId = isFocusV3 ? null : selectedCorridorAt(event);
      if (corridorNodeId) {
        void requestPlanetCorridor(corridorNodeId);
        return;
      }
      const nodeId = selectedPlanetSurfaceNodeAt(event);
      if (nodeId) requestMapEntry(nodeId);
    }
  }

  function isFrontFacingPlanetNode(view) {
    if (!isFocusV3 || !graph || !view?.v5) return true;
    const activePlanet = planetViews.get(state.selectedGalaxyNodeId);
    if (!activePlanet) return false;
    const center = activePlanet.root.getWorldPosition(new THREE.Vector3());
    const world = view.root.getWorldPosition(new THREE.Vector3());
    const cameraDirection = graph.camera().position.clone().sub(center).normalize();
    return world.sub(center).normalize().dot(cameraDirection) > .015;
  }

  function worldUnitsForPlanetHitPixels(distance, pixels) {
    const camera = graph?.camera?.();
    const viewportHeight = Math.max(1, galaxyMount.clientHeight);
    if (!camera?.isPerspectiveCamera) return Math.max(.001, distance * .025);
    const worldHeight = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) * .5) * Math.max(distance, .001);
    return Math.max(.001, (worldHeight / viewportHeight) * pixels);
  }

  function selectedPlanetSurfaceNodeAt(event) {
    if (!graph || !planetNodeViews.size) return null;
    const rect = galaxyMount.getBoundingClientRect();
    if (!rect.width || !rect.height) return null;
    graph.scene().updateMatrixWorld(true);
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(pointer, graph.camera());
    if (isFocusV3) {
      let bestHit = null;
      planetNodeViews.forEach((view) => {
        if (!view.v5 || !isFrontFacingPlanetNode(view)) return;
        const nodeWorld = view.root.getWorldPosition(new THREE.Vector3());
        const alongRay = nodeWorld.clone().sub(raycaster.ray.origin).dot(raycaster.ray.direction);
        if (alongRay <= 0) return;
        const hitRadius = Math.max(view.baseScale * 1.22, worldUnitsForPlanetHitPixels(alongRay, 12));
        const distanceSq = raycaster.ray.distanceSqToPoint(nodeWorld);
        if (distanceSq > hitRadius * hitRadius) return;
        if (!bestHit || alongRay < bestHit.alongRay) bestHit = { id: view.id, alongRay };
      });
      return bestHit?.id || null;
    }
    const hits = raycaster.intersectObjects([...planetNodeViews.values()].map((view) => view.hitSphere), false);
    for (const hit of hits) {
      let object = hit.object;
      while (object && !object.userData?.planetNodeId) object = object.parent;
      const nodeId = object?.userData?.planetNodeId;
      const view = nodeId ? planetNodeViews.get(nodeId) : null;
      if (view && isFrontFacingPlanetNode(view)) return nodeId;
    }
    return null;
  }

  function pointToScreenSegmentDistance(point, start, end) {
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const denominator = dx * dx + dy * dy;
    if (denominator < 1e-8) return Math.hypot(point.x - start.x, point.y - start.y);
    const t = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / denominator));
    return Math.hypot(point.x - (start.x + dx * t), point.y - (start.y + dy * t));
  }

  function selectedPlanetFocusEdgeAt(event) {
    if (!isFocusV3 || !state.selectedPlanetNodeId || !universeV5Planet || !graph) return null;
    const selectedPlanet = planetViews.get(state.selectedGalaxyNodeId);
    const rect = galaxyMount.getBoundingClientRect();
    if (!selectedPlanet || !rect.width || !rect.height) return null;
    const center = selectedPlanet.root.getWorldPosition(new THREE.Vector3());
    const camera = graph.camera();
    const tap = { x: event.clientX - rect.left, y: event.clientY - rect.top };
    let closest = null;

    universeV5Planet.physicsEdges
      .filter((edge) => edge.source === state.selectedPlanetNodeId || edge.target === state.selectedPlanetNodeId)
      .forEach((edge) => {
        const source = planetNodeViews.get(edge.source);
        const target = planetNodeViews.get(edge.target);
        if (!source?.v5 || !target?.v5) return;
        const sourceLocal = source.root.getWorldPosition(new THREE.Vector3()).sub(center);
        const targetLocal = target.root.getWorldPosition(new THREE.Vector3()).sub(center);
        const radius = (sourceLocal.length() + targetLocal.length()) * .5 / 1.022;
        const points = surfaceArcPoints(sourceLocal, targetLocal, radius, 16, .026)
          .map((point) => center.clone().add(new THREE.Vector3(point.x, point.y, point.z)));
        for (let index = 1; index < points.length; index += 1) {
          const start = projectPointToScreen(points[index - 1], camera, rect.width, rect.height);
          const end = projectPointToScreen(points[index], camera, rect.width, rect.height);
          if (start.ndcZ < -1 || start.ndcZ > 1 || end.ndcZ < -1 || end.ndcZ > 1) continue;
          const distance = pointToScreenSegmentDistance(tap, start, end);
          if (distance > 16 || (closest && distance >= closest.distance)) continue;
          closest = { id: `universe-v5-focus-${edge.source}-${edge.target}`, distance };
        }
      });
    return closest?.id || null;
  }

  async function requestMapEntry(nodeId) {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.PLANET || !planetNodeViews.has(nodeId)) return;
    const selectedView = planetNodeViews.get(nodeId);
    const camera = graph.camera();
    const controls = graph.controls();
    const selectedPlanetView = planetViews.get(state.selectedGalaxyNodeId);
    hideCorridorLayer();
    state.level = UNIVERSE_LEVEL.PLANET_TO_MAP;
    state.interactionLocked = true;
    state.selectedPlanetNodeId = nodeId;
    refreshUniverseV5Labels();
    refreshUniverseV5CityContext();
    state.savedPlanetCamera = { position: camera.position.clone(), target: controls.target.clone(), globeQuaternion: detailGlobe.quaternion.clone() };
    planetNodeViews.forEach((view, id) => {
      if (isBrandV2) {
        view.visibleSphere.material.color.copy(id === nodeId ? new THREE.Color(DJINN_V2.focus) : view.baseColor);
        view.glow.material.color.copy(id === nodeId ? new THREE.Color(DJINN_V2.focusGlow) : view.baseGlowColor);
      }
      view.visibleSphere.material.opacity = id === nodeId ? 1 : .28 * view.baseOpacity;
      view.glow.material.opacity = id === nodeId ? .48 : .04 * view.baseOpacity;
    });
    planetLinkViews.forEach((edge) => {
      edge.material.opacity = edge.source === nodeId || edge.target === nodeId ? .8 : .06;
      if (isBrandV2) edge.material.color.set(edge.source === nodeId || edge.target === nodeId ? DJINN_V2.focus : DJINN_V2.structure);
    });
    updateDebug();
    controls.enabled = false;
    graph.scene().updateMatrixWorld(true);
    const planetCenter = selectedPlanetView.root.getWorldPosition(new THREE.Vector3());
    const cameraDirection = camera.position.clone().sub(planetCenter).normalize();
    const startQuaternion = detailGlobe.quaternion.clone();
    const targetQuaternion = new THREE.Quaternion().setFromUnitVectors(selectedView.normal, cameraDirection);
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const selectedWorldPosition = selectedView.root.getWorldPosition(new THREE.Vector3());
    const cameraTarget = focusCameraTarget(selectedWorldPosition, camera.position, controls.target, selectedPlanetView.radius * 2.35);
    const cameraEnd = new THREE.Vector3(cameraTarget.x, cameraTarget.y, cameraTarget.z);
    const focused = await tween(420, (eased, raw) => {
      state.transitionProgress = raw * .42;
      detailGlobe.quaternion.slerpQuaternions(startQuaternion, targetQuaternion, eased);
      camera.position.lerpVectors(cameraStart, cameraEnd, eased);
      controls.target.lerpVectors(targetStart, selectedWorldPosition, eased);
      controls.update();
      updateDebug();
    });
    if (!focused || destroyed) return;

    graph.scene().updateMatrixWorld(true);
    const screen = projectPointToScreen(selectedView.root.getWorldPosition(new THREE.Vector3()), camera, stage.clientWidth, stage.clientHeight);
    const startDiameter = 52;
    proxy.hidden = false;
    setProxyFrame({
      x: screen.x,
      y: screen.y,
      width: startDiameter,
      height: startDiameter,
      radius: '50%',
      opacity: 0,
      background: 'radial-gradient(circle at 32% 28%, #fff4a8, #e2b93a 68%, #a66e12)',
    });

    try {
      await ensureMapGraph(nodeId);
      const mapTarget = { x: stage.clientWidth / 2, y: stage.clientHeight / 2 };
      const morphed = await tween(560, (eased, raw) => {
        state.transitionProgress = .42 + raw * .58;
        selectedView.visibleSphere.material.opacity = 1 - Math.min(1, eased * 1.35);
        selectedView.glow.material.opacity = .48 * (1 - eased);
        const width = startDiameter + (148 - startDiameter) * eased;
        const height = startDiameter + (56 - startDiameter) * eased;
        const x = screen.x + (mapTarget.x - screen.x) * eased;
        const y = screen.y + (mapTarget.y - screen.y) * eased;
        setProxyFrame({
          x,
          y,
          width,
          height,
          radius: `${Math.round(startDiameter / 2 * (1 - eased) + 16 * eased)}px`,
          opacity: Math.min(1, eased * 3) * (1 - Math.max(0, (eased - .88) / .12)),
          background: eased < .52
            ? 'radial-gradient(circle at 32% 28%, #fff4a8, #e2b93a 68%, #a66e12)'
            : 'linear-gradient(135deg, #8b65fa, #5b31cc)',
        });
        mapMount.style.opacity = String(Math.max(0, (eased - .28) / .72));
        galaxyMount.style.opacity = String(1 - Math.max(0, (eased - .18) / .82));
        updateDebug();
      });
      if (!morphed || destroyed) return;
      proxy.hidden = true;
      proxy.style.opacity = '0';
      galaxyMount.style.opacity = '0';
      galaxyMount.style.pointerEvents = 'none';
      mapMount.style.opacity = '1';
      mapMount.classList.add('is-map-active');
      state.level = UNIVERSE_LEVEL.MAP;
      state.transitionProgress = 1;
      state.interactionLocked = false;
      updateDebug();
    } catch (error) {
      proxy.hidden = true;
      mapMount.hidden = true;
      mapMount.style.opacity = '0';
      galaxyMount.style.opacity = '1';
      controls.enabled = true;
      state.level = UNIVERSE_LEVEL.PLANET;
      state.transitionProgress = 1;
      state.interactionLocked = false;
      refreshUniverseV5CityContext();
      helpers.showToast?.(error.message || 'A térképnavigáció nem tölthető be.');
      updateDebug();
    }
  }

  async function requestPlanetReturn() {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.MAP || !state.selectedPlanetNodeId || !state.savedPlanetCamera) return;
    const selectedView = planetNodeViews.get(state.selectedPlanetNodeId);
    if (!selectedView) return;
    const camera = graph.camera();
    const controls = graph.controls();
    state.level = UNIVERSE_LEVEL.MAP_TO_PLANET;
    state.interactionLocked = true;
    mapMount.classList.remove('is-map-active');
    const mapStartScreen = { x: stage.clientWidth / 2, y: stage.clientHeight / 2 };
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const globeStart = detailGlobe.quaternion.clone();
    const saved = state.savedPlanetCamera;
    proxy.hidden = false;
    setProxyFrame({
      x: mapStartScreen.x,
      y: mapStartScreen.y,
      width: 148,
      height: 56,
      radius: '16px',
      opacity: 1,
      background: 'linear-gradient(135deg, #8b65fa, #5b31cc)',
    });
    galaxyMount.style.pointerEvents = '';
    const returned = await tween(560, (eased, raw) => {
      state.transitionProgress = 1 - raw;
      camera.position.lerpVectors(cameraStart, saved.position, eased);
      controls.target.lerpVectors(targetStart, saved.target, eased);
      detailGlobe.quaternion.slerpQuaternions(globeStart, saved.globeQuaternion, eased);
      controls.update();
      graph.scene().updateMatrixWorld(true);
      const endScreen = projectPointToScreen(selectedView.root.getWorldPosition(new THREE.Vector3()), camera, stage.clientWidth, stage.clientHeight);
      setProxyFrame({
        x: mapStartScreen.x + (endScreen.x - mapStartScreen.x) * eased,
        y: mapStartScreen.y + (endScreen.y - mapStartScreen.y) * eased,
        width: 148 + (52 - 148) * eased,
        height: 56 + (52 - 56) * eased,
        radius: `${Math.round(16 * (1 - eased) + 26 * eased)}px`,
        opacity: 1 - Math.max(0, (eased - .86) / .14),
        background: eased < .52
          ? 'linear-gradient(135deg, #8b65fa, #5b31cc)'
          : 'radial-gradient(circle at 32% 28%, #fff4a8, #e2b93a 68%, #a66e12)',
      });
      mapMount.style.opacity = String(1 - eased);
      galaxyMount.style.opacity = String(eased);
      selectedView.visibleSphere.material.opacity = eased;
      selectedView.glow.material.opacity = eased * .45;
      updateDebug();
    });
    if (!returned || destroyed) return;
    proxy.hidden = true;
    mapMount.hidden = true;
    mapMount.style.opacity = '0';
    galaxyMount.style.opacity = '1';
    galaxyMount.style.pointerEvents = '';
    setPlanetContentOpacity(1);
    planetNodeViews.forEach((view) => {
      if (!isBrandV2) return;
      view.visibleSphere.material.color.copy(view.baseColor);
      view.glow.material.color.copy(view.baseGlowColor);
    });
    planetLinkViews.forEach((edge) => {
      if (isBrandV2) edge.material.color.set(DJINN_V2.structure);
    });
    const neighborPlanetId = !isFocusV3 && mock.galaxy.planetIds.find((id) => id !== state.selectedGalaxyNodeId);
    const restoredPlanetView = planetViews.get(state.selectedGalaxyNodeId);
    if (neighborPlanetId && restoredPlanetView) {
      positionCorridorLayer(restoredPlanetView, neighborPlanetId);
      corridorStrand.material.opacity = .66;
      corridorStrandHit.visible = true;
    }
    state.level = UNIVERSE_LEVEL.PLANET;
    state.transitionProgress = 1;
    state.interactionLocked = false;
    controls.enabled = true;
    if (isFocusV3 && restoredPlanetView) {
      state.focusMode = UNIVERSE_FOCUS_STATE.PLANET_FOCUS;
      applyPlanetFocusControls(restoredPlanetView);
      enforcePlanetFocusLock();
      refreshUniverseV5Labels();
    }
    refreshUniverseV5CityContext();
    updateDebug();
  }

  async function requestGalaxyReturn() {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.PLANET || !state.selectedGalaxyNodeId || !state.savedGalaxyCamera) return;
    const activeView = planetViews.get(state.selectedGalaxyNodeId);
    if (!activeView) return;
    const camera = graph.camera();
    const controls = graph.controls();
    hideCorridorLayer();
    if (isFocusV3) {
      state.selectedPlanetNodeId = null;
      state.selectedPlanetEdgeId = null;
      updateUniverseV5FocusArcs(null);
      refreshUniverseV5CityContext();
    }
    state.level = UNIVERSE_LEVEL.PLANET_TO_GALAXY;
    state.interactionLocked = true;
    if (isFocusV3) {
      state.focusMode = UNIVERSE_FOCUS_STATE.PLANET_FOCUS_EXIT;
      applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.PLANET_TRANSITION);
      focusProofGroup && (focusProofGroup.visible = false);
    }
    controls.enabled = false;
    const cameraStart = camera.position.clone();
    const targetStart = controls.target.clone();
    const globeScale = activeView.radius / (detailGlobe.getGlobeRadius?.() || 100);
    if (isFocusV3) prepareFocusedOverviewReturn(activeView);
    const returned = await tween(520, (eased, raw) => {
      state.transitionProgress = 1 - raw;
      camera.position.lerpVectors(cameraStart, state.savedGalaxyCamera.position, eased);
      controls.target.lerpVectors(targetStart, state.savedGalaxyCamera.target, eased);
      detailGlobe.scale.setScalar(globeScale * (1 - eased * .08));
      setObjectOpacity(detailGlobe, 1 - eased);
      setPlanetContentOpacity(1 - eased);
      activeView.proxySphere.material.opacity = eased;
      if (isFocusV3) {
        setV3BackgroundFocus(state.selectedGalaxyNodeId, 1 - eased);
        activeView.proxySphere.visible = eased > .01;
        activeView.proxySphere.material.opacity = eased;
        activeView.proxySphere.material.depthWrite = eased > .04;
        activeView.glow.visible = eased > .01;
        activeView.glow.material.opacity = eased * .44;
      } else {
        nodeViews.forEach((view, id) => {
          if (id !== state.selectedGalaxyNodeId) view.proxySphere.material.opacity = .1 + eased * .9;
          view.ring.visible = false;
          view.glow.material.opacity = view.root.userData.isPlanet ? (.08 + eased * .08) : .045;
        });
        graph.linkOpacity(.03 + eased * .31);
      }
      controls.update();
      if (isFocusV3) syncDetailGlobeView();
      updateDebug();
    });
    if (!returned || destroyed) return;
    detailGlobe.visible = false;
    detailGlobe.removeFromParent?.();
    setPlanetContentOpacity(0);
    state.level = UNIVERSE_LEVEL.GALAXY;
    state.selectedPlanetNodeId = null;
    state.transitionProgress = 0;
    state.interactionLocked = false;
    if (isFocusV3) {
      restoreGalaxyLayout();
      restoreControls(controls, state.savedGalaxyCamera.controls);
      camera.near = state.savedGalaxyCamera.near;
      camera.far = state.savedGalaxyCamera.far;
      camera.quaternion.copy(state.savedGalaxyCamera.quaternion);
      camera.updateProjectionMatrix();
      state.focusMode = UNIVERSE_FOCUS_STATE.GALAXY_OVERVIEW;
      state.focusLimits = null;
      activeView.proxySphere.visible = true;
      activeView.proxySphere.material.opacity = 1;
      activeView.proxySphere.material.depthWrite = true;
      activeView.glow.visible = true;
      activeView.glow.material.opacity = .16;
      focusProofGroup && (focusProofGroup.visible = false);
      refreshUniverseV5Labels();
      applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.GALAXY_INTERACTION);
    } else {
      controls.enabled = true;
    }
    updateDebug();
  }

  function setUniverseBackgroundColor(nextColor) {
    if (destroyed || typeof nextColor !== 'string' || !/^#[0-9a-f]{6}$/i.test(nextColor)) return false;
    universeRendererBackgroundColor = nextColor.toUpperCase();
    galaxyMount.style.backgroundColor = universeRendererBackgroundColor;
    graph?.backgroundColor?.(universeRendererBackgroundColor);
    return true;
  }

  async function resetToGalaxyOverview() {
    if (destroyed || !graph) return false;
    // Universe 4 Reset intentionally discards the standalone Globe orbit.
    // It reuses U3's native return route, so the final ForceGraph state is
    // the same baseline reached by the regular U3 Galaxy action.
    state.interactionLocked = false;
    if (state.level === UNIVERSE_LEVEL.CORRIDOR) await closeCorridor();
    if (state.level === UNIVERSE_LEVEL.MAP) await requestPlanetReturn();
    if (state.level === UNIVERSE_LEVEL.PLANET) await requestGalaxyReturn();
    return state.level === UNIVERSE_LEVEL.GALAXY;
  }

  async function reverse() {
    if (state.level === UNIVERSE_LEVEL.CORRIDOR) {
      await closeCorridor();
      return;
    }
    const target = reverseTransition(state.level);
    if (target === UNIVERSE_LEVEL.MAP_TO_PLANET) await requestPlanetReturn();
    if (target === UNIVERSE_LEVEL.PLANET_TO_GALAXY) await requestGalaxyReturn();
  }

  async function handleDebugAction(action) {
    if (state.interactionLocked) return;
    const defaultPlanetId = mock.galaxy.planetIds[0];
    const defaultPlanetNodeId = mock.planet.nodes[0].id;
    if (action === 'corridor') {
      if (state.level === UNIVERSE_LEVEL.GALAXY) await requestPlanetEntry(defaultPlanetId);
      if (state.level === UNIVERSE_LEVEL.PLANET) await requestPlanetCorridor();
      return;
    }
    if (action === 'reverse') {
      if (state.level === UNIVERSE_LEVEL.CORRIDOR) {
        await closeCorridor();
        return;
      }
      await reverse();
      return;
    }
    if (action === 'galaxy') {
      if (state.level === UNIVERSE_LEVEL.CORRIDOR) {
        await closeCorridor();
        return;
      }
      if (state.level === UNIVERSE_LEVEL.MAP) await requestPlanetReturn();
      if (state.level === UNIVERSE_LEVEL.PLANET) await requestGalaxyReturn();
      return;
    }
    if (action === 'planet') {
      if (state.level === UNIVERSE_LEVEL.CORRIDOR) await closeCorridor();
      if (state.level === UNIVERSE_LEVEL.MAP) await requestPlanetReturn();
      if (state.level === UNIVERSE_LEVEL.GALAXY) await requestPlanetEntry(defaultPlanetId);
      return;
    }
    if (action === 'map') {
      if (state.level === UNIVERSE_LEVEL.CORRIDOR) await closeCorridor();
      if (state.level === UNIVERSE_LEVEL.GALAXY) await requestPlanetEntry(defaultPlanetId);
      if (state.level === UNIVERSE_LEVEL.PLANET) {
        const targetCity = isFocusV3 ? state.selectedPlanetNodeId : defaultPlanetNodeId;
        if (targetCity) await requestMapEntry(targetCity);
        else helpers.showToast?.('Előbb jelölj ki egy várost.');
      }
      return;
    }
    if (action === 'replay') {
      if (state.level === UNIVERSE_LEVEL.CORRIDOR) await closeCorridor();
      if (state.level === UNIVERSE_LEVEL.MAP) await requestPlanetReturn();
      if (state.level === UNIVERSE_LEVEL.PLANET) await requestGalaxyReturn();
      if (state.level === UNIVERSE_LEVEL.GALAXY) await requestPlanetEntry(defaultPlanetId);
      if (state.level === UNIVERSE_LEVEL.PLANET) await requestMapEntry(defaultPlanetNodeId);
    }
  }

  function onDebugClick(event) {
    const toggle = event.target.closest('[data-universe-v3-toggle]');
    if (isFocusV3 && toggle) {
      const key = toggle.dataset.universeV3Toggle;
      const propertyByKey = {
        'target-lock': 'targetLock',
        'force-freeze': 'forceFreeze',
        'background-planets': 'backgroundPlanets',
        'galaxy-links': 'galaxyLinks',
        'target-proof': 'targetProof',
        'orbit-proof': 'orbitProof',
      };
      const property = propertyByKey[key];
      if (!property) return;
      v3Debug[property] = toggle.checked;
      const activeView = planetViews.get(state.selectedGalaxyNodeId);
      if (key === 'force-freeze') {
        if (toggle.checked && state.level === UNIVERSE_LEVEL.PLANET) freezeGalaxyLayout();
        if (!toggle.checked) restoreGalaxyLayout();
      }
      if (activeView && state.level === UNIVERSE_LEVEL.PLANET) {
        setV3BackgroundFocus(state.selectedGalaxyNodeId, 1);
        if (v3Debug.targetLock) enforcePlanetFocusLock();
      }
      refreshFocusProof();
      lastHudUpdate = 0;
      updateDebug();
      return;
    }
    const action = event.target.closest('[data-universe-action]')?.dataset.universeAction;
    if (action) void handleDebugAction(action);
  }

  function onCityContextClick(event) {
    const action = event.target.closest('[data-universe-city-action]')?.dataset.universeCityAction;
    if (!action) return;
    if (action === 'clear') {
      selectUniverseV5City(state.selectedPlanetNodeId);
      return;
    }
    if (action === 'street-map' && state.selectedPlanetNodeId) {
      void requestMapEntry(state.selectedPlanetNodeId);
    }
  }

  function startGraph() {
    if (destroyed) return;
    // Warm the inline detail renderer while the user still explores the
    // galaxy. The tap can then begin camera travel and planet morph together.
    if (isFocusV3) void loadThreeGlobe().catch(() => {});
    graph = new window.ForceGraph3D(galaxyMount, { controlType: 'orbit' })
      .graphData(mock.galaxy)
      .backgroundColor(universeRendererBackgroundColor)
      .nodeThreeObject(createGalaxyNodeRoot)
      // Keep ForceGraph's default sphere out of the scene. Every visible
      // node body belongs to the stable root returned above.
      .nodeThreeObjectExtend(false)
      .nodeLabel(() => '')
      .linkColor(() => isBrandV2 ? 'rgba(161,139,247,.34)' : 'rgba(201,196,255,.28)')
      .linkOpacity(.34)
      // V3 keeps the surrounding galaxy readable without competing with the
      // focused V5 planet and its local neon structure.
      .linkWidth(isFocusV3 ? .14 : .42)
      .cooldownTicks(90)
      .cooldownTime(900);

    const scene = graph.scene();
    if (isFocusV3) {
      stripForceGraphDefaultLights(scene);
      // A broad directional key comes from the same stable virtual direction.
      // The soft ambient + hemisphere pair prevents the planet
      // from becoming a hard two-tone, flashlight-lit sphere.
      const ambient = new THREE.AmbientLight(UNIVERSE_V3_REFERENCE_LIGHTING.ambientColor, UNIVERSE_V3_REFERENCE_LIGHTING.ambientIntensity);
      const fill = new THREE.HemisphereLight(
        UNIVERSE_V3_REFERENCE_LIGHTING.fillColor,
        UNIVERSE_V3_REFERENCE_LIGHTING.fillGroundColor,
        UNIVERSE_V3_REFERENCE_LIGHTING.fillIntensity,
      );
      universeCosmicLightTarget = new THREE.Object3D();
      universeCosmicLightTarget.name = 'universe-v3-cosmic-light-target';
      universeCosmicKeyLight = new THREE.DirectionalLight(UNIVERSE_V3_REFERENCE_LIGHTING.keyColor, UNIVERSE_V3_REFERENCE_LIGHTING.keyIntensity);
      universeCosmicKeyLight.name = 'universe-v3-cosmic-key-light';
      universeCosmicKeyLight.target = universeCosmicLightTarget;
      scene.add(ambient, fill, universeCosmicLightTarget, universeCosmicKeyLight);
      sceneLights = [ambient, fill, universeCosmicLightTarget, universeCosmicKeyLight];
      resumeUniverseCosmicEnvironment({ reseedSun: true });
    } else {
      const ambient = new THREE.AmbientLight(isBrandV2 ? 0x1f6f96 : 0x6d4ca4, isBrandV2 ? 1.05 : .9);
      const key = new THREE.PointLight(isBrandV2 ? 0x8fefff : 0xe9e0ff, isBrandV2 ? 1.9 : 1.7, 420);
      key.position.set(55, 72, 120);
      scene.add(ambient, key);
      sceneLights = [ambient, key];
    }
    if (isFocusV3) {
      ensureFocusInfrastructure();
      controlsChangeListener = scheduleV3ControlRefresh;
      graph.controls().addEventListener('change', controlsChangeListener);
      applyUniverseInteractionPolicy(UNIVERSE_INTERACTION_OWNER.GALAXY_INTERACTION);
    }
    resize();
    resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(galaxyMount);
    galaxyMount.addEventListener('pointerdown', onPointerDown);
    galaxyMount.addEventListener('pointermove', onPointerMove);
    galaxyMount.addEventListener('pointerup', onPointerUp);
    galaxyMount.addEventListener('pointercancel', onPointerCancel);
    debug?.addEventListener('click', onDebugClick);
    corridor?.addEventListener('click', onCorridorClick);
    cityContext?.addEventListener('click', onCityContextClick);
    startHudLoop();
    updateDebug();
  }

  removeWaiter = waitForForceGraph(startGraph, () => {
    galaxyMount.innerHTML = '<p class="empty">A 3D Force Graph motor nem tölthető be.</p>';
    helpers.showToast?.('A 3D Force Graph motor nem tölthető be.');
  });
  fullscreenButton?.addEventListener('click', toggleUniverseFullscreen);
  document.addEventListener('fullscreenchange', onUniverseFullscreenChange);
  syncUniverseFullscreenState();

  function resumeAfterExternalHandoff() {
    if (destroyed || !isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || !graph) return false;
    const view = planetViews.get(state.selectedGalaxyNodeId);
    if (!view || !detailGlobe?.parent) return false;
    state.interactionLocked = false;
    state.focusMode = UNIVERSE_FOCUS_STATE.PLANET_FOCUS;
    applyPlanetFocusControls(view);
    enforcePlanetFocusLock();
    refreshUniverseV5Labels();
    refreshUniverseV5CityContext();
    updateDebug();
    return true;
  }

  function captureFocusedPlanetRenderProfile() {
    if (destroyed || !isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || !graph || !detailGlobe) return null;
    const view = planetViews.get(state.selectedGalaxyNodeId);
    if (!view || detailGlobe.parent !== view.detailMount) return null;
    const scene = graph.scene();
    scene?.updateMatrixWorld?.(true);
    const material = detailGlobe.globeMaterial?.();
    return Object.freeze({
      material: captureMaterialRenderProfile(material),
      renderer: captureRendererRenderProfile(graph.renderer?.(), material),
      // `configuredLights` is the expected contract; `sceneLights` proves
      // whether ForceGraph leaves any additive vendor lights behind.
      configuredLights: Object.freeze(sceneLights
        .filter((light) => light?.isLight)
        .map((light) => ({
          name: light.name || null,
          type: light.type || light.constructor?.name || null,
          visible: light.visible !== false,
          color: colorHex(light.color),
          groundColor: colorHex(light.groundColor),
          intensity: numberOrNull(light.intensity),
        }))
        .sort((left, right) => `${left.type}:${left.name}`.localeCompare(`${right.type}:${right.name}`))),
      sceneLights: captureSceneLightProfile(scene),
    });
  }

  // A renderer handoff must use the *drawn* V3 planet rather than the raw
  // ForceGraph node coordinates.  This generic capture seam is also useful to
  // diagnostics: it records the actual detail globe transform, camera and a
  // stable subset of visible city landmarks in CSS pixels.
  function captureFocusedPlanetHandoffFrame({ landmarkIds = null } = {}) {
    if (destroyed || !isFocusV3 || state.level !== UNIVERSE_LEVEL.PLANET || !graph || !detailGlobe) return null;
    const view = planetViews.get(state.selectedGalaxyNodeId);
    if (!view || detailGlobe.parent !== view.detailMount) return null;

    const camera = graph.camera();
    const controls = graph.controls();
    const viewport = { width: stage.clientWidth, height: stage.clientHeight };
    if (viewport.width <= 0 || viewport.height <= 0) return null;
    graph.scene().updateMatrixWorld(true);
    camera.updateMatrixWorld(true);
    detailGlobe.updateMatrixWorld(true);

    const center = detailGlobe.getWorldPosition(new THREE.Vector3());
    const quaternion = detailGlobe.getWorldQuaternion(new THREE.Quaternion());
    const worldScale = Math.max(.001, detailGlobe.getWorldScale(new THREE.Vector3()).x || 1);
    const visualRadius = Math.max(.001, (detailGlobe.getGlobeRadius?.() || 100) * worldScale);
    const project = (worldPosition) => projectPointToScreen(worldPosition, camera, viewport.width, viewport.height);
    const screenCenter = project(center);
    const cameraDirection = camera.position.clone().sub(center).normalize();
    const horizontal = new THREE.Vector3().crossVectors(camera.up, cameraDirection).normalize();
    const vertical = new THREE.Vector3().crossVectors(cameraDirection, horizontal).normalize();
    const radius = Math.max(
      ...[horizontal, horizontal.clone().negate(), vertical, vertical.clone().negate()]
        .map((axis) => {
          const edge = project(center.clone().addScaledVector(axis, visualRadius));
          return Math.hypot(edge.x - screenCenter.x, edge.y - screenCenter.y);
        }),
    );

    const requestedIds = Array.isArray(landmarkIds) && landmarkIds.length
      ? new Set(landmarkIds)
      : null;
    const landmarks = [...planetNodeViews.values()]
      .filter((entry) => !requestedIds || requestedIds.has(entry.id))
      .map((entry) => {
        const world = entry.root.getWorldPosition(new THREE.Vector3());
        const point = project(world);
        const normal = world.clone().sub(center).normalize();
        return {
          id: entry.id,
          lat: entry.atom.lat,
          lng: entry.atom.lng,
          altitude: entry.atom.altitude,
          x: point.x,
          y: point.y,
          visible: point.ndcZ >= -1 && point.ndcZ <= 1
            && point.x >= 0 && point.x <= viewport.width
            && point.y >= 0 && point.y <= viewport.height
            && normal.dot(cameraDirection) > -.04,
          facing: normal.dot(cameraDirection),
        };
      })
      .filter((entry) => entry.visible)
      .sort((left, right) => right.facing - left.facing || left.id.localeCompare(right.id))
      .slice(0, requestedIds ? landmarkIds.length : 5)
      .map(({ visible, facing, ...entry }) => entry);
    const ambient = sceneLights.find((light) => light?.isAmbientLight);
    const fill = sceneLights.find((light) => light?.isHemisphereLight);
    const globeMaterial = detailGlobe.globeMaterial?.();
    const lightSnapshot = Object.freeze({
      // This is the actual world-fixed U3 light vector at the Force last
      // frame. V7 adopts it while invisible; it must not seed a second,
      // unrelated light direction from its own default camera.
      worldSunDirection: Object.freeze({
        x: universeCosmicSunDirection.x,
        y: universeCosmicSunDirection.y,
        z: universeCosmicSunDirection.z,
      }),
      keyColor: colorHex(universeCosmicKeyLight?.color),
      keyIntensity: universeCosmicKeyLight?.intensity ?? null,
      fillColor: colorHex(fill?.color),
      fillGroundColor: colorHex(fill?.groundColor),
      fillIntensity: fill?.intensity ?? null,
      ambientColor: colorHex(ambient?.color),
      ambientIntensity: ambient?.intensity ?? null,
      material: Object.freeze({
        color: colorHex(globeMaterial?.color),
        emissive: colorHex(globeMaterial?.emissive),
        emissiveIntensity: globeMaterial?.emissiveIntensity ?? null,
      }),
    });

    return {
      viewport,
      cameraPosition: camera.getWorldPosition(new THREE.Vector3()).toArray().reduce((record, value, index) => {
        record[['x', 'y', 'z'][index]] = value;
        return record;
      }, {}),
      cameraQuaternion: camera.getWorldQuaternion(new THREE.Quaternion()).toArray().reduce((record, value, index) => {
        record[['x', 'y', 'z', 'w'][index]] = value;
        return record;
      }, {}),
      cameraUp: { x: camera.up.x, y: camera.up.y, z: camera.up.z },
      fov: camera.fov,
      aspect: camera.aspect,
      near: camera.near,
      far: camera.far,
      controlsTarget: { x: controls.target.x, y: controls.target.y, z: controls.target.z },
      planetWorldCenter: { x: center.x, y: center.y, z: center.z },
      planetWorldQuaternion: { x: quaternion.x, y: quaternion.y, z: quaternion.z, w: quaternion.w },
      planetVisualRadius: visualRadius,
      center: { x: screenCenter.x, y: screenCenter.y },
      radius,
      landmarks,
      lightSnapshot,
      renderProfile: captureFocusedPlanetRenderProfile(),
    };
  }

  // This is deliberately camera-only. It contains no U4 state, so the U3
  // reference keeps its own lifecycle while a caller may restore any captured
  // planet-local pose (for example after a standalone renderer handoff).
  function applyFocusedPlanetHandoffCamera(snapshot) {
    if (destroyed || !isFocusV3 || !graph || !snapshot?.cameraPosition) return false;
    const view = planetViews.get(state.selectedGalaxyNodeId);
    if (!view || !detailGlobe?.parent) return false;
    const camera = graph.camera();
    const controls = graph.controls();
    camera.position.set(snapshot.cameraPosition.x, snapshot.cameraPosition.y, snapshot.cameraPosition.z);
    if (snapshot.cameraUp) camera.up.set(snapshot.cameraUp.x, snapshot.cameraUp.y, snapshot.cameraUp.z);
    if (Number.isFinite(snapshot.fov)) camera.fov = snapshot.fov;
    if (Number.isFinite(snapshot.aspect)) camera.aspect = snapshot.aspect;
    if (Number.isFinite(snapshot.near)) camera.near = snapshot.near;
    if (Number.isFinite(snapshot.far)) camera.far = snapshot.far;
    const target = snapshot.controlsTarget || getPlanetWorldPosition(view);
    controls.target.set(target.x, target.y, target.z);
    camera.lookAt(controls.target);
    camera.updateProjectionMatrix();
    controls.update();
    syncDetailGlobeView();
    refreshUniverseV5Labels();
    return true;
  }

  const dispose = () => {
    destroyed = true;
    removeWaiter();
    window.cancelAnimationFrame(transitionFrame);
    window.cancelAnimationFrame(hudFrame);
    window.cancelAnimationFrame(v3ControlRefreshFrame);
    window.cancelAnimationFrame(v3VisualRefreshFrame);
    resizeObserver?.disconnect();
    mapResizeObserver?.disconnect();
    galaxyMount.removeEventListener('pointerdown', onPointerDown);
    galaxyMount.removeEventListener('pointermove', onPointerMove);
    galaxyMount.removeEventListener('pointerup', onPointerUp);
    galaxyMount.removeEventListener('pointercancel', onPointerCancel);
    debug?.removeEventListener('click', onDebugClick);
    corridor?.removeEventListener('click', onCorridorClick);
    cityContext?.removeEventListener('click', onCityContextClick);
    fullscreenButton?.removeEventListener('click', toggleUniverseFullscreen);
    document.removeEventListener('fullscreenchange', onUniverseFullscreenChange);
    if (document.fullscreenElement === stage) void document.exitFullscreen?.();
    fullscreenFallbackActive = false;
    universeV5LabelSprites.forEach((sprite) => sprite.removeFromParent());
    universeV5LabelSprites.clear();
    universeV5LabelPool.length = 0;
    universeV5LabelTextureCache.forEach(({ texture }) => texture.dispose());
    universeV5LabelTextureCache.clear();
    if (controlsChangeListener) graph?.controls?.().removeEventListener('change', controlsChangeListener);
    universeCosmicEnvironment?.dispose();
    universeCosmicEnvironment = null;
    sceneLights.forEach((light) => light.removeFromParent());
    detailGlobe?.removeFromParent?.();
    corridorLayer?.removeFromParent?.();
    planetFocusAnchor?.removeFromParent?.();
    focusProofGroup?.traverse((object) => object.geometry?.dispose?.());
    focusProofGroup?.removeFromParent?.();
    corridorStrand?.geometry?.dispose?.();
    corridorStrandHit?.geometry?.dispose?.();
    planetContentGroup?.traverse((object) => object.geometry?.dispose?.());
    nodeViews.forEach((view) => view.root.traverse((object) => object.geometry?.dispose?.()));
    ownedMaterials.forEach((material) => material.dispose());
    try { mapGraph?.destroy?.(); } catch { /* G6 cleanup must not block routing. */ }
    mapMount.replaceChildren();
    selectedRingMaterial.dispose();
    invisibleHitMaterial.dispose();
    sharedSphereGeometry.dispose();
    try { graph?._destructor?.(); } catch { /* ForceGraph cleanup must not block routing. */ }
    galaxyMount.replaceChildren();
  };

  // Universe 4 uses the production U3 controller as its ForceGraph source.
  // Expose the complete U3 runtime lifecycle, including the local HUD/cosmic
  // RAF, so the hidden stage consumes no continuous frame budget.
  dispose.pauseAnimation = pauseUniverseRenderRuntime;
  dispose.resumeAnimation = resumeUniverseRenderRuntime;
  dispose.resetToGalaxyOverview = resetToGalaxyOverview;
  dispose.setUniverseBackgroundColor = setUniverseBackgroundColor;
  dispose.resumeAfterExternalHandoff = resumeAfterExternalHandoff;
  dispose.captureFocusedPlanetHandoffFrame = captureFocusedPlanetHandoffFrame;
  dispose.captureFocusedPlanetRenderProfile = captureFocusedPlanetRenderProfile;
  dispose.applyFocusedPlanetHandoffCamera = applyFocusedPlanetHandoffCamera;
  return dispose;
}
