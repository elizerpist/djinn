// City-label density is a visual LOD policy, not a substitute for the
// planet camera distance.  Keeping it pure makes the V5/V6/V7 label budget
// explicit and independently regression-testable.
export function getPlanetLabelLod({ distance, focused = false }) {
  const normalizedDistance = Number.isFinite(distance) ? distance : 2.1;

  if (focused) return { id: 'focus', limit: 9 };
  if (normalizedDistance > 3.7) return { id: 'far', limit: 5 };
  if (normalizedDistance > 2.55) return { id: 'orbit', limit: 8 };
  if (normalizedDistance < 1.68) return { id: 'near', limit: 15 };
  return { id: 'medium', limit: 11 };
}
