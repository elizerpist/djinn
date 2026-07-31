import { createUniverse4TransitionMachine, U4_STATE } from './universe4/universe4-transition-machine.js?rev=2';
import { createUniverse4U3Stage } from './universe4/universe4-u3-stage.js?rev=20';
import { createUniverse4V7SourceStage } from './universe4/universe4-v7-source-stage.js?rev=22';
import { prepareInvisibleGlobeMatch } from './universe4/universe4-handoff-matcher.js?rev=1';
import { resolveUniverse4Background } from './universe4/universe4-background.js?rev=1';
import { mountUniverse4DebugPanel } from './universe4/universe4-debug-panel.js?rev=3';
import { createUniverse4DepthController, U4_DEPTH_STATE } from './universe4/universe4-depth-controller.js?rev=1';
import { resolveUniverse4GlobeTap } from './universe4/universe4-globe-selection.js?rev=2';
import { buildUniverse4FocusedMapSnapshot } from './universe4/universe4-focused-map-snapshot.js?rev=2';
import { createUniverse4TangentPlane } from './universe4/universe4-tangent-plane.js?rev=1';
import { createUniverse4MorphPatch } from './universe4/universe4-morph-patch.js?rev=1';
import { createUniverse4G6FocusedMapStage } from './universe4/universe4-g6-focused-map-stage.js?rev=3';
import { universe4InputOwnershipForDepth } from './universe4/universe4-input-ownership.js?rev=1';

const HANDOFF_DURATION_MS = 240;

function sameValue(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function renderProfileParity(forceProfile, globeProfile) {
  const forceLights = forceProfile?.sceneLights || [];
  const globeLights = globeProfile?.sceneLights || [];
  return {
    material: sameValue(forceProfile?.material, globeProfile?.material),
    rendererColorPipeline: sameValue(
      forceProfile?.renderer && {
        outputColorSpace: forceProfile.renderer.outputColorSpace,
        outputEncoding: forceProfile.renderer.outputEncoding,
        toneMapping: forceProfile.renderer.toneMapping,
        toneMappingExposure: forceProfile.renderer.toneMappingExposure,
        physicallyCorrectLights: forceProfile.renderer.physicallyCorrectLights,
      },
      globeProfile?.renderer && {
        outputColorSpace: globeProfile.renderer.outputColorSpace,
        outputEncoding: globeProfile.renderer.outputEncoding,
        toneMapping: globeProfile.renderer.toneMapping,
        toneMappingExposure: globeProfile.renderer.toneMappingExposure,
        physicallyCorrectLights: globeProfile.renderer.physicallyCorrectLights,
      },
    ),
    sceneLightCount: { force: forceLights.length, globe: globeLights.length },
    sceneLights: sameValue(forceLights, globeLights),
  };
}

export const getUniverse4PointerOwner = (state, depthState = null) => {
  if (depthState) return universe4InputOwnershipForDepth(depthState);
  if (state === U4_STATE.GLOBE_STANDALONE) return 'GLOBE';
  if ([U4_STATE.INLINE_PLANET_ENTER, U4_STATE.INLINE_PLANET_FOCUS, U4_STATE.GLOBE_PREWARM,
    U4_STATE.HANDOFF_ALIGN, U4_STATE.HANDOFF_READY, U4_STATE.HANDOFF_CROSSFADE,
    U4_STATE.RETURN_PREPARE, U4_STATE.RETURN_ALIGN, U4_STATE.RETURN_CROSSFADE].includes(state)) return 'LOCKED';
  return 'FORCE';
};

const easeInOut = (progress) => (progress < .5
  ? 4 * progress * progress * progress
  : 1 - Math.pow(-2 * progress + 2, 3) / 2);

function fade(duration, onFrame) {
  const startedAt = performance.now();
  return new Promise((resolve) => {
    const render = (now) => {
      const raw = Math.min(1, (now - startedAt) / Math.max(1, duration));
      onFrame(easeInOut(raw));
      if (raw < 1) window.requestAnimationFrame(render);
      else resolve();
    };
    window.requestAnimationFrame(render);
  });
}

const wait = (duration) => new Promise((resolve) => window.setTimeout(resolve, Math.max(0, duration)));

// U4 is explicitly a renderer handoff prototype: its entry is the production
// U3 ForceGraph controller and its destination is the production Universe V7
// controller mounted in a second, overlapping stage. Neither endpoint is
// recreated in this file.
export function initUniverse4(root, helpers = {}) {
  const stageShell = root.querySelector('[data-universe4-stage-shell]');
  const viewport = root.querySelector('[data-universe4-viewport]');
  const u3Mount = root.querySelector('[data-universe4-force-stage]');
  const v7Mount = root.querySelector('[data-universe4-globe-stage]');
  const morphPatchMount = root.querySelector('[data-universe4-morph-patch-stage]');
  const g6Mount = root.querySelector('[data-universe4-g6-stage]');
  const v7DebugPortal = root.querySelector('[data-universe4-v7-debug-portal]');
  const debugHost = root.querySelector('[data-universe4-debug]');
  const fullscreenButton = root.querySelector('[data-universe4-fullscreen]');
  const resetButton = root.querySelector('[data-universe4-reset]');
  const forceBackgroundSelect = root.querySelector('[data-universe4-force-background]');
  const globeBackgroundSelect = root.querySelector('[data-universe4-globe-background]');
  if (!stageShell || !viewport || !u3Mount || !v7Mount || !morphPatchMount || !g6Mount) return () => {};

  const machine = createUniverse4TransitionMachine();
  const depth = createUniverse4DepthController();
  let disposed = false;
  let handoffInFlight = false;
  let mapTransitionInFlight = false;
  let activePlanetId = null;
  let forceOpacity = 1;
  let globeOpacity = 0;
  let morphPatchOpacity = 0;
  let g6Opacity = 0;
  let depthGeneration = 0;
  let focusedMapSnapshot = null;
  let focusedMapEntryLayout = null;
  let focusedMapSettleTimer = 0;
  let fullscreenFallbackActive = false;
  let lastResetRequestAt = -Infinity;
  let latestMatch = null;
  let handoffLabelReleaseTimer = 0;
  // The canonical V7 factory can synchronously publish `onGlobeReady` while
  // it is still being constructed. This intentionally starts as nullable so
  // every callback sees a safe value rather than a temporal-dead-zone const.
  let v7Stage = null;
  // G6 uses the same callback model: onReady can fire while its factory is
  // still constructing the stage, before an assignment expression completes.
  let g6Stage = null;

  const debug = mountUniverse4DebugPanel({ host: debugHost, viewport, onProof });
  const recordU4Signal = (event, payload = {}) => {
    debug.appendSignal(event, payload);
    // Keep transition diagnostics in the same canonical trace as pointer and
    // Globe events. This makes a claimed tap distinguishable from a map
    // transition that was rejected or failed during prewarm.
    v7Stage?.recordEmbeddedSignal?.(event, payload);
  };
  const morphPatch = createUniverse4MorphPatch({ mount: morphPatchMount });
  g6Stage = createUniverse4G6FocusedMapStage({
    mount: g6Mount,
    onReady: () => {
      if (disposed) return;
      debug.appendSignal('u4.g6.ready', { stage: 'focused-map-v2' });
      updateDebug();
    },
    onNodeClick: (cityId, mapState = {}) => {
      debug.appendSignal('u4.g6.node.focus', {
        cityId,
        previousFocusCityId: mapState.previousFocusCityId || null,
        focusCityId: mapState.focusCityId || cityId,
        visibleNodeCount: mapState.visibleNodeCount || 0,
      });
      updateDebug();
    },
  });
  v7Stage = createUniverse4V7SourceStage({
    mount: v7Mount,
    debugPortal: v7DebugPortal,
    onCityTap: resolveV7CityTap,
    onSelectionTransition: onV7SelectionTransition,
    onCityVisualRole: resolveV7CityVisualRole,
    onInputDiagnostic: (event, payload) => {
      if (disposed) return;
      debug.appendSignal(event, payload);
      updateDebug();
    },
    onReady: () => {
      // The Globe stage may invoke onGlobeReady synchronously while
      // createUniverse4V7SourceStage is still constructing the const below.
      // Deferring prevents updateDebug from reading v7Stage in its temporal
      // dead zone and, crucially, lets the canonical V7 factory finish its
      // ResizeObserver/edge setup without being caught as a globe error.
      queueMicrotask(() => {
        if (disposed) return;
        debug.appendSignal('v7.source.ready', { source: 'initUniverse4GlobeStage', variant: 'v7' });
        updateDebug();
      });
    },
  });
  const u3Stage = createUniverse4U3Stage({
    mount: u3Mount,
    helpers,
    onPlanetReady: handoffToCanonicalV7,
  });

  function setStageOpacities(nextForceOpacity, nextGlobeOpacity) {
    forceOpacity = Math.max(0, Math.min(1, nextForceOpacity));
    globeOpacity = Math.max(0, Math.min(1, nextGlobeOpacity));
    u3Stage.setOpacity(forceOpacity);
    v7Stage.setOpacity(globeOpacity);
    updateDebug();
  }

  function setMapStageOpacities(nextPatchOpacity, nextG6Opacity) {
    morphPatchOpacity = Math.max(0, Math.min(1, nextPatchOpacity));
    g6Opacity = Math.max(0, Math.min(1, nextG6Opacity));
    morphPatch.setOpacity(morphPatchOpacity);
    g6Stage.setOpacity(g6Opacity);
    updateDebug();
  }

  function applyDepthInputOwnership() {
    const owner = universe4InputOwnershipForDepth(depth.state);
    u3Stage.setInputEnabled(owner === 'FORCE');
    v7Stage?.setInputEnabled(owner === 'GLOBE');
    g6Stage.setInputEnabled(owner === 'G6');
    g6Mount.classList.toggle('is-interactive', owner === 'G6');
    v7Mount.classList.toggle('is-interactive', owner === 'GLOBE');
    debug.appendSignal('u4.input.owner', {
      owner,
      depthState: depth.state,
      v7InteractiveClass: v7Mount.classList.contains('is-interactive'),
      g6InteractiveClass: g6Mount.classList.contains('is-interactive'),
      v7MountPointerEvents: v7Mount.style.pointerEvents || null,
      g6MountPointerEvents: g6Mount.style.pointerEvents || null,
    });
    return owner;
  }

  function updateDebug() {
    const matchRejected = Boolean(latestMatch && !latestMatch.valid);
    // A healthy U4 endpoint stays visually identical to the bare V7 source.
    // On a rejected hidden calibration, however, the user needs the exact
    // measured center/radius/landmark deltas rather than a wrong Globe frame.
    stageShell.classList.toggle('is-u4-match-diagnostics', matchRejected);
    debug.update({
      state: machine.state,
      depthState: depth.state,
      generation: machine.generation,
      planetId: activePlanetId,
      pointerOwner: getUniverse4PointerOwner(machine.state, depth.state),
      forceOpacity,
      globeOpacity,
      globeReady: Boolean(v7Stage?.isReady),
      globeFrames: latestMatch?.stableFrames || 0,
      forcePaused: machine.state === U4_STATE.GLOBE_STANDALONE,
      pixelMatch: latestMatch?.match || { valid: false, failures: ['awaiting-hidden-calibration'] },
      globeOffset: latestMatch?.pose?.globeOffset || null,
      crossfadeProgress: globeOpacity,
      mapOpacity: g6Opacity,
      morphPatchOpacity,
      mapSnapshot: focusedMapSnapshot?.snapshotId || null,
      g6MapState: g6Stage?.getState?.() || null,
      forceCamera: latestMatch?.forceFrame?.cameraPosition
        ? `${latestMatch.forceFrame.cameraPosition.x.toFixed(1)}, ${latestMatch.forceFrame.cameraPosition.y.toFixed(1)}, ${latestMatch.forceFrame.cameraPosition.z.toFixed(1)}`
        : (machine.state === U4_STATE.GALAXY_IDLE ? 'Universe V3 owns camera' : 'awaiting U3 frame capture'),
      globePov: latestMatch?.pose?.pointOfView
        ? `${latestMatch.pose.pointOfView.lat.toFixed(2)}° / ${latestMatch.pose.pointOfView.lng.toFixed(2)}° / ${latestMatch.pose.pointOfView.altitude.toFixed(3)}`
        : (v7Stage?.globe?.pointOfView ? 'Universe V7 prewarming' : 'Universe V7 unavailable'),
    });
  }

  function applyRendererBackground(renderer, profileId) {
    const profile = resolveUniverse4Background(profileId);
    const applied = renderer === 'force'
      ? u3Stage.setBackgroundColor(profile.color)
      : v7Stage.setBackgroundColor(profile.color);
    debug.appendSignal('u4.background.change', {
      renderer,
      profile: profile.id,
      color: profile.color,
      applied,
    });
    updateDebug();
    return applied;
  }

  function onForceBackgroundChange(event) {
    applyRendererBackground('force', event.currentTarget.value);
  }

  function onGlobeBackgroundChange(event) {
    applyRendererBackground('globe', event.currentTarget.value);
  }

  function scheduleStandaloneLabelLod(generation) {
    if (handoffLabelReleaseTimer) window.clearTimeout(handoffLabelReleaseTimer);
    handoffLabelReleaseTimer = window.setTimeout(() => {
      handoffLabelReleaseTimer = 0;
      if (disposed || !machine.isCurrentGeneration(generation) || machine.state !== U4_STATE.GLOBE_STANDALONE) return;
      if (v7Stage.releaseHandoffLabels()) {
        debug.appendSignal('u4.handoff.labels.release', { planetId: activePlanetId, delayMs: 400 });
      }
    }, 400);
  }

  function resolveV7CityTap(payload = {}) {
    const depthIsReady = [
      U4_DEPTH_STATE.PLANET_IDLE,
      U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
    ].includes(depth.state);
    if (disposed || mapTransitionInFlight || !depthIsReady) {
      recordU4Signal('u4.globe.tap.skip', {
        cityId: payload.cityId || null,
        disposed,
        mapTransitionInFlight,
        depthState: depth.state,
        depthIsReady,
      });
      return null;
    }
    const resolution = resolveUniverse4GlobeTap({ cityId: payload.cityId, selection: payload.selection });
    recordU4Signal('u4.globe.tap.resolve', {
      cityId: payload.cityId || null,
      role: resolution.role,
      action: resolution.action,
      rootCityId: resolution.rootCityId,
      contextCityIds: resolution.contextCityIds,
    });
    if (resolution.action === 'enter-map') {
      recordU4Signal('u4.map.request', {
        cityId: resolution.cityId,
        rootCityId: resolution.rootCityId,
        contextCityCount: resolution.contextCityIds.length,
        depthState: depth.state,
        mapTransitionInFlight,
      });
      void enterFocusedMap(resolution, payload);
      return { handled: true, action: 'enter-map' };
    }
    if (resolution.action === 'clear-context') {
      return { handled: true, action: 'clear-context', reason: resolution.role === 'foreign' ? 'foreign-city-first-tap' : 'context-toggle-off' };
    }
    return null;
  }

  function resolveV7CityVisualRole({ cityId, selection } = {}) {
    return resolveUniverse4GlobeTap({ cityId, selection }).role;
  }

  function onV7SelectionTransition(payload = {}) {
    if (disposed || mapTransitionInFlight) return;
    const selectedCityId = payload.selection?.selectedCityId || null;
    if (selectedCityId && depth.state === U4_DEPTH_STATE.PLANET_IDLE) {
      depthGeneration = depth.begin(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE) || depthGeneration;
    } else if (!selectedCityId && depth.state === U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE) {
      depth.advance(U4_DEPTH_STATE.PLANET_IDLE, depthGeneration);
    }
    debug.appendSignal('u4.globe.selection', {
      source: payload.source || 'unknown',
      action: payload.action || 'unknown',
      cityId: payload.cityId || null,
      selectedCityId,
      depthState: depth.state,
      reason: payload.reason || null,
    });
    applyDepthInputOwnership();
    updateDebug();
  }

  function createFocusedMapEntryLayout(snapshot, anchor = null) {
    const width = Math.max(viewport.clientWidth || 0, 320);
    const height = Math.max(viewport.clientHeight || 0, 420);
    const focus = snapshot.nodes.find((node) => node.id === snapshot.focusCityId) || snapshot.nodes[0];
    const projector = createUniverse4TangentPlane(focus);
    const projected = snapshot.nodes.map((node) => ({ node, plane: projector.project(node).plane }));
    const maxDistance = Math.max(.001, ...projected.map(({ plane }) => Math.hypot(plane.x, plane.y)));
    const centerX = Number.isFinite(anchor?.left) ? anchor.left + anchor.width / 2 : width / 2;
    const centerY = Number.isFinite(anchor?.top) ? anchor.top + anchor.height / 2 : height / 2;
    const scale = Math.min(width, height) * .24 / maxDistance;
    return new Map(projected.map(({ node, plane }) => [node.id, {
      x: node.id === focus.id ? centerX : centerX + plane.x * scale,
      y: node.id === focus.id ? centerY : centerY + plane.y * scale,
    }]));
  }

  function globePositionsFor(snapshot) {
    return new Map(snapshot.nodes.map((node) => {
      const anchor = v7Stage.getCityAnchor(node.id);
      return [node.id, anchor
        ? { x: anchor.left + anchor.width / 2, y: anchor.top + anchor.height / 2 }
        : { x: viewport.clientWidth / 2, y: viewport.clientHeight / 2 }];
    }));
  }

  async function enterFocusedMap(resolution, payload) {
    if (disposed || mapTransitionInFlight || depth.state !== U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE) {
      recordU4Signal('u4.map.skip', {
        reason: disposed ? 'disposed' : mapTransitionInFlight ? 'transition-in-flight' : 'depth-not-context-active',
        depthState: depth.state,
        mapTransitionInFlight,
        cityId: resolution?.cityId || payload?.cityId || null,
      });
      return false;
    }
    mapTransitionInFlight = true;
    const generation = depth.begin(U4_DEPTH_STATE.PLANET_TO_MAP_PREPARE);
    if (!generation) {
      recordU4Signal('u4.map.skip', {
        reason: 'depth-transition-rejected',
        depthState: depth.state,
        cityId: resolution?.cityId || payload?.cityId || null,
      });
      mapTransitionInFlight = false;
      return false;
    }
    depthGeneration = generation;
    recordU4Signal('u4.map.begin', {
      generation,
      depthState: depth.state,
      cityId: resolution?.cityId || payload?.cityId || null,
      rootCityId: resolution?.rootCityId || null,
    });
    try {
      const cityIds = [resolution.rootCityId, ...resolution.contextCityIds];
      const nodes = cityIds.map((id) => v7Stage.getCity(id)).filter(Boolean);
      focusedMapSnapshot = buildUniverse4FocusedMapSnapshot({
        sourcePlanetId: activePlanetId || 'universe-v3-planet',
        rootCityId: resolution.rootCityId,
        tappedContextCityId: resolution.cityId,
        selection: payload.selection,
        nodes,
        globePointOfView: payload.pointOfView,
        cityAnchor: payload.cityAnchor,
      });
      focusedMapEntryLayout = createFocusedMapEntryLayout(focusedMapSnapshot, payload.cityAnchor);
      v7Stage.setInputEnabled(false);
      g6Stage.setInputEnabled(false);
      recordU4Signal('u4.map.prewarm', {
        snapshotId: focusedMapSnapshot.snapshotId,
        rootCityId: focusedMapSnapshot.rootCityId,
        focusCityId: focusedMapSnapshot.focusCityId,
        nodeCount: focusedMapSnapshot.nodes.length,
        edgeCount: focusedMapSnapshot.edges.length,
      });
      const g6Ready = await Promise.race([
        g6Stage.prewarm(focusedMapSnapshot, { entryLayout: focusedMapEntryLayout }),
        wait(2800).then(() => { throw new Error('G6 Focused Map v2 prewarm timeout'); }),
      ]);
      recordU4Signal('u4.map.prewarm.ready', {
        generation,
        ready: Boolean(g6Ready),
        depthState: depth.state,
      });
      if (!g6Ready || disposed || !depth.isCurrentGeneration(generation)) throw new Error('G6 Focused Map v2 is not ready');
      if (!depth.advance(U4_DEPTH_STATE.PLANET_TO_MAP_MORPH, generation)) throw new Error('planet-map-morph transition rejected');
      v7Stage.resumeAnimation();
      v7Stage.focusCityForMap(focusedMapSnapshot.focusCityId, { durationMs: 520, zoomFactor: .58 });
      const sourcePositions = globePositionsFor(focusedMapSnapshot);
      setMapStageOpacities(1, 0);
      await fade(520, (progress) => {
        if (disposed || !depth.isCurrentGeneration(generation)) return;
        morphPatch.draw({
          nodes: focusedMapSnapshot.nodes,
          edges: focusedMapSnapshot.edges,
          globePositions: sourcePositions,
          entryPositions: focusedMapEntryLayout,
          progress,
        });
      });
      if (disposed || !depth.isCurrentGeneration(generation)) return false;
      const finalAnchor = v7Stage.getCityAnchor(focusedMapSnapshot.focusCityId);
      focusedMapEntryLayout = createFocusedMapEntryLayout(focusedMapSnapshot, finalAnchor);
      g6Stage.showEntryLayout(focusedMapEntryLayout);
      morphPatch.draw({
        nodes: focusedMapSnapshot.nodes,
        edges: focusedMapSnapshot.edges,
        globePositions: globePositionsFor(focusedMapSnapshot),
        entryPositions: focusedMapEntryLayout,
        progress: 1,
      });
      await fade(240, (progress) => {
        if (disposed || !depth.isCurrentGeneration(generation)) return;
        setStageOpacities(0, 1 - progress);
        setMapStageOpacities(1 - progress, progress);
      });
      if (disposed || !depth.isCurrentGeneration(generation)) return false;
      v7Stage.pauseAnimation();
      if (!depth.advance(U4_DEPTH_STATE.MAP_ACTIVE, generation)) throw new Error('map-active transition rejected');
      applyDepthInputOwnership();
      focusedMapSettleTimer = window.setTimeout(() => {
        if (!disposed && depth.state === U4_DEPTH_STATE.MAP_ACTIVE) g6Stage.settleToFocusedLayout();
      }, 340);
      recordU4Signal('u4.map.active', {
        snapshotId: focusedMapSnapshot.snapshotId,
        focusCityId: focusedMapSnapshot.focusCityId,
        inputOwner: universe4InputOwnershipForDepth(depth.state),
      });
      updateDebug();
      return true;
    } catch (error) {
      if (depth.isCurrentGeneration(generation)) {
        depth.fail(generation);
        depth.advance(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE, generation);
      }
      setStageOpacities(0, 1);
      setMapStageOpacities(0, 0);
      v7Stage.resumeAnimation();
      applyDepthInputOwnership();
      recordU4Signal('u4.map.error', {
        generation,
        depthState: depth.state,
        message: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? (error.stack || null) : null,
      });
      updateDebug();
      return false;
    } finally {
      mapTransitionInFlight = false;
    }
  }

  async function returnFocusedMapToPlanet() {
    if (disposed || mapTransitionInFlight || depth.state !== U4_DEPTH_STATE.MAP_ACTIVE || !focusedMapSnapshot) return false;
    mapTransitionInFlight = true;
    if (focusedMapSettleTimer) window.clearTimeout(focusedMapSettleTimer);
    const generation = depth.begin(U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE);
    if (!generation) {
      mapTransitionInFlight = false;
      return false;
    }
    depthGeneration = generation;
    try {
      g6Stage.setInputEnabled(false);
      v7Stage.resumeAnimation();
      v7Stage.setInputEnabled(false);
      g6Stage.showEntryLayout(focusedMapEntryLayout);
      v7Stage.setPointOfView(focusedMapSnapshot.entryGlobePointOfView, 420);
      if (!depth.advance(U4_DEPTH_STATE.MAP_TO_PLANET_MORPH, generation)) throw new Error('map-planet-morph transition rejected');
      setMapStageOpacities(1, 1);
      await fade(420, (progress) => {
        if (disposed || !depth.isCurrentGeneration(generation)) return;
        morphPatch.draw({
          nodes: focusedMapSnapshot.nodes,
          edges: focusedMapSnapshot.edges,
          globePositions: globePositionsFor(focusedMapSnapshot),
          entryPositions: focusedMapEntryLayout,
          progress: 1 - progress,
        });
        setStageOpacities(0, progress);
        setMapStageOpacities(1 - progress, 1 - progress);
      });
      if (disposed || !depth.isCurrentGeneration(generation)) return false;
      if (!depth.advance(U4_DEPTH_STATE.PLANET_RETURNED, generation)) throw new Error('planet-returned transition rejected');
      if (!depth.advance(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE, generation)) throw new Error('planet-context restore transition rejected');
      applyDepthInputOwnership();
      debug.appendSignal('u4.map.return.complete', {
        snapshotId: focusedMapSnapshot.snapshotId,
        rootCityId: focusedMapSnapshot.rootCityId,
        focusCityId: focusedMapSnapshot.focusCityId,
      });
      updateDebug();
      return true;
    } catch (error) {
      if (depth.isCurrentGeneration(generation)) {
        depth.fail(generation);
        depth.advance(U4_DEPTH_STATE.MAP_ACTIVE, generation);
      }
      setStageOpacities(0, 0);
      setMapStageOpacities(0, 1);
      applyDepthInputOwnership();
      debug.appendSignal('u4.map.return.error', { message: error instanceof Error ? error.message : String(error) });
      return false;
    } finally {
      mapTransitionInFlight = false;
    }
  }

  async function handoffToCanonicalV7({ nodeId } = {}) {
    if (disposed || handoffInFlight || machine.state !== U4_STATE.GALAXY_IDLE) return { claimed: false };
    handoffInFlight = true;
    activePlanetId = nodeId || 'selected-planet';
    depthGeneration = depth.begin(U4_DEPTH_STATE.GALAXY_TO_PLANET);
    if (!depthGeneration) {
      handoffInFlight = false;
      return { claimed: false };
    }
    const generation = machine.begin(U4_STATE.INLINE_PLANET_ENTER);
    if (!generation) {
      handoffInFlight = false;
      return { claimed: false };
    }
    debug.appendSignal('u4.u3.inline.complete', { planetId: activePlanetId, generation });
    u3Stage.setInputEnabled(false);
    v7Stage.setInputEnabled(false);
    machine.advance(U4_STATE.INLINE_PLANET_FOCUS, generation);
    machine.advance(U4_STATE.GLOBE_PREWARM, generation);
    updateDebug();

    try {
      const readyPayload = await v7Stage.whenReady();
      if (disposed || !machine.isCurrentGeneration(generation) || !readyPayload) throw new Error('A kanonikus V7 Globe.gl nem készült el.');
      machine.advance(U4_STATE.HANDOFF_ALIGN, generation);
      // The Force canvas remains the visible veil. V7 resumes strictly under
      // opacity 0, receives the actual final U3 transform, then proves its
      // own projection before a single Globe frame can reach the user.
      v7Stage.resumeAnimation();
      const forceFrame = u3Stage.captureHandoffFrame();
      if (!forceFrame || forceFrame.landmarks.length < 3) {
        throw new Error('Az U3 inline bolygó nem adott elég valós landmarkot a handoffhoz.');
      }
      debug.appendSignal('u4.handoff.capture.force', {
        planetId: activePlanetId,
        center: forceFrame.center,
        radius: forceFrame.radius,
        landmarkCount: forceFrame.landmarks.length,
      });
      debug.appendSignal('u4.handoff.light.transfer', {
        planetId: activePlanetId,
        worldSunDirection: forceFrame.lightSnapshot?.worldSunDirection || null,
        keyColor: forceFrame.lightSnapshot?.keyColor || null,
        keyIntensity: forceFrame.lightSnapshot?.keyIntensity ?? null,
        fillIntensity: forceFrame.lightSnapshot?.fillIntensity ?? null,
        ambientIntensity: forceFrame.lightSnapshot?.ambientIntensity ?? null,
      });
      latestMatch = await prepareInvisibleGlobeMatch({ forceFrame, globeStage: v7Stage });
      if (disposed || !machine.isCurrentGeneration(generation)) return { claimed: false };
      const forceRenderProfile = forceFrame.renderProfile || u3Stage.captureRenderProfile();
      const globeRenderProfile = v7Stage.captureRenderProfile();
      debug.appendSignal('u4.handoff.render.profile', {
        parity: renderProfileParity(forceRenderProfile, globeRenderProfile),
        force: forceRenderProfile,
        globe: globeRenderProfile,
      });
      debug.appendSignal('u4.handoff.validate', {
        valid: latestMatch.valid,
        centerDeltaPx: latestMatch.match.centerDeltaPx,
        radiusDeltaPercent: latestMatch.match.radiusDeltaPercent,
        landmarkRmsDeltaPx: latestMatch.match.landmarkRmsDeltaPx,
        landmarkMaxDeltaPx: latestMatch.match.maxLandmarkDeltaPx,
        failures: latestMatch.match.failures,
        stableFrames: latestMatch.stableFrames,
        globeOffset: latestMatch.pose.globeOffset,
        labelsApplied: latestMatch.pose.labelsApplied === true,
        lightingApplied: latestMatch.pose.lightingApplied === true,
      });
      if (!latestMatch.valid) {
        throw new Error(`V7 match-cut elutasítva: ${latestMatch.match.failures.join(', ')}`);
      }
      // Last-frame lock: no Force camera, label or city-layout movement can
      // happen while the handoff veil still owns the only visible pixels.
      u3Stage.pauseAnimation();
      machine.advance(U4_STATE.HANDOFF_READY, generation);
      machine.advance(U4_STATE.HANDOFF_CROSSFADE, generation);
      updateDebug();
      await fade(HANDOFF_DURATION_MS, (progress) => {
        if (!disposed && machine.isCurrentGeneration(generation)) setStageOpacities(1 - progress, progress);
      });
      if (disposed || !machine.isCurrentGeneration(generation)) return { claimed: false };
      v7Stage.setInputEnabled(true);
      machine.advance(U4_STATE.GLOBE_STANDALONE, generation);
      depth.advance(U4_DEPTH_STATE.PLANET_IDLE, depthGeneration);
      applyDepthInputOwnership();
      scheduleStandaloneLabelLod(generation);
      debug.appendSignal('u4.handoff.complete', {
        planetId: activePlanetId,
        source: 'Universe V3 ForceGraph',
        target: 'Universe V7 Globe.gl',
      });
      updateDebug();
      return { claimed: true };
    } catch (error) {
      if (machine.isCurrentGeneration(generation)) machine.fail(generation);
      setStageOpacities(1, 0);
      u3Stage.resumeAnimation();
      u3Stage.setInputEnabled(true);
      v7Stage.setInputEnabled(false);
      v7Stage.pauseAnimation();
      depth.fail(depthGeneration);
      depth.advance(U4_DEPTH_STATE.GALAXY, depthGeneration);
      latestMatch = null;
      debug.appendSignal('u4.handoff.error', { message: error instanceof Error ? error.message : String(error) });
      helpers.showToast?.('A V7 illesztése nem érte el a match-cut tűrést — az U3 ForceGraph aktív maradt.');
      if (machine.state === U4_STATE.TRANSITION_ERROR) machine.advance(U4_STATE.GALAXY_IDLE, generation);
      activePlanetId = null;
      updateDebug();
      return { claimed: false };
    } finally {
      handoffInFlight = false;
    }
  }

  function restoreV7AfterResetFailure(generation, reason) {
    setStageOpacities(0, 1);
    u3Stage.pauseAnimation();
    u3Stage.setInputEnabled(false);
    v7Stage.resumeAnimation();
    v7Stage.setInputEnabled(true);
    if (machine.isCurrentGeneration(generation) && machine.state !== U4_STATE.GLOBE_STANDALONE) {
      machine.advance(U4_STATE.GLOBE_STANDALONE, generation);
    }
    debug.appendSignal('u4.reset.error', { reason, planetId: activePlanetId, state: machine.state });
    updateDebug();
  }

  async function resetToForceGalaxy() {
    if (disposed || handoffInFlight || machine.state !== U4_STATE.GLOBE_STANDALONE || ![
      U4_DEPTH_STATE.PLANET_IDLE,
      U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
      U4_DEPTH_STATE.PLANET_RETURNED,
    ].includes(depth.state)) return false;
    handoffInFlight = true;
    if (handoffLabelReleaseTimer) {
      window.clearTimeout(handoffLabelReleaseTimer);
      handoffLabelReleaseTimer = 0;
    }
    const generation = machine.begin(U4_STATE.RETURN_PREPARE);
    if (!generation) {
      handoffInFlight = false;
      return false;
    }
    try {
      v7Stage.setInputEnabled(false);
      u3Stage.setInputEnabled(false);
      if (!machine.advance(U4_STATE.RETURN_ALIGN, generation)) throw new Error('reset-align-transition-rejected');
      // Reset is deliberately not a reverse camera handoff. The hidden U3
      // renderer returns via its own reliable Galaxy route while the last
      // visible V7 frame remains on top; only the finished galaxy baseline is
      // faded in, so a user orbit can never leave the handoff stuck.
      const restored = await u3Stage.resetToGalaxyOverview();
      if (!restored || disposed || !machine.isCurrentGeneration(generation)) {
        restoreV7AfterResetFailure(generation, 'u3-galaxy-reset-unavailable');
        return false;
      }
      if (!machine.advance(U4_STATE.RETURN_CROSSFADE, generation)) throw new Error('reset-crossfade-transition-rejected');
      debug.appendSignal('u4.reset.begin', { planetId: activePlanetId, generation });
      updateDebug();
      await fade(HANDOFF_DURATION_MS, (progress) => {
        if (!disposed && machine.isCurrentGeneration(generation)) setStageOpacities(progress, 1 - progress);
      });
      if (disposed || !machine.isCurrentGeneration(generation)) return false;
      v7Stage.pauseAnimation();
      u3Stage.setInputEnabled(true);
      if (!machine.advance(U4_STATE.INLINE_PLANET_RETURN, generation)) throw new Error('reset-complete-transition-rejected');
      if (!machine.advance(U4_STATE.GALAXY_IDLE, generation)) throw new Error('reset-galaxy-transition-rejected');
      debug.appendSignal('u4.reset.complete', {
        planetId: activePlanetId,
        source: 'Universe V7 Globe.gl',
        target: 'Universe V3 ForceGraph galaxy baseline',
      });
      activePlanetId = null;
      latestMatch = null;
      depthGeneration = depth.begin(U4_DEPTH_STATE.GALAXY) || depthGeneration;
      applyDepthInputOwnership();
      updateDebug();
      return true;
    } catch (error) {
      if (!disposed && machine.isCurrentGeneration(generation)) {
        restoreV7AfterResetFailure(generation, error instanceof Error ? error.message : String(error));
      }
      return false;
    } finally {
      handoffInFlight = false;
    }
  }

  function resizeStages() {
    u3Stage.resize();
    v7Stage.resize();
    updateDebug();
  }

  function syncFullscreenState() {
    const active = document.fullscreenElement === stageShell || fullscreenFallbackActive;
    stageShell.classList.toggle('is-universe4-fullscreen-fallback', fullscreenFallbackActive && !document.fullscreenElement);
    fullscreenButton?.classList.toggle('is-active', active);
    fullscreenButton?.setAttribute('aria-pressed', String(active));
    window.requestAnimationFrame(resizeStages);
  }

  async function toggleFullscreen() {
    if (document.fullscreenElement === stageShell) {
      await document.exitFullscreen?.();
      return;
    }
    if (fullscreenFallbackActive) {
      fullscreenFallbackActive = false;
      syncFullscreenState();
      return;
    }
    try {
      await stageShell.requestFullscreen?.({ navigationUI: 'hide' });
    } catch {
      fullscreenFallbackActive = true;
      syncFullscreenState();
    }
  }

  function onProof(proof) {
    if (proof === 'force-only') {
      v7Stage.pauseAnimation();
      u3Stage.resumeAnimation();
      setStageOpacities(1, 0);
    }
    if (proof === 'globe-only' && v7Stage.isReady) {
      u3Stage.pauseAnimation();
      v7Stage.resumeAnimation();
      setStageOpacities(0, 1);
    }
    if (proof === 'automatic-handoff') helpers.showToast?.('Koppints egy Universe V3 bolygóra: az U3 saját morphja indítja a V7 handoffot.');
    if (proof === 'reset') requestReset('debug-control');
    updateDebug();
  }

  function requestReset(source) {
    const now = performance.now();
    if (now - lastResetRequestAt < 420) return;
    lastResetRequestAt = now;
    debug.appendSignal('u4.reset.request', {
      source,
      state: machine.state,
      handoffInFlight,
      forceOpacity,
      globeOpacity,
      planetId: activePlanetId,
      depthState: depth.state,
    });
    if (depth.state === U4_DEPTH_STATE.MAP_ACTIVE) void returnFocusedMapToPlanet();
    else void resetToForceGalaxy();
  }

  function onResetPointerUp(event) {
    event.preventDefault();
    event.stopPropagation();
    requestReset('stage-pointerup');
  }

  function onResetClick(event) {
    event.preventDefault();
    event.stopPropagation();
    requestReset('stage-click');
  }

  const resizeObserver = new ResizeObserver(resizeStages);
  resizeObserver.observe(viewport);
  fullscreenButton?.addEventListener('click', toggleFullscreen);
  resetButton?.addEventListener('pointerup', onResetPointerUp);
  resetButton?.addEventListener('click', onResetClick);
  forceBackgroundSelect?.addEventListener('change', onForceBackgroundChange);
  globeBackgroundSelect?.addEventListener('change', onGlobeBackgroundChange);
  document.addEventListener('fullscreenchange', syncFullscreenState);
  v7Stage.setOpacity(0);
  v7Stage.setInputEnabled(false);
  u3Stage.setOpacity(1);
  g6Stage.setOpacity(0);
  g6Stage.setInputEnabled(false);
  morphPatch.setOpacity(0);
  applyRendererBackground('force', forceBackgroundSelect?.value);
  applyRendererBackground('globe', globeBackgroundSelect?.value);
  updateDebug();

  return () => {
    disposed = true;
    if (handoffLabelReleaseTimer) window.clearTimeout(handoffLabelReleaseTimer);
    if (focusedMapSettleTimer) window.clearTimeout(focusedMapSettleTimer);
    machine.dispose();
    resizeObserver.disconnect();
    fullscreenButton?.removeEventListener('click', toggleFullscreen);
    resetButton?.removeEventListener('pointerup', onResetPointerUp);
    resetButton?.removeEventListener('click', onResetClick);
    forceBackgroundSelect?.removeEventListener('change', onForceBackgroundChange);
    globeBackgroundSelect?.removeEventListener('change', onGlobeBackgroundChange);
    document.removeEventListener('fullscreenchange', syncFullscreenState);
    if (document.fullscreenElement === stageShell) void document.exitFullscreen?.();
    debug.dispose();
    morphPatch.dispose();
    g6Stage.dispose();
    v7Stage.dispose();
    u3Stage.dispose();
  };
}
