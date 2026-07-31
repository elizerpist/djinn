// Universe 4 deliberately mounts the *same* Explore controller that owns V7.
// It does not recreate the 700-city layout, lights, cosmic field, labels,
// gold paths or gesture router.  This is a live embedded Explore V7 instance.
import { initExpandableGalaxyOrb } from '../explore-galaxy-orb.js?rev=239';
import {
  mapForceCameraSnapshotToGlobePov,
  solveAltitudeForCssRadius,
} from './universe4-camera-mapper.js?rev=3';

const finite = (value) => Number.isFinite(value);
const vectorRecord = (vector) => ({ x: vector.x, y: vector.y, z: vector.z });
const numberOrNull = (value) => Number.isFinite(value) ? value : null;
const colorHex = (color) => color?.getHexString?.() ? `#${color.getHexString()}` : null;

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

function captureRendererRenderProfile(renderer, material) {
  const clearColor = material?.color?.clone?.() || null;
  try {
    if (clearColor) renderer?.getClearColor?.(clearColor);
  } catch {
    // Renderer diagnostics are optional and must never make the V7 source
    // stage ineligible for the real handoff.
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

function projectWorldToCss(point, camera, viewport) {
  const projected = point.clone().project(camera);
  return {
    x: (projected.x * .5 + .5) * viewport.width,
    y: (-projected.y * .5 + .5) * viewport.height,
    ndcZ: projected.z,
  };
}

export function createUniverse4V7SourceStage({
  mount,
  debugPortal = null,
  onReady,
  onCityTap = null,
  onSelectionTransition = null,
  onCityVisualRole = null,
  onInputDiagnostic = null,
} = {}) {
  if (!mount) throw new Error('Universe 4 V7 source stage mount kötelező.');

  const host = document.createElement('div');
  host.className = 'universe4-v7-source-root';
  host.setAttribute('aria-label', 'Explore V7 Globe.gl bolygó');
  mount.replaceChildren(host);

  let disposed = false;
  let ready = false;
  let animationPaused = false;
  let prewarmPauseFrame = 0;
  let resolveReady;
  const readyPromise = new Promise((resolve) => { resolveReady = resolve; });
  // `initExpandableGalaxyOrb` only requires a truthy nav host. U4 keeps its
  // own route and never dispatches an Explore navigation event.
  const controller = initExpandableGalaxyOrb({
    root: host,
    nav: document.createElement('div'),
    initialVariant: 'v7',
    embeddedViewport: mount,
    embeddedBarePlanet: true,
    embeddedDebugPortal: debugPortal,
    onV5CityTap: onCityTap,
    onV5SelectionTransition: onSelectionTransition,
    onV5CityVisualRole: onCityVisualRole,
    onGlobeReady: (payload) => {
      if (disposed || ready) return;
      ready = true;
      resolveReady(payload);
      // The canonical factory can invoke this callback before its own factory
      // returns the controller object. Defer diagnostics until that nullable
      // binding is initialized, just like the U4 onReady seam does.
      queueMicrotask(() => {
        if (!disposed) emitInputDiagnostic('u4.controls.source-ready', { reason: 'canonical-v7-ready' });
      });
      onReady?.(payload);
    },
  });

  // Make the canonical source controller visible *inside this stage*.  It is
  // not a route change: the U4 Globe canvas stays over the U4 Force canvas.
  controller.setRoute('explore');

  function pauseAnimation() {
    if (disposed || animationPaused) return;
    controller.getGlobe?.()?.pauseAnimation?.();
    animationPaused = true;
  }

  function resumeAnimation() {
    if (disposed || !animationPaused) return;
    controller.getGlobe?.()?.resumeAnimation?.();
    animationPaused = false;
  }

  function waitForRenderedFrames(frameCount = 1) {
    const targetFrames = Math.max(1, Math.floor(Number(frameCount) || 1));
    return new Promise((resolve) => {
      let renderedFrames = 0;
      const nextFrame = () => {
        if (disposed) return resolve(renderedFrames);
        renderedFrames += 1;
        if (renderedFrames >= targetFrames) return resolve(renderedFrames);
        window.requestAnimationFrame(nextFrame);
      };
      window.requestAnimationFrame(nextFrame);
    });
  }

  // Let the canonical V7 controller finish construction and render one full
  // frame, then stop it while U3 owns the visible interaction. This prevents
  // two continuous WebGL loops from competing during the entire ForceGraph
  // portion of the U4 flow.
  prewarmPauseFrame = window.requestAnimationFrame(() => {
    prewarmPauseFrame = 0;
    pauseAnimation();
  });

  function setOpacity(opacity) {
    mount.style.opacity = String(Math.max(0, Math.min(1, Number(opacity) || 0)));
  }

  function getInputDiagnostics() {
    const controllerDiagnostics = controller.getGlobeControlsDiagnostics?.() || null;
    return {
      source: 'universe4-v7-source-stage',
      inputEnabled: mount.style.pointerEvents !== 'none',
      mountPointerEvents: mount.style.pointerEvents || null,
      mountAriaHidden: mount.getAttribute('aria-hidden'),
      hostClasses: host.className,
      hostPointerEvents: host.style.pointerEvents || null,
      controller: controllerDiagnostics,
    };
  }

  function emitInputDiagnostic(event, extra = {}) {
    const diagnostics = { ...getInputDiagnostics(), ...extra };
    controller.recordEmbeddedSignal?.(event, diagnostics);
    onInputDiagnostic?.(event, diagnostics);
  }

  function recordEmbeddedSignal(event, payload = {}) {
    controller.recordEmbeddedSignal?.(event, payload);
  }

  function setInputEnabled(enabled) {
    // `pointer-events` is inherited, but the canonical Explore controller
    // deliberately gives its canvas, labels and controls explicit `auto`
    // values. Toggling only the mount would therefore still let the hidden
    // V7 canvas consume taps intended for the U3 ForceGraph below it.
    host.classList.toggle('is-u4-input-disabled', !enabled);
    mount.style.pointerEvents = enabled ? 'auto' : 'none';
    mount.setAttribute('aria-hidden', String(!enabled));
    emitInputDiagnostic('u4.input.owner', {
      requestedEnabled: Boolean(enabled),
      reason: 'set-input-enabled',
    });
  }

  function setBackgroundColor(color) {
    if (disposed) return false;
    return controller.setEmbeddedBackgroundColor?.(color) === true;
  }

  function focusCityForMap(cityId, { durationMs = 520, zoomFactor = .58 } = {}) {
    const globe = controller.getGlobe?.();
    const city = controller.getV5City?.(cityId);
    if (disposed || !globe?.pointOfView || !city || !Number.isFinite(city.lat) || !Number.isFinite(city.lng)) return null;
    const current = globe.pointOfView?.() || {};
    const altitude = Math.max(.38, Math.min(2.9, (Number(current.altitude) || 1.2) * zoomFactor));
    const pointOfView = { lat: city.lat, lng: city.lng, altitude };
    globe.pointOfView(pointOfView, durationMs);
    return pointOfView;
  }

  function setPointOfView(pointOfView, durationMs = 0) {
    const globe = controller.getGlobe?.();
    if (disposed || !globe?.pointOfView || !pointOfView) return false;
    globe.pointOfView(pointOfView, durationMs);
    return true;
  }

  function captureRenderProfile() {
    const globe = controller.getGlobe?.();
    if (disposed || !globe?.scene || !globe?.renderer) return null;
    const scene = globe.scene();
    scene?.updateMatrixWorld?.(true);
    const material = globe.globeMaterial?.();
    return Object.freeze({
      material: captureMaterialRenderProfile(material),
      renderer: captureRendererRenderProfile(globe.renderer?.(), material),
      sceneLights: captureSceneLightProfile(scene),
    });
  }

  function captureHandoffFrame({ landmarks = [] } = {}) {
    const globe = controller.getGlobe?.();
    if (disposed || !globe?.camera || !globe?.controls) return null;
    const camera = globe.camera();
    const controls = globe.controls();
    const viewport = { width: mount.clientWidth, height: mount.clientHeight };
    if (viewport.width <= 0 || viewport.height <= 0) return null;
    camera.updateMatrixWorld(true);
    globe.scene?.().updateMatrixWorld?.(true);
    const centerWorld = controls.target.clone();
    const center = projectWorldToCss(centerWorld, camera, viewport);
    const radiusWorld = Math.max(.001, globe.getGlobeRadius?.() || 100);
    const cameraDirection = camera.position.clone().sub(centerWorld).normalize();
    const horizontal = camera.up.clone().cross(cameraDirection).normalize();
    if (horizontal.lengthSq() < 1e-8) horizontal.set(1, 0, 0);
    const vertical = cameraDirection.clone().cross(horizontal).normalize();
    const radius = Math.max(
      ...[horizontal, horizontal.clone().negate(), vertical, vertical.clone().negate()]
        .map((axis) => {
          const edge = projectWorldToCss(centerWorld.clone().addScaledVector(axis, radiusWorld), camera, viewport);
          return Math.hypot(edge.x - center.x, edge.y - center.y);
        }),
    );
    const landmarkPoints = (Array.isArray(landmarks) ? landmarks : []).map((landmark) => {
      const point = globe.getScreenCoords?.(landmark.lat, landmark.lng, landmark.altitude ?? .012);
      return point && finite(point.x) && finite(point.y)
        ? { id: landmark.id, x: point.x, y: point.y }
        : { id: landmark.id, x: Infinity, y: Infinity };
    });
    return {
      viewport,
      cameraPosition: vectorRecord(camera.position),
      cameraQuaternion: { x: camera.quaternion.x, y: camera.quaternion.y, z: camera.quaternion.z, w: camera.quaternion.w },
      cameraUp: vectorRecord(camera.up),
      fov: camera.fov,
      aspect: camera.aspect,
      near: camera.near,
      far: camera.far,
      controlsTarget: vectorRecord(controls.target),
      globeRadius: radiusWorld,
      pointOfView: globe.pointOfView?.(),
      center: { x: center.x, y: center.y },
      radius,
      landmarks: landmarkPoints,
    };
  }

  // Applies a Force-originated pose while this live canonical V7 renderer is
  // still invisible. Size is solved against V7's own projection, never by
  // copying the raw Force distance into Globe.gl altitude.
  function applyHandoffPose(forceFrame) {
    const globe = controller.getGlobe?.();
    if (disposed || !globe?.pointOfView || !forceFrame) return null;
    const camera = globe.camera();
    const controls = globe.controls();
    const labelsApplied = controller.setEmbeddedHandoffLabelSnapshot?.(forceFrame.landmarks) === true;
    if (!labelsApplied) return null;
    const lightingApplied = forceFrame.lightSnapshot
      ? controller.applyEmbeddedHandoffLighting?.(forceFrame.lightSnapshot)
      : true;
    if (!lightingApplied) return null;
    const radius = globe.getGlobeRadius?.() || 100;
    const mapping = mapForceCameraSnapshotToGlobePov({
      forceCameraSnapshot: forceFrame,
      globeRadius: radius,
      toGeoCoords: (position) => globe.toGeoCoords(position),
    });
    if (finite(forceFrame.fov)) camera.fov = forceFrame.fov;
    if (finite(forceFrame.aspect)) camera.aspect = forceFrame.aspect;
    if (finite(forceFrame.near)) camera.near = forceFrame.near;
    if (finite(forceFrame.far)) camera.far = forceFrame.far;
    camera.updateProjectionMatrix();
    controls.target.set(0, 0, 0);
    globe.globeOffset?.([0, 0]);
    globe.pointOfView(mapping.pointOfView, 0);
    controls.update?.();

    const targetRadius = forceFrame.radius;
    const altitudeFloor = .02;
    const altitudeCeiling = Math.max(6, mapping.pointOfView.altitude * 3, 3);
    const solved = solveAltitudeForCssRadius({
      targetRadius,
      minAltitude: altitudeFloor,
      maxAltitude: altitudeCeiling,
      iterations: 16,
      measureRadius: (altitude) => {
        globe.pointOfView({ ...mapping.pointOfView, altitude }, 0);
        controls.update?.();
        return captureHandoffFrame({ landmarks: forceFrame.landmarks })?.radius || 0;
      },
    });
    const pointOfView = { ...mapping.pointOfView, altitude: solved.altitude };
    globe.pointOfView(pointOfView, 0);
    controls.update?.();

    let offset = [0, 0];
    for (let attempt = 0; attempt < 4; attempt += 1) {
      const current = captureHandoffFrame({ landmarks: forceFrame.landmarks });
      if (!current) break;
      const deltaX = forceFrame.center.x - current.center.x;
      const deltaY = forceFrame.center.y - current.center.y;
      if (Math.hypot(deltaX, deltaY) <= .25) break;
      globe.globeOffset?.([offset[0] + 1, offset[1]]);
      const xProbe = captureHandoffFrame({ landmarks: forceFrame.landmarks });
      globe.globeOffset?.([offset[0], offset[1] + 1]);
      const yProbe = captureHandoffFrame({ landmarks: forceFrame.landmarks });
      const responseX = (xProbe?.center.x ?? current.center.x) - current.center.x;
      const responseY = (yProbe?.center.y ?? current.center.y) - current.center.y;
      offset = [
        offset[0] + deltaX / (Math.abs(responseX) > 1e-4 ? responseX : 1),
        offset[1] + deltaY / (Math.abs(responseY) > 1e-4 ? responseY : 1),
      ];
      globe.globeOffset?.(offset);
    }

    return {
      mapping,
      pointOfView,
      globeOffset: offset,
      labelsApplied,
      lightingApplied,
      radiusSolver: solved,
      frame: captureHandoffFrame({ landmarks: forceFrame.landmarks }),
    };
  }

  return {
    get isReady() { return ready; },
    get isAnimationPaused() { return animationPaused; },
    get controller() { return controller; },
    get globe() { return controller.getGlobe?.() || null; },
    whenReady: () => readyPromise,
    setOpacity,
    setInputEnabled,
    setBackgroundColor,
    focusCityForMap,
    setPointOfView,
    getInputDiagnostics,
    recordEmbeddedSignal,
    getCity: (cityId) => controller.getV5City?.(cityId) || null,
    getCityAnchor: (cityId) => controller.getV5CityAnchor?.(cityId) || null,
    getSelection: () => controller.getV5SelectionState?.() || null,
    pauseAnimation,
    resumeAnimation,
    waitForRenderedFrames,
    captureHandoffFrame,
    captureRenderProfile,
    applyHandoffPose,
    releaseHandoffLabels() {
      return controller.clearEmbeddedHandoffLabelSnapshot?.() === true;
    },
    resize() {
      // The canonical controller owns its own ResizeObserver. Dispatching a
      // resize event keeps that code path unchanged when U4 enters fullscreen.
      window.dispatchEvent(new Event('resize'));
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      if (prewarmPauseFrame) window.cancelAnimationFrame(prewarmPauseFrame);
      resolveReady?.(null);
      controller.destroy?.();
      host.remove();
    },
  };
}
