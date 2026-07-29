import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const u3Stage = await readFile(new URL('../assets/universe4/universe4-u3-stage.js', import.meta.url), 'utf8');
const v7SourceStage = await readFile(new URL('../assets/universe4/universe4-v7-source-stage.js', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');
const matcher = await readFile(new URL('../assets/universe4/universe4-handoff-matcher.js', import.meta.url), 'utf8');
const screen = await readFile(new URL('../screens/universe-morph-test-v4.html', import.meta.url), 'utf8');
const u3Controller = await readFile(new URL('../assets/universe-morph-test.js', import.meta.url), 'utf8');
const exploreController = await readFile(new URL('../assets/explore-galaxy-orb.js', import.meta.url), 'utf8');

assert.match(u3Stage, /export function createUniverse4U3Stage/);
assert.match(u3Stage, /initUniverseMorphTest/);
assert.match(u3Stage, /universe-morph-v3-screen/);
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
assert.match(u3Controller, /captureFocusedPlanetHandoffFrame/,
  'the production U3 controller must capture its selected detail globe world transform and landmark projections');
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
assert.match(u3Controller, /const UNIVERSE_V3_ENTRY_VIEWPORT_FILL = \.46;/,
  'the U3/U4 focused entry must tighten once more from the prior .43 viewport fill');
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
assert.match(u3Controller, /stripForceGraphDefaultLights\(scene\);[\s\S]*?new THREE\.AmbientLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.ambientColor, UNIVERSE_V3_REFERENCE_LIGHTING\.ambientIntensity\)[\s\S]*?new THREE\.HemisphereLight\([\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillColor[\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillGroundColor[\s\S]*?UNIVERSE_V3_REFERENCE_LIGHTING\.fillIntensity[\s\S]*?new THREE\.DirectionalLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.keyColor, UNIVERSE_V3_REFERENCE_LIGHTING\.keyIntensity\)/,
  'the only active inline focus rig must be the V3-reference ambient, hemisphere and directional-light contract used by V7');
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

assert.match(runtime, /createUniverse4U3Stage/);
assert.match(runtime, /createUniverse4V7SourceStage/);
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
