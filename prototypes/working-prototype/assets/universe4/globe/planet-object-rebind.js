/**
 * Recreates Globe.gl custom objects after an explicit planet-variant switch.
 * The fresh callback identity is essential: ThreeGlobe caches Object3D values
 * by stable data ID, while each V5-family renderer needs a fresh hitSphere
 * registry for those same 700 IDs.
 */
export function rebindPlanetObjects({
  globe,
  points = [],
  clearRegistry,
  createObject,
  trace = () => {},
  reason = 'variant-rebind',
} = {}) {
  if (typeof globe?.objectsData !== 'function' || typeof globe?.objectThreeObject !== 'function') {
    throw new TypeError('globe.objectsData and globe.objectThreeObject are required');
  }
  if (typeof clearRegistry !== 'function' || typeof createObject !== 'function') {
    throw new TypeError('clearRegistry and createObject are required');
  }
  const activePoints = Array.isArray(points) ? points : [];

  globe.objectsData([]);
  clearRegistry();
  globe.objectThreeObject((point) => createObject(point));
  globe.objectsData(activePoints);

  const result = { expectedTargetCount: activePoints.length, reason };
  trace('node.registry.rebind', result);
  return result;
}
