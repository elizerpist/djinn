// Immutable Universe palettes and interaction-display policies. This module
// deliberately owns no Globe, Three.js, DOM, selection controller or mutable
// runtime state: V5, V6 and V7 can import their own stable profile data.

export const DJINN_ORB_V2 = Object.freeze({
  space: '#06163F',
  planet: '#3A237C',
  atom: '#43E7F8',
  atomGlow: '#75F1FA',
  structure: '#A18BF7',
  focus: '#FFD45A',
  focusGlow: '#FFE783',
});

export const DJINN_ORB_V3 = Object.freeze({
  space: '#06163F',
  planet: '#27175A',
  overkillSpace: '#020817',
  overkillPlanet: '#160D38',
  overkillBackground: '#4A3D79',
  overkillBack: '#28224D',
  atom: '#43E7F8',
  atomDim: '#263778',
  atomGlow: '#75F1FA',
  structure: '#A18BF7',
  edge: '#7A6FB6',
  focus: '#FFD45A',
  focusGlow: '#FFE783',
});

export const DJINN_ORB_V4 = Object.freeze({
  space: '#03091D',
  planet: '#241451',
  atom: '#33D9FF',
  atomDim: '#1C4A79',
  atomGlow: '#8AF2FF',
  localEdge: '#2AC7FF',
  remoteEdge: '#FF8A32',
  remoteGlow: '#FFD45A',
  focus: '#FFD45A',
  focusGlow: '#FFE69A',
});

export const DJINN_ORB_V5 = Object.freeze({
  space: DJINN_ORB_V4.space,
  planet: DJINN_ORB_V4.planet,
  atom: '#33D9FF',
  atomDim: '#0A4264',
  atomGlow: '#8AF2FF',
  arc: '#5BA9D6',
  arcDim: '#2C668D',
  focus: '#FFD45A',
  focusGlow: '#FFE69A',
});

export const DJINN_ORB_V6 = Object.freeze({ ...DJINN_ORB_V5 });
export const DJINN_ORB_V7 = Object.freeze({ ...DJINN_ORB_V5 });
export const V5_FOCUS_NO_ZOOM = true;

// The V5-family city POV is an automatic camera move, not a modal lock. Keep
// native Globe.gl orbit and zoom available while that tween (or any later
// focus state) is active. Legacy V1–V4 card morphs retain their camera lock.
export function v5GlobeControlsEnabled({ expanded = false, variant = '', focusState = 'idle' } = {}) {
  const v5Family = variant === 'v5' || variant === 'v6' || variant === 'v7';
  return Boolean(expanded && (v5Family || focusState === 'idle'));
}

// V5–V7 city selection is a Globe-only context interaction. Keep the
// dedicated Globe camera centered on the planet and move the selected
// latitude/longitude in front of it; do not reuse the older V1–V4 card-morph
// camera path, which changes OrbitControls' target to the selected node.
export const V5_CITY_FOCUS = Object.freeze({
  zoomFactor: .75,
  minimumAltitude: .5,
  maximumAltitude: 3.4,
  durationMs: 680,
});

export function v5CityFocusPointOfView(currentPointOfView, city, lockedAltitude = null) {
  if (!Number.isFinite(city?.lat) || !Number.isFinite(city?.lng)) return null;
  const currentAltitude = Number.isFinite(currentPointOfView?.altitude)
    ? currentPointOfView.altitude
    : V5_CITY_FOCUS.maximumAltitude;
  const requestedAltitude = Number.isFinite(lockedAltitude)
    ? lockedAltitude
    : currentAltitude * V5_CITY_FOCUS.zoomFactor;
  const boundedAltitude = Math.max(
    V5_CITY_FOCUS.minimumAltitude,
    Math.min(V5_CITY_FOCUS.maximumAltitude, requestedAltitude),
  );
  const altitude = Number(boundedAltitude.toFixed(4));
  return Object.freeze({ lat: city.lat, lng: city.lng, altitude });
}

export const V6_HYBRID_LIGHT = Object.freeze({
  keyIntensity: 1.95,
  fillIntensity: .68,
  rimIntensity: .30,
  cameraOrbitInfluence: .16,
  lightLagMs: 120,
  keyDistance: 300,
  rimDistance: 260,
  sunDirection: Object.freeze([-0.62, .48, .62]),
  specular: '#4EA8C6',
  shininess: 16,
  emissive: '#0B102C',
  emissiveIntensity: .045,
});

export const V6_LIGHT_RIG_MODES = Object.freeze([
  'hybrid',
  'default-globe',
  'camera-headlight',
  'fixed-galaxy-sun',
  'light-direction-proof',
  'no-fill',
  'no-rim',
]);

const createV5ContextVisuals = () => Object.freeze({
  idle: Object.freeze({ sphereOpacity: 1, emissiveIntensity: .42, glowMultiplier: 1, bridgeOpacity: .34, color: DJINN_ORB_V5.atom }),
  focused: Object.freeze({ sphereOpacity: 1, emissiveIntensity: .98, glowMultiplier: 2.8, bridgeOpacity: .74, color: DJINN_ORB_V5.focus }),
  related: Object.freeze({ sphereOpacity: .86, emissiveIntensity: .62, glowMultiplier: 1.5, bridgeOpacity: .5, color: DJINN_ORB_V5.atom }),
  dimmed: Object.freeze({ sphereOpacity: .07, emissiveIntensity: .018, glowMultiplier: .06, bridgeOpacity: .05, color: DJINN_ORB_V5.atomDim }),
});

const V5_CONTEXT_VISUALS = createV5ContextVisuals();
const V6_CONTEXT_VISUALS = createV5ContextVisuals();
const V7_CONTEXT_VISUALS = createV5ContextVisuals();

export const V5_VARIANT_CONTEXT_VISUALS = Object.freeze({
  v5: V5_CONTEXT_VISUALS,
  v6: V6_CONTEXT_VISUALS,
  v7: V7_CONTEXT_VISUALS,
});

export const V5_VARIANT_INTERACTION_POLICIES = Object.freeze({
  v5: Object.freeze({ id: 'v5', contextOnly: true, pointerRouter: 'v5-native-tap-router', repeatTap: 'dehighlight' }),
  v6: Object.freeze({ id: 'v6', contextOnly: true, pointerRouter: 'v6-native-tap-router', repeatTap: 'dehighlight' }),
  v7: Object.freeze({ id: 'v7', contextOnly: true, pointerRouter: 'v7-native-tap-router', repeatTap: 'dehighlight' }),
});

export function v5VariantContextVisualState(variant, { hasFocus, isFocused, isRelated }) {
  const visuals = V5_VARIANT_CONTEXT_VISUALS[variant];
  if (!visuals) throw new Error(`Unsupported V5-family variant: ${variant}`);
  if (!hasFocus) return visuals.idle;
  if (isFocused) return visuals.focused;
  if (isRelated) return visuals.related;
  return visuals.dimmed;
}

export function v5VariantFocusTransition(variant, currentFocusedNodeId, tappedNodeId) {
  const policy = V5_VARIANT_INTERACTION_POLICIES[variant];
  if (!policy) throw new Error(`Unsupported V5-family variant: ${variant}`);
  if (!tappedNodeId) return { focusedNodeId: currentFocusedNodeId || null, action: 'ignore' };
  if (policy.repeatTap === 'dehighlight' && currentFocusedNodeId === tappedNodeId) {
    return { focusedNodeId: null, action: 'dehighlight' };
  }
  return { focusedNodeId: tappedNodeId, action: 'focus' };
}

export function createV5VariantFocusSessions() {
  return Object.fromEntries(['v5', 'v6', 'v7'].map((variant) => [variant, { focusedNodeId: null }]));
}

export function transitionV5VariantFocusSession(sessions, variant, tappedNodeId) {
  const session = sessions?.[variant];
  if (!session) throw new Error(`Unsupported V5-family variant session: ${variant}`);
  const transition = v5VariantFocusTransition(variant, session.focusedNodeId, tappedNodeId);
  session.focusedNodeId = transition.focusedNodeId;
  return transition;
}

export const VARIANT_PROFILES = Object.freeze({
  v1: Object.freeze({ layout: null, diagnostic: 'all', edgeLayer: false, backPass: false, bridgeRenderer: 'native-auto', localEdges: true, remoteEdges: true, lod: 'medium' }),
  v2: Object.freeze({ layout: null, diagnostic: 'all', edgeLayer: false, backPass: false, bridgeRenderer: 'native-auto', localEdges: true, remoteEdges: true, lod: 'medium' }),
  v3: Object.freeze({ layout: 'spherical-force', diagnostic: 'all', edgeLayer: true, backPass: true, bridgeRenderer: 'native-auto', localEdges: true, remoteEdges: true, lod: 'medium' }),
  v4: Object.freeze({ layout: 'community-arc', diagnostic: 'all', edgeLayer: true, backPass: true, bridgeRenderer: 'native-weighted', localEdges: true, remoteEdges: true, lod: 'medium' }),
  v5: Object.freeze({ layout: 'community-overkill', diagnostic: 'all', edgeLayer: false, backPass: false, bridgeRenderer: 'native-auto', localEdges: false, remoteEdges: false, lod: 'overkill' }),
  v6: Object.freeze({ layout: 'community-overkill', diagnostic: 'all', edgeLayer: false, backPass: false, bridgeRenderer: 'native-auto', localEdges: false, remoteEdges: false, lod: 'overkill' }),
  v7: Object.freeze({ layout: 'community-overkill', diagnostic: 'all', edgeLayer: false, backPass: false, bridgeRenderer: 'native-auto', localEdges: false, remoteEdges: false, lod: 'overkill' }),
});

export const V4_FOCUS_ARC_ALTITUDE = .025;

export const __v5FamilyFocusVisualTestModel = Object.freeze({
  contextState: (variant, state) => ({ ...v5VariantContextVisualState(variant, state) }),
});

export const __v5VariantInteractionTestModel = Object.freeze({
  policy: (variant) => ({ ...V5_VARIANT_INTERACTION_POLICIES[variant] }),
  createSessions: () => createV5VariantFocusSessions(),
  transitionSession: (sessions, variant, tappedNodeId) => ({
    ...transitionV5VariantFocusSession(sessions, variant, tappedNodeId),
  }),
  transition: (variant, currentFocusedNodeId, tappedNodeId) => ({
    ...v5VariantFocusTransition(variant, currentFocusedNodeId, tappedNodeId),
  }),
});

export const __v7FocusVisualTestModel = Object.freeze({
  contextState: (state) => ({ ...v5VariantContextVisualState('v7', state) }),
});

export const __v6DiffuseLightTestModel = Object.freeze({
  profile: () => ({
    keyIntensity: V6_HYBRID_LIGHT.keyIntensity,
    fillIntensity: V6_HYBRID_LIGHT.fillIntensity,
    rimIntensity: V6_HYBRID_LIGHT.rimIntensity,
    shininess: V6_HYBRID_LIGHT.shininess,
    specular: V6_HYBRID_LIGHT.specular,
    sunDirection: [...V6_HYBRID_LIGHT.sunDirection],
  }),
  affectsVariants: () => ({ v5: false, v6: true, v7: false }),
});
