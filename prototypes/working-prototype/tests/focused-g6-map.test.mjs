import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import * as THREE from '../assets/vendor/three.module.min.js';
import {
  bendCardToSphereGeometry,
  buildRollingFocusedWindow,
  buildFocusedG6V2Subgraph,
  buildRollingFrontier,
  knowledgeNodes,
  knowledgeEdges,
  buildFocusedG6Subgraph,
  focusedG6Positions,
  focusedG6V2Lod,
  forceSphereCardTransform,
  forceSphereCardLayout,
  forceSphereStructuredCardFrame,
  forceSphereCardCameraDistance,
  projectVirtualPointToSphereCap,
  buildRollingSlotAtoms,
  buildForceSphereSlotAtoms,
  buildMorphClusterFocusAtoms,
  projectFocusedMapPointToGlobeCap,
  rollingSlotToGeo,
  filterCardGlobeArcs,
  buildCardGlobeSurfacePath,
  globeFocusedAirArcAltitude,
  buildForceSphereSurfaceLinkPoints,
  forceSphereZoomScale,
  forceSphereNodeValue,
  forceSphereCardEntrySlot,
  forceSphereCardLayerSlot,
  buildLayeredSphericalFocusLayout,
  destinationPointOnGlobe,
  buildGlobeFocusedCardLayout,
} from '../assets/universe4/universe4-graph-data.js';

const subgraph = buildFocusedG6Subgraph('resp_failure', knowledgeNodes, knowledgeEdges);

assert.equal(subgraph.focusId, 'resp_failure', 'a központi atom maradjon a fókusz');
assert.ok(subgraph.nodes.length > 1, 'a fókuszhoz tartozzon lokális környezet');
assert.ok(subgraph.nodes.length <= 24, 'a G6 ne kapja meg a teljes gráfot');
assert.ok(subgraph.nodes.some((node) => node.id === 'do2'), 'a legerősebb szomszédok kerüljenek be');
assert.ok(subgraph.edges.every((edge) => subgraph.nodeIds.has(edge.source) && subgraph.nodeIds.has(edge.target)), 'csak a lokális kártyák közötti kapcsolatok rajzolódjanak ki');

const positions = focusedG6Positions(subgraph.nodes, 'resp_failure', 360, 560);
const focus = positions.get('resp_failure');
assert.deepEqual(focus, { x: 180, y: 280, level: 0 }, 'a fókuszkártya a vászon közepére kerüljön');
assert.ok([...positions.values()].some((position) => position.level === 1), 'az első gyűrű külön pozíciós szintet kapjon');

const cardSizes = { 0: [124, 62], 1: [96, 48], 2: [78, 38] };
for (const focusId of ['resp_failure', 'niv', 'do2', 'ards']) {
  const focusedGraph = buildFocusedG6Subgraph(focusId, knowledgeNodes, knowledgeEdges);
  const focusedPositions = focusedG6Positions(focusedGraph.nodes, focusedGraph.focusId, 360, 560);
  const collisions = [];
  assert.equal(focusedPositions.size, focusedGraph.nodes.length, `${focusId}: minden renderelt kártyához legyen pozíció`);
  for (let index = 0; index < focusedGraph.nodes.length; index += 1) {
    for (let otherIndex = index + 1; otherIndex < focusedGraph.nodes.length; otherIndex += 1) {
      const first = focusedGraph.nodes[index];
      const second = focusedGraph.nodes[otherIndex];
      const firstPosition = focusedPositions.get(first.id);
      const secondPosition = focusedPositions.get(second.id);
      const [firstWidth, firstHeight] = cardSizes[first.focusDepth];
      const [secondWidth, secondHeight] = cardSizes[second.focusDepth];
      const overlapsHorizontally = Math.abs(firstPosition.x - secondPosition.x) < (firstWidth + secondWidth) / 2 + 10;
      const overlapsVertically = Math.abs(firstPosition.y - secondPosition.y) < (firstHeight + secondHeight) / 2 + 10;
      if (overlapsHorizontally && overlapsVertically) collisions.push(`${first.id}:${second.id}`);
    }
  }
  assert.deepEqual(collisions, [], `${focusId}: a lokális G6-kártyák között legalább 10 px biztonsági távolság maradjon`);
}

const mapSource = await readFile(new URL('../assets/universe4/universe4-graph-data.js', import.meta.url), 'utf8');
const mapScreen = await readFile(new URL('../screens/universe.html', import.meta.url), 'utf8');
assert.doesNotMatch(mapSource, /\{ id: 'force', label: 'Force'/, 'a régi Force 2D nézet ne szerepeljen a dropdownban');
assert.doesNotMatch(mapSource, /\{ id: 'd3-force', label: 'D3 Force'/, 'a régi D3 Force 2D nézet ne szerepeljen a dropdownban');
assert.doesNotMatch(mapSource, /Fa elrendezések|compact-box|dendrogram|fishbone|mindmap|indented/, 'a fa-elrendezések és a hozzájuk tartozó opciók ne maradjanak az appban');
assert.doesNotMatch(mapSource, /TREE_LAYOUTS|treeGraphData|buildSpanningTree/, 'a törölt fa-renderelési útvonal ne maradjon az appban');
assert.doesNotMatch(mapSource, /combo-combined|Combo Combined|Csoportosított/, 'a Combo Combined és a csoportosított opció ne maradjon az appban');
assert.doesNotMatch(mapSource, /id: '(?:circular|concentric|radial|grid|random|snake)'|group: 'Kör és tér'/, 'a Kör és tér csoport és összes nézete ne maradjon az appban');
assert.doesNotMatch(mapSource, /id: '(?:force-atlas2|fruchterman|mds)'|group: 'Erő alapú hálók'/, 'az Erő alapú hálók csoport és összes nézete ne maradjon az appban');
assert.doesNotMatch(mapSource, /cytoscape|Cytoscape|antv-dagre|dagre|Irányított gráfok/, 'a Cytoscape és az Irányított gráfok nézetei ne maradjanak az app kódjában');
assert.doesNotMatch(mapScreen, /data-map-|knowledge-map|cytoscape|Cytoscape/, 'a régi Workspace gráfkonténer ne maradjon az appban');
assert.match(mapScreen, /data-universe4-g6-stage/, 'a G6 nézet a Universe képernyőn maradjon');
assert.match(mapSource, /labelPlacement:\s*'center'/, 'a G6 címke a kártya belsejében, középen jelenjen meg');
assert.match(mapSource, /localStorage\.removeItem\(STORAGE_KEY\)/, 'frissítéskor a korábbi navigációs és vizualizációs állapot törlődjön');
assert.match(mapSource, /visualization: 'g6-focused-map'/, 'frissítés után biztonságos, lokális fókusznézet induljon');
assert.match(mapSource, /const D3_FORCE_3D_NODE_LIMIT = 120/, 'a D3 Force 3D mobilos előnézete korlátozott elemszámmal induljon');
assert.match(mapSource, /function compactD3Force3DNodes\(/, 'a D3 Force 3D a teljes gráf helyett determinisztikus, korlátozott részgráfot kapjon');
assert.match(mapSource, /if \(!graphReady \|\| !graph\) return;/, 'nézetváltáskor a leállított G6 utolsó viewport-eseménye ne kérjen zoomot a már destruktált példánytól');

const curvedGeometry = new THREE.PlaneGeometry(37, 18.5, 16, 8);
bendCardToSphereGeometry(curvedGeometry, 115, 180);
const curvedPositions = curvedGeometry.attributes.position;
const curvedZ = Array.from({ length: curvedPositions.count }, (_, index) => curvedPositions.getZ(index));
assert.ok(curvedPositions.count > 4, 'az ívelt kártya geometriája több mint két háromszögből álljon');
assert.ok(Math.max(...curvedZ) - Math.min(...curvedZ) > .5, 'a kártya vertexei tényleges Z-görbületet kapjanak');
assert.ok(Math.min(...curvedZ) < -.5, 'a kártya szélei a gömb felszíne felé hajoljanak');
assert.match(mapSource, /new THREE\.PlaneGeometry\(37, 18\.5, 16, 8\)/, 'a fókuszált gömbkártya felosztott PlaneGeometry-t használjon');
assert.match(mapSource, /makeKnowledgeCardObject\(point, \{ curved: true \}\)/, 'csak a fókuszált gömbkártya kérjen ívelt geometriát');

const v2Subgraph = buildFocusedG6V2Subgraph('resp_failure', knowledgeNodes, knowledgeEdges);
assert.ok(v2Subgraph.nodes.length <= 8, 'a V2 csak kevés, szoros fókuszkártyát mutasson');
assert.ok(v2Subgraph.nodes.some((node) => node.id === 'resp_failure'), 'a V2-ben is megmaradjon a fókuszatom');
assert.equal(focusedG6V2Lod(1).maxNodes, 8, 'közeli G6 V2 nézetben kevés kártya maradjon');
assert.ok(focusedG6V2Lod(.55).maxNodes > focusedG6V2Lod(1).maxNodes, 'kifelé zoomolva a G6 V2 további kártyákat kérjen');
assert.ok(focusedG6V2Lod(.25).maxNodes > focusedG6V2Lod(.55).maxNodes, 'nagy távolságban még több context-kártya legyen elérhető');
assert.match(mapSource, /id: 'g6-focused-map-v2'/, 'a Fókuszált térkép v2 önálló választható opció legyen');
assert.match(mapSource, /id: 'g6-focused-map-dark'/, 'a G6 fókuszált térkép deep-space violet duplikált nézete választható legyen');
assert.match(mapSource, /function isFocusedG6DarkView\(\)/, 'a deep-space G6 nézet külön témát használjon');
assert.match(mapSource, /fill: '#6B3EF6', stroke: '#B9B0E6', label: '#ECE7FF'/, 'a deep-space G6 fókuszkártya a Globe palettáját használja');
assert.match(mapSource, /mapContainer\.style\.background = dark \? '#0B0A17'/, 'a deep-space G6 térképfelülete sötét legyen');
assert.match(mapSource, /id: 'g6-focused-map-v2-dark'/, 'a G6 fókuszált térkép v2 deep-space violet duplikált nézete választható legyen');
assert.match(mapSource, /function isFocusedG6V2DarkView\(\)/, 'a v2 deep-space G6 nézet külön témát használjon');
assert.match(mapSource, /function focusedG6V2GraphData\(dark = false\)/, 'a v2 grafikon külön színpalettát kaphasson');
assert.match(mapSource, /renderFocusedG6V2Graph/, 'a V2 saját G6 renderelési útvonalon fusson');

const capCenter = projectVirtualPointToSphereCap(0, 0, 100, .004);
const capOffset = projectVirtualPointToSphereCap(160, -80, 100, .004);
assert.deepEqual(capCenter, { x: 0, y: 0, z: 100 }, 'a rolling gömbsapka középpontja a kamera előtt legyen');
assert.notDeepEqual(capOffset, capCenter, 'a virtuális elmozdulás új, nem modulo 360 fokos renderpozíciót adjon');
const rollingFrontier = buildRollingFrontier('resp_failure', new Set(['resp_failure']), knowledgeNodes, knowledgeEdges);
assert.equal(rollingFrontier[0].id, 'hypoxemic_failure', 'a rolling frontier a legerősebb közvetlen kapcsolattal kezdődjön');
const sparseRollingSlots = buildRollingSlotAtoms('diffusion_disorder', 7, knowledgeNodes, knowledgeEdges);
assert.equal(sparseRollingSlots.length, 7, 'kevés közvetlen kapcsolatnál is hét slot töltse ki a kamera előtti sapkát');
assert.equal(sparseRollingSlots[0], 'diffusion_disorder', 'a kiválasztott atom maradjon az első, központi slotban');
assert.equal(new Set(sparseRollingSlots).size, 7, 'a kiterjesztett rolling környezetben ne legyen ismétlődő atom');
const rollingWindow = buildRollingFocusedWindow('resp_failure', knowledgeNodes, knowledgeEdges);
assert.equal(rollingWindow.length, 7, 'a rolling gömb fókuszablaka pontosan egy fókuszt és hat context-kártyát tartson meg');
assert.equal(rollingWindow[0].id, 'resp_failure', 'a fókuszatom kerüljön a kamera előtti középpontba');
assert.ok(Math.max(...rollingWindow.map((item) => item.virtualX)) - Math.min(...rollingWindow.map((item) => item.virtualX)) >= 320, 'a context-kártyák töltsék ki a gömb látható szélességét');
assert.ok(Math.max(...rollingWindow.map((item) => item.virtualY)) - Math.min(...rollingWindow.map((item) => item.virtualY)) >= 250, 'a context-kártyák töltsék ki a gömb látható magasságát');
assert.match(mapSource, /id: 'globe-rolling-cards'/, 'a rolling fókuszált gömb V2 önálló választható opció legyen');
assert.match(mapSource, /ROLLING_CARD_POOL_SIZE/, 'a rolling gömb korlátos kártyapoolt használjon');
assert.match(mapSource, /function rollingCurvedCardGeometry\(/, 'a rolling nézet saját, ívelt kártyageometriát készítsen');

const forceCardTransform = forceSphereCardTransform(3, 4, 12, 77);
assert.ok(Math.abs(Math.hypot(forceCardTransform.position.x, forceCardTransform.position.y, forceCardTransform.position.z) - 77) < 1e-9, 'a Force-kártya a gömbhéjra legyen vetítve');
assert.ok(Math.abs(Math.hypot(forceCardTransform.normal.x, forceCardTransform.normal.y, forceCardTransform.normal.z) - 1) < 1e-9, 'a Force-kártya felszíni normálja egységvektor legyen');
assert.match(mapSource, /id: '3d-force-globe-cards'/, 'a 3D Force gömbkártya V2 önálló választható opció legyen');
assert.match(mapSource, /nodeThreeObject\(createForceSphereCard\)/, 'a Force gömbkártya V2 a 3d-force-graph saját objektumrétegét használja');

const mixedCenter = projectFocusedMapPointToGlobeCap({ x: 180, y: 280 }, 360, 560);
const mixedOuter = projectFocusedMapPointToGlobeCap({ x: 330, y: 120 }, 360, 560);
assert.deepEqual(mixedCenter, { lat: 0, lng: 0 }, 'a mixed nézet fókuszkártyája a gömb kamera előtti közepére kerüljön');
assert.ok(Math.abs(mixedOuter.lat) > 20 && Math.abs(mixedOuter.lng) > 20, 'a mixed context-kártyák a gömbsapka érdemi részét töltsék ki');
assert.match(mapSource, /id: 'globe-focused-mixed'/, 'a Mixed gömbnézet önálló választható opció legyen');
assert.match(mapSource, /\.pathsData\(paths\)/, 'a Mixed nézet a gömb felszínén futó path-vonalakat használja arcok helyett');

const rollingSlotGeo = rollingSlotToGeo({ lat: 20, lng: 170 }, { yawOffset: 18, pitchOffset: 8 });
assert.equal(rollingSlotGeo.lat, 28, 'a rolling slot pitch eltolása a kamera aktuális szélességéhez adódjon');
assert.ok(rollingSlotGeo.lng < -160, 'a rolling slot longitude-ja átforduljon a dátumvonalon');
const globeDestination = destinationPointOnGlobe(20, 170, 25, 90);
assert.ok(Math.abs(globeDestination.lat - 20) < 3, 'a keleti tangenciális eltolás a helyi fókuszsávban maradjon');
assert.ok(globeDestination.lng < -160, 'a tangenciális Globe-elrendezés a dátumvonalon is stabil maradjon');
const globeFocusedLayout = buildGlobeFocusedCardLayout('resp_failure', { lat: 12, lng: 24 }, knowledgeNodes, knowledgeEdges);
assert.deepEqual(globeFocusedLayout, buildGlobeFocusedCardLayout('resp_failure', { lat: 12, lng: 24 }, knowledgeNodes, knowledgeEdges), 'azonos fókusz és anchor mindig ugyanazt a Globe-koordinátás layoutot adja');
assert.deepEqual(globeFocusedLayout.active[0].geo, { lat: 12, lng: 24 }, 'a fókuszatom megtartja a kiválasztott Globe-ankert');
assert.ok(globeFocusedLayout.active.filter((card) => card.graphDepth === 1).every((card) => card.angularDistance >= 18 && card.angularDistance <= 48), 'a közvetlen kapcsolatok a belső gömbi sávban maradnak');
assert.ok(globeFocusedLayout.active.filter((card) => card.graphDepth === 2).every((card) => card.angularDistance >= 45 && card.angularDistance <= 82), 'a másodlagos kapcsolatok külön külső sávba kerülnek');
assert.ok(globeFocusedLayout.prefetched.every((card) => card.graphDepth === 3), 'a harmadik réteg csak lazy prefetch-adatként készül elő');
assert.match(mapSource, /const ROLLING_ACTIVE_CARD_COUNT = 20/, 'a rolling nézetben a fókusz mellett másodlagos, feltáruló kártyarétegek is legyenek');
assert.match(mapSource, /const ROLLING_PREFETCH_CARD_COUNT = 12/, 'a rolling nézet a horizont mögötti lazy frontierhez külön előtöltött slotokat tartson');
const rollingSource = mapSource.slice(mapSource.indexOf('function createRollingGlobeCard'), mapSource.indexOf('// Az eredeti Arc Links'));
assert.match(rollingSource, /\.objectsData\(rollingGlobeActiveCards\)/, 'a rolling V2 kizárólag az aktív Globe Objects Layer kártyákat adja át');
assert.match(rollingSource, /\.objectThreeObject\(createRollingGlobeCard\)/, 'a rolling V2 valódi Three.js kártyaobjektumokat ad a Globe.GL-nek');
assert.match(rollingSource, /\.objectThreeObject\(createRollingGlobeCard\)/, 'a Globe a valódi Three.js kártyaobjektumot a támogatott Objects Layer API-val kapja meg');
assert.doesNotMatch(rollingSource, /\.objectThreeObjectUpdate\(/, 'a Globe V2 ne hívjon nem létező Globe.gl API-t');
assert.match(rollingSource, /\.arcsData\(rollingGlobeActiveEdges\)/, 'csak az aktív helyi kapcsolatok kerülnek a Globe Arc Layerébe');
assert.match(rollingSource, /buildGlobeFocusedCardLayout\(/, 'a Globe V2 a közös determinisztikus depth- és branch-layoutot alakítja Globe-koordinátává');
assert.match(rollingSource, /scheduleRollingGlobeViewportUpdate\(\)/, 'a Globe zoom/forgatás rAF-es, könnyű viewport-frissítést ütemez');
assert.match(mapSource, /const rollingGlobeFreeCards = \[\]/, 'a Globe V2 korlátos, újrahasznosítható Three.js kártyaobjektum-poolt tart fenn');
assert.match(rollingSource, /function reclaimRollingGlobeObjects\(/, 'a távozó aktív kártyák objektumai visszakerülnek a Globe V2 poolba');
assert.doesNotMatch(rollingSource, /rollingGlobe\.scene\(\)\.add/, 'a Globe V2 nem külön scene-overlay réteget használ');
assert.doesNotMatch(rollingSource, /rollingCardPoolGroup/, 'a Globe V2 kártyái nem független scene-poolban élnek');
assert.doesNotMatch(rollingSource, /bindRollingGlobePointer/, 'a kártyakoppintást a Globe Objects Layer kezeli');
assert.doesNotMatch(rollingSource, /forceGraph|d3Force|forceSimulation|nodePositionUpdate/, 'a Globe V2 nem használ force-alapú gráfmotort');

const forceSphereSlots = buildForceSphereSlotAtoms('diffusion_disorder', 7, knowledgeNodes, knowledgeEdges);
assert.equal(forceSphereSlots.length, 7, 'a 3D Force gömbkártya is mindig hét egyedi, aktív atomot kapjon');
assert.equal(forceSphereSlots[0], 'diffusion_disorder', 'a 3D Force központi slotja a fókuszatomot tartsa');
assert.equal(new Set(forceSphereSlots).size, 7, 'a 3D Force aktív slotjaiban ne ismétlődjön Atom');
assert.match(mapSource, /const FORCE_SPHERE_CARD_POOL_SIZE = FORCE_SPHERE_LAYERED_CARD_COUNT \+ FORCE_SPHERE_PREFETCH_CARD_COUNT/, 'a 3D Force gömbkártyák fix, réteges renderpoolt használjanak');
assert.match(mapSource, /\.cooldownTicks\(1\)/, 'a 3D Force lazy kártyanézet force szimulációja azonnal lehűljön');
const forceSphereCardSource = mapSource.slice(mapSource.indexOf('function forceSphereCameraBasis'), mapSource.indexOf('function syncViewportState'));
assert.match(forceSphereCardSource, /forceSphereCardSlots\.filter\(\(slot\) => slot\.atomId\)/, 'csak aktív Force-kártya slotok kerüljenek a graphData node-listájába');
assert.match(forceSphereCardSource, /slice\(0, 10\)/, 'a Force-kártya részgráfban legfeljebb tíz kapcsolat maradjon');
assert.match(forceSphereCardSource, /new THREE\.CanvasTexture\(canvas\)/, 'a Force-kártya slotjai saját, tartós CanvasTexture-t használjanak');
assert.match(forceSphereCardSource, /texture\.needsUpdate = true/, 'Force-atomcserekor a meglévő textúra frissüljön');
assert.match(forceSphereCardSource, /nodePositionUpdate\(updateForceSphereCardPosition\)/, 'a ForceGraph ne írja felül a slotok gömbpozícióját');
assert.match(forceSphereCardSource, /scheduleForceSphereCardViewport\(\)/, 'a controls változása rAF-es Force viewport-frissítést ütemezzen');
assert.match(forceSphereCardSource, /buildLayeredSphericalFocusLayout\(/, 'a Force V2 ugyanazt a determinisztikus depth- és branch-layoutot használja');
assert.match(forceSphereCardSource, /return forceSphereCardEntryTransform\(\{ yaw: slot\.yaw, pitch: slot\.pitch \}, basis\)/, 'a Force V2 90° mögött is valódi gömbi sin/cos pozíciót használjon');

assert.equal(forceSphereZoomScale(300), 1, 'az alap kamera-távolságon a CSS-gömb eredeti méretű');
assert.ok(forceSphereZoomScale(240) > 1, 'közelebb zoomolva a CSS-gömb is nagyobb lesz');
assert.ok(forceSphereZoomScale(420) < 1, 'kifelé zoomolva a CSS-gömb is kisebb lesz');
const forceSurfaceLink = buildForceSphereSurfaceLinkPoints({ x: 77, y: 0, z: 0 }, { x: 0, y: 0, z: 77 }, 8, 78.4);
assert.equal(forceSurfaceLink.length, 9, 'a 3D Force felszíni link köztes mintapontokat kap');
assert.ok(forceSurfaceLink.every((point) => Math.abs(Math.hypot(point.x, point.y, point.z) - 78.4) < 1e-7), 'a 3D Force link minden mintapontja a gömbhéjon marad');
assert.ok(forceSurfaceLink[4].x > 0 && forceSurfaceLink[4].z > 0, 'a link közepe a gömb ívét követi, nem egyenes húrt rajzol');
const forceCardVisualSource = mapSource.slice(mapSource.indexOf('function syncForceSphereCardVisuals'), mapSource.indexOf('function forceSphereCameraTurnDegrees'));
assert.match(forceCardVisualSource, /syncForceSphereVisualScale\(\)/, 'a kártyás 3D Force nézet a CSS-gömb zoomskáláját is frissíti');
assert.match(forceSphereCardSource, /linkThreeObject\(createForceSphereSurfaceLink\)/, 'a 3D Force gömbkártyák egyedi, felszínkövető linkobjektumot használnak');
assert.match(forceSphereCardSource, /linkPositionUpdate\(updateForceSphereSurfaceLink\)/, 'a felszíni linkek a kártyák pozícióját követve frissülnek');

const forceSphereLayout = forceSphereCardLayout();
assert.equal(forceSphereLayout.length, 7, 'a 3D Force kártyanézetnek hét kanonikus, látható slotja legyen');
assert.deepEqual(forceSphereLayout[0], { yaw: 0, pitch: 0 }, 'a kezdő elrendezés a Morph középső kártyapozíciójával induljon');
assert.ok(forceSphereLayout.every((slot) => !slot.focus), 'a végtelen V2-nak ne legyen kamerához rögzített fókuszkártyája');
assert.ok(Math.max(...forceSphereLayout.map((slot) => slot.yaw)) - Math.min(...forceSphereLayout.map((slot) => slot.yaw)) >= 70, 'a kontextuskártyák a gömb széles részét töltsék ki');
assert.ok(Math.max(...forceSphereLayout.map((slot) => slot.pitch)) - Math.min(...forceSphereLayout.map((slot) => slot.pitch)) >= 50, 'a kontextuskártyák több sorban használják a gömb felszínét');
const rearEntry = forceSphereCardEntrySlot({ x: 1, y: 0 }, 0);
assert.ok(Math.abs(rearEntry.yaw) > 90, 'az új lazy kártya a horizont mögötti, hátoldali belépőhelyen szülessen');
assert.equal(Math.sign(rearEntry.yaw), 1, 'a belépőhely a kamera forgásának jövőbeli oldalára kerüljön, hogy a horizont felé érkezzen');
const layerTwoRight = forceSphereCardLayerSlot({ x: 1, y: 0 }, 2, 1);
const layerThreeRight = forceSphereCardLayerSlot({ x: 1, y: 0 }, 3, 1);
assert.ok(Math.abs(layerTwoRight.yaw) < 90, 'a második réteg még a távoli, de látható gömbsapkán legyen');
assert.ok(Math.abs(layerThreeRight.yaw) > 90, 'a harmadik réteg a horizont mögött maradjon, amíg be nem streamelődik');
assert.notDeepEqual(layerTwoRight, layerThreeRight, 'a Layer 2 és Layer 3 külön, ütközésmentes sávot használjon');
assert.match(forceSphereCardSource, /function forceSphereCardSlotTransform\(/, 'a 3D Force kártyák stabil, teljes tangenciális slot-orientációt használjanak');
assert.match(forceSphereCardSource, /makeBasis\(right, up, normal\)/, 'a 3D Force kártyák ne kapjanak véletlenszerű roll-forgatást');
assert.match(forceSphereCardSource, /function streamForceSphereCardSlots\(/, 'a lazy render egyszerre minden kilépő slotot kezeljen');
assert.match(forceSphereCardSource, /function forceSphereCardEntryTransform\(/, 'a lazy belépők külön, valódi hátoldali gömbpozíciót kapjanak');
assert.match(forceSphereCardSource, /slot\.anchorNormal/, 'a renderpozíció a slothoz tartozzon, ne az Atomhoz vagy a kamera aktuális helyéhez');
assert.match(forceSphereCardSource, /slot\.layer/, 'a V2 slotjai vizuális és navigációs réteget is tároljanak');
assert.match(forceSphereCardSource, /forceSphereCardLayerSlot/, 'a V2 rétegekhez determinisztikus, külön slotkiosztás tartozzon');
assert.match(forceSphereCardSource, /force3dSphereControls\.enableZoom = false/, 'a 3D Force gömbkártyák kamerazoomja rögzített legyen');
assert.doesNotMatch(forceSphereCardSource, /leavingSlot\.yaw\s*=/, 'a lazy render ne írja át a kanonikus slotok yaw pozícióját');
assert.doesNotMatch(forceSphereCardSource, /leavingSlot\.pitch\s*=/, 'a lazy render ne írja át a kanonikus slotok pitch pozícióját');
assert.equal(forceSphereCardCameraDistance(), 196.35, 'a Gömbkártyák v2 rögzített kamerája a közeli, teljes gömbsapkát kitöltő távolság legyen');
assert.match(forceSphereCardSource, /initializeForceSphereCardCamera\(/, 'a Gömbkártyák v2 a 3D Force alapértelmezett távoli kameráját felülírja');
assert.match(forceSphereCardSource, /FORCE_SPHERE_CARD_CAMERA_DISTANCE/, 'az induló és reset kamera ugyanazt a rögzített távolságot használja');

assert.equal(knowledgeNodes.length, 700, 'minden grafikus motor ugyanazt a hétszáz Atomból álló mintagráfot kapja');
assert.ok(knowledgeEdges.length >= 1_000, 'a hétszáz Atomhoz szerteágazó, több közösséget átszelő kapcsolatháló tartozik');
const nodeIds = new Set(knowledgeNodes.map((node) => node.id));
assert.ok(knowledgeEdges.every((edge) => nodeIds.has(edge.source) && nodeIds.has(edge.target)), 'minden bővített kapcsolat létező Atomok között fut');
assert.ok(knowledgeEdges.some((edge) => edge.label === 'közösségi híd'), 'a bővített gráfban közösségeket összekötő keresztkapcsolatok is vannak');
assert.ok(forceSphereNodeValue(12, 12) > forceSphereNodeValue(2, 12), 'a sima 3D Force gömbben a több kapcsolattal rendelkező Atom nagyobb legyen');
assert.ok(forceSphereNodeValue(2, 12) > forceSphereNodeValue(0, 12), 'a kapcsolattal rendelkező Atom legalább az izolált Atomnál nagyobb legyen');
assert.ok(Math.cbrt(forceSphereNodeValue(12, 12)) <= 1.2, 'a 3D Force gömbök legnagyobb sugara az előző skála nagyjából fele legyen');
assert.ok(Math.cbrt(forceSphereNodeValue(12, 12)) / Math.cbrt(forceSphereNodeValue(0, 12)) > 5, 'a nagy és a kicsi gömbök méretkülönbsége legyen erősebb');
assert.match(mapSource, /const degreeById = new Map/, 'a sima 3D Force gömb a látható kapcsolatokból számolja a node fokszámát');
assert.match(mapSource, /const FORCE_SPHERE_NODE_RESOLUTION = 12/, 'a sima 3D Force gömb alacsonyabb felbontású mesh-eket használjon');
assert.match(mapSource, /fx: position\.x, fy: position\.y, fz: position\.z/, 'a sima 3D Force gömb atomjai rögzített gömbhéj-pozíciót kapjanak, ne fusson rájuk force-szimuláció');
assert.match(mapSource, /FORCE_SPHERE_CULLING_STEP_DEGREES/, 'a horizont-culling csak érzékelhető kamerafordulás után frissüljön');

const layeredFocusLayout = buildLayeredSphericalFocusLayout('resp_failure', knowledgeNodes, knowledgeEdges);
const repeatedLayeredFocusLayout = buildLayeredSphericalFocusLayout('resp_failure', knowledgeNodes, knowledgeEdges);
assert.deepEqual(layeredFocusLayout, repeatedLayeredFocusLayout, 'azonos fókuszhoz a gömbi réteg-layout mindig determinisztikus legyen');
assert.equal(layeredFocusLayout[0].id, 'resp_failure', 'a layered layout első eleme mindig a fókuszatom legyen');
assert.equal(layeredFocusLayout[0].depth, 0, 'a fókuszatom külön depth 0 réteget kapjon');
const layeredDepthOne = layeredFocusLayout.filter((item) => item.depth === 1);
const layeredDepthTwo = layeredFocusLayout.filter((item) => item.depth === 2);
const layeredDepthThree = layeredFocusLayout.filter((item) => item.depth === 3);
assert.ok(layeredDepthOne.length >= 4 && layeredDepthOne.length <= 6, 'az első réteg közvetlen, korlátozott számú környezetből álljon');
assert.ok(layeredDepthOne.every((item) => item.angularDistance >= 18 && item.angularDistance <= 48), 'az első réteg a fókusz körüli belső gömbi sávba kerüljön');
assert.ok(layeredDepthTwo.length >= 6, 'a második réteg valódi távolabbi kontextust adjon');
assert.ok(layeredDepthTwo.every((item) => item.angularDistance >= 45 && item.angularDistance <= 82), 'a második réteg külső, de még feltárható gömbi sávba kerüljön');
assert.ok(layeredDepthTwo.every((item) => layeredDepthOne.some((parent) => parent.id === item.parentId)), 'minden másodlagos Atom egy stabil első réteg-ághoz tartozzon');
assert.ok(layeredDepthThree.length >= 6, 'a harmadik réteg lazy frontierként elő legyen készítve');
assert.ok(layeredDepthThree.every((item) => Math.abs(item.yaw) >= 92), 'a harmadik réteg kezdetben a horizont mögötti sávban maradjon');
assert.equal(new Set(layeredFocusLayout.map((item) => `${item.yaw.toFixed(2)}:${item.pitch.toFixed(2)}`)).size, layeredFocusLayout.length, 'a determinisztikus gömbi slotok ne fedjék egymást');
assert.match(mapSource, /function buildLayeredSphericalFocusLayout\(/, 'a két V2 nézet közös, fókuszvezérelt layered spherical layout motort használjon');

const morphClusterAtoms = buildMorphClusterFocusAtoms('do2', knowledgeNodes, knowledgeEdges);
assert.equal(morphClusterAtoms.length, 7, 'a morph cluster fókusza pontosan hét gömb/kártya atomot készítsen elő');
assert.equal(morphClusterAtoms[0], 'do2', 'a morph első slotja a kiválasztott cluster-atom legyen');
assert.equal(new Set(morphClusterAtoms).size, 7, 'a morph-kártyák között ne legyen ismétlődő Atom');
assert.match(mapSource, /id: '3d-force-globe-morph'/, 'a Morph cluster külön választható 3D Force opció legyen');
assert.match(mapSource, /const MORPH_CLUSTER_STATES =/, 'a morph animáció explicit állapotgépet használjon');
assert.match(mapSource, /function focusMorphCluster\(/, 'cluster-koppintás folyamatos fókuszátmenetet indítson');
assert.match(mapSource, /function exitMorphCluster\(/, 'a morph nézet visszalépése vizuális inverz átmenet legyen');
assert.match(mapSource, /nodeThreeObject\(createMorphSphereAtom\)/, 'a Morph cluster a 3d-force-graph saját Three.js atomobjektumait használja');
assert.match(mapSource, /requestAnimationFrame\(runMorphClusterTransition\)/, 'a morph átmenet rAF-en, nem nézetváltással fusson');

const forcePlanetSource = mapSource.slice(mapSource.indexOf('function forceGraphPlanetData'), mapSource.indexOf('// A gömbforgásnál'));
assert.match(mapSource, /id: '3d-force-graph-morph', label: '3D Force · Planet zoom'/, 'a sima 3D Force Graph mellé külön Planet zoom opció kerüljön');
assert.match(mapSource, /const FORCE_GRAPH_PLANET_STATES =/, 'a Planet zoom explicit overview/zoom/handoff állapotgépet használjon');
assert.match(mapSource, /const FORCE_GRAPH_MORPH_NODE_LIMIT = 40/, 'a bolygó-overview legfeljebb negyven gömböt adjon a mobilos 3D motorba');
assert.match(forcePlanetSource, /nodeThreeObject\(createForceGraphPlanetNode\)/, 'a Planet zoom a 3D Force saját Three.js gömbobjektumait használja');
assert.doesNotMatch(forcePlanetSource, /CanvasTexture|PlaneGeometry|cardMaterial/, 'a Planet zoom áttekintése nem tudáskártyákat, csak kis bolygó-gömböket renderel');
assert.match(forcePlanetSource, /function startForceGraphPlanetZoom\(/, 'Gömb-koppintás indítson bolygóba zoomoló átmenetet');
assert.match(forcePlanetSource, /requestAnimationFrame\(runForceGraphPlanetZoom\)/, 'a bolygó-kibomlás rAF-en fusson, ne nézetvágással');
assert.match(forcePlanetSource, /scale = selected \? 1 \+ eased \* 19/, 'a kiválasztott kis gömb a Globe-szerű világgömb méretére nőjön');
assert.match(forcePlanetSource, /--force-planet-map-progress/, 'a bolygó végső kifakulása a fókuszált térkép fehér hátterére fusson rá');
assert.match(forcePlanetSource, /state\.visualization = 'g6-focused-map'/, 'a zoom végén a fehér hátterű G6 Fókuszált térkép vegye át a nézetet');

const structuredFrame = forceSphereStructuredCardFrame({ x: 0, y: 0, z: 1 });
assert.deepEqual(structuredFrame.right, { x: 1, y: 0, z: 0 }, 'a középső Morph-kártya vízszintes tengelye stabil legyen');
assert.deepEqual(structuredFrame.up, { x: 0, y: 1, z: 0 }, 'a középső Morph-kártya a kamera felé nézve egyenesen álljon');
assert.ok(Math.abs(structuredFrame.right.x * structuredFrame.up.x + structuredFrame.right.y * structuredFrame.up.y + structuredFrame.right.z * structuredFrame.up.z) < 1e-9, 'a strukturált Morph-kártya lokális tengelyei merőlegesek legyenek');
assert.match(mapSource, /function forceSphereMorphSlotTransform\(/, 'a Morph külön, stabil kártya-slot transzformot használjon');
assert.match(mapSource, /makeBasis\(right, up, normal\)/, 'a Morph-kártyák teljes tangenciális koordinátarendszert kapjanak, ne csak normál-forgatást');
assert.match(mapSource, /force3dSphereControls\.enableZoom = false/, 'a Morph nézet interaktív zoomja rögzített legyen');

const cardGlobeSource = mapSource.slice(mapSource.indexOf('function renderCardGlobe'), mapSource.indexOf('function drawCardTexture'));
assert.match(cardGlobeSource, /color: '#ffffff'/, 'a Globe tudáskártya kapcsolatainak fehérnek kell lenniük');
assert.match(cardGlobeSource, /\.pathStroke\(\.22\)/, 'a Globe tudáskártya felszíni kapcsolatai a korábbinál vastagabbak legyenek');
assert.match(cardGlobeSource, /cardTier:/, 'a Globe tudáskártyák a fókuszhoz viszonyított háromszintű kártyatípust kapjanak');
assert.match(mapSource, /function knowledgeCardTierPalette\(/, 'a Globe tudáskártya textúrája külön kezelje a három fókuszszintet');

const cardGlobePoints = new Map([
  ['front_a', { id: 'front_a', lat: 0, lng: 0, altitude: .012 }],
  ['front_b', { id: 'front_b', lat: 14, lng: 12, altitude: .012 }],
  ['back', { id: 'back', lat: 0, lng: 180, altitude: .012 }],
]);
const cardGlobeEdges = [
  { source: 'front_a', target: 'front_b', weight: .9 },
  { source: 'front_a', target: 'back', weight: .9 },
];
const visibleCardGlobeArcs = filterCardGlobeArcs(cardGlobeEdges, cardGlobePoints, { lat: 0, lng: 0 });
assert.deepEqual(visibleCardGlobeArcs.map((edge) => `${edge.source}:${edge.target}`), ['front_a:front_b'], 'a kártyagömbön a hátoldali végpontú ívek ne végződjenek vakon');
assert.match(cardGlobeSource, /pathPointAlt\('altitude'\)/, 'a Globe felszíni kapcsolat magassága a kártyák szintjéhez igazodjon');

const surfacePath = buildCardGlobeSurfacePath({ lat: 0, lng: 0 }, { lat: 0, lng: 90 }, 4, .015);
assert.equal(surfacePath.length, 5, 'a gömbfelszíni kapcsolat a két végpont közé sima, köztes mintapontokat rajzol');
assert.deepEqual(surfacePath[0], { lat: 0, lng: 0, altitude: .015 }, 'a felszíni út pontosan az első kártya koordinátáján indul');
assert.deepEqual(surfacePath.at(-1), { lat: 0, lng: 90, altitude: .015 }, 'a felszíni út pontosan a második kártya koordinátáján ér véget');
assert.ok(Math.abs(surfacePath[2].lng - 45) < .001, 'a köztes útvonal a gömb nagy körét követi');
assert.match(cardGlobeSource, /\.pathsData\(paths\)/, 'a Globe tudáskártyák kapcsolatai a Paths Layert használják');
assert.doesNotMatch(cardGlobeSource, /\.arcsData\(/, 'a Globe tudáskártyák kapcsolatai ne Arc Links-ek legyenek');

const nearbyArcAltitude = globeFocusedAirArcAltitude({ lat: 0, lng: 0 }, { lat: 0, lng: 14 });
const distantArcAltitude = globeFocusedAirArcAltitude({ lat: 0, lng: 0 }, { lat: 0, lng: 82 });
assert.ok(distantArcAltitude > nearbyArcAltitude, 'a sima Globe fókuszkártyák távolabbi kapcsolatai magasabb levegőívet kapjanak');
const focusedCardGlobeSource = mapSource.slice(mapSource.indexOf('function renderFocusedCardGlobe'), mapSource.indexOf('function renderFocusedMixedGlobe'));
assert.match(focusedCardGlobeSource, /globeFocusedAirArcAltitude\(start, end/, 'a sima Globe fókuszkártyák a kártyák közötti szögtől számolják az ív magasságát');
assert.match(mapSource, /function separateFocusedGlobeCards\(/, 'a fókuszált Globe kártyái külön ütközéselkerülést használjanak');
assert.match(mapSource, /function buildFocusedGlobeSpread\(/, 'a fókuszált Globe kártyái fókuszváltáskor új, egyenletes gömbi eloszlást kapjanak');
assert.match(focusedCardGlobeSource, /buildFocusedGlobeSpread\(subgraph\.nodes, focusId, focusAnchor\)/, 'a releváns kártyák eloszlása az aktuális fókuszhoz igazodjon');
assert.match(focusedCardGlobeSource, /const previousFocusPoint = focusedGlobeNodeCache\.get\(focusId\)/, 'a kamera a tapped kártya előző aktuális helyére forduljon');
assert.match(focusedCardGlobeSource, /const focusPosition = focusAnchor/, 'a fókuszba forgatás célja az aktuális kártyapozíció legyen');
assert.match(mapSource, /focusedGlobe\.globeMaterial\(new THREE\.MeshPhongMaterial/, 'a sima fókuszált Globe felülete fény-árnyék anyagot kapjon');
assert.match(mapSource, /fill="#7546bd"/, 'a bolygó egyszínű alappal kapja a kamera-relatív fényelést');
assert.match(mapSource, /focusedGlobe\.lights\(\[ambientLight, keyLight\]\)/, 'a fókuszált Globe kamera-relatív főfényt használjon');
assert.match(mapSource, /cameraRelativeOffset = new THREE\.Vector3\(1\.5, \.25, 2\.2\)/, 'a főfény erősen jobb oldali, kamera felőli irányból érkezzen');
assert.match(mapSource, /new THREE\.DirectionalLight\(0xf0eaff, 3\.0\)/, 'a jobb oldali főfény legyen erősebb');
assert.doesNotMatch(mapSource, /focusedGlobeGlowMesh = new THREE\.Mesh\(/, 'a fókuszált Globe ne kapjon külön halo gömböt');
assert.match(focusedCardGlobeSource, /separateFocusedGlobeCards\(/, 'az ütközéselkerülés ne írja át a fókuszpont kamerakoordinátáját');
assert.match(focusedCardGlobeSource, /startAltitude: \(start\.altitude \?\? \.025\) \+ \.028/, 'a fókusz-ív a kártya légrétegéből induljon');
assert.match(focusedCardGlobeSource, /\.arcStartAltitude\('startAltitude'\)/, 'a fókusz-ív kezdőpontja ne a gömb felszínén legyen');
assert.match(focusedCardGlobeSource, /\.arcEndAltitude\('endAltitude'\)/, 'a fókusz-ív végpontja ne a gömb felszínén legyen');
assert.match(focusedCardGlobeSource, /color: '#C9C4FF'/, 'a sima fókuszált Globe ívei halvány lilás-kékek legyenek');
assert.match(focusedCardGlobeSource, /\.arcStroke\(\.16\)/, 'a sima fókuszált Globe ívei maradjanak finom vonalvastagságúak');
assert.match(mapSource, /\.backgroundColor\('#0B0A17'\)/, 'a sima fókuszált Globe háttere deep-space violet legyen');
assert.match(mapSource, /point\.isFocused \|\| point\.id === state\.selectedId/, 'a kijelölt Globe-kártya külön kiemelési állapotot kapjon');
assert.match(mapSource, /top: '#ECE7FF', bottom: '#D9D0FA'/, 'a kijelölt Globe-kártya világos levendula legyen');
assert.match(mapSource, /\.onZoom\(\(\) => \{\}\)/, 'zoom közben ne fusson új kártya-layout');
assert.match(rollingSource, /\.arcAltitude\(\.015\)/, 'a Globe fókuszált kártyák v2 ívbeállítása ettől a javítástól változatlan maradjon');

console.log(`focused G6 map OK (${subgraph.nodes.length} nodes, ${subgraph.edges.length} edges)`);
