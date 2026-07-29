/*
 * DjinnEdgeLayer
 *
 * A Globe.gl scene-be illesztett, batch-elt gömbfelszíni edge renderer.
 * Nem hoz létre saját renderer/camera/render loop példányt. A geodetikus
 * ribbon geometriák egyszer készülnek el, a kameraoldali fading és az energia
 * animáció shader uniformokkal történik.
 */
import * as THREE from './vendor/three.module.min.js?rev=92';

const PASS_NAMES = ['background', 'structure', 'bridge'];
const DEFAULT_PLANET_RADIUS = 100;
// Globe.gl expresses arc altitude as a fraction of the globe radius.  The
// previous native presets allowed long bridges to climb into a second
// concentric shell.  Keep the native trajectories varied, but bound their
// apex so the bridges read as local paths above the planet surface.
const NATIVE_AUTO_MAX_ALTITUDE = 0.14;
const NATIVE_WEIGHTED_MAX_ALTITUDE = 0.12;
const DEG = Math.PI / 180;

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

function stableHash(value) {
  let hash = 2166136261;
  const text = String(value || '');
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function stableUnit(value) {
  return (stableHash(value) % 100000) / 100000;
}

function bridgeProfile(
  edge,
  sourcePosition,
  targetPosition,
  planetRadius = DEFAULT_PLANET_RADIUS,
  renderer = 'native-weighted',
) {
  const safeRadius = Math.max(Number(planetRadius) || DEFAULT_PLANET_RADIUS, 0.001);
  const angle = Math.acos(clamp(
    sourcePosition.clone().normalize().dot(targetPosition.clone().normalize()),
    -1,
    1,
  ));
  const normalizedDistance = clamp(angle / Math.PI, 0, 1);
  const weight = clamp(Number(edge.weight || 0), 0, 1);
  const tier = edge.isSelected || edge.isFocused || weight >= 0.86
    ? 'hero'
    : (weight >= 0.56 ? 'major' : 'minor');
  const sourceAltitude = Math.max(0, sourcePosition.length() / safeRadius - 1);
  const targetAltitude = Math.max(0, targetPosition.length() / safeRadius - 1);
  // Globe.gl's native arc layer uses:
  //   angle / 2 * arcAltitudeAutoScale + max(startAltitude, endAltitude)
  // whenever arcAltitude is null. Keep this value available so the glow pass
  // can sample the exact Native Auto trajectory instead of inventing one.
  const variation = (stableUnit(edgeKey(edge)) - 0.5) * 0.012;
  const maxEndpointAltitude = Math.max(sourceAltitude, targetAltitude);
  const autoTierBoost = { minor: 0, major: 0.008, hero: 0.016 }[tier];
  const autoVariation = variation * 0.5;
  const desiredAutoAltitude = clamp(
    0.035 + normalizedDistance * 0.055 + weight * 0.025 + autoTierBoost + autoVariation,
    maxEndpointAltitude + 0.012,
    NATIVE_AUTO_MAX_ALTITUDE - 0.004,
  );
  // Solve Globe.gl's native formula backwards so the actual auto-scale value
  // produces the restrained target altitude for this edge, rather than merely
  // clamping a diagnostic value after the renderer has already used it.
  const autoScale = angle > 0.0001
    ? clamp((2 * Math.max(desiredAutoAltitude - maxEndpointAltitude, 0.004)) / angle, 0.01, 0.4)
    : 0.01;
  const nativeAutoAltitude = Math.min(
    NATIVE_AUTO_MAX_ALTITUDE,
    (angle / 2) * autoScale + maxEndpointAltitude,
  );

  // Weighted bridges remain restrained, but vary enough by distance, weight
  // and tier to avoid a shared concentric shell. The lower bound is only a
  // small lift above the rendered node surface, unlike the previous fixed
  // high trajectory.
  const tierBoost = { minor: 0, major: 0.012, hero: 0.026 }[tier];
  const distanceBoost = normalizedDistance * 0.028;
  const weightBoost = weight * 0.018;
  const surfaceAltitude = Math.max(sourceAltitude, targetAltitude) + 0.004;
  const peakAltitude = clamp(
    surfaceAltitude + 0.008 + tierBoost + distanceBoost + weightBoost + variation,
    surfaceAltitude,
    NATIVE_WEIGHTED_MAX_ALTITUDE,
  );
  return {
    angularDistance: angle,
    normalizedDistance,
    bridgeTier: tier,
    peakAltitude,
    nativeAutoAltitude,
    autoScale,
    nativePeakAltitude: renderer === 'native-auto' ? nativeAutoAltitude : peakAltitude,
    sourceAltitude,
    targetAltitude,
    apexPosition: 0.5,
    shapeExponent: 1,
    trajectoryShape: 'globe-native-cubic',
    stableVariation: variation,
  };
}

const PASS_CONFIG = Object.freeze({
  background: Object.freeze({
    maxEdges: 5000,
    // Pixel widths. The vertex shader expands the centerline in screen space,
    // so zooming the planet cannot turn these into giant world-space ribbons.
    width: 0.68,
    frontOpacity: 0.25,
    backOpacity: 0.1,
    altitude: 0.004,
    segmentsMin: 6,
    segmentsMax: 16,
    color: '#2189C7',
    energy: 0,
  }),
  structure: Object.freeze({
    maxEdges: 800,
    width: 0.62,
    frontOpacity: 0.86,
    backOpacity: 0.13,
    altitude: 0.007,
    segmentsMin: 8,
    segmentsMax: 24,
    color: '#43E7F8',
    energy: 0.12,
  }),
  bridge: Object.freeze({
    maxEdges: 100,
    width: 0.66,
    frontOpacity: 0.56,
    backOpacity: 0.09,
    // Bridge points are sampled from the same cubic great-circle trajectory
    // Globe.gl uses for Native Weighted arcs. This value is only a fallback;
    // each edge receives its own peakAltitude in bridgeProfile().
    altitude: 0.12,
    segmentsMin: 32,
    segmentsMax: 64,
    color: '#FF8A3D',
    energy: 0.78,
  }),
});

const EDGE_VERTEX_SHADER = `
  attribute vec3 aSurfaceNormal;
  attribute vec3 aColor;
  attribute float aProgress;
  attribute float aWeight;
  attribute float aPhase;
  attribute vec3 aSideVector;
  attribute float aRibbonSide;
  attribute float aWidthScale;

  uniform float uPixelWidth;
  uniform vec2 uResolution;

  varying vec3 vSurfaceNormal;
  varying vec3 vWorldPosition;
  varying vec3 vColor;
  varying float vProgress;
  varying float vWeight;
  varying float vPhase;

  void main() {
    vSurfaceNormal = normalize(mat3(modelMatrix) * aSurfaceNormal);
    vWorldPosition = (modelMatrix * vec4(position, 1.0)).xyz;
    vColor = aColor;
    vProgress = aProgress;
    vWeight = aWeight;
    vPhase = aPhase;
    vec4 clipPosition = projectionMatrix * viewMatrix * vec4(vWorldPosition, 1.0);
    vec3 worldSide = normalize(mat3(modelMatrix) * aSideVector);
    vec4 sideClip = projectionMatrix * viewMatrix * vec4(vWorldPosition + worldSide, 1.0);
    vec2 ndcDelta = sideClip.xy / sideClip.w - clipPosition.xy / clipPosition.w;
    vec2 screenDirection = length(ndcDelta) > 0.00001 ? normalize(ndcDelta) : vec2(1.0, 0.0);
    vec2 pixelToNdc = vec2(2.0 / max(uResolution.x, 1.0), 2.0 / max(uResolution.y, 1.0));
    clipPosition.xy += screenDirection * pixelToNdc * (uPixelWidth * aWidthScale * 0.5) * clipPosition.w * aRibbonSide;
    gl_Position = clipPosition;
  }
`;

const EDGE_FRAGMENT_SHADER = `
  uniform float uOpacity;
  uniform float uBackOpacity;
  uniform float uEnergy;
  uniform float uTime;
  uniform float uShowBack;
  uniform float uWhiteProof;
  uniform float uFacingDebug;
  uniform float uRadiusDebug;
  uniform float uPlanetRadius;

  varying vec3 vSurfaceNormal;
  varying vec3 vWorldPosition;
  varying vec3 vColor;
  varying float vProgress;
  varying float vWeight;
  varying float vPhase;

  void main() {
    vec3 viewDirection = normalize(cameraPosition - vWorldPosition);
    float facing = dot(normalize(vSurfaceNormal), viewDirection);
    float frontMix = smoothstep(-0.18, 0.22, facing);
    float opacity = mix(uBackOpacity, uOpacity, frontMix);

    if (uShowBack < 0.5 && facing < 0.0) discard;

    vec3 color = uWhiteProof > 0.5 ? vec3(1.0) : vColor;
    if (uRadiusDebug > 0.5) {
      float radiusRatio = length(vWorldPosition) / max(uPlanetRadius, 0.001);
      color = radiusRatio < 0.999 ? vec3(1.0, 0.05, 0.08)
        : (radiusRatio > 1.10 ? vec3(1.0, 0.5, 0.05) : vec3(0.15, 1.0, 0.5));
      opacity = 1.0;
    }
    if (uFacingDebug > 0.5) {
      color = facing > 0.22
        ? vec3(0.15, 1.0, 0.38)
        : (facing > -0.18 ? vec3(1.0, 0.78, 0.08) : vec3(1.0, 0.12, 0.18));
      opacity = 1.0;
    }

    float pulse = 0.0;
    if (uEnergy > 0.0) {
      float phase = fract(vProgress + vPhase + uTime * (0.08 + vWeight * 0.12));
      pulse = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.08, 0.22, phase));
    }
    color += pulse * uEnergy * vec3(0.45, 0.7, 0.85);
    float luminance = 0.72 + (vWeight * 0.28) + (pulse * uEnergy * 0.5);
    gl_FragColor = vec4(color * luminance, clamp(opacity, 0.0, 1.0));
  }
`;

function readColor(value, fallback) {
  const color = new THREE.Color();
  try {
    color.set(value || fallback);
  } catch (_) {
    color.set(fallback);
  }
  return color;
}

function toVector(value, radius) {
  if (value?.isVector3) return value.clone().normalize().multiplyScalar(radius);
  const lat = Number(value?.lat || 0) * DEG;
  const lng = Number(value?.lng || 0) * DEG;
  return new THREE.Vector3(
    Math.cos(lat) * Math.cos(lng),
    Math.sin(lat),
    Math.cos(lat) * Math.sin(lng),
  ).normalize().multiplyScalar(radius);
}

function slerpDirection(source, target, t) {
  const a = source.clone().normalize();
  const b = target.clone().normalize();
  const dot = clamp(a.dot(b), -1, 1);
  const angle = Math.acos(dot);
  if (angle < 0.0001) return a;
  if (Math.abs(Math.PI - angle) < 0.0001) {
    const axis = Math.abs(a.x) < 0.8
      ? new THREE.Vector3(1, 0, 0)
      : new THREE.Vector3(0, 1, 0);
    axis.cross(a).normalize();
    return a.clone().applyAxisAngle(axis, Math.PI * t).normalize();
  }
  const sinAngle = Math.sin(angle);
  return a.multiplyScalar(Math.sin((1 - t) * angle) / sinAngle)
    .add(b.multiplyScalar(Math.sin(t * angle) / sinAngle))
    .normalize();
}

// Globe.gl's arc layer builds a cubic Bézier over great-circle control
// points. Reusing that construction here keeps the optional Djinn glow pass
// on exactly the same trajectory as Native Auto/Weighted; it is styling, not
// a second competing path generator.
function nativeControlAltitude(endpointAltitude, arcAltitude) {
  return arcAltitude + (arcAltitude - endpointAltitude)
    * (endpointAltitude < arcAltitude ? 0.5 : 0.25);
}

function cubicBezierPoint(start, controlA, controlB, end, t) {
  const inverse = 1 - t;
  return start.clone().multiplyScalar(inverse ** 3)
    .add(controlA.clone().multiplyScalar(3 * inverse * inverse * t))
    .add(controlB.clone().multiplyScalar(3 * inverse * t * t))
    .add(end.clone().multiplyScalar(t ** 3));
}

function nativeArcPoints(
  source,
  target,
  planetRadius,
  peakAltitude,
  segments,
  sourceAltitude = Math.max(0, source.length() / Math.max(planetRadius, 0.001) - 1),
  targetAltitude = Math.max(0, target.length() / Math.max(planetRadius, 0.001) - 1),
) {
  const sourceDirection = source.clone().normalize();
  const targetDirection = target.clone().normalize();
  const controlAAltitude = nativeControlAltitude(sourceAltitude, peakAltitude);
  const controlBAltitude = nativeControlAltitude(targetAltitude, peakAltitude);
  const controlA = slerpDirection(sourceDirection, targetDirection, 0.25)
    .multiplyScalar(planetRadius * (1 + controlAAltitude));
  const controlB = slerpDirection(sourceDirection, targetDirection, 0.75)
    .multiplyScalar(planetRadius * (1 + controlBAltitude));
  return Array.from({ length: segments + 1 }, (_, index) => {
    const t = index / segments;
    if (index === 0) return source.clone();
    if (index === segments) return target.clone();
    const nativePoint = cubicBezierPoint(source, controlA, controlB, target, t);
    if (nativePoint.length() >= planetRadius) return nativePoint;
    // Globe's normal dataset avoids exact antipodes. For a pathological
    // antipodal pair, its cubic can pass through the origin; keep the same
    // great-circle direction but project only that invalid segment back above
    // the surface so endpoint/radius proofs remain valid.
    const direction = slerpDirection(sourceDirection, targetDirection, t);
    const safetyLift = planetRadius * peakAltitude * Math.sin(Math.PI * t);
    return direction.multiplyScalar(planetRadius + 0.25 + safetyLift);
  });
}

function edgeKey(edge) {
  return edge.id || [edge.source, edge.target].sort().join('::');
}

function compareEdges(a, b) {
  const weightDelta = Number(b.weight || 0) - Number(a.weight || 0);
  if (Math.abs(weightDelta) > 1e-9) return weightDelta;
  return edgeKey(a).localeCompare(edgeKey(b));
}

function communityOf(node) {
  return node?.v3Community ?? node?.communityId ?? node?.community ?? 'default';
}

/**
 * Select a compact, deterministic production edge set. The input remains the
 * complete physics graph; only this visible set is rendered. A spanning tree
 * per community guarantees that connected atoms do not become visual orphans,
 * then a small number of strong local edges and cross-community bridges are
 * added without allowing a single hub to consume the entire bridge budget.
 */
function selectEdgePolicy(edges, nodes, focusNodeId = null) {
  const atomById = new Map(nodes.map((node) => [node.id, node]));
  const byCommunity = new Map();
  const internal = [];
  const external = [];
  edges.forEach((edge) => {
    const source = atomById.get(edge.source);
    const target = atomById.get(edge.target);
    if (!source || !target || edge.source === edge.target) return;
    const sourceCommunity = communityOf(source);
    const targetCommunity = communityOf(target);
    const normalized = {
      ...edge,
      id: edgeKey(edge),
      sourceCommunity,
      targetCommunity,
      isCrossCommunity: sourceCommunity !== targetCommunity,
      isFocused: Boolean(focusNodeId && (edge.source === focusNodeId || edge.target === focusNodeId)),
    };
    if (sourceCommunity === targetCommunity) {
      internal.push(normalized);
      if (!byCommunity.has(sourceCommunity)) byCommunity.set(sourceCommunity, []);
      byCommunity.get(sourceCommunity).push(normalized);
    } else {
      external.push(normalized);
    }
  });

  const selected = new Map();
  const add = (edge, tier = 'surface', required = false) => {
    if (!edge) return;
    const key = edgeKey(edge);
    const previous = selected.get(key);
    if (!previous || required || (tier === 'bridge' && previous.tier !== 'bridge')) {
      selected.set(key, { ...edge, renderTier: tier, required: required || previous?.required });
    }
  };

  // Kruskal maximum spanning forest in each community.
  byCommunity.forEach((communityEdges) => {
    const ids = new Set();
    communityEdges.forEach((edge) => { ids.add(edge.source); ids.add(edge.target); });
    const parent = new Map([...ids].map((id) => [id, id]));
    const find = (id) => {
      let root = id;
      while (parent.get(root) !== root) root = parent.get(root);
      while (parent.get(id) !== id) {
        const next = parent.get(id);
        parent.set(id, root);
        id = next;
      }
      return root;
    };
    const union = (a, b) => {
      const ra = find(a);
      const rb = find(b);
      if (ra === rb) return false;
      parent.set(ra, rb);
      return true;
    };
    [...communityEdges].sort(compareEdges).forEach((edge) => {
      if (union(edge.source, edge.target)) add(edge, 'surface', true);
    });
  });

  // Add two stable local neighbours per node. This keeps the surface dense
  // enough to read without returning to the several-thousand-edge spaghetti.
  const perNode = new Map();
  internal.forEach((edge) => {
    if (!perNode.has(edge.source)) perNode.set(edge.source, []);
    if (!perNode.has(edge.target)) perNode.set(edge.target, []);
    perNode.get(edge.source).push(edge);
    perNode.get(edge.target).push(edge);
  });
  perNode.forEach((list) => list.sort(compareEdges));
  nodes.forEach((node) => {
    (perNode.get(node.id) || []).slice(0, 2).forEach((edge) => add(edge, 'surface', false));
  });

  // Strongest 1-5 edges per community pair, then cap endpoint participation.
  const byPair = new Map();
  external.forEach((edge) => {
    const pair = [edge.sourceCommunity, edge.targetCommunity].sort().join('::');
    if (!byPair.has(pair)) byPair.set(pair, []);
    byPair.get(pair).push(edge);
  });
  const candidateBridges = [];
  byPair.forEach((list) => {
    [...list].sort(compareEdges).slice(0, 5).forEach((edge) => candidateBridges.push(edge));
  });
  candidateBridges.sort(compareEdges);
  const sourceCounts = new Map();
  const targetCounts = new Map();
  const communityPairs = new Set();
  candidateBridges.forEach((edge) => {
    if (communityPairs.has([edge.sourceCommunity, edge.targetCommunity].sort().join('::'))
      && (sourceCounts.get(edge.source) || 0) >= 2
      && (targetCounts.get(edge.target) || 0) >= 2) return;
    if ((sourceCounts.get(edge.source) || 0) >= 2 || (targetCounts.get(edge.target) || 0) >= 2) return;
    if (communityPairs.size >= 40 && !communityPairs.has([edge.sourceCommunity, edge.targetCommunity].sort().join('::'))) return;
    add(edge, 'bridge', false);
    sourceCounts.set(edge.source, (sourceCounts.get(edge.source) || 0) + 1);
    targetCounts.set(edge.target, (targetCounts.get(edge.target) || 0) + 1);
    communityPairs.add([edge.sourceCommunity, edge.targetCommunity].sort().join('::'));
  });

  // A connected node without an internal edge gets its strongest external
  // edge as a bridge. Truly isolated atoms are reported, never fabricated.
  const visibleDegree = new Map();
  selected.forEach((edge) => {
    visibleDegree.set(edge.source, (visibleDegree.get(edge.source) || 0) + 1);
    visibleDegree.set(edge.target, (visibleDegree.get(edge.target) || 0) + 1);
  });
  const externalByNode = new Map();
  external.forEach((edge) => {
    [edge.source, edge.target].forEach((id) => {
      if (!externalByNode.has(id)) externalByNode.set(id, []);
      externalByNode.get(id).push(edge);
    });
  });
  nodes.forEach((node) => {
    if (visibleDegree.has(node.id)) return;
    const fallback = (externalByNode.get(node.id) || []).sort(compareEdges)[0];
    if (fallback) add(fallback, 'bridge', true);
  });

  const result = [...selected.values()].sort((a, b) => edgeKey(a).localeCompare(edgeKey(b)));
  const inputDegree = new Map();
  edges.forEach((edge) => {
    inputDegree.set(edge.source, (inputDegree.get(edge.source) || 0) + 1);
    inputDegree.set(edge.target, (inputDegree.get(edge.target) || 0) + 1);
  });
  const visibleDegreeFinal = new Map();
  result.forEach((edge) => {
    visibleDegreeFinal.set(edge.source, (visibleDegreeFinal.get(edge.source) || 0) + 1);
    visibleDegreeFinal.set(edge.target, (visibleDegreeFinal.get(edge.target) || 0) + 1);
  });
  return {
    edges: result,
    spanningTreeEdgeCount: result.filter((edge) => edge.required && edge.renderTier === 'surface').length,
    isolatedNodeCount: nodes.filter((node) => (inputDegree.get(node.id) || 0) > 0 && !(visibleDegreeFinal.get(node.id) || 0)).length,
    averageVisibleDegree: nodes.length ? [...visibleDegreeFinal.values()].reduce((sum, degree) => sum + degree, 0) / nodes.length : 0,
  };
}

function edgePass(edge, atomById) {
  if (edge.arcPass && PASS_NAMES.includes(edge.arcPass)) return edge.arcPass;
  const source = atomById.get(edge.source);
  const target = atomById.get(edge.target);
  if (source?.v3Community !== target?.v3Community) return 'bridge';
  return Number(edge.weight || 0) >= 0.42 ? 'structure' : 'background';
}

function makeMaterial(pass, config) {
  const uniforms = {
    uPixelWidth: { value: config.width },
    uResolution: { value: new THREE.Vector2(390, 230) },
    uOpacity: { value: config.frontOpacity },
    uBackOpacity: { value: config.backOpacity },
    uEnergy: { value: config.energy },
    uTime: { value: 0 },
    uShowBack: { value: 1 },
    uWhiteProof: { value: 0 },
    uFacingDebug: { value: 0 },
    uRadiusDebug: { value: 0 },
    uPlanetRadius: { value: DEFAULT_PLANET_RADIUS },
  };
  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: EDGE_VERTEX_SHADER,
    fragmentShader: EDGE_FRAGMENT_SHADER,
    transparent: true,
    depthTest: true,
    depthWrite: false,
    side: THREE.DoubleSide,
    blending: THREE.AdditiveBlending,
  });
  material.name = `DjinnEdgeMaterial:${pass}`;
  material.userData.pass = pass;
  return material;
}

export class DjinnEdgeLayer {
  constructor({ globe, scene, planetRadius, forceGraph = null, forceLinkCount = 0, onEdgeClick = null, nodeObjects = null, planetGraphRoot = null, bridgeRenderer = 'native-weighted' } = {}) {
    if (!globe && !scene) throw new Error('DjinnEdgeLayer requires a Globe.gl instance or Three.js scene');
    this.globe = globe || null;
    this.forceGraph = forceGraph || null;
    this.composer = globe?.postProcessingComposer?.() || null;
    this.onEdgeClick = typeof onEdgeClick === 'function' ? onEdgeClick : null;
    this.scene = scene || globe.scene();
    this.planetRadius = Number(planetRadius || globe?.getGlobeRadius?.() || DEFAULT_PLANET_RADIUS);
    this.nodeObjects = nodeObjects instanceof Map ? nodeObjects : null;
    this.lastNodeRegistryCount = this.nodeObjects?.size || 0;
    this.planetGraphRoot = planetGraphRoot || new THREE.Group();
    this.ownsPlanetGraphRoot = !planetGraphRoot;
    this.planetGraphRoot.name = this.planetGraphRoot.name || 'planetGraphRoot';
    if (!this.planetGraphRoot.parent) this.scene.add(this.planetGraphRoot);
    this.group = new THREE.Group();
    this.group.name = 'DjinnEdgeLayer';
    this.group.userData.renderer = 'DjinnEdgeLayer';
    this.group.userData.postProcessingComposer = Boolean(this.composer);
    this.planetGraphRoot.add(this.group);
    this.batches = new Map();
    this.edges = [];
    this.nodes = [];
    this.focusNodeId = null;
    this.selectedEdgeId = null;
    this.diagnosticMode = 'all';
    this.showBack = true;
    this.enabled = true;
    this.localEdgesVisible = true;
    this.remoteEdgesVisible = true;
    this.renderBridges = true;
    this.bridgeRenderer = bridgeRenderer === 'native-auto' ? 'native-auto' : 'native-weighted';
    this.lastRenderBridges = true;
    this.rebuildCount = 0;
    this.geodesicSegments = 0;
    this.forceLinkCount = forceLinkCount;
    this.forceVisibleLinkCount = 0;
    this.lastCameraDistance = 0;
    this.pickRecords = [];
    this.endpointMarkers = null;
    this.bridgeEdges = [];
    this.lastBuildStats = null;
    this.edgePolicyStats = { spanningTreeEdgeCount: 0, isolatedNodeCount: 0, averageVisibleDegree: 0 };
    this.pointerDown = null;
    this.domElement = globe?.renderer?.()?.domElement || null;
    this.onPointerDown = (event) => {
      this.pointerDown = { x: event.clientX, y: event.clientY, time: performance.now() };
    };
    this.onPointerUp = (event) => {
      if (!this.pointerDown || performance.now() - this.pointerDown.time > 360) {
        this.pointerDown = null;
        return;
      }
      const distance = Math.hypot(event.clientX - this.pointerDown.x, event.clientY - this.pointerDown.y);
      this.pointerDown = null;
      if (distance > 8 || !this.enabled) return;
      const edge = this.pickEdgeAt(event.clientX, event.clientY);
      if (edge) {
        this.setSelectedEdge(edge.id);
        this.onEdgeClick?.(edge);
      }
    };
    this.domElement?.addEventListener('pointerdown', this.onPointerDown, { passive: true });
    this.domElement?.addEventListener('pointerup', this.onPointerUp, { passive: true });
    this.setForceGraph(this.forceGraph);
  }

  pickEdgeAt(clientX, clientY) {
    const camera = this.globe?.camera?.();
    const rect = this.domElement?.getBoundingClientRect?.();
    if (!camera || !rect || !this.pickRecords.length) return null;
    const x = clientX - rect.left;
    const y = clientY - rect.top;
    let best = null;
    this.pickRecords.forEach((record) => {
      const edge = record.edge;
      if (!(edge.isFocused || edge.isSelected || edge.arcPass === 'bridge' || Number(edge.weight || 0) >= .75)) return;
      const projected = record.points.map((point) => {
        const ndc = point.clone().project(camera);
        return {
          x: (ndc.x * .5 + .5) * rect.width,
          y: (-ndc.y * .5 + .5) * rect.height,
          z: ndc.z,
        };
      });
      for (let index = 1; index < projected.length; index += 1) {
        const a = projected[index - 1];
        const b = projected[index];
        if ((a.z < -1 && b.z < -1) || (a.z > 1 && b.z > 1)) continue;
        const abx = b.x - a.x;
        const aby = b.y - a.y;
        const lengthSq = (abx * abx) + (aby * aby);
        const t = lengthSq > 0 ? clamp((((x - a.x) * abx) + ((y - a.y) * aby)) / lengthSq, 0, 1) : 0;
        const dx = x - (a.x + (abx * t));
        const dy = y - (a.y + (aby * t));
        const pixelDistance = Math.hypot(dx, dy);
        if (pixelDistance <= 18 && (!best || pixelDistance < best.distance)) {
          best = { edge, distance: pixelDistance };
        }
      }
    });
    return best?.edge || null;
  }

  setForceGraph(forceGraph) {
    this.forceGraph = forceGraph || null;
    if (!this.forceGraph) return;
    // Keep the physical link data in the force engine, but never let its
    // renderer compete with the batched Djinn passes.
    this.forceGraph.linkVisibility?.(false);
    this.forceVisibleLinkCount = 0;
  }

  setForceLinkStats(forceLinkCount, forceVisibleLinkCount = 0) {
    this.forceLinkCount = Number(forceLinkCount || 0);
    this.forceVisibleLinkCount = Number(forceVisibleLinkCount || 0);
  }

  setNodeRegistry({ objects = this.nodeObjects, root = this.planetGraphRoot } = {}) {
    if (objects instanceof Map) this.nodeObjects = objects;
    if (root && root !== this.planetGraphRoot) {
      this.group.removeFromParent();
      this.planetGraphRoot = root;
      this.ownsPlanetGraphRoot = false;
      root.add(this.group);
    }
    return this.nodeObjects;
  }

  getNodeTransform(nodeId, fallbackNode = null) {
    const object = this.nodeObjects?.get(nodeId);
    if (object?.getWorldPosition && this.planetGraphRoot) {
      const worldPosition = object.getWorldPosition(new THREE.Vector3());
      const localPosition = this.planetGraphRoot.worldToLocal(worldPosition.clone());
      const worldScale = object.getWorldScale?.(new THREE.Vector3(1, 1, 1)) || new THREE.Vector3(1, 1, 1);
      const baseRadius = Number(object.userData?.baseRadius || fallbackNode?.renderRadius || fallbackNode?.radius || 0.8);
      return {
        object,
        position: localPosition,
        radius: baseRadius * Math.max(worldScale.x, worldScale.y, worldScale.z),
      };
    }
    // Unit tests can use lat/lng nodes without a registry. Production always
    // passes nodeObjects, so a missing object is counted as an invalid endpoint.
    if (!this.nodeObjects && fallbackNode) {
      return {
        object: null,
        position: toVector(fallbackNode, this.planetRadius),
        radius: Number(fallbackNode.renderRadius || fallbackNode.radius || 0.8),
      };
    }
    return null;
  }

  setEdges(edges = [], nodes = [], {
    planetRadius,
    forceLinkCount,
    nodeObjects,
    planetGraphRoot,
    renderBridges = this.renderBridges,
    bridgeRenderer = this.bridgeRenderer,
  } = {}) {
    const nextRadius = Number(planetRadius || this.planetRadius || DEFAULT_PLANET_RADIUS);
    const nextEdges = Array.isArray(edges) ? edges : [];
    if (forceLinkCount !== undefined) this.forceLinkCount = Number(forceLinkCount || 0);
    if (nodeObjects || planetGraphRoot) this.setNodeRegistry({ objects: nodeObjects, root: planetGraphRoot });
    this.renderBridges = Boolean(renderBridges);
    this.bridgeRenderer = bridgeRenderer === 'native-auto' ? 'native-auto' : 'native-weighted';
    const registryCount = this.nodeObjects?.size || 0;
    const sameInput = this.edges === nextEdges
      && this.nodes === nodes
      && this.planetRadius === nextRadius
      && this.lastNodeRegistryCount === registryCount
      && this.lastRenderBridges === this.renderBridges
      && this.lastBridgeRenderer === this.bridgeRenderer;
    this.lastNodeRegistryCount = registryCount;
    this.lastRenderBridges = this.renderBridges;
    this.lastBridgeRenderer = this.bridgeRenderer;
    this.planetRadius = nextRadius;
    if (sameInput) return this.getDebugStats();
    this.edges = nextEdges;
    this.nodes = Array.isArray(nodes) ? nodes : [];
    this.rebuild();
    return this.getDebugStats();
  }

  setFocus(nodeId) {
    if (this.focusNodeId === (nodeId || null)) return;
    this.focusNodeId = nodeId || null;
    if (this.edges.length) this.rebuild();
  }

  setSelectedEdge(edgeId) {
    if (this.selectedEdgeId === (edgeId || null)) return;
    this.selectedEdgeId = edgeId || null;
    if (this.edges.length) this.rebuild();
  }

  setDiagnostics(mode = 'all') {
    const needsEndpointRebuild = mode === 'endpoint' || this.diagnosticMode === 'endpoint';
    this.diagnosticMode = mode;
    if (needsEndpointRebuild && this.edges.length && ((mode === 'endpoint') !== Boolean(this.endpointMarkers))) {
      this.rebuild();
      return;
    }
    const visiblePass = PASS_NAMES.includes(mode) ? mode : null;
    this.batches.forEach((batch, pass) => {
      const categoryVisible = pass === 'bridge' ? this.remoteEdgesVisible : this.localEdgesVisible;
      batch.mesh.visible = this.enabled && categoryVisible && (!visiblePass || visiblePass === pass);
      batch.material.uniforms.uWhiteProof.value = mode === 'white' || mode === 'endpoint' ? 1 : 0;
      batch.material.uniforms.uFacingDebug.value = mode === 'facing' ? 1 : 0;
      batch.material.uniforms.uRadiusDebug.value = mode === 'radius' ? 1 : 0;
      batch.material.uniforms.uPlanetRadius.value = this.planetRadius;
      batch.material.uniforms.uShowBack.value = this.showBack ? 1 : 0;
    });
  }

  setEdgeVisibility({ local = this.localEdgesVisible, remote = this.remoteEdgesVisible } = {}) {
    this.localEdgesVisible = Boolean(local);
    this.remoteEdgesVisible = Boolean(remote);
    this.setDiagnostics(this.diagnosticMode);
  }

  setDebugOptions({
    showBack = this.showBack,
    facingDebug = this.diagnosticMode === 'facing',
    whiteProof = this.diagnosticMode === 'white' || this.diagnosticMode === 'endpoint',
    radiusDebug = this.diagnosticMode === 'radius',
  } = {}) {
    this.showBack = Boolean(showBack);
    this.batches.forEach((batch) => {
      batch.material.uniforms.uShowBack.value = this.showBack ? 1 : 0;
      batch.material.uniforms.uFacingDebug.value = facingDebug ? 1 : 0;
      batch.material.uniforms.uWhiteProof.value = whiteProof ? 1 : 0;
      batch.material.uniforms.uRadiusDebug.value = radiusDebug ? 1 : 0;
      batch.material.uniforms.uPlanetRadius.value = this.planetRadius;
    });
  }

  setVisible(visible) {
    this.enabled = Boolean(visible);
    this.group.visible = this.enabled;
    this.setDiagnostics(this.diagnosticMode);
  }

  updateCamera(camera = this.globe?.camera?.()) {
    if (!camera) return;
    this.lastCameraDistance = camera.position.length() / Math.max(this.planetRadius, 1);
    const width = this.domElement?.clientWidth || 390;
    const height = this.domElement?.clientHeight || 230;
    this.batches.forEach((batch) => {
      batch.material.uniforms.uShowBack.value = this.showBack ? 1 : 0;
      batch.material.uniforms.uResolution.value.set(width, height);
    });
  }

  updateTime(time = performance.now() / 1000) {
    this.batches.forEach((batch) => {
      batch.material.uniforms.uTime.value = time;
    });
  }

  rebuild() {
    this.disposeBatches();
    this.disposeEndpointMarkers();
    this.pickRecords = [];
    this.bridgeEdges = [];
    const atomById = new Map(this.nodes.map((node) => [node.id, node]));
    const groups = new Map(PASS_NAMES.map((pass) => [pass, []]));
    const policy = selectEdgePolicy(this.edges, this.nodes, this.focusNodeId);
    this.edgePolicyStats = {
      spanningTreeEdgeCount: policy.spanningTreeEdgeCount,
      isolatedNodeCount: policy.isolatedNodeCount,
      averageVisibleDegree: policy.averageVisibleDegree,
    };
    const sorted = [...policy.edges].sort(compareEdges);
    this.planetGraphRoot.updateMatrixWorld?.(true);

    let invalidEndpointCount = this.edges.filter((edge) => !atomById.has(edge.source) || !atomById.has(edge.target)).length;
    let zeroLengthCount = 0;
    let missingNodeCount = 0;
    sorted.forEach((edge) => {
      const source = atomById.get(edge.source);
      const target = atomById.get(edge.target);
      if (!source || !target) {
        return;
      }
      const sourceTransform = this.getNodeTransform(edge.source, source);
      const targetTransform = this.getNodeTransform(edge.target, target);
      if (!sourceTransform || !targetTransform) {
        invalidEndpointCount += 1;
        missingNodeCount += 1;
        return;
      }
      const sourceVector = sourceTransform.position.clone();
      const targetVector = targetTransform.position.clone();
      if (sourceVector.distanceToSquared(targetVector) < 0.000001) {
        zeroLengthCount += 1;
        return;
      }
      const pass = edge.renderTier === 'bridge' ? 'bridge' : 'structure';
      const surfacePass = pass === 'bridge' ? 'bridge' : (edge.required ? 'structure' : 'background');
      const renderPass = edge.renderTier === 'bridge' ? 'bridge' : surfacePass;
      const isFocused = Boolean(this.focusNodeId && (edge.source === this.focusNodeId || edge.target === this.focusNodeId));
      const isSelected = Boolean(this.selectedEdgeId && edgeKey(edge) === this.selectedEdgeId);
      const profile = renderPass === 'bridge'
        ? bridgeProfile({ ...edge, isFocused, isSelected }, sourceVector, targetVector, this.planetRadius, this.bridgeRenderer)
        : null;
      groups.get(renderPass)?.push({
        ...edge,
        id: edgeKey(edge),
        sourceCommunity: communityOf(source),
        targetCommunity: communityOf(target),
        sourcePosition: sourceVector,
        targetPosition: targetVector,
        sourceRadius: sourceTransform.radius,
        targetRadius: targetTransform.radius,
        isCrossCommunity: communityOf(source) !== communityOf(target),
        isFocused,
        isSelected,
        ...(profile || {}),
        renderTier: renderPass,
      });
    });

    let geodesicSegments = 0;
    let endpointMaxError = 0;
    let radiusInsideCount = 0;
    let surfaceMinRadius = Number.POSITIVE_INFINITY;
    let bridgeMaxRadius = 0;
    const endpointPoints = [];
    const passCounts = {};
    PASS_NAMES.forEach((pass) => {
      const config = PASS_CONFIG[pass];
      const selectedPassEdges = groups.get(pass).slice(0, config.maxEdges);
      const passEdges = pass === 'bridge' && !this.renderBridges ? [] : selectedPassEdges;
      const result = this.createBatch(pass, passEdges, config);
      if (result) {
        this.batches.set(pass, result);
        this.group.add(result.mesh);
        this.pickRecords.push(...result.pickRecords);
        endpointPoints.push(...(result.endpointPoints || []));
        geodesicSegments += result.segmentCount;
        endpointMaxError = Math.max(endpointMaxError, result.endpointMaxError || 0);
        radiusInsideCount += result.radiusInsideCount || 0;
        surfaceMinRadius = Math.min(surfaceMinRadius, result.surfaceMinRadius ?? Number.POSITIVE_INFINITY);
        bridgeMaxRadius = Math.max(bridgeMaxRadius, result.bridgeMaxRadius || 0);
      }
      passCounts[pass] = selectedPassEdges.length;
      if (pass === 'bridge') this.bridgeEdges = selectedPassEdges;
    });
    this.geodesicSegments = geodesicSegments;
    this.rebuildCount += 1;
    if (this.diagnosticMode === 'endpoint' && endpointPoints.length) {
      const markerPositions = [];
      const markerColors = [];
      endpointPoints.forEach(({ point, color }) => {
        markerPositions.push(point.x, point.y, point.z);
        markerColors.push(color[0], color[1], color[2]);
      });
      const markerGeometry = new THREE.BufferGeometry();
      markerGeometry.setAttribute('position', new THREE.Float32BufferAttribute(markerPositions, 3));
      markerGeometry.setAttribute('color', new THREE.Float32BufferAttribute(markerColors, 3));
      const markerMaterial = new THREE.PointsMaterial({ size: 4, sizeAttenuation: false, vertexColors: true, depthTest: false, depthWrite: false });
      this.endpointMarkers = new THREE.Points(markerGeometry, markerMaterial);
      this.endpointMarkers.name = 'DjinnEdgeEndpointProof';
      this.group.add(this.endpointMarkers);
    }
    this.setDiagnostics(this.diagnosticMode);
    this.lastBuildStats = {
      invalidEndpointCount,
      missingNodeCount,
      zeroLengthCount,
      passCounts,
      spanningTreeEdgeCount: policy.spanningTreeEdgeCount,
      isolatedNodeCount: policy.isolatedNodeCount,
      averageVisibleDegree: policy.averageVisibleDegree,
      endpointMaxError,
      radiusInsideCount,
      surfaceMinRadius: Number.isFinite(surfaceMinRadius) ? surfaceMinRadius : 0,
      bridgeMaxRadius,
    };
  }

  createBatch(pass, edges, config) {
    if (!edges.length) return null;
    const positions = [];
    const normals = [];
    const colors = [];
    const progress = [];
    const weights = [];
    const phases = [];
    const sideVectors = [];
    const ribbonSides = [];
    const widthScales = [];
    const indices = [];
    const pickRecords = [];
    let vertexOffset = 0;
    let segmentCount = 0;
    let endpointMaxError = 0;
    let radiusInsideCount = 0;
    let surfaceMinRadius = Number.POSITIVE_INFINITY;
    let bridgeMaxRadius = 0;
    const endpointPoints = [];
    const defaultColor = readColor(config.color, '#8E6BFF');

    edges.forEach((edge, edgeIndex) => {
      const source = edge.sourcePosition;
      const target = edge.targetPosition;
      const sourceDirection = source.clone().normalize();
      const targetDirection = target.clone().normalize();
      const angle = Math.acos(clamp(sourceDirection.dot(targetDirection), -1, 1));
      const angleDegrees = angle / DEG;
      const segments = clamp(
        Math.ceil(angleDegrees / 7),
        config.segmentsMin,
        edge.isFocused || edge.isSelected ? 72 : config.segmentsMax,
      );
      segmentCount += segments;
      const weight = clamp(Number(edge.weight || 0), 0, 1);
      const widthScale = edge.isSelected
        ? 1.45
        : (edge.isFocused ? 1.18 : (pass === 'bridge' && weight >= .8 ? 1.05 : 1));
      const edgeColor = this.diagnosticMode === 'white'
        ? readColor('#FFFFFF', '#FFFFFF')
        : pass === 'bridge'
          ? readColor(edge.bridgeTier === 'hero' ? '#FFB347' : (edge.bridgeTier === 'major' ? '#FF933C' : '#F07832'), '#FF933C')
          : defaultColor;
      const phase = ((edgeIndex * 0.61803398875) % 1);
      const startVertex = vertexOffset;
      const sourceRadius = source.length();
      const targetRadius = target.length();
      const customBridgeProfile = pass === 'bridge'
        ? (edge.peakAltitude !== undefined
          ? edge
          : bridgeProfile(edge, source, target, this.planetRadius, this.bridgeRenderer))
        : null;
      // Bridge overlays deliberately reuse the Globe.gl Native Weighted cubic
      // great-circle trajectory. Surface edges remain low geodesic ribbons.
      const edgePoints = pass === 'bridge'
        ? nativeArcPoints(
          source,
          target,
          this.planetRadius,
          customBridgeProfile.nativePeakAltitude ?? customBridgeProfile.peakAltitude,
          segments,
          customBridgeProfile.sourceAltitude,
          customBridgeProfile.targetAltitude,
        )
        : Array.from({ length: segments + 1 }, (_, index) => {
          const t = index / segments;
          if (index === 0) return source.clone();
          if (index === segments) return target.clone();
          const direction = slerpDirection(sourceDirection, targetDirection, t);
          const endpointSurfaceRadius = (sourceRadius * (1 - t)) + (targetRadius * t);
          const radialLift = this.planetRadius * clamp(config.altitude, 0.003, 0.008) * Math.sin(Math.PI * t);
          return direction.multiplyScalar(Math.max(this.planetRadius + 0.25, endpointSurfaceRadius + radialLift));
        });

      for (let index = 0; index <= segments; index += 1) {
        const t = index / segments;
        const point = edgePoints[index];
        const previous = edgePoints[Math.max(0, index - 1)].clone();
        const next = edgePoints[Math.min(segments, index + 1)].clone();
        const tangent = next.sub(previous).normalize();
        const surfaceNormal = point.clone().normalize();
        let side = new THREE.Vector3().crossVectors(tangent, surfaceNormal).normalize();
        if (side.lengthSq() < 0.000001) side = new THREE.Vector3(1, 0, 0);
        // The geometry stores a centerline twice; the shader expands it in
        // screen pixels using the tangent side vector and ribbon side sign.
        positions.push(point.x, point.y, point.z, point.x, point.y, point.z);
        sideVectors.push(side.x, side.y, side.z, side.x, side.y, side.z);
        ribbonSides.push(-1, 1);
        // Taper only the final pixels into the node. This keeps the measured
        // endpoint exact instead of visually shifting it by half a ribbon.
        const endpointTaper = (index === 0 || index === segments)
          ? 0.05
          : ((index === 1 || index === segments - 1) ? 0.65 : 1);
        widthScales.push(widthScale * endpointTaper, widthScale * endpointTaper);
        normals.push(surfaceNormal.x, surfaceNormal.y, surfaceNormal.z, surfaceNormal.x, surfaceNormal.y, surfaceNormal.z);
        colors.push(edgeColor.r, edgeColor.g, edgeColor.b, edgeColor.r, edgeColor.g, edgeColor.b);
        progress.push(t, t);
        weights.push(weight, weight);
        phases.push(phase, phase);
        if (index < segments) {
          const a = vertexOffset;
          const b = vertexOffset + 1;
          const c = vertexOffset + 2;
          const d = vertexOffset + 3;
          indices.push(a, b, c, b, d, c);
          vertexOffset += 2;
        }
      }
      endpointMaxError = Math.max(
        endpointMaxError,
        edgePoints[0].distanceTo(source),
        edgePoints[edgePoints.length - 1].distanceTo(target),
      );
      endpointPoints.push({ point: edgePoints[0].clone(), color: [0.1, 1, 0.2] });
      endpointPoints.push({ point: edgePoints[edgePoints.length - 1].clone(), color: [1, 0.1, 0.1] });
      endpointPoints.push({ point: edgePoints[0].clone(), color: [1, 1, 1] });
      endpointPoints.push({ point: edgePoints[edgePoints.length - 1].clone(), color: [1, 0.9, 0.1] });
      edgePoints.forEach((point) => {
        const radius = point.length();
        if (radius < this.planetRadius - 0.001) radiusInsideCount += 1;
        if (pass === 'bridge') bridgeMaxRadius = Math.max(bridgeMaxRadius, radius);
        else surfaceMinRadius = Math.min(surfaceMinRadius, radius);
      });
      // The final pair belongs to this edge, and the next edge starts after it.
      vertexOffset = startVertex + ((segments + 1) * 2);
      if (edge.isFocused || edge.isSelected || pass === 'bridge' || weight >= .75) {
        pickRecords.push({ edge, points: edgePoints });
      }
    });

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('aSurfaceNormal', new THREE.Float32BufferAttribute(normals, 3));
    geometry.setAttribute('aColor', new THREE.Float32BufferAttribute(colors, 3));
    geometry.setAttribute('aProgress', new THREE.Float32BufferAttribute(progress, 1));
    geometry.setAttribute('aWeight', new THREE.Float32BufferAttribute(weights, 1));
    geometry.setAttribute('aPhase', new THREE.Float32BufferAttribute(phases, 1));
    geometry.setAttribute('aSideVector', new THREE.Float32BufferAttribute(sideVectors, 3));
    geometry.setAttribute('aRibbonSide', new THREE.Float32BufferAttribute(ribbonSides, 1));
    geometry.setAttribute('aWidthScale', new THREE.Float32BufferAttribute(widthScales, 1));
    geometry.setIndex(indices);
    geometry.computeBoundingSphere();
    const material = makeMaterial(pass, config);
    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = `DjinnEdgeBatch:${pass}`;
    mesh.frustumCulled = false;
    mesh.userData.edgeCount = edges.length;
    mesh.userData.segmentCount = segmentCount;
    mesh.onBeforeRender = (_renderer, _scene, camera) => {
      material.uniforms.uTime.value = performance.now() / 1000;
      if (camera?.position) this.lastCameraDistance = camera.position.length() / Math.max(this.planetRadius, 1);
    };
    return {
      mesh,
      geometry,
      material,
      edgeCount: edges.length,
      segmentCount,
      pickRecords,
      endpointPoints,
      endpointMaxError,
      radiusInsideCount,
      surfaceMinRadius,
      bridgeMaxRadius,
    };
  }

  getDebugStats() {
    const passCounts = this.lastBuildStats?.passCounts || { background: 0, structure: 0, bridge: 0 };
    const geometryCount = [...this.batches.values()].length;
    return {
      forceLinkCount: this.forceLinkCount,
      forceVisibleLinkCount: this.forceVisibleLinkCount,
      inputEdgeCount: this.edges.length,
      validEdgeCount: this.edges.length - (this.lastBuildStats?.invalidEndpointCount || 0) - (this.lastBuildStats?.zeroLengthCount || 0),
      invalidEndpointCount: this.lastBuildStats?.invalidEndpointCount || 0,
      missingNodeCount: this.lastBuildStats?.missingNodeCount || 0,
      zeroLengthCount: this.lastBuildStats?.zeroLengthCount || 0,
      backgroundEdgeCount: passCounts.background,
      structureEdgeCount: passCounts.structure,
      bridgeEdgeCount: passCounts.bridge,
      interactiveEdgeCount: this.edges.filter((edge) => edge.isFocused || edge.isSelected || edge.arcPass === 'bridge').length,
      renderedEdgeCount: [...this.batches.values()].reduce((sum, batch) => sum + batch.edgeCount, 0),
      geodesicSegments: this.geodesicSegments,
      vertexCount: [...this.batches.values()].reduce((sum, batch) => sum + (batch.geometry.getAttribute('position')?.count || 0), 0),
      geometryCount,
      materialCount: geometryCount,
      drawCallCount: geometryCount,
      rebuildCount: this.rebuildCount,
      lod: this.lastCameraDistance > 2.55 ? 'far' : (this.lastCameraDistance < 1.68 ? 'near' : 'medium'),
      diagnosticMode: this.diagnosticMode,
      frontOpacity: PASS_CONFIG.structure.frontOpacity,
      backOpacity: PASS_CONFIG.structure.backOpacity,
      spanningTreeEdgeCount: this.lastBuildStats?.spanningTreeEdgeCount || 0,
      isolatedNodeCount: this.lastBuildStats?.isolatedNodeCount || 0,
      averageVisibleDegree: this.lastBuildStats?.averageVisibleDegree || 0,
      endpointMaxError: this.lastBuildStats?.endpointMaxError || 0,
      radiusInsideCount: this.lastBuildStats?.radiusInsideCount || 0,
      surfaceMinRadius: this.lastBuildStats?.surfaceMinRadius || 0,
      bridgeMaxRadius: this.lastBuildStats?.bridgeMaxRadius || 0,
    };
  }

  getBridgeEdges() {
    return this.bridgeEdges.map((edge) => ({
      ...edge,
      sourcePosition: edge.sourcePosition?.clone?.() || edge.sourcePosition,
      targetPosition: edge.targetPosition?.clone?.() || edge.targetPosition,
    }));
  }

  disposeBatches() {
    this.batches.forEach((batch) => {
      batch.mesh.onBeforeRender = null;
      batch.geometry.dispose();
      batch.material.dispose();
      this.group.remove(batch.mesh);
    });
    this.batches.clear();
  }

  disposeEndpointMarkers() {
    if (!this.endpointMarkers) return;
    this.endpointMarkers.geometry?.dispose?.();
    this.endpointMarkers.material?.dispose?.();
    this.endpointMarkers.removeFromParent();
    this.endpointMarkers = null;
  }

  dispose() {
    this.domElement?.removeEventListener('pointerdown', this.onPointerDown);
    this.domElement?.removeEventListener('pointerup', this.onPointerUp);
    this.disposeBatches();
    this.disposeEndpointMarkers();
    this.group.removeFromParent();
    if (this.ownsPlanetGraphRoot) this.planetGraphRoot?.removeFromParent();
    this.edges = [];
    this.nodes = [];
    this.pickRecords = [];
    this.globe = null;
    this.forceGraph = null;
    this.scene = null;
    this.nodeObjects = null;
    this.planetGraphRoot = null;
  }
}

export const __djinnEdgeLayerTest = Object.freeze({
  PASS_NAMES,
  PASS_CONFIG,
  NATIVE_AUTO_MAX_ALTITUDE,
  NATIVE_WEIGHTED_MAX_ALTITUDE,
  bridgeProfile,
  nativeArcPoints,
  slerpDirection,
  selectEdgePolicy,
});
