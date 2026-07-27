import * as THREE from './vendor/three.module.min.js?rev=92';
import {
  TEST_SEED,
  UNIVERSE_LEVEL,
  classifyPointerTap,
  createUniverseMockData,
  easeInOutCubic,
  focusCameraTarget,
  galaxyNodeRadius,
  fibonacciSpherePoint,
  projectPointToScreen,
  surfaceArcPoints,
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
  const mapMount = root.querySelector('[data-universe-map]');
  const proxy = root.querySelector('[data-universe-proxy]');
  const debug = root.querySelector('[data-universe-debug]');
  if (!stage || !galaxyMount || !mapMount || !proxy) return () => {};

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
  let mapResizeObserver;
  let removeWaiter = () => {};
  let transitionFrame = 0;
  let pointerStart;
  let destroyed = false;
  let sceneLights = [];
  let detailGlobe;
  let mapGraph;
  let planetContentGroup;
  const planetNodeViews = new Map();
  const planetLinkViews = [];
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
    configurePlanetContent();
    return scale;
  }

  function configurePlanetContent() {
    if (!detailGlobe || planetContentGroup) return;
    const detailRadius = detailGlobe.getGlobeRadius?.() || 100;
    const visibleGeometry = new THREE.SphereGeometry(1, 12, 10);
    const hitGeometry = new THREE.SphereGeometry(1, 10, 8);
    const glowGeometry = new THREE.SphereGeometry(1, 12, 10);
    const hitMaterial = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
    const edgeMaterial = new THREE.LineBasicMaterial({ color: 0xddd1ff, transparent: true, opacity: 0 });
    ownedMaterials.add(hitMaterial);
    ownedMaterials.add(edgeMaterial);
    planetContentGroup = new THREE.Group();
    planetContentGroup.name = 'planet-content';
    planetContentGroup.visible = false;
    const pointById = new Map();

    mock.planet.nodes.forEach((node, index) => {
      const point = fibonacciSpherePoint(index, mock.planet.nodes.length, detailRadius, .025);
      const rootGroup = new THREE.Group();
      const visibleMaterial = new THREE.MeshStandardMaterial({ color: 0xf6d76b, roughness: .5, metalness: .06, transparent: true, opacity: 0 });
      const glowMaterial = new THREE.MeshBasicMaterial({ color: 0xffe786, transparent: true, opacity: 0, depthWrite: false, side: THREE.BackSide });
      ownedMaterials.add(visibleMaterial);
      ownedMaterials.add(glowMaterial);
      const visibleSphere = new THREE.Mesh(visibleGeometry, visibleMaterial);
      const glow = new THREE.Mesh(glowGeometry, glowMaterial);
      const hitSphere = new THREE.Mesh(hitGeometry, hitMaterial);
      const baseScale = 2.5 + node.importance * 2.6;
      visibleSphere.scale.setScalar(baseScale);
      glow.scale.setScalar(baseScale * 1.52);
      hitSphere.scale.setScalar(baseScale * 2.1);
      rootGroup.position.set(point.x, point.y, point.z);
      rootGroup.userData = { planetNodeId: node.id };
      rootGroup.add(visibleSphere, glow, hitSphere);
      const normal = new THREE.Vector3(point.x, point.y, point.z).normalize();
      planetContentGroup.add(rootGroup);
      planetNodeViews.set(node.id, { id: node.id, root: rootGroup, visibleSphere, glow, hitSphere, normal, baseScale });
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

    detailGlobe.add(planetContentGroup);
  }

  function setPlanetContentOpacity(opacity) {
    if (!planetContentGroup) return;
    planetContentGroup.visible = opacity > 0;
    planetNodeViews.forEach((view) => {
      view.visibleSphere.material.opacity = opacity;
      view.glow.material.opacity = opacity * .17;
    });
    planetLinkViews.forEach((edge) => { edge.material.opacity = opacity * .24; });
  }

  function resize() {
    if (!graph || destroyed) return;
    graph.width(Math.max(1, galaxyMount.clientWidth));
    graph.height(Math.max(1, galaxyMount.clientHeight));
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
          fill: focused ? '#8b65fa' : '#302153',
          stroke: focused ? '#d9ccff' : '#8068a7',
          lineWidth: focused ? 1.8 : 1,
          shadowColor: focused ? '#7c4dff' : '#150d2b',
          shadowBlur: focused ? 18 : 8,
          shadowOffsetY: focused ? 6 : 3,
          labelText: focused ? 'Fókuszpont' : node.label,
          labelPlacement: 'center',
          labelFill: '#f1ecff',
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
        setPlanetContentOpacity(Math.max(0, (eased - .32) / .68));
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
    if (state.level === UNIVERSE_LEVEL.GALAXY) {
      const nodeId = selectedPlanetAt(event);
      if (nodeId) requestPlanetEntry(nodeId);
      return;
    }
    if (state.level === UNIVERSE_LEVEL.PLANET) {
      const nodeId = selectedPlanetSurfaceNodeAt(event);
      if (nodeId) requestMapEntry(nodeId);
    }
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
    const hits = raycaster.intersectObjects([...planetNodeViews.values()].map((view) => view.hitSphere), false);
    const hit = hits[0];
    if (!hit) return null;
    let object = hit.object;
    while (object && !object.userData?.planetNodeId) object = object.parent;
    return object?.userData?.planetNodeId || null;
  }

  async function requestMapEntry(nodeId) {
    if (state.interactionLocked || state.level !== UNIVERSE_LEVEL.PLANET || !planetNodeViews.has(nodeId)) return;
    const selectedView = planetNodeViews.get(nodeId);
    const camera = graph.camera();
    const controls = graph.controls();
    const selectedPlanetView = planetViews.get(state.selectedGalaxyNodeId);
    state.level = UNIVERSE_LEVEL.PLANET_TO_MAP;
    state.interactionLocked = true;
    state.selectedPlanetNodeId = nodeId;
    state.savedPlanetCamera = { position: camera.position.clone(), target: controls.target.clone(), globeQuaternion: detailGlobe.quaternion.clone() };
    planetNodeViews.forEach((view, id) => {
      view.visibleSphere.material.opacity = id === nodeId ? 1 : .28;
      view.glow.material.opacity = id === nodeId ? .48 : .04;
    });
    planetLinkViews.forEach((edge) => {
      edge.material.opacity = edge.source === nodeId || edge.target === nodeId ? .8 : .06;
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
      helpers.showToast?.(error.message || 'A térképnavigáció nem tölthető be.');
      updateDebug();
    }
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
    mapResizeObserver?.disconnect();
    galaxyMount.removeEventListener('pointerdown', onPointerDown);
    galaxyMount.removeEventListener('pointerup', onPointerUp);
    sceneLights.forEach((light) => light.removeFromParent());
    detailGlobe?.removeFromParent?.();
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
}
