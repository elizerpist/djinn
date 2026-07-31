/* A single live Globe.gl scene rendered inline in the Explore scroll content. */
import { knowledgeNodes, knowledgeEdges } from './knowledge-map.js?rev=141';
import * as THREE from './vendor/three.module.min.js?rev=92';
import { DjinnEdgeLayer } from './djinn-edge-layer.js?rev=6';
import { V7_LIGHT_MODES, V7_PRODUCTION_CINEMATIC_BLEND, VirtualGalaxyLightingRig } from './virtual-galaxy-light-rig.js?rev=24';
import { COSMIC_MODES, CosmicEnvironment } from './cosmic-environment.js?rev=6';
import {
  SURFACE_SELECTION_ARC_PROFILE,
  clearCityConnections,
  isSurfaceSelectionArc,
  selectCityConnections,
} from './city-selection-arcs.js?rev=9';
import { createPlanetSignalTrace } from './explore/planet-signal-trace.js?rev=1';
import { createPlanetVariantController } from './explore/planet-variant-controller.js?rev=4';
import { createPlanetInputRouter } from './explore/planet-input-router.js?rev=4';
import { rebindPlanetObjects } from './explore/planet-object-rebind.js?rev=1';
import { getPlanetLabelLod } from './explore/planet-label-lod.js?rev=1';
import {
  clearPlanetSelectionArcs,
  commitPlanetSelectionArcs,
} from './explore/planet-globe-arc-adapter.js?rev=4';
import { mountPlanetSignalDebugPanel } from './explore/planet-debug-panel.js?rev=1';

import {
  ORB_POINTS, ORB_ARCS, nodeById, degreeById, nodeRadius, typeColors, arcPalette,
  clamp, V3_BASE_ATOMS, V3_PHYSICS_EDGES, V3_DEGREE_BY_ID, V3_WEIGHTED_DEGREE_BY_ID,
  V5_SIZE_DEFAULTS, V5_SIZE_PROFILE, V5_BRIDGE_NODE_IDS,
  buildV3Layout, v3OverkillArcPasses, v3NodeRadius, buildV5SizeProfile,
  quantileRank, interpolate, v5ImportanceScale, v5TierForRank,
  getV5PlanetVisualSnapshot, syncV5NodePositionRegistry as syncPlanetNodePositionRegistry,
  surfaceSelectionArcProfile, surfaceSelectionEndpointAltitude,
} from './explore/planet-data.js?rev=4';
import {
  DJINN_ORB_V2, DJINN_ORB_V3, DJINN_ORB_V4, DJINN_ORB_V5, DJINN_ORB_V6, DJINN_ORB_V7,
  V4_FOCUS_ARC_ALTITUDE, V5_CITY_FOCUS, V5_FOCUS_NO_ZOOM, V5_VARIANT_CONTEXT_VISUALS,
  V5_VARIANT_INTERACTION_POLICIES, V6_HYBRID_LIGHT, V6_LIGHT_RIG_MODES,
  VARIANT_PROFILES, v5CityFocusPointOfView, v5GlobeControlsEnabled, v5VariantContextVisualState,
} from './explore/planet-visuals.js?rev=5';
export { __surfaceSelectionArcTestModel, __v3TestModel } from './explore/planet-data.js?rev=4';
export { getV5PlanetVisualSnapshot };
export { __v5FamilyFocusVisualTestModel, __v5VariantInteractionTestModel, __v6DiffuseLightTestModel, __v7FocusVisualTestModel } from './explore/planet-visuals.js?rev=5';
export function initExpandableGalaxyOrb({
  root,
  nav,
  // The embedded Universe 4 endpoint must use this controller verbatim. An
  // initial variant avoids briefly constructing a V1 planet and then mutating
  // it into V7 after the handoff has started.
  initialVariant = 'v1',
  onGlobeReady = null,
  // U4 reuses this exact renderer inside its own stage. In that case the
  // Explore inline-slot geometry does not exist, so the caller supplies the
  // actual measured viewport instead.
  embeddedViewport = null,
  embeddedBarePlanet = false,
  // A host-only diagnostics portal lets Universe 4 expose this controller's
  // existing V7 light controls and copyable signal trace even while its Globe
  // stage is prewarmed at opacity zero beneath the U3 ForceGraph stage.
  embeddedDebugPortal = null,
  // Universe 4 can claim a V5/V6/V7 city tap before this canonical controller
  // applies its normal select/replace logic. The normal Explore route leaves
  // both seams null, so its interaction contract is unchanged.
  onV5CityTap = null,
  onV5SelectionTransition = null,
  onV5CityVisualRole = null,
} = {}) {
  if (!root || !nav) return () => {};
  const requestedInitialVariant = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7'].includes(initialVariant)
    ? initialVariant
    : 'v1';
  const layer = document.createElement('section');
  layer.className = 'expandable-galaxy-orb';
  layer.classList.toggle('is-embedded-bare-planet', Boolean(embeddedBarePlanet));
  layer.dataset.state = 'expanded';
  layer.innerHTML = `
      <div class="galaxy-orb-morph" role="region" aria-label="Universe tudásgalaxis">
      <div class="galaxy-orb-canvas" aria-hidden="true"></div>
      <div class="galaxy-orb-label-layer" aria-hidden="true"></div>
      <article class="galaxy-node-morph-overlay" aria-hidden="true">
        <div class="galaxy-node-card-content">
          <div class="galaxy-node-card-meta"><span data-node-type></span><span data-node-degree></span></div>
          <h2 data-node-title></h2>
          <p data-node-subtitle></p>
          <div class="galaxy-node-card-source" data-node-source></div>
          <div class="galaxy-node-card-actions"><button type="button" data-node-close>Vissza a galaxisba</button></div>
        </div>
      </article>
      <div class="galaxy-orb-controls" aria-hidden="true">
        <span class="galaxy-orb-title">Tudásgalaxis</span>
        <div class="galaxy-orb-variants" role="group" aria-label="Bolygó nézet verziója">
          <button type="button" data-galaxy-variant="v1" class="is-active" aria-pressed="true">V1</button>
          <button type="button" data-galaxy-variant="v2" aria-pressed="false">V2</button>
          <button type="button" data-galaxy-variant="v3" aria-pressed="false">V3</button>
          <button type="button" data-galaxy-variant="v4" aria-pressed="false">V4</button>
          <button type="button" data-galaxy-variant="v5" aria-pressed="false">V5</button>
          <button type="button" data-galaxy-variant="v6" aria-pressed="false">V6</button>
          <button type="button" data-galaxy-variant="v7" aria-pressed="false">V7</button>
        </div>
        <button type="button" class="galaxy-orb-fullscreen-toggle" data-galaxy-action="fullscreen" aria-label="Tudásgalaxis teljes képernyőre váltása" aria-pressed="false" title="Teljes képernyő">⛶</button>
        <button type="button" data-galaxy-action="reset" aria-label="Galaxis középre állítása">⌖</button>
      </div>
      <div class="galaxy-orb-v3-tuning" data-v3-tuning aria-hidden="true">
        <label>Layout
          <select data-v3-layout aria-label="V3 gömbi layout">
            <option value="uniform">Uniform Sphere</option>
            <option value="spherical-force" selected>Spherical Force</option>
            <option value="community-caps">Community Caps</option>
            <option value="community-arc">Community Arc</option>
            <option value="community-adaptive">Community Adaptive</option>
            <option value="community-overkill">Community Overkill</option>
          </select>
        </label>
        <label>Edges
          <select data-v3-edge-diagnostic aria-label="Overkill edge diagnosztika">
            <option value="all" selected>Mindhárom réteg</option>
            <option value="background">Csak háttérháló</option>
            <option value="structure">Csak szerkezeti csövek</option>
            <option value="bridge">Csak kiemelt hidak</option>
            <option value="white">Minden él fehér</option>
            <option value="endpoint">Endpoint Proof</option>
            <option value="radius">Radius Proof</option>
            <option value="facing">Facing Debug</option>
          </select>
        </label>
        <label>Bridge renderer
          <select data-v3-bridge-renderer aria-label="Légi hidak renderere">
            <option value="native-auto" selected>Globe Native Auto</option>
            <option value="native-weighted">Globe Native Weighted</option>
            <option value="custom">Djinn Custom</option>
          </select>
        </label>
        <label class="v3-edge-toggle"><input type="checkbox" data-v3-edge-enabled checked /> Djinn edge</label>
        <label class="v3-edge-toggle"><input type="checkbox" data-v3-edge-back checked /> Back pass</label>
        <label class="v4-edge-toggle"><input type="checkbox" data-v4-local-edges checked /> Közeli kék szálak</label>
        <label class="v4-edge-toggle"><input type="checkbox" data-v4-remote-edges checked /> Távoli arany ívek</label>
        <output data-v3-stats>700 atom · layout előkészítése</output>
      </div>
      <div class="galaxy-orb-v5-size-debug" data-v5-size-debug aria-hidden="true">
        <label class="v5-debug-toggle"><input type="checkbox" data-v5-size-rank-debug /> Size Rank Debug</label>
        <label class="v5-debug-toggle"><input type="checkbox" data-v5-clamp-debug /> Clamp Debug</label>
        <label>Metric <select data-v5-size-metric aria-label="V5 méret metricája"><option value="weighted-degree" selected>weighted degree</option><option value="degree">degree</option></select></label>
        <label>Curve <select data-v5-size-curve aria-label="V5 méretgörbe"><option value="quantile-tiers" selected>quantile tiers</option><option value="linear">linear</option><option value="sqrt">sqrt</option><option value="log">log</option></select></label>
        <label>Min <input type="range" data-v5-size-min min=".9" max="2.1" step=".1" value="1.5" /></label>
        <label>Max <input type="range" data-v5-size-max min="1" max="2.5" step=".1" value="1.5" /></label>
        <label>Hub <input type="range" data-v5-hub-multiplier min="2.8" max="3.5" step=".1" value="3.5" /></label>
        <label>Far LOD <input type="range" data-v5-far-lod-min min=".6" max="1" step=".02" value=".78" /></label>
        <label>Perspective <input type="range" data-v5-perspective min="0" max=".12" step=".005" value=".045" /></label>
        <label>Halo <input type="range" data-v5-halo min="1.2" max="2.4" step=".1" value="1.58" /></label>
        <label>Collision <input type="range" data-v5-collision-padding min=".1" max=".6" step=".02" value=".28" /></label>
        <output data-v5-size-stats>V5 méretprofil előkészítése</output>
      </div>
      <div class="galaxy-orb-v6-light-debug" data-v6-light-debug aria-hidden="true">
        <label>Light rig
          <select data-v6-light-mode aria-label="V6 virtuális fényrig">
            <option value="hybrid" selected>Hybrid Cinematic Rig</option>
            <option value="default-globe">Default Globe Lights</option>
            <option value="camera-headlight">Camera Headlight</option>
            <option value="fixed-galaxy-sun">Fixed Galaxy Sun</option>
            <option value="light-direction-proof">Light Direction Proof</option>
            <option value="no-fill">No Fill</option>
            <option value="no-rim">No Rim</option>
          </select>
        </label>
        <label>Cosmic space
          <select data-v6-cosmic-mode aria-label="V6 kozmikus környezet">
            <option value="cosmic-production" selected>Cosmic Production</option>
            <option value="static-background-proof">Static Background Proof</option>
            <option value="single-star-shell">Single Star Shell</option>
            <option value="three-depth-shells">Three Depth Shells</option>
            <option value="near-stars-exaggerated">Near Stars Exaggerated</option>
            <option value="stars-only">Stars Only</option>
          </select>
        </label>
        <label><input type="checkbox" data-v6-reduced-cosmic /> Reduced cosmic effects</label>
        <output data-v6-light-stats>Virtual light rig előkészítése</output>
      </div>
      <div class="galaxy-orb-v7-light-debug" data-v7-light-debug aria-hidden="true">
        <label>Light rig
          <select data-v7-light-mode aria-label="V7 virtuális galaxiskeretű fényrig">
            <option value="hybrid-cinematic" selected>Hybrid Cinematic Rig</option>
            <option value="default-globe">Default Globe Lights</option>
            <option value="camera-headlight">Camera Headlight</option>
            <option value="fixed-galaxy-sun">Fixed Galaxy Sun</option>
            <option value="universe-v3-reference">Universe V3 Reference</option>
            <option value="no-fill">No Fill</option>
            <option value="specular-proof">Specular Proof</option>
            <option value="light-direction-proof">Light Direction Proof</option>
          </select>
        </label>
        <label>Camera blend <input type="range" data-v7-light-blend min="0" max="1" step=".01" value=".12" /></label>
        <label>Cosmic space
          <select data-v7-cosmic-mode aria-label="V7 kozmikus környezet">
            <option value="cosmic-production" selected>Cosmic Production</option>
            <option value="static-background-proof">Static Background Proof</option>
            <option value="single-star-shell">Single Star Shell</option>
            <option value="three-depth-shells">Three Depth Shells</option>
            <option value="near-stars-exaggerated">Near Stars Exaggerated</option>
            <option value="stars-only">Stars Only</option>
          </select>
        </label>
        <label><input type="checkbox" data-v7-reduced-cosmic /> Reduced cosmic effects</label>
        <output data-v7-light-stats>Virtual Galaxy Lighting Frame előkészítése</output>
      </div>
    </div>`;
  root.append(layer);

  const morph = layer.querySelector('.galaxy-orb-morph');
  const canvas = layer.querySelector('.galaxy-orb-canvas');
  const labelLayer = layer.querySelector('.galaxy-orb-label-layer');
  const planetSignalDebugHost = document.createElement('div');
  planetSignalDebugHost.hidden = true;
  morph.append(planetSignalDebugHost);
  const planetSignalTrace = createPlanetSignalTrace({ limit: 200 });
  const planetSignalDebugPanel = mountPlanetSignalDebugPanel({
    host: planetSignalDebugHost,
    trace: planetSignalTrace,
  });
  // This registry is deliberately narrow: cosmic diagnostics only receive
  // references from their own Three.js branch, never DOM presentation layers.
  const virtualSunObjectRegistry = {
    virtualSunRoot: null,
    sunBody: null,
    sunCore: null,
    sunCorona: null,
    sunLightProxy: null,
    sunLensFlare: null,
    focusedKnowledgePlanet: null,
  };
  const morphOverlay = layer.querySelector('.galaxy-node-morph-overlay');
  const cardContent = layer.querySelector('.galaxy-node-card-content');
  const cardClose = layer.querySelector('[data-node-close]');
  const controlsPanel = layer.querySelector('.galaxy-orb-controls');
  const fullscreenToggle = layer.querySelector('[data-galaxy-action="fullscreen"]');
  let globe = null;
  let embeddedBackgroundColor = null;
  let djinnEdgeLayer = null;
  let destroyed = false;
  let planetSignalRenderTimer = 0;
  let state = 'expanded';
  let bounds = null;
  let resizeObserver = null;
  let focusState = 'idle';
  let focusedNode = null;
  let focusedCameraState = null;
  let v5CityFocusAltitude = null;
  let galaxyFullscreen = false;
  let focusTimer = 0;
  let orbVariant = requestedInitialVariant;
  let ambientLight = null;
  let keyLight = null;
  let fillLight = null;
  let rimLight = null;
  let lightTarget = null;
  let virtualGalaxyFrame = null;
  let lightRigMode = 'hybrid';
  let lightRigFrame = 0;
  let lightRigLastAt = 0;
  let lightRigListener = null;
  let lightProofGroup = null;
  let lightProofArrow = null;
  let lightProofTarget = null;
  let lightProofCamera = null;
  let v6CosmicEnvironment = null;
  let v6CosmicMode = 'cosmic-production';
  let v6ReducedCosmicEffects = false;
  let v7LightRig = null;
  // V7 is the Globe.gl endpoint for Universe 4, so its production default
  // deliberately matches the U3 ForceGraph reference palette and rig.
  let v7LightMode = 'universe-v3-reference';
  let v7CosmicEnvironment = null;
  let v7CosmicMode = 'cosmic-production';
  let v7ReducedCosmicEffects = false;
  let v7LightStatsLastAt = 0;
  let v7SceneBeforeRender = null;
  let v7SceneBeforeRenderHook = null;
  let v7ControlsListener = null;
  let v7ControlStartListener = null;
  let v7ControlEndListener = null;
  let v7LastControlChangeAt = -Infinity;
  let globePointerInteractionEnabled = null;
  let v3LayoutMode = 'spherical-force';
  let v3Atoms = [];
  let v3VisibleEdges = [];
  let v3RenderedEdges = [];
  let v3LayoutStats = null;
  let v3VisibilityListener = null;
  let v3VisibilityFrame = 0;
  let v3Lod = 'medium';
  let v3OverkillDiagnostics = null;
  let v5LabelLod = null;
  let v5LabelProjectionListener = null;
  let v5LabelProjectionFrame = 0;
  const v5LabelElements = new Map();
  // U4 supplies this only while the canonical V7 canvas is still hidden
  // below the Force last-frame veil. Normal Explore never enters this path.
  let embeddedHandoffLabelIds = null;
  let v3DiagnosticMode = 'all';
  let v3EdgeLayerEnabled = true;
  let v3EdgeBackEnabled = true;
  let v3BridgeRenderer = 'native-auto';
  let v3NativeBridgeEdges = [];
  let v4LocalEdgesEnabled = true;
  let v4RemoteEdgesEnabled = true;
  let v4FocusedNeighborId = null;
  let planetGraphRoot = null;
  let edgeRegistryRetryTimer = 0;
  let committedVariant = 'v1';
  const nodeObjects = new Map();
  // The controller needs the actual V3/V5 geographic endpoints, not the
  // small V1/V2 ORB_POINTS map. Keep this Map identity stable for all three
  // isolated controllers and refresh its values when the layout freezes.
  const v5NodePositionRegistry = new Map();
  function syncV5NodePositionRegistry(atoms) {
    return syncPlanetNodePositionRegistry(v5NodePositionRegistry, atoms);
  }
  syncV5NodePositionRegistry(getV5PlanetVisualSnapshot().atoms);
  // Pointer state is intentionally separate for every explicit V5-family
  // view. No tap/drag gesture started in V5 can affect V6 or V7 after a
  // view switch.
  const v5VariantControllers = new Map(['v5', 'v6', 'v7'].map((variant) => [variant,
    createPlanetVariantController({
      variant,
      edges: V3_PHYSICS_EDGES,
      nodesById: v5NodePositionRegistry,
      trace: ({ type, ...payload }) => recordPlanetSignal(type, payload),
    }),
  ]));
  const v5VariantPointerRuntime = new Map(['v5', 'v6', 'v7'].map((variant) => [variant, {
    gestures: new Map(),
    raycaster: new THREE.Raycaster(),
    ndc: new THREE.Vector2(),
  }]));
  // Labels are real DOM above the Globe canvas, so their deliberate mobile
  // taps need their own short gesture gate. They deliberately finish through
  // focusNode(), the exact same selection/U4 handoff seam as a hit sphere.
  const v5LabelGestures = new Map();
  const v5PointerRouter = createPlanetInputRouter({
    canvas,
    runtimeFor: (variant = orbVariant) => v5VariantPointerRuntime.get(variant) || null,
    isEnabled: () => isV5Variant() && state === 'expanded',
    pick: (event) => pickV5NodeFromPointer(event),
    activate: (cityId) => focusNode(cityId),
    onEmptyTap: () => clearV5CitySelectionFromEmptyTap(),
    trace: (event, payload) => recordPlanetSignal(event, payload),
    // The native Explore screen keeps its existing strict orbit gesture
    // threshold. U4 is an embedded mobile destination with DOM city chips
    // above a live globe, where a deliberate finger tap commonly shifts
    // 10–20 CSS pixels before pointerup.
    tapDistanceSquared: embeddedViewport ? 576 : 81,
    tapDurationMs: embeddedViewport ? 620 : 360,
  });
  const variantProfileState = new Map(Object.entries(VARIANT_PROFILES)
    .map(([variant, profile]) => [variant, { ...profile }]));
  const sphereGeometry = new THREE.SphereGeometry(1, 24, 18);
  const v5BridgeRingGeometry = new THREE.TorusGeometry(1, .035, 7, 24);
  const materialCache = new Map();
  const v3Tuning = layer.querySelector('[data-v3-tuning]');
  const v3LayoutSelect = layer.querySelector('[data-v3-layout]');
  const v3DiagnosticSelect = layer.querySelector('[data-v3-edge-diagnostic]');
  const v3BridgeRendererSelect = layer.querySelector('[data-v3-bridge-renderer]');
  const v3EdgeEnabledToggle = layer.querySelector('[data-v3-edge-enabled]');
  const v3EdgeBackToggle = layer.querySelector('[data-v3-edge-back]');
  const v4LocalEdgesToggle = layer.querySelector('[data-v4-local-edges]');
  const v4RemoteEdgesToggle = layer.querySelector('[data-v4-remote-edges]');
  const v3Stats = layer.querySelector('[data-v3-stats]');
  const v5SizeTuning = layer.querySelector('[data-v5-size-debug]');
  const v6LightTuning = layer.querySelector('[data-v6-light-debug]');
  const v6LightModeSelect = layer.querySelector('[data-v6-light-mode]');
  const v6CosmicModeSelect = layer.querySelector('[data-v6-cosmic-mode]');
  const v6ReducedCosmicToggle = layer.querySelector('[data-v6-reduced-cosmic]');
  const v6LightStats = layer.querySelector('[data-v6-light-stats]');
  const v7LightTuning = layer.querySelector('[data-v7-light-debug]');
  const v7LightModeSelect = layer.querySelector('[data-v7-light-mode]');
  const v7LightBlendInput = layer.querySelector('[data-v7-light-blend]');
  const v7CosmicModeSelect = layer.querySelector('[data-v7-cosmic-mode]');
  const v7ReducedCosmicToggle = layer.querySelector('[data-v7-reduced-cosmic]');
  const v7LightStats = layer.querySelector('[data-v7-light-stats]');
  if (embeddedDebugPortal && v7LightTuning) {
    embeddedDebugPortal.classList.add('universe4-v7-debug-portal');
    embeddedDebugPortal.append(v7LightTuning, planetSignalDebugHost);
  }
  const v5SizeRankDebugToggle = layer.querySelector('[data-v5-size-rank-debug]');
  const v5ClampDebugToggle = layer.querySelector('[data-v5-clamp-debug]');
  const v5SizeMetricSelect = layer.querySelector('[data-v5-size-metric]');
  const v5SizeCurveSelect = layer.querySelector('[data-v5-size-curve]');
  const v5SizeMinInput = layer.querySelector('[data-v5-size-min]');
  const v5SizeMaxInput = layer.querySelector('[data-v5-size-max]');
  const v5HubMultiplierInput = layer.querySelector('[data-v5-hub-multiplier]');
  const v5FarLodMinInput = layer.querySelector('[data-v5-far-lod-min]');
  const v5PerspectiveInput = layer.querySelector('[data-v5-perspective]');
  const v5HaloInput = layer.querySelector('[data-v5-halo]');
  const v5CollisionPaddingInput = layer.querySelector('[data-v5-collision-padding]');
  const v5SizeStats = layer.querySelector('[data-v5-size-stats]');
  const v5SizeSettings = { ...V5_SIZE_DEFAULTS };
  let v5SizeRankDebug = false;
  let v5ClampDebug = false;
  let v5RuntimeSizeProfile = V5_SIZE_PROFILE;

  function syncVirtualSunObjectRegistry(cosmicEnvironment, flareController) {
    // The V5 planet is Globe.gl's own world-space globe. It is only a
    // read-only context reference for diagnostics; the cosmic path never
    // writes to its scene graph.
    virtualSunObjectRegistry.virtualSunRoot = cosmicEnvironment?.sunRoot || null;
    virtualSunObjectRegistry.sunBody = cosmicEnvironment?.sunBody || null;
    virtualSunObjectRegistry.sunCore = cosmicEnvironment?.sunCore || null;
    virtualSunObjectRegistry.sunCorona = cosmicEnvironment?.coronas || null;
    virtualSunObjectRegistry.sunLightProxy = flareController?.virtualSunFlareProxy || null;
    virtualSunObjectRegistry.sunLensFlare = flareController?.flare || null;
    virtualSunObjectRegistry.focusedKnowledgePlanet = globe?.scene?.().getObjectByName?.('globe') || planetGraphRoot || null;
  }

  function clearVirtualSunObjectRegistry() {
    virtualSunObjectRegistry.virtualSunRoot = null;
    virtualSunObjectRegistry.sunBody = null;
    virtualSunObjectRegistry.sunCore = null;
    virtualSunObjectRegistry.sunCorona = null;
    virtualSunObjectRegistry.sunLightProxy = null;
    virtualSunObjectRegistry.sunLensFlare = null;
    virtualSunObjectRegistry.focusedKnowledgePlanet = null;
  }

  function schedulePlanetSignalDebugRender(immediate = false) {
    if (immediate) {
      if (planetSignalRenderTimer) window.clearTimeout(planetSignalRenderTimer);
      planetSignalRenderTimer = 0;
      planetSignalDebugPanel.render();
      return;
    }
    if (planetSignalDebugHost.hidden || planetSignalRenderTimer) return;
    planetSignalRenderTimer = window.setTimeout(() => {
      planetSignalRenderTimer = 0;
      if (!destroyed && !planetSignalDebugHost.hidden) planetSignalDebugPanel.render();
    }, 280);
  }

  function recordPlanetSignal(event, payload = {}) {
    planetSignalTrace.record(event, {
      variant: payload.variant || orbVariant,
      ...payload,
    });
    schedulePlanetSignalDebugRender();
  }

  // This is deliberately a low-frequency construction/error trace, not a
  // frame loop. It makes the actual WebGL boundary inspectable on-device:
  // an U4 user can copy the exact V7 signal panel and see whether the canvas
  // has a CSS rectangle, a non-zero drawing buffer and a visible Globe body.
  function recordEmbeddedRenderDiagnostic(event, extra = {}) {
    if (!embeddedViewport) return;
    const viewportRect = embeddedViewport.getBoundingClientRect();
    const canvasRect = canvas.getBoundingClientRect();
    const renderer = globe?.renderer?.();
    const rendererCanvas = renderer?.domElement || canvas.querySelector('canvas');
    const material = globe?.globeMaterial?.();
    const sceneGlobe = globe?.scene?.().getObjectByName?.('globe');
    recordPlanetSignal(event, {
      viewportCss: `${Math.round(viewportRect.width)}x${Math.round(viewportRect.height)}`,
      canvasCss: `${Math.round(canvasRect.width)}x${Math.round(canvasRect.height)}`,
      drawingBuffer: rendererCanvas ? `${rendererCanvas.width}x${rendererCanvas.height}` : 'none',
      renderer: renderer?.constructor?.name || 'none',
      globeCreated: Boolean(globe),
      sceneGlobe: Boolean(sceneGlobe),
      materialVisible: material?.visible !== false,
      materialOpacity: Number.isFinite(material?.opacity) ? Number(material.opacity.toFixed(3)) : null,
      materialTransparent: Boolean(material?.transparent),
      materialColor: material?.color?.getHexString?.() || null,
      ...extra,
    });
  }

  function describeDomTarget(target) {
    if (!target) return null;
    return {
      tag: target.tagName || null,
      id: target.id || null,
      className: typeof target.className === 'string' ? target.className : null,
      role: target.getAttribute?.('role') || null,
      nodeId: target.dataset?.nodeId || null,
    };
  }

  function domStyleSnapshot(element) {
    if (!element) return null;
    let style = null;
    try {
      style = window.getComputedStyle?.(element) || null;
    } catch {
      style = null;
    }
    return {
      pointerEvents: style?.pointerEvents || element.style?.pointerEvents || null,
      touchAction: style?.touchAction || element.style?.touchAction || null,
      display: style?.display || null,
      visibility: style?.visibility || null,
      opacity: style?.opacity || element.style?.opacity || null,
      zIndex: style?.zIndex || null,
    };
  }

  function rectSnapshot(element) {
    const rect = element?.getBoundingClientRect?.();
    if (!rect) return null;
    return {
      left: Math.round(rect.left),
      top: Math.round(rect.top),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
    };
  }

  function getGlobeControlsDiagnostics({ includeDom = true } = {}) {
    const controls = globe?.controls?.() || null;
    const diagnostics = {
      variant: orbVariant,
      controllerState: state,
      focusState,
      pointerInteractionEnabled: globePointerInteractionEnabled,
      controls: controls ? {
        enabled: controls.enabled ?? null,
        enableRotate: controls.enableRotate ?? null,
        enableZoom: controls.enableZoom ?? null,
        enablePan: controls.enablePan ?? null,
        autoRotate: controls.autoRotate ?? null,
        damping: controls.enableDamping ?? null,
        target: controls.target ? {
          x: Number(controls.target.x?.toFixed?.(3) ?? controls.target.x),
          y: Number(controls.target.y?.toFixed?.(3) ?? controls.target.y),
          z: Number(controls.target.z?.toFixed?.(3) ?? controls.target.z),
        } : null,
      } : null,
    };
    if (!includeDom) return diagnostics;

    const rendererCanvas = globe?.renderer?.()?.domElement || canvas.querySelector?.('canvas') || null;
    const viewportRect = embeddedViewport?.getBoundingClientRect?.() || canvas.getBoundingClientRect?.();
    let centerTarget = null;
    if (viewportRect?.width > 0 && viewportRect?.height > 0) {
      try {
        centerTarget = document.elementFromPoint(
          viewportRect.left + viewportRect.width / 2,
          viewportRect.top + viewportRect.height / 2,
        );
      } catch {
        centerTarget = null;
      }
    }
    return {
      ...diagnostics,
      canvas: {
        rect: rectSnapshot(canvas),
        style: domStyleSnapshot(canvas),
      },
      rendererCanvas: {
        rect: rectSnapshot(rendererCanvas),
        style: domStyleSnapshot(rendererCanvas),
      },
      embeddedMount: {
        rect: rectSnapshot(embeddedViewport),
        style: domStyleSnapshot(embeddedViewport),
      },
      hitTestCenter: describeDomTarget(centerTarget),
    };
  }

  function recordGlobeControlsDiagnostic(event, extra = {}, options = {}) {
    if (!embeddedViewport) return;
    recordPlanetSignal(event, {
      source: 'globe-orbit-controls',
      ...getGlobeControlsDiagnostics(options),
      ...extra,
    });
  }

  function syncPlanetSignalDebugVisibility() {
    const visible = isV5Variant();
    planetSignalDebugHost.hidden = !visible;
    morph.classList.toggle('has-planet-signal-debug', visible);
    if (visible) schedulePlanetSignalDebugRender(true);
  }

  function v5VariantControllerFor(variant = orbVariant) {
    return v5VariantControllers.get(variant) || null;
  }

  function activeV5CitySelection() {
    return v5VariantControllerFor()?.state() || clearCityConnections();
  }

  function externalV5CityVisualRole(nodeId) {
    if (typeof onV5CityVisualRole !== 'function' || !isV5Variant()) return null;
    try {
      return onV5CityVisualRole({
        variant: orbVariant,
        cityId: nodeId,
        selection: activeV5CitySelection(),
      }) || null;
    } catch (error) {
      recordPlanetSignal('u4.visual-role.seam.error', {
        cityId: nodeId,
        message: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  function renderV3Stats() {
    if (!v3Stats || !v3LayoutStats) return;
    if (isV5Variant()) {
      const focusArcs = v5FocusArcs();
      const selectedCity = activeV5CitySelection().selectedCityId || '—';
      const renderer = focusArcs[0]?.renderer || 'native-arcs';
      const stroke = focusArcs.length
        ? `${Math.min(...focusArcs.map((arc) => arc.stroke)).toFixed(3)}–${Math.max(...focusArcs.map((arc) => arc.stroke)).toFixed(3)}`
        : '—';
      const sampleCount = focusArcs.length
        ? `${Math.min(...focusArcs.map((arc) => arc.surfacePoints?.length || 0))}–${Math.max(...focusArcs.map((arc) => arc.surfacePoints?.length || 0))}`
        : '—';
      v3Stats.textContent = `${v3LayoutStats.atoms} atom · ${orbVariant.toUpperCase()} · city ${selectedCity} · surface paths ${focusArcs.length} · ${renderer} · alt ${SURFACE_SELECTION_ARC_PROFILE.altitude.toFixed(3)} · path ${SURFACE_SELECTION_ARC_PROFILE.pathResolution}° · samples ${sampleCount} · stroke ${stroke} · LOD ${v3Lod}`;
      renderV5SizeStats();
      return;
    }
    if (djinnEdgeLayer && isDjinnEdgeMode()) {
      const layerStats = djinnEdgeLayer.getDebugStats();
      const v4Toggles = isV4Family()
        ? ` · local ${v4LocalEdgesEnabled ? 'on' : 'off'} · remote ${v4RemoteEdgesEnabled ? 'on' : 'off'}`
        : '';
      v3Stats.textContent = `DjinnEdgeLayer · bridge ${v3BridgeRenderer} · native ${v3NativeBridgeEdges.length}${v4Toggles} · force ${layerStats.forceLinkCount}/${layerStats.forceVisibleLinkCount} · input ${layerStats.inputEdgeCount} · valid ${layerStats.validEdgeCount} · invalid ${layerStats.invalidEndpointCount} · missing ${layerStats.missingNodeCount} · rendered ${layerStats.renderedEdgeCount} · surface ${layerStats.backgroundEdgeCount + layerStats.structureEdgeCount} · bridge ${layerStats.bridgeEdgeCount} · tree ${layerStats.spanningTreeEdgeCount} · isolated ${layerStats.isolatedNodeCount} · endpoint ${layerStats.endpointMaxError.toFixed(3)} · inside ${layerStats.radiusInsideCount} · minR ${layerStats.surfaceMinRadius.toFixed(2)} · maxBridgeR ${layerStats.bridgeMaxRadius.toFixed(2)} · interactive ${layerStats.interactiveEdgeCount} · segments ${layerStats.geodesicSegments} · vertices ${layerStats.vertexCount} · geometry ${layerStats.geometryCount} · material ${layerStats.materialCount} · draw ${layerStats.drawCallCount} · rebuild ${layerStats.rebuildCount} · LOD ${layerStats.lod} · ${layerStats.diagnosticMode}`;
      return;
    }
    if (v3OverkillDiagnostics) {
      const diagnostics = v3OverkillDiagnostics;
      const selected = selectedOverkillEdges();
      const tubes = selected.filter((edge) => edge.arcPass !== 'background' || v3DiagnosticMode === 'white').length;
      const lines = selected.length - tubes;
      v3Stats.textContent = `Overkill renderer active · ${v3DiagnosticMode} · input ${diagnostics.input} · preset ${diagnostics.preset} · selected ${selected.length} · valid ${diagnostics.valid} · created ${selected.length} · zero ${diagnostics.zeroLength} · missing-node ${diagnostics.missing} · Tube ${tubes} · Line ${lines} · front ${diagnostics.front} · back ${diagnostics.back} · culled ${diagnostics.culled}`;
      return;
    }
    v3Stats.textContent = `${v3LayoutStats.atoms} atom · ${v3LayoutStats.visibleEdges} él · ${v3LayoutStats.mode} · LOD ${v3Lod}`;
  }

  function updateOverkillFacingDiagnostics() {
    if (!v3OverkillDiagnostics || !globe) return;
    const cameraDirection = globe.camera().position.clone()
      .sub(globe.controls().target).normalize();
    const renderedByKey = new Map(v3RenderedEdges.map((edge) => [
      [edge.source, edge.target].sort().join('::'),
      edge,
    ]));
    let front = 0;
    let back = 0;
    selectedOverkillEdges().forEach((edge) => {
      const source = new THREE.Vector3(
        Math.cos(edge.startLat * Math.PI / 180) * Math.cos(edge.startLng * Math.PI / 180),
        Math.sin(edge.startLat * Math.PI / 180),
        Math.cos(edge.startLat * Math.PI / 180) * Math.sin(edge.startLng * Math.PI / 180),
      );
      const target = new THREE.Vector3(
        Math.cos(edge.endLat * Math.PI / 180) * Math.cos(edge.endLng * Math.PI / 180),
        Math.sin(edge.endLat * Math.PI / 180),
        Math.cos(edge.endLat * Math.PI / 180) * Math.sin(edge.endLng * Math.PI / 180),
      );
      const facing = source.add(target).normalize().dot(cameraDirection);
      edge.overkillFacing = facing;
      const renderedEdge = renderedByKey.get([edge.source, edge.target].sort().join('::'));
      if (renderedEdge) renderedEdge.overkillFacing = facing;
      if (facing >= 0) front += 1;
      else back += 1;
    });
    v3OverkillDiagnostics.front = front;
    v3OverkillDiagnostics.back = back;
    renderV3Stats();
  }

  function measureBounds() {
    if (embeddedViewport) {
      const rect = embeddedViewport.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      bounds = {
        expanded: {
          left: 0,
          top: 0,
          width: rect.width,
          height: rect.height,
        },
        anchorRect: null,
      };
      applyProgress();
      syncEmbeddedViewportSize();
      return;
    }
    if (!root.classList.contains('is-inline')) return;
    const inlineSlot = root.parentElement;
    if (!inlineSlot?.classList.contains('explore-galaxy-slot')) return;

    const rootRect = root.getBoundingClientRect();
    const width = rootRect.width || inlineSlot.getBoundingClientRect().width;
    const expandedHeight = 230;
    const expandedInset = 12;
    const expanded = {
      left: expandedInset,
      top: 0,
      width: Math.max(0, width - (expandedInset * 2)),
      height: expandedHeight
    };
    bounds = { expanded, anchorRect: null };
    applyProgress();
  }

  // Globe.gl measures its canvas during construction. U4 deliberately
  // prewarms its destination at opacity 0, so that first measurement can be
  // zero even though the absolute stage has a real CSS rectangle. Explicitly
  // applying the U4 viewport keeps the WebGL drawing buffer in sync with the
  // visible stage before it participates in the crossfade.
  function syncEmbeddedViewportSize() {
    if (!embeddedViewport || !globe) return;
    const rect = embeddedViewport.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    globe.width(rect.width).height(rect.height);
    globe.camera()?.updateProjectionMatrix?.();
    globe.controls?.()?.update?.();
  }

  function applyProgress() {
    if (!bounds) return;
    const b = bounds.expanded;
    const inlineSlot = root.closest('.explore-galaxy-slot');
    if (inlineSlot) inlineSlot.style.height = `${b.height}px`;
    morph.style.left = `${b.left}px`;
    morph.style.top = `${b.top}px`;
    morph.style.width = `${b.width}px`;
    morph.style.height = `${b.height}px`;
    morph.style.borderRadius = '24px';
    layer.dataset.state = 'expanded';
    controlsPanel.setAttribute('aria-hidden', 'false');
    controlsPanel.style.opacity = '1';
    morph.classList.add('is-expanded');
    if (globe) applyGlobeProfile(true);
  }

  function syncFullscreenState() {
    const browserFullscreen = document.fullscreenElement === morph;
    const active = browserFullscreen || layer.classList.contains('is-fullscreen');
    galaxyFullscreen = active;
    fullscreenToggle?.setAttribute('aria-pressed', String(active));
    fullscreenToggle?.setAttribute('aria-label', active
      ? 'Tudásgalaxis teljes képernyő bezárása'
      : 'Tudásgalaxis teljes képernyőre váltása');
    fullscreenToggle?.setAttribute('title', active ? 'Teljes képernyő bezárása' : 'Teljes képernyő');
    fullscreenToggle?.replaceChildren(document.createTextNode(active ? '×' : '⛶'));
  }

  async function setGalaxyFullscreen(next) {
    const shouldEnter = Boolean(next);
    if (shouldEnter === galaxyFullscreen && (!shouldEnter || document.fullscreenElement === morph || layer.classList.contains('is-fullscreen'))) return;
    if (!shouldEnter) {
      layer.classList.remove('is-fullscreen');
      if (document.fullscreenElement === morph && document.exitFullscreen) {
        try { await document.exitFullscreen(); } catch (_) { /* WebView may reject after an interrupted gesture. */ }
      }
      syncFullscreenState();
      return;
    }
    if (morph.requestFullscreen) {
      try {
        await morph.requestFullscreen({ navigationUI: 'hide' });
        syncFullscreenState();
        return;
      } catch (_) {
        // Android WebView and embedded previews may not expose the API. Use
        // the fixed-position fallback below instead of failing silently.
      }
    }
    layer.classList.add('is-fullscreen');
    syncFullscreenState();
  }

  function nodeMaterial(node) {
    const key = node.type || 'concept';
    if (!materialCache.has(key)) {
      materialCache.set(key, new THREE.MeshStandardMaterial({
        color: typeColors[key] || typeColors.concept,
        roughness: .65,
        metalness: .05,
        transparent: true,
        opacity: 1,
        depthTest: true,
        depthWrite: true
      }));
    }
    return materialCache.get(key).clone();
  }

  function isV3Family() {
    return orbVariant === 'v3' || orbVariant === 'v4' || orbVariant === 'v5' || orbVariant === 'v6' || orbVariant === 'v7';
  }

  function isV4Family() {
    return orbVariant === 'v4';
  }

  function isV5Variant() {
    return orbVariant === 'v5' || orbVariant === 'v6' || orbVariant === 'v7';
  }

  function isV6Variant() {
    return orbVariant === 'v6';
  }

  function isV7Variant() {
    return orbVariant === 'v7';
  }

  function captureVirtualGalaxyFrame() {
    if (!globe || !lightTarget) return null;
    const camera = globe.camera();
    const controls = globe.controls();
    camera.updateMatrixWorld?.(true);
    const planetCenter = controls.target.clone();
    const entryCameraDirection = camera.position.clone().sub(planetCenter).normalize();
    const sunDirection = new THREE.Vector3(...V6_HYBRID_LIGHT.sunDirection).normalize();
    virtualGalaxyFrame = {
      planetCenter,
      planetQuaternion: globe.scene().quaternion.clone(),
      entryCameraDirection,
      sunDirection,
      currentKeyDirection: sunDirection.clone(),
      currentRimDirection: entryCameraDirection.clone(),
    };
    lightTarget.position.copy(planetCenter);
    lightTarget.updateMatrixWorld(true);
    lightRigLastAt = performance.now();
    return virtualGalaxyFrame;
  }

  function ensureV6CosmicEnvironment() {
    if (!globe) return null;
    if (!v6CosmicEnvironment) {
      v6CosmicEnvironment = new CosmicEnvironment({
        THREE,
        scene: globe.scene(),
        getRenderer: () => globe.renderer(),
        getCamera: () => globe.camera(),
        getPlanetCenter: (target) => target.copy(globe.controls().target),
        getPlanetRadius: () => globe.getGlobeRadius?.() || 100,
        getWorldSunDirection: (target) => target.copy(virtualGalaxyFrame?.sunDirection || new THREE.Vector3(...V6_HYBRID_LIGHT.sunDirection)),
        // V6 contains only the world-space star layers here. The lighting
        // direction remains virtual; it never creates a visible sun object.
        getLensFlareController: () => null,
        planetId: 'explore-v6-knowledge-planet',
      });
      v6CosmicEnvironment.initialize();
    }
    return v6CosmicEnvironment;
  }

  function applyV6CosmicEnvironment() {
    const cosmic = ensureV6CosmicEnvironment();
    if (!cosmic) return;
    cosmic.setMode(v6CosmicMode);
    cosmic.setReducedEffects(v6ReducedCosmicEffects);
    cosmic.captureEntryFrame();
    cosmic.resume();
    syncVirtualSunObjectRegistry(cosmic, null);
  }

  function suspendV6CosmicEnvironment() {
    v6CosmicEnvironment?.suspend();
  }

  function updateV6LightStats() {
    if (!v6LightStats || !globe || !virtualGalaxyFrame || !keyLight) return;
    const cameraDirection = globe.camera().position.clone()
      .sub(virtualGalaxyFrame.planetCenter).normalize();
    const lightAngle = THREE.MathUtils.radToDeg(Math.acos(clamp(
      cameraDirection.dot(virtualGalaxyFrame.currentKeyDirection),
      -1,
      1,
    )));
    const key = keyLight.position.clone().sub(virtualGalaxyFrame.planetCenter);
    const fill = fillLight ? fillLight.intensity.toFixed(2) : '0.00';
    const rim = rimLight ? rimLight.intensity.toFixed(2) : '0.00';
    const cosmic = v6CosmicEnvironment?.getDebugSnapshot();
    const cosmicDebug = cosmic
      ? ` · stars ${cosmic.starCounts.join('/')} · corona ${(cosmic.coronaOpacity * 100).toFixed(0)}%${cosmic.reducedEffects ? ' · reduced' : ''}`
      : '';
    v6LightStats.textContent = `${lightRigMode} · key ${key.length().toFixed(0)}u · camera↔sun ${lightAngle.toFixed(0)}° · key/fill/rim ${keyLight.intensity.toFixed(2)}/${fill}/${rim}${cosmicDebug}`;
  }

  function updateVirtualGalaxyLightRig() {
    if (!isV6Variant() || !globe || !keyLight || !fillLight || !rimLight || !lightTarget) return;
    const frame = virtualGalaxyFrame || captureVirtualGalaxyFrame();
    if (!frame) return;
    const camera = globe.camera();
    camera.updateMatrixWorld?.(true);
    const cameraDirection = camera.position.clone().sub(frame.planetCenter).normalize();
    const now = performance.now();
    const deltaMs = Math.max(1, now - lightRigLastAt);
    lightRigLastAt = now;
    const isDefault = lightRigMode === 'default-globe';
    const isHeadlight = isDefault || lightRigMode === 'camera-headlight';
    const isFixed = lightRigMode === 'fixed-galaxy-sun' || lightRigMode === 'light-direction-proof';
    const influence = isHeadlight ? 1 : (isFixed ? 0 : V6_HYBRID_LIGHT.cameraOrbitInfluence);
    const desiredKeyDirection = frame.sunDirection.clone().lerp(cameraDirection, influence).normalize();
    const smoothing = isHeadlight || isFixed
      ? 1
      : 1 - Math.exp(-deltaMs / V6_HYBRID_LIGHT.lightLagMs);
    frame.currentKeyDirection.lerp(desiredKeyDirection, smoothing).normalize();
    frame.currentRimDirection.lerp(cameraDirection, Math.max(smoothing, .24)).normalize();
    lightTarget.position.copy(frame.planetCenter);
    keyLight.position.copy(frame.planetCenter)
      .addScaledVector(frame.currentKeyDirection, V6_HYBRID_LIGHT.keyDistance);
    rimLight.position.copy(frame.planetCenter)
      .addScaledVector(frame.currentRimDirection, V6_HYBRID_LIGHT.rimDistance);
    keyLight.target = lightTarget;
    rimLight.target = lightTarget;
    ambientLight.visible = isDefault;
    fillLight.visible = !isDefault;
    rimLight.visible = !isDefault;
    keyLight.intensity = isDefault ? 2.6 : V6_HYBRID_LIGHT.keyIntensity;
    fillLight.intensity = lightRigMode === 'no-fill' || isDefault ? 0 : V6_HYBRID_LIGHT.fillIntensity;
    rimLight.intensity = lightRigMode === 'no-rim' || isDefault ? 0 : V6_HYBRID_LIGHT.rimIntensity;
    const proof = lightRigMode === 'light-direction-proof';
    lightProofGroup && (lightProofGroup.visible = proof);
    if (proof) updateLightDirectionProof(frame, camera);
    v6CosmicEnvironment?.updateFrame(now);
    updateV6LightStats();
    const cosmicStillSmoothing = v6CosmicEnvironment?.isSmoothing();
    if ((frame.currentKeyDirection.angleTo(desiredKeyDirection) > .001 && lightRigMode === 'hybrid') || cosmicStillSmoothing) {
      scheduleVirtualGalaxyLightRig();
    }
  }

  function scheduleVirtualGalaxyLightRig() {
    if (!isV6Variant() || !globe || lightRigFrame) return;
    lightRigFrame = requestAnimationFrame(() => {
      lightRigFrame = 0;
      if (!destroyed) updateVirtualGalaxyLightRig();
    });
  }

  function updateLegacyGlobeLight() {
    if (!globe || !keyLight || !lightTarget || isV6Variant() || isV7Variant()) return;
    const camera = globe.camera();
    const controls = globe.controls();
    camera.updateMatrixWorld?.(true);
    const offset = new THREE.Vector3(1.3, .35, 2)
      .applyQuaternion(camera.quaternion).normalize().multiplyScalar(300);
    lightTarget.position.copy(controls.target);
    keyLight.position.copy(controls.target).add(offset);
  }

  function applyVariantLightRig() {
    if (!globe || !ambientLight || !keyLight || !fillLight || !rimLight) return;
    const material = globe.globeMaterial?.();
    if (isV7Variant()) {
      suspendV6CosmicEnvironment();
      applyV7LightRig();
      return;
    }
    suspendV7LightRig();
    // The former V7 list must be replaced explicitly; otherwise its key/fill/
    // rim lights would remain in Globe.gl's scene when returning to V1–V6.
    globe.lights([ambientLight, keyLight, fillLight, rimLight]);
    if (isV6Variant()) {
      if (!virtualGalaxyFrame) captureVirtualGalaxyFrame();
      ambientLight.visible = false;
      keyLight.visible = true;
      fillLight.visible = true;
      rimLight.visible = true;
      if (material) {
        material.color.set(DJINN_ORB_V6.planet);
        material.specular?.set(V6_HYBRID_LIGHT.specular);
        material.shininess = V6_HYBRID_LIGHT.shininess;
        material.emissive?.set(V6_HYBRID_LIGHT.emissive);
        material.emissiveIntensity = V6_HYBRID_LIGHT.emissiveIntensity;
      }
      applyV6CosmicEnvironment();
      scheduleVirtualGalaxyLightRig();
      return;
    }
    suspendV6CosmicEnvironment();
    virtualGalaxyFrame = null;
    ambientLight.visible = true;
    keyLight.visible = true;
    fillLight.visible = false;
    rimLight.visible = false;
    lightProofGroup && (lightProofGroup.visible = false);
    if (material) {
      material.specular?.set('#2B174F');
      material.shininess = 20;
      material.emissive?.set('#000000');
      material.emissiveIntensity = 0;
    }
    updateLegacyGlobeLight();
  }

  function setV6LightRigMode(nextMode) {
    if (!V6_LIGHT_RIG_MODES.includes(nextMode)) return;
    lightRigMode = nextMode;
    if (v6LightModeSelect) v6LightModeSelect.value = nextMode;
    scheduleVirtualGalaxyLightRig();
  }

  function createLightDirectionProof() {
    if (!globe || lightProofGroup) return;
    lightProofGroup = new THREE.Group();
    lightProofGroup.name = 'v6-light-direction-proof';
    lightProofTarget = new THREE.Mesh(
      new THREE.SphereGeometry(1.4, 10, 8),
      new THREE.MeshBasicMaterial({ color: 0x53ff9a, depthTest: false, depthWrite: false }),
    );
    lightProofCamera = new THREE.Mesh(
      new THREE.SphereGeometry(1.1, 10, 8),
      new THREE.MeshBasicMaterial({ color: 0xffffff, depthTest: false, depthWrite: false }),
    );
    lightProofArrow = new THREE.ArrowHelper(new THREE.Vector3(0, 1, 0), new THREE.Vector3(), 40, 0xffd45a, 7, 4);
    lightProofGroup.add(lightProofTarget, lightProofCamera, lightProofArrow);
    lightProofGroup.visible = false;
    globe.scene().add(lightProofGroup);
  }

  function updateLightDirectionProof(frame, camera) {
    if (!lightProofGroup || !lightProofTarget || !lightProofCamera || !lightProofArrow) return;
    lightProofTarget.position.copy(frame.planetCenter);
    lightProofCamera.position.copy(camera.position);
    const direction = keyLight.position.clone().sub(frame.planetCenter).normalize();
    lightProofArrow.position.copy(frame.planetCenter);
    lightProofArrow.setDirection(direction);
    lightProofArrow.setLength(Math.min(70, V6_HYBRID_LIGHT.keyDistance * .22), 8, 5);
  }

  function ensureV7LightRig() {
    if (!globe) return null;
    if (!v7LightRig) {
      const scene = globe.scene();
      v7LightRig = new VirtualGalaxyLightingRig({
        THREE,
        scene,
        getCamera: () => globe.camera(),
        getPlanetCenter: (target) => target.copy(globe.controls().target),
        getPlanetRadius: () => globe.getGlobeRadius?.() || 100,
        planetId: 'explore-v7-knowledge-planet',
      });
      v7LightRig.initialize();
      // This is deliberately Globe.gl's existing render frame, not a second
      // requestAnimationFrame. Controls only update target directions; the
      // smoothed light transform happens immediately before Globe renders.
      v7SceneBeforeRender = scene.onBeforeRender;
      v7SceneBeforeRenderHook = function v7SceneBeforeRenderHook(...args) {
        v7SceneBeforeRender?.apply(this, args);
        if (!destroyed && isV7Variant()) {
          // Covers OrbitControls damping and programmatic pointOfView()
          // transitions even when a platform misses a controls change event.
          v7LightRig?.updateTargetFromCamera();
          v7LightRig?.updateFrame(performance.now());
          v7CosmicEnvironment?.updateFrame(performance.now());
          updateV7LightStats();
        }
      };
      scene.onBeforeRender = v7SceneBeforeRenderHook;
      v7ControlsListener = () => {
        if (isV7Variant()) v7LightRig?.updateTargetFromCamera();
        if (!embeddedViewport || !isV7Variant()) return;
        const now = performance.now();
        if (now - v7LastControlChangeAt < 320) return;
        v7LastControlChangeAt = now;
        recordGlobeControlsDiagnostic(
          'u4.controls.change',
          { reason: 'orbit-controls-change' },
          { includeDom: false },
        );
      };
      v7ControlStartListener = () => recordGlobeControlsDiagnostic('u4.controls.start', { reason: 'orbit-controls-start' });
      v7ControlEndListener = () => recordGlobeControlsDiagnostic('u4.controls.end', { reason: 'orbit-controls-end' });
      globe.controls().addEventListener('change', v7ControlsListener);
      globe.controls().addEventListener('start', v7ControlStartListener);
      globe.controls().addEventListener('end', v7ControlEndListener);
    }
    return v7LightRig;
  }

  function ensureV7CosmicEnvironment() {
    if (!globe) return null;
    if (!v7CosmicEnvironment) {
      v7CosmicEnvironment = new CosmicEnvironment({
        THREE,
        scene: globe.scene(),
        getRenderer: () => globe.renderer(),
        getCamera: () => globe.camera(),
        getPlanetCenter: (target) => target.copy(globe.controls().target),
        getPlanetRadius: () => globe.getGlobeRadius?.() || 100,
        getWorldSunDirection: (target) => v7LightRig
          ? v7LightRig.copyWorldSunDirection(target)
          : target.set(-.62, .54, .57).normalize(),
        // V7 contains only the world-space star field. Its light direction
        // remains virtual, so there is no visible sun or flare overlay.
        getLensFlareController: () => null,
        planetId: 'explore-v7-knowledge-planet',
      });
      v7CosmicEnvironment.initialize();
    }
    return v7CosmicEnvironment;
  }

  function applyV7CosmicEnvironment() {
    const cosmic = ensureV7CosmicEnvironment();
    if (!cosmic) return;
    cosmic.setMode(v7CosmicMode);
    cosmic.setReducedEffects(v7ReducedCosmicEffects);
    cosmic.captureEntryFrame();
    cosmic.resume();
    syncVirtualSunObjectRegistry(cosmic, null);
  }

  function suspendV7CosmicEnvironment() {
    v7CosmicEnvironment?.suspend();
  }

  function updateV7LightMaterial() {
    if (!isV7Variant() || !globe || !v7LightRig) return;
    const material = globe.globeMaterial?.();
    const settings = v7LightRig.getMaterialSettings();
    if (!material) return;
    material.color.set(settings.color);
    material.specular?.set(settings.specular);
    material.shininess = settings.shininess;
    material.emissive?.set(settings.emissive);
    material.emissiveIntensity = settings.emissiveIntensity;
    // A view switch can leave a Globe.gl material with transparency state
    // from an earlier profile. V7's planet body is always a solid occluder.
    material.transparent = false;
    material.opacity = 1;
    material.depthTest = true;
    material.depthWrite = true;
    material.needsUpdate = true;
  }

  function updateV7LightStats(force = false) {
    if (!isV7Variant() || !v7LightRig || !v7LightStats) return;
    const now = performance.now();
    if (!force && now - v7LightStatsLastAt < 220) return;
    v7LightStatsLastAt = now;
    const snapshot = v7LightRig.getDebugSnapshot();
    const camera = new THREE.Vector3(...snapshot.cameraDirection);
    const key = new THREE.Vector3(...snapshot.blendedKeyDirection);
    const keyAngle = THREE.MathUtils.radToDeg(Math.acos(clamp(camera.dot(key), -1, 1)));
    const round = (values) => values.map((value) => value.toFixed(2)).join(',');
    const cosmic = v7CosmicEnvironment?.getDebugSnapshot();
    const cosmicDebug = cosmic
      ? ` · stars ${cosmic.starCounts.join('/')} · corona ${(cosmic.coronaOpacity * 100).toFixed(0)}%${cosmic.reducedEffects ? ' · reduced' : ''}`
      : '';
    v7LightStats.textContent = `${snapshot.mode} · POV ${snapshot.pov.lat.toFixed(0)}°,${snapshot.pov.lng.toFixed(0)}°/${snapshot.pov.altitude.toFixed(2)} · blend ${(v7LightRig.cinematicBlend * 100).toFixed(0)}% · key↔camera ${keyAngle.toFixed(0)}° · key/fill/ambient ${snapshot.keyIntensity.toFixed(2)}/${snapshot.fillIntensity.toFixed(2)}/${snapshot.ambientIntensity.toFixed(2)} · sun ${round(snapshot.worldSunDirection)} · ${snapshot.fps.toFixed(0)} fps${cosmicDebug}`;
  }

  function applyV7LightRig() {
    const rig = ensureV7LightRig();
    if (!rig || !globe) return;
    rig.setMode(v7LightMode);
    rig.setCinematicBlend(Number(v7LightBlendInput?.value ?? V7_PRODUCTION_CINEMATIC_BLEND));
    rig.captureEntryFrame({ planetId: 'explore-v7-knowledge-planet' });
    rig.resume();
    globe.lights(rig.getLights());
    updateV7LightMaterial();
    applyV7CosmicEnvironment();
    updateV7LightStats(true);
  }

  function suspendV7LightRig() {
    if (!v7LightRig) return;
    v7LightRig.suspend();
    suspendV7CosmicEnvironment();
    v7LightStatsLastAt = 0;
  }

  function setV7LightRigMode(nextMode) {
    if (!V7_LIGHT_MODES.includes(nextMode) || !isV7Variant()) return;
    v7LightMode = nextMode;
    if (v7LightModeSelect) v7LightModeSelect.value = nextMode;
    v7LightRig?.setMode(nextMode);
    updateV7LightMaterial();
    updateV7LightStats(true);
  }

  // Narrow embedded-renderer seam for Universe 4's hidden match-cut phase.
  // It never changes the normal Explore route: the live V7 rig still owns
  // the material/lights, but takes the already-rendered U3 world sun vector
  // instead of creating a visually unrelated entry light.
  function applyEmbeddedHandoffLighting(lightSnapshot) {
    if (!embeddedViewport || !isV7Variant() || !globe || !lightSnapshot?.worldSunDirection) return false;
    const direction = lightSnapshot.worldSunDirection;
    if (![direction.x, direction.y, direction.z].every(Number.isFinite)) return false;
    const rig = ensureV7LightRig();
    if (!rig) return false;
    v7LightMode = 'universe-v3-reference';
    if (v7LightModeSelect) v7LightModeSelect.value = v7LightMode;
    rig.setMode(v7LightMode);
    rig.captureEntryFrame({
      planetId: 'universe4-v3-handoff',
      entryLightDirection: new THREE.Vector3(direction.x, direction.y, direction.z),
    });
    rig.resume();
    globe.lights(rig.getLights());
    updateV7LightMaterial();
    updateV7LightStats(true);
    return true;
  }

  function v5NodeHemisphereProfile(facing) {
    // Keep far-side atoms visible, but make the globe read as glass: the
    // camera-facing half is crisp and bright, while the back half is softer,
    // dimmer and carried by a larger halo instead of disappearing.
    const blend = clamp(facing * .5 + .5, 0, 1);
    const smooth = blend * blend * (3 - (2 * blend));
    return {
      opacity: .44 + (.56 * smooth),
      glowOpacity: .06 + (.10 * smooth),
      glowScale: 1.92 - (.42 * smooth),
    };
  }

  function refreshV5SizeProfile() {
    v5RuntimeSizeProfile = buildV5SizeProfile(v3Atoms.length ? v3Atoms : V3_BASE_ATOMS, V3_PHYSICS_EDGES, v5SizeSettings);
  }

  function v5SizeInfo(nodeId) {
    const profile = v5RuntimeSizeProfile || V5_SIZE_PROFILE;
    const metric = profile.metricValues.get(nodeId) || 0;
    const rank = quantileRank(metric, profile.sorted);
    const baseImportanceScale = v5ImportanceScale(rank, v5SizeSettings.curve, v5SizeSettings.hubMultiplier);
    const baseRadius = interpolate(rank, 0, 1, v5SizeSettings.minRadius, v5SizeSettings.maxRadius);
    return {
      metric,
      weightedDegree: profile.weightedDegrees.get(nodeId) || 0,
      rank,
      tier: v5TierForRank(rank),
      baseRadius,
      baseImportanceScale,
      visualRadius: baseRadius * baseImportanceScale,
    };
  }

  function v5PerspectiveScale() {
    if (!globe) return 1;
    const distance = v5LabelDistance();
    // This multiplier is shared by all tiers. It only reacts to camera
    // distance, never to rotation, so it cannot flatten the data hierarchy.
    return clamp(1 + ((2.15 - distance) * v5SizeSettings.perspective), v5SizeSettings.farLodMin, 1.12);
  }

  function v5HitRadius(node, visualRadius) {
    if (!globe?.camera || !globe?.renderer) return Math.max(visualRadius * 1.22, 3.5);
    const camera = globe.camera();
    const rendererSize = globe.renderer().getSize?.(new THREE.Vector2());
    const height = Math.max(Number(rendererSize?.y) || canvas.clientHeight || 1, 1);
    const distance = camera.position.distanceTo(worldPosition(node));
    const worldPerPixel = (2 * Math.tan((camera.fov || 45) * Math.PI / 360) * distance) / height;
    // Twelve to twenty pixels are reserved for the invisible pick target.
    const target = clamp(worldPerPixel * 16, worldPerPixel * 12, worldPerPixel * 20);
    return Math.max(visualRadius * 1.16, target);
  }

  function v5TierDebugColor(tier) {
    return ({ micro: '#6B7280', small: '#38BDF8', medium: '#34D399', large: '#F59E0B', hub: '#F43F5E' })[tier] || DJINN_ORB_V5.atom;
  }

  function renderV5SizeStats() {
    if (!v5SizeStats) return;
    const profile = v5RuntimeSizeProfile || V5_SIZE_PROFILE;
    const q = profile.quantiles;
    const min = profile.minVisualRadius.toFixed(2);
    const max = profile.maxVisualRadius.toFixed(2);
    const clampState = v5ClampDebug ? 'min: nincs univerzális · max: nincs univerzális · zöld: adatvezérelt' : 'clamp: adatvezérelt';
    v5SizeStats.textContent = `Size Rank ${v5SizeRankDebug ? 'ON' : 'OFF'} · weighted min ${q.min.toFixed(2)} · med ${q.median.toFixed(2)} · p70 ${q.p70.toFixed(2)} · p90 ${q.p90.toFixed(2)} · p98 ${q.p98.toFixed(2)} · R ${min}–${max} (${(profile.maxVisualRadius / profile.minVisualRadius).toFixed(1)}×) · ${clampState} · LOD ${v3Lod}`;
  }

  function v5LabelName(node) {
    return String(node?.label || node?.title || node?.id || '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 28);
  }

  function v5LabelDistance() {
    if (!globe) return 2.1;
    return globe.camera().position.distanceTo(globe.controls().target)
      / Math.max(globe.getGlobeRadius?.() || 100, 1);
  }

  function v5LabelLodState() {
    return getPlanetLabelLod({
      distance: v5LabelDistance(),
      focused: Boolean(focusedNode),
    });
  }

  function v5LabelCandidates() {
    const atoms = [...nodeById.values()];
    const importance = (node) => Number(V3_WEIGHTED_DEGREE_BY_ID.get(node.id) || degreeById.get(node.id) || 0);
    const compare = (a, b) => (importance(b) - importance(a)) || String(a.id).localeCompare(String(b.id));
    if (embeddedHandoffLabelIds?.length) {
      return embeddedHandoffLabelIds
        .map((id) => nodeById.get(id))
        .filter(Boolean);
    }
    if (focusedNode) {
      const related = connectedTo(focusedNode.id);
      return [focusedNode, ...atoms.filter((node) => node.id !== focusedNode.id && related.has(node.id)).sort(compare)];
    }

    // Use one high-degree landmark per community first, then fill the small
    // global budget with the remaining strongest atoms.
    const byCommunity = new Map();
    atoms.forEach((node) => {
      const key = node.v3Community ?? 'global';
      const current = byCommunity.get(key);
      if (!current || compare(node, current) < 0) byCommunity.set(key, node);
    });
    const landmarks = [...byCommunity.values()].sort(compare);
    const seen = new Set();
    return [...landmarks, ...atoms.sort(compare)].filter((node) => {
      if (seen.has(node.id)) return false;
      seen.add(node.id);
      return true;
    });
  }

  function labelsOverlap(a, b, padding = 6) {
    return !(a.right + padding < b.left || b.right + padding < a.left
      || a.bottom + padding < b.top || b.bottom + padding < a.top);
  }

  function refreshV5Labels() {
    if (!labelLayer) return;
    if (!isV5Variant() || !globe) {
      labelLayer.replaceChildren();
      v5LabelElements.clear();
      v5LabelLod = null;
      return;
    }
    const width = canvas.clientWidth || morph.clientWidth || 1;
    const height = canvas.clientHeight || morph.clientHeight || 1;
    const camera = globe.camera();
    const cameraDirection = camera.position.clone().sub(globe.controls().target).normalize();
    const labelLod = v5LabelLodState();
    v5LabelLod = labelLod.id;
    const limit = labelLod.limit;
    const accepted = [];
    const visibleIds = new Set();

    v5LabelCandidates().some((node) => {
      if (accepted.length >= limit) return true;
      const text = v5LabelName(node);
      if (!text) return false;
      const position = worldPosition(node);
      const facing = position.clone().normalize().dot(cameraDirection);
      const projected = position.project(camera);
      const isFocused = focusedNode?.id === node.id;
      if (projected.z < -1 || projected.z > 1 || (!isFocused && facing < -.06)) return false;
      const labelWidth = Math.min(148, Math.max(48, text.length * 6.6 + 20));
      const labelHeight = 23;
      const left = (projected.x * .5 + .5) * width - labelWidth / 2;
      const top = (-projected.y * .5 + .5) * height - labelHeight / 2;
      const rect = { left, top, right: left + labelWidth, bottom: top + labelHeight };
      if (rect.right < 8 || rect.left > width - 8 || rect.bottom < 8 || rect.top > height - 8) return false;
      if (accepted.some((other) => labelsOverlap(rect, other))) return false;
      accepted.push(rect);
      visibleIds.add(node.id);
      let element = v5LabelElements.get(node.id);
      if (!element) {
        element = document.createElement('span');
        element.className = 'galaxy-orb-label';
        element.dataset.nodeId = node.id;
        element.textContent = text;
        element.style.width = `${labelWidth}px`;
        v5LabelElements.set(node.id, element);
      } else if (element.textContent !== text) {
        element.textContent = text;
        element.style.width = `${labelWidth}px`;
      }
      element.classList.toggle('is-focus', isFocused);
      element.style.transform = `translate3d(${left}px, ${top}px, 0)`;
      if (element.parentElement !== labelLayer) labelLayer.append(element);
      return false;
    });
    v5LabelElements.forEach((element, nodeId) => {
      if (!visibleIds.has(nodeId)) element.remove();
    });
  }

  // This narrow embedded seam retains the canonical V7 DOM label renderer,
  // but locks its candidate IDs to the labels captured from U3's final frame.
  // It cannot affect the normal Explore route.
  function setEmbeddedHandoffLabelSnapshot(landmarks) {
    if (!embeddedViewport || !isV7Variant()) return false;
    const ids = [...new Set((Array.isArray(landmarks) ? landmarks : [])
      .map((landmark) => landmark?.id)
      .filter((id) => typeof id === 'string' && nodeById.has(id)))];
    if (ids.length < 3) return false;
    embeddedHandoffLabelIds = ids;
    refreshV5Labels();
    return true;
  }

  function clearEmbeddedHandoffLabelSnapshot() {
    if (!embeddedViewport) return false;
    embeddedHandoffLabelIds = null;
    refreshV5Labels();
    return true;
  }

  function setEmbeddedBackgroundColor(nextColor) {
    if (!embeddedViewport || !isV7Variant() || typeof nextColor !== 'string' || !/^#[0-9a-f]{6}$/i.test(nextColor)) return false;
    embeddedBackgroundColor = nextColor.toUpperCase();
    canvas.style.backgroundColor = embeddedBackgroundColor;
    globe?.backgroundColor?.(embeddedBackgroundColor);
    return true;
  }

  // The labels live in a DOM overlay rather than the WebGL scene.  Orbiting
  // moves the camera but not an atom's world position, so projection must be
  // refreshed explicitly on every control change.  Keeping this listener
  // separate from V3's LOD listener prevents a LOD early return from freezing
  // the V5 landmark and focused-node labels on screen.
  function scheduleV5LabelProjection() {
    if (!isV5Variant() || !globe || v5LabelProjectionFrame) return;
    v5LabelProjectionFrame = requestAnimationFrame(() => {
      v5LabelProjectionFrame = 0;
      if (destroyed || !isV5Variant() || !globe) return;
      const camera = globe.camera();
      globe.scene().updateMatrixWorld?.(true);
      camera.updateMatrixWorld?.(true);
      refreshV5Labels();
    });
  }

  function rememberVariantProfile() {
    const profile = variantProfileState.get(orbVariant);
    if (!profile || !isV3Family()) return;
    profile.layout = isV3Family() ? v3LayoutMode : null;
    profile.diagnostic = v3DiagnosticMode;
    profile.edgeLayer = v3EdgeLayerEnabled;
    profile.backPass = v3EdgeBackEnabled;
    profile.bridgeRenderer = v3BridgeRenderer;
    profile.localEdges = v4LocalEdgesEnabled;
    profile.remoteEdges = v4RemoteEdgesEnabled;
    profile.lod = v3Lod;
  }

  function restoreVariantProfile(variant) {
    const variantProfile = variantProfileState.get(variant) || { ...VARIANT_PROFILES.v1 };
    v3LayoutMode = variantProfile.layout || 'spherical-force';
    v3DiagnosticMode = variantProfile.diagnostic;
    v3EdgeLayerEnabled = variantProfile.edgeLayer;
    v3EdgeBackEnabled = variantProfile.backPass;
    v3BridgeRenderer = variantProfile.bridgeRenderer;
    v4LocalEdgesEnabled = variantProfile.localEdges;
    v4RemoteEdgesEnabled = variantProfile.remoteEdges;
    v3Lod = variantProfile.lod;
    if (v3LayoutSelect) v3LayoutSelect.value = v3LayoutMode;
    if (v3DiagnosticSelect) v3DiagnosticSelect.value = v3DiagnosticMode;
    if (v3BridgeRendererSelect) v3BridgeRendererSelect.value = v3BridgeRenderer;
    if (v3EdgeEnabledToggle) v3EdgeEnabledToggle.checked = v3EdgeLayerEnabled;
    if (v3EdgeBackToggle) v3EdgeBackToggle.checked = v3EdgeBackEnabled;
    if (v4LocalEdgesToggle) v4LocalEdgesToggle.checked = v4LocalEdgesEnabled;
    if (v4RemoteEdgesToggle) v4RemoteEdgesToggle.checked = v4RemoteEdgesEnabled;
    return variantProfile;
  }

  function resetFocusForVariantSwitch() {
    cancelAnimationFrame(focusTimer);
    focusTimer = 0;
    clearV5PointerGestures();
    clearAllV5CitySelections('variant-switch');
    focusedNode = null;
    focusedCameraState = null;
    v5CityFocusAltitude = null;
    focusState = 'idle';
    v4FocusedNeighborId = null;
    morphOverlay?.classList.remove('is-visible');
    morphOverlay?.setAttribute('aria-hidden', 'true');
    morphOverlay?.style && (morphOverlay.style.opacity = '0');
    cardContent?.classList.remove('is-readable');
    if (globe) {
      const controls = globe.controls?.();
      if (controls) {
        controls.enableRotate = true;
        controls.enableZoom = true;
        controls.enablePan = false;
        controls.autoRotate = false;
        controls.update?.();
      }
      globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 0);
      clearPlanetSelectionArcs({ globe, trace: planetSignalTrace, reason: 'variant-switch' });
      schedulePlanetSignalDebugRender(true);
    }
  }

  function switchOrbVariant(nextVariant) {
    const normalized = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7'].includes(nextVariant) ? nextVariant : 'v1';
    if (normalized === orbVariant) {
      applyOrbVariant();
      return;
    }
    rememberVariantProfile();
    resetFocusForVariantSwitch();
    orbVariant = normalized;
    if (isV6Variant()) {
      lightRigMode = 'hybrid';
      v6CosmicMode = 'cosmic-production';
      v6ReducedCosmicEffects = false;
    }
    if (isV7Variant()) {
      v7LightMode = 'universe-v3-reference';
      v7CosmicMode = 'cosmic-production';
      v7ReducedCosmicEffects = false;
      if (v7LightBlendInput) v7LightBlendInput.value = String(V7_PRODUCTION_CINEMATIC_BLEND);
    }
    const variantProfile = restoreVariantProfile(orbVariant);
    // Force a real data/material rebind even when two profiles use the same
    // 700-atom dataset.  This prevents Globe.gl's old object cache from
    // keeping the previous variant's colors or visibility flags.
    committedVariant = null;
    if (djinnEdgeLayer) djinnEdgeLayer.setVisible(false);
    applyOrbVariant();
    return variantProfile;
  }

  function activePoints() {
    return isV3Family() ? v3Atoms : ORB_POINTS;
  }

  function resolveActiveNode(nodeId) {
    if (!nodeId) return null;
    return isV3Family()
      ? (v5NodePositionRegistry.get(nodeId) || nodeById.get(nodeId) || null)
      : (nodeById.get(nodeId) || null);
  }

  function applyCitySelection(cityId) {
    return v5VariantControllerFor()?.tap(cityId) || {
      action: 'ignore',
      selection: clearCityConnections(),
    };
  }

  function clearCitySelection(reason = 'clear') {
    return v5VariantControllerFor()?.clear(reason) || {
      action: 'clear',
      selection: clearCityConnections(),
    };
  }

  function clearV5CitySelectionFromEmptyTap() {
    if (!isV5Variant()) return;
    const previous = activeV5CitySelection();
    if (!previous.selectedCityId) {
      recordPlanetSignal('selection.clear.skip', { reason: 'blank-globe-tap', selectedCityId: null });
      return;
    }
    const transition = clearCitySelection('blank-globe-tap');
    focusedNode = null;
    focusedCameraState = null;
    focusState = 'idle';
    v4FocusedNeighborId = null;
    recordPlanetSignal('focus.transition', {
      cityId: previous.selectedCityId,
      action: transition.action,
      selectedCityId: null,
      selectedArcCount: 0,
      reason: 'blank-globe-tap',
    });
    refreshNodeVisuals();
    refreshEdges();
    renderV3Stats();
    notifyV5SelectionTransition({
      source: 'background',
      cityId: null,
      previousSelection: previous,
      selection: transition.selection,
      action: transition.action,
      reason: 'blank-globe-tap',
    });
  }

  function notifyV5SelectionTransition(payload) {
    if (typeof onV5SelectionTransition !== 'function') return;
    try {
      onV5SelectionTransition({
        variant: orbVariant,
        pointOfView: globe?.pointOfView?.() || null,
        ...payload,
      });
    } catch (error) {
      recordPlanetSignal('u4.selection.seam.error', {
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  function clearAllV5CitySelections(reason = 'variant-reset') {
    v5VariantControllers.forEach((controller) => controller.clear(reason));
  }

  function focusV5CityCamera(node, action) {
    if (!globe?.pointOfView || !node) return null;
    // A city focus is an automatic POV tween only. It must never turn the
    // Globe.gl orbit/zoom controls into a fixed view, including during the
    // tween itself.
    applyGlobeControlsProfile(true);
    const currentPointOfView = globe.pointOfView();
    const target = v5CityFocusPointOfView(currentPointOfView, node, v5CityFocusAltitude);
    if (!target) {
      recordPlanetSignal('camera.city-focus.skip', {
        cityId: node.id,
        action,
        reason: 'invalid-city-coordinates',
      });
      return null;
    }
    v5CityFocusAltitude = target.altitude;
    globe.pointOfView(target, V5_CITY_FOCUS.durationMs);
    recordPlanetSignal('camera.city-focus', {
      cityId: node.id,
      action,
      lat: target.lat,
      lng: target.lng,
      startAltitude: Number.isFinite(currentPointOfView?.altitude) ? currentPointOfView.altitude : null,
      targetAltitude: target.altitude,
      durationMs: V5_CITY_FOCUS.durationMs,
    });
    return target;
  }

  function syncV5SelectionArcLayer(reason) {
    if (!globe) {
      recordPlanetSignal('arc.skip.no-globe', { reason });
      return null;
    }
    const selection = activeV5CitySelection();
    const hasSelection = selection.ownerVariant === orbVariant
      && selection.selectedCityId
      && selection.selectedCityArcData.length > 0;
    try {
      const result = hasSelection
        ? commitPlanetSelectionArcs({ globe, selection, trace: planetSignalTrace })
        : clearPlanetSelectionArcs({ globe, trace: planetSignalTrace, reason });
      if (hasSelection) {
        const arcs = selection.selectedCityArcData;
        const strokes = arcs.map((arc) => Number(arc.stroke)).filter(Number.isFinite);
        recordPlanetSignal('arc.native.profile', {
          reason,
          renderer: 'Globe.gl native Paths / great-circle surface line',
          color: DJINN_ORB_V5.focus,
          selectedCityId: selection.selectedCityId,
          continuous: true,
          autoScale: 0,
          altitude: SURFACE_SELECTION_ARC_PROFILE.altitude,
          pathResolution: SURFACE_SELECTION_ARC_PROFILE.pathResolution,
          surfaceSampleMin: Math.min(...arcs.map((arc) => arc.surfacePoints?.length || 0)),
          surfaceSampleMax: Math.max(...arcs.map((arc) => arc.surfacePoints?.length || 0)),
          strokeMin: strokes.length ? Math.min(...strokes) : null,
          strokeMax: strokes.length ? Math.max(...strokes) : null,
          assignedCount: result.assignedCount,
          verifiedCount: result.verifiedCount,
        });
      }
      return result;
    } catch (error) {
      recordPlanetSignal('arc.commit.error', {
        reason,
        message: error instanceof Error ? error.message : String(error),
      });
      return null;
    } finally {
      schedulePlanetSignalDebugRender(true);
    }
  }

  function selectedSurfaceArcEndpointAltitude(arc, endpoint) {
    return surfaceSelectionEndpointAltitude(arc, endpoint, () => arcEndpointAltitude(arc, endpoint));
  }

  function selectedOverkillEdges() {
    if (v3DiagnosticMode === 'all' || v3DiagnosticMode === 'white') return v3RenderedEdges;
    return v3RenderedEdges.filter((edge) => edge.arcPass === v3DiagnosticMode);
  }

  function activeEdges() {
    if (isV5Variant()) return focusedNode ? v5FocusArcs() : [];
    if (!isV3Family()) return ORB_ARCS;
    if (v3LayoutMode !== 'community-overkill') {
      return v3RenderedEdges;
    }
    return selectedOverkillEdges();
  }

  function ensureV3Layout(force = false) {
    if (!force && v3Atoms.length && v3LayoutStats?.mode === v3LayoutMode) return;
    const layout = buildV3Layout(v3LayoutMode);
    v3Atoms = layout.atoms;
    syncV5NodePositionRegistry(v3Atoms);
    v3VisibleEdges = layout.edges;
    v3RenderedEdges = layout.mode === 'community-overkill'
      ? v3OverkillArcPasses(v3Atoms, layout.edges)
      : layout.edges;
    v3LayoutStats = layout.stats;
    refreshV5SizeProfile();
    if (layout.mode === 'community-overkill') {
      const background = v3RenderedEdges.filter((edge) => edge.arcPass === 'background').length;
      const structure = v3RenderedEdges.filter((edge) => edge.arcPass === 'structure').length;
      const bridges = v3RenderedEdges.filter((edge) => edge.arcPass === 'bridge').length;
      const atomIds = new Set(v3Atoms.map((atom) => atom.id));
      const valid = layout.edges.filter((edge) => atomIds.has(edge.source) && atomIds.has(edge.target)).length;
      const zeroLength = layout.edges.filter((edge) => edge.source === edge.target).length;
      v3OverkillDiagnostics = {
        input: V3_PHYSICS_EDGES.length,
        preset: layout.edges.length,
        valid,
        created: v3RenderedEdges.length,
        zeroLength,
        missing: layout.edges.length - valid,
        background,
        structure,
        bridges,
        tubes: structure + bridges,
        lines: background,
        front: '—',
        back: '—',
        culled: 0,
      };
      console.info('[Explore V3] Overkill renderer diagnostics', v3OverkillDiagnostics);
    } else {
      v3OverkillDiagnostics = null;
    }
    v3Atoms.forEach((atom) => {
      nodeById.set(atom.id, atom);
      degreeById.set(atom.id, V3_DEGREE_BY_ID.get(atom.id) || 0);
    });
    renderV3Stats();
  }

  function isDjinnEdgeMode() {
    return Boolean(globe && !isV5Variant() && isV3Family()
      && (orbVariant === 'v4'
        || v3LayoutMode === 'community-caps'
        || v3LayoutMode === 'community-overkill'));
  }

  function bridgeGeo(position) {
    if (globe?.toGeoCoords) {
      const geo = globe.toGeoCoords(position);
      return {
        lat: Number(geo.lat || 0),
        lng: Number(geo.lng || 0),
        altitude: Number(geo.altitude ?? geo.alt ?? .014),
      };
    }
    const normal = position.clone().normalize();
    return {
      lat: Math.asin(clamp(normal.y, -1, 1)) * 180 / Math.PI,
      lng: Math.atan2(normal.z, normal.x) * 180 / Math.PI,
      altitude: .014,
    };
  }

  function arcEndpointAltitude(edge, endpoint) {
    const nodeId = endpoint === 'start' ? edge?.source : edge?.target;
    const node = resolveActiveNode(nodeId);
    const fallback = endpoint === 'start'
      ? Number(edge?.startAltitude ?? .014)
      : Number(edge?.endAltitude ?? .014);
    if (!node) return fallback;

    // Globe.gl's arc endpoints otherwise land at the globe surface.  The
    // V5 atom is a real sphere above that surface, so lift the endpoint past
    // the sphere radius; otherwise the native arc visibly disappears into the
    // node and appears to terminate in empty space.
    const globeRadius = Math.max(globe?.getGlobeRadius?.() || 100, 1);
    const registeredObject = nodeObjects.get(node.id);
    const sphere = registeredObject?.userData?.sphere;
    const worldScale = sphere?.getWorldScale?.(new THREE.Vector3());
    const measuredRadius = Number(worldScale?.x || 0);
    const visualRadius = measuredRadius > 0
      ? measuredRadius
      : (isV5Variant()
        ? v5SizeInfo(node.id).visualRadius
        : (isV3Family()
        ? v3NodeRadius(V3_DEGREE_BY_ID.get(node.id) || 0)
        : nodeRadius(degreeById.get(node.id) || 0)));
    // Keep the tube outside the measured sphere, including its stroke edge.
    // The extra margin is deliberately larger than the previous estimate so
    // oblique/native arcs cannot disappear into translucent node geometry.
    const nodeAltitude = .012 + (visualRadius / globeRadius) + .018;
    return Math.max(fallback, nodeAltitude);
  }

  function nativeBridgeData(bridgeEdges) {
    return bridgeEdges.map((edge) => {
      const source = bridgeGeo(edge.sourcePosition);
      const target = bridgeGeo(edge.targetPosition);
      const peakAltitude = v3BridgeRenderer === 'native-auto'
        ? edge.nativeAutoAltitude
        : edge.peakAltitude;
      return {
        ...edge,
        startLat: source.lat,
        startLng: source.lng,
        startAltitude: source.altitude,
        endLat: target.lat,
        endLng: target.lng,
        endAltitude: target.altitude,
        peakAltitude,
        nativePeakAltitude: peakAltitude,
        nativeRenderer: v3BridgeRenderer,
      };
    });
  }

  function syncDjinnEdgeLayer() {
    if (!globe) return;
    if (!planetGraphRoot) {
      planetGraphRoot = new THREE.Group();
      planetGraphRoot.name = 'planetGraphRoot';
      globe.scene().add(planetGraphRoot);
    }
    if (!djinnEdgeLayer) {
      djinnEdgeLayer = new DjinnEdgeLayer({
        globe,
        planetGraphRoot,
        nodeObjects,
        planetRadius: globe.getGlobeRadius?.() || 100,
        bridgeRenderer: v3BridgeRenderer,
        forceLinkCount: V3_PHYSICS_EDGES.length,
        onEdgeClick: (edge) => {
          djinnEdgeLayer?.setSelectedEdge(edge.id);
          renderV3Stats();
        },
      });
    }
    if (!isDjinnEdgeMode()) {
      djinnEdgeLayer.setVisible(false);
      return;
    }
    djinnEdgeLayer.setForceLinkStats(V3_PHYSICS_EDGES.length, 0);
    djinnEdgeLayer.setNodeRegistry({ objects: nodeObjects, root: planetGraphRoot });
    // The force/layout graph stays complete here. DjinnEdgeLayer applies the
    // production spanning-tree + top-local + bridge policy to the visible set.
    djinnEdgeLayer.setEdges(V3_PHYSICS_EDGES, v3Atoms, {
      planetRadius: globe.getGlobeRadius?.() || 100,
      forceLinkCount: V3_PHYSICS_EDGES.length,
      nodeObjects,
      planetGraphRoot,
      // Native arcs are the geometry source of truth. DjinnEdgeLayer keeps a
      // matching, thin orange pass over them for animated glow; it is not a
      // second trajectory.
      renderBridges: true,
      bridgeRenderer: v3BridgeRenderer,
    });
    djinnEdgeLayer.setEdgeVisibility({
      local: !isV4Family() || v4LocalEdgesEnabled,
      remote: !isV4Family() || v4RemoteEdgesEnabled,
    });
    v3NativeBridgeEdges = nativeBridgeData(djinnEdgeLayer.getBridgeEdges());
    djinnEdgeLayer.setFocus(focusedNode?.id || null);
    djinnEdgeLayer.setDiagnostics(v3DiagnosticMode);
    djinnEdgeLayer.setDebugOptions({ showBack: v3EdgeBackEnabled });
    djinnEdgeLayer.setVisible(v3EdgeLayerEnabled);
    djinnEdgeLayer.updateCamera(globe.camera());
    if (nodeObjects.size < v3Atoms.length && !edgeRegistryRetryTimer && !destroyed) {
      edgeRegistryRetryTimer = window.setTimeout(() => {
        edgeRegistryRetryTimer = 0;
        syncDjinnEdgeLayer();
      }, 60);
    }
  }

  function commitActiveGlobeData(forceRebind = false) {
    if (!globe) return;
    if (isV3Family()) ensureV3Layout();
    const variantChanged = forceRebind || committedVariant !== orbVariant;
    if (variantChanged) {
      rebindPlanetObjects({
        globe,
        points: activePoints(),
        clearRegistry: clearNodeObjectRegistry,
        createObject: createNodeObject,
        trace: recordPlanetSignal,
        reason: forceRebind ? 'forced-rebind' : 'variant-rebind',
      });
    }
    if (isV5Variant()) {
      const selection = activeV5CitySelection();
      recordPlanetSignal('arc.rebind.clear', {
        reason: variantChanged ? 'variant-rebind' : 'data-refresh',
        selectedCityId: selection.selectedCityId,
        selectedArcCount: selection.selectedCityArcData.length,
        priorPathCount: Array.isArray(globe.pathsData?.()) ? globe.pathsData().length : null,
        priorArcCount: Array.isArray(globe.arcsData?.()) ? globe.arcsData().length : null,
      });
    }
    globe
      .objectsData(activePoints())
      .arcsData(isV5Variant()
        ? []
        : (isDjinnEdgeMode()
        ? (v3BridgeRenderer === 'custom' ? [] : v3NativeBridgeEdges)
        : activeEdges()));
    committedVariant = orbVariant;
    if (isV5Variant()) {
      recordPlanetSignal('node.registry.status', {
        targetCount: nodeObjects.size,
        expectedTargetCount: activePoints().length,
      });
    }
    refreshNodeVisuals();
    refreshEdges();
    if (isV5Variant()) {
      const committedPaths = globe.pathsData?.();
      recordPlanetSignal('arc.rebind.recommit', {
        selectedCityId: activeV5CitySelection().selectedCityId,
        verifiedPathCount: Array.isArray(committedPaths) ? committedPaths.length : null,
        verifiedArcCount: Array.isArray(globe.arcsData?.()) ? globe.arcsData().length : null,
      });
    }
  }

  function createNodeObject(node) {
    const group = new THREE.Group();
    const v5Info = isV5Variant() ? v5SizeInfo(node.id) : null;
    const baseRadius = v5Info
      ? v5Info.visualRadius
      : (isV3Family()
        ? v3NodeRadius(V3_DEGREE_BY_ID.get(node.id) || 0)
        : nodeRadius(degreeById.get(node.id) || 0));
    const radius = orbVariant === 'v3' && v3LayoutMode === 'community-overkill'
      ? baseRadius * .78
      : baseRadius;
    const material = nodeMaterial(node);
    if (isV5Variant()) {
      material.color.set(DJINN_ORB_V5.atom);
      material.emissive = new THREE.Color(DJINN_ORB_V5.atomGlow);
      material.emissiveIntensity = .42;
      material.depthTest = false;
      material.depthWrite = false;
    } else if (isV4Family()) {
      material.color.set(DJINN_ORB_V4.atom);
      material.emissive = new THREE.Color(DJINN_ORB_V4.atomGlow);
      material.emissiveIntensity = .28;
    } else if (orbVariant === 'v3') {
      material.color.set(DJINN_ORB_V3.atom);
      material.emissive = new THREE.Color(DJINN_ORB_V3.atomGlow);
      material.emissiveIntensity = .6;
    }
    const sphere = new THREE.Mesh(sphereGeometry, material);
    sphere.scale.setScalar(radius);
    sphere.renderOrder = isV5Variant() ? 3 : 0;
    sphere.castShadow = true;
    sphere.receiveShadow = true;
    const glow = new THREE.Mesh(
      sphereGeometry,
      new THREE.MeshBasicMaterial({
        color: isV5Variant() ? DJINN_ORB_V5.atomGlow : (isV4Family() ? DJINN_ORB_V4.atomGlow : DJINN_ORB_V3.atomGlow),
        transparent: true,
        opacity: isV5Variant() ? .13 : (isV4Family() ? .11 : 0),
        depthTest: false,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      }),
    );
    glow.scale.setScalar(radius * 1.55);
    glow.renderOrder = isV5Variant() ? 4 : 2;
    const hitSphere = new THREE.Mesh(
      sphereGeometry,
      new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false, depthTest: false })
    );
    hitSphere.scale.setScalar(Math.max(radius * 1.5, 3.5));
    hitSphere.userData.isHitTarget = true;
    hitSphere.userData.nodeId = node.id;
    let bridgeRing = null;
    if (isV5Variant() && V5_BRIDGE_NODE_IDS.has(node.id)) {
      bridgeRing = new THREE.Mesh(
        v5BridgeRingGeometry,
        new THREE.MeshBasicMaterial({
          color: '#BFEFFF', transparent: true, opacity: .38, depthTest: false, depthWrite: false,
          blending: THREE.AdditiveBlending,
        }),
      );
      bridgeRing.rotation.set(.75, .35, 0);
      bridgeRing.renderOrder = 5;
      group.add(sphere, glow, bridgeRing, hitSphere);
    } else {
      group.add(sphere, glow, hitSphere);
    }
    group.userData = {
      nodeId: node.id,
      nodeType: node.type || 'concept',
      sphere,
      glow,
      hitSphere,
      bridgeRing,
      v5Size: v5Info,
      baseRadius: radius,
    };
    nodeObjects.set(node.id, group);
    return group;
  }

  function clearNodeObjectRegistry() {
    nodeObjects.forEach((object) => {
      object.userData?.sphere?.material?.dispose?.();
      object.userData?.glow?.material?.dispose?.();
      object.userData?.hitSphere?.material?.dispose?.();
      object.userData?.bridgeRing?.material?.dispose?.();
    });
    nodeObjects.clear();
  }

  function connectedTo(nodeId) {
    const related = new Set([nodeId]);
    const edges = isV3Family() ? V3_PHYSICS_EDGES : knowledgeEdges;
    edges.forEach((edge) => {
      if (edge.source === nodeId) related.add(edge.target);
      if (edge.target === nodeId) related.add(edge.source);
    });
    return related;
  }

  function v4FocusArc() {
    if (!isV4Family() || !focusedNode) return null;
    const candidates = V3_PHYSICS_EDGES
      .filter((edge) => edge.source === focusedNode.id || edge.target === focusedNode.id)
      .sort((a, b) => {
        const weightDelta = Number(b.weight || 0) - Number(a.weight || 0);
        if (Math.abs(weightDelta) > 1e-9) return weightDelta;
        return `${a.source}:${a.target}`.localeCompare(`${b.source}:${b.target}`);
      });
    const edge = candidates[0];
    if (!edge) return null;
    const targetId = edge.source === focusedNode.id ? edge.target : edge.source;
    const targetNode = resolveActiveNode(targetId);
    if (!targetNode) return null;
    v4FocusedNeighborId = targetId;
    const sourceGeo = bridgeGeo(worldPosition(focusedNode));
    const targetGeo = bridgeGeo(worldPosition(targetNode));
    return {
      id: `v4-focus-${focusedNode.id}-${targetId}`,
      source: focusedNode.id,
      target: targetId,
      startLat: sourceGeo.lat,
      startLng: sourceGeo.lng,
      startAltitude: sourceGeo.altitude,
      endLat: targetGeo.lat,
      endLng: targetGeo.lng,
      endAltitude: targetGeo.altitude,
      weight: edge.weight,
      v4FocusArc: true,
      isFocused: true,
    };
  }

  function v5FocusArcs() {
    const selection = activeV5CitySelection();
    if (!isV5Variant() || selection.ownerVariant !== orbVariant) return [];
    return selection.selectedCityArcData;
  }

  function refreshNodeVisuals() {
    const related = focusedNode ? connectedTo(focusedNode.id) : null;
    const v5Mode = isV5Variant();
    const externalSelection = v5Mode ? activeV5CitySelection() : null;
    const externalRootId = externalSelection?.selectedCityId || null;
    const externalContextIds = new Set();
    if (v5Mode && externalRootId) {
      (externalSelection?.selectedCityArcData || []).forEach((arc) => {
        const otherId = arc?.sourceCityId === externalRootId
          ? arc?.targetCityId
          : (arc?.targetCityId === externalRootId ? arc?.sourceCityId : null);
        if (typeof otherId === 'string' && otherId !== externalRootId) externalContextIds.add(otherId);
      });
    }
    nodeObjects.forEach((object, nodeId) => {
      const data = object.userData;
      const node = resolveActiveNode(nodeId);
      if (!node) return;
      const isFocused = focusedNode?.id === nodeId;
      const isRelated = related?.has(nodeId);
      const externalRole = v5Mode && (nodeId === externalRootId || externalContextIds.has(nodeId))
        ? externalV5CityVisualRole(nodeId)
        : null;
      const v5VariantContext = v5Mode
        ? v5VariantContextVisualState(orbVariant, { hasFocus: Boolean(focusedNode), isFocused, isRelated: Boolean(isRelated) })
        : null;
      const overkillMode = (orbVariant === 'v3' && v3LayoutMode === 'community-overkill') || v5Mode;
      const v4Mode = isV4Family();
      const v4PrimaryNeighbor = v4Mode && nodeId === v4FocusedNeighborId;
      const baseOpacity = v5VariantContext
        ? v5VariantContext.sphereOpacity
        : !focusedNode
        ? (v5Mode ? 1 : (overkillMode ? .62 : 1))
        : (isFocused ? 1 : (isRelated ? (v5Mode ? .86 : (overkillMode ? .72 : .86)) : (v5Mode ? .12 : (overkillMode ? .24 : (v4Mode ? .2 : .32)))));
      const facing = isV3Family() && globe
        ? worldPosition(node).normalize()
          .dot(globe.camera().position.clone().sub(globe.controls().target).normalize())
        : 1;
      const v5Profile = v5Mode ? v5NodeHemisphereProfile(facing) : null;
      const v5Info = v5Mode ? v5SizeInfo(nodeId) : null;
      const perspectiveScale = v5Mode ? v5PerspectiveScale() : 1;
      const interactionScale = v5Mode ? (isFocused ? 1.16 : (isRelated ? 1.035 : 1)) : (isFocused ? 1.12 : 1);
      const visualRadius = v5Mode
        ? v5Info.baseRadius * v5Info.baseImportanceScale * perspectiveScale * interactionScale
        : data.baseRadius * interactionScale;
      data.v5Size = v5Info;
      data.externalRole = externalRole;
      data.baseImportanceScale = v5Info?.baseImportanceScale || 1;
      data.perspectiveScale = perspectiveScale;
      data.interactionScale = interactionScale;
      data.visualRadius = visualRadius;
      data.collisionRadius = v5Mode
        ? visualRadius + (visualRadius * v5SizeSettings.collisionPadding)
        : visualRadius * 1.24;
      data.hitRadius = v5Mode ? v5HitRadius(node, visualRadius) : Math.max(visualRadius * 1.5, 3.5);
      const hemisphereOpacity = v5Mode
        ? v5Profile.opacity
        : (isV3Family() ? clamp((facing + .12) / .3, 0, 1) : 1);
      const opacity = baseOpacity * hemisphereOpacity;
      data.baseOpacity = baseOpacity;
      let v5DataColor = v5ClampDebug
        ? '#48E5A9' // green = data-driven; no universal min/max clamp is active in production
        : (v5SizeRankDebug ? v5TierDebugColor(v5Info.tier) : (v5VariantContext?.color || (isFocused ? DJINN_ORB_V5.focus : (focusedNode && !isRelated ? DJINN_ORB_V5.atomDim : DJINN_ORB_V5.atom))));
      // U4 city semantics: the selected mother/root is gold; selectable
      // child/context cities are blue-cyan. This seam is inactive in Explore.
      if (!v5ClampDebug && !v5SizeRankDebug && externalRole === 'root') v5DataColor = '#FFD45A';
      if (!v5ClampDebug && !v5SizeRankDebug && externalRole === 'context') v5DataColor = '#77E8FF';
      const color = v5Mode
        ? v5DataColor
        : v4Mode
        ? (isFocused
          ? DJINN_ORB_V4.focus
          : (v4PrimaryNeighbor
            ? DJINN_ORB_V4.remoteGlow
            : (focusedNode ? (isRelated ? DJINN_ORB_V4.atom : DJINN_ORB_V4.atomDim) : DJINN_ORB_V4.atom)))
        : orbVariant === 'v3'
          ? (isFocused ? DJINN_ORB_V3.focus : (isRelated ? DJINN_ORB_V3.atom : DJINN_ORB_V3.atomDim))
        : orbVariant === 'v2'
          ? (isFocused ? DJINN_ORB_V2.focus : DJINN_ORB_V2.atom)
          : (typeColors[data.nodeType] || typeColors.concept);
      data.sphere.material.color.set(color);
      data.sphere.material.opacity = opacity;
      // V5 is an all-around luminous atom field: its spheres must remain
      // visible even when their coordinates are on the far side of the
      // planet.  Render them after the globe without changing the V3/V4
      // depth-tested presentation.
      data.sphere.material.depthTest = !v5Mode;
      data.sphere.material.depthWrite = !v5Mode;
      data.sphere.renderOrder = v5Mode ? 3 : 0;
      data.sphere.material.emissive = new THREE.Color(externalRole === 'root'
        ? '#FFD45A'
        : externalRole === 'context'
          ? '#5EEFFF'
          : v5Mode
        ? (isFocused ? DJINN_ORB_V5.focusGlow : DJINN_ORB_V5.atomGlow)
        : (isFocused
          ? (v4Mode ? DJINN_ORB_V4.focusGlow : (orbVariant === 'v3' ? DJINN_ORB_V3.focusGlow : (orbVariant === 'v2' ? DJINN_ORB_V2.focusGlow : '#9B7BFF')))
          : (v4Mode ? DJINN_ORB_V4.atomGlow : '#000000')));
      data.sphere.material.emissiveIntensity = externalRole === 'root' || externalRole === 'context'
        ? .9
        : v5VariantContext
        ? v5VariantContext.emissiveIntensity
        : isFocused
        ? (v5Mode ? .98 : (v4Mode ? .95 : (orbVariant === 'v3' ? .6 : .42)))
        : (v5Mode ? (focusedNode ? (isRelated ? .62 : .06) : .42) : (v4Mode ? .28 : (overkillMode ? .04 : 0)));
      // visualRadius = baseImportanceScale × perspectiveScale × interactionScale.
      // Rotation only affects opacity; it never rewrites this data-driven size.
      data.sphere.scale.setScalar(visualRadius);
      if (data.glow) {
        data.glow.visible = v4Mode || v5Mode;
        data.glow.material.color.set(externalRole === 'root'
          ? '#FFD45A'
          : externalRole === 'context'
            ? '#5EEFFF'
            : isFocused
          ? (v5Mode ? DJINN_ORB_V5.focusGlow : DJINN_ORB_V4.focusGlow)
          : (v5Mode ? DJINN_ORB_V5.atomGlow : (v4PrimaryNeighbor ? DJINN_ORB_V4.remoteGlow : DJINN_ORB_V4.atomGlow)));
        data.glow.material.opacity = externalRole === 'root' || externalRole === 'context'
          ? clamp(v5Profile.glowOpacity * 2.2, 0, .48)
          : v5Mode
          ? clamp(v5Profile.glowOpacity * (v5VariantContext?.glowMultiplier ?? (isFocused ? 2.8 : (isRelated ? 1.5 : .25))), 0, .48)
          : (v4Mode
            ? clamp((isFocused ? .36 : (v4PrimaryNeighbor ? .26 : (isRelated ? .18 : .11))) * hemisphereOpacity, 0, .48)
            : 0);
        data.glow.scale.setScalar(v5Mode
          ? visualRadius * v5SizeSettings.halo * (v5Profile?.glowScale || 1)
          : data.baseRadius * (isFocused ? 1.9 : (v4PrimaryNeighbor ? 1.65 : 1.42)));
      }
      if (data.bridgeRing) {
        data.bridgeRing.visible = v5Mode;
        if (externalRole === 'root') data.bridgeRing.material.color.set('#FFD45A');
        else if (externalRole === 'context') data.bridgeRing.material.color.set('#5EEFFF');
        data.bridgeRing.material.opacity = v5Mode ? (v5VariantContext?.bridgeOpacity ?? (isFocused ? .74 : (isRelated ? .5 : .34))) : 0;
        data.bridgeRing.scale.setScalar(visualRadius * 1.18);
      }
      data.hitSphere.scale.setScalar(data.hitRadius);
      data.hitSphere.visible = true;
      object.visible = (focusState !== 'morphing-to-card' || !isFocused)
        && (!isV3Family() || isV5Variant() || facing > -.12);
    });
    refreshV5Labels();
  }

  function refreshV5CameraVisuals() {
    if (!isV5Variant() || !globe) return;
    const camera = globe.camera();
    const controls = globe.controls();
    const cameraDirection = camera.position.clone().sub(controls.target).normalize();
    const scratchPosition = new THREE.Vector3();
    const related = focusedNode ? new Set([focusedNode.id]) : null;
    if (related) {
      const selection = activeV5CitySelection();
      (selection?.selectedCityArcData || []).forEach((arc) => {
        if (arc?.sourceCityId === focusedNode.id) related.add(arc.targetCityId);
        if (arc?.targetCityId === focusedNode.id) related.add(arc.sourceCityId);
      });
    }
    nodeObjects.forEach((object, nodeId) => {
      const data = object.userData;
      object.getWorldPosition?.(scratchPosition);
      const facing = scratchPosition.normalize().dot(cameraDirection);
      const profile = v5NodeHemisphereProfile(facing);
      const isFocused = focusedNode?.id === nodeId;
      const isRelated = related?.has(nodeId);
      const glowMultiplier = isFocused ? 2.8 : (isRelated ? 1.5 : .25);
      data.sphere.material.opacity = (data.baseOpacity ?? 1) * profile.opacity;
      if (data.glow) {
        data.glow.material.opacity = data.externalRole === 'root' || data.externalRole === 'context'
          ? clamp(profile.glowOpacity * 2.2, 0, .48)
          : clamp(profile.glowOpacity * glowMultiplier, 0, .48);
        data.glow.scale.setScalar(data.visualRadius * v5SizeSettings.halo * profile.glowScale);
      }
      object.visible = focusState !== 'morphing-to-card' || !isFocused;
    });
  }

  function refreshEdges() {
    if (!globe) return;
    if (isV5Variant()) {
      djinnEdgeLayer?.setVisible(false);
      syncV5SelectionArcLayer(focusedNode ? 'focus-refresh' : 'idle-refresh');
      return;
    }
    if (isDjinnEdgeMode()) {
      djinnEdgeLayer?.setFocus(focusedNode?.id || null);
      djinnEdgeLayer?.setDiagnostics(v3DiagnosticMode);
      djinnEdgeLayer?.setDebugOptions({ showBack: v3EdgeBackEnabled });
      djinnEdgeLayer?.setVisible(v3EdgeLayerEnabled);
      if (v3BridgeRenderer !== 'custom' && djinnEdgeLayer) {
        v3NativeBridgeEdges = nativeBridgeData(djinnEdgeLayer.getBridgeEdges());
      }
      const focusArc = v4FocusArc();
      const nativeArcs = v3BridgeRenderer === 'custom' ? [] : v3NativeBridgeEdges;
      globe.arcsData([
        ...(isV4Family() && !v4RemoteEdgesEnabled ? [] : nativeArcs),
        ...(focusArc ? [focusArc] : []),
      ]);
      return;
    }
    djinnEdgeLayer?.setVisible(false);
    const related = focusedNode ? connectedTo(focusedNode.id) : null;
    activeEdges().forEach((edge) => {
      edge.isFocused = Boolean(focusedNode && (edge.source === focusedNode.id || edge.target === focusedNode.id));
      edge.isRelated = Boolean(related && related.has(edge.source) && related.has(edge.target));
    });
    const arcs = orbVariant === 'v3'
      ? activeEdges().filter((edge, index) => (
        edge.isFocused || edge.isRelated || (!focusedNode && (v3Lod !== 'far' || index % 2 === 0))
      ))
      : orbVariant === 'v2'
        ? ORB_ARCS.filter((edge, index) => index % 3 === 0 || edge.isFocused || edge.isRelated)
        : ORB_ARCS;
    globe.arcsData(arcs);
  }

  function arcColorFor(edge) {
    // Selected V5/V6/V7 routes are one gold native-Globe layer. They must
    // never inherit the blue background-network palette or a debug override.
    if (isSurfaceSelectionArc(edge)) return DJINN_ORB_V5.focus;
    if (isV3Family() && v3DiagnosticMode === 'white') return '#FFFFFF';
    if (edge.v4FocusArc) return DJINN_ORB_V4.focus;
    if (edge.isFocused) return isV3Family() ? '#FFB347' : '#FFFFFF';
    if (edge.nativeRenderer) {
      if (edge.bridgeTier === 'hero') return isV4Family() ? DJINN_ORB_V4.remoteGlow : '#FFB347';
      if (isV4Family()) {
        if (edge.bridgeTier === 'major') return '#FFB13B';
        return '#FF7A2F';
      }
      if (edge.bridgeTier === 'major') return '#FF933C';
      return '#F07832';
    }
    const largeArcStyle = orbVariant === 'v2' || (orbVariant === 'v3' && v3LayoutMode === 'community-arc');
    const overkillArcStyle = orbVariant === 'v3' && v3LayoutMode === 'community-overkill';
    if (overkillArcStyle) {
      const back = Number(edge.overkillFacing) < 0;
      if (edge.arcPass === 'background') return back ? DJINN_ORB_V3.overkillBack : DJINN_ORB_V3.overkillBackground;
      if (edge.arcPass === 'bridge') return edge.isFocused ? '#FFB347' : (back ? '#704326' : '#FF933C');
      if (edge.arcPass === 'structure') {
        const strong = edge.isFocused || Number(edge.weight || 0) >= .78;
        return strong ? '#43E7F8' : (back ? '#28616E' : DJINN_ORB_V3.atom);
      }
      return DJINN_ORB_V3.edge;
    }
    if (edge.isRelated) return largeArcStyle ? DJINN_ORB_V2.atom : '#E9D5FF';
    if (orbVariant === 'v3' && v3LayoutMode === 'community-arc') return DJINN_ORB_V2.structure;
    if (orbVariant === 'v3') return DJINN_ORB_V3.edge;
    return orbVariant === 'v2'
      ? DJINN_ORB_V2.structure
      : arcPalette[Math.floor(Math.abs(Number(edge.weight || 0) * 1000 + String(edge.source).length)) % arcPalette.length];
  }

  function adaptiveArcAltitude(edge) {
    const toVector = (lat, lng) => {
      const latitude = lat * Math.PI / 180;
      const longitude = lng * Math.PI / 180;
      return new THREE.Vector3(
        Math.cos(latitude) * Math.cos(longitude),
        Math.sin(latitude),
        Math.cos(latitude) * Math.sin(longitude),
      );
    };
    const source = toVector(edge.startLat, edge.startLng);
    const target = toVector(edge.endLat, edge.endLng);
    const angularDistance = Math.acos(clamp(source.dot(target), -1, 1));
    const normalizedDistance = clamp(angularDistance / Math.PI, 0, 1);
    const emphasis = edge.isFocused ? .002 : (edge.isRelated ? .001 : 0);
    return Math.min(.018, .003 + (normalizedDistance * .012) + emphasis);
  }

  function overkillArcAltitude(edge) {
    // Keep the dense web above the shell, but avoid satellite-orbit arcs.
    return Math.min(.04, adaptiveArcAltitude(edge) * 1.8 + .003);
  }

  function applyArcProfile() {
    if (!globe) return;
    const nativeBridgeMode = isDjinnEdgeMode() && v3BridgeRenderer !== 'custom';
    const nativeWeighted = v3BridgeRenderer === 'native-weighted';
    const largeArcStyle = orbVariant === 'v2' || (orbVariant === 'v3' && v3LayoutMode === 'community-arc');
    const v3SmallArcStyle = isV3Family() && !largeArcStyle;
    const adaptiveArcStyle = orbVariant === 'v3' && v3LayoutMode === 'community-adaptive';
    const overkillArcStyle = orbVariant === 'v3' && v3LayoutMode === 'community-overkill';
    globe.arcColor(arcColorFor);
    globe.arcCurveResolution(nativeBridgeMode ? 64 : (overkillArcStyle ? 12 : 64));
    globe.arcCircularResolution((nativeBridgeMode || isV5Variant()) ? 4 : (overkillArcStyle ? 3 : 6));
    globe.arcsTransitionDuration(nativeBridgeMode || isV5Variant() ? 0 : 350);
    globe.arcAltitude((edge) => {
      if (isSurfaceSelectionArc(edge)) return surfaceSelectionArcProfile(edge).altitude;
      if (edge.v4FocusArc) return V4_FOCUS_ARC_ALTITUDE;
      if (nativeBridgeMode) return nativeWeighted ? edge.peakAltitude : null;
      if (overkillArcStyle) return overkillArcAltitude(edge);
      if (adaptiveArcStyle) return adaptiveArcAltitude(edge);
      if (edge.isFocused) return v3SmallArcStyle ? .06 : .32;
      if (edge.isRelated) return v3SmallArcStyle ? .045 : .26;
      return v3SmallArcStyle ? .025 : (largeArcStyle ? .22 : .19);
    });
    globe.arcAltitudeAutoScale((edge) => {
      if (isSurfaceSelectionArc(edge)) return surfaceSelectionArcProfile(edge).autoScale;
      return nativeBridgeMode ? (edge.autoScale ?? .55) : .5;
    });
    globe.arcStroke((edge) => {
      // A thin native TubeGeometry gives the selected route a stable, visible
      // gold core. It samples Globe.gl's own geodetic arc; no custom chord or
      // straight-line overlay is involved.
      if (isSurfaceSelectionArc(edge)) return surfaceSelectionArcProfile(edge).stroke;
      if (edge.v4FocusArc) return .14;
      if (nativeBridgeMode) {
        if (v3DiagnosticMode === 'white') return .12;
        if (edge.bridgeTier === 'hero') return .17;
        if (edge.bridgeTier === 'major') return .125;
        return .09;
      }
      if (overkillArcStyle) {
        if (edge.arcPass === 'background') return v3DiagnosticMode === 'white' ? .12 : null;
        const focusStroke = edge.isFocused ? .20 : (edge.isRelated ? .14 : .085);
        return edge.arcPass === 'bridge'
          ? Math.min(.35, Math.max(.22, focusStroke * 2.4))
          : Math.max(.12, focusStroke * 1.5);
      }
      if (adaptiveArcStyle) return edge.isFocused ? .09 : (edge.isRelated ? .075 : .045);
      if (edge.isFocused) return v3SmallArcStyle ? .09 : .24;
      if (edge.isRelated) return v3SmallArcStyle ? .075 : .18;
      return v3SmallArcStyle ? .045 : (largeArcStyle ? .12 : .14);
    });
    // V5 context arcs are intentionally continuous: no dash pattern and no
    // travelling light animation, so the selected context remains stable.
    globe.arcDashLength((edge) => (isSurfaceSelectionArc(edge) ? 1 : (edge.v4FocusArc ? .32 : (nativeBridgeMode ? .9 : 1))));
    globe.arcDashGap((edge) => (isSurfaceSelectionArc(edge) ? 0 : (edge.v4FocusArc ? .68 : (nativeBridgeMode ? .1 : 0))));
    globe.arcDashAnimateTime((edge) => (isSurfaceSelectionArc(edge)
      ? 0
      : (edge.v4FocusArc
        ? 900
      : (nativeBridgeMode
        ? (edge.bridgeTier === 'hero' ? 1500 : (edge.bridgeTier === 'major' ? 2200 : 3000))
        : 0))));
    globe.pathPoints((edge) => edge.surfacePoints);
    globe.pathPointLat((point) => point.lat);
    globe.pathPointLng((point) => point.lng);
    globe.pathPointAlt((point) => point.altitude);
    globe.pathColor((edge) => (isSurfaceSelectionArc(edge) ? DJINN_ORB_V5.focus : '#000000'));
    globe.pathStroke((edge) => (isSurfaceSelectionArc(edge) ? surfaceSelectionArcProfile(edge).stroke : 0));
    globe.pathResolution(isV5Variant() ? SURFACE_SELECTION_ARC_PROFILE.pathResolution : 1);
    globe.pathDashLength((edge) => (isSurfaceSelectionArc(edge) ? 1 : 0));
    globe.pathDashGap((edge) => (isSurfaceSelectionArc(edge) ? 0 : 1));
    globe.pathDashAnimateTime(() => 0);
    globe.pathTransitionDuration(0);
  }

  function applyOrbVariant() {
    const variantProfile = variantProfileState.get(orbVariant) || VARIANT_PROFILES.v1;
    layer.dataset.variant = orbVariant;
    layer.querySelectorAll('[data-galaxy-variant]').forEach((button) => {
      const active = button.dataset.galaxyVariant === orbVariant;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', String(active));
    });
    if (isV5Variant() && v3LayoutMode !== variantProfile.layout) {
      v3LayoutMode = variantProfile.layout;
      if (v3LayoutSelect) v3LayoutSelect.value = v3LayoutMode;
    }
    v3Tuning?.setAttribute('aria-hidden', String(!isV3Family() || isV5Variant()));
    v3Tuning?.classList.toggle('is-visible', isV3Family() && !isV5Variant());
    v5SizeTuning?.setAttribute('aria-hidden', String(!isV5Variant() || isV6Variant() || isV7Variant()));
    v5SizeTuning?.classList.toggle('is-visible', isV5Variant() && !isV6Variant() && !isV7Variant());
    v6LightTuning?.setAttribute('aria-hidden', String(!isV6Variant()));
    v6LightTuning?.classList.toggle('is-visible', isV6Variant());
    if (v6LightModeSelect && isV6Variant()) v6LightModeSelect.value = lightRigMode;
    if (v6CosmicModeSelect && isV6Variant()) v6CosmicModeSelect.value = v6CosmicMode;
    if (v6ReducedCosmicToggle && isV6Variant()) v6ReducedCosmicToggle.checked = v6ReducedCosmicEffects;
    v7LightTuning?.setAttribute('aria-hidden', String(!isV7Variant()));
    v7LightTuning?.classList.toggle('is-visible', isV7Variant());
    if (v7LightModeSelect && isV7Variant()) v7LightModeSelect.value = v7LightMode;
    if (v7LightBlendInput && isV7Variant()) v7LightBlendInput.value = String(v7LightRig?.cinematicBlend ?? V7_PRODUCTION_CINEMATIC_BLEND);
    if (v7CosmicModeSelect && isV7Variant()) v7CosmicModeSelect.value = v7CosmicMode;
    if (v7ReducedCosmicToggle && isV7Variant()) v7ReducedCosmicToggle.checked = v7ReducedCosmicEffects;
    syncPlanetSignalDebugVisibility();
    if (!globe) return;
    // V5/V6/V7 use their own raycaster and gesture state. Globe.gl pointer
    // interaction must not consume the second tap before dehighlight runs.
    globePointerInteractionEnabled = !isV5Variant();
    globe.enablePointerInteraction?.(globePointerInteractionEnabled);
    recordGlobeControlsDiagnostic('u4.pointer-interaction.profile', {
      enabled: globePointerInteractionEnabled,
      reason: 'orb-variant',
    });
    // The planet is part of every explicit view profile.  Only its nodes and
    // edge layers change; a mode switch must never hide or fade the Globe.gl
    // surface itself.
    globe.showGlobe?.(true);
    const globeMaterial = globe.globeMaterial?.();
    if (globeMaterial) {
      globeMaterial.visible = true;
      globeMaterial.transparent = false;
      globeMaterial.opacity = 1;
      globeMaterial.depthWrite = true;
    }
    if (isV3Family()) ensureV3Layout();
    if (isV5Variant()) refreshV5SizeProfile();
    commitActiveGlobeData();
    const overkillMode = (orbVariant === 'v3' && v3LayoutMode === 'community-overkill') || isV5Variant();
    const profileBackgroundColor = isV5Variant()
      ? DJINN_ORB_V5.space
      : (isV4Family()
        ? DJINN_ORB_V4.space
      : (orbVariant === 'v3'
        ? (overkillMode ? DJINN_ORB_V3.overkillSpace : DJINN_ORB_V3.space)
        : (orbVariant === 'v2' ? DJINN_ORB_V2.space : '#0B0A17')));
    globe.backgroundColor(embeddedViewport && embeddedBackgroundColor
      ? embeddedBackgroundColor
      : profileBackgroundColor);
    globe.globeMaterial?.().color?.set(isV5Variant()
      ? DJINN_ORB_V5.planet
      : (isV4Family()
        ? DJINN_ORB_V4.planet
      : (orbVariant === 'v3'
        ? (overkillMode ? DJINN_ORB_V3.overkillPlanet : DJINN_ORB_V3.planet)
        : (orbVariant === 'v2' ? DJINN_ORB_V2.planet : '#2B1366'))));
    if (ambientLight && keyLight) {
      ambientLight.color.set(isV5Variant() ? '#255D82' : (isV4Family() ? '#255D82' : (orbVariant === 'v3' ? '#254D86' : (orbVariant === 'v2' ? '#1F6F96' : '#4B286F'))));
      ambientLight.intensity = isV5Variant() ? 1.02 : (isV4Family() ? 1.02 : (orbVariant === 'v3' ? .9 : (orbVariant === 'v2' ? .82 : .72)));
      keyLight.color.set(isV5Variant() ? '#FFF0D1' : (isV4Family() ? '#FFF0D1' : (orbVariant === 'v3' ? '#D9FBFF' : (orbVariant === 'v2' ? '#E7FCFF' : '#F0EAFF'))));
      keyLight.intensity = isV5Variant() ? 2.8 : (isV4Family() ? 2.8 : (orbVariant === 'v3' ? 2.5 : (orbVariant === 'v2' ? 2.8 : 2.6)));
    }
    applyVariantLightRig();
    if (overkillMode) v3Lod = 'overkill';
    applyArcProfile();
    refreshNodeVisuals();
    if (overkillMode) updateOverkillFacingDiagnostics();
    syncDjinnEdgeLayer();
    refreshEdges();
  }

  function worldPosition(node) {
    const object = nodeObjects.get(node?.id);
    if (object?.getWorldPosition) return object.getWorldPosition(new THREE.Vector3());
    const coords = globe.getCoords(node.lat, node.lng, .012);
    return new THREE.Vector3(coords.x, coords.y, coords.z);
  }

  function scheduleV3Visibility() {
    if (!isV3Family() || !globe || v3VisibilityFrame) return;
    v3VisibilityFrame = requestAnimationFrame(() => {
      v3VisibilityFrame = 0;
      const cameraDirection = globe.camera().position.clone()
        .sub(globe.controls().target).normalize();
      const cameraDistance = globe.camera().position.distanceTo(globe.controls().target)
        / Math.max(globe.getGlobeRadius?.() || 100, 1);
      const overkillActive = orbVariant === 'v3' && v3LayoutMode === 'community-overkill';
      const nextLod = isV5Variant()
        ? (cameraDistance > 2.55 ? 'far' : (cameraDistance < 1.68 ? 'near' : 'medium'))
        : (overkillActive ? 'overkill' : (cameraDistance > 2.55 ? 'far' : (cameraDistance < 1.68 ? 'focused' : 'medium')));
      if (nextLod !== v3Lod) {
        v3Lod = nextLod;
        refreshEdges();
        updateOverkillFacingDiagnostics();
      }
      if (isV5Variant()) {
        // Camera motion only changes hemisphere opacity and halo falloff.
        // Keep the 700-node data/material rebuild for selection or variant
        // transitions; doing it on every orbit event makes mobile dragging
        // allocate and resolve the entire graph repeatedly.
        refreshV5CameraVisuals();
        return;
      }
      renderV3Stats();
      djinnEdgeLayer?.updateCamera(globe.camera());
      const related = focusedNode ? connectedTo(focusedNode.id) : null;
      nodeObjects.forEach((object, nodeId) => {
        const node = resolveActiveNode(nodeId);
        if (!node) return;
        const facing = worldPosition(node).normalize().dot(cameraDirection);
        const v5Profile = isV5Variant() ? v5NodeHemisphereProfile(facing) : null;
        const data = object.userData;
        const isFocused = focusedNode?.id === nodeId;
        const isRelated = related?.has(nodeId);
        data.sphere.material.opacity = (data.baseOpacity ?? 1)
          * (isV5Variant() ? v5Profile.opacity : clamp((facing + .12) / .3, 0, 1));
        if (isV3Family()) {
          const lodScale = v3Lod === 'far' ? .78 : (v3Lod === 'focused' ? 1.05 : 1);
          data.sphere.scale.setScalar(data.baseRadius * lodScale * (focusedNode?.id === nodeId ? 1.12 : 1) * (v5Profile?.scale || 1));
        }
        if (v5Profile && data.glow) {
          data.glow.material.opacity = clamp(v5Profile.glowOpacity
            * (isFocused ? 2.8 : (isRelated ? 1.5 : .25)), 0, .48);
          data.glow.scale.setScalar(data.baseRadius
            * (isFocused ? 1.75 : 1.5)
            * v5Profile.glowScale);
        }
        object.visible = (isV5Variant() || facing > -.12)
          && (focusState !== 'morphing-to-card' || focusedNode?.id !== nodeId);
      });
      refreshV5Labels();
    });
  }

  function animateCameraToNode(node, duration, altitude, done) {
    const controls = globe.controls?.();
    const camera = globe.camera?.();
    if (!controls || !camera) return done?.();
    const startTarget = controls.target.clone();
    const startPosition = camera.position.clone();
    const targetCoords = worldPosition(node);
    const targetTarget = targetCoords.clone();
    const viewDirection = camera.position.clone().sub(controls.target).normalize();
    const distance = globe.getGlobeRadius?.() * altitude || 190;
    const targetPosition = targetCoords.clone().add(viewDirection.multiplyScalar(distance));
    const start = performance.now();
    cancelAnimationFrame(focusTimer);
    const tick = (now) => {
      const t = clamp((now - start) / duration, 0, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      controls.target.lerpVectors(startTarget, targetTarget, eased);
      camera.position.lerpVectors(startPosition, targetPosition, eased);
      camera.lookAt(controls.target);
      controls.update?.();
      if (t < 1 && !destroyed) focusTimer = requestAnimationFrame(tick);
      else {
        controls.target.copy(targetTarget);
        camera.position.copy(targetPosition);
        camera.lookAt(targetTarget);
        controls.update?.();
        done?.();
      }
    };
    focusTimer = requestAnimationFrame(tick);
  }

  function projectedNodeRect(node) {
    const camera = globe.camera();
    const rect = canvas.getBoundingClientRect();
    const projected = worldPosition(node).project(camera);
    const x = (projected.x * .5 + .5) * rect.width;
    const y = (-projected.y * .5 + .5) * rect.height;
    const radiusBase = isV3Family()
      ? v3NodeRadius(V3_DEGREE_BY_ID.get(node.id) || 0)
      : nodeRadius(degreeById.get(node.id) || 0);
    const radius = clamp(48 + (radiusBase * 4), 58, 104);
    return { left: x - radius / 2, top: y - radius / 2, width: radius, height: radius };
  }

  function fillCard(node) {
    morphOverlay.querySelector('[data-node-type]').textContent = node.type || 'fogalom';
    morphOverlay.querySelector('[data-node-degree]').textContent = `${degreeById.get(node.id) || 0} kapcsolat`;
    morphOverlay.querySelector('[data-node-title]').textContent = node.title;
    morphOverlay.querySelector('[data-node-subtitle]').textContent = node.subtitle || 'Kapcsolódó tudáselem a Djinn gráfjában.';
    morphOverlay.querySelector('[data-node-source]').textContent = node.sourceName || 'Djinn tudásgráf';
  }

  function v5PointerRuntimeFor(variant = orbVariant) {
    return v5VariantPointerRuntime.get(variant) || null;
  }

  function clearV5PointerGestures(variant = null) {
    v5LabelGestures.clear();
    if (variant) {
      v5PointerRouter.clear(variant);
      return;
    }
    v5VariantPointerRuntime.forEach((_, key) => v5PointerRouter.clear(key));
  }

  function pickV5NodeFromPointer(event) {
    if (!isV5Variant() || !globe || state !== 'expanded') {
      recordPlanetSignal('pointer.pick.skip', { reason: !globe ? 'no-globe' : `state:${state}` });
      return null;
    }
    const runtime = v5PointerRuntimeFor();
    if (!runtime) {
      recordPlanetSignal('pointer.pick.skip', { reason: 'no-runtime' });
      return null;
    }
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) {
      recordPlanetSignal('pointer.pick.skip', { reason: 'empty-canvas' });
      return null;
    }
    runtime.ndc.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -(((event.clientY - rect.top) / rect.height) * 2 - 1),
    );
    const camera = globe.camera();
    globe.scene().updateMatrixWorld?.(true);
    camera.updateMatrixWorld?.(true);
    runtime.raycaster.setFromCamera(runtime.ndc, camera);
    const cameraDirection = camera.position.clone().sub(globe.controls().target).normalize();

    const selectedHitSphere = focusedNode
      ? nodeObjects.get(focusedNode.id)?.userData?.hitSphere
      : null;
    const selectedIsFrontFacing = focusedNode
      ? worldPosition(focusedNode).normalize().dot(cameraDirection) > -.06
      : false;
    // The current gold city gets first refusal. This makes the documented
    // repeat-tap dehighlight deterministic even in a dense 700-city field,
    // but never lets a hidden back-side hit sphere win through the globe.
    if (selectedHitSphere && selectedIsFrontFacing && runtime.raycaster.intersectObject(selectedHitSphere, false).length) {
      recordPlanetSignal('pointer.pick.selected', { cityId: focusedNode.id });
      return focusedNode.id;
    }

    const hitTargets = [...nodeObjects.values()]
      .map((object) => object.userData?.hitSphere)
      .filter(Boolean);
    const expectedTargetCount = activePoints().length;
    if (hitTargets.length < expectedTargetCount) {
      recordPlanetSignal('pointer.pick.not-ready', {
        targetCount: hitTargets.length,
        expectedTargetCount,
        selectedCityId: focusedNode?.id || null,
      });
      return undefined;
    }
    const hit = runtime.raycaster.intersectObjects(hitTargets, false).find((intersection) => {
      const node = resolveActiveNode(intersection.object.userData?.nodeId);
      return node && worldPosition(node).normalize().dot(cameraDirection) > -.06;
    });
    const cityId = hit?.object?.userData?.nodeId || null;
    recordPlanetSignal(cityId ? 'pointer.pick.hit' : 'pointer.pick.miss', {
      cityId,
      targetCount: hitTargets.length,
    });
    return cityId;
  }

  function isPlanetPointerEvent(event) {
    const target = event.target;
    if (!target?.closest) return true;
    return !target.closest([
      '.galaxy-orb-controls',
      '.galaxy-orb-v3-tuning',
      '.galaxy-orb-v5-size-debug',
      '.galaxy-orb-v6-light-debug',
      '.galaxy-orb-v7-light-debug',
      '.planet-signal-debug-panel',
      '.galaxy-node-morph-overlay.is-visible',
      '.galaxy-orb-background-swipe',
    ].join(','));
  }

  function beginV5LabelTap(event) {
    if (!isV5Variant() || state !== 'expanded' || (event.button != null && event.button !== 0)) return false;
    const label = event.target?.closest?.('.galaxy-orb-label[data-node-id]');
    const cityId = label?.dataset?.nodeId || null;
    if (!cityId || !resolveActiveNode(cityId)) return false;
    const runtime = v5PointerRuntimeFor();
    const gesture = {
      cityId,
      startX: event.clientX,
      startY: event.clientY,
      startedAt: performance.now(),
      moved: false,
      multiPointer: Boolean(runtime?.gestures?.size || v5LabelGestures.size),
    };
    runtime?.gestures?.forEach((activeGesture) => { activeGesture.multiPointer = true; });
    v5LabelGestures.forEach((activeGesture) => { activeGesture.multiPointer = true; });
    v5LabelGestures.set(event.pointerId, gesture);
    label.setPointerCapture?.(event.pointerId);
    recordPlanetSignal('pointer.label.down', {
      pointerId: event.pointerId,
      cityId,
      target: describeDomTarget(event.target),
      defaultPrevented: event.defaultPrevented === true,
    });
    event.preventDefault?.();
    event.stopPropagation?.();
    return true;
  }

  function moveV5LabelTap(event) {
    const gesture = v5LabelGestures.get(event.pointerId);
    if (!gesture) return false;
    const dx = event.clientX - gesture.startX;
    const dy = event.clientY - gesture.startY;
    const distanceSquared = (dx * dx) + (dy * dy);
    const tapDistanceSquared = embeddedViewport ? 576 : 81;
    if (distanceSquared > tapDistanceSquared && !gesture.moved) {
      gesture.moved = true;
      recordPlanetSignal('pointer.label.drag', {
        pointerId: event.pointerId,
        cityId: gesture.cityId,
        distanceSquared,
        target: describeDomTarget(event.target),
        defaultPrevented: event.defaultPrevented === true,
      });
    }
    event.preventDefault?.();
    event.stopPropagation?.();
    return true;
  }

  function completeV5LabelTap(event) {
    const gesture = v5LabelGestures.get(event.pointerId);
    if (!gesture) return false;
    v5LabelGestures.delete(event.pointerId);
    const label = event.target?.closest?.('.galaxy-orb-label[data-node-id]');
    if (label?.hasPointerCapture?.(event.pointerId)) label.releasePointerCapture?.(event.pointerId);
    const duration = performance.now() - gesture.startedAt;
    const tapDurationMs = embeddedViewport ? 620 : 360;
    if (gesture.moved || gesture.multiPointer || duration > tapDurationMs) {
      recordPlanetSignal('pointer.label.reject', {
        pointerId: event.pointerId,
        cityId: gesture.cityId,
        moved: gesture.moved,
        hadMultiplePointers: gesture.multiPointer,
        duration: Math.round(duration),
        target: describeDomTarget(event.target),
        defaultPrevented: event.defaultPrevented === true,
      });
    } else {
      recordPlanetSignal('pointer.label.tap', {
        pointerId: event.pointerId,
        cityId: gesture.cityId,
        duration: Math.round(duration),
        target: describeDomTarget(event.target),
        defaultPrevented: event.defaultPrevented === true,
      });
      focusNode(gesture.cityId);
    }
    event.preventDefault?.();
    event.stopPropagation?.();
    return true;
  }

  function cancelV5LabelTap(event) {
    const gesture = v5LabelGestures.get(event.pointerId);
    if (!gesture) return false;
    v5LabelGestures.delete(event.pointerId);
    recordPlanetSignal('pointer.label.cancel', { pointerId: event.pointerId, cityId: gesture.cityId });
    event.preventDefault?.();
    event.stopPropagation?.();
    return true;
  }

  function onPlanetPointerDown(event) {
    if (beginV5LabelTap(event)) return;
    if (!isPlanetPointerEvent(event)) return;
    v5PointerRouter.onPointerDown(event);
  }

  function onPlanetPointerMove(event) {
    if (moveV5LabelTap(event)) return;
    if (!isPlanetPointerEvent(event)) return;
    v5PointerRouter.onPointerMove(event);
  }

  function onPlanetPointerUp(event) {
    if (completeV5LabelTap(event)) return;
    if (!isPlanetPointerEvent(event)) return;
    v5PointerRouter.onPointerUp(event);
  }

  function onPlanetPointerCancel(event) {
    if (cancelV5LabelTap(event)) return;
    if (!isPlanetPointerEvent(event)) return;
    v5PointerRouter.onPointerCancel(event);
  }

  function morphToCard(node) {
    focusState = 'morphing-to-card';
    refreshNodeVisuals();
    const startRect = projectedNodeRect(node);
    const panelWidth = morph.clientWidth;
    const panelHeight = morph.clientHeight;
    const endWidth = Math.max(240, panelWidth - 32);
    const endHeight = Math.min(250, Math.max(180, panelHeight * .62));
    morphOverlay.style.left = `${startRect.left}px`;
    morphOverlay.style.top = `${startRect.top}px`;
    morphOverlay.style.width = `${startRect.width}px`;
    morphOverlay.style.height = `${startRect.height}px`;
    morphOverlay.style.borderRadius = '50%';
    morphOverlay.style.opacity = '0';
    morphOverlay.classList.add('is-visible');
    fillCard(node);
    requestAnimationFrame(() => {
      morphOverlay.style.left = `${(panelWidth - endWidth) / 2}px`;
      morphOverlay.style.top = `${Math.max(42, (panelHeight - endHeight) * .56)}px`;
      morphOverlay.style.width = `${endWidth}px`;
      morphOverlay.style.height = `${endHeight}px`;
      morphOverlay.style.borderRadius = '22px';
      morphOverlay.style.opacity = '1';
      cardContent.classList.add('is-readable');
    });
    window.setTimeout(() => {
      focusState = 'card-open';
      morphOverlay.setAttribute('aria-hidden', 'false');
      cardClose.focus?.();
    }, 420);
  }

  function focusNode(nodeId) {
    if (focusState !== 'idle' || state !== 'expanded') {
      recordPlanetSignal('focus.skip', { cityId: nodeId, reason: `focus:${focusState}; state:${state}` });
      return;
    }
    if (!globe) {
      recordPlanetSignal('focus.waiting-globe', { cityId: nodeId });
      if (!destroyed) window.setTimeout(() => focusNode(nodeId), 80);
      return;
    }
    const node = resolveActiveNode(nodeId);
    if (!node) {
      recordPlanetSignal('focus.skip', { cityId: nodeId, reason: 'unknown-city' });
      return;
    }
    const controls = globe.controls();
    if (isV5Variant() && V5_FOCUS_NO_ZOOM) {
      const previousSelection = activeV5CitySelection();
      let handoff = null;
      if (typeof onV5CityTap === 'function') {
        try {
          handoff = onV5CityTap({
            variant: orbVariant,
            cityId: node.id,
            city: node,
            selection: previousSelection,
            pointOfView: globe.pointOfView?.() || null,
            cityAnchor: projectedNodeRect(node),
          });
        } catch (error) {
          recordPlanetSignal('u4.tap.seam.error', {
            cityId: node.id,
            message: error instanceof Error ? error.message : String(error),
          });
        }
      }
      if (handoff?.handled) {
        if (handoff.action === 'clear-context') {
          const transition = clearCitySelection(handoff.reason || 'universe4-context-clear');
          focusedNode = null;
          focusedCameraState = null;
          focusState = 'idle';
          v4FocusedNeighborId = null;
          recordPlanetSignal('focus.transition', {
            cityId: node.id,
            action: transition.action,
            selectedCityId: null,
            selectedArcCount: 0,
            reason: handoff.reason || 'universe4-context-clear',
          });
          refreshNodeVisuals();
          refreshEdges();
          renderV3Stats();
          notifyV5SelectionTransition({
            source: 'city',
            cityId: node.id,
            previousSelection,
            selection: transition.selection,
            action: transition.action,
            reason: handoff.reason || 'universe4-context-clear',
          });
        } else {
          recordPlanetSignal('u4.tap.claimed', {
            cityId: node.id,
            action: handoff.action || 'claimed',
            selectedCityId: previousSelection.selectedCityId || null,
          });
        }
        return;
      }
      const transition = applyCitySelection(node.id);
      const selection = transition.selection;
      focusedNode = selection.selectedCityId ? resolveActiveNode(selection.selectedCityId) : null;
      recordPlanetSignal('focus.transition', {
        cityId: node.id,
        action: transition.action,
        selectedCityId: selection.selectedCityId,
        selectedArcCount: selection.selectedCityArcData.length,
      });
      if (selection.selectedCityId && transition.action !== 'dehighlight') {
        focusV5CityCamera(focusedNode, transition.action);
      }
      focusedCameraState = null;
      controls.enableRotate = true;
      controls.enableZoom = true;
      controls.autoRotate = false;
      focusState = 'idle';
      v4FocusedNeighborId = null;
      refreshNodeVisuals();
      refreshEdges();
      renderV3Stats();
      notifyV5SelectionTransition({
        source: 'city',
        cityId: node.id,
        previousSelection,
        selection,
        action: transition.action,
      });
      return;
    }
    focusedNode = node;
    v4FocusedNeighborId = null;
    focusState = 'node-selected';
    focusedCameraState = {
      cameraPosition: globe.camera().position.clone(),
      controlsTarget: globe.controls().target.clone()
    };
    controls.enableRotate = false;
    controls.enableZoom = false;
    controls.autoRotate = false;
    if (isV4Family()) v4FocusArc();
    refreshNodeVisuals();
    refreshEdges();
    focusState = 'orienting';
    animateCameraToNode(node, 380, 1.7, () => {
      focusState = 'zooming';
      animateCameraToNode(node, 320, 1.32, () => morphToCard(node));
    });
  }

  function focusConcept(nodeId, sourceElement) {
    if (!resolveActiveNode(nodeId) || focusState !== 'idle') return;
    sourceElement?.classList.add('is-focus-requested');
    focusNode(nodeId);
    window.setTimeout(() => sourceElement?.classList.remove('is-focus-requested'), 220);
  }

  function closeNodeCard() {
    if (!focusedNode || (focusState !== 'card-open' && focusState !== 'morphing-to-card')) return;
    focusState = 'morphing-to-node';
    cardContent.classList.remove('is-readable');
    morphOverlay.style.left = `${projectedNodeRect(focusedNode).left}px`;
    morphOverlay.style.top = `${projectedNodeRect(focusedNode).top}px`;
    morphOverlay.style.width = `${projectedNodeRect(focusedNode).width}px`;
    morphOverlay.style.height = `${projectedNodeRect(focusedNode).height}px`;
    morphOverlay.style.borderRadius = '50%';
    morphOverlay.style.opacity = '0';
    window.setTimeout(() => {
      morphOverlay.classList.remove('is-visible');
      morphOverlay.setAttribute('aria-hidden', 'true');
      const controls = globe.controls();
      controls.target.copy(focusedCameraState.controlsTarget);
      globe.camera().position.copy(focusedCameraState.cameraPosition);
      controls.enableRotate = true;
      controls.enableZoom = true;
      controls.update?.();
      focusedNode = null;
      v4FocusedNeighborId = null;
      focusState = 'idle';
      refreshNodeVisuals();
      refreshEdges();
      scheduleV3Visibility();
    }, 380);
  }

  function applyGlobeProfile(expanded) {
    if (!globe) return;
    applyGlobeControlsProfile(expanded);
    applyArcProfile();
    refreshNodeVisuals();
  }

  function applyGlobeControlsProfile(expanded) {
    const controls = globe?.controls?.();
    if (!controls) return;
    const enabled = v5GlobeControlsEnabled({
      expanded,
      variant: orbVariant,
      focusState,
    });
    controls.enableRotate = enabled;
    controls.enableZoom = enabled;
    controls.enablePan = false;
    controls.autoRotate = false;
    controls.autoRotateSpeed = .28;
    recordGlobeControlsDiagnostic('u4.controls.profile', {
      expanded: Boolean(expanded),
      policyEnabled: enabled,
      reason: 'profile-apply',
    });
  }

  function createGlobe(attempt = 0) {
    if (destroyed || globe) return;
    const Globe = window.Globe;
    if (!Globe) {
      if (attempt < 60) window.setTimeout(() => createGlobe(attempt + 1), 50);
      else recordEmbeddedRenderDiagnostic('u4.globe.error', { phase: 'vendor-load', message: 'window.Globe missing after retry budget' });
      return;
    }
    try {
      globe = new Globe(canvas, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: false })
        .backgroundColor('#0B0A17')
        .showAtmosphere(false)
        .showGraticules(false)
        .objectsData(ORB_POINTS)
        .objectLat((point) => point.lat)
        .objectLng((point) => point.lng)
        .objectAltitude(.012)
        .objectThreeObject((point) => createNodeObject(point))
        .onObjectClick((point) => {
          // V5/V6/V7 own their pointer routing below. Globe.gl remains the
          // click owner for V1–V4 only, so a native callback cannot race the
          // explicit repeat-tap dehighlight transaction.
          if (!isV5Variant()) focusNode(point.id);
        })
        .arcsData(ORB_ARCS)
        .pathsData([])
        .arcStartLat((arc) => arc.startLat)
        .arcStartLng((arc) => arc.startLng)
        .arcStartAltitude((arc) => selectedSurfaceArcEndpointAltitude(arc, 'start'))
        .arcEndLat((arc) => arc.endLat)
        .arcEndLng((arc) => arc.endLng)
        .arcEndAltitude((arc) => selectedSurfaceArcEndpointAltitude(arc, 'end'))
        .arcColor(arcColorFor)
        .arcAltitude((edge) => edge.isFocused ? .32 : (edge.isRelated ? .26 : .19))
        .arcStroke((edge) => edge.isFocused ? .24 : (edge.isRelated ? .18 : .14))
        .arcDashLength(1)
        .arcDashGap(0)
        .pathPoints((edge) => edge.surfacePoints)
        .pathPointLat((point) => point.lat)
        .pathPointLng((point) => point.lng)
        .pathPointAlt((point) => point.altitude)
        .pathColor((edge) => (isSurfaceSelectionArc(edge) ? DJINN_ORB_V5.focus : '#000000'))
        .pathStroke((edge) => (isSurfaceSelectionArc(edge) ? surfaceSelectionArcProfile(edge).stroke : 0))
        .pathResolution(SURFACE_SELECTION_ARC_PROFILE.pathResolution)
        .pathDashLength(1)
        .pathDashGap(0)
        .pathDashAnimateTime(0)
        .pathTransitionDuration(0)
        .arcsTransitionDuration(0);
      globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 0);
      ambientLight = new THREE.AmbientLight(0x4b286f, .72);
      keyLight = new THREE.DirectionalLight(0xf0eaff, 2.6);
      fillLight = new THREE.HemisphereLight(0x4d3a86, 0x080b25, .42);
      rimLight = new THREE.DirectionalLight(0x75f1fa, .18);
      lightTarget = new THREE.Object3D();
      lightTarget.name = 'virtual-galaxy-light-target';
      globe.scene().add(lightTarget);
      keyLight.target = lightTarget;
      rimLight.target = lightTarget;
      globe.lights([ambientLight, keyLight, fillLight, rimLight]);
      createLightDirectionProof();
      lightRigListener = () => {
        if (isV6Variant()) scheduleVirtualGalaxyLightRig();
        else if (!isV7Variant()) updateLegacyGlobeLight();
      };
      globe.controls().addEventListener('change', lightRigListener);
      v3VisibilityListener = scheduleV3Visibility;
      globe.controls().addEventListener('change', v3VisibilityListener);
      v5LabelProjectionListener = scheduleV5LabelProjection;
      globe.controls().addEventListener('change', v5LabelProjectionListener);
      updateLegacyGlobeLight();
      applyGlobeProfile(true);
      applyOrbVariant();
      syncEmbeddedViewportSize();
      recordEmbeddedRenderDiagnostic('u4.globe.ready');
      recordGlobeControlsDiagnostic('u4.controls.ready', { reason: 'globe-ready' });
      // This callback is intentionally emitted only after `applyOrbVariant`:
      // consumers such as Universe 4 receive the exact selected V7 city,
      // material, lighting, cosmic and input controller—not an unstyled Globe
      // shell during its setup frame.
      onGlobeReady?.({ globe, layer, canvas, variant: orbVariant });
      resizeObserver = new ResizeObserver(() => {
        const rect = canvas.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) globe.width(rect.width).height(rect.height);
        v6CosmicEnvironment?.resize();
        v7LightRig?.resize();
        v7CosmicEnvironment?.resize();
      });
      resizeObserver.observe(canvas);
      refreshEdges();
    } catch (error) {
      canvas.innerHTML = '<span class="galaxy-orb-fallback">✦</span>';
      canvas.setAttribute('data-error', error.message);
      recordEmbeddedRenderDiagnostic('u4.globe.error', {
        phase: 'create',
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  function setRoute(route) {
    const visible = route === 'explore';
    layer.classList.toggle('is-route-visible', visible);
    if (visible) {
      measureBounds();
      createGlobe();
      if (isV6Variant()) {
        v6CosmicEnvironment?.resume();
        scheduleVirtualGalaxyLightRig();
      }
      if (isV7Variant()) {
        v7LightRig?.resume();
        v7CosmicEnvironment?.resume();
      }
    } else {
      v6CosmicEnvironment?.suspend();
      v7LightRig?.suspend();
      v7CosmicEnvironment?.suspend();
    }
  }

  function onClick(event) {
    const variantButton = event.target.closest('[data-galaxy-variant]');
    if (variantButton) {
      const requestedVariant = variantButton.dataset.galaxyVariant;
      switchOrbVariant(requestedVariant);
      return;
    }
    const action = event.target.closest('[data-galaxy-action]')?.dataset.galaxyAction;
    if (action === 'fullscreen') {
      void setGalaxyFullscreen(!galaxyFullscreen);
      return;
    }
    if (action === 'reset' && globe) globe.pointOfView({ lat: 12, lng: 28, altitude: 2.15 }, 500);
  }

  function onFullscreenChange() {
    syncFullscreenState();
  }

  function onCardClose(event) {
    event.preventDefault();
    closeNodeCard();
  }

  function onV3LayoutChange(event) {
    const nextMode = event.target.closest('[data-v3-layout]')?.value;
    if (!nextMode || !['uniform', 'spherical-force', 'community-caps', 'community-arc', 'community-adaptive', 'community-overkill'].includes(nextMode)) return;
    v3LayoutMode = nextMode;
    rememberVariantProfile();
    if (isV3Family()) {
      ensureV3Layout(true);
      applyOrbVariant();
      scheduleV3Visibility();
    }
  }

  function onV3DiagnosticChange(event) {
    const nextMode = event.target.closest('[data-v3-edge-diagnostic]')?.value;
    if (!nextMode || !['all', 'background', 'structure', 'bridge', 'white', 'endpoint', 'radius', 'facing'].includes(nextMode)) return;
    v3DiagnosticMode = nextMode;
    rememberVariantProfile();
    if (isV3Family() && isDjinnEdgeMode()) {
      djinnEdgeLayer?.setDiagnostics(v3DiagnosticMode);
      commitActiveGlobeData(false);
      applyArcProfile();
      renderV3Stats();
      scheduleV3Visibility();
    }
  }

  function onV3EdgeToggleChange(event) {
    const edgeEnabled = event.target.closest('[data-v3-edge-enabled]');
    const backEnabled = event.target.closest('[data-v3-edge-back]');
    if (edgeEnabled) {
      v3EdgeLayerEnabled = edgeEnabled.checked;
      djinnEdgeLayer?.setVisible(v3EdgeLayerEnabled);
    }
    if (backEnabled) {
      v3EdgeBackEnabled = backEnabled.checked;
      djinnEdgeLayer?.setDebugOptions({ showBack: v3EdgeBackEnabled });
    }
    rememberVariantProfile();
    renderV3Stats();
  }

  function onV4EdgeToggleChange(event) {
    if (!isV4Family()) return;
    const localToggle = event.target.closest('[data-v4-local-edges]');
    const remoteToggle = event.target.closest('[data-v4-remote-edges]');
    if (localToggle) v4LocalEdgesEnabled = localToggle.checked;
    if (remoteToggle) v4RemoteEdgesEnabled = remoteToggle.checked;
    rememberVariantProfile();
    djinnEdgeLayer?.setEdgeVisibility({
      local: v4LocalEdgesEnabled,
      remote: v4RemoteEdgesEnabled,
    });
    refreshEdges();
    renderV3Stats();
  }

  function onV3BridgeRendererChange(event) {
    const nextRenderer = event.target.closest('[data-v3-bridge-renderer]')?.value;
    if (!nextRenderer || !['native-auto', 'native-weighted', 'custom'].includes(nextRenderer)) return;
    v3BridgeRenderer = nextRenderer;
    rememberVariantProfile();
    if (isV3Family() && isDjinnEdgeMode()) {
      syncDjinnEdgeLayer();
      applyArcProfile();
      refreshEdges();
      renderV3Stats();
    }
  }

  function syncV5SizeSettings() {
    v5SizeSettings.metric = v5SizeMetricSelect?.value || V5_SIZE_DEFAULTS.metric;
    v5SizeSettings.curve = v5SizeCurveSelect?.value || V5_SIZE_DEFAULTS.curve;
    v5SizeSettings.minRadius = Number(v5SizeMinInput?.value || V5_SIZE_DEFAULTS.minRadius);
    v5SizeSettings.maxRadius = Number(v5SizeMaxInput?.value || V5_SIZE_DEFAULTS.maxRadius);
    v5SizeSettings.hubMultiplier = Number(v5HubMultiplierInput?.value || V5_SIZE_DEFAULTS.hubMultiplier);
    v5SizeSettings.farLodMin = Number(v5FarLodMinInput?.value || V5_SIZE_DEFAULTS.farLodMin);
    v5SizeSettings.perspective = Number(v5PerspectiveInput?.value || V5_SIZE_DEFAULTS.perspective);
    v5SizeSettings.halo = Number(v5HaloInput?.value || V5_SIZE_DEFAULTS.halo);
    v5SizeSettings.collisionPadding = Number(v5CollisionPaddingInput?.value || V5_SIZE_DEFAULTS.collisionPadding);
    v5SizeRankDebug = Boolean(v5SizeRankDebugToggle?.checked);
    v5ClampDebug = Boolean(v5ClampDebugToggle?.checked);
    refreshV5SizeProfile();
    if (isV5Variant()) {
      refreshNodeVisuals();
      refreshEdges();
      renderV3Stats();
    }
  }

  function onV6LightRigChange(event) {
    if (!isV6Variant()) return;
    const nextMode = event.target.closest('[data-v6-light-mode]')?.value;
    if (nextMode) setV6LightRigMode(nextMode);
    const nextCosmicMode = event.target.closest('[data-v6-cosmic-mode]')?.value;
    if (nextCosmicMode && COSMIC_MODES.includes(nextCosmicMode)) {
      v6CosmicMode = nextCosmicMode;
      v6CosmicEnvironment?.setMode(nextCosmicMode);
      scheduleVirtualGalaxyLightRig();
    }
    const reducedCosmic = event.target.closest('[data-v6-reduced-cosmic]');
    if (reducedCosmic) {
      v6ReducedCosmicEffects = Boolean(reducedCosmic.checked);
      v6CosmicEnvironment?.setReducedEffects(v6ReducedCosmicEffects);
      scheduleVirtualGalaxyLightRig();
    }
  }

  function onV7LightRigChange(event) {
    if (!isV7Variant()) return;
    const nextMode = event.target.closest('[data-v7-light-mode]')?.value;
    if (nextMode) setV7LightRigMode(nextMode);
    const nextBlend = event.target.closest('[data-v7-light-blend]')?.value;
    if (nextBlend != null && v7LightRig) {
      v7LightRig.setCinematicBlend(Number(nextBlend));
      updateV7LightStats(true);
    }
    const nextCosmicMode = event.target.closest('[data-v7-cosmic-mode]')?.value;
    if (nextCosmicMode && COSMIC_MODES.includes(nextCosmicMode)) {
      v7CosmicMode = nextCosmicMode;
      v7CosmicEnvironment?.setMode(nextCosmicMode);
      updateV7LightStats(true);
    }
    const reducedCosmic = event.target.closest('[data-v7-reduced-cosmic]');
    if (reducedCosmic) {
      v7ReducedCosmicEffects = Boolean(reducedCosmic.checked);
      v7CosmicEnvironment?.setReducedEffects(v7ReducedCosmicEffects);
      updateV7LightStats(true);
    }
  }

  function onKeydown(event) {
    if (event.key === 'Escape' && galaxyFullscreen) {
      void setGalaxyFullscreen(false);
      return;
    }
    if (event.key === 'Escape' && focusState === 'card-open') closeNodeCard();
  }

  layer.addEventListener('click', onClick);
  // Listen at the viewport root in capture phase. The canvas remains the
  // pointer-capture owner, but a transparent scene sibling can no longer
  // silently swallow taps before the debug trace sees them.
  morph.addEventListener('pointerdown', onPlanetPointerDown, true);
  morph.addEventListener('pointermove', onPlanetPointerMove, true);
  morph.addEventListener('pointerup', onPlanetPointerUp, true);
  morph.addEventListener('pointercancel', onPlanetPointerCancel, true);
  v3LayoutSelect.addEventListener('change', onV3LayoutChange);
  v3DiagnosticSelect.addEventListener('change', onV3DiagnosticChange);
  v3BridgeRendererSelect.addEventListener('change', onV3BridgeRendererChange);
  v3EdgeEnabledToggle.addEventListener('change', onV3EdgeToggleChange);
  v3EdgeBackToggle.addEventListener('change', onV3EdgeToggleChange);
  v4LocalEdgesToggle.addEventListener('change', onV4EdgeToggleChange);
  v4RemoteEdgesToggle.addEventListener('change', onV4EdgeToggleChange);
  v5SizeTuning.addEventListener('change', syncV5SizeSettings);
  v5SizeTuning.addEventListener('input', syncV5SizeSettings);
  v6LightTuning.addEventListener('change', onV6LightRigChange);
  v7LightTuning.addEventListener('change', onV7LightRigChange);
  v7LightTuning.addEventListener('input', onV7LightRigChange);
  cardClose.addEventListener('click', onCardClose);
  window.addEventListener('keydown', onKeydown);
  document.addEventListener('fullscreenchange', onFullscreenChange);
  window.addEventListener('resize', measureBounds);
  measureBounds();
  // The U4 portal must be usable even if Globe.gl fails before its first
  // renderer callback. Make the canonical V7 panel visible and put an
  // explicit prewarm record in its own trace before construction starts.
  // This is intentionally outside the render loop.
  if (embeddedViewport) {
    syncPlanetSignalDebugVisibility();
    recordEmbeddedRenderDiagnostic('u4.globe.prewarm');
  }
  createGlobe();

  return {
    setRoute,
    setVariant(nextVariant) {
      const normalized = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7'].includes(nextVariant)
        ? nextVariant
        : null;
      if (!normalized) return;
      switchOrbVariant(normalized);
    },
    getGlobe: () => globe,
    getGlobeControlsDiagnostics,
    recordEmbeddedSignal(event, payload = {}) {
      if (embeddedViewport) recordPlanetSignal(event, payload);
    },
    applyEmbeddedHandoffLighting,
    setEmbeddedBackgroundColor,
    setEmbeddedHandoffLabelSnapshot,
    clearEmbeddedHandoffLabelSnapshot,
    getV5SelectionState: () => activeV5CitySelection(),
    getV5City: (cityId) => resolveActiveNode(cityId),
    getV5CityAnchor: (cityId) => {
      const node = resolveActiveNode(cityId);
      return node && globe ? projectedNodeRect(node) : null;
    },
    focusConcept,
    destroy() {
      destroyed = true;
      if (planetSignalRenderTimer) window.clearTimeout(planetSignalRenderTimer);
      planetSignalRenderTimer = 0;
      resizeObserver?.disconnect();
      window.removeEventListener('resize', measureBounds);
      layer.removeEventListener('click', onClick);
      morph.removeEventListener('pointerdown', onPlanetPointerDown, true);
      morph.removeEventListener('pointermove', onPlanetPointerMove, true);
      morph.removeEventListener('pointerup', onPlanetPointerUp, true);
      morph.removeEventListener('pointercancel', onPlanetPointerCancel, true);
      cardClose.removeEventListener('click', onCardClose);
      window.removeEventListener('keydown', onKeydown);
      document.removeEventListener('fullscreenchange', onFullscreenChange);
      v3LayoutSelect.removeEventListener('change', onV3LayoutChange);
      v3DiagnosticSelect.removeEventListener('change', onV3DiagnosticChange);
      v3BridgeRendererSelect.removeEventListener('change', onV3BridgeRendererChange);
      v3EdgeEnabledToggle.removeEventListener('change', onV3EdgeToggleChange);
      v3EdgeBackToggle.removeEventListener('change', onV3EdgeToggleChange);
      v4LocalEdgesToggle.removeEventListener('change', onV4EdgeToggleChange);
      v4RemoteEdgesToggle.removeEventListener('change', onV4EdgeToggleChange);
      v5SizeTuning.removeEventListener('change', syncV5SizeSettings);
      v5SizeTuning.removeEventListener('input', syncV5SizeSettings);
      v6LightTuning.removeEventListener('change', onV6LightRigChange);
      v7LightTuning.removeEventListener('change', onV7LightRigChange);
      v7LightTuning.removeEventListener('input', onV7LightRigChange);
      if (v3VisibilityFrame) cancelAnimationFrame(v3VisibilityFrame);
      if (v5LabelProjectionFrame) cancelAnimationFrame(v5LabelProjectionFrame);
      if (lightRigFrame) cancelAnimationFrame(lightRigFrame);
      if (edgeRegistryRetryTimer) window.clearTimeout(edgeRegistryRetryTimer);
      edgeRegistryRetryTimer = 0;
      if (document.fullscreenElement === morph && document.exitFullscreen) void document.exitFullscreen();
      layer.classList.remove('is-fullscreen');
      if (v3VisibilityListener) globe?.controls?.().removeEventListener('change', v3VisibilityListener);
      if (v5LabelProjectionListener) globe?.controls?.().removeEventListener('change', v5LabelProjectionListener);
      if (lightRigListener) globe?.controls?.().removeEventListener('change', lightRigListener);
      if (v7ControlsListener) globe?.controls?.().removeEventListener('change', v7ControlsListener);
      if (v7ControlStartListener) globe?.controls?.().removeEventListener('start', v7ControlStartListener);
      if (v7ControlEndListener) globe?.controls?.().removeEventListener('end', v7ControlEndListener);
      if (globe?.scene?.()?.onBeforeRender === v7SceneBeforeRenderHook) globe.scene().onBeforeRender = v7SceneBeforeRender;
      v6CosmicEnvironment?.dispose();
      v6CosmicEnvironment = null;
      v7CosmicEnvironment?.dispose();
      v7CosmicEnvironment = null;
      v7LightRig?.dispose();
      v7LightRig = null;
      planetSignalDebugPanel.dispose();
      clearVirtualSunObjectRegistry();
      djinnEdgeLayer?.dispose();
      djinnEdgeLayer = null;
      planetGraphRoot?.removeFromParent();
      planetGraphRoot = null;
      lightProofGroup?.traverse((object) => {
        object.geometry?.dispose?.();
        object.material?.dispose?.();
      });
      lightProofGroup?.removeFromParent();
      lightTarget?.removeFromParent();
      lightProofGroup = null;
      lightTarget = null;
      virtualGalaxyFrame = null;
      clearNodeObjectRegistry();
      globe?.controls?.().dispose?.();
      sphereGeometry.dispose();
      v5BridgeRingGeometry.dispose();
      materialCache.forEach((material) => material.dispose());
      globe = null;
      layer.remove();
    }
  };
}
