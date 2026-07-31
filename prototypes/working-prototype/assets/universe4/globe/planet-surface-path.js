// Pure spherical geometry for Globe.gl's native Paths layer. Keeping the
// sampling here makes every intermediate coordinate an explicit point on the
// globe shell instead of leaving a low native Arc to visually read as a chord.
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const radians = (degrees) => (Number(degrees) * Math.PI) / 180;
const degrees = (radiansValue) => (Number(radiansValue) * 180) / Math.PI;

const normalize = ([x, y, z]) => {
  const length = Math.hypot(x, y, z) || 1;
  return [x / length, y / length, z / length];
};

const dot = (left, right) => left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
const cross = (left, right) => ([
  left[1] * right[2] - left[2] * right[1],
  left[2] * right[0] - left[0] * right[2],
  left[0] * right[1] - left[1] * right[0],
]);

const normalFromGeo = ({ lat, lng }) => {
  const latitude = radians(lat);
  const longitude = radians(lng);
  const cosine = Math.cos(latitude);
  return [
    cosine * Math.cos(longitude),
    Math.sin(latitude),
    cosine * Math.sin(longitude),
  ];
};

const geoFromNormal = ([x, y, z], altitude) => ({
  lat: degrees(Math.asin(clamp(y, -1, 1))),
  lng: degrees(Math.atan2(z, x)),
  altitude,
});

const greatCircleNormal = (start, end, progress, angle, sinAngle) => {
  if (Math.abs(sinAngle) > 1e-7) {
    const startScale = Math.sin((1 - progress) * angle) / sinAngle;
    const endScale = Math.sin(progress * angle) / sinAngle;
    return normalize([
      start[0] * startScale + end[0] * endScale,
      start[1] * startScale + end[1] * endScale,
      start[2] * startScale + end[2] * endScale,
    ]);
  }
  if (dot(start, end) < 0) {
    const reference = Math.abs(start[1]) < .8 ? [0, 1, 0] : [1, 0, 0];
    const tangent = normalize(cross(reference, start));
    return normalize([
      start[0] * Math.cos(Math.PI * progress) + tangent[0] * Math.sin(Math.PI * progress),
      start[1] * Math.cos(Math.PI * progress) + tangent[1] * Math.sin(Math.PI * progress),
      start[2] * Math.cos(Math.PI * progress) + tangent[2] * Math.sin(Math.PI * progress),
    ]);
  }
  return normalize([
    start[0] + (end[0] - start[0]) * progress,
    start[1] + (end[1] - start[1]) * progress,
    start[2] + (end[2] - start[2]) * progress,
  ]);
};

/**
 * Produces explicit great-circle samples for Globe.gl Paths. The first and
 * last coordinates stay bit-for-bit at their city locations; only interior
 * points are interpolated, so routes attach to the intended atoms.
 */
export function buildGreatCircleSurfacePath(start, end, {
  altitude = .015,
  minSegments = 16,
  maxSegments = 96,
  degreesPerSegment = 2,
} = {}) {
  const startNormal = normalFromGeo(start);
  const endNormal = normalFromGeo(end);
  const angle = Math.acos(clamp(dot(startNormal, endNormal), -1, 1));
  const segmentCount = clamp(
    Math.ceil(degrees(angle) / Math.max(.1, Number(degreesPerSegment) || 2)),
    Math.max(2, Math.round(minSegments)),
    Math.max(2, Math.round(maxSegments)),
  );
  const sinAngle = Math.sin(angle);
  const points = [];
  for (let index = 0; index <= segmentCount; index += 1) {
    if (index === 0) {
      points.push({ lat: Number(start.lat), lng: Number(start.lng), altitude });
      continue;
    }
    if (index === segmentCount) {
      points.push({ lat: Number(end.lat), lng: Number(end.lng), altitude });
      continue;
    }
    points.push(geoFromNormal(
      greatCircleNormal(startNormal, endNormal, index / segmentCount, angle, sinAngle),
      altitude,
    ));
  }
  return points;
}
