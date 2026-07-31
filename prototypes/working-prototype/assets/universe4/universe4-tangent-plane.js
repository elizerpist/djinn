const radians = (degrees) => degrees * Math.PI / 180;

const dot = (a, b) => a.x * b.x + a.y * b.y + a.z * b.z;
const cross = (a, b) => ({
  x: a.y * b.z - a.z * b.y,
  y: a.z * b.x - a.x * b.z,
  z: a.x * b.y - a.y * b.x,
});
const length = (v) => Math.hypot(v.x, v.y, v.z);
const normalize = (v) => {
  const size = length(v) || 1;
  return { x: v.x / size, y: v.y / size, z: v.z / size };
};

export function universe4LatLngToUnitVector(lat, lng) {
  const latitude = radians(Number(lat) || 0);
  const longitude = radians(Number(lng) || 0);
  return {
    x: Math.cos(latitude) * Math.sin(longitude),
    y: Math.sin(latitude),
    z: Math.cos(latitude) * Math.cos(longitude),
  };
}

// A stable local East/North/Normal frame. Plane y is inverted to match CSS
// screen coordinates: north projects upward (negative y).
export function createUniverse4TangentPlane(anchor = {}) {
  const normal = normalize(universe4LatLngToUnitVector(anchor.lat, anchor.lng));
  let east = normalize(cross({ x: 0, y: 1, z: 0 }, normal));
  if (length(east) < 1e-6) east = { x: 1, y: 0, z: 0 };
  const north = normalize(cross(normal, east));
  return Object.freeze({
    anchor: Object.freeze({ lat: Number(anchor.lat) || 0, lng: Number(anchor.lng) || 0 }),
    normal: Object.freeze(normal),
    east: Object.freeze(east),
    north: Object.freeze(north),
    project(city = {}) {
      const vector = universe4LatLngToUnitVector(city.lat, city.lng);
      // Gnomonic-like tangent coordinates keep angular directions continuous.
      const facing = Math.max(.08, dot(vector, normal));
      const localX = dot(vector, east) / facing;
      const localY = -dot(vector, north) / facing;
      const plane = Object.freeze({
        x: Math.abs(localX) < 1e-12 ? 0 : localX,
        y: Math.abs(localY) < 1e-12 ? 0 : localY,
      });
      return Object.freeze({
        id: city.id ?? null,
        sphere: Object.freeze(vector),
        plane,
      });
    },
  });
}

export function interpolateUniverse4SurfacePoint(sphere, plane, progress) {
  const t = Math.max(0, Math.min(1, Number(progress) || 0));
  return {
    x: sphere.x + (plane.x - sphere.x) * t,
    y: sphere.y + (plane.y - sphere.y) * t,
    z: sphere.z + (plane.z - sphere.z) * t,
  };
}
