import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const {
  __v3TestModel,
  __v5FamilyFocusVisualTestModel,
  __v5VariantInteractionTestModel,
  __v6DiffuseLightTestModel,
  __v7FocusVisualTestModel,
  __surfaceSelectionArcTestModel,
  getV5PlanetVisualSnapshot,
} = await import('../assets/explore-galaxy-orb.js?test-v3');
const {
  V5_CITY_FOCUS,
  v5GlobeControlsEnabled,
  v5CityFocusPointOfView,
} = await import('../assets/explore/planet-visuals.js?test-city-focus');

assert.equal(__v3TestModel.atomCount, 700);
assert.ok(__v3TestModel.physicsEdgeCount > 700);

const uniform = __v3TestModel.buildLayout('uniform');
const spherical = __v3TestModel.buildLayout('spherical-force');
const caps = __v3TestModel.buildLayout('community-caps');
const communityArc = __v3TestModel.buildLayout('community-arc');
const communityAdaptive = __v3TestModel.buildLayout('community-adaptive');
const communityOverkill = __v3TestModel.buildLayout('community-overkill');
const overkillPasses = __v3TestModel.buildOverkillPasses(communityOverkill.atoms, communityOverkill.edges);

for (const layout of [uniform, spherical, caps, communityArc, communityAdaptive, communityOverkill]) {
  assert.equal(layout.atoms.length, 700);
  assert.ok(layout.edges.length > 700);
  if (!layout.stats.overkill) assert.ok(layout.edges.length <= 1400);
  layout.atoms.forEach((atom) => {
    assert.ok(Number.isFinite(atom.lat));
    assert.ok(Number.isFinite(atom.lng));
    assert.ok(atom.lat >= -90 && atom.lat <= 90);
    assert.ok(atom.lng >= -180 && atom.lng <= 180);
  });
}

const uniformAgain = __v3TestModel.buildLayout('uniform');
assert.deepEqual(
  uniform.atoms.map(({ id, lat, lng }) => ({ id, lat, lng })),
  uniformAgain.atoms.map(({ id, lat, lng }) => ({ id, lat, lng })),
);
assert.equal(spherical.stats.ticks, 46);
assert.equal(caps.stats.ticks, 0);
assert.equal(communityArc.stats.ticks, 0);
assert.equal(communityAdaptive.stats.ticks, 0);
assert.equal(communityOverkill.stats.overkill, true);
assert.ok(communityOverkill.edges.length > 2000);
assert.deepEqual(
  caps.atoms.map(({ id, lat, lng }) => ({ id, lat, lng })),
  communityOverkill.atoms.map(({ id, lat, lng }) => ({ id, lat, lng })),
);
assert.ok(overkillPasses.filter((edge) => edge.arcPass === 'background').length >= 2000);
assert.ok(overkillPasses.filter((edge) => edge.arcPass === 'structure').length >= 300);
assert.ok(overkillPasses.filter((edge) => edge.arcPass === 'bridge').length >= 20);

// V5 keeps its own native Globe.gl arc data and its size hierarchy must be
// derived from weighted degree, not the old unweighted degree helper.
const v5 = __v3TestModel.v5SizeProfile;
assert.equal(v5.metric, 'weighted-degree');
assert.equal(v5.curve, 'quantile-tiers');
assert.equal(v5.idleArcCount, 0, 'V5 must be path-free before an atom is highlighted');
assert.ok(v5.maxVisualRadius / v5.minVisualRadius >= 4, 'hub to micro radius ratio must stay strong');
assert.ok(v5.farHubToMicroRatio >= 3, 'far LOD cannot collapse the size hierarchy');
assert.deepEqual(v5.tierMultipliers, [.55, .8, 1.15, 1.8, 3.5]);
assert.ok(v5.quantiles.p98 >= v5.quantiles.p90);
assert.ok(v5.quantiles.p90 >= v5.quantiles.p70);

const v5Planet = getV5PlanetVisualSnapshot();
assert.equal(v5Planet.atoms.length, 700, 'Universe focus must reuse the real V5 700-atom planet dataset');
assert.equal(v5Planet.idleEdgeCount, 0, 'V5 must remain path-free until an atom is focused');
assert.ok(v5Planet.atoms.every((atom) => atom.color === '#33D9FF' && atom.glow === '#8AF2FF'));
assert.ok(v5Planet.atoms.some((atom) => atom.visualRadius >= 5), 'the V5 hub hierarchy must survive the Universe embedding');
assert.ok(v5Planet.atoms.every((atom) => Number.isFinite(atom.lat) && Number.isFinite(atom.lng)));

const v7ContextIdle = __v7FocusVisualTestModel.contextState({ hasFocus: false, isFocused: false, isRelated: false });
const v7ContextDim = __v7FocusVisualTestModel.contextState({ hasFocus: true, isFocused: false, isRelated: false });
const v7ContextRelated = __v7FocusVisualTestModel.contextState({ hasFocus: true, isFocused: false, isRelated: true });
assert.equal(v7ContextIdle.emissiveIntensity, .42, 'V7 must restore every inactive city to its full V5 idle glow after dehighlight');
assert.ok(v7ContextDim.sphereOpacity < .1 && v7ContextDim.emissiveIntensity < .03 && v7ContextDim.glowMultiplier < .1, 'V7 context focus must visibly deactivate unrelated cities instead of leaving a uniformly glowing field');
assert.ok(v7ContextRelated.sphereOpacity > .8 && v7ContextRelated.emissiveIntensity > .5, 'directly related cities must stay bright in the V7 context spotlight');

// V5, V6 and V7 are one interaction family. A renderer/light-rig variant may
// not leave unrelated cities or their bridge rings active after a context tap.
// Their view policies must also stay distinct, rather than hiding one shared
// mutable focus/pointer controller behind three different lighting rigs.
const v5VariantPointerRouters = new Set();
for (const variant of ['v5', 'v6', 'v7']) {
  const policy = __v5VariantInteractionTestModel.policy(variant);
  assert.equal(policy.id, variant, `${variant} must own an explicit view policy`);
  v5VariantPointerRouters.add(policy.pointerRouter);
  const idle = __v5FamilyFocusVisualTestModel.contextState(variant, { hasFocus: false, isFocused: false, isRelated: false });
  const dimmed = __v5FamilyFocusVisualTestModel.contextState(variant, { hasFocus: true, isFocused: false, isRelated: false });
  const related = __v5FamilyFocusVisualTestModel.contextState(variant, { hasFocus: true, isFocused: false, isRelated: true });
  assert.equal(idle.emissiveIntensity, .42, `${variant} must restore the idle neon state after dehighlight`);
  assert.ok(dimmed.sphereOpacity < .1 && dimmed.emissiveIntensity < .03 && dimmed.glowMultiplier < .1 && dimmed.bridgeOpacity < .1, `${variant} must dim every non-context city and its bridge ring`);
  assert.ok(related.sphereOpacity > .8 && related.emissiveIntensity > .5 && related.bridgeOpacity >= .5, `${variant} direct context must remain readable`);

  const selected = __v5VariantInteractionTestModel.transition(variant, null, 'pao2');
  const dehighlighted = __v5VariantInteractionTestModel.transition(variant, selected.focusedNodeId, 'pao2');
  const reselected = __v5VariantInteractionTestModel.transition(variant, dehighlighted.focusedNodeId, 'pao2');
  assert.deepEqual(selected, { focusedNodeId: 'pao2', action: 'focus' }, `${variant} first tap must focus only its own city context`);
  assert.deepEqual(dehighlighted, { focusedNodeId: null, action: 'dehighlight' }, `${variant} second tap on the gold city must always dehighlight`);
  assert.deepEqual(reselected, { focusedNodeId: 'pao2', action: 'focus' }, `${variant} must focus again after a deterministic dehighlight`);
}
assert.equal(v5VariantPointerRouters.size, 3, 'V5, V6 and V7 must not share a mutable pointer-routing policy');

// A Globe.gl city focus must be an actual geographic camera target, not the
// legacy card-morph camera that changes OrbitControls to a surface target.
// The first city tap moves gently inward once; city changes keep that exact
// distance and a dehighlight must not request another camera pose.
const cityFocusPov = v5CityFocusPointOfView(
  { lat: 12, lng: 28, altitude: 2.15 },
  { id: 'pao2', lat: -18.25, lng: 41.75 },
);
assert.deepEqual(cityFocusPov, {
  lat: -18.25,
  lng: 41.75,
  altitude: 1.6125,
});
const replacedCityFocusPov = v5CityFocusPointOfView(
  { lat: 55, lng: -4, altitude: .9 },
  { id: 'peep', lat: 22.5, lng: -73.5 },
  cityFocusPov.altitude,
);
assert.deepEqual(replacedCityFocusPov, {
  lat: 22.5,
  lng: -73.5,
  altitude: cityFocusPov.altitude,
}, 'replacing a selected city must retain the one-time focus zoom instead of compounding it');
assert.equal(v5CityFocusPointOfView({ altitude: 2.15 }, { id: 'bad', lat: NaN, lng: 5 }), null,
  'invalid city coordinates must not move the Globe camera');
assert.equal(V5_CITY_FOCUS.durationMs, 680,
  'city focus must be a visible, gradual camera move rather than a jump');

// V5/V6/V7 keep native Globe.gl navigation available while their automatic
// city POV tween runs. Only the legacy card-morph family locks controls while
// it owns the camera transition.
assert.equal(v5GlobeControlsEnabled({ expanded: true, variant: 'v7', focusState: 'orienting' }), true);
assert.equal(v5GlobeControlsEnabled({ expanded: true, variant: 'v7', focusState: 'zooming' }), true);
assert.equal(v5GlobeControlsEnabled({ expanded: true, variant: 'v4', focusState: 'orienting' }), false);
assert.equal(v5GlobeControlsEnabled({ expanded: false, variant: 'v7', focusState: 'idle' }), false);

const isolatedViewSessions = __v5VariantInteractionTestModel.createSessions();
const v5SessionFocus = __v5VariantInteractionTestModel.transitionSession(isolatedViewSessions, 'v5', 'pao2');
assert.equal(v5SessionFocus.focusedNodeId, 'pao2');
assert.equal(isolatedViewSessions.v6.focusedNodeId, null, 'a V5 selection must not create hidden V6 focus state');
assert.equal(isolatedViewSessions.v7.focusedNodeId, null, 'a V5 selection must not create hidden V7 focus state');
const v6SessionFocus = __v5VariantInteractionTestModel.transitionSession(isolatedViewSessions, 'v6', 'peep');
assert.equal(v6SessionFocus.focusedNodeId, 'peep');
assert.equal(isolatedViewSessions.v5.focusedNodeId, 'pao2', 'V6 focus state must not overwrite V5 session state');
assert.equal(isolatedViewSessions.v7.focusedNodeId, null, 'V7 must remain idle until V7 itself receives a tap');

// V6 must be a complete V5-family view with a separate, world-anchored
// cinematic light rig. The source assertions deliberately reject the old
// camera-quaternion headlight as the production V6 light path.
const orbSource = await readFile(new URL('../assets/explore-galaxy-orb.js', import.meta.url), 'utf8');
const planetDataSource = await readFile(new URL('../assets/explore/planet-data.js', import.meta.url), 'utf8');
const planetVisualSource = await readFile(new URL('../assets/explore/planet-visuals.js', import.meta.url), 'utf8');
const planetInputRouterSource = await readFile(new URL('../assets/explore/planet-input-router.js', import.meta.url), 'utf8');
assert.match(orbSource, /from '\.\/explore\/planet-data\.js\?rev=4'/,
  'the browser lifecycle module must import the static planet data model');
assert.match(orbSource, /from '\.\/explore\/planet-visuals\.js\?rev=5'/,
  'the browser lifecycle module must import the isolated V5/V6/V7 visual profiles');
assert.match(planetDataSource, /export const V3_BASE_ATOMS/);
assert.match(planetDataSource, /export function getV5PlanetVisualSnapshot/);
assert.match(planetVisualSource, /export const V5_VARIANT_CONTEXT_VISUALS/);
assert.match(planetVisualSource, /export const V5_CITY_FOCUS/,
  'V5–V7 city taps need an explicit bounded Globe point-of-view focus profile');
assert.match(planetVisualSource, /export function v5CityFocusPointOfView/,
  'the city-focus POV calculation must be pure and regression-testable outside the Globe runtime');
assert.match(planetVisualSource, /export function v5GlobeControlsEnabled/,
  'the V5-family camera policy must keep native Globe.gl navigation available during focus');
assert.match(orbSource, /function focusV5CityCamera\(node, action\)/,
  'the Globe lifecycle must own a dedicated city camera handoff, not silently use the card morph');
assert.match(orbSource, /globe\.pointOfView\(target, V5_CITY_FOCUS\.durationMs\)/,
  'the selected city POV must be applied through the native Globe.gl camera API');
assert.match(orbSource, /applyGlobeControlsProfile\(true\);[\s\S]*globe\.pointOfView\(target, V5_CITY_FOCUS\.durationMs\)/,
  'automatic city zoom must not disable free Globe.gl rotation or zoom');
assert.match(orbSource, /selection\.selectedCityId && transition\.action !== 'dehighlight'/,
  'repeat tapping the selected city must keep the existing dehighlight-only contract without extra zoom');
assert.match(planetVisualSource, /v6:\s*Object\.freeze\(\{\s*layout:\s*'community-overkill'/);
assert.match(planetVisualSource, /v7:\s*Object\.freeze\(\{\s*layout:\s*'community-overkill'/);
assert.match(orbSource, /const v5NodePositionRegistry = new Map\(\)/,
  'V5-family selection must own a stable final-position registry');
assert.match(orbSource, /nodesById:\s*v5NodePositionRegistry/,
  'every V5-family controller must read selection endpoints from the final-position registry');
assert.match(orbSource, /syncV5NodePositionRegistry\(v3Atoms\)/,
  'every V3 layout refresh must update V5-family selection endpoints');
assert.match(orbSource, /data-galaxy-variant="v6"/);
assert.match(orbSource, /function isV6Variant\(\)/);
assert.match(orbSource, /function updateVirtualGalaxyLightRig\(\)/);
assert.match(orbSource, /virtualGalaxyFrame/);
assert.match(orbSource, /new THREE\.HemisphereLight/);
assert.match(orbSource, /new THREE\.DirectionalLight/);
assert.match(planetVisualSource, /cameraOrbitInfluence:\s*\.16/);
assert.match(orbSource, /lightRigMode/);
assert.match(orbSource, /Light Direction Proof/);
assert.doesNotMatch(orbSource, /VirtualSunLensFlareController/);
assert.doesNotMatch(orbSource, /data-v6-flare-mode/);
assert.doesNotMatch(orbSource, /applyV6LensFlare/);
assert.match(orbSource, /CosmicEnvironment/);
assert.doesNotMatch(orbSource, /galaxy-orb-glass/);
assert.doesNotMatch(orbSource, /glassDomeEffect/);
assert.doesNotMatch(orbSource, /Glass dome untouched/);
assert.match(orbSource, /data-v6-cosmic-mode/);
assert.match(orbSource, /applyV6CosmicEnvironment/);
assert.match(orbSource, /v6CosmicEnvironment\?\.updateFrame/);

const diffuseV6Light = __v6DiffuseLightTestModel.profile();
assert.deepEqual(diffuseV6Light, {
  keyIntensity: 1.95,
  fillIntensity: .68,
  rimIntensity: .30,
  shininess: 16,
  specular: '#4EA8C6',
  sunDirection: [-.62, .48, .62],
});
assert.deepEqual(__v6DiffuseLightTestModel.affectsVariants(), {
  v5: false,
  v6: true,
  v7: false,
});
assert.deepEqual(__v6DiffuseLightTestModel.profile().sunDirection, [-.62, .48, .62]);

// V7 is an isolated V5-family view. It delegates its production lighting to
// a controller that updates from Globe.gl's own render frame instead of a
// second requestAnimationFrame loop.
assert.match(orbSource, /data-galaxy-variant="v7"/);
assert.match(orbSource, /function isV7Variant\(\)/);
assert.match(orbSource, /VirtualGalaxyLightingRig/);
assert.match(orbSource, /scene\.onBeforeRender/);
assert.match(orbSource, /Specular Proof/);
assert.match(orbSource, /Universe V3 Reference/);
assert.match(orbSource, /material\.transparent = false;[\s\S]*material\.opacity = 1;[\s\S]*material\.depthWrite = true;/,
  'the V7 planet material must be reset to an opaque depth-writing body after any light-profile switch');
const v7LightPanel = orbSource.slice(orbSource.indexOf('data-v7-light-debug'), orbSource.indexOf('data-v7-cosmic-mode'));
assert.doesNotMatch(v7LightPanel, /value="no-rim"/, 'V7 debug UI must not expose the removed blue side-light mode');
assert.doesNotMatch(orbSource, /data-v7-flare-mode/);
assert.doesNotMatch(orbSource, /applyV7LensFlare/);
assert.doesNotMatch(orbSource, /v7LensFlare\?\.updateFrame/);
assert.match(orbSource, /data-v7-cosmic-mode/);
assert.match(orbSource, /applyV7CosmicEnvironment/);
assert.match(orbSource, /v7CosmicEnvironment\?\.updateFrame/);
assert.doesNotMatch(orbSource, /V5_FAMILY_CONTEXT_VISUALS/);
assert.match(orbSource, /V5_VARIANT_CONTEXT_VISUALS/);

const universeSource = await readFile(new URL('../assets/universe4/universe4-force-controller.js', import.meta.url), 'utf8');
assert.match(universeSource, /UNIVERSE_V3_REFERENCE_LIGHTING/, 'ForceGraph V3 and Globe V7 must read the same V3-reference colour/light tokens');
assert.match(universeSource, /new THREE\.AmbientLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.ambientColor, UNIVERSE_V3_REFERENCE_LIGHTING\.ambientIntensity\)/);
assert.match(universeSource, /new THREE\.HemisphereLight\(\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillColor,\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillGroundColor,\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillIntensity/s);
assert.match(universeSource, /new THREE\.DirectionalLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.keyColor, UNIVERSE_V3_REFERENCE_LIGHTING\.keyIntensity\)/);
assert.match(orbSource, /V5_VARIANT_INTERACTION_POLICIES/);
assert.match(orbSource, /createPlanetInputRouter/);
assert.match(orbSource, /v5PointerRouter\.onPointerDown/);
assert.match(orbSource, /v5PointerRouter\.onPointerUp/);
assert.match(orbSource, /function pickV5NodeFromPointer/);
assert.match(orbSource, /selectedIsFrontFacing/,
  'the selected hit sphere must not win a raycast through the back side of the globe');
assert.match(orbSource, /if \(!isV5Variant\(\)\) focusNode\(point\.id\);/);

// The V5/V6/V7 signal path is deliberately modular: a view-local controller
// decides focus, a dedicated adapter commits Globe arcs, and the HUD only
// observes the trace. The bootstrap must no longer own one shared mutable
// `citySelectionState` closure that couples all three views.
assert.match(orbSource, /createPlanetVariantController/);
assert.match(orbSource, /commitPlanetSelectionArcs/);
assert.match(orbSource, /mountPlanetSignalDebugPanel/);
assert.match(orbSource, /nodesById: v5NodePositionRegistry/);
assert.match(orbSource, /globePointerInteractionEnabled = !isV5Variant\(\);[\s\S]*?globe\.enablePointerInteraction\?\.\(globePointerInteractionEnabled\)/,
  'V5/V6/V7 must hand all selection ownership to their dedicated pointer router');
assert.match(orbSource, /getGlobeControlsDiagnostics/,
  'the embedded V7 controller must expose effective OrbitControls and pointer-surface state');
assert.match(orbSource, /u4\.controls\.start/,
  'the embedded V7 controller must trace native OrbitControls gesture starts');
assert.match(planetInputRouterSource, /pointer\.tap\.no-city/,
  'the on-screen trace must distinguish a raycast miss from a missing tap');
assert.match(orbSource, /arc\.rebind\.clear/,
  'the trace must expose lifecycle clears that could clobber selected arcs');
assert.doesNotMatch(orbSource, /let citySelectionState\s*=/);

const surfaceSelectionCityId = getV5PlanetVisualSnapshot().atoms[0].id;
for (const variant of ['v5', 'v6', 'v7']) {
  const selection = __surfaceSelectionArcTestModel.select(variant, surfaceSelectionCityId);
  assert.equal(selection.ownerVariant, variant);
  assert.ok(selection.selectedCityArcData.length >= 1 && selection.selectedCityArcData.length <= 12);
  assert.ok(selection.selectedCityArcData.every((arc) => arc.renderer === 'surface-selection-arc'));
  assert.ok(selection.selectedCityArcData.every((arc) => arc.startAltitude >= .014 && arc.startAltitude <= .016));
  assert.ok(selection.selectedCityArcData.every((arc) => arc.highlight), 'a city focus must render all direct routes gold');
  assert.equal(__surfaceSelectionArcTestModel.endpointAltitude(selection.selectedCityArcData[0], 'start'), .015);
  assert.deepEqual(__surfaceSelectionArcTestModel.arcProfile(selection.selectedCityArcData[0]), {
    autoScale: 0,
    pathResolution: .5,
    stroke: selection.selectedCityArcData[0].stroke,
  });
}
assert.deepEqual(__surfaceSelectionArcTestModel.clear(), {
  ownerVariant: null,
  selectedCityId: null,
  selectedConnectionIds: [],
  selectedCityArcData: [],
});
assert.doesNotMatch(orbSource, /function v5FocusArcs\(\)[\s\S]*safeV5ArcAltitude/);
assert.match(orbSource, /selectedSurfaceArcEndpointAltitude/);
assert.match(orbSource, /isSurfaceSelectionArc\(edge\)/);
assert.match(orbSource, /if \(isSurfaceSelectionArc\(edge\)\) return DJINN_ORB_V5\.focus/,
  'selected V5/V6/V7 routes must not inherit the blue background-network palette');
assert.match(orbSource, /if \(isSurfaceSelectionArc\(edge\)\) return surfaceSelectionArcProfile\(edge\)\.stroke/,
  'selected routes must use the native Globe tube, not a buried line primitive');
assert.match(orbSource, /\.pathsData\(\[\]\)/,
  'selected routes must use Globe.gl Paths with explicit great-circle samples');
assert.match(orbSource, /pathPoints\(\(edge\) => edge\.surfacePoints\)/,
  'the Paths layer must consume the precomputed surface samples');
assert.match(orbSource, /onEmptyTap: \(\) => clearV5CitySelectionFromEmptyTap\(\)/,
  'a blank globe tap must invoke the same V5/V6/V7 clear transaction');
assert.match(orbSource, /rebindPlanetObjects\(\{[\s\S]*createObject: createNodeObject/,
  'a V5/V6/V7 variant rebind must force Globe.gl to rebuild the hit-target registry');
assert.match(orbSource, /pointer\.pick\.not-ready/,
  'a tap during object rehydration must be diagnosed separately from a real globe miss');
assert.match(orbSource, /morph\.addEventListener\('pointerdown', onPlanetPointerDown, true\)/,
  'the router must listen at the viewport root so transparent overlays cannot swallow globe taps');
assert.match(orbSource, /recordPlanetSignal\('arc\.native\.profile'/,
  'the copyable on-screen trace must prove the effective Globe.gl gold Paths profile');
assert.match(orbSource, /verifiedPathCount/,
  'the rebind trace must verify the active Paths layer rather than the intentionally empty arcs layer');

const [firstSurfaceCityId, secondSurfaceCityId] = getV5PlanetVisualSnapshot().atoms
  .slice(0, 2)
  .map((atom) => atom.id);
for (const variant of ['v5', 'v6', 'v7']) {
  const first = __surfaceSelectionArcTestModel.select(variant, firstSurfaceCityId);
  const second = __surfaceSelectionArcTestModel.select(variant, secondSurfaceCityId);
  assert.ok(first.selectedCityArcData.every((arc) => arc.source === firstSurfaceCityId));
  assert.ok(second.selectedCityArcData.every((arc) => arc.source === secondSurfaceCityId));
  assert.equal(__surfaceSelectionArcTestModel.clear().selectedCityArcData.length, 0);
}

console.log(`explore galaxy v3 model OK (${uniform.atoms.length} atoms, ${uniform.edges.length} visible edges)`);
