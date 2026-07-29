import * as THREE from '../vendor/three.module.min.js?rev=92';
import { getV5PlanetVisualSnapshot } from '../explore/planet-data.js?rev=4';

let forceGraphPromise;
let threeGlobePromise;

function loadForceGraph3D() {
  if (window.ForceGraph3D) return Promise.resolve(window.ForceGraph3D);
  if (forceGraphPromise) return forceGraphPromise;
  forceGraphPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.async = true;
    script.src = new URL('../vendor/3d-force-graph.min.js?rev=1', import.meta.url).href;
    script.addEventListener('load', () => window.ForceGraph3D
      ? resolve(window.ForceGraph3D)
      : reject(new Error('Universe 4: ForceGraph3D global export hiányzik.')), { once: true });
    script.addEventListener('error', () => reject(new Error('Universe 4: Force Graph vendor nem tölthető be.')), { once: true });
    document.head.append(script);
  });
  return forceGraphPromise;
}

// This is the same inline ThreeGlobe vendor used by Universe 3. U4 keeps it
// inside the ForceGraph node until the renderer handoff is actually ready.
function loadThreeGlobe() {
  if (window.ThreeGlobe) return Promise.resolve(window.ThreeGlobe);
  if (threeGlobePromise) return threeGlobePromise;
  threeGlobePromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.async = true;
    script.src = new URL('../vendor/three-globe.min.js?rev=3', import.meta.url).href;
    script.addEventListener('load', () => window.ThreeGlobe
      ? resolve(window.ThreeGlobe)
      : reject(new Error('Universe 4: ThreeGlobe global export hiányzik.')), { once: true });
    script.addEventListener('error', () => reject(new Error('Universe 4: ThreeGlobe vendor nem tölthető be.')), { once: true });
    document.head.append(script);
  });
  return threeGlobePromise;
}

function latLngToVector(lat, lng, radius, altitude = 0) {
  const phi = THREE.MathUtils.degToRad(90 - Number(lat || 0));
  const theta = THREE.MathUtils.degToRad(Number(lng || 0) + 180);
  const r = radius * (1 + Number(altitude || 0));
  return new THREE.Vector3(
    -r * Math.sin(phi) * Math.cos(theta),
    r * Math.cos(phi),
    r * Math.sin(phi) * Math.sin(theta),
  );
}

function opacityOf(material, opacity) {
  if (!material) return;
  material.transparent = opacity < .995;
  material.opacity = opacity;
  material.depthWrite = opacity > .12;
  material.needsUpdate = true;
}

function projectMetrics({ camera, root, radius, viewport }) {
  const center = root.getWorldPosition(new THREE.Vector3()).project(camera);
  const edge = root.localToWorld(new THREE.Vector3(radius, 0, 0)).project(camera);
  const width = Math.max(1, viewport.width);
  const height = Math.max(1, viewport.height);
  const centerPx = { x: (center.x * .5 + .5) * width, y: (-center.y * .5 + .5) * height };
  const edgePx = { x: (edge.x * .5 + .5) * width, y: (-edge.y * .5 + .5) * height };
  return { center: centerPx, radius: Math.hypot(edgePx.x - centerPx.x, edgePx.y - centerPx.y) };
}

function snapshotGalaxy(snapshot) {
  const galaxy = snapshot?.galaxy || { nodes: [], links: [] };
  // The snapshot itself must stay immutable. ForceGraph owns this separate,
  // mutable simulation copy and never writes positions back to the snapshot.
  return {
    nodes: (galaxy.nodes || []).map((node) => ({ ...node })),
    links: (galaxy.links || []).map((link) => ({ ...link })),
  };
}

function snapshotAtoms(snapshot) {
  // Universe 3's inline detailed planet already uses this exact immutable
  // V5/V7 city layout. Keep U4's Force entry on that source rather than
  // constructing a second generic atom cloud.
  return snapshot?.planet?.atoms || snapshot?.atoms || getV5PlanetVisualSnapshot().atoms;
}

function snapshotArcs(snapshot) {
  return snapshot?.planet?.surfaceArcs || snapshot?.planet?.arcs || snapshot?.surfaceArcs || [];
}

export function createUniverse4ForceStage({ mount, onPlanetSelect, background = '#071027' }) {
  if (!mount) throw new Error('Universe 4 Force stage mount kötelező.');

  let graph = null;
  let snapshot = null;
  let selectedPlanetId = null;
  let paused = false;
  let disposed = false;
  let inputEnabled = true;
  let frozenNodes = null;
  let liveGalaxy = null;
  let ThreeGlobe = null;
  const planetRoots = new Map();
  const nodeMaterials = new Map();
  const selectedRadius = 13;
  const viewport = () => ({ width: mount.clientWidth || 1, height: mount.clientHeight || 1 });
  const syncPointerEvents = () => {
    const opacity = Number(mount.style.opacity || 1);
    mount.style.pointerEvents = inputEnabled && opacity > .99 ? 'auto' : 'none';
  };

  function createPlanetRoot(node) {
    const root = new THREE.Group();
    root.name = `u4-inline-planet:${node.id}`;
    const baseRadius = node.isPlanet ? selectedRadius : 3.2;
    // U3 hydrates exactly one selected planet into a detailed ThreeGlobe.
    // Keeping the other ForceGraph planets as light overview meshes prevents
    // eight hidden 700-city render trees from consuming mobile GPU time.
    if (node.isPlanet && ThreeGlobe && node.id === selectedPlanetId) {
      // Exact U3 body contract: an actual ThreeGlobe child, using the same
      // solid violet MeshStandardMaterial and globe radius conversion.
      const inlineGlobe = new ThreeGlobe({ animateIn: false, waitForGlobeReady: false })
        .showGlobe(true)
        .showAtmosphere(false)
        .atmosphereColor('#8AF2FF')
        .atmosphereAltitude(.06)
        .globeImageUrl(null);
      const bodyMaterial = new THREE.MeshStandardMaterial({
        color: 0x241451,
        roughness: .54,
        metalness: .05,
        emissive: 0x0d3156,
        emissiveIntensity: .28,
        transparent: false,
        opacity: 1,
        depthWrite: true,
      });
      inlineGlobe.globeMaterial(bodyMaterial);
      inlineGlobe.scale.setScalar((baseRadius / (inlineGlobe.getGlobeRadius?.() || 100)) * .92);
      inlineGlobe.name = `u4-u3-inline-threeglobe:${node.id}`;
      root.add(inlineGlobe);
      nodeMaterials.set(node.id, bodyMaterial);
      const atomGroup = new THREE.Group();
      atomGroup.name = `u4-u3-inline-v7-atoms:${node.id}`;
      const atomMaterial = new THREE.MeshBasicMaterial({ color: 0x73eaff, transparent: true, opacity: 0 });
      const atomGeometry = new THREE.SphereGeometry(1, 16, 12);
      snapshotAtoms(snapshot).forEach((atom) => {
        const marker = new THREE.Mesh(atomGeometry, atomMaterial.clone());
        const fromGlobe = inlineGlobe.getCoords?.(atom.lat, atom.lng, atom.altitude);
        marker.position.copy(fromGlobe || latLngToVector(atom.lat, atom.lng, inlineGlobe.getGlobeRadius?.() || 100, atom.altitude));
        marker.scale.setScalar(Number(atom.visualRadius || .32));
        marker.renderOrder = 3;
        marker.userData.atomId = atom.id;
        atomGroup.add(marker);
      });
      atomGroup.visible = false;
      inlineGlobe.add(atomGroup);

      const arcMaterial = new THREE.LineBasicMaterial({ color: 0xffd45a, transparent: true, opacity: 0 });
      const arcGroup = new THREE.Group();
      snapshotArcs(snapshot).slice(0, 16).forEach((arc) => {
        const radius = inlineGlobe.getGlobeRadius?.() || 100;
        const from = inlineGlobe.getCoords?.(arc.startLat, arc.startLng, .015) || latLngToVector(arc.startLat, arc.startLng, radius, .015);
        const to = inlineGlobe.getCoords?.(arc.endLat, arc.endLng, .015) || latLngToVector(arc.endLat, arc.endLng, radius, .015);
        const midpoint = from.clone().add(to).normalize().multiplyScalar(radius * 1.015);
        const curve = new THREE.QuadraticBezierCurve3(from, midpoint, to);
        arcGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(curve.getPoints(36)), arcMaterial.clone()));
      });
      arcGroup.visible = false;
      inlineGlobe.add(arcGroup);
      root.userData.detail = { bodyMaterial, inlineGlobe, atomGroup, arcGroup, baseRadius };
    } else {
      const bodyMaterial = new THREE.MeshStandardMaterial({
        color: node.isPlanet ? 0x241451 : 0x56428d,
        roughness: .56,
        metalness: .06,
        emissive: 0x0d3156,
        emissiveIntensity: .28,
        transparent: true,
        opacity: node.isPlanet ? .86 : .42,
      });
      const body = new THREE.Mesh(new THREE.SphereGeometry(baseRadius, 24, 18), bodyMaterial);
      body.name = `u4-inline-body:${node.id}`;
      root.add(body);
      nodeMaterials.set(node.id, bodyMaterial);
    }

    planetRoots.set(node.id, root);
    return root;
  }

  function hydrateSelectedU3Planet(root, planetId) {
    if (!root || root.userData.detail) return root;
    const node = liveGalaxy?.nodes?.find((candidate) => candidate.id === planetId);
    if (!node) return root;
    // Reuse the existing ForceGraph Object3D so its simulation position and
    // parent transform remain untouched; swap only its local visual content.
    const temporary = createPlanetRoot(node);
    root.children.slice().forEach((child) => {
      root.remove(child);
      child.traverse?.((object) => {
        object.geometry?.dispose?.();
        object.material?.dispose?.();
      });
    });
    temporary.children.slice().forEach((child) => root.add(child));
    root.userData = temporary.userData;
    planetRoots.set(planetId, root);
    return root;
  }

  function applySelectedVisuals(progress = 1) {
    planetRoots.forEach((root, nodeId) => {
      const isSelected = nodeId === selectedPlanetId;
      const isPlanet = root.userData.detail;
      const material = isPlanet ? root.userData.detail.bodyMaterial : nodeMaterials.get(nodeId);
      opacityOf(material, isSelected ? 1 : (isPlanet ? .3 * (1 - progress) : .18 * (1 - progress)));
      if (!isPlanet) return;
      const detailOpacity = isSelected ? progress : 0;
      root.userData.detail.atomGroup.visible = detailOpacity > .01;
      root.userData.detail.arcGroup.visible = detailOpacity > .01;
      root.userData.detail.atomGroup.children.forEach((atom) => opacityOf(atom.material, detailOpacity));
      root.userData.detail.arcGroup.children.forEach((arc) => opacityOf(arc.material, detailOpacity * .92));
    });
  }

  async function initialize(nextSnapshot) {
    snapshot = nextSnapshot;
    window.THREE = THREE;
    const [ForceGraph3D, inlineThreeGlobe] = await Promise.all([loadForceGraph3D(), loadThreeGlobe()]);
    if (disposed) return;
    ThreeGlobe = inlineThreeGlobe;
    liveGalaxy = snapshotGalaxy(snapshot);
    graph = new ForceGraph3D(mount, { controlType: 'orbit' })
      .backgroundColor(background)
      .graphData(liveGalaxy)
      .nodeThreeObject(createPlanetRoot)
      .nodeThreeObjectExtend(false)
      .nodeLabel(() => '')
      .linkColor(() => 'rgba(140, 118, 220, .30)')
      .linkOpacity(.32)
      .linkWidth(.2)
      .cooldownTicks(90)
      .cooldownTime(900)
      .onNodeClick((node) => {
        if (!node?.isPlanet || !onPlanetSelect) return;
        onPlanetSelect(node.id);
      });
    graph.enableNodeDrag(false);
    graph.enablePointerInteraction(true);
    graph.controls().enablePan = false;
    graph.controls().enableDamping = true;
    graph.controls().dampingFactor = .08;
  }

  function selectPlanet(planetId, duration = 720) {
    if (!graph || !planetRoots.has(planetId)) return null;
    selectedPlanetId = planetId;
    const root = hydrateSelectedU3Planet(planetRoots.get(planetId), planetId);
    root.updateMatrixWorld(true);
    const center = root.getWorldPosition(new THREE.Vector3());
    const camera = graph.camera();
    const fromTarget = camera.position.clone().sub(graph.controls().target).normalize();
    const distance = selectedRadius * 3.75;
    const position = center.clone().addScaledVector(fromTarget, distance);
    graph.cameraPosition(position, center, duration);
    graph.enableNodeDrag(false);
    applySelectedVisuals(0);
    return { center, position, duration };
  }

  function setInlineProgress(progress) {
    applySelectedVisuals(Math.max(0, Math.min(1, progress)));
  }

  function fadeEnvironment(progress) {
    if (!graph) return;
    const amount = Math.max(0, Math.min(1, progress));
    graph.linkOpacity(.32 * (1 - amount));
    applySelectedVisuals(1);
  }

  function freezeLayout() {
    if (!graph || frozenNodes) return;
    frozenNodes = liveGalaxy.nodes.map((node) => ({
      node,
      fx: node.fx,
      fy: node.fy,
      fz: node.fz,
      x: node.x,
      y: node.y,
      z: node.z,
    }));
    frozenNodes.forEach(({ node }) => { node.fx = node.x; node.fy = node.y; node.fz = node.z; });
  }

  function restoreLayout() {
    frozenNodes?.forEach(({ node, fx, fy, fz }) => { node.fx = fx; node.fy = fy; node.fz = fz; });
    frozenNodes = null;
  }

  function captureCamera() {
    if (!graph || !selectedPlanetId) return null;
    const root = planetRoots.get(selectedPlanetId);
    if (!root) return null;
    const camera = graph.camera();
    const controls = graph.controls();
    root.updateMatrixWorld(true);
    camera.updateMatrixWorld(true);
    const center = root.getWorldPosition(new THREE.Vector3());
    const quaternion = root.getWorldQuaternion(new THREE.Quaternion());
    const scale = root.getWorldScale(new THREE.Vector3());
    // U3's detail globe intentionally sits at 92% of the ForceGraph node
    // radius. The handoff must measure that rendered body, never the old
    // overview proxy radius, otherwise a "valid" match still jumps by 8%.
    const detail = root.userData.detail;
    const localVisualRadius = detail
      ? (detail.inlineGlobe.getGlobeRadius?.() || 100) * detail.inlineGlobe.scale.x
      : selectedRadius;
    const radius = localVisualRadius * scale.x;
    return {
      cameraPosition: camera.getWorldPosition(new THREE.Vector3()),
      cameraQuaternion: camera.getWorldQuaternion(new THREE.Quaternion()),
      cameraUp: camera.up.clone(),
      fov: camera.fov,
      aspect: camera.aspect,
      near: camera.near,
      far: camera.far,
      controlsTarget: controls.target.clone(),
      planetWorldCenter: center,
      planetWorldQuaternion: quaternion,
      planetWorldScale: scale,
      planetVisualRadius: radius,
      viewport: { ...viewport(), devicePixelRatio: window.devicePixelRatio || 1 },
      screen: projectMetrics({ camera, root, radius: localVisualRadius, viewport: viewport() }),
    };
  }

  function applyCameraSnapshot(cameraSnapshot) {
    if (!graph || !cameraSnapshot) return;
    const camera = graph.camera();
    const controls = graph.controls();
    camera.position.copy(cameraSnapshot.cameraPosition);
    camera.quaternion.copy(cameraSnapshot.cameraQuaternion);
    camera.up.copy(cameraSnapshot.cameraUp);
    camera.fov = cameraSnapshot.fov;
    camera.aspect = cameraSnapshot.aspect;
    camera.near = cameraSnapshot.near;
    camera.far = cameraSnapshot.far;
    camera.updateProjectionMatrix();
    controls.target.copy(cameraSnapshot.controlsTarget);
    controls.update();
  }

  function resize() {
    if (!graph) return;
    const { width, height } = viewport();
    graph.width(width).height(height);
    const camera = graph.camera();
    camera.aspect = width / Math.max(1, height);
    camera.updateProjectionMatrix();
  }

  function getLandmarkScreenPoints(landmarks = []) {
    if (!graph || !selectedPlanetId) return [];
    const root = planetRoots.get(selectedPlanetId);
    if (!root) return [];
    const camera = graph.camera();
    const { width, height } = viewport();
    root.updateMatrixWorld(true);
    const detail = root.userData.detail;
    return landmarks.map((landmark) => {
      // Use the same ThreeGlobe geographic conversion that renders U3's
      // inline cities. A handwritten spherical conversion can choose a
      // different longitude axis and falsely pass center/radius validation.
      const globePoint = detail?.inlineGlobe.getCoords?.(landmark.lat, landmark.lng, landmark.altitude || .03);
      const worldPoint = globePoint
        ? detail.inlineGlobe.localToWorld(globePoint.clone())
        : root.localToWorld(latLngToVector(landmark.lat, landmark.lng, selectedRadius, landmark.altitude || .03));
      const projected = worldPoint.project(camera);
      return { id: landmark.id, x: (projected.x * .5 + .5) * width, y: (-projected.y * .5 + .5) * height };
    });
  }

  function setInputEnabled(enabled) {
    if (!graph) return;
    inputEnabled = Boolean(enabled);
    graph.enablePointerInteraction(inputEnabled);
    graph.enableNodeDrag(false);
    const controls = graph.controls();
    controls.enabled = inputEnabled;
    controls.enablePan = false;
    syncPointerEvents();
  }

  function setOpacity(opacity) {
    mount.style.opacity = String(Math.max(0, Math.min(1, opacity)));
    syncPointerEvents();
  }

  function pauseAfterFade() {
    if (!graph || paused) return;
    graph.pauseAnimation();
    paused = true;
  }

  function resume() {
    if (!graph || !paused) return;
    graph.resumeAnimation?.();
    paused = false;
  }

  function dispose() {
    disposed = true;
    restoreLayout();
    planetRoots.forEach((root) => root.traverse((object) => {
      object.geometry?.dispose?.();
      if (Array.isArray(object.material)) object.material.forEach((material) => material.dispose?.());
      else object.material?.dispose?.();
    }));
    planetRoots.clear();
    nodeMaterials.clear();
    try { graph?._destructor?.(); } catch { /* vendor cleanup is best effort */ }
    mount.replaceChildren();
    graph = null;
  }

  return {
    initialize,
    selectPlanet,
    setInlineProgress,
    fadeEnvironment,
    freezeLayout,
    restoreLayout,
    captureCamera,
    applyCameraSnapshot,
    resize,
    getLandmarkScreenPoints,
    setInputEnabled,
    setOpacity,
    pauseAfterFade,
    resume,
    dispose,
    get graph() { return graph; },
    get selectedPlanetId() { return selectedPlanetId; },
    get isPaused() { return paused; },
  };
}
