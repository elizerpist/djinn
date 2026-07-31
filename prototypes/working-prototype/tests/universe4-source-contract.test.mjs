import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const u3Stage = await readFile(new URL('../assets/universe4/universe4-u3-stage.js', import.meta.url), 'utf8');
const v7SourceStage = await readFile(new URL('../assets/universe4/universe4-v7-source-stage.js', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const matcher = await readFile(new URL('../assets/universe4/universe4-handoff-matcher.js', import.meta.url), 'utf8');
const screen = await readFile(new URL('../screens/universe.html', import.meta.url), 'utf8');
const u3Controller = await readFile(new URL('../assets/universe4/universe4-force-controller.js', import.meta.url), 'utf8');
const exploreController = await readFile(new URL('../assets/explore-galaxy-orb.js', import.meta.url), 'utf8');
const depthController = await readFile(new URL('../assets/universe4/universe4-depth-controller.js', import.meta.url), 'utf8');
const selectionPolicy = await readFile(new URL('../assets/universe4/universe4-globe-selection.js', import.meta.url), 'utf8');
const focusedSnapshot = await readFile(new URL('../assets/universe4/universe4-focused-map-snapshot.js', import.meta.url), 'utf8');
const tangentPlane = await readFile(new URL('../assets/universe4/universe4-tangent-plane.js', import.meta.url), 'utf8');
const morphPatch = await readFile(new URL('../assets/universe4/universe4-morph-patch.js', import.meta.url), 'utf8');
const g6Stage = await readFile(new URL('../assets/universe4/universe4-g6-focused-map-stage.js', import.meta.url), 'utf8');
const sharedG6Stage = await readFile(new URL('../assets/focused-g6-v2-stage.js', import.meta.url), 'utf8');

assert.match(u3Stage, /export function createUniverse4U3Stage/);
assert.match(u3Stage, /initUniverse4ForceController/);
assert.doesNotMatch(u3Stage, /initUniverseMorphTest/);
assert.match(u3Stage, /universe4-u3-screen/);
assert.match(u3Stage, /onPlanetReady/);
assert.match(u3Stage, /is-u4-input-disabled/);
assert.match(u3Stage, /pauseAnimation\(\)/,
  'the production U3 adapter must be able to stop its hidden ForceGraph render loop');
assert.match(u3Stage, /resumeAnimation\(\)/,
  'the production U3 adapter must be able to resume before a diagnostic return');
assert.match(u3Stage, /resetToGalaxyOverview/,
  'the U3 adapter must expose a deterministic galaxy reset seam instead of rebuilding a reverse camera pose');
assert.match(u3Stage, /setBackgroundColor/,
  'the U3 adapter must expose only its own ForceGraph background clear-color seam');
assert.match(u3Stage, /captureHandoffFrame/,
  'the U3 adapter must expose the real final Force camera/planet frame, not a node-coordinate estimate');
assert.match(u3Stage, /captureRenderProfile/,
  'the U3 adapter must expose the live Force material/light/renderer profile for handoff parity diagnostics');
assert.match(u3Controller, /captureFocusedPlanetHandoffFrame/,
  'the production U3 controller must capture its selected detail globe world transform and landmark projections');
assert.match(u3Controller, /function captureFocusedPlanetRenderProfile\(/,
  'the production U3 controller must report its actual material, recursively discovered scene lights and renderer state');
assert.match(u3Controller, /material === globeMaterial && opacity >= \.999[\s\S]*?material\.transparent = false/,
  'the fully revealed inline globe body must return to the same opaque Phong state as V7 after its morph fade');
assert.match(u3Controller, /lightSnapshot/,
  'the Force capture must include its actual V3-reference light state, not leave V7 to start from an unrelated sun direction');
assert.match(u3Controller, /resetToGalaxyOverview/,
  'the production U3 controller must restore its actual galaxy baseline for Reset');
assert.match(u3Controller, /setUniverseBackgroundColor/,
  'the production U3 controller must own ForceGraph background updates');
assert.match(u3Controller, /function applyInlinePlanetEntryMorph\(/,
  'the U3 entry needs one reusable morph operation so camera travel and detail reveal share the same timeline');
assert.match(u3Controller, /const v3MorphSetup = isFocusV3[\s\S]*?loadThreeGlobe\(\)[\s\S]*?configureDetailGlobe/,
  'the V3 detail globe must prewarm before the focus tween rather than waiting for zoom to finish');
assert.match(u3Controller, /const focused = await tween\(isFocusV3 \? 920 : 560,[\s\S]*?if \(isFocusV3 && detailScale != null\) \{\s*applyInlinePlanetEntryMorph\(/,
  'each V3 zoom frame must advance the already-prepared inline morph');
assert.match(u3Controller, /if \(isFocusV3\) \{\s*const preparedDetailScale = await v3MorphSetup[\s\S]*?applyInlinePlanetEntryMorph\(view, detailScale, 1, nodeId\);/,
  'the handoff must wait for the same concurrent morph to reach its final state, without a second post-zoom tween');
const inlineEntryMorph = u3Controller.match(/function applyInlinePlanetEntryMorph\(view, detailScale, eased, nodeId\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(u3Controller, /const UNIVERSE_V3_INLINE_GLOBE_VISUAL_RADIUS_MULTIPLIER = 1\.18;/,
  'the inline ThreeGlobe needs one explicit, static visual-size calibration instead of an animated shrink compensation');
assert.match(inlineEntryMorph, /detailGlobe\.scale\.setScalar\(detailScale\);/,
  'the calibrated inline ThreeGlobe scale must stay fixed throughout entry');
assert.doesNotMatch(inlineEntryMorph, /\.92 \+ eased \* \.08/,
  'entry must not hide a Force-proxy/ThreeGlobe size mismatch behind a shrink or grow tween');
const inlineGlobeSetup = u3Controller.match(/function configureDetailGlobe\(ThreeGlobe, view\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(inlineGlobeSetup, /const scale = \(view\.radius \/ \(detailGlobe\.getGlobeRadius\?\.\(\) \|\| 100\)\) \* UNIVERSE_V3_INLINE_GLOBE_VISUAL_RADIUS_MULTIPLIER;[\s\S]*?detailGlobe\.scale\.setScalar\(scale\);/,
  'the prewarmed ThreeGlobe must start at its final calibrated visual radius before the first visible morph frame');
const inlinePlanetFactory = u3Controller.match(/function createGalaxyNodeRoot\(node\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(inlinePlanetFactory, /glow\.scale\.setScalar\(radius \* \(isFocusV3 && node\.isPlanet \? 1 : 1\.23\)\);/,
  'the visible U3 planet proxy glow must share the body radius; its former 1.23 shell made the source globe visibly larger than the inline ThreeGlobe');
assert.match(u3Controller, /const UNIVERSE_V3_ENTRY_VIEWPORT_FILL = \.56;/,
  'the U3/U4 focused entry must end at the closer requested shared Force/Globe framing');
assert.match(u3Controller, /focusDistanceForBoundingRadius\(radius, camera\.fov \|\| 50, camera\.aspect \|\| 1, UNIVERSE_V3_ENTRY_VIEWPORT_FILL\)/,
  'the Force camera endpoint must derive from the tighter V3 entry framing so the captured handoff also starts Globe.gl closer');
assert.match(u3Stage, /suppressInlineCityLabels:\s*true/,
  'the U4 Force stage must explicitly keep inline city labels disabled during the renderer handoff');
assert.match(u3Controller, /const suppressInlineCityLabels = Boolean\(helpers\.suppressInlineCityLabels\);/,
  'the production U3 controller must accept the U4-only inline-label policy without changing ordinary U3');
assert.match(u3Controller, /if \(suppressInlineCityLabels\) \{\s*hideUniverseV5LabelSprites\(\);\s*return;\s*\}/,
  'the inline U3 label path must return before creating or positioning city sprites');
const inlineDetailGlobe = u3Controller.match(/function configureDetailGlobe\(ThreeGlobe, view\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(inlineDetailGlobe, /new THREE\.MeshPhongMaterial\(/,
  'the inline U3 globe body must use V7\'s Phong response instead of a visually different Standard material');
assert.match(u3Controller, /function stripForceGraphDefaultLights\(scene\)/,
  'the U3 reference stage must explicitly remove ForceGraph\'s inherited lights before installing the authoritative V3 rig');
const defaultLightStripper = u3Controller.match(/function stripForceGraphDefaultLights\(scene\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(defaultLightStripper, /scene\.traverse\?\.\(/,
  'the Force-side light cleanup must inspect nested vendor groups, not only direct scene children');
assert.match(defaultLightStripper, /lights\.forEach\(\(light\) => light\.removeFromParent\(\)\)/,
  'every inherited ForceGraph light must be removed before the V3-reference rig is installed');
assert.match(u3Controller, /stripForceGraphDefaultLights\(scene\);[\s\S]*?new THREE\.AmbientLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.ambientColor, UNIVERSE_V3_REFERENCE_LIGHTING\.ambientIntensity\)[\s\S]*?new THREE\.HemisphereLight\([\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillColor[\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillGroundColor[\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillIntensity[\s\S]*?new THREE\.DirectionalLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.keyColor, UNIVERSE_V3_REFERENCE_LIGHTING\.keyIntensity\)/,
  'the only active inline focus rig must be the V3-reference ambient, hemisphere and directional-light contract used by V7');
assert.match(u3Controller, /const sharedSphereGeometry = new THREE\.SphereGeometry\(1, 32, 24\);/,
  'ForceGraph planet proxies must use a sufficiently dense shared sphere geometry instead of visibly faceted 16×12 shells');
assert.match(u3Controller, /function pauseUniverseRenderRuntime\(\)/,
  'pausing the hidden U3 stage must stop its own HUD/cosmic RAF, not only the vendor ForceGraph loop');
assert.match(u3Controller, /window\.cancelAnimationFrame\(hudFrame\)/,
  'the hidden U3 HUD RAF must be cancelled when V7 becomes the active renderer');
assert.match(u3Controller, /universeCosmicEnvironment\?\.suspend\?\.\(\)/,
  'the hidden U3 cosmic environment must be suspended with its HUD RAF');
assert.match(u3Controller, /function resumeUniverseRenderRuntime\(\)/,
  'Reset must be able to restart the U3 HUD/cosmic runtime before Force becomes visible again');
assert.match(u3Controller, /dispose\.pauseAnimation = pauseUniverseRenderRuntime/,
  'the U4 adapter seam must use the full U3 runtime pause, not only graph.pauseAnimation');
assert.match(u3Controller, /dispose\.resumeAnimation = resumeUniverseRenderRuntime/,
  'the U4 adapter seam must use the full U3 runtime resume');

assert.match(v7SourceStage, /export function createUniverse4V7SourceStage/);
assert.match(v7SourceStage, /initExpandableGalaxyOrb/);
assert.match(v7SourceStage, /initialVariant:\s*'v7'/);
assert.match(v7SourceStage, /setRoute\('explore'\)/);
assert.match(v7SourceStage, /setInputEnabled/);
assert.match(v7SourceStage, /is-u4-input-disabled/);
assert.match(v7SourceStage, /pauseAnimation\(\)/,
  'the hidden canonical V7 stage must stop rendering after prewarm');
assert.match(v7SourceStage, /resumeAnimation\(\)/,
  'the canonical V7 stage must resume immediately before handoff');
assert.match(v7SourceStage, /waitForRenderedFrames/,
  'handoff must wait for freshly rendered V7 frames rather than fading in a stale canvas');
assert.match(v7SourceStage, /applyHandoffPose/,
  'the canonical V7 source stage must accept a real mapped Force pose while hidden');
assert.match(v7SourceStage, /captureHandoffFrame/,
  'the canonical V7 source stage must measure its own CSS center, radius and landmark projections');
assert.match(v7SourceStage, /captureRenderProfile/,
  'the canonical V7 adapter must expose its live material/light/renderer profile for parity diagnostics');
assert.match(v7SourceStage, /getInputDiagnostics/,
  'the canonical V7 adapter must expose effective DOM and OrbitControls input state');
assert.match(v7SourceStage, /onInputDiagnostic/,
  'the canonical V7 adapter must forward input-boundary diagnostics to the U4 trace');
assert.match(v7SourceStage, /applyEmbeddedHandoffLighting/,
  'the hidden V7 stage must adopt the captured U3 V3-reference light direction before it is eligible for reveal');
assert.match(v7SourceStage, /lightSnapshot/,
  'the hidden V7 stage must receive the actual Force light snapshot together with camera pose');
assert.match(v7SourceStage, /setEmbeddedHandoffLabelSnapshot/,
  'the hidden V7 stage must freeze the Force landmark label set before it can be revealed');
assert.match(v7SourceStage, /setBackgroundColor/,
  'the canonical V7 source stage must expose only its own Globe background clear-color seam');
assert.match(exploreController, /setEmbeddedHandoffLabelSnapshot/,
  'the canonical V7 source must own the temporary frozen label set rather than rebuilding a U4-specific label renderer');
assert.match(exploreController, /setEmbeddedBackgroundColor/,
  'the canonical V7 source must own embedded Globe background updates');
assert.match(exploreController, /externalRole === 'root'\) v5DataColor = '#FFD45A'/,
  'the selected mother/root city must render gold in the embedded U4 Globe');
assert.match(exploreController, /externalRole === 'context'\) v5DataColor = '#77E8FF'/,
  'the context child cities must render blue in the embedded U4 Globe');
assert.match(exploreController, /function beginV5LabelTap\(event\)/,
  'a canonical V7 label must start an explicit city gesture instead of relying on a canvas raycast behind the DOM chip');
assert.match(exploreController, /function completeV5LabelTap\(event\)[\s\S]*?focusNode\(gesture\.cityId\)/,
  'a completed V7 label gesture must enter the same city-focus/U4 tap-policy path as a sphere tap');
assert.match(exploreController, /tapDistanceSquared:\s*embeddedViewport \? 576 : 81/,
  'the embedded mobile V7 endpoint must tolerate a 24px intentional city tap before classifying it as an orbit drag');
assert.match(exploreController, /tapDurationMs:\s*embeddedViewport \? 620 : 360/,
  'the embedded mobile V7 endpoint must tolerate a deliberate city tap without loosening the normal Explore gesture contract');

// Globe → G6 is a third U4 depth, not an Explore route or a second V7 clone.
assert.match(depthController, /PLANET_TO_MAP_MORPH/);
assert.match(depthController, /MAP_TO_PLANET_MORPH/);
assert.match(selectionPolicy, /clear-context/);
assert.match(selectionPolicy, /enter-map/);
assert.match(selectionPolicy, /consume: true/,
  'a foreign-city tap must be consumed after clearing the prior context');
assert.match(focusedSnapshot, /immutable domain bridge/);
assert.match(tangentPlane, /stable local East\/North\/Normal frame/);
assert.match(morphPatch, /never changes Globe geometry/);
assert.match(g6Stage, /createFocusedG6V2Stage/,
  'Universe owns a narrow adapter around the existing G6 v2 stage rather than a duplicated map renderer');
assert.match(sharedG6Stage, /buildFocusedG6V2Subgraph/);
assert.match(sharedG6Stage, /focusedG6V2Positions/);
assert.match(sharedG6Stage, /knowledgeNodes/,
  'the embedded stage must use the canonical full G6 V2 domain after the Globe entry handoff');
assert.match(sharedG6Stage, /focusedG6V2ShouldRefreshLod/,
  'pinch/wheel zoom must only rebuild cards after a real V2 LOD boundary');
assert.match(sharedG6Stage, /setActiveFocus/,
  'a G6 node tap must replace the dynamic center card instead of remaining a static map');
assert.match(sharedG6Stage, /createFocusedG6V2StageControls/,
  'the embedded full map must expose explicit zoom in, zoom out and recenter controls');
assert.match(runtime, /createUniverse4G6FocusedMapStage/);
assert.match(runtime, /let g6Stage = null;/,
  'the G6 ready callback can be synchronous, so it must not close over a TDZ const binding');
assert.match(runtime, /g6Stage = createUniverse4G6FocusedMapStage\(/,
  'the nullable G6 reference must be assigned only after its safe binding exists');
assert.match(runtime, /createUniverse4MorphPatch/);
assert.match(runtime, /resolveV7CityTap/);
assert.match(runtime, /enterFocusedMap/);
assert.match(runtime, /returnFocusedMapToPlanet/);
assert.match(runtime, /data-universe4-g6-stage/);
assert.match(screen, /data-universe4-g6-stage/);
assert.match(screen, /data-universe4-morph-patch-stage/);
assert.doesNotMatch(runtime, /navigate\([^)]*explore/i,
  'the G6 depth must remain mounted inside Universe 4, never navigate to Explore');

assert.match(runtime, /createUniverse4U3Stage/);
assert.match(runtime, /createUniverse4V7SourceStage/);
assert.match(runtime, /let v7Stage = null;/,
  'the synchronous canonical V7 ready callback must never close over a TDZ const binding');
assert.match(app, /universe4\.js\?rev=55/,
  'the U4 module revision must change when its embedded full-map runtime changes');
assert.match(runtime, /universe4-u3-stage\.js\?rev=20/,
  'the migrated V4 Force adapter must invalidate its owner module');
assert.match(runtime, /universe4-v7-source-stage\.js\?rev=22/,
  'the U4 source-stage revision must change when its canonical Globe controls change');
assert.match(index, /assets\/app\.js\?rev=274/,
  'the browser entrypoint must invalidate the app module which imports U4');
assert.match(runtime, /HANDOFF_CROSSFADE/);
assert.match(runtime, /GLOBE_STANDALONE/);
assert.match(runtime, /whenReady\(\)/, 'handoff must wait for the embedded canonical V7 controller');
assert.match(matcher, /validatePixelMatch/,
  'the renderer reveal must be blocked by a measured Force/V7 pixel match');
assert.match(runtime, /prepareInvisibleGlobeMatch/,
  'the V7 size must be solved from CSS radius instead of copied as a raw Force distance');
assert.match(matcher, /waitForRenderedFrames\?\.\(stableFrameCount\)/,
  'the first visible V7 frame requires the matcher to wait for hidden stable frames');
assert.match(matcher, /U4_REQUIRED_HIDDEN_GLOBE_FRAMES\s*=\s*3/,
  'the first visible V7 frame requires three hidden stable frames');
assert.match(runtime, /u4\.u3\.inline\.complete/);
assert.match(runtime, /u4\.handoff\.complete/);
assert.match(runtime, /u4\.handoff\.light\.transfer/,
  'the on-screen U4 trace must identify the exact transferred U3 light direction');
assert.match(runtime, /u4\.handoff\.render\.profile/,
  'the on-screen U4 trace must emit both rendered material/light/renderer profiles before reveal');
assert.match(runtime, /v7Stage\.resumeAnimation\(\);\s*const forceFrame = u3Stage\.captureHandoffFrame\(\);/,
  'U4 must capture the final U3 world transform before the hidden V7 pose solve');
assert.match(runtime, /if \(!latestMatch\.valid\)/,
  'a failed pixel match must retain the visible U3 renderer instead of crossfading');
assert.match(runtime, /u3Stage\.pauseAnimation\(\);/,
  'U4 must stop ForceGraph once the V7 canvas owns the screen');
assert.match(runtime, /v7Stage\.pauseAnimation\(\);/,
  'U4 must keep hidden V7 idle outside the handoff window');
assert.match(runtime, /async function resetToForceGalaxy\(\)/,
  'the visible Reset action must restore the ForceGraph galaxy baseline, not reconstruct a reverse camera pose');
assert.match(runtime, /machine\.begin\(U4_STATE\.RETURN_PREPARE\)/);
assert.match(runtime, /machine\.advance\(U4_STATE\.RETURN_CROSSFADE, generation\)/);
assert.match(runtime, /u3Stage\.resetToGalaxyOverview\(\)/,
  'Reset must call the genuine U3 galaxy baseline seam before returning Force input');
assert.match(runtime, /data-universe4-reset/,
  'the U4 runtime must route the stage-level Reset button');
assert.match(screen, /data-universe4-reset/,
  'Reset must remain visible in the actual V4 stage, not only in a hidden debug panel');
assert.match(runtime, /const resetButton = root\.querySelector\('\[data-universe4-reset\]'\);/,
  'Reset must bind directly to its own control instead of relying on the Globe pointer event chain');
assert.match(runtime, /resetButton\?\.addEventListener\('pointerup', onResetPointerUp\)/,
  'a V7 pointer router must not be able to suppress the Reset tap');
assert.match(runtime, /u4\.reset\.request/,
  'the V7 trace needs a reset-request boundary event before any state guard runs');
assert.match(runtime, /u4\.reset\.error/,
  'a failed U3 reset must recover the live V7 stage rather than silently leaving Reset locked');
assert.match(runtime, /data-universe4-force-background/,
  'U4 must bind an independent ForceGraph background selector');
assert.match(runtime, /data-universe4-globe-background/,
  'U4 must bind an independent Globe background selector');
assert.match(screen, /data-universe4-force-background/,
  'the ForceGraph background selector must be visible in the stage');
assert.match(screen, /data-universe4-globe-background/,
  'the Globe background selector must be visible in the stage');
assert.match(runtime, /u3Stage\.setBackgroundColor/,
  'ForceGraph background changes must remain scoped to the Force stage');
assert.match(runtime, /v7Stage\.setBackgroundColor/,
  'Globe background changes must remain scoped to the Globe stage');
assert.doesNotMatch(runtime, /createUniverse4ForceStage/);
assert.doesNotMatch(runtime, /createUniverse4V7GlobeStage/);

console.log('universe4 source contract OK');
