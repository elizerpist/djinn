// Deterministic Explore planet data and geometry.  Browser lifecycle code
// intentionally stays in explore-galaxy-orb.js; this module owns only data
// construction and pure layout/selection mapping helpers.
import { knowledgeEdges, knowledgeNodes } from '../knowledge-map.js?rev=138';
import * as THREE from '../vendor/three.module.min.js?rev=92';
import {
  SURFACE_SELECTION_ARC_PROFILE,
  clearCityConnections,
  isSurfaceSelectionArc,
  selectCityConnections,
} from '../city-selection-arcs.js?rev=9';
import { DJINN_ORB_V5 } from './planet-visuals.js?rev=1';

const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
const V3_ATOM_COUNT = 700;

export const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export const ORB_POINTS = knowledgeNodes.map((node, index) => {
  const latitude = -72 + ((index + .5) / knowledgeNodes.length) * 144;
  const longitude = ((index * GOLDEN_ANGLE * 180 / Math.PI + 180) % 360) - 180;
  return { ...node, lat: latitude, lng: longitude, label: node.title };
});

const pointById = new Map(ORB_POINTS.map((point) => [point.id, point]));
export const ORB_ARCS = knowledgeEdges
  .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
  .map((edge) => ({
    ...edge,
    startLat: pointById.get(edge.source).lat,
    startLng: pointById.get(edge.source).lng,
    endLat: pointById.get(edge.target).lat,
    endLng: pointById.get(edge.target).lng,
  }));

// These maps are intentionally mutable: runtime V3 layout coordinates update
// the same objects used by pointer hit-testing and the V5-family controller.
export const nodeById = new Map(ORB_POINTS.map((node) => [node.id, node]));
export const degreeById = new Map(ORB_POINTS.map((node) => [node.id, 0]));
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

export function nodeRadius(degree) {
  const t = maxDegree <= minDegree ? 0 : Math.sqrt(clamp((degree - minDegree) / (maxDegree - minDegree), 0, 1));
  return 1.6 + t * 3.6;
}

export const typeColors = Object.freeze({
  topic: '#6B3EF6', condition: '#8A63E8', measurement: '#B9B0E6', concept: '#7C4DFF',
  treatment: '#9B7BFF', procedure: '#8276BA', symptom: '#C58BDF', source: '#6D75C8',
});
export const arcPalette = Object.freeze(['#8E6BFF', '#C084FC', '#60A5FA', '#F0ABFC', '#A78BFA', '#67E8F9', '#F9A8D4']);

function stableV3Hash(value) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function v3SphereVector(index, total, radius = 1) {
  const y = 1 - (2 * (index + .5)) / total;
  const ring = Math.sqrt(Math.max(0, 1 - (y * y)));
  const theta = index * GOLDEN_ANGLE;
  return new THREE.Vector3(
    Math.cos(theta) * ring * radius,
    y * radius,
    Math.sin(theta) * ring * radius,
  );
}

function buildV3StressData() {
  const base = [...knowledgeNodes].sort((a, b) => a.id.localeCompare(b.id));
  const atoms = [];
  for (let index = 0; index < V3_ATOM_COUNT; index += 1) {
    const source = base[index % base.length];
    const isOriginal = index < base.length;
    atoms.push({
      ...(isOriginal ? source : {
        id: `v3_atom_${String(index).padStart(3, '0')}`,
        title: `Fogalom ${String(index + 1).padStart(3, '0')}`,
        subtitle: 'Determinista stresszteszt atom',
        type: 'concept',
        importance: .35 + ((index * 17) % 60) / 100,
        validated: index % 5 !== 0,
        sourceName: 'V3 stresszteszt',
      }),
      label: isOriginal ? source.title : `Fogalom ${String(index + 1).padStart(3, '0')}`,
      altitude: .014,
      v3Index: index,
      v3Community: stableV3Hash(isOriginal ? source.id : `v3_atom_${index}`) % 10,
    });
  }
  const atomIds = atoms.map((atom) => atom.id);
  const atomSet = new Set(atomIds);
  const edges = [];
  const physicsKeys = new Set();
  const addEdge = (source, target, weight) => {
    if (!source || !target || source === target || !atomSet.has(source) || !atomSet.has(target)) return;
    const key = [source, target].sort().join('::');
    if (physicsKeys.has(key)) return;
    physicsKeys.add(key);
    edges.push({ source, target, weight: clamp(weight, .12, .99), physicsOnly: true });
  };
  knowledgeEdges.forEach((edge) => {
    if (atomSet.has(edge.source) && atomSet.has(edge.target)) addEdge(edge.source, edge.target, edge.weight || .4);
  });
  for (let index = 0; index < V3_ATOM_COUNT; index += 1) {
    const source = atomIds[index];
    addEdge(source, atomIds[(index + 1) % V3_ATOM_COUNT], .34 + ((index % 9) * .025));
    addEdge(source, atomIds[(index + 7) % V3_ATOM_COUNT], .24 + ((index % 11) * .021));
    addEdge(source, atomIds[(index + 31) % V3_ATOM_COUNT], .18 + ((index % 13) * .019));
    if (index % 3 === 0) addEdge(source, atomIds[(index + 113) % V3_ATOM_COUNT], .21 + ((index % 7) * .018));
  }
  return { atoms, edges };
}

const V3_STRESS_DATA = buildV3StressData();
export const V3_BASE_ATOMS = V3_STRESS_DATA.atoms;
export const V3_PHYSICS_EDGES = V3_STRESS_DATA.edges;
export const V3_DEGREE_BY_ID = new Map(V3_BASE_ATOMS.map((atom) => [atom.id, 0]));
V3_PHYSICS_EDGES.forEach((edge) => {
  V3_DEGREE_BY_ID.set(edge.source, (V3_DEGREE_BY_ID.get(edge.source) || 0) + 1);
  V3_DEGREE_BY_ID.set(edge.target, (V3_DEGREE_BY_ID.get(edge.target) || 0) + 1);
});
const V3_DEGREES = [...V3_DEGREE_BY_ID.values()];
const V3_MIN_DEGREE = Math.min(...V3_DEGREES);
const V3_MAX_DEGREE = Math.max(...V3_DEGREES);

export const V5_SIZE_DEFAULTS = Object.freeze({
  metric: 'weighted-degree',
  curve: 'quantile-tiers',
  baseRadius: 1.5,
  minRadius: 1.5,
  maxRadius: 1.5,
  hubMultiplier: 3.5,
  farLodMin: .78,
  perspective: .045,
  halo: 1.58,
  collisionPadding: .28,
});
const V5_TIER_MULTIPLIERS = Object.freeze([.55, .8, 1.15, 1.8, 3.5]);

function percentile(sorted, ratio) {
  if (!sorted.length) return 0;
  const index = clamp(ratio, 0, 1) * (sorted.length - 1);
  const lower = Math.floor(index);
  const upper = Math.ceil(index);
  return sorted[lower] + ((sorted[upper] - sorted[lower]) * (index - lower));
}

function weightedDegreeMap(atoms, edges) {
  const values = new Map(atoms.map((atom) => [atom.id, 0]));
  edges.forEach((edge) => {
    if (!values.has(edge.source) || !values.has(edge.target)) return;
    const weight = clamp(Number(edge.weight) || 0, 0, 1);
    values.set(edge.source, values.get(edge.source) + weight);
    values.set(edge.target, values.get(edge.target) + weight);
  });
  return values;
}

function plainDegreeMap(atoms, edges) {
  const values = new Map(atoms.map((atom) => [atom.id, 0]));
  edges.forEach((edge) => {
    if (!values.has(edge.source) || !values.has(edge.target)) return;
    values.set(edge.source, values.get(edge.source) + 1);
    values.set(edge.target, values.get(edge.target) + 1);
  });
  return values;
}

export function quantileRank(value, sorted) {
  if (sorted.length < 2) return 0;
  let lower = 0;
  let upper = sorted.length - 1;
  while (lower < upper) {
    const middle = Math.floor((lower + upper) / 2);
    if (sorted[middle] < value) lower = middle + 1;
    else upper = middle;
  }
  const first = lower;
  lower = first;
  upper = sorted.length - 1;
  while (lower < upper) {
    const middle = Math.ceil((lower + upper) / 2);
    if (sorted[middle] > value) upper = middle - 1;
    else lower = middle;
  }
  return clamp(((first + lower) * .5) / (sorted.length - 1), 0, 1);
}

export function interpolate(value, from, to, start, end) {
  if (to <= from) return end;
  return start + ((end - start) * clamp((value - from) / (to - from), 0, 1));
}

function v5QuantileTierScale(rank, multipliers = V5_TIER_MULTIPLIERS) {
  if (rank < .4) return interpolate(rank, 0, .4, multipliers[0], multipliers[1] * .9);
  if (rank < .7) return interpolate(rank, .4, .7, multipliers[1], multipliers[2] * .92);
  if (rank < .9) return interpolate(rank, .7, .9, multipliers[2], multipliers[3] * .88);
  if (rank < .98) return interpolate(rank, .9, .98, multipliers[3], multipliers[4] * .72);
  return interpolate(rank, .98, 1, multipliers[4] * .8, multipliers[4]);
}

export function v5TierForRank(rank) {
  if (rank < .4) return 'micro';
  if (rank < .7) return 'small';
  if (rank < .9) return 'medium';
  if (rank < .98) return 'large';
  return 'hub';
}

export function v5ImportanceScale(rank, curve = 'quantile-tiers', hubMultiplier = V5_SIZE_DEFAULTS.hubMultiplier) {
  const normalized = clamp(rank, 0, 1);
  if (curve === 'linear') return .55 + ((hubMultiplier - .55) * normalized);
  if (curve === 'sqrt') return .55 + ((hubMultiplier - .55) * Math.sqrt(normalized));
  if (curve === 'log') return .55 + ((hubMultiplier - .55) * (Math.log1p(normalized * 15) / Math.log(16)));
  const multipliers = [...V5_TIER_MULTIPLIERS.slice(0, 4), hubMultiplier];
  return v5QuantileTierScale(normalized, multipliers);
}

function v5BridgeNodeIds(atoms, edges, weightedDegrees) {
  const byId = new Map(atoms.map((atom) => [atom.id, atom]));
  const score = new Map(atoms.map((atom) => [atom.id, 0]));
  edges.forEach((edge) => {
    const source = byId.get(edge.source);
    const target = byId.get(edge.target);
    if (!source || !target || source.v3Community === target.v3Community) return;
    const value = Number(edge.weight) || 0;
    score.set(source.id, score.get(source.id) + value);
    score.set(target.id, score.get(target.id) + value);
  });
  return new Set([...score.entries()]
    .sort((a, b) => (b[1] - a[1]) || ((weightedDegrees.get(b[0]) || 0) - (weightedDegrees.get(a[0]) || 0)))
    .slice(0, Math.max(10, Math.floor(atoms.length * .025)))
    .filter(([, value]) => value > 0)
    .map(([id]) => id));
}

export function buildV5SizeProfile(atoms, edges, options = V5_SIZE_DEFAULTS) {
  const weightedDegrees = weightedDegreeMap(atoms, edges);
  const metricValues = options.metric === 'degree' ? plainDegreeMap(atoms, edges) : weightedDegrees;
  const sorted = [...metricValues.values()].sort((a, b) => a - b);
  const values = atoms.map((atom) => {
    const rank = quantileRank(metricValues.get(atom.id) || 0, sorted);
    const baseRadius = interpolate(rank, 0, 1, options.minRadius, options.maxRadius);
    return baseRadius * v5ImportanceScale(rank, options.curve, options.hubMultiplier);
  });
  const minVisualRadius = Math.min(...values);
  const maxVisualRadius = Math.max(...values);
  return {
    metric: options.metric,
    curve: options.curve,
    weightedDegrees,
    metricValues,
    sorted,
    quantiles: { min: percentile(sorted, 0), median: percentile(sorted, .5), p70: percentile(sorted, .7), p90: percentile(sorted, .9), p98: percentile(sorted, .98), max: percentile(sorted, 1) },
    minVisualRadius,
    maxVisualRadius,
    farHubToMicroRatio: (maxVisualRadius * options.farLodMin) / Math.max(minVisualRadius * options.farLodMin, .0001),
    tierMultipliers: [...V5_TIER_MULTIPLIERS.slice(0, 4), options.hubMultiplier],
  };
}

export const V3_WEIGHTED_DEGREE_BY_ID = weightedDegreeMap(V3_BASE_ATOMS, V3_PHYSICS_EDGES);
export const V5_SIZE_PROFILE = buildV5SizeProfile(V3_BASE_ATOMS, V3_PHYSICS_EDGES);
export const V5_IDLE_EDGE_BLUEPRINT = Object.freeze([]);
export const V5_BRIDGE_NODE_IDS = v5BridgeNodeIds(V3_BASE_ATOMS, V3_PHYSICS_EDGES, V3_WEIGHTED_DEGREE_BY_ID);

export function v3NodeRadius(degree) {
  const normalized = V3_MAX_DEGREE <= V3_MIN_DEGREE
    ? 0
    : clamp((degree - V3_MIN_DEGREE) / (V3_MAX_DEGREE - V3_MIN_DEGREE), 0, 1);
  return 1.15 + Math.sqrt(normalized) * 1.65;
}

function v3GeoFromVector(vector) {
  const normal = vector.clone().normalize();
  return {
    lat: Math.asin(clamp(normal.y, -1, 1)) * 180 / Math.PI,
    lng: Math.atan2(normal.z, normal.x) * 180 / Math.PI,
    altitude: .014,
  };
}

function v3VisibleEdges(atoms, physicsEdges, topK = 3, maxVisible = 1320) {
  const byId = new Map(atoms.map((atom) => [atom.id, atom]));
  const adjacency = new Map(atoms.map((atom) => [atom.id, []]));
  physicsEdges.forEach((edge) => {
    adjacency.get(edge.source)?.push(edge);
    adjacency.get(edge.target)?.push(edge);
  });
  const selected = new Map();
  const add = (edge) => {
    const key = [edge.source, edge.target].sort().join('::');
    if (!selected.has(key)) selected.set(key, edge);
  };
  adjacency.forEach((edges) => [...edges]
    .sort((a, b) => (b.weight || 0) - (a.weight || 0))
    .slice(0, topK)
    .forEach(add));
  for (let index = 0; index < atoms.length; index += 1) {
    const source = atoms[index];
    const target = atoms[(index + 1) % atoms.length];
    const edge = physicsEdges.find((candidate) => (
      (candidate.source === source.id && candidate.target === target.id)
      || (candidate.source === target.id && candidate.target === source.id)
    ));
    if (edge) add(edge);
  }
  const boundedEdges = [...selected.values()]
    .sort((a, b) => (b.weight || 0) - (a.weight || 0))
    .slice(0, Math.min(maxVisible, Math.max(atoms.length, selected.size)));
  return boundedEdges.map((edge) => {
    const source = byId.get(edge.source);
    const target = byId.get(edge.target);
    return {
      ...edge,
      startLat: source.lat,
      startLng: source.lng,
      endLat: target.lat,
      endLng: target.lng,
      physicsOnly: false,
    };
  });
}

export function v3OverkillArcPasses(atoms, edges) {
  const atomById = new Map(atoms.map((atom) => [atom.id, atom]));
  const keyOf = (edge) => [edge.source, edge.target].sort().join('::');
  const crossCommunity = edges
    .filter((edge) => atomById.get(edge.source)?.v3Community !== atomById.get(edge.target)?.v3Community)
    .sort((a, b) => (b.weight || 0) - (a.weight || 0));
  const bridgeKeys = new Set(crossCommunity.slice(0, 40).map(keyOf));
  const structure = edges
    .filter((edge) => !bridgeKeys.has(keyOf(edge)) && atomById.get(edge.source)?.v3Community === atomById.get(edge.target)?.v3Community)
    .sort((a, b) => (b.weight || 0) - (a.weight || 0))
    .slice(0, 500);
  const structureKeys = new Set(structure.map(keyOf));
  const bridges = crossCommunity.filter((edge) => bridgeKeys.has(keyOf(edge)));
  const background = edges.filter((edge) => !structureKeys.has(keyOf(edge)) && !bridgeKeys.has(keyOf(edge)));
  return [
    ...background.map((edge) => ({ ...edge, arcPass: 'background', visualOpacity: .18 })),
    ...structure.map((edge) => ({ ...edge, arcPass: 'structure', visualOpacity: .78 })),
    ...bridges.map((edge) => ({ ...edge, arcPass: 'bridge', visualOpacity: .95 })),
  ];
}

export function buildV3Layout(mode = 'uniform') {
  const radius = 1;
  const slots = V3_BASE_ATOMS.map((_, index) => v3SphereVector(index, V3_BASE_ATOMS.length, radius));
  const positions = slots.map((slot) => slot.clone());
  const adjacency = new Map(V3_BASE_ATOMS.map((atom) => [atom.id, []]));
  V3_PHYSICS_EDGES.forEach((edge) => {
    adjacency.get(edge.source)?.push(edge);
    adjacency.get(edge.target)?.push(edge);
  });
  const atomIndex = new Map(V3_BASE_ATOMS.map((atom, index) => [atom.id, index]));

  if (mode === 'community-caps' || mode === 'community-arc' || mode === 'community-adaptive' || mode === 'community-overkill') {
    const centers = Array.from({ length: 10 }, (_, index) => v3SphereVector(index, 10, .72));
    const communityCounts = new Map();
    V3_BASE_ATOMS.forEach((atom) => communityCounts.set(atom.v3Community, (communityCounts.get(atom.v3Community) || 0) + 1));
    const communityRanks = new Map();
    V3_BASE_ATOMS.forEach((atom, index) => {
      const center = centers[atom.v3Community];
      const rank = communityRanks.get(atom.v3Community) || 0;
      communityRanks.set(atom.v3Community, rank + 1);
      const local = v3SphereVector(rank, communityCounts.get(atom.v3Community), .34);
      positions[index].copy(center).add(local).normalize();
    });
  } else if (mode === 'spherical-force') {
    const velocities = positions.map(() => new THREE.Vector3());
    const neighborOffsets = [1, 2, 3, 5, 8, 13];
    for (let tick = 0; tick < 46; tick += 1) {
      V3_BASE_ATOMS.forEach((atom, index) => {
        const point = positions[index];
        const force = new THREE.Vector3();
        const tangent = (vector) => vector.clone().sub(point.clone().multiplyScalar(vector.dot(point)));
        const linkNeighbors = adjacency.get(atom.id) || [];
        linkNeighbors.slice(0, 10).forEach((edge) => {
          const otherId = edge.source === atom.id ? edge.target : edge.source;
          const other = positions[atomIndex.get(otherId)];
          if (!other) return;
          force.add(tangent(other).multiplyScalar(.0025 + (edge.weight || 0) * .002));
        });
        neighborOffsets.forEach((offset) => {
          const other = positions[(index + offset) % positions.length];
          const delta = tangent(point.clone().sub(other));
          const distance = Math.max(.015, point.distanceTo(other));
          force.add(delta.multiplyScalar(.0008 / (distance * distance)));
        });
        force.add(tangent(slots[index].clone().sub(point)).multiplyScalar(.024));
        velocities[index].add(force).multiplyScalar(.68);
      });
      positions.forEach((point, index) => {
        point.add(velocities[index].multiplyScalar(.18)).normalize();
      });
      for (let pass = 0; pass < 2; pass += 1) {
        V3_BASE_ATOMS.forEach((atom, index) => {
          const point = positions[index];
          neighborOffsets.forEach((offset) => {
            const otherIndex = (index + offset) % positions.length;
            const other = positions[otherIndex];
            const delta = point.clone().sub(other);
            const distance = delta.length();
            const minDistance = .026 + ((v3NodeRadius(V3_DEGREE_BY_ID.get(atom.id) || 0)
              + v3NodeRadius(V3_DEGREE_BY_ID.get(V3_BASE_ATOMS[otherIndex].id) || 0)) * .0018);
            if (distance >= minDistance || distance < .0001) return;
            point.add(delta.normalize().multiplyScalar((minDistance - distance) * .16)).normalize();
          });
        });
      }
    }
  }

  const atoms = V3_BASE_ATOMS.map((atom, index) => ({ ...atom, ...v3GeoFromVector(positions[index]) }));
  const overkill = mode === 'community-overkill';
  const edges = v3VisibleEdges(atoms, V3_PHYSICS_EDGES, overkill ? 10 : 2, overkill ? 5000 : 1320);
  return {
    atoms,
    edges,
    stats: {
      atoms: atoms.length,
      physicsEdges: V3_PHYSICS_EDGES.length,
      visibleEdges: edges.length,
      mode,
      ticks: mode === 'spherical-force' ? 46 : 0,
      collisionPasses: mode === 'spherical-force' ? 2 : 0,
      overkill,
    },
  };
}

let v5PlanetVisualSnapshot;
export function getV5PlanetVisualSnapshot() {
  if (v5PlanetVisualSnapshot) return v5PlanetVisualSnapshot;
  const layout = buildV3Layout('community-overkill');
  const profile = V5_SIZE_PROFILE;
  const atoms = layout.atoms.map((atom) => {
    const metric = profile.metricValues.get(atom.id) || 0;
    const rank = quantileRank(metric, profile.sorted);
    const visualRadius = profile.minVisualRadius === profile.maxVisualRadius
      ? V5_SIZE_DEFAULTS.baseRadius * v5ImportanceScale(rank, profile.curve, V5_SIZE_DEFAULTS.hubMultiplier)
      : interpolate(rank, 0, 1, V5_SIZE_DEFAULTS.minRadius, V5_SIZE_DEFAULTS.maxRadius)
        * v5ImportanceScale(rank, profile.curve, V5_SIZE_DEFAULTS.hubMultiplier);
    return Object.freeze({
      id: atom.id,
      label: atom.label,
      lat: atom.lat,
      lng: atom.lng,
      altitude: atom.altitude ?? .014,
      community: atom.v3Community,
      weightedDegree: metric,
      tier: v5TierForRank(rank),
      visualRadius,
      hasBridgeRing: V5_BRIDGE_NODE_IDS.has(atom.id),
      color: DJINN_ORB_V5.atom,
      glow: DJINN_ORB_V5.atomGlow,
    });
  });
  v5PlanetVisualSnapshot = Object.freeze({
    palette: Object.freeze({ ...DJINN_ORB_V5 }),
    atoms: Object.freeze(atoms),
    physicsEdges: Object.freeze(V3_PHYSICS_EDGES.map((edge) => Object.freeze({ ...edge }))),
    idleEdgeCount: V5_IDLE_EDGE_BLUEPRINT.length,
  });
  return v5PlanetVisualSnapshot;
}

// Selection controllers need final geographic endpoints, not the stale
// original Fibonacci positions.  The map identity stays stable across V3
// layouts so each V5/V6/V7 controller keeps its own reliable endpoint source.
export function createV5NodePositionRegistry(snapshot = getV5PlanetVisualSnapshot()) {
  return new Map(snapshot.atoms.map((atom) => [atom.id, atom]));
}

export function syncV5NodePositionRegistry(registry, atoms = []) {
  if (!(registry instanceof Map)) throw new TypeError('V5 node position registry must be a Map');
  registry.clear();
  atoms.forEach((atom) => registry.set(atom.id, atom));
  return registry;
}

export function surfaceSelectionEndpointAltitude(arc, endpoint, fallback) {
  if (isSurfaceSelectionArc(arc)) {
    return endpoint === 'start' ? Number(arc.startAltitude) : Number(arc.endAltitude);
  }
  return fallback();
}

export function surfaceSelectionArcProfile(arc) {
  if (!isSurfaceSelectionArc(arc)) return null;
  return {
    altitude: Number(arc.peakAltitude),
    autoScale: 0,
    pathResolution: SURFACE_SELECTION_ARC_PROFILE.pathResolution,
    stroke: Number(arc.stroke),
  };
}

export const __surfaceSelectionArcTestModel = Object.freeze({
  select: (variant, cityId) => selectCityConnections({
    variant,
    cityId,
    edges: V3_PHYSICS_EDGES,
    nodesById: new Map(getV5PlanetVisualSnapshot().atoms.map((atom) => [atom.id, atom])),
  }),
  clear: () => clearCityConnections(),
  endpointAltitude: (arc, endpoint) => surfaceSelectionEndpointAltitude(arc, endpoint, () => .014),
  arcProfile: (arc) => {
    const profile = surfaceSelectionArcProfile(arc);
    return profile && {
      autoScale: profile.autoScale,
      pathResolution: profile.pathResolution,
      stroke: profile.stroke,
    };
  },
});

export const __v3TestModel = Object.freeze({
  atomCount: V3_BASE_ATOMS.length,
  physicsEdgeCount: V3_PHYSICS_EDGES.length,
  buildLayout: buildV3Layout,
  buildOverkillPasses: v3OverkillArcPasses,
  v5SizeProfile: Object.freeze({
    metric: V5_SIZE_PROFILE.metric,
    curve: V5_SIZE_PROFILE.curve,
    physicsEdgeCount: V3_PHYSICS_EDGES.length,
    idleArcCount: 0,
    minVisualRadius: V5_SIZE_PROFILE.minVisualRadius,
    maxVisualRadius: V5_SIZE_PROFILE.maxVisualRadius,
    farHubToMicroRatio: V5_SIZE_PROFILE.farHubToMicroRatio,
    tierMultipliers: V5_SIZE_PROFILE.tierMultipliers,
    quantiles: V5_SIZE_PROFILE.quantiles,
  }),
});
