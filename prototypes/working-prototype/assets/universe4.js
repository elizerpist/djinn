import { createUniverse4TransitionMachine, U4_STATE } from './universe4/universe4-transition-machine.js?rev=2';
import { createUniverse4U3Stage } from './universe4/universe4-u3-stage.js?rev=14';
import { createUniverse4V7SourceStage } from './universe4/universe4-v7-source-stage.js?rev=10';
import { prepareInvisibleGlobeMatch } from './universe4/universe4-handoff-matcher.js?rev=1';
import { resolveUniverse4Background } from './universe4/universe4-background.js?rev=1';
import { mountUniverse4DebugPanel } from './universe4/universe4-debug-panel.js?rev=3';

const HANDOFF_DURATION_MS = 240;

export const getUniverse4PointerOwner = (state) => {
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

// U4 is explicitly a renderer handoff prototype: its entry is the production
// U3 ForceGraph controller and its destination is the production Explore V7
// controller mounted in a second, overlapping stage. Neither endpoint is
// recreated in this file.
export function initUniverse4(root, helpers = {}) {
  const stageShell = root.querySelector('[data-universe4-stage-shell]');
  const viewport = root.querySelector('[data-universe4-viewport]');
  const u3Mount = root.querySelector('[data-universe4-force-stage]');
  const v7Mount = root.querySelector('[data-universe4-globe-stage]');
  const v7DebugPortal = root.querySelector('[data-universe4-v7-debug-portal]');
  const debugHost = root.querySelector('[data-universe4-debug]');
  const fullscreenButton = root.querySelector('[data-universe4-fullscreen]');
  const resetButton = root.querySelector('[data-universe4-reset]');
  const forceBackgroundSelect = root.querySelector('[data-universe4-force-background]');
  const globeBackgroundSelect = root.querySelector('[data-universe4-globe-background]');
  if (!stageShell || !viewport || !u3Mount || !v7Mount) return () => {};

  const machine = createUniverse4TransitionMachine();
  let disposed = false;
  let handoffInFlight = false;
  let activePlanetId = null;
  let forceOpacity = 1;
  let globeOpacity = 0;
  let fullscreenFallbackActive = false;
  let lastResetRequestAt = -Infinity;
  let latestMatch = null;
  let handoffLabelReleaseTimer = 0;

  const debug = mountUniverse4DebugPanel({ host: debugHost, viewport, onProof });
  const v7Stage = createUniverse4V7SourceStage({
    mount: v7Mount,
    debugPortal: v7DebugPortal,
    onReady: () => {
      // `initExpandableGalaxyOrb` may invoke onGlobeReady synchronously while
      // createUniverse4V7SourceStage is still constructing the const below.
      // Deferring prevents updateDebug from reading v7Stage in its temporal
      // dead zone and, crucially, lets the canonical V7 factory finish its
      // ResizeObserver/edge setup without being caught as a globe error.
      queueMicrotask(() => {
        if (disposed) return;
        debug.appendSignal('v7.source.ready', { source: 'initExpandableGalaxyOrb', variant: 'v7' });
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

  function updateDebug() {
    const matchRejected = Boolean(latestMatch && !latestMatch.valid);
    // A healthy U4 endpoint stays visually identical to the bare V7 source.
    // On a rejected hidden calibration, however, the user needs the exact
    // measured center/radius/landmark deltas rather than a wrong Globe frame.
    stageShell.classList.toggle('is-u4-match-diagnostics', matchRejected);
    debug.update({
      state: machine.state,
      generation: machine.generation,
      planetId: activePlanetId,
      pointerOwner: getUniverse4PointerOwner(machine.state),
      forceOpacity,
      globeOpacity,
      globeReady: v7Stage.isReady,
      globeFrames: latestMatch?.stableFrames || 0,
      forcePaused: machine.state === U4_STATE.GLOBE_STANDALONE,
      pixelMatch: latestMatch?.match || { valid: false, failures: ['awaiting-hidden-calibration'] },
      globeOffset: latestMatch?.pose?.globeOffset || null,
      crossfadeProgress: globeOpacity,
      forceCamera: latestMatch?.forceFrame?.cameraPosition
        ? `${latestMatch.forceFrame.cameraPosition.x.toFixed(1)}, ${latestMatch.forceFrame.cameraPosition.y.toFixed(1)}, ${latestMatch.forceFrame.cameraPosition.z.toFixed(1)}`
        : (machine.state === U4_STATE.GALAXY_IDLE ? 'Universe V3 owns camera' : 'awaiting U3 frame capture'),
      globePov: latestMatch?.pose?.pointOfView
        ? `${latestMatch.pose.pointOfView.lat.toFixed(2)}° / ${latestMatch.pose.pointOfView.lng.toFixed(2)}° / ${latestMatch.pose.pointOfView.altitude.toFixed(3)}`
        : (v7Stage.globe?.pointOfView ? 'Explore V7 prewarming' : 'Explore V7 unavailable'),
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

  async function handoffToCanonicalV7({ nodeId } = {}) {
    if (disposed || handoffInFlight || machine.state !== U4_STATE.GALAXY_IDLE) return { claimed: false };
    handoffInFlight = true;
    activePlanetId = nodeId || 'selected-planet';
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
      scheduleStandaloneLabelLod(generation);
      debug.appendSignal('u4.handoff.complete', {
        planetId: activePlanetId,
        source: 'Universe V3 ForceGraph',
        target: 'Explore V7 Globe.gl',
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
    if (disposed || handoffInFlight || machine.state !== U4_STATE.GLOBE_STANDALONE) return false;
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
        source: 'Explore V7 Globe.gl',
        target: 'Universe V3 ForceGraph galaxy baseline',
      });
      activePlanetId = null;
      latestMatch = null;
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
    });
    void resetToForceGalaxy();
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
  applyRendererBackground('force', forceBackgroundSelect?.value);
  applyRendererBackground('globe', globeBackgroundSelect?.value);
  updateDebug();

  return () => {
    disposed = true;
    if (handoffLabelReleaseTimer) window.clearTimeout(handoffLabelReleaseTimer);
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
    v7Stage.dispose();
    u3Stage.dispose();
  };
}
