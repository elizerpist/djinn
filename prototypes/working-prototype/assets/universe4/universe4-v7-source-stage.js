// Universe 4 deliberately mounts the *same* Explore controller that owns V7.
// It does not recreate the 700-city layout, lights, cosmic field, labels,
// gold paths or gesture router.  This is a live embedded Explore V7 instance.
import { initExpandableGalaxyOrb } from '../explore-galaxy-orb.js?rev=226';
import {
  mapForceCameraSnapshotToGlobePov,
  solveAltitudeForCssRadius,
} from './universe4-camera-mapper.js?rev=3';

const finite = (value) => Number.isFinite(value);
const vectorRecord = (vector) => ({ x: vector.x, y: vector.y, z: vector.z });

function projectWorldToCss(point, camera, viewport) {
  const projected = point.clone().project(camera);
  return {
    x: (projected.x * .5 + .5) * viewport.width,
    y: (-projected.y * .5 + .5) * viewport.height,
    ndcZ: projected.z,
  };
}

export function createUniverse4V7SourceStage({ mount, debugPortal = null, onReady } = {}) {
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
    onGlobeReady: (payload) => {
      if (disposed || ready) return;
      ready = true;
      resolveReady(payload);
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

  function setInputEnabled(enabled) {
    // `pointer-events` is inherited, but the canonical Explore controller
    // deliberately gives its canvas, labels and controls explicit `auto`
    // values. Toggling only the mount would therefore still let the hidden
    // V7 canvas consume taps intended for the U3 ForceGraph below it.
    host.classList.toggle('is-u4-input-disabled', !enabled);
    mount.style.pointerEvents = enabled ? 'auto' : 'none';
    mount.setAttribute('aria-hidden', String(!enabled));
  }

  function setBackgroundColor(color) {
    if (disposed) return false;
    return controller.setEmbeddedBackgroundColor?.(color) === true;
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
    pauseAnimation,
    resumeAnimation,
    waitForRenderedFrames,
    captureHandoffFrame,
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
