const EPSILON = 1e-10;

const finiteNumber = (value, label) => {
  if (!Number.isFinite(value)) throw new TypeError(`${label} must be finite`);
  return value;
};

const finiteVector = (value, label) => ({
  x: finiteNumber(value?.x, `${label}.x`),
  y: finiteNumber(value?.y, `${label}.y`),
  z: finiteNumber(value?.z, `${label}.z`),
});

const finiteQuaternion = (value, label) => ({
  x: finiteNumber(value?.x, `${label}.x`),
  y: finiteNumber(value?.y, `${label}.y`),
  z: finiteNumber(value?.z, `${label}.z`),
  w: finiteNumber(value?.w, `${label}.w`),
});

const clean = (value) => {
  if (Math.abs(value) < EPSILON) return 0;
  const integer = Math.round(value);
  return Math.abs(value - integer) < EPSILON ? integer : value;
};

const subtract = (left, right) => ({
  x: clean(left.x - right.x),
  y: clean(left.y - right.y),
  z: clean(left.z - right.z),
});

const scale = (vector, factor) => ({
  x: clean(vector.x * factor),
  y: clean(vector.y * factor),
  z: clean(vector.z * factor),
});

const inverseUnitQuaternion = (value) => {
  const x = finiteNumber(value?.x, 'planet.worldQuaternion.x');
  const y = finiteNumber(value?.y, 'planet.worldQuaternion.y');
  const z = finiteNumber(value?.z, 'planet.worldQuaternion.z');
  const w = finiteNumber(value?.w, 'planet.worldQuaternion.w');
  const length = Math.hypot(x, y, z, w);
  if (length < EPSILON) throw new TypeError('planet.worldQuaternion must not be zero');
  return { x: -x / length, y: -y / length, z: -z / length, w: w / length };
};

const unitQuaternion = (value) => {
  const inverse = inverseUnitQuaternion(value);
  return { x: -inverse.x, y: -inverse.y, z: -inverse.z, w: inverse.w };
};

const rotateByQuaternion = (vector, quaternion) => {
  const ix = quaternion.w * vector.x + quaternion.y * vector.z - quaternion.z * vector.y;
  const iy = quaternion.w * vector.y + quaternion.z * vector.x - quaternion.x * vector.z;
  const iz = quaternion.w * vector.z + quaternion.x * vector.y - quaternion.y * vector.x;
  const iw = -quaternion.x * vector.x - quaternion.y * vector.y - quaternion.z * vector.z;

  return {
    x: clean(ix * quaternion.w + iw * -quaternion.x + iy * -quaternion.z - iz * -quaternion.y),
    y: clean(iy * quaternion.w + iw * -quaternion.y + iz * -quaternion.x - ix * -quaternion.z),
    z: clean(iz * quaternion.w + iw * -quaternion.z + ix * -quaternion.y - iy * -quaternion.x),
  };
};

/**
 * Converts the captured Force camera into the selected planet's local space,
 * then delegates geographic axes to Globe.gl's own toGeoCoords converter.
 */
export function mapForceCameraToGlobePov({ forceCamera, planet, globeRadius, toGeoCoords } = {}) {
  const forceCameraPosition = finiteVector(forceCamera?.worldPosition, 'forceCamera.worldPosition');
  const planetWorldPosition = finiteVector(planet?.worldPosition, 'planet.worldPosition');
  const visualRadius = finiteNumber(planet?.visualRadius, 'planet.visualRadius');
  const targetGlobeRadius = finiteNumber(globeRadius, 'globeRadius');
  if (visualRadius <= 0 || targetGlobeRadius <= 0) {
    throw new RangeError('planet.visualRadius and globeRadius must be greater than zero');
  }
  if (typeof toGeoCoords !== 'function') throw new TypeError('toGeoCoords must be a function');

  const forceRelativeCameraPosition = subtract(forceCameraPosition, planetWorldPosition);
  const planetLocalCameraPosition = rotateByQuaternion(
    forceRelativeCameraPosition,
    inverseUnitQuaternion(planet?.worldQuaternion),
  );
  const globeLocalCameraPosition = scale(planetLocalCameraPosition, targetGlobeRadius / visualRadius);
  const converted = toGeoCoords({ ...globeLocalCameraPosition });
  const pointOfView = {
    lat: finiteNumber(converted?.lat, 'toGeoCoords().lat'),
    lng: finiteNumber(converted?.lng, 'toGeoCoords().lng'),
    altitude: finiteNumber(converted?.altitude, 'toGeoCoords().altitude'),
  };

  return {
    forceRelativeCameraPosition,
    planetLocalCameraPosition,
    globeLocalCameraPosition,
    pointOfView,
    camera: {
      fov: finiteNumber(forceCamera?.fov, 'forceCamera.fov'),
      aspect: finiteNumber(forceCamera?.aspect, 'forceCamera.aspect'),
      near: finiteNumber(forceCamera?.near, 'forceCamera.near'),
      far: finiteNumber(forceCamera?.far, 'forceCamera.far'),
    },
  };
}

/** Adapts the Force stage's captureCamera() record to the pure mapper contract. */
export function mapForceCameraSnapshotToGlobePov({ forceCameraSnapshot, globeRadius, toGeoCoords } = {}) {
  return mapForceCameraToGlobePov({
    forceCamera: {
      worldPosition: forceCameraSnapshot?.cameraPosition,
      fov: forceCameraSnapshot?.fov,
      aspect: forceCameraSnapshot?.aspect,
      near: forceCameraSnapshot?.near,
      far: forceCameraSnapshot?.far,
    },
    planet: {
      worldPosition: forceCameraSnapshot?.planetWorldCenter,
      worldQuaternion: forceCameraSnapshot?.planetWorldQuaternion,
      visualRadius: forceCameraSnapshot?.planetVisualRadius,
    },
    globeRadius,
    toGeoCoords,
  });
}

/**
 * Maps the actual standalone Globe camera back into the frozen Force planet's
 * world frame. The Globe snapshot is captured after the user's last POV, so
 * return never first snaps to a default Globe viewpoint.
 */
export function mapGlobeCameraSnapshotToForceCamera({ globeCameraSnapshot, planet } = {}) {
  const globeCameraPosition = finiteVector(globeCameraSnapshot?.cameraPosition, 'globeCameraSnapshot.cameraPosition');
  const globeRadius = finiteNumber(globeCameraSnapshot?.globeRadius, 'globeCameraSnapshot.globeRadius');
  const planetWorldPosition = finiteVector(planet?.worldPosition, 'planet.worldPosition');
  const visualRadius = finiteNumber(planet?.visualRadius, 'planet.visualRadius');
  if (globeRadius <= 0 || visualRadius <= 0) throw new RangeError('globeRadius and visualRadius must be greater than zero');

  const planetLocalCameraPosition = scale(globeCameraPosition, visualRadius / globeRadius);
  const worldRelativeCameraPosition = rotateByQuaternion(planetLocalCameraPosition, unitQuaternion(planet?.worldQuaternion));
  const cameraPosition = {
    x: clean(planetWorldPosition.x + worldRelativeCameraPosition.x),
    y: clean(planetWorldPosition.y + worldRelativeCameraPosition.y),
    z: clean(planetWorldPosition.z + worldRelativeCameraPosition.z),
  };
  return {
    cameraPosition,
    cameraQuaternion: finiteQuaternion(globeCameraSnapshot?.cameraQuaternion, 'globeCameraSnapshot.cameraQuaternion'),
    cameraUp: finiteVector(globeCameraSnapshot?.cameraUp, 'globeCameraSnapshot.cameraUp'),
    fov: finiteNumber(globeCameraSnapshot?.fov, 'globeCameraSnapshot.fov'),
    aspect: finiteNumber(globeCameraSnapshot?.aspect, 'globeCameraSnapshot.aspect'),
    near: finiteNumber(globeCameraSnapshot?.near, 'globeCameraSnapshot.near'),
    far: finiteNumber(globeCameraSnapshot?.far, 'globeCameraSnapshot.far'),
    controlsTarget: planetWorldPosition,
  };
}

/** Projects a world position to CSS, never framebuffer, pixels. */
export function projectWorldToCss({ worldPosition, viewport, project } = {}) {
  const width = finiteNumber(viewport?.width, 'viewport.width');
  const height = finiteNumber(viewport?.height, 'viewport.height');
  if (width <= 0 || height <= 0) throw new RangeError('viewport dimensions must be greater than zero');
  if (typeof project !== 'function') throw new TypeError('project must be a function');

  const projected = finiteVector(project(finiteVector(worldPosition, 'worldPosition')), 'project()');
  return {
    x: ((projected.x + 1) * .5) * width,
    y: ((1 - projected.y) * .5) * height,
    ndcZ: projected.z,
    visible: projected.x >= -1 && projected.x <= 1
      && projected.y >= -1 && projected.y <= 1
      && projected.z >= -1 && projected.z <= 1,
  };
}

/** Returns a planet's visible CSS radius from a projected center and surface edge. */
export function measureCssRadius(center, surfaceEdge) {
  const measuredCenter = finiteVector({ ...center, z: 0 }, 'center');
  const measuredEdge = finiteVector({ ...surfaceEdge, z: 0 }, 'surfaceEdge');
  return Math.hypot(measuredEdge.x - measuredCenter.x, measuredEdge.y - measuredCenter.y);
}

/**
 * Finds the Globe.gl POV altitude whose projected globe radius matches a
 * captured Force radius.  The caller owns rendering and can therefore use
 * the exact live `getScreenCoords()` measurement without allocating meshes.
 */
export function solveAltitudeForCssRadius({
  targetRadius,
  minAltitude,
  maxAltitude,
  measureRadius,
  iterations = 14,
} = {}) {
  const wantedRadius = finiteNumber(targetRadius, 'targetRadius');
  const minimum = finiteNumber(minAltitude, 'minAltitude');
  const maximum = finiteNumber(maxAltitude, 'maxAltitude');
  if (wantedRadius <= 0) throw new RangeError('targetRadius must be greater than zero');
  if (!(minimum >= 0) || !(maximum > minimum)) throw new RangeError('altitude bounds must be ordered and non-negative');
  if (typeof measureRadius !== 'function') throw new TypeError('measureRadius must be a function');

  let low = minimum;
  let high = maximum;
  let bestAltitude = low;
  let bestRadius = finiteNumber(measureRadius(low), 'measureRadius(minAltitude)');
  let bestDelta = Math.abs(bestRadius - wantedRadius);
  const highRadius = finiteNumber(measureRadius(high), 'measureRadius(maxAltitude)');
  const decreasesWithAltitude = highRadius < bestRadius;
  const attemptCount = Math.max(1, Math.floor(finiteNumber(iterations, 'iterations')));

  const record = (altitude) => {
    const radius = finiteNumber(measureRadius(altitude), 'measureRadius()');
    const delta = Math.abs(radius - wantedRadius);
    if (delta < bestDelta) {
      bestAltitude = altitude;
      bestRadius = radius;
      bestDelta = delta;
    }
    return radius;
  };

  record(high);
  for (let index = 0; index < attemptCount; index += 1) {
    const middle = (low + high) * .5;
    const radius = record(middle);
    const radiusTooLarge = radius > wantedRadius;
    const moveTowardHigherAltitude = decreasesWithAltitude ? radiusTooLarge : !radiusTooLarge;
    if (moveTowardHigherAltitude) low = middle;
    else high = middle;
  }

  return Object.freeze({
    altitude: bestAltitude,
    radius: bestRadius,
    deltaPercent: (bestDelta / wantedRadius) * 100,
    iterations: attemptCount,
  });
}
