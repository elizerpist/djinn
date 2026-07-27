export const TEST_SEED = 42;
export const TAP_MOVE_THRESHOLD_PX = 8;
export const TAP_DURATION_THRESHOLD_MS = 300;

export const UNIVERSE_LEVEL = Object.freeze({
  GALAXY: 'GALAXY',
  GALAXY_TO_PLANET: 'GALAXY_TO_PLANET',
  PLANET: 'PLANET',
  PLANET_TO_MAP: 'PLANET_TO_MAP',
  MAP: 'MAP',
  MAP_TO_PLANET: 'MAP_TO_PLANET',
  PLANET_TO_GALAXY: 'PLANET_TO_GALAXY',
});

function mulberry32(seed) {
  let value = seed >>> 0;
  return () => {
    value += 0x6d2b79f5;
    let result = value;
    result = Math.imul(result ^ (result >>> 15), result | 1);
    result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  };
}

function padId(index) {
  return String(index).padStart(3, '0');
}

function createNodes(prefix, count, label, options = {}) {
  return Array.from({ length: count }, (_, index) => ({
    id: `${prefix}-${padId(index)}`,
    label: options.planetCount && index < options.planetCount
      ? `Bolygó ${index + 1}`
      : `${label} ${index + 1}`,
    isPlanet: Boolean(options.planetCount && index < options.planetCount),
    importance: Number((.35 + (index % 11) / 20).toFixed(2)),
  }));
}

function edgeKey(source, target) {
  return source < target ? `${source}:${target}` : `${target}:${source}`;
}

function createConnectedLinks(nodes, count, seed) {
  const random = mulberry32(seed);
  const keys = new Set();
  const links = [];
  const add = (source, target) => {
    if (source === target || links.length >= count) return false;
    const key = edgeKey(source, target);
    if (keys.has(key)) return false;
    keys.add(key);
    links.push({ id: `edge-${padId(links.length)}`, source, target, weight: Number((.35 + random() * .65).toFixed(3)) });
    return true;
  };

  for (let index = 1; index < nodes.length; index += 1) {
    add(nodes[index - 1].id, nodes[index].id);
  }

  while (links.length < count) {
    const source = nodes[Math.floor(random() * nodes.length)].id;
    const target = nodes[Math.floor(random() * nodes.length)].id;
    add(source, target);
  }

  return links;
}

export function createUniverseMockData(seed = TEST_SEED) {
  const galaxyNodes = createNodes('galaxy', 180, 'Fogalom', { planetCount: 8 });
  const planetNodes = createNodes('planet-node', 140, 'Kapcsolat');
  const mapNodes = createNodes('map-node', 28, 'Tudáselem');

  return {
    galaxy: {
      nodes: galaxyNodes,
      links: createConnectedLinks(galaxyNodes, 260, seed + 11),
      planetIds: galaxyNodes.filter((node) => node.isPlanet).map((node) => node.id),
    },
    planet: {
      nodes: planetNodes,
      links: createConnectedLinks(planetNodes, 210, seed + 23),
    },
    map: {
      nodes: mapNodes,
      links: createConnectedLinks(mapNodes, 42, seed + 37),
    },
  };
}

export function fibonacciSpherePoint(index, count, radius, altitude = 0) {
  const phi = Math.acos(1 - (2 * (index + .5)) / count);
  const theta = Math.PI * (3 - Math.sqrt(5)) * index;
  const r = radius * (1 + altitude);
  const x = r * Math.sin(phi) * Math.cos(theta);
  const y = r * Math.cos(phi);
  const z = r * Math.sin(phi) * Math.sin(theta);
  return {
    x,
    y,
    z,
    lat: 90 - phi * 180 / Math.PI,
    lng: ((theta * 180 / Math.PI + 540) % 360) - 180,
  };
}

export function galaxyNodeRadius(degree, minDegree, maxDegree) {
  if (maxDegree <= minDegree) return 1.5;
  const normalized = Math.max(0, Math.min(1, (degree - minDegree) / (maxDegree - minDegree)));
  return 1.5 + Math.sqrt(normalized) * 4.7;
}

export function easeInOutCubic(progress) {
  return progress < .5
    ? 4 * progress * progress * progress
    : 1 - Math.pow(-2 * progress + 2, 3) / 2;
}

export function focusCameraTarget(node, camera, previousTarget, distance) {
  const dx = camera.x - previousTarget.x;
  const dy = camera.y - previousTarget.y;
  const dz = camera.z - previousTarget.z;
  const length = Math.hypot(dx, dy, dz) || 1;
  return {
    x: node.x + dx / length * distance,
    y: node.y + dy / length * distance,
    z: node.z + dz / length * distance,
  };
}

export function surfaceArcPoints(start, end, baseRadius, segments, lift) {
  const startLength = Math.hypot(start.x, start.y, start.z) || 1;
  const endLength = Math.hypot(end.x, end.y, end.z) || 1;
  const a = { x: start.x / startLength, y: start.y / startLength, z: start.z / startLength };
  const b = { x: end.x / endLength, y: end.y / endLength, z: end.z / endLength };
  const dot = Math.max(-1, Math.min(1, a.x * b.x + a.y * b.y + a.z * b.z));
  const angle = Math.acos(dot);
  const sine = Math.sin(angle);

  return Array.from({ length: segments + 1 }, (_, index) => {
    const t = index / segments;
    const firstWeight = sine < 1e-7 ? 1 - t : Math.sin((1 - t) * angle) / sine;
    const secondWeight = sine < 1e-7 ? t : Math.sin(t * angle) / sine;
    const directionLength = Math.hypot(
      a.x * firstWeight + b.x * secondWeight,
      a.y * firstWeight + b.y * secondWeight,
      a.z * firstWeight + b.z * secondWeight,
    ) || 1;
    const direction = {
      x: (a.x * firstWeight + b.x * secondWeight) / directionLength,
      y: (a.y * firstWeight + b.y * secondWeight) / directionLength,
      z: (a.z * firstWeight + b.z * secondWeight) / directionLength,
    };
    const radius = baseRadius * (1 + lift + lift * .55 * Math.sin(Math.PI * t));
    return { x: direction.x * radius, y: direction.y * radius, z: direction.z * radius };
  });
}

export function projectPointToScreen(point, camera, width, height) {
  const projected = point.clone().project(camera);
  return {
    x: (projected.x * .5 + .5) * width,
    y: (-projected.y * .5 + .5) * height,
    ndcZ: projected.z,
  };
}

export function classifyPointerTap(start, end, endedAt = end.endedAt) {
  const duration = endedAt - start.startedAt;
  return Math.hypot(end.x - start.x, end.y - start.y) <= TAP_MOVE_THRESHOLD_PX
    && duration <= TAP_DURATION_THRESHOLD_MS;
}

export function canTransition(level, targetLevel) {
  return new Set([
    `${UNIVERSE_LEVEL.GALAXY}:${UNIVERSE_LEVEL.GALAXY_TO_PLANET}`,
    `${UNIVERSE_LEVEL.GALAXY_TO_PLANET}:${UNIVERSE_LEVEL.PLANET}`,
    `${UNIVERSE_LEVEL.PLANET}:${UNIVERSE_LEVEL.PLANET_TO_MAP}`,
    `${UNIVERSE_LEVEL.PLANET_TO_MAP}:${UNIVERSE_LEVEL.MAP}`,
    `${UNIVERSE_LEVEL.MAP}:${UNIVERSE_LEVEL.MAP_TO_PLANET}`,
    `${UNIVERSE_LEVEL.MAP_TO_PLANET}:${UNIVERSE_LEVEL.PLANET}`,
    `${UNIVERSE_LEVEL.PLANET}:${UNIVERSE_LEVEL.PLANET_TO_GALAXY}`,
    `${UNIVERSE_LEVEL.PLANET_TO_GALAXY}:${UNIVERSE_LEVEL.GALAXY}`,
  ]).has(`${level}:${targetLevel}`);
}

export function reverseTransition(level) {
  if (level === UNIVERSE_LEVEL.MAP) return UNIVERSE_LEVEL.MAP_TO_PLANET;
  if (level === UNIVERSE_LEVEL.PLANET) return UNIVERSE_LEVEL.PLANET_TO_GALAXY;
  return null;
}
