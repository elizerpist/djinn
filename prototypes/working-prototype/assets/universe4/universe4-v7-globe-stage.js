// Universe 4's standalone endpoint is deliberately the Explore V7 planet,
// not an approximation. This module owns a second, embedded Globe.gl
// lifecycle only; it never navigates to the Explore route.
import * as THREE from '../vendor/three.module.min.js?rev=92';
import {
  getV5PlanetVisualSnapshot,
  createV5NodePositionRegistry,
  V3_PHYSICS_EDGES,
  V5_BRIDGE_NODE_IDS,
  V5_SIZE_DEFAULTS,
} from '../explore/planet-data.js?rev=4';
import {
  DJINN_ORB_V5,
  DJINN_ORB_V7,
  v5VariantContextVisualState,
} from '../explore/planet-visuals.js?rev=1';
import { createPlanetVariantController } from '../explore/planet-variant-controller.js?rev=4';
import { createPlanetInputRouter } from '../explore/planet-input-router.js?rev=3';
import { commitPlanetSelectionArcs, clearPlanetSelectionArcs } from '../explore/planet-globe-arc-adapter.js?rev=4';
import { getPlanetLabelLod } from '../explore/planet-label-lod.js?rev=1';
import { rebindPlanetObjects } from '../explore/planet-object-rebind.js?rev=1';
import { VirtualGalaxyLightingRig, V7_PRODUCTION_CINEMATIC_BLEND } from '../virtual-galaxy-light-rig.js?rev=22';
import { COSMIC_MODES, CosmicEnvironment } from '../cosmic-environment.js?rev=6';

let globePromise;

function loadGlobe() {
  if (window.Globe) return Promise.resolve(window.Globe);
  if (globePromise) return globePromise;
  globePromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.async = true;
    script.src = new URL('../vendor/globe.gl.min.js?rev=1', import.meta.url).href;
    script.addEventListener('load', () => window.Globe
      ? resolve(window.Globe)
      : reject(new Error('Universe 4: Globe.gl global export hiányzik.')), { once: true });
    script.addEventListener('error', () => reject(new Error('Universe 4: Globe.gl vendor nem tölthető be.')), { once: true });
    document.head.append(script);
  });
  return globePromise;
}

const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));
const U4_V7_SURFACE_SELECTION_RENDERER = 'surface-selection-arc';

function screenMetrics(globe, viewport) {
  const camera = globe?.camera?.();
  if (!camera) return null;
  const center = globe.getCoords?.(0, 0, 0) || new THREE.Vector3();
  const edge = globe.getCoords?.(0, 90, 0) || new THREE.Vector3(globe.getGlobeRadius?.() || 100, 0, 0);
  const toPx = (vector) => {
    const projected = vector.clone().project(camera);
    return {
      x: (projected.x * .5 + .5) * viewport.width,
      y: (-projected.y * .5 + .5) * viewport.height,
    };
  };
  const centerPx = toPx(center);
  const edgePx = toPx(edge);
  return { center: centerPx, radius: Math.hypot(edgePx.x - centerPx.x, edgePx.y - centerPx.y) };
}

function disposeNodeObjects(nodeObjects) {
  nodeObjects.forEach((object) => {
    object.userData?.sphere?.material?.dispose?.();
    object.userData?.glow?.material?.dispose?.();
    object.userData?.hitSphere?.material?.dispose?.();
    object.userData?.bridgeRing?.material?.dispose?.();
  });
  nodeObjects.clear();
}

/**
 * A self-contained V7 Globe.gl controller for U4. Its concrete city layout,
 * context selection and light/cosmic contracts are copied from the active
 * Explore V7 implementation so the handoff target is the actual same planet.
 */
export function createUniverse4V7GlobeStage({ mount, onCitySelection, onSignal } = {}) {
  if (!mount) throw new Error('Universe 4 V7 Globe stage mount kötelező.');

  const v7Snapshot = getV5PlanetVisualSnapshot();
  const atoms = v7Snapshot.atoms;
  const nodesById = createV5NodePositionRegistry(v7Snapshot);
  const nodeObjects = new Map();
  const labelElements = new Map();
  const sphereGeometry = new THREE.SphereGeometry(1, 24, 18);
  const bridgeRingGeometry = new THREE.TorusGeometry(1, .035, 7, 24);
  const pointerRuntime = {
    gestures: new Map(),
    raycaster: new THREE.Raycaster(),
    ndc: new THREE.Vector2(),
  };

  let globe = null;
  let ready = false;
  let disposed = false;
  let inputEnabled = false;
  let focusedNode = null;
  let renderedFrames = 0;
  let frameCounter = 0;
  let labelFrame = 0;
  let controlsListener = null;
  let sceneBeforeRender = null;
  let sceneBeforeRenderHook = null;
  let v7LightRig = null;
  let cosmicEnvironment = null;
  let labelLayer = null;
  let activeCosmicMode = 'cosmic-production';
  let reducedCosmicEffects = false;

  const viewport = () => ({ width: mount.clientWidth || 1, height: mount.clientHeight || 1 });
  const signal = (event, payload = {}) => onSignal?.(event, { variant: 'v7', ...payload });
  const cityController = createPlanetVariantController({
    variant: 'v7',
    edges: V3_PHYSICS_EDGES,
    nodesById,
    trace: ({ type, ...payload }) => signal(type, payload),
  });

  function worldPosition(node, target = new THREE.Vector3()) {
    const object = nodeObjects.get(node?.id);
    if (object?.getWorldPosition) return object.getWorldPosition(target);
    const coords = globe?.getCoords?.(node?.lat, node?.lng, .012);
    return coords ? target.set(coords.x, coords.y, coords.z) : target.set(0, 0, 0);
  }

  function cameraDistance() {
    if (!globe) return 2.1;
    return globe.camera().position.distanceTo(globe.controls().target)
      / Math.max(globe.getGlobeRadius?.() || 100, 1);
  }

  function perspectiveScale() {
    return clamp(1 + ((2.15 - cameraDistance()) * V5_SIZE_DEFAULTS.perspective), V5_SIZE_DEFAULTS.farLodMin, 1.12);
  }

  function hemisphereProfile(facing) {
    const blend = clamp(facing * .5 + .5, 0, 1);
    const smooth = blend * blend * (3 - (2 * blend));
    return {
      opacity: .44 + (.56 * smooth),
      glowOpacity: .06 + (.10 * smooth),
      glowScale: 1.92 - (.42 * smooth),
    };
  }

  function hitRadius(node, visualRadius) {
    if (!globe) return Math.max(visualRadius * 1.22, 3.5);
    const rendererSize = globe.renderer?.().getSize?.(new THREE.Vector2());
    const height = Math.max(Number(rendererSize?.y) || mount.clientHeight || 1, 1);
    const distance = globe.camera().position.distanceTo(worldPosition(node));
    const worldPerPixel = (2 * Math.tan((globe.camera().fov || 45) * Math.PI / 360) * distance) / height;
    return Math.max(visualRadius * 1.16, clamp(worldPerPixel * 16, worldPerPixel * 12, worldPerPixel * 20));
  }

  function createNodeObject(node) {
    const group = new THREE.Group();
    const radius = Number(node.visualRadius || 1);
    const sphere = new THREE.Mesh(sphereGeometry, new THREE.MeshStandardMaterial({
      color: DJINN_ORB_V5.atom,
      emissive: DJINN_ORB_V5.atomGlow,
      emissiveIntensity: .42,
      roughness: .65,
      metalness: .05,
      transparent: true,
      opacity: 1,
      depthTest: false,
      depthWrite: false,
    }));
    sphere.scale.setScalar(radius);
    sphere.renderOrder = 3;
    const glow = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial({
      color: DJINN_ORB_V5.atomGlow,
      transparent: true,
      opacity: .13,
      depthTest: false,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    }));
    glow.scale.setScalar(radius * 1.55);
    glow.renderOrder = 4;
    const hitSphere = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial({
      transparent: true,
      opacity: 0,
      depthTest: false,
      depthWrite: false,
    }));
    hitSphere.scale.setScalar(Math.max(radius * 1.5, 3.5));
    hitSphere.userData.isHitTarget = true;
    hitSphere.userData.nodeId = node.id;
    let bridgeRing = null;
    if (node.hasBridgeRing || V5_BRIDGE_NODE_IDS.has(node.id)) {
      bridgeRing = new THREE.Mesh(bridgeRingGeometry, new THREE.MeshBasicMaterial({
        color: '#BFEFFF', transparent: true, opacity: .38, depthTest: false, depthWrite: false, blending: THREE.AdditiveBlending,
      }));
      bridgeRing.rotation.set(.75, .35, 0);
      bridgeRing.renderOrder = 5;
      group.add(sphere, glow, bridgeRing, hitSphere);
    } else {
      group.add(sphere, glow, hitSphere);
    }
    group.userData = { nodeId: node.id, sphere, glow, hitSphere, bridgeRing, baseRadius: radius };
    nodeObjects.set(node.id, group);
    return group;
  }

  function relatedIds(nodeId) {
    const related = new Set([nodeId]);
    V3_PHYSICS_EDGES.forEach((edge) => {
      if (edge.source === nodeId) related.add(edge.target);
      if (edge.target === nodeId) related.add(edge.source);
    });
    return related;
  }

  function refreshNodeVisuals() {
    if (!globe) return;
    const related = focusedNode ? relatedIds(focusedNode.id) : null;
    const cameraDirection = globe.camera().position.clone().sub(globe.controls().target).normalize();
    const scale = perspectiveScale();
    nodeObjects.forEach((object, nodeId) => {
      const data = object.userData;
      const node = nodesById.get(nodeId);
      if (!node) return;
      const isFocused = focusedNode?.id === nodeId;
      const isRelated = Boolean(related?.has(nodeId));
      const state = v5VariantContextVisualState('v7', {
        hasFocus: Boolean(focusedNode), isFocused, isRelated,
      });
      const facing = worldPosition(node).normalize().dot(cameraDirection);
      const hemisphere = hemisphereProfile(facing);
      const interactionScale = isFocused ? 1.16 : (isRelated ? 1.035 : 1);
      const visualRadius = Number(node.visualRadius || data.baseRadius) * scale * interactionScale;
      data.visualRadius = visualRadius;
      data.hitRadius = hitRadius(node, visualRadius);
      data.sphere.material.color.set(state.color);
      data.sphere.material.opacity = state.sphereOpacity * hemisphere.opacity;
      data.sphere.material.emissive.set(isFocused ? DJINN_ORB_V5.focusGlow : DJINN_ORB_V5.atomGlow);
      data.sphere.material.emissiveIntensity = state.emissiveIntensity;
      data.sphere.material.depthTest = false;
      data.sphere.material.depthWrite = false;
      data.sphere.scale.setScalar(visualRadius);
      data.sphere.renderOrder = 3;
      data.glow.visible = true;
      data.glow.material.color.set(isFocused ? DJINN_ORB_V5.focusGlow : DJINN_ORB_V5.atomGlow);
      data.glow.material.opacity = clamp(hemisphere.glowOpacity * state.glowMultiplier, 0, .48);
      data.glow.scale.setScalar(visualRadius * V5_SIZE_DEFAULTS.halo * hemisphere.glowScale);
      if (data.bridgeRing) {
        data.bridgeRing.visible = true;
        data.bridgeRing.material.opacity = state.bridgeOpacity;
        data.bridgeRing.scale.setScalar(visualRadius * 1.18);
      }
      data.hitSphere.scale.setScalar(data.hitRadius);
      data.hitSphere.visible = true;
      object.visible = true;
    });
    refreshLabels();
  }

  function labelCandidates() {
    const importance = (node) => Number(node.weightedDegree || 0);
    const compare = (left, right) => (importance(right) - importance(left)) || String(left.id).localeCompare(String(right.id));
    if (focusedNode) {
      const related = relatedIds(focusedNode.id);
      return [focusedNode, ...atoms.filter((node) => node.id !== focusedNode.id && related.has(node.id)).sort(compare)];
    }
    const byCommunity = new Map();
    atoms.forEach((node) => {
      const existing = byCommunity.get(node.community);
      if (!existing || compare(node, existing) < 0) byCommunity.set(node.community, node);
    });
    const seen = new Set();
    return [...byCommunity.values().sort(compare), ...atoms.slice().sort(compare)].filter((node) => {
      if (seen.has(node.id)) return false;
      seen.add(node.id);
      return true;
    });
  }

  function overlaps(left, right, padding = 6) {
    return !(left.right + padding < right.left || right.right + padding < left.left
      || left.bottom + padding < right.top || right.bottom + padding < left.top);
  }

  function refreshLabels() {
    if (!labelLayer || !globe) return;
    const { width, height } = viewport();
    const camera = globe.camera();
    const cameraDirection = camera.position.clone().sub(globe.controls().target).normalize();
    const budget = getPlanetLabelLod({ distance: cameraDistance(), focused: Boolean(focusedNode) }).limit;
    const placed = [];
    const visible = new Set();
    labelCandidates().some((node) => {
      if (placed.length >= budget) return true;
      const text = String(node.label || node.id).replace(/\s+/g, ' ').trim().slice(0, 28);
      if (!text) return false;
      const position = worldPosition(node);
      const projected = position.project(camera);
      const isFocused = focusedNode?.id === node.id;
      if (projected.z < -1 || projected.z > 1 || (!isFocused && position.normalize().dot(cameraDirection) < -.06)) return false;
      const labelWidth = Math.min(148, Math.max(48, text.length * 6.6 + 20));
      const labelHeight = 23;
      const left = (projected.x * .5 + .5) * width - labelWidth / 2;
      const top = (-projected.y * .5 + .5) * height - labelHeight / 2;
      const rect = { left, top, right: left + labelWidth, bottom: top + labelHeight };
      if (rect.right < 8 || rect.left > width - 8 || rect.bottom < 8 || rect.top > height - 8 || placed.some((item) => overlaps(rect, item))) return false;
      placed.push(rect);
      visible.add(node.id);
      let element = labelElements.get(node.id);
      if (!element) {
        element = document.createElement('span');
        element.className = 'universe4-v7-label';
        element.dataset.nodeId = node.id;
        labelElements.set(node.id, element);
      }
      element.textContent = text;
      element.classList.toggle('is-focus', isFocused);
      element.style.width = `${labelWidth}px`;
      element.style.transform = `translate3d(${left}px, ${top}px, 0)`;
      labelLayer.append(element);
      return false;
    });
    labelElements.forEach((element, nodeId) => { if (!visible.has(nodeId)) element.remove(); });
  }

  function scheduleLabels() {
    if (!globe || labelFrame) return;
    labelFrame = window.requestAnimationFrame(() => {
      labelFrame = 0;
      if (disposed || !globe) return;
      globe.scene().updateMatrixWorld?.(true);
      globe.camera().updateMatrixWorld?.(true);
      refreshNodeVisuals();
    });
  }

  function syncSelectionPaths(reason) {
    if (!globe) return;
    const selection = cityController.state();
    if (selection.selectedCityId && selection.selectedCityArcData.length
      && selection.selectedCityArcData.every((arc) => arc.renderer === U4_V7_SURFACE_SELECTION_RENDERER)) {
      const result = commitPlanetSelectionArcs({ globe, selection, trace: { record: signal } });
      signal('arc.native.profile', {
        reason,
        renderer: 'Globe.gl native Paths / great-circle surface line',
        color: DJINN_ORB_V5.focus,
        selectedCityId: selection.selectedCityId,
        continuous: true,
        altitude: .015,
        pathResolution: .5,
        assignedCount: result.assignedCount,
        verifiedCount: result.verifiedCount,
      });
      return;
    }
    clearPlanetSelectionArcs({ globe, trace: { record: signal }, reason });
  }

  function activateCity(cityId) {
    const transition = cityController.tap(cityId);
    const selection = transition.selection;
    focusedNode = selection.selectedCityId ? nodesById.get(selection.selectedCityId) || null : null;
    signal('focus.transition', {
      cityId,
      action: transition.action,
      selectedCityId: selection.selectedCityId,
      selectedArcCount: selection.selectedCityArcData.length,
    });
    refreshNodeVisuals();
    syncSelectionPaths('focus-refresh');
    onCitySelection?.({ action: transition.action, selection });
  }

  function clearSelection(reason = 'blank-globe-tap') {
    const current = cityController.state();
    if (!current.selectedCityId) {
      signal('selection.clear.skip', { reason, selectedCityId: null });
      return;
    }
    cityController.clear(reason);
    focusedNode = null;
    refreshNodeVisuals();
    syncSelectionPaths(reason);
    onCitySelection?.({ action: 'clear', selection: cityController.state() });
  }

  function pickCity(event) {
    if (!globe || !inputEnabled) return null;
    const rect = mount.getBoundingClientRect();
    if (!rect.width || !rect.height) return null;
    pointerRuntime.ndc.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -(((event.clientY - rect.top) / rect.height) * 2 - 1),
    );
    const camera = globe.camera();
    globe.scene().updateMatrixWorld?.(true);
    camera.updateMatrixWorld?.(true);
    pointerRuntime.raycaster.setFromCamera(pointerRuntime.ndc, camera);
    const cameraDirection = camera.position.clone().sub(globe.controls().target).normalize();
    const selectedHitSphere = focusedNode ? nodeObjects.get(focusedNode.id)?.userData?.hitSphere : null;
    const selectedFront = focusedNode ? worldPosition(focusedNode).normalize().dot(cameraDirection) > -.06 : false;
    if (selectedHitSphere && selectedFront && pointerRuntime.raycaster.intersectObject(selectedHitSphere, false).length) {
      signal('pointer.pick.selected', { cityId: focusedNode.id });
      return focusedNode.id;
    }
    const hitTargets = [...nodeObjects.values()].map((object) => object.userData?.hitSphere).filter(Boolean);
    if (hitTargets.length < atoms.length) {
      signal('pointer.pick.not-ready', { targetCount: hitTargets.length, expectedTargetCount: atoms.length, selectedCityId: focusedNode?.id || null });
      return undefined;
    }
    const hit = pointerRuntime.raycaster.intersectObjects(hitTargets, false).find((intersection) => {
      const node = nodesById.get(intersection.object.userData?.nodeId);
      return node && worldPosition(node).normalize().dot(cameraDirection) > -.06;
    });
    const cityId = hit?.object?.userData?.nodeId || null;
    signal(cityId ? 'pointer.pick.hit' : 'pointer.pick.miss', { cityId, targetCount: hitTargets.length });
    return cityId;
  }

  const inputRouter = createPlanetInputRouter({
    canvas: mount,
    runtimeFor: () => pointerRuntime,
    isEnabled: () => inputEnabled && !disposed,
    pick: pickCity,
    activate: activateCity,
    onEmptyTap: () => clearSelection(),
    trace: signal,
  });

  function attachInput() {
    mount.addEventListener('pointerdown', inputRouter.onPointerDown, true);
    mount.addEventListener('pointermove', inputRouter.onPointerMove, true);
    mount.addEventListener('pointerup', inputRouter.onPointerUp, true);
    mount.addEventListener('pointercancel', inputRouter.onPointerCancel, true);
  }

  function detachInput() {
    mount.removeEventListener('pointerdown', inputRouter.onPointerDown, true);
    mount.removeEventListener('pointermove', inputRouter.onPointerMove, true);
    mount.removeEventListener('pointerup', inputRouter.onPointerUp, true);
    mount.removeEventListener('pointercancel', inputRouter.onPointerCancel, true);
  }

  function updateV7Material() {
    const material = globe?.globeMaterial?.();
    const settings = v7LightRig?.getMaterialSettings?.();
    if (!material || !settings) return;
    material.color.set(settings.color);
    material.specular?.set(settings.specular);
    material.shininess = settings.shininess;
    material.emissive?.set(settings.emissive);
    material.emissiveIntensity = settings.emissiveIntensity;
    material.transparent = false;
    material.opacity = 1;
    material.depthTest = true;
    material.depthWrite = true;
    material.needsUpdate = true;
  }

  function attachV7Environment() {
    const scene = globe.scene();
    v7LightRig = new VirtualGalaxyLightingRig({
      THREE,
      scene,
      getCamera: () => globe.camera(),
      getPlanetCenter: (target) => target.copy(globe.controls().target),
      getPlanetRadius: () => globe.getGlobeRadius?.() || 100,
      planetId: 'explore-v7-knowledge-planet',
    });
    v7LightRig.initialize();
    // The current Explore V7 source-of-truth state uses its explicit
    // Universe V3 Reference profile: opaque violet body, white-magenta key
    // and a readable deep-violet far side. U4 inherits that exact V7 preset
    // instead of inventing a handoff-only colour grade.
    v7LightRig.setMode('universe-v3-reference');
    v7LightRig.setCinematicBlend(V7_PRODUCTION_CINEMATIC_BLEND);
    v7LightRig.captureEntryFrame({ planetId: 'explore-v7-knowledge-planet' });
    v7LightRig.resume();
    globe.lights(v7LightRig.getLights());
    updateV7Material();
    cosmicEnvironment = new CosmicEnvironment({
      THREE,
      scene,
      getRenderer: () => globe.renderer(),
      getCamera: () => globe.camera(),
      getPlanetCenter: (target) => target.copy(globe.controls().target),
      getPlanetRadius: () => globe.getGlobeRadius?.() || 100,
      getWorldSunDirection: (target) => v7LightRig.copyWorldSunDirection(target),
      getLensFlareController: () => null,
      planetId: 'explore-v7-knowledge-planet',
    });
    cosmicEnvironment.initialize();
    cosmicEnvironment.setMode(activeCosmicMode);
    cosmicEnvironment.setReducedEffects(reducedCosmicEffects);
    cosmicEnvironment.captureEntryFrame();
    cosmicEnvironment.resume();
    sceneBeforeRender = scene.onBeforeRender;
    sceneBeforeRenderHook = function universe4V7BeforeRender(...args) {
      sceneBeforeRender?.apply(this, args);
      if (disposed || !globe) return;
      v7LightRig.updateTargetFromCamera();
      v7LightRig.updateFrame(performance.now());
      cosmicEnvironment.updateFrame(performance.now());
      renderedFrames += 1;
    };
    scene.onBeforeRender = sceneBeforeRenderHook;
    controlsListener = () => {
      v7LightRig?.updateTargetFromCamera();
      scheduleLabels();
    };
    globe.controls().addEventListener('change', controlsListener);
  }

  function createLabelLayer() {
    labelLayer?.remove();
    labelLayer = document.createElement('div');
    labelLayer.className = 'universe4-v7-label-layer';
    labelLayer.setAttribute('aria-hidden', 'true');
    mount.append(labelLayer);
  }

  function frameCount() {
    if (disposed || !globe) return;
    frameCounter = window.requestAnimationFrame(frameCount);
  }

  function destroyGlobe() {
    window.cancelAnimationFrame(frameCounter);
    window.cancelAnimationFrame(labelFrame);
    frameCounter = 0;
    labelFrame = 0;
    detachInput();
    inputRouter.clear();
    if (controlsListener) globe?.controls?.().removeEventListener?.('change', controlsListener);
    controlsListener = null;
    if (globe?.scene?.()?.onBeforeRender === sceneBeforeRenderHook) globe.scene().onBeforeRender = sceneBeforeRender;
    sceneBeforeRender = null;
    sceneBeforeRenderHook = null;
    cosmicEnvironment?.dispose?.();
    cosmicEnvironment = null;
    v7LightRig?.dispose?.();
    v7LightRig = null;
    disposeNodeObjects(nodeObjects);
    labelElements.clear();
    labelLayer?.remove();
    labelLayer = null;
    try { globe?._destructor?.(); } catch { /* Globe.gl vendor cleanup is best effort. */ }
    globe = null;
    ready = false;
    renderedFrames = 0;
    mount.replaceChildren();
  }

  async function prewarm() {
    if (globe) destroyGlobe();
    const Globe = await loadGlobe();
    if (disposed) return { ready: false, cancelled: true };
    let resolveReady;
    const readyPromise = new Promise((resolve) => { resolveReady = resolve; });
    globe = new Globe(mount, {
      rendererConfig: { antialias: true, alpha: true },
      waitForGlobeReady: false,
      animateIn: false,
    })
      // V7 itself intentionally renders over this opaque near-black, not
      // the palette's transparent/blue route backdrop. Keeping the literal
      // source value is important during the live crossfade.
      .backgroundColor('#0B0A17')
      .showAtmosphere(false)
      .showGraticules(false)
      .objectsData([])
      .objectLat((point) => point.lat)
      .objectLng((point) => point.lng)
      .objectAltitude(() => .012)
      .arcsData([])
      .pathsData([])
      .pathPoints((edge) => edge.surfacePoints)
      .pathPointLat((point) => point.lat)
      .pathPointLng((point) => point.lng)
      .pathPointAlt((point) => point.altitude)
      .pathColor(() => DJINN_ORB_V5.focus)
      .pathStroke((edge) => Number(edge?.stroke || 0))
      .pathResolution(.5)
      .pathDashLength(() => 1)
      .pathDashGap(() => 0)
      .pathDashAnimateTime(() => 0)
      .pathTransitionDuration(0)
      .arcsTransitionDuration(0)
      .onGlobeReady(() => {
        ready = true;
        resolveReady({ ready: true });
      });
    globe.enablePointerInteraction(false);
    globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 0);
    rebindPlanetObjects({
      globe,
      points: atoms,
      clearRegistry: () => disposeNodeObjects(nodeObjects),
      createObject: createNodeObject,
      trace: signal,
      reason: 'u4-v7-source-truth-prewarm',
    });
    createLabelLayer();
    attachV7Environment();
    attachInput();
    resize();
    refreshNodeVisuals();
    syncSelectionPaths('initial');
    setInputEnabled(false);
    mount.style.opacity = '0';
    frameCount();
    const outcome = await Promise.race([
      readyPromise,
      new Promise((resolve) => window.setTimeout(() => resolve({ ready: true, timeoutFallback: true }), 180)),
    ]);
    ready = true;
    return outcome;
  }

  function setInputEnabled(enabled) {
    inputEnabled = Boolean(enabled);
    if (!globe) return;
    mount.style.pointerEvents = inputEnabled ? 'auto' : 'none';
    const controls = globe.controls();
    controls.enabled = inputEnabled;
    controls.enablePan = false;
    controls.enableRotate = inputEnabled;
    controls.enableZoom = inputEnabled;
    controls.enableDamping = true;
    controls.dampingFactor = .08;
    controls.minDistance = (globe.getGlobeRadius?.() || 100) * 1.7;
    controls.maxDistance = (globe.getGlobeRadius?.() || 100) * 8.2;
    controls.update();
  }

  function setMappedCamera(mapping) {
    if (!globe || !mapping) return null;
    const camera = globe.camera();
    camera.fov = Number(mapping.fov || camera.fov);
    camera.aspect = Number(mapping.aspect || camera.aspect);
    camera.near = Number(mapping.near || camera.near);
    camera.far = Number(mapping.far || camera.far);
    camera.updateProjectionMatrix();
    globe.globeOffset([Number(mapping.offsetX || 0), Number(mapping.offsetY || 0)]);
    globe.pointOfView({
      lat: Number(mapping.lat || 0),
      lng: Number(mapping.lng || 0),
      altitude: Math.max(.01, Number(mapping.altitude || 2.5)),
    }, 0);
    globe.controls().update();
    v7LightRig?.captureEntryFrame({ planetId: 'explore-v7-knowledge-planet' });
    refreshNodeVisuals();
    return captureCamera();
  }

  function captureCamera() {
    if (!globe) return null;
    const camera = globe.camera();
    const controls = globe.controls();
    camera.updateMatrixWorld(true);
    return {
      pov: globe.pointOfView(),
      cameraPosition: camera.getWorldPosition(new THREE.Vector3()),
      cameraQuaternion: camera.getWorldQuaternion(new THREE.Quaternion()),
      cameraUp: camera.up.clone(),
      fov: camera.fov,
      aspect: camera.aspect,
      near: camera.near,
      far: camera.far,
      controlsTarget: controls.target.clone(),
      globeRadius: globe.getGlobeRadius?.() || 100,
      screen: screenMetrics(globe, viewport()),
    };
  }

  function getLandmarkScreenPoints(landmarks = []) {
    if (!globe) return [];
    const { width, height } = viewport();
    const camera = globe.camera();
    return landmarks.map((landmark) => {
      const node = nodesById.get(landmark.id) || landmark;
      const position = worldPosition(node).project(camera);
      return { id: landmark.id || node.id, x: (position.x * .5 + .5) * width, y: (-position.y * .5 + .5) * height };
    });
  }

  function resize() {
    if (!globe) return;
    const { width, height } = viewport();
    globe.width(width).height(height);
    const camera = globe.camera();
    camera.aspect = width / Math.max(1, height);
    camera.updateProjectionMatrix();
    v7LightRig?.resize?.();
    cosmicEnvironment?.resize?.();
    scheduleLabels();
  }

  return Object.freeze({
    prewarm,
    resize,
    setInputEnabled,
    setMappedCamera,
    captureCamera,
    getLandmarkScreenPoints,
    setOpacity(opacity) { mount.style.opacity = String(opacity); },
    pause() { setInputEnabled(false); v7LightRig?.suspend(); cosmicEnvironment?.suspend(); },
    resume() { v7LightRig?.resume(); cosmicEnvironment?.resume(); },
    setCosmicMode(mode) {
      if (!COSMIC_MODES.includes(mode)) return false;
      activeCosmicMode = mode;
      cosmicEnvironment?.setMode(mode);
      return true;
    },
    setReducedCosmicEffects(enabled) {
      reducedCosmicEffects = Boolean(enabled);
      cosmicEnvironment?.setReducedEffects(reducedCosmicEffects);
    },
    selection() { return cityController.state(); },
    signalEntries: () => null,
    get globe() { return globe; },
    get ready() { return ready; },
    get renderedFrames() { return renderedFrames; },
    dispose() { disposed = true; destroyGlobe(); sphereGeometry.dispose(); bridgeRingGeometry.dispose(); },
  });
}
