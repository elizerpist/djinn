/* A single live Globe.gl scene shared by the collapsed orb and expanded panel. */
import { knowledgeNodes, knowledgeEdges } from './knowledge-map.js?rev=133';
import * as THREE from './vendor/three.module.min.js?rev=92';

const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
const ORB_POINTS = knowledgeNodes.map((node, index) => {
  // Egyenletes, determinisztikus gömbi sáv: a pólusokat kerüljük, mert ott a
  // kártya/gömb vetülete torlódna. A kapcsolatszám továbbra is csak a méretet
  // szabályozza, nem az elhelyezést.
  const latitude = -72 + ((index + .5) / knowledgeNodes.length) * 144;
  const longitude = ((index * GOLDEN_ANGLE * 180 / Math.PI + 180) % 360) - 180;
  return { ...node, lat: latitude, lng: longitude, label: node.title };
});
const pointById = new Map(ORB_POINTS.map((point) => [point.id, point]));
const ORB_ARCS = knowledgeEdges
  .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
  .map((edge) => ({
    ...edge,
    startLat: pointById.get(edge.source).lat,
    startLng: pointById.get(edge.source).lng,
    endLat: pointById.get(edge.target).lat,
    endLng: pointById.get(edge.target).lng,
  }));

const nodeById = new Map(ORB_POINTS.map((node) => [node.id, node]));
const degreeById = new Map(ORB_POINTS.map((node) => [node.id, 0]));
const edgeKeys = new Set();
knowledgeEdges.forEach((edge) => {
  if (!nodeById.has(edge.source) || !nodeById.has(edge.target)) return;
  const key = [edge.source, edge.target].sort().join('::');
  if (edgeKeys.has(key)) return;
  edgeKeys.add(key);
  degreeById.set(edge.source, (degreeById.get(edge.source) || 0) + 1);
  degreeById.set(edge.target, (degreeById.get(edge.target) || 0) + 1);
});
const degrees = [...degreeById.values()];
const minDegree = Math.min(...degrees);
const maxDegree = Math.max(...degrees);
const nodeRadius = (degree) => {
  const t = maxDegree <= minDegree ? 0 : Math.sqrt(clamp((degree - minDegree) / (maxDegree - minDegree), 0, 1));
  return 1.6 + t * 3.6;
};
const typeColors = {
  topic: '#6B3EF6', condition: '#8A63E8', measurement: '#B9B0E6', concept: '#7C4DFF',
  treatment: '#9B7BFF', procedure: '#8276BA', symptom: '#C58BDF', source: '#6D75C8'
};
const arcPalette = ['#8E6BFF', '#C084FC', '#60A5FA', '#F0ABFC', '#A78BFA', '#67E8F9', '#F9A8D4'];

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const lerp = (a, b, t) => a + (b - a) * t;

export function initExpandableGalaxyOrb({ root, nav }) {
  if (!root || !nav) return () => {};
  const layer = document.createElement('section');
  layer.className = 'expandable-galaxy-orb';
  layer.dataset.state = 'collapsed';
  layer.innerHTML = `
    <div class="galaxy-orb-morph" role="dialog" aria-label="Tudásgalaxis">
      <div class="galaxy-orb-canvas" aria-hidden="true"></div>
      <div class="galaxy-orb-background-swipe" aria-hidden="true"></div>
      <div class="galaxy-orb-glass" aria-hidden="true"></div>
      <button class="galaxy-orb-trigger" type="button" aria-label="Tudásgalaxis megnyitása" aria-expanded="false">✦</button>
      <button class="galaxy-orb-handle" type="button" aria-label="Tudásgalaxis összecsukása"></button>
      <article class="galaxy-node-morph-overlay" aria-hidden="true">
        <div class="galaxy-node-card-content">
          <div class="galaxy-node-card-meta"><span data-node-type></span><span data-node-degree></span></div>
          <h2 data-node-title></h2>
          <p data-node-subtitle></p>
          <div class="galaxy-node-card-source" data-node-source></div>
          <div class="galaxy-node-card-actions"><button type="button" data-node-close>Vissza a galaxisba</button></div>
        </div>
      </article>
      <div class="galaxy-orb-controls" aria-hidden="true">
        <span class="galaxy-orb-title">Tudásgalaxis</span>
        <button type="button" data-galaxy-action="reset" aria-label="Galaxis középre állítása">⌖</button>
        <button type="button" data-galaxy-action="collapse" aria-label="Galaxis összecsukása">⌄</button>
      </div>
    </div>`;
  root.append(layer);

  const morph = layer.querySelector('.galaxy-orb-morph');
  const canvas = layer.querySelector('.galaxy-orb-canvas');
  const backgroundSwipe = layer.querySelector('.galaxy-orb-background-swipe');
  const trigger = layer.querySelector('.galaxy-orb-trigger');
  const handle = layer.querySelector('.galaxy-orb-handle');
  const morphOverlay = layer.querySelector('.galaxy-node-morph-overlay');
  const cardContent = layer.querySelector('.galaxy-node-card-content');
  const cardClose = layer.querySelector('[data-node-close]');
  const controlsPanel = layer.querySelector('.galaxy-orb-controls');
  let globe = null;
  let destroyed = false;
  let state = 'collapsed';
  let progress = 0;
  let pointer = null;
  let bounds = null;
  let resizeObserver = null;
  let raf = 0;
  let focusState = 'idle';
  let focusedNode = null;
  let focusedCameraState = null;
  let focusTimer = 0;
  const nodeObjects = new Map();
  const sphereGeometry = new THREE.SphereGeometry(1, 24, 18);
  const materialCache = new Map();

  function measureBounds() {
    if (!root.classList.contains('is-inline')) return;
    const inlineSlot = root.parentElement;
    if (!inlineSlot?.classList.contains('explore-galaxy-slot')) return;

    const rootRect = root.getBoundingClientRect();
    const width = rootRect.width || inlineSlot.getBoundingClientRect().width;
    const collapsedHeight = 230;
    const expandedHeight = collapsedHeight;
    const collapsedSize = clamp(Math.min(190, width - 48), 154, 190);
    const collapsed = {
      left: (width - collapsedSize) / 2,
      top: (collapsedHeight - collapsedSize) / 2,
      width: collapsedSize,
      height: collapsedSize
    };
    const expanded = {
      left: 0,
      top: 0,
      width,
      height: expandedHeight
    };
    bounds = { collapsed, expanded, anchorRect: null };
    applyProgress(progress);
  }

  function applyProgress(next) {
    if (!bounds) return;
    progress = clamp(next, 0, 1);
    const a = bounds.collapsed;
    const b = bounds.expanded;
    const inlineSlot = root.closest('.explore-galaxy-slot');
    if (inlineSlot) {
      inlineSlot.style.height = `${b.height}px`;
    }
    // A collapsed állapot a jóváhagyott látvány szerint lekerekített négyzetes
    // galaxisablak, nem kör alakú ikon. Innen morphol tovább a nagy panelbe.
    const radius = lerp(34, 24, progress);
    morph.style.left = `${lerp(a.left, b.left, progress)}px`;
    morph.style.top = `${lerp(a.top, b.top, progress)}px`;
    morph.style.width = `${lerp(a.width, b.width, progress)}px`;
    morph.style.height = `${lerp(a.height, b.height, progress)}px`;
    morph.style.borderRadius = `${radius}px`;
    layer.dataset.state = state;
    trigger.setAttribute('aria-expanded', String(progress > .5));
    trigger.tabIndex = progress < .5 ? 0 : -1;
    handle.tabIndex = progress > .5 ? 0 : -1;
    controlsPanel.setAttribute('aria-hidden', String(progress < .7));
    controlsPanel.style.opacity = String(clamp((progress - .68) / .22, 0, 1));
    morph.classList.toggle('is-expanded', progress > .5);
    if (globe) applyGlobeProfile(progress > .5);
  }

  function animateTo(target, duration = 390) {
    const from = progress;
    const start = performance.now();
    state = target > from ? 'expanding' : 'collapsing';
    layer.dataset.state = state;
    cancelAnimationFrame(raf);
    const tick = (now) => {
      const t = clamp((now - start) / duration, 0, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      applyProgress(lerp(from, target, eased));
      if (t < 1 && !destroyed) raf = requestAnimationFrame(tick);
      else {
        progress = target;
        state = target > .5 ? 'expanded' : 'collapsed';
        layer.dataset.state = state;
        applyGlobeProfile(state === 'expanded');
      }
    };
    raf = requestAnimationFrame(tick);
  }

  function nodeMaterial(node) {
    const key = node.type || 'concept';
    if (!materialCache.has(key)) {
      materialCache.set(key, new THREE.MeshStandardMaterial({
        color: typeColors[key] || typeColors.concept,
        roughness: .65,
        metalness: .05,
        transparent: true,
        opacity: 1,
        depthTest: true,
        depthWrite: true
      }));
    }
    return materialCache.get(key).clone();
  }

  function createNodeObject(node) {
    const group = new THREE.Group();
    const radius = nodeRadius(degreeById.get(node.id) || 0);
    const sphere = new THREE.Mesh(sphereGeometry, nodeMaterial(node));
    sphere.scale.setScalar(radius);
    sphere.castShadow = true;
    sphere.receiveShadow = true;
    const hitSphere = new THREE.Mesh(
      sphereGeometry,
      new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false, depthTest: false })
    );
    hitSphere.scale.setScalar(Math.max(radius * 1.5, 3.5));
    hitSphere.userData.isHitTarget = true;
    group.add(sphere, hitSphere);
    group.userData = { nodeId: node.id, sphere, hitSphere, baseRadius: radius };
    nodeObjects.set(node.id, group);
    return group;
  }

  function connectedTo(nodeId) {
    const related = new Set([nodeId]);
    knowledgeEdges.forEach((edge) => {
      if (edge.source === nodeId) related.add(edge.target);
      if (edge.target === nodeId) related.add(edge.source);
    });
    return related;
  }

  function refreshNodeVisuals() {
    const related = focusedNode ? connectedTo(focusedNode.id) : null;
    nodeObjects.forEach((object, nodeId) => {
      const data = object.userData;
      const isFocused = focusedNode?.id === nodeId;
      const isRelated = related?.has(nodeId);
      const opacity = !focusedNode ? 1 : (isFocused ? 1 : (isRelated ? .86 : .32));
      data.sphere.material.opacity = opacity;
      data.sphere.material.emissive = new THREE.Color(isFocused ? '#9B7BFF' : '#000000');
      data.sphere.material.emissiveIntensity = isFocused ? .42 : 0;
      data.sphere.scale.setScalar(data.baseRadius * (isFocused ? 1.12 : 1));
      data.hitSphere.visible = true;
      object.visible = focusState !== 'morphing-to-card' || !isFocused;
    });
  }

  function refreshEdges() {
    if (!globe) return;
    const related = focusedNode ? connectedTo(focusedNode.id) : null;
    ORB_ARCS.forEach((edge) => {
      edge.isFocused = Boolean(focusedNode && (edge.source === focusedNode.id || edge.target === focusedNode.id));
      edge.isRelated = Boolean(related && related.has(edge.source) && related.has(edge.target));
    });
    globe.arcsData(ORB_ARCS);
  }

  function worldPosition(node) {
    const coords = globe.getCoords(node.lat, node.lng, .012);
    return new THREE.Vector3(coords.x, coords.y, coords.z);
  }

  function animateCameraToNode(node, duration, altitude, done) {
    const controls = globe.controls?.();
    const camera = globe.camera?.();
    if (!controls || !camera) return done?.();
    const startTarget = controls.target.clone();
    const startPosition = camera.position.clone();
    const targetCoords = worldPosition(node);
    const targetTarget = targetCoords.clone();
    const viewDirection = camera.position.clone().sub(controls.target).normalize();
    const distance = globe.getGlobeRadius?.() * altitude || 190;
    const targetPosition = targetCoords.clone().add(viewDirection.multiplyScalar(distance));
    const start = performance.now();
    cancelAnimationFrame(focusTimer);
    const tick = (now) => {
      const t = clamp((now - start) / duration, 0, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      controls.target.lerpVectors(startTarget, targetTarget, eased);
      camera.position.lerpVectors(startPosition, targetPosition, eased);
      camera.lookAt(controls.target);
      controls.update?.();
      if (t < 1 && !destroyed) focusTimer = requestAnimationFrame(tick);
      else {
        controls.target.copy(targetTarget);
        camera.position.copy(targetPosition);
        camera.lookAt(targetTarget);
        controls.update?.();
        done?.();
      }
    };
    focusTimer = requestAnimationFrame(tick);
  }

  function projectedNodeRect(node) {
    const camera = globe.camera();
    const rect = canvas.getBoundingClientRect();
    const projected = worldPosition(node).project(camera);
    const x = (projected.x * .5 + .5) * rect.width;
    const y = (-projected.y * .5 + .5) * rect.height;
    const radius = clamp(48 + (nodeRadius(degreeById.get(node.id) || 0) * 4), 58, 104);
    return { left: x - radius / 2, top: y - radius / 2, width: radius, height: radius };
  }

  function fillCard(node) {
    morphOverlay.querySelector('[data-node-type]').textContent = node.type || 'fogalom';
    morphOverlay.querySelector('[data-node-degree]').textContent = `${degreeById.get(node.id) || 0} kapcsolat`;
    morphOverlay.querySelector('[data-node-title]').textContent = node.title;
    morphOverlay.querySelector('[data-node-subtitle]').textContent = node.subtitle || 'Kapcsolódó tudáselem a Djinn gráfjában.';
    morphOverlay.querySelector('[data-node-source]').textContent = node.sourceName || 'Djinn tudásgráf';
  }

  function morphToCard(node) {
    focusState = 'morphing-to-card';
    refreshNodeVisuals();
    const startRect = projectedNodeRect(node);
    const panelWidth = morph.clientWidth;
    const panelHeight = morph.clientHeight;
    const endWidth = Math.max(240, panelWidth - 32);
    const endHeight = Math.min(250, Math.max(180, panelHeight * .62));
    morphOverlay.style.left = `${startRect.left}px`;
    morphOverlay.style.top = `${startRect.top}px`;
    morphOverlay.style.width = `${startRect.width}px`;
    morphOverlay.style.height = `${startRect.height}px`;
    morphOverlay.style.borderRadius = '50%';
    morphOverlay.style.opacity = '0';
    morphOverlay.classList.add('is-visible');
    fillCard(node);
    requestAnimationFrame(() => {
      morphOverlay.style.left = `${(panelWidth - endWidth) / 2}px`;
      morphOverlay.style.top = `${Math.max(42, (panelHeight - endHeight) * .56)}px`;
      morphOverlay.style.width = `${endWidth}px`;
      morphOverlay.style.height = `${endHeight}px`;
      morphOverlay.style.borderRadius = '22px';
      morphOverlay.style.opacity = '1';
      cardContent.classList.add('is-readable');
    });
    window.setTimeout(() => {
      focusState = 'card-open';
      morphOverlay.setAttribute('aria-hidden', 'false');
      cardClose.focus?.();
    }, 420);
  }

  function focusNode(nodeId) {
    if (!globe || focusState !== 'idle' || state !== 'expanded') return;
    const node = nodeById.get(nodeId);
    if (!node) return;
    focusedNode = node;
    focusState = 'node-selected';
    focusedCameraState = {
      cameraPosition: globe.camera().position.clone(),
      controlsTarget: globe.controls().target.clone()
    };
    const controls = globe.controls();
    controls.enableRotate = false;
    controls.enableZoom = false;
    controls.autoRotate = false;
    refreshNodeVisuals();
    refreshEdges();
    focusState = 'orienting';
    animateCameraToNode(node, 380, 1.7, () => {
      focusState = 'zooming';
      animateCameraToNode(node, 320, 1.32, () => morphToCard(node));
    });
  }

  function closeNodeCard() {
    if (!focusedNode || (focusState !== 'card-open' && focusState !== 'morphing-to-card')) return;
    focusState = 'morphing-to-node';
    cardContent.classList.remove('is-readable');
    morphOverlay.style.left = `${projectedNodeRect(focusedNode).left}px`;
    morphOverlay.style.top = `${projectedNodeRect(focusedNode).top}px`;
    morphOverlay.style.width = `${projectedNodeRect(focusedNode).width}px`;
    morphOverlay.style.height = `${projectedNodeRect(focusedNode).height}px`;
    morphOverlay.style.borderRadius = '50%';
    morphOverlay.style.opacity = '0';
    window.setTimeout(() => {
      morphOverlay.classList.remove('is-visible');
      morphOverlay.setAttribute('aria-hidden', 'true');
      const controls = globe.controls();
      controls.target.copy(focusedCameraState.controlsTarget);
      globe.camera().position.copy(focusedCameraState.cameraPosition);
      controls.enableRotate = true;
      controls.enableZoom = true;
      controls.update?.();
      focusedNode = null;
      focusState = 'idle';
      refreshNodeVisuals();
      refreshEdges();
    }, 380);
  }

  function applyGlobeProfile(expanded) {
    if (!globe) return;
    const controls = globe.controls?.();
    if (controls) {
      controls.enableRotate = expanded && focusState === 'idle';
      controls.enableZoom = expanded && focusState === 'idle';
      controls.enablePan = false;
      controls.autoRotate = !expanded && focusState === 'idle';
      controls.autoRotateSpeed = .28;
    }
    globe.arcStroke?.((edge) => edge.isFocused ? (expanded ? .24 : .20) : (edge.isRelated ? (expanded ? .18 : .15) : (expanded ? .14 : .12)));
    refreshNodeVisuals();
  }

  function createGlobe(attempt = 0) {
    if (destroyed || globe) return;
    const Globe = window.Globe;
    if (!Globe) {
      if (attempt < 60) window.setTimeout(() => createGlobe(attempt + 1), 50);
      return;
    }
    try {
      globe = new Globe(canvas, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: false })
        .backgroundColor('#0B0A17')
        .showAtmosphere(false)
        .showGraticules(false)
        .objectsData(ORB_POINTS)
        .objectLat((point) => point.lat)
        .objectLng((point) => point.lng)
        .objectAltitude(.012)
        .objectThreeObject((point) => createNodeObject(point))
        .onObjectClick((point) => focusNode(point.id))
        .arcsData(ORB_ARCS)
        .arcStartLat((arc) => arc.startLat)
        .arcStartLng((arc) => arc.startLng)
        .arcEndLat((arc) => arc.endLat)
        .arcEndLng((arc) => arc.endLng)
        .arcColor((edge) => edge.isFocused ? '#FFFFFF' : (edge.isRelated ? '#E9D5FF' : arcPalette[Math.floor(Math.abs(Number(edge.weight || 0) * 1000 + String(edge.source).length)) % arcPalette.length]))
        .arcAltitude((edge) => edge.isFocused ? .32 : (edge.isRelated ? .26 : .19))
        .arcStroke((edge) => edge.isFocused ? .24 : (edge.isRelated ? .18 : .14))
        .arcDashLength(1)
        .arcDashGap(0)
        .arcsTransitionDuration(0);
      globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 0);
      const ambient = new THREE.AmbientLight(0x4b286f, .72);
      const key = new THREE.DirectionalLight(0xf0eaff, 2.6);
      const target = new THREE.Object3D();
      globe.scene().add(target);
      key.target = target;
      globe.lights([ambient, key]);
      const updateLight = () => {
        const camera = globe.camera();
        const controls = globe.controls();
        camera.updateMatrixWorld();
        const offset = new THREE.Vector3(1.3, .35, 2).applyQuaternion(camera.quaternion).normalize().multiplyScalar(300);
        target.position.copy(controls.target);
        key.position.copy(controls.target).add(offset);
      };
      globe.controls().addEventListener('change', updateLight);
      updateLight();
      applyGlobeProfile(false);
      resizeObserver = new ResizeObserver(() => {
        const rect = canvas.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) globe.width(rect.width).height(rect.height);
      });
      resizeObserver.observe(canvas);
      refreshEdges();
    } catch (error) {
      canvas.innerHTML = '<span class="galaxy-orb-fallback">✦</span>';
      canvas.setAttribute('data-error', error.message);
    }
  }

  function setRoute(route) {
    const visible = route === 'explore';
    layer.classList.toggle('is-route-visible', visible);
    if (!visible && progress > 0) animateTo(0, 260);
    if (visible) { measureBounds(); createGlobe(); }
  }

  function onTrigger(event) {
    event.preventDefault();
    if (state === 'collapsed') animateTo(1);
  }

  function onPointerDown(event) {
    if (state === 'expanding' || state === 'collapsing') return;
    pointer = { id: event.pointerId, startY: event.clientY, startX: event.clientX, startProgress: progress, moved: false };
    event.currentTarget.setPointerCapture?.(event.pointerId);
  }

  function onPointerMove(event) {
    if (!pointer || pointer.id !== event.pointerId) return;
    const dy = pointer.startY - event.clientY;
    if (Math.abs(dy) < 4) return;
    pointer.moved = true;
    state = 'dragging';
    const range = Math.max(160, bounds.expanded.height - bounds.collapsed.height);
    applyProgress(pointer.startProgress + dy / range);
  }

  function onPointerUp(event) {
    if (!pointer || pointer.id !== event.pointerId) return;
    const dy = pointer.startY - event.clientY;
    const shouldExpand = pointer.startProgress < .5 && (progress > .35 || dy > 28);
    const shouldCollapse = pointer.startProgress >= .5 && progress < .72;
    const wasMoved = pointer.moved;
    pointer = null;
    if (shouldExpand) animateTo(1);
    else if (shouldCollapse) animateTo(0);
    else if (!wasMoved && state === 'collapsed') animateTo(1);
    else { state = progress > .5 ? 'expanded' : 'collapsed'; layer.dataset.state = state; }
  }

  function onHandleDown(event) {
    onPointerDown(event);
  }

  function onHandleMove(event) {
    if (!pointer || pointer.id !== event.pointerId) return;
    const dy = pointer.startY - event.clientY;
    pointer.moved = true;
    applyProgress(pointer.startProgress + dy / Math.max(160, bounds.expanded.height - bounds.collapsed.height));
  }

  function onHandleUp(event) {
    if (!pointer || pointer.id !== event.pointerId) return;
    const collapse = progress < .82;
    pointer = null;
    animateTo(collapse ? 0 : 1);
  }

  function onClick(event) {
    const action = event.target.closest('[data-galaxy-action]')?.dataset.galaxyAction;
    if (action === 'collapse') animateTo(0);
    if (action === 'reset' && globe) globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 500);
  }

  function onCardClose(event) {
    event.preventDefault();
    closeNodeCard();
  }

  function onKeydown(event) {
    if (event.key === 'Escape' && focusState === 'card-open') closeNodeCard();
  }

  trigger.addEventListener('click', onTrigger);
  backgroundSwipe.addEventListener('pointerdown', onPointerDown);
  backgroundSwipe.addEventListener('pointermove', onPointerMove);
  backgroundSwipe.addEventListener('pointerup', onPointerUp);
  backgroundSwipe.addEventListener('pointercancel', onPointerUp);
  handle.addEventListener('pointerdown', onHandleDown);
  handle.addEventListener('pointermove', onHandleMove);
  handle.addEventListener('pointerup', onHandleUp);
  layer.addEventListener('click', onClick);
  cardClose.addEventListener('click', onCardClose);
  window.addEventListener('keydown', onKeydown);
  window.addEventListener('resize', measureBounds);
  measureBounds();
  createGlobe();

  return {
    setRoute,
    destroy() {
      destroyed = true;
      cancelAnimationFrame(raf);
      resizeObserver?.disconnect();
      window.removeEventListener('resize', measureBounds);
      trigger.removeEventListener('click', onTrigger);
      backgroundSwipe.removeEventListener('pointerdown', onPointerDown);
      backgroundSwipe.removeEventListener('pointermove', onPointerMove);
      backgroundSwipe.removeEventListener('pointerup', onPointerUp);
      backgroundSwipe.removeEventListener('pointercancel', onPointerUp);
      handle.removeEventListener('pointerdown', onHandleDown);
      handle.removeEventListener('pointermove', onHandleMove);
      handle.removeEventListener('pointerup', onHandleUp);
      layer.removeEventListener('click', onClick);
      cardClose.removeEventListener('click', onCardClose);
      window.removeEventListener('keydown', onKeydown);
      globe?.controls?.().dispose?.();
      sphereGeometry.dispose();
      materialCache.forEach((material) => material.dispose());
      globe = null;
      layer.remove();
    }
  };
}
