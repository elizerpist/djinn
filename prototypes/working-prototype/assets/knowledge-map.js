/*
 * Djinn knowledge map prototype
 * -----------------------------
 * The two datasets below are deliberately independent from the renderer. In the
 * Flutter/ObjectBox app they can be replaced by Note/Section records and their
 * Navigation Graph edges without changing the interaction layer.
 */

import * as THREE from './vendor/three.module.min.js?rev=65';

export const knowledgeNodes = [
  { id: 'resp_failure', title: 'Légzési elégtelenség', type: 'topic', subtitle: 'Központi fogalom', noteId: 'note_001', sectionId: 'section_001', importance: 1, validated: true, sourceType: 'note', sourceName: 'Légzési elégtelenség jegyzet' },
  { id: 'hypoxemic_failure', title: 'Hipoxémiás légzési elégtelenség', type: 'condition', subtitle: 'I. típusú elégtelenség', noteId: 'note_002', sectionId: 'section_010', importance: .94, validated: true },
  { id: 'hypercapnic_failure', title: 'Hiperkapniás légzési elégtelenség', type: 'condition', subtitle: 'II. típusú elégtelenség', noteId: 'note_002', sectionId: 'section_011', importance: .92, validated: true },
  { id: 'do2', title: 'DO2', type: 'measurement', subtitle: 'Oxigénkínálat', noteId: 'note_003', sectionId: 'section_020', importance: .93, validated: true },
  { id: 'vo2', title: 'VO2', type: 'measurement', subtitle: 'Oxigénigény', noteId: 'note_003', sectionId: 'section_021', importance: .79, validated: true },
  { id: 'oxygen_delivery', title: 'Oxigénkínálat', type: 'concept', subtitle: 'A szervezethez jutó oxigén', noteId: 'note_003', sectionId: 'section_022', importance: .9, validated: true },
  { id: 'oxygen_demand', title: 'Oxigénigény', type: 'concept', subtitle: 'Sejtszintű szükséglet', noteId: 'note_003', sectionId: 'section_023', importance: .81, validated: true },
  { id: 'hemoglobin', title: 'Hemoglobin', type: 'measurement', subtitle: 'Oxigénszállító fehérje', noteId: 'note_004', sectionId: 'section_030', importance: .82, validated: true },
  { id: 'sao2', title: 'SaO2', type: 'measurement', subtitle: 'Artériás szaturáció', noteId: 'note_004', sectionId: 'section_031', importance: .77, validated: true },
  { id: 'pao2', title: 'PaO2', type: 'measurement', subtitle: 'Artériás oxigénnyomás', noteId: 'note_005', sectionId: 'section_040', importance: .9, validated: true, sourceType: 'pdf', sourceName: 'Artériás vérgáz gyorsreferencia.pdf', pageNumber: 3 },
  { id: 'paco2', title: 'PaCO2', type: 'measurement', subtitle: 'Artériás szén-dioxid nyomás', noteId: 'note_005', sectionId: 'section_041', importance: .9, validated: true, sourceType: 'pdf', sourceName: 'Artériás vérgáz gyorsreferencia.pdf', pageNumber: 3 },
  { id: 'cardiac_output', title: 'Cardiac output', type: 'measurement', subtitle: 'Perctérfogat', noteId: 'note_004', sectionId: 'section_032', importance: .74, validated: false },
  { id: 'ards', title: 'ARDS', type: 'condition', subtitle: 'Akut respiratorikus distressz', noteId: 'note_006', sectionId: 'section_050', importance: .95, validated: true, sourceType: 'pdf', sourceName: 'ARDS Berlin kritériumok.pdf', pageNumber: 1 },
  { id: 'copd', title: 'COPD', type: 'condition', subtitle: 'Krónikus obstruktív tüdőbetegség', noteId: 'note_007', sectionId: 'section_060', importance: .86, validated: true },
  { id: 'pneumonia', title: 'Pneumonia', type: 'condition', subtitle: 'Tüdőgyulladás', noteId: 'note_008', sectionId: 'section_070', importance: .84, validated: true },
  { id: 'pulmonary_edema', title: 'Tüdőödéma', type: 'condition', subtitle: 'Alveoláris folyadékfelszaporodás', noteId: 'note_009', sectionId: 'section_080', importance: .79, validated: true },
  { id: 'niv', title: 'NIV', type: 'treatment', subtitle: 'Non-invazív lélegeztetés', noteId: 'note_010', sectionId: 'section_090', importance: .83, validated: true },
  { id: 'intubation', title: 'Intubáció', type: 'procedure', subtitle: 'Légútbiztosítás', noteId: 'note_011', sectionId: 'section_100', importance: .88, validated: true },
  { id: 'mechanical_ventilation', title: 'Mechanikus lélegeztetés', type: 'treatment', subtitle: 'Invazív ventiláció', noteId: 'note_011', sectionId: 'section_101', importance: .87, validated: true },
  { id: 'oxygen_therapy', title: 'Oxigénterápia', type: 'treatment', subtitle: 'Oxigénpótlás', noteId: 'note_012', sectionId: 'section_110', importance: .89, validated: true },
  { id: 'peep', title: 'PEEP', type: 'treatment', subtitle: 'Kilégzésvégi pozitív nyomás', noteId: 'note_011', sectionId: 'section_102', importance: .85, validated: true },
  { id: 'vq_mismatch', title: 'V/Q aránytalanság', type: 'concept', subtitle: 'Ventiláció–perfúzió eltérés', noteId: 'note_013', sectionId: 'section_120', importance: .82, validated: true },
  { id: 'shunt', title: 'Shunt', type: 'concept', subtitle: 'Jobb-bal sönt', noteId: 'note_013', sectionId: 'section_121', importance: .78, validated: true },
  { id: 'diffusion_disorder', title: 'Diffúziós zavar', type: 'concept', subtitle: 'Gázcsere-károsodás', noteId: 'note_013', sectionId: 'section_122', importance: .7, validated: false },
  { id: 'lactate', title: 'Laktát', type: 'measurement', subtitle: 'Szöveti hipoxia jelzője', noteId: 'note_014', sectionId: 'section_130', importance: .71, validated: true },
  { id: 'acid_base', title: 'Sav-bázis egyensúly', type: 'concept', subtitle: 'pH és kompenzáció', noteId: 'note_005', sectionId: 'section_042', importance: .75, validated: true },
  { id: 'abg', title: 'Artériás vérgáz', type: 'source', subtitle: 'Gázcsere diagnosztika', noteId: 'note_005', sectionId: 'section_043', importance: .86, validated: true, sourceType: 'pdf', sourceName: 'Artériás vérgáz gyorsreferencia.pdf', pageNumber: 2 },
  { id: 'tachypnea', title: 'Tachypnoe', type: 'symptom', subtitle: 'Szapora légzés', noteId: 'note_015', sectionId: 'section_140', importance: .67, validated: true },
  { id: 'cyanosis', title: 'Cianózis', type: 'symptom', subtitle: 'Kékes elszíneződés', noteId: 'note_015', sectionId: 'section_141', importance: .64, validated: true },
  { id: 'altered_consciousness', title: 'Tudatzavar', type: 'symptom', subtitle: 'Neurológiai figyelmeztető jel', noteId: 'note_015', sectionId: 'section_142', importance: .76, validated: true },
  { id: 'hypoxemia', title: 'Hipoxémia', type: 'condition', subtitle: 'Alacsony artériás oxigén', noteId: 'note_016', sectionId: 'section_150', importance: .84, validated: true },
  { id: 'oxygenation', title: 'Oxigenizáció', type: 'concept', subtitle: 'Oxigénfelvétel javítása', noteId: 'note_012', sectionId: 'section_111', importance: .8, validated: true },
];

export const knowledgeEdges = [
  { source: 'resp_failure', target: 'hypoxemic_failure', weight: .96, bidirectional: true, label: 'típus' },
  { source: 'resp_failure', target: 'hypercapnic_failure', weight: .94, bidirectional: true, label: 'típus' },
  { source: 'resp_failure', target: 'ards', weight: .9, bidirectional: true, label: 'kapcsolódó állapot' },
  { source: 'resp_failure', target: 'copd', weight: .88, bidirectional: true, label: 'kapcsolódó állapot' },
  { source: 'resp_failure', target: 'pneumonia', weight: .87, bidirectional: true, label: 'kapcsolódó állapot' },
  { source: 'resp_failure', target: 'pulmonary_edema', weight: .8, bidirectional: true, label: 'kapcsolódó állapot' },
  { source: 'resp_failure', target: 'do2', weight: .85, bidirectional: true, label: 'oxigénegyensúly' },
  { source: 'resp_failure', target: 'abg', weight: .84, bidirectional: true, label: 'értékelés' },
  { source: 'resp_failure', target: 'tachypnea', weight: .72, bidirectional: true, label: 'tünet' },
  { source: 'resp_failure', target: 'oxygen_therapy', weight: .82, bidirectional: true, label: 'ellátás' },
  { source: 'do2', target: 'oxygen_delivery', weight: .98, bidirectional: true, label: 'azonos fogalom' },
  { source: 'do2', target: 'hemoglobin', weight: .93, bidirectional: true, label: 'összetevő' },
  { source: 'do2', target: 'sao2', weight: .91, bidirectional: true, label: 'összetevő' },
  { source: 'do2', target: 'cardiac_output', weight: .9, bidirectional: true, label: 'összetevő' },
  { source: 'do2', target: 'vo2', weight: .86, bidirectional: true, label: 'egyensúly' },
  { source: 'do2', target: 'lactate', weight: .79, bidirectional: true, label: 'perfúzió' },
  { source: 'oxygen_delivery', target: 'oxygen_demand', weight: .84, bidirectional: true, label: 'egyensúly' },
  { source: 'oxygen_delivery', target: 'oxygenation', weight: .86, bidirectional: true, label: 'gázcsere' },
  { source: 'oxygen_delivery', target: 'pao2', weight: .78, bidirectional: true, label: 'mérés' },
  { source: 'vo2', target: 'oxygen_demand', weight: .96, bidirectional: true, label: 'azonos fogalom' },
  { source: 'vo2', target: 'lactate', weight: .82, bidirectional: true, label: 'metabolizmus' },
  { source: 'hemoglobin', target: 'sao2', weight: .87, bidirectional: true, label: 'oxigénszállítás' },
  { source: 'hemoglobin', target: 'cardiac_output', weight: .72, bidirectional: true, label: 'DO2' },
  { source: 'sao2', target: 'pao2', weight: .92, bidirectional: true, label: 'oxigenizáció' },
  { source: 'pao2', target: 'abg', weight: .96, bidirectional: true, label: 'mérés' },
  { source: 'pao2', target: 'oxygen_therapy', weight: .83, bidirectional: true, label: 'kezelés' },
  { source: 'pao2', target: 'hypoxemia', weight: .94, bidirectional: true, label: 'értékelés' },
  { source: 'paco2', target: 'acid_base', weight: .95, bidirectional: true, label: 'kompenzáció' },
  { source: 'paco2', target: 'abg', weight: .96, bidirectional: true, label: 'mérés' },
  { source: 'paco2', target: 'altered_consciousness', weight: .83, bidirectional: true, label: 'tünet' },
  { source: 'paco2', target: 'copd', weight: .91, bidirectional: true, label: 'hiperkapnia' },
  { source: 'paco2', target: 'hypercapnic_failure', weight: .92, bidirectional: true, label: 'típus' },
  { source: 'ards', target: 'shunt', weight: .94, bidirectional: true, label: 'mechanizmus' },
  { source: 'ards', target: 'peep', weight: .91, bidirectional: true, label: 'kezelés' },
  { source: 'ards', target: 'mechanical_ventilation', weight: .9, bidirectional: true, label: 'ellátás' },
  { source: 'ards', target: 'pao2', weight: .88, bidirectional: true, label: 'oxigenizáció' },
  { source: 'ards', target: 'vq_mismatch', weight: .85, bidirectional: true, label: 'mechanizmus' },
  { source: 'ards', target: 'pneumonia', weight: .76, bidirectional: true, label: 'keresztkapcsolat' },
  { source: 'copd', target: 'niv', weight: .92, bidirectional: true, label: 'kezelés' },
  { source: 'copd', target: 'hypercapnic_failure', weight: .9, bidirectional: true, label: 'típus' },
  { source: 'copd', target: 'abg', weight: .82, bidirectional: true, label: 'értékelés' },
  { source: 'copd', target: 'tachypnea', weight: .7, bidirectional: true, label: 'tünet' },
  { source: 'pneumonia', target: 'hypoxemia', weight: .91, bidirectional: true, label: 'állapot' },
  { source: 'pneumonia', target: 'vq_mismatch', weight: .9, bidirectional: true, label: 'mechanizmus' },
  { source: 'pneumonia', target: 'oxygen_therapy', weight: .82, bidirectional: true, label: 'ellátás' },
  { source: 'pneumonia', target: 'ards', weight: .77, bidirectional: true, label: 'súlyosbodás' },
  { source: 'pneumonia', target: 'cyanosis', weight: .64, bidirectional: true, label: 'tünet' },
  { source: 'pulmonary_edema', target: 'peep', weight: .86, bidirectional: true, label: 'kezelés' },
  { source: 'pulmonary_edema', target: 'oxygenation', weight: .81, bidirectional: true, label: 'gázcsere' },
  { source: 'pulmonary_edema', target: 'vq_mismatch', weight: .73, bidirectional: true, label: 'mechanizmus' },
  { source: 'niv', target: 'hypercapnic_failure', weight: .88, bidirectional: true, label: 'ellátás' },
  { source: 'niv', target: 'oxygen_therapy', weight: .72, bidirectional: true, label: 'támogatás' },
  { source: 'intubation', target: 'mechanical_ventilation', weight: .98, bidirectional: true, label: 'eljárás' },
  { source: 'intubation', target: 'peep', weight: .84, bidirectional: true, label: 'beállítás' },
  { source: 'intubation', target: 'altered_consciousness', weight: .8, bidirectional: true, label: 'indikáció' },
  { source: 'mechanical_ventilation', target: 'peep', weight: .96, bidirectional: true, label: 'beállítás' },
  { source: 'mechanical_ventilation', target: 'oxygenation', weight: .87, bidirectional: true, label: 'cél' },
  { source: 'peep', target: 'oxygenation', weight: .9, bidirectional: true, label: 'hatás' },
  { source: 'peep', target: 'shunt', weight: .75, bidirectional: true, label: 'toborzás' },
  { source: 'vq_mismatch', target: 'shunt', weight: .82, bidirectional: true, label: 'gázcsere' },
  { source: 'vq_mismatch', target: 'diffusion_disorder', weight: .77, bidirectional: true, label: 'mechanizmus' },
  { source: 'hypoxemic_failure', target: 'hypoxemia', weight: .97, bidirectional: true, label: 'mérés' },
  { source: 'hypoxemic_failure', target: 'oxygen_therapy', weight: .87, bidirectional: true, label: 'ellátás' },
  { source: 'hypoxemic_failure', target: 'cyanosis', weight: .74, bidirectional: true, label: 'tünet' },
  { source: 'hypercapnic_failure', target: 'acid_base', weight: .78, bidirectional: true, label: 'kompenzáció' },
  { source: 'tachypnea', target: 'hypoxemia', weight: .68, bidirectional: true, label: 'tünet' },
  { source: 'cyanosis', target: 'sao2', weight: .63, bidirectional: true, label: 'jel' },
];

const TYPE_META = {
  topic: { label: 'Téma', icon: '✦' }, concept: { label: 'Fogalom', icon: '◇' }, measurement: { label: 'Mérés', icon: '◌' },
  condition: { label: 'Állapot', icon: '◒' }, treatment: { label: 'Kezelés', icon: '＋' }, procedure: { label: 'Eljárás', icon: '↗' },
  source: { label: 'Forrás', icon: '▧' }, symptom: { label: 'Tünet', icon: '◔' },
};

const FILTER_TYPES = ['concept', 'condition', 'measurement', 'treatment', 'procedure', 'symptom'];
const MIN_ZOOM = .15;
const MAX_ZOOM = 4;
// A 3D atomok gömbhéjon helyezkednek el. A hátsó féltekét nem egy poligonos
// takarógömb, hanem a kamera irányából számított horizont-levágás rejti el.
const FORCE_SPHERE_SHELL_RADIUS = 77;
const FORCE_SPHERE_NODE_REL_SIZE = 4;
const FORCE_SPHERE_HORIZON = -.22;
const FORCE_SPHERE_SCALE_START = .42;
const FORCE_SPHERE_MIN_SCALE = .24;
const FORCE_SPHERE_MAX_SCALE = 1.2;
const FORCE_SPHERE_BASE_CAMERA_DISTANCE = 300;
// A G6 v5 helyben tárolt csomagjának mind a 19 2D layoutja és három térbeli nézet.
// A G6 nézetek a könyvtár alapértelmezett node- és élstílusait használják; a Djinn
// felület csak a vásznon kívüli vezérlőket adja hozzá.
const VISUALIZATIONS = [
  { id: 'g6-focused-map', label: 'G6 · Fókuszált térkép', group: 'Navigáció', icon: '⌖', focusedG6: true },
  { id: 'force', label: 'Force', group: 'Erő alapú hálók', icon: '✦' },
  { id: 'd3-force', label: 'D3 Force', group: 'Erő alapú hálók', icon: '◌' },
  { id: 'd3-force-3d', label: 'D3 Force 3D', group: 'Térbeli', icon: '◈', threeD: true },
  { id: '3d-force-graph', label: '3D Force Graph', group: 'Térbeli', icon: '◉', force3d: true },
  { id: '3d-force-globe', label: '3D Force · Gömbforgás', group: 'Térbeli', icon: '◍', force3d: true, forceSphere: true },
  { id: 'globe-arc-links', label: 'Globe · Arc Links', group: 'Térbeli', icon: '◐', globe: true },
  { id: 'globe-knowledge-cards', label: 'Globe · Tudáskártyák', group: 'Térbeli', icon: '▤', cardGlobe: true },
  { id: 'globe-focused-cards', label: 'Globe · Fókuszált kártyák', group: 'Térbeli', icon: '◉', focusedCardGlobe: true },
  { id: 'globe-static-atoms', label: 'Globe · Árnyék nélküli forgás', group: 'Térbeli', icon: '◌', staticAtomGlobe: true },
  { id: 'cytoscape-cose', label: 'Cytoscape · COSE', group: 'Cytoscape', icon: '⌘', cytoscape: true },
  { id: 'force-atlas2', label: 'ForceAtlas2', group: 'Erő alapú hálók', icon: '✺' },
  { id: 'fruchterman', label: 'Fruchterman', group: 'Erő alapú hálók', icon: '✳' },
  { id: 'mds', label: 'MDS', group: 'Erő alapú hálók', icon: '⌁' },
  { id: 'circular', label: 'Circular', group: 'Kör és tér', icon: '○' },
  { id: 'concentric', label: 'Concentric', group: 'Kör és tér', icon: '◎' },
  { id: 'radial', label: 'Radial', group: 'Kör és tér', icon: '◉' },
  { id: 'grid', label: 'Grid', group: 'Kör és tér', icon: '▦' },
  { id: 'random', label: 'Random', group: 'Kör és tér', icon: '⌘' },
  { id: 'snake', label: 'Snake', group: 'Kör és tér', icon: '〰' },
  { id: 'antv-dagre', label: 'AntV Dagre', group: 'Irányított gráfok', icon: '⇣' },
  { id: 'dagre', label: 'Dagre', group: 'Irányított gráfok', icon: '⇢' },
  { id: 'combo-combined', label: 'Combo Combined', group: 'Csoportosított', icon: '◫' },
  { id: 'compact-box', label: 'Compact Box', group: 'Fa elrendezések', icon: '┬', tree: true },
  { id: 'dendrogram', label: 'Dendrogram', group: 'Fa elrendezések', icon: '┤', tree: true },
  { id: 'fishbone', label: 'Fishbone', group: 'Fa elrendezések', icon: '≋', tree: true },
  { id: 'mindmap', label: 'Mindmap', group: 'Fa elrendezések', icon: '☍', tree: true },
  { id: 'indented', label: 'Indented', group: 'Fa elrendezések', icon: '≡', tree: true },
];
const VISUALIZATION_BY_ID = new Map(VISUALIZATIONS.map((item) => [item.id, item]));
const TREE_LAYOUTS = new Set(VISUALIZATIONS.filter((item) => item.tree).map((item) => item.id));
const STORAGE_KEY = 'djinn-knowledge-map-state-v1';
const FAVORITES_KEY = 'djinn-knowledge-map-node-favorites-v1';
const THEME_FAVORITE_KEY = 'djinn-knowledge-map-theme-favorite-v1';

const nodeById = new Map(knowledgeNodes.map((node) => [node.id, node]));
const neighborsById = new Map(knowledgeNodes.map((node) => [node.id, []]));
knowledgeEdges.forEach((edge) => {
  neighborsById.get(edge.source)?.push({ id: edge.target, edge });
  if (edge.bidirectional !== false) neighborsById.get(edge.target)?.push({ id: edge.source, edge });
});
neighborsById.forEach((items) => items.sort((a, b) => b.edge.weight - a.edge.weight));

// A síkbeli Google Maps-szerű nézet nem a teljes gráfot adja a G6-nak. A
// gráfadat végig teljes marad, de a renderer egy fókusz + kontextus ablakot
// kap: 1 központi Atom, legfeljebb 8 közvetlen és legfeljebb 15 másodlagos
// kapcsolat. A függvény tiszta marad, így később ObjectBox-lekérdezéssel is
// ugyanígy helyettesíthető.
export function buildFocusedG6Subgraph(focusId, nodes = knowledgeNodes, edges = knowledgeEdges, options = {}) {
  const nodeMap = new Map(nodes.map((node) => [node.id, node]));
  const resolvedFocusId = nodeMap.has(focusId) ? focusId : nodes[0]?.id;
  const includeNode = options.includeNode || (() => true);
  const firstRingLimit = options.firstRingLimit ?? 6;
  const secondRingPerNode = options.secondRingPerNode ?? 1;
  const maxNodes = options.maxNodes ?? 12;
  if (!resolvedFocusId) return { focusId: undefined, nodeIds: new Set(), nodes: [], edges: [] };

  const eligibleIds = new Set(nodes.filter(includeNode).map((node) => node.id));
  eligibleIds.add(resolvedFocusId);
  const adjacency = new Map([...eligibleIds].map((id) => [id, []]));
  edges.forEach((edge) => {
    if (!eligibleIds.has(edge.source) || !eligibleIds.has(edge.target)) return;
    adjacency.get(edge.source)?.push({ id: edge.target, edge });
    if (edge.bidirectional !== false) adjacency.get(edge.target)?.push({ id: edge.source, edge });
  });
  adjacency.forEach((items) => items.sort((a, b) => b.edge.weight - a.edge.weight));

  const nodeIds = new Set([resolvedFocusId]);
  const details = new Map([[resolvedFocusId, { depth: 0, rank: 0, parentId: undefined }]]);
  const firstRing = (adjacency.get(resolvedFocusId) || []).slice(0, firstRingLimit);
  firstRing.forEach((item, rank) => {
    nodeIds.add(item.id);
    details.set(item.id, { depth: 1, rank, parentId: resolvedFocusId });
  });

  for (const [parentIndex, first] of firstRing.entries()) {
    if (nodeIds.size >= maxNodes) break;
    const secondRing = (adjacency.get(first.id) || [])
      .filter((item) => !nodeIds.has(item.id))
      .slice(0, secondRingPerNode);
    secondRing.forEach((item, rank) => {
      if (nodeIds.size >= maxNodes) return;
      nodeIds.add(item.id);
      details.set(item.id, { depth: 2, rank, parentId: first.id, parentIndex });
    });
  }

  const subgraphNodes = [...nodeIds].map((id) => {
    const detail = details.get(id);
    return { ...nodeMap.get(id), focusDepth: detail.depth, focusRank: detail.rank, focusParentId: detail.parentId, focusParentIndex: detail.parentIndex };
  });
  const subgraphEdges = edges.filter((edge) => nodeIds.has(edge.source) && nodeIds.has(edge.target));
  return { focusId: resolvedFocusId, nodeIds, nodes: subgraphNodes, edges: subgraphEdges };
}

const FOCUSED_G6_CARD_SIZES = {
  0: [124, 62],
  1: [96, 48],
  2: [78, 38],
};

function focusedG6CardSize(level) {
  return FOCUSED_G6_CARD_SIZES[level] || FOCUSED_G6_CARD_SIZES[2];
}

function focusedG6CardsOverlap(first, second, spacing = 10) {
  const [firstWidth, firstHeight] = focusedG6CardSize(first.level);
  const [secondWidth, secondHeight] = focusedG6CardSize(second.level);
  return Math.abs(first.x - second.x) < (firstWidth + secondWidth) / 2 + spacing
    && Math.abs(first.y - second.y) < (firstHeight + secondHeight) / 2 + spacing;
}

function focusedG6CardFitsViewport(position, width, height, spacing = 10) {
  const [cardWidth, cardHeight] = focusedG6CardSize(position.level);
  return position.x >= cardWidth / 2 + spacing
    && position.x <= width - cardWidth / 2 - spacing
    && position.y >= cardHeight / 2 + spacing
    && position.y <= height - cardHeight / 2 - spacing;
}

function focusedG6PlacementCandidates(angle, level, width, height) {
  const [cardWidth, cardHeight] = focusedG6CardSize(level);
  const baseRadiusX = level === 1
    ? Math.min(126, width / 2 - cardWidth / 2 - 10)
    : Math.min(132, width / 2 - cardWidth / 2 - 10);
  const baseRadiusY = level === 1
    ? Math.min(180, height / 2 - cardHeight / 2 - 14)
    : Math.min(244, height / 2 - cardHeight / 2 - 10);
  const angleOffsets = [0, .18, -.18, .36, -.36, .55, -.55, .75, -.75, 1, -1, 1.25, -1.25, 1.5, -1.5, Math.PI];
  const radiusMultipliers = [1, .93, .86, 1.08];
  return radiusMultipliers.flatMap((multiplier) => angleOffsets.map((offset) => ({
    x: width / 2 + Math.cos(angle + offset) * baseRadiusX * multiplier,
    y: height / 2 + Math.sin(angle + offset) * baseRadiusY * multiplier,
    level,
  })));
}

// Stabil radiális térképkoordináták. A fókusz mindig középen van; ugyanahhoz
// a fókuszhoz és lokális részgráfhoz ugyanaz a kártya-elrendezés tér vissza.
export function focusedG6Positions(nodes, focusId, width, height) {
  const positions = new Map();
  const center = { x: width / 2, y: height / 2, level: 0 };
  const placed = [center];
  positions.set(focusId, center);
  const orderedByLevel = [
    nodes.filter((node) => node.focusDepth === 1).sort((a, b) => a.focusRank - b.focusRank || a.id.localeCompare(b.id)),
    nodes.filter((node) => node.focusDepth === 2).sort((a, b) => a.focusParentIndex - b.focusParentIndex || a.focusRank - b.focusRank || a.id.localeCompare(b.id)),
  ];

  orderedByLevel.forEach((levelNodes, groupIndex) => {
    const level = groupIndex + 1;
    levelNodes.forEach((node, index) => {
      // Az eltolás miatt első körben sem kerül kártya pontosan a fókusz bal,
      // jobb, felső vagy alsó tengelyére. Ez megszünteti a centrum-ütközést.
      const preferredAngle = (Math.PI * 2 * (index + .5) / Math.max(levelNodes.length, 1)) - Math.PI / 2;
      const candidate = focusedG6PlacementCandidates(preferredAngle, level, width, height)
        .find((position) => focusedG6CardFitsViewport(position, width, height) && placed.every((other) => !focusedG6CardsOverlap(position, other)));
      // A részgráf 12 elemre korlátozott, ezért a determinisztikus jelöltlista
      // minden támogatott mobil viewportban talál szabad helyet. A fallback a
      // világos hibahatár: soha nem tolja rá a kártyát egy meglévőre.
      if (!candidate) return;
      positions.set(node.id, candidate);
      placed.push(candidate);
    });
  });
  return positions;
}

// Tartós, teljes-gráf szintű gömbi koordináták. A fókuszált nézet csak a
// renderablakot cseréli, az Atomok földrajzi helye soha nem rendeződik újra.
const PERSISTENT_GLOBE_COORDINATES = new Map();
{
  const ordered = [...knowledgeNodes].sort((a, b) => a.id.localeCompare(b.id));
  const goldenAngle = Math.PI * (3 - Math.sqrt(5));
  ordered.forEach((node, index) => {
    const progress = (index + .5) / ordered.length;
    const lat = Math.asin(1 - 2 * progress) * 180 / Math.PI;
    const lng = ((goldenAngle * index * 180 / Math.PI + 540) % 360) - 180;
    PERSISTENT_GLOBE_COORDINATES.set(node.id, { lat, lng });
  });
}

function safeRead(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; }
}

function safeWrite(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* Offline prototype still works without storage. */ }
}

function hash(value) {
  return [...value].reduce((total, character) => ((total << 5) - total) + character.charCodeAt(0) | 0, 0);
}

function clamp(value, min, max) { return Math.min(max, Math.max(min, value)); }

function pointFor(id, index, total, level, parentIndex = 0) {
  const seed = Math.abs(hash(id));
  const center = { x: 180, y: 252 };
  if (level === 'center') return center;
  if (level === 'primary') {
    const angle = (Math.PI * 2 * index / Math.max(total, 1)) - Math.PI / 2 + ((seed % 17) - 8) * .014;
    const radiusX = 120 + (seed % 14);
    const radiusY = 102 + (seed % 12);
    return { x: center.x + Math.cos(angle) * radiusX, y: center.y + Math.sin(angle) * radiusY };
  }
  if (level === 'secondary') {
    const angle = (Math.PI * 2 * index / Math.max(total, 1)) + parentIndex * .71 + ((seed % 19) * .03);
    const radius = 74 + (seed % 20);
    return { x: center.x + Math.cos(angle) * radius + (index % 2 ? 82 : -82), y: center.y + Math.sin(angle) * radius + (index % 3 ? 58 : -58) };
  }
  return { x: 22 + (seed % 315), y: 26 + (Math.abs(hash(`${id}-world`)) % 405) };
}

function hasPathEdge(a, b, history) {
  return history.some((item, index) => index > 0 && ((history[index - 1] === a && item === b) || (history[index - 1] === b && item === a)));
}

export function initKnowledgeMap(root, helpers = {}) {
  const screen = root.querySelector('.knowledge-map-screen');
  if (!screen) return () => {};

  const mapContainer = screen.querySelector('[data-map-g6]');
  const force3dContainer = screen.querySelector('[data-map-force-3d]');
  const force3dSphereContainer = screen.querySelector('[data-map-force-3d-sphere]');
  const globeContainer = screen.querySelector('[data-map-globe]');
  let cardGlobeContainer = screen.querySelector('[data-map-globe-cards]');
  let focusedGlobeContainer = screen.querySelector('[data-map-globe-focused-cards]');
  const staticAtomGlobeContainer = screen.querySelector('[data-map-globe-static]');
  const cytoscapeContainer = screen.querySelector('[data-map-cytoscape]');
  const mapCanvas = screen.querySelector('.map-canvas-wrap');
  const layer = screen.querySelector('[data-map-layer]');
  const empty = screen.querySelector('[data-map-empty]');
  const breadcrumb = screen.querySelector('[data-map-breadcrumb]');
  const search = screen.querySelector('[data-map-search]');
  const searchResults = screen.querySelector('[data-map-search-results]');
  const clearSearch = screen.querySelector('.map-search-clear');
  const historyBack = screen.querySelector('.map-history-back');
  const mapRouteStatus = screen.querySelector('[data-map-route-status]');
  const topicFavorite = screen.querySelector('[data-map-action="toggle-topic-favorite"]');
  const topicMenu = screen.querySelector('[data-map-menu]');
  const topicMenuButton = screen.querySelector('[data-map-action="topic-menu"]');
  const showToast = helpers.showToast || (() => {});

  // A prototípus külön HTML-screeneket tölt be. Egy régebbi, böngészőben
  // megmaradt screen-fragmentből ez a konténer hiányozhat; ilyenkor az új
  // renderer helyben, a többi vászonnal azonos rétegbe teszi vissza.
  function ensureCardGlobeContainer() {
    if (cardGlobeContainer || !mapCanvas) return cardGlobeContainer;
    cardGlobeContainer = document.createElement('div');
    cardGlobeContainer.className = 'knowledge-globe knowledge-globe-cards';
    cardGlobeContainer.dataset.mapGlobeCards = '';
    cardGlobeContainer.tabIndex = 0;
    cardGlobeContainer.setAttribute('role', 'application');
    cardGlobeContainer.setAttribute('aria-label', 'Légzési elégtelenség perspektivikus tudáskártyákkal megjelenített gömbnézete');
    mapCanvas.prepend(cardGlobeContainer);
    return cardGlobeContainer;
  }

  function ensureFocusedGlobeContainer() {
    if (focusedGlobeContainer || !mapCanvas) return focusedGlobeContainer;
    focusedGlobeContainer = document.createElement('div');
    focusedGlobeContainer.className = 'knowledge-globe knowledge-globe-focused-cards';
    focusedGlobeContainer.dataset.mapGlobeFocusedCards = '';
    focusedGlobeContainer.tabIndex = 0;
    focusedGlobeContainer.setAttribute('role', 'application');
    focusedGlobeContainer.setAttribute('aria-label', 'Légzési elégtelenség fókuszált, bejárható tudáskártya-gömbnézete');
    mapCanvas.prepend(focusedGlobeContainer);
    return focusedGlobeContainer;
  }

  const stored = safeRead(STORAGE_KEY, {});
  const state = {
    centerId: nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure',
    selectedId: nodeById.has(stored.selectedId) ? stored.selectedId : (nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure'),
    focusedGlobeId: nodeById.has(stored.focusedGlobeId) ? stored.focusedGlobeId : (nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure'),
    history: Array.isArray(stored.history) && stored.history.every((id) => nodeById.has(id)) && stored.history.length ? stored.history : ['resp_failure'],
    zoom: clamp(Number(stored.zoom) || 1, MIN_ZOOM, MAX_ZOOM),
    panX: clamp(Number(stored.panX) || 0, -260, 260),
    panY: clamp(Number(stored.panY) || 0, -260, 260),
    selectedTypes: new Set(Array.isArray(stored.selectedTypes) ? stored.selectedTypes.filter((type) => FILTER_TYPES.includes(type)) : FILTER_TYPES),
    validatedOnly: Boolean(stored.validatedOnly),
    favoritesOnly: Boolean(stored.favoritesOnly),
    sheetOpen: Boolean(stored.sheetOpen),
    filtersOpen: false,
    worldOpen: false,
    noteOpen: false,
    djinnOpen: false,
    pathMode: Boolean(stored.pathMode),
    searchText: '',
    visualization: VISUALIZATION_BY_ID.has(stored.visualization) ? stored.visualization : 'force',
    layoutMenuOpen: false,
  };
  const favoriteNodes = new Set(safeRead(FAVORITES_KEY, []));
  let topicIsFavorite = safeRead(THEME_FAVORITE_KEY, false) === true;
  let graph;
  let forceGraph3D;
  let forceGraphSphere3D;
  let forceGraphSphereNodes = [];
  let globe;
  let cardGlobe;
  let cardGlobeObjects = [];
  let cardGlobeControls;
  let cardGlobeResizeObserver;
  let cardGlobePoints = [];
  let focusedGlobe;
  let focusedGlobeControls;
  let focusedGlobeResizeObserver;
  let focusedGlobePoints = [];
  let focusedGlobeLastFocusId;
  let focusedGlobeLodKey = '';
  const focusedGlobeNodeCache = new Map();
  const focusedGlobeObjectCache = new Map();
  let staticAtomGlobe;
  let cytoscapeGraph;
  let cytoscapeResizeObserver;
  let graphReady = false;
  let visibleNodeIds = [];
  let suppressGraphClick = false;
  let longPressTimer;
  let keyboardIndex = 0;
  let resizeObserver;
  let force3dResizeObserver;
  let force3dSphereResizeObserver;
  let force3dSphereControls;
  let force3dSphereControlsChangeHandler;
  let force3dSphereCullingFrame;
  let force3dSphereVisibilityKey = '';
  let globeResizeObserver;
  let staticAtomGlobeResizeObserver;

  function persist() {
    safeWrite(STORAGE_KEY, {
      centerId: state.centerId, selectedId: state.selectedId, focusedGlobeId: state.focusedGlobeId, history: state.history, zoom: state.zoom, panX: state.panX, panY: state.panY,
      selectedTypes: [...state.selectedTypes], validatedOnly: state.validatedOnly, favoritesOnly: state.favoritesOnly, sheetOpen: state.sheetOpen, pathMode: state.pathMode, visualization: state.visualization,
    });
    safeWrite(FAVORITES_KEY, [...favoriteNodes]);
    safeWrite(THEME_FAVORITE_KEY, topicIsFavorite);
  }

  function matchesFilters(node) {
    if (!state.selectedTypes.has(node.type)) return false;
    if (state.validatedOnly && !node.validated) return false;
    if (state.favoritesOnly && !favoriteNodes.has(node.id)) return false;
    return true;
  }

  function selectedNode() { return nodeById.get(state.selectedId) || nodeById.get(state.centerId); }

  function relationCount(nodeId) { return neighborsById.get(nodeId)?.length || 0; }

  function isGlobeView() { return state.visualization === 'globe-arc-links'; }

  function isCardGlobeView() { return state.visualization === 'globe-knowledge-cards'; }

  function isFocusedCardGlobeView() { return state.visualization === 'globe-focused-cards'; }

  function isFocusedG6View() { return state.visualization === 'g6-focused-map'; }

  function isStaticAtomGlobeView() { return state.visualization === 'globe-static-atoms'; }

  function isCytoscapeView() { return state.visualization === 'cytoscape-cose'; }

  function isAnyGlobeView() { return isGlobeView() || isCardGlobeView() || isFocusedCardGlobeView() || isStaticAtomGlobeView(); }

  function isForce3DView() { return state.visualization === '3d-force-graph'; }

  function isForceSphereView() { return state.visualization === '3d-force-globe'; }

  function updateTopicFavorite() {
    topicFavorite.textContent = topicIsFavorite ? '★' : '☆';
    topicFavorite.setAttribute('aria-pressed', String(topicIsFavorite));
    topicFavorite.setAttribute('aria-label', topicIsFavorite ? 'Téma eltávolítása a kedvencek közül' : 'Téma kedvencnek jelölése');
  }

  function updateVisualizationSelector() {
    const current = VISUALIZATION_BY_ID.get(state.visualization) || VISUALIZATION_BY_ID.get('force');
    const trigger = screen.querySelector('[data-map-action="toggle-layout-menu"]');
    const currentLabel = screen.querySelector('[data-map-layout-current]');
    const menu = screen.querySelector('[data-map-layout-menu]');
    const options = screen.querySelector('[data-map-layout-options]');
    if (currentLabel) currentLabel.textContent = current.label;
    if (trigger) trigger.setAttribute('aria-expanded', String(state.layoutMenuOpen));
    if (menu) menu.hidden = !state.layoutMenuOpen;
    mapCanvas?.classList.toggle('is-globe-view', isAnyGlobeView());
    mapCanvas?.classList.toggle('is-force3d-view', isForce3DView() || isForceSphereView());
    mapCanvas?.classList.toggle('is-force3d-sphere-view', isForceSphereView());
    if (!options) return;
    const groups = [...new Set(VISUALIZATIONS.map((item) => item.group))];
    options.innerHTML = groups.map((group) => {
      const entries = VISUALIZATIONS.filter((item) => item.group === group).map((item) => {
        const active = item.id === state.visualization;
        const badge = item.globe || item.force3d ? '<small>WebGL</small>' : item.threeD ? '<small>3D</small>' : '';
        return `<button class="map-layout-option ${active ? 'is-active' : ''}" role="menuitemradio" aria-checked="${active}" data-map-action="set-visualization" data-map-visualization="${item.id}"><i aria-hidden="true">${item.icon}</i><span>${item.label}</span>${badge}</button>`;
      }).join('');
      return `<section class="map-layout-group"><div class="map-layout-group-label">${group}</div>${entries}</section>`;
    }).join('');
  }

  function g6Layout() {
    if (state.visualization === 'd3-force-3d' || isFocusedG6View() || isAnyGlobeView() || isForce3DView() || isForceSphereView()) return undefined;
    const width = Math.max(mapContainer.clientWidth || 0, 320);
    const height = Math.max(mapContainer.clientHeight || 0, 420);
    const center = [width / 2, height / 2];
    const base = { type: state.visualization, width, height, center };
    if (state.visualization === 'force') return { ...base, linkDistance: 92, nodeStrength: -150, gravity: 9, preventOverlap: true, maxIteration: 240 };
    if (state.visualization === 'd3-force') return { ...base, link: { distance: 86, strength: .8 }, manyBody: { strength: -155 }, collide: { radius: 16, strength: .8 } };
    if (state.visualization === 'force-atlas2') return { ...base, kr: 12, kg: 8, preventOverlap: true, maxIteration: 220 };
    if (state.visualization === 'fruchterman') return { ...base, gravity: 8, speed: 4, maxIteration: 220, preventOverlap: true };
    if (state.visualization === 'mds') return { ...base, linkDistance: 82 };
    if (state.visualization === 'circular') return { ...base, radius: Math.min(width, height) * .35, ordering: 'degree', divisions: 3, startRadius: 24 };
    if (state.visualization === 'concentric') return { ...base, minNodeSpacing: 18, equidistant: true, preventOverlap: true };
    if (state.visualization === 'radial') return { ...base, unitRadius: 72, preventOverlap: true, maxIteration: 180 };
    if (state.visualization === 'grid') return { ...base, begin: [22, 22], preventOverlap: true, nodeSize: 26 };
    if (state.visualization === 'random') return { ...base, padding: 28 };
    if (state.visualization === 'snake') return { ...base, direction: 'LR', nodeSpacing: 24 };
    if (state.visualization === 'antv-dagre') return { ...base, rankdir: 'TB', nodesep: 24, ranksep: 45, controlPoints: true };
    if (state.visualization === 'dagre') return { ...base, rankdir: 'LR', nodesep: 22, ranksep: 45, controlPoints: true };
    if (state.visualization === 'combo-combined') return { ...base, spacing: 28 };
    if (state.visualization === 'compact-box') return { ...base, direction: 'TB', getId: (datum) => datum.id };
    if (state.visualization === 'dendrogram') return { ...base, direction: 'LR', getId: (datum) => datum.id };
    if (state.visualization === 'fishbone') return { ...base, direction: 'LR', getId: (datum) => datum.id };
    if (state.visualization === 'mindmap') return { ...base, direction: 'H', getId: (datum) => datum.id };
    if (state.visualization === 'indented') return { ...base, direction: 'LR', indent: 30, getId: (datum) => datum.id };
    return base;
  }

  function destroyG6Graph() {
    resizeObserver?.disconnect();
    resizeObserver = undefined;
    graphReady = false;
    graph?.destroy();
    graph = undefined;
    mapContainer.replaceChildren();
  }

  function destroyGlobe() {
    globeResizeObserver?.disconnect();
    globeResizeObserver = undefined;
    try { globe?._destructor?.(); } catch { /* A nézetváltás Globe.GL nélkül is folytatódik. */ }
    globe = undefined;
    globeContainer?.replaceChildren();
    if (globeContainer) globeContainer.hidden = true;
  }

  function destroyCardGlobe() {
    cardGlobeResizeObserver?.disconnect();
    cardGlobeResizeObserver = undefined;
    cardGlobe?.objectsData?.([]);
    disposeCardGlobeObjects();
    cardGlobeControls = undefined;
    try { cardGlobe?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    cardGlobe = undefined;
    cardGlobePoints = [];
    cardGlobeContainer?.replaceChildren();
    if (cardGlobeContainer) cardGlobeContainer.hidden = true;
  }

  function destroyFocusedCardGlobe() {
    focusedGlobeResizeObserver?.disconnect();
    focusedGlobeResizeObserver = undefined;
    focusedGlobe?.objectsData?.([]);
    disposeFocusedGlobeObjects();
    focusedGlobeControls = undefined;
    try { focusedGlobe?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    focusedGlobe = undefined;
    focusedGlobePoints = [];
    focusedGlobeLastFocusId = undefined;
    focusedGlobeLodKey = '';
    focusedGlobeNodeCache.clear();
    focusedGlobeContainer?.replaceChildren();
    if (focusedGlobeContainer) focusedGlobeContainer.hidden = true;
  }

  function destroyCytoscape() {
    cytoscapeResizeObserver?.disconnect();
    cytoscapeResizeObserver = undefined;
    try { cytoscapeGraph?.destroy?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    cytoscapeGraph = undefined;
    cytoscapeContainer?.replaceChildren();
    if (cytoscapeContainer) cytoscapeContainer.hidden = true;
  }

  function destroyStaticAtomGlobe() {
    staticAtomGlobeResizeObserver?.disconnect();
    staticAtomGlobeResizeObserver = undefined;
    try { staticAtomGlobe?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    staticAtomGlobe = undefined;
    staticAtomGlobeContainer?.replaceChildren();
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
  }

  function destroyForceGraph3D() {
    force3dResizeObserver?.disconnect();
    force3dResizeObserver = undefined;
    try { forceGraph3D?._destructor?.(); } catch { /* A nézetváltás a WebGL motor hibája nélkül is folytatódik. */ }
    forceGraph3D = undefined;
    force3dContainer?.replaceChildren();
    if (force3dContainer) force3dContainer.hidden = true;
  }

  function destroyForceGraphSphere3D() {
    force3dSphereResizeObserver?.disconnect();
    force3dSphereResizeObserver = undefined;
    if (force3dSphereCullingFrame) window.cancelAnimationFrame(force3dSphereCullingFrame);
    force3dSphereCullingFrame = undefined;
    force3dSphereControls?.removeEventListener?.('change', force3dSphereControlsChangeHandler);
    force3dSphereControls = undefined;
    force3dSphereControlsChangeHandler = undefined;
    force3dSphereVisibilityKey = '';
    mapCanvas?.style.removeProperty('--force-sphere-scale');
    try { forceGraphSphere3D?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    forceGraphSphere3D = undefined;
    forceGraphSphereNodes = [];
    force3dSphereContainer?.replaceChildren();
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
  }

  function createActiveRenderer() {
    if (isGlobeView()) { createGlobe(); return; }
    if (isCardGlobeView()) { createCardGlobe(); return; }
    if (isFocusedCardGlobeView()) { createFocusedCardGlobe(); return; }
    if (isStaticAtomGlobeView()) { createStaticAtomGlobe(); return; }
    if (isCytoscapeView()) { createCytoscape(); return; }
    if (isForceSphereView()) { createForceGraphSphere3D(); return; }
    if (isForce3DView()) { createForceGraph3D(); return; }
    createG6Graph();
  }

  function setVisualization(visualization) {
    if (!VISUALIZATION_BY_ID.has(visualization)) return;
    if (state.visualization === visualization) { state.layoutMenuOpen = false; updateVisualizationSelector(); return; }
    state.visualization = visualization;
    if (visualization === 'globe-focused-cards') state.focusedGlobeId = state.centerId;
    state.layoutMenuOpen = false;
    state.zoom = 1; state.panX = 0; state.panY = 0;
    updateVisualizationSelector();
    persist();
    destroyG6Graph();
    destroyGlobe();
    destroyCardGlobe();
    destroyFocusedCardGlobe();
    destroyStaticAtomGlobe();
    destroyCytoscape();
    destroyForceGraph3D();
    destroyForceGraphSphere3D();
    // A layoutok eltérő adatot igényelnek (pl. fa vagy combo), ezért tisztán indulnak újra.
    window.requestAnimationFrame(createActiveRenderer);
    showToast(`${VISUALIZATION_BY_ID.get(visualization).label} nézet aktív.`);
  }

  function renderBreadcrumb() {
    const displayHistory = state.history.slice(-4);
    breadcrumb.innerHTML = displayHistory.map((id, index) => {
      const historyIndex = state.history.length - displayHistory.length + index;
      const node = nodeById.get(id);
      const separator = index ? '<span aria-hidden="true">›</span>' : '';
      return `${separator}<button data-map-breadcrumb="${historyIndex}" aria-label="Ugrás ide: ${node.title}" class="${id === state.centerId ? 'is-current' : ''}">${node.title}</button>`;
    }).join('');
    historyBack.disabled = state.history.length < 2;
    mapRouteStatus.hidden = !state.pathMode || state.history.length < 2;
  }

  // Determinisztikus, perspektivikus 3D-vetítés a G6 D3 Force 3D választójához.
  // A G6 rajzolása itt is a gyári stíluson marad; csak a térbeli pozíció vetül 2D-re.
  function threeDPositions(nodes) {
    const width = Math.max(mapContainer.clientWidth || 0, 320);
    const height = Math.max(mapContainer.clientHeight || 0, 420);
    const radius = Math.max(90, Math.min(width, height) * .36);
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));
    const rotation = (Math.abs(hash(state.centerId)) % 360) * Math.PI / 180;
    const positions = new Map();
    nodes.forEach((node, index) => {
      const progress = nodes.length === 1 ? .5 : index / (nodes.length - 1);
      const y3 = 1 - (2 * progress);
      const ring = Math.sqrt(Math.max(0, 1 - y3 * y3));
      const theta = goldenAngle * index + rotation;
      const x3 = Math.cos(theta) * ring;
      const z3 = Math.sin(theta) * ring;
      const depth = .55 + ((z3 + 1) / 2) * .75;
      positions.set(node.id, { x: width / 2 + x3 * radius * depth, y: height / 2 + y3 * radius * depth, z: z3, depth });
    });
    return positions;
  }

  function graphNode(node, index, total, treeDepth = 0, threeD = undefined) {
    const graphNode = {
      id: node.id,
      data: { ...node, treeDepth, z: threeD?.z || 0 },
      combo: state.visualization === 'combo-combined' ? `type-${node.type}` : undefined,
      zIndex: threeD ? Math.round(threeD.z * 1000) : index,
    };
    // A pozíció nem vizuális felülírás: csak a G6 rajzvászon koordinátája a 3D vetítéshez.
    if (threeD) graphNode.style = { x: threeD.x, y: threeD.y };
    return graphNode;
  }

  function graphEdge(edge, index) {
    return { id: edge.id || `${edge.source}-${edge.target}-${index}`, source: edge.source, target: edge.target, data: edge.data || edge };
  }

  function buildSpanningTree(allowedIds) {
    const rootId = allowedIds.has(state.centerId) ? state.centerId : [...allowedIds][0];
    if (!rootId) return null;
    const children = new Map([...allowedIds].map((id) => [id, []]));
    const visited = new Set([rootId]);
    const queue = [rootId];
    while (queue.length) {
      const current = queue.shift();
      (neighborsById.get(current) || []).forEach(({ id }) => {
        if (!allowedIds.has(id) || visited.has(id)) return;
        visited.add(id); children.get(current).push(id); queue.push(id);
      });
    }
    [...allowedIds].forEach((id) => { if (!visited.has(id)) { visited.add(id); children.get(rootId).push(id); } });
    const toTree = (id) => ({ id, data: { ...nodeById.get(id) }, children: children.get(id).map(toTree) });
    return toTree(rootId);
  }

  function treeGraphData(matched) {
    const tree = buildSpanningTree(new Set(matched.map((node) => node.id)));
    if (!tree) return { nodes: [], edges: [] };
    const raw = window.G6?.treeToGraphData ? window.G6.treeToGraphData(tree) : { nodes: [tree], edges: [] };
    // A children mező G6 számára is megőrzi a parent–child struktúrát: erre a
    // Compact Box / Mindmap / Indented mellett a Fishbone is támaszkodik.
    const nodes = raw.nodes.map((item, index) => ({
      ...graphNode(nodeById.get(item.id), index, raw.nodes.length, item.depth || 0),
      children: item.children || [],
    }));
    return { nodes, edges: raw.edges.map((edge, index) => graphEdge(edge, index, true)) };
  }

  function fullGraphData(matched) {
    const isThreeD = state.visualization === 'd3-force-3d';
    const projection = isThreeD ? threeDPositions(matched) : undefined;
    const ordered = isThreeD ? [...matched].sort((a, b) => projection.get(a.id).z - projection.get(b.id).z) : matched;
    const nodes = ordered.map((node, index) => graphNode(node, index, ordered.length, 0, projection?.get(node.id)));
    const nodeIds = new Set(matched.map((node) => node.id));
    const edges = knowledgeEdges.filter(({ source, target }) => nodeIds.has(source) && nodeIds.has(target)).map((edge, index) => graphEdge(edge, index));
    const result = { nodes, edges };
    if (state.visualization === 'combo-combined') {
      result.combos = [...new Set(matched.map((node) => node.type))].map((type) => ({ id: `type-${type}`, data: { label: TYPE_META[type].label } }));
    }
    return result;
  }

  function localGraphData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    return TREE_LAYOUTS.has(state.visualization) ? treeGraphData(matched) : fullGraphData(matched);
  }

  // A G6-síkban megjelenő kártyák grafikus primitívek, nem HTML-overlayek. Így
  // a vászon pan/zoom gesztusai végig a G6-é maradnak, és a fókuszváltás csak
  // a lusta részgráf adathalmazát cseréli.
  function focusedG6GraphData() {
    const subgraph = buildFocusedG6Subgraph(state.centerId, knowledgeNodes, knowledgeEdges, { includeNode: matchesFilters });
    empty.hidden = subgraph.nodes.length > 0;
    mapContainer.hidden = !empty.hidden;
    if (!empty.hidden) {
      visibleNodeIds = [];
      renderBreadcrumb();
      return null;
    }
    visibleNodeIds = subgraph.nodes.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const width = Math.max(mapContainer.clientWidth || 0, 320);
    const height = Math.max(mapContainer.clientHeight || 0, 420);
    const positions = focusedG6Positions(subgraph.nodes, subgraph.focusId, width, height);
    const colorsByDepth = {
      0: { fill: '#7954ed', stroke: '#6341d2', label: '#ffffff', shadow: '#6848d8' },
      1: { fill: '#ffffff', stroke: '#d8cbed', label: '#494154', shadow: '#a99aca' },
      2: { fill: '#faf8ff', stroke: '#e7def5', label: '#675e72', shadow: '#c9bedb' },
    };
    const nodes = subgraph.nodes.map((node, index) => {
      const position = positions.get(node.id);
      const depth = node.focusDepth;
      const colors = colorsByDepth[depth] || colorsByDepth[2];
      const cardSize = focusedG6CardSize(depth);
      return {
        id: node.id,
        type: 'rect',
        data: { ...node, focusDepth: depth },
        zIndex: 20 - depth + index / 100,
        style: {
          x: position.x,
          y: position.y,
          size: cardSize,
          radius: depth === 0 ? 18 : 14,
          fill: colors.fill,
          stroke: colors.stroke,
          lineWidth: depth === 0 ? 2 : 1,
          shadowColor: colors.shadow,
          shadowBlur: depth === 0 ? 18 : 9,
          shadowOffsetY: depth === 0 ? 7 : 4,
          labelText: node.title,
          labelPlacement: 'center',
          labelFill: colors.label,
          labelFontSize: depth === 0 ? 11 : depth === 1 ? 9.5 : 8,
          labelFontWeight: depth === 0 ? 700 : 600,
          labelWordWrap: true,
          labelMaxWidth: cardSize[0] - 16,
        },
      };
    });
    const edges = subgraph.edges.map((edge, index) => {
      const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
      return {
        id: `${edge.source}-${edge.target}-${index}`,
        type: 'quadratic',
        source: edge.source,
        target: edge.target,
        data: { ...edge },
        zIndex: 1,
        style: {
          stroke: onPath ? '#7250e6' : '#b7a7dd',
          lineWidth: onPath ? 3 : 1 + edge.weight * .7,
          opacity: onPath ? 1 : .48,
          endArrow: false,
        },
      };
    });
    return { focusId: subgraph.focusId, nodes, edges };
  }

  function renderFocusedG6Graph(animated = false) {
    const data = focusedG6GraphData();
    if (!graphReady || !graph) return;
    if (!data) {
      graph.setData({ nodes: [], edges: [] });
      void graph.render();
      return;
    }
    graph.setData({ nodes: data.nodes, edges: data.edges });
    void Promise.resolve(graph.render()).then(() => {
      // A központi kártya mindig a viewport közepe. Fókuszváltáskor a G6
      // animációja rendezi át a régi contextet az új, lokális contextté.
      if (typeof graph.focusElement === 'function') {
        void graph.focusElement(data.focusId, { duration: animated ? 420 : 0, easing: 'ease-in-out' }).then(syncViewportState);
      }
    });
  }

  function globePointData(matched) {
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));
    const rotation = (Math.abs(hash(state.centerId)) % 360) * Math.PI / 180;
    return matched.map((node, index) => {
      const progress = matched.length === 1 ? .5 : index / (matched.length - 1);
      const latitude = Math.asin(1 - (2 * progress)) * 180 / Math.PI;
      const longitude = ((goldenAngle * index + rotation) * 180 / Math.PI + 540) % 360 - 180;
      return {
        ...node,
        lat: latitude,
        lng: longitude,
        color: node.id === state.centerId ? '#fff2ff' : '#d4bbff',
      };
    });
  }

  function renderGlobe() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    if (!globe) return;
    const points = globePointData(matched);
    const pointById = new Map(points.map((point) => [point.id, point]));
    const arcPalette = ['#f2b3ff', '#b995ff', '#8bc7ff', '#ff94c8', '#ffd18d', '#a8f0df'];
    const arcs = knowledgeEdges
      .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
      .map((edge, index) => {
        const start = pointById.get(edge.source);
        const end = pointById.get(edge.target);
        const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
        return {
          ...edge,
          startLat: start.lat, startLng: start.lng, endLat: end.lat, endLng: end.lng,
          color: onPath ? '#ffffff' : arcPalette[index % arcPalette.length],
          altitude: onPath ? .34 : .1 + edge.weight * .2,
        };
      });
    globe
      .pointsData(points)
      .pointLat('lat')
      .pointLng('lng')
      .pointColor('color')
      .pointAltitude((point) => point.id === state.centerId ? .14 : .055)
      .pointRadius((point) => point.id === state.centerId ? .72 : .42)
      .pointLabel((point) => `<b>${point.title}</b><br/>${point.subtitle}`)
      .arcsData(arcs)
      .arcStartLat('startLat')
      .arcStartLng('startLng')
      .arcEndLat('endLat')
      .arcEndLng('endLng')
      .arcColor('color')
      .arcAltitude('altitude')
      .arcStroke(.18)
      .arcDashLength(1)
      .arcDashGap(0)
      .arcDashAnimateTime(0)
      .arcsTransitionDuration(0);
  }

  function createGlobe(attempt = 0) {
    const Globe = window.Globe;
    if (!Globe || !globeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createGlobe(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      globeContainer?.setAttribute('hidden', '');
      showToast('A Globe.GL nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    globeContainer.hidden = false;
    const texture = `data:image/svg+xml;charset=utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512"><defs><radialGradient id="g" cx="32%" cy="28%"><stop offset="0" stop-color="#b88bff"/><stop offset=".45" stop-color="#6f3eb2"/><stop offset="1" stop-color="#2a1457"/></radialGradient></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>')}`;
    globe = new Globe(globeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(globeContainer.clientWidth, 320))
      .height(Math.max(globeContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .globeImageUrl(texture)
      .showAtmosphere(true)
      .atmosphereColor('#bb8aff')
      .atmosphereAltitude(.17)
      .showGraticules(false)
      .onPointClick((point) => navigateTo(point.id))
      .onPointHover((point) => { globeContainer.style.cursor = point ? 'pointer' : 'grab'; });
    const globeControls = globe.controls?.();
    if (globeControls) { globeControls.enableDamping = true; globeControls.dampingFactor = .08; }
    globe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 0);
    globeResizeObserver = new ResizeObserver(() => {
      globe?.width(Math.max(globeContainer.clientWidth, 320)).height(Math.max(globeContainer.clientHeight, 420));
    });
    globeResizeObserver.observe(globeContainer);
    renderGlobe();
  }

  // Az Arc Links nézettől független Globe.GL-változat. A kártyák nem DOM
  // overlayek: ugyanabban a Three.js scene graphban lévő plane mesh-ek, mint
  // a gömb. Így nincs önálló képernyő-koordinátás drag- vagy offset-állapotuk.
  function renderCardGlobe() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (cardGlobeContainer) cardGlobeContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    if (!cardGlobe) return;
    cardGlobePoints = globePointData(matched).map((point) => ({
      ...point,
      // Globe.GL-relatív magasság: éppen a felszín fölött, z-fighting nélkül.
      altitude: .012,
      visualScale: .74 + point.importance * .22,
    }));
    const pointById = new Map(cardGlobePoints.map((point) => [point.id, point]));
    const arcPalette = ['#f2b3ff', '#b995ff', '#8bc7ff', '#ff94c8', '#ffd18d', '#a8f0df'];
    const arcs = knowledgeEdges
      .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
      .map((edge, index) => {
        const start = pointById.get(edge.source);
        const end = pointById.get(edge.target);
        const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
        return {
          ...edge,
          startLat: start.lat, startLng: start.lng, endLat: end.lat, endLng: end.lng,
          color: onPath ? '#fff9c9' : arcPalette[index % arcPalette.length],
          altitude: onPath ? .34 : .1 + edge.weight * .2,
        };
      });
    disposeCardGlobeObjects();
    cardGlobe
      .pointsData([])
      .arcsData(arcs)
      .arcStartLat('startLat')
      .arcStartLng('startLng')
      .arcEndLat('endLat')
      .arcEndLng('endLng')
      .arcColor('color')
      .arcAltitude('altitude')
      .arcStroke(.16)
      .arcDashLength(1)
      .arcDashGap(0)
      .arcDashAnimateTime(0)
      .arcsTransitionDuration(0)
      // A kártya pozícióját és a külső Group felszíni orientációját a
      // Globe.GL kezeli; sem pixel-, sem világkoordinátás offsetet nem tárolunk.
      .objectsData(cardGlobePoints)
      .objectLat('lat')
      .objectLng('lng')
      .objectAltitude('altitude')
      .objectFacesSurface(true)
      .objectThreeObject(createKnowledgeCard)
      .onObjectClick((point) => navigateTo(point.id))
      .onObjectHover((point) => { cardGlobeContainer.style.cursor = point ? 'pointer' : 'grab'; });
  }

  function drawCardTexture(point) {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 256;
    const context = canvas.getContext('2d');
    const selected = point.id === state.selectedId;
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, selected ? '#b38aff' : '#8b61db');
    gradient.addColorStop(1, selected ? '#5423a4' : '#31146a');
    context.fillStyle = gradient;
    context.roundRect?.(5, 5, 502, 246, 30);
    if (!context.roundRect) {
      context.beginPath();
      context.moveTo(35, 5); context.arcTo(507, 5, 507, 251, 30); context.arcTo(507, 251, 5, 251, 30);
      context.arcTo(5, 251, 5, 5, 30); context.arcTo(5, 5, 507, 5, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = 5;
    context.strokeStyle = selected ? '#fff0ae' : 'rgba(245,237,255,.86)';
    context.stroke();
    context.fillStyle = 'rgba(255,255,255,.7)';
    context.font = '700 27px system-ui, sans-serif';
    context.fillText(TYPE_META[point.type].label.toUpperCase(), 34, 54);
    context.fillStyle = '#ffffff';
    context.font = '800 49px system-ui, sans-serif';
    context.fillText(point.title.length > 22 ? `${point.title.slice(0, 21)}…` : point.title, 34, 120);
    context.fillStyle = 'rgba(250,244,255,.8)';
    context.font = '400 29px system-ui, sans-serif';
    context.fillText(point.subtitle.length > 31 ? `${point.subtitle.slice(0, 30)}…` : point.subtitle, 34, 173);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.needsUpdate = true;
    return texture;
  }

  function disposeCardGlobeObjects() {
    cardGlobeObjects.forEach((root) => root.traverse((object) => {
      if (!object.isMesh) return;
      object.geometry?.dispose?.();
      const material = object.material;
      material?.map?.dispose?.();
      material?.dispose?.();
    }));
    cardGlobeObjects = [];
  }

  function disposeFocusedGlobeObjects() {
    focusedGlobeObjectCache.forEach((root) => root.traverse((object) => {
      if (!object.isMesh) return;
      object.geometry?.dispose?.();
      object.material?.map?.dispose?.();
      object.material?.dispose?.();
    }));
    focusedGlobeObjectCache.clear();
  }

  // A Globe.GL az ezt visszaadó külső Groupot helyezi a lat/lng anchorra és
  // forgatja a felszín normáljára. A belső meshhez nincs kamera-quaternion.
  function makeKnowledgeCardObject(point) {
    const group = new THREE.Group();
    group.name = `djinn-globe-card-${point.id}`;
    group.userData.atomId = point.id;
    group.userData.baseScale = point.visualScale;
    const texture = drawCardTexture(point);
    const material = new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      depthTest: true,
      depthWrite: false,
      side: THREE.FrontSide,
    });
    const card = new THREE.Mesh(new THREE.PlaneGeometry(37, 18.5), material);
    card.scale.setScalar(point.id === state.selectedId ? 1.12 : 1);
    group.add(card);
    group.scale.setScalar(point.visualScale);
    return group;
  }

  function createKnowledgeCard(point) {
    const group = makeKnowledgeCardObject(point);
    cardGlobeObjects.push(group);
    return group;
  }

  function createFocusedKnowledgeCard(point) {
    const cached = focusedGlobeObjectCache.get(point.id);
    if (cached) return cached;
    const group = makeKnowledgeCardObject(point);
    group.userData.isFocused = point.isFocused;
    focusedGlobeObjectCache.set(point.id, group);
    return group;
  }

  function createCardGlobe(attempt = 0) {
    ensureCardGlobeContainer();
    const Globe = window.Globe;
    if (!Globe || !cardGlobeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createCardGlobe(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      cardGlobeContainer?.setAttribute('hidden', '');
      showToast('A tudáskártyás Globe.GL nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    cardGlobeContainer.hidden = false;
    const texture = `data:image/svg+xml;charset=utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512"><defs><radialGradient id="g" cx="32%" cy="28%"><stop offset="0" stop-color="#b88bff"/><stop offset=".45" stop-color="#6f3eb2"/><stop offset="1" stop-color="#2a1457"/></radialGradient></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>')}`;
    cardGlobe = new Globe(cardGlobeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(cardGlobeContainer.clientWidth, 320))
      .height(Math.max(cardGlobeContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .globeImageUrl(texture)
      .showAtmosphere(true)
      .atmosphereColor('#bb8aff')
      .atmosphereAltitude(.17)
      .showGraticules(false);
    cardGlobeControls = cardGlobe.controls?.();
    if (cardGlobeControls) {
      // A fókusz a gömb közepe; húzáskor csak az OrbitControls forgathat.
      cardGlobeControls.enablePan = false;
      cardGlobeControls.screenSpacePanning = false;
      cardGlobeControls.target?.set?.(0, 0, 0);
      cardGlobeControls.enableDamping = true;
      cardGlobeControls.dampingFactor = .08;
    }
    cardGlobe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 0);
    cardGlobeResizeObserver = new ResizeObserver(() => {
      cardGlobe?.width(Math.max(cardGlobeContainer.clientWidth, 320)).height(Math.max(cardGlobeContainer.clientHeight, 420));
    });
    cardGlobeResizeObserver.observe(cardGlobeContainer);
    renderCardGlobe();
  }

  function focusedGlobeLod(altitude = 2.1) {
    if (altitude > 2.2) return { firstRingLimit: 4, secondRingPerNode: 1, maxNodes: 10, key: 'far' };
    if (altitude > 1.4) return { firstRingLimit: 8, secondRingPerNode: 2, maxNodes: 24, key: 'normal' };
    return { firstRingLimit: 12, secondRingPerNode: 3, maxNodes: 40, key: 'near' };
  }

  // A teljes gráf nem kerül a WebGL scene-be. A súly szerint rendezett két
  // gyűrűből készül egy korlátos, fókuszált renderablak.
  function buildFocusedNeighborhood(focusId, options = focusedGlobeLod()) {
    const validFocusId = nodeById.has(focusId) ? focusId : 'resp_failure';
    const eligibleIds = new Set(knowledgeNodes.filter(matchesFilters).map((node) => node.id));
    eligibleIds.add(validFocusId);
    const nodeIds = new Set([validFocusId]);
    const rankedNeighbors = (id) => (neighborsById.get(id) || []).filter(({ id: neighborId }) => eligibleIds.has(neighborId));
    const firstRing = rankedNeighbors(validFocusId).slice(0, options.firstRingLimit);

    firstRing.forEach(({ id }) => {
      if (nodeIds.size < options.maxNodes) nodeIds.add(id);
    });

    for (const { id: parentId } of firstRing) {
      if (nodeIds.size >= options.maxNodes) break;
      const secondRing = rankedNeighbors(parentId)
        .filter(({ id }) => !nodeIds.has(id))
        .slice(0, options.secondRingPerNode);
      for (const { id } of secondRing) {
        if (nodeIds.size >= options.maxNodes) break;
        nodeIds.add(id);
      }
    }

    return {
      nodeIds,
      nodes: [...nodeIds].map((id) => nodeById.get(id)).filter(Boolean),
      edges: knowledgeEdges.filter((edge) => nodeIds.has(edge.source) && nodeIds.has(edge.target)),
    };
  }

  function focusedGlobePointData(nodes, focusId) {
    return nodes.map((node) => {
      const position = PERSISTENT_GLOBE_COORDINATES.get(node.id);
      let point = focusedGlobeNodeCache.get(node.id);
      if (!point) {
        point = { ...node, lat: position.lat, lng: position.lng, altitude: .012, visualScale: .72 + node.importance * .2 };
        focusedGlobeNodeCache.set(node.id, point);
      }
      point.isFocused = node.id === focusId;
      point.visualScale = (point.isFocused ? 1.12 : 1) * (.72 + node.importance * .2);
      const existingCard = focusedGlobeObjectCache.get(node.id);
      if (existingCard) {
        const wasFocused = existingCard.userData.isFocused;
        existingCard.userData.isFocused = point.isFocused;
        existingCard.scale.setScalar(point.visualScale);
        const mesh = existingCard.children[0];
        if (mesh) mesh.scale.setScalar(point.isFocused ? 1.12 : 1);
        if (wasFocused !== point.isFocused && mesh?.material?.map) {
          mesh.material.map.dispose();
          mesh.material.map = drawCardTexture(point);
          mesh.material.needsUpdate = true;
        }
      }
      return point;
    });
  }

  function renderFocusedCardGlobe(animated = false) {
    const focusId = nodeById.has(state.focusedGlobeId) ? state.focusedGlobeId : state.centerId;
    state.focusedGlobeId = focusId;
    const isInitialView = !focusedGlobeLastFocusId;
    const cameraAltitude = isInitialView ? 2.1 : (focusedGlobe?.pointOfView?.().altitude || 2.1);
    const lod = focusedGlobeLod(cameraAltitude);
    const subgraph = buildFocusedNeighborhood(focusId, lod);
    empty.hidden = subgraph.nodes.length > 0;
    mapContainer.hidden = true;
    if (focusedGlobeContainer) focusedGlobeContainer.hidden = !empty.hidden;
    if (!empty.hidden || !focusedGlobe) { visibleNodeIds = []; renderBreadcrumb(); return; }
    focusedGlobePoints = focusedGlobePointData(subgraph.nodes, focusId);
    visibleNodeIds = focusedGlobePoints.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const pointById = new Map(focusedGlobePoints.map((point) => [point.id, point]));
    const arcPalette = ['#f2b3ff', '#b995ff', '#8bc7ff', '#ff94c8', '#ffd18d', '#a8f0df'];
    const arcs = subgraph.edges.map((edge, index) => {
      const start = pointById.get(edge.source);
      const end = pointById.get(edge.target);
      const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
      return {
        ...edge,
        startLat: start.lat, startLng: start.lng, endLat: end.lat, endLng: end.lng,
        color: onPath ? '#fff9c9' : arcPalette[index % arcPalette.length],
        altitude: onPath ? .26 : .06 + edge.weight * .14,
      };
    });
    focusedGlobe
      .pointsData([])
      .arcsData(arcs)
      .arcStartLat('startLat')
      .arcStartLng('startLng')
      .arcEndLat('endLat')
      .arcEndLng('endLng')
      .arcColor('color')
      .arcAltitude('altitude')
      .arcStroke(.15)
      .arcDashLength(1)
      .arcDashGap(0)
      .arcDashAnimateTime(0)
      .arcsTransitionDuration(0)
      .objectsData(focusedGlobePoints)
      .objectLat('lat')
      .objectLng('lng')
      .objectAltitude('altitude')
      .objectFacesSurface(true)
      .objectThreeObject(createFocusedKnowledgeCard)
      .onObjectClick((point) => navigateTo(point.id))
      .onObjectHover((point) => { focusedGlobeContainer.style.cursor = point ? 'pointer' : 'grab'; });

    const focusPosition = PERSISTENT_GLOBE_COORDINATES.get(focusId);
    if (focusedGlobeLastFocusId !== focusId || animated) {
      focusedGlobe.pointOfView({ lat: focusPosition.lat, lng: focusPosition.lng, altitude: clamp(cameraAltitude, 1.05, 3.6) }, animated ? 700 : 0);
      focusedGlobeLastFocusId = focusId;
    }
    focusedGlobeLodKey = lod.key;
  }

  function createFocusedCardGlobe(attempt = 0) {
    ensureFocusedGlobeContainer();
    const Globe = window.Globe;
    if (!Globe || !focusedGlobeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createFocusedCardGlobe(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      focusedGlobeContainer?.setAttribute('hidden', '');
      showToast('A fókuszált tudáskártya-gömbnézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (cardGlobeContainer) cardGlobeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    focusedGlobeContainer.hidden = false;
    const texture = `data:image/svg+xml;charset=utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512"><defs><radialGradient id="g" cx="32%" cy="28%"><stop offset="0" stop-color="#b88bff"/><stop offset=".45" stop-color="#6f3eb2"/><stop offset="1" stop-color="#2a1457"/></radialGradient></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>')}`;
    focusedGlobe = new Globe(focusedGlobeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(focusedGlobeContainer.clientWidth, 320))
      .height(Math.max(focusedGlobeContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .globeImageUrl(texture)
      .showAtmosphere(true)
      .atmosphereColor('#bb8aff')
      .atmosphereAltitude(.17)
      .showGraticules(false)
      .onZoom((pov) => {
        const nextLod = focusedGlobeLod(pov.altitude);
        if (nextLod.key !== focusedGlobeLodKey) renderFocusedCardGlobe();
      });
    focusedGlobeControls = focusedGlobe.controls?.();
    if (focusedGlobeControls) {
      focusedGlobeControls.enablePan = false;
      focusedGlobeControls.screenSpacePanning = false;
      focusedGlobeControls.target?.set?.(0, 0, 0);
      focusedGlobeControls.enableDamping = true;
      focusedGlobeControls.dampingFactor = .08;
    }
    focusedGlobeResizeObserver = new ResizeObserver(() => {
      focusedGlobe?.width(Math.max(focusedGlobeContainer.clientWidth, 320)).height(Math.max(focusedGlobeContainer.clientHeight, 420));
    });
    focusedGlobeResizeObserver.observe(focusedGlobeContainer);
    renderFocusedCardGlobe();
  }

  // Az eredeti Arc Links külön példánya: a kamera forog, a gömb pedig egyszínű
  // emisszív anyag, ezért a felszín vizuálisan álló marad.
  function renderStaticAtomGlobe() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    if (!staticAtomGlobe) return;
    const points = globePointData(matched);
    const pointById = new Map(points.map((point) => [point.id, point]));
    const arcPalette = ['#f2b3ff', '#b995ff', '#8bc7ff', '#ff94c8', '#ffd18d', '#a8f0df'];
    const arcs = knowledgeEdges
      .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
      .map((edge, index) => {
      const start = pointById.get(edge.source);
      const end = pointById.get(edge.target);
      const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
      return {
        ...edge,
        startLat: start.lat, startLng: start.lng, endLat: end.lat, endLng: end.lng,
        color: onPath ? '#ffffff' : arcPalette[index % arcPalette.length],
        altitude: onPath ? .34 : .1 + edge.weight * .2,
      };
    });
    staticAtomGlobe
      .pointsData(points)
      .pointLat('lat')
      .pointLng('lng')
      .pointColor('color')
      .pointAltitude((point) => point.id === state.centerId ? .14 : .055)
      .pointRadius((point) => point.id === state.centerId ? .72 : .42)
      .pointLabel((point) => `<b>${point.title}</b><br/>${point.subtitle}`)
      .arcsData(arcs)
      .arcStartLat('startLat')
      .arcStartLng('startLng')
      .arcEndLat('endLat')
      .arcEndLng('endLng')
      .arcColor('color')
      .arcAltitude('altitude')
      .arcStroke(.18)
      .arcDashLength(1)
      .arcDashGap(0)
      .arcDashAnimateTime(0)
      .arcsTransitionDuration(0);
  }

  function createStaticAtomGlobe(attempt = 0) {
    const Globe = window.Globe;
    if (!Globe || !staticAtomGlobeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createStaticAtomGlobe(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      staticAtomGlobeContainer?.setAttribute('hidden', '');
      showToast('A statikus atomgömb nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    staticAtomGlobeContainer.hidden = false;
    staticAtomGlobe = new Globe(staticAtomGlobeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(staticAtomGlobeContainer.clientWidth, 320))
      .height(Math.max(staticAtomGlobeContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .showAtmosphere(true)
      .atmosphereColor('#bb8aff')
      .atmosphereAltitude(.17)
      .showGraticules(false)
      .onPointClick((point) => navigateTo(point.id))
      .onPointHover((point) => { staticAtomGlobeContainer.style.cursor = point ? 'pointer' : 'grab'; });
    const shadowlessMaterial = staticAtomGlobe.globeMaterial?.();
    if (shadowlessMaterial) {
      shadowlessMaterial.map = null;
      shadowlessMaterial.color?.set?.('#000000');
      shadowlessMaterial.emissive?.set?.('#6f3eb2');
      shadowlessMaterial.emissiveIntensity = 1;
      shadowlessMaterial.specular?.set?.('#000000');
      shadowlessMaterial.shininess = 0;
      shadowlessMaterial.needsUpdate = true;
    }
    const staticControls = staticAtomGlobe.controls?.();
    if (staticControls) {
      staticControls.enableDamping = true;
      staticControls.dampingFactor = .08;
      staticControls.autoRotate = true;
      staticControls.autoRotateSpeed = 2.2;
    }
    staticAtomGlobe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 0);
    staticAtomGlobeResizeObserver = new ResizeObserver(() => {
      staticAtomGlobe?.width(Math.max(staticAtomGlobeContainer.clientWidth, 320)).height(Math.max(staticAtomGlobeContainer.clientHeight, 420));
    });
    staticAtomGlobeResizeObserver.observe(staticAtomGlobeContainer);
    renderStaticAtomGlobe();
  }

  // Cytoscape.js saját COSE elrendezése. Ez szándékosan külön motor és külön
  // DOM-vászon: a Navigation Graph azonos adatait használja, de a renderer
  // interakcióit, pan- és zoom-viselkedését teljesen Cytoscape kezeli.
  function cytoscapeData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (cardGlobeContainer) cardGlobeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (cytoscapeContainer) cytoscapeContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const matchedIds = new Set(visibleNodeIds);
    return {
      nodes: matched.map((node) => ({ data: { id: node.id, label: node.title, type: node.type, importance: node.importance }, classes: node.id === state.selectedId ? 'is-selected' : '' })),
      edges: knowledgeEdges
        .filter(({ source, target }) => matchedIds.has(source) && matchedIds.has(target))
        .map((edge, index) => ({ data: { id: `cy-${edge.source}-${edge.target}-${index}`, source: edge.source, target: edge.target, weight: edge.weight } })),
    };
  }

  function renderCytoscape(animated = false) {
    const data = cytoscapeData();
    if (!cytoscapeGraph) return;
    cytoscapeGraph.elements().remove();
    if (!data) return;
    cytoscapeGraph.add([...data.nodes, ...data.edges]);
    cytoscapeGraph.layout({
      name: 'cose',
      animate: animated ? 'end' : false,
      animationDuration: 300,
      fit: true,
      padding: 36,
      nodeRepulsion: () => 4500,
      idealEdgeLength: () => 74,
      gravity: .28,
      numIter: 600,
    }).run();
  }

  function createCytoscape(attempt = 0) {
    const cytoscape = window.cytoscape;
    if (!cytoscape || !cytoscapeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createCytoscape(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      cytoscapeContainer?.setAttribute('hidden', '');
      showToast('A Cytoscape.js nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (cardGlobeContainer) cardGlobeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    cytoscapeContainer.hidden = false;
    cytoscapeGraph = cytoscape({
      container: cytoscapeContainer,
      elements: [],
      wheelSensitivity: .2,
      minZoom: MIN_ZOOM,
      maxZoom: MAX_ZOOM,
      style: [
        { selector: 'node', style: { label: 'data(label)', width: 15, height: 15, 'background-color': '#7654e6', color: '#4b4455', 'font-size': 8, 'font-weight': 700, 'text-valign': 'bottom', 'text-margin-y': 5, 'text-wrap': 'wrap', 'text-max-width': 72 } },
        { selector: 'node.is-selected', style: { width: 22, height: 22, 'background-color': '#4f28bd', 'border-width': 3, 'border-color': '#c4a9ff', color: '#39236f', 'font-size': 9 } },
        { selector: 'edge', style: { width: 1.6, 'line-color': '#b6a4e9', opacity: .62, 'curve-style': 'bezier' } },
      ],
    });
    cytoscapeGraph.on('tap', 'node', (event) => navigateTo(event.target.id()));
    cytoscapeResizeObserver = new ResizeObserver(() => {
      cytoscapeGraph?.resize();
      cytoscapeGraph?.fit(cytoscapeGraph.elements(), 36);
    });
    cytoscapeResizeObserver.observe(cytoscapeContainer);
    renderCytoscape();
  }

  // A vasturiano/3d-force-graph saját, gyári ThreeJS/WebGL rajzolója.
  // Sem node-, sem linkstílust nem állítunk be: a könyvtár natív gömbjei és élei látszanak.
  function forceGraph3DData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const nodeIds = new Set(visibleNodeIds);
    return {
      nodes: matched.map((node) => ({ ...node, name: node.title })),
      links: knowledgeEdges
        .filter(({ source, target }) => nodeIds.has(source) && nodeIds.has(target))
        .map((edge) => ({ source: edge.source, target: edge.target })),
    };
  }

  function renderForceGraph3D(animated = false) {
    const data = forceGraph3DData();
    if (!forceGraph3D) return;
    forceGraph3D.graphData(data || { nodes: [], links: [] });
    if (animated && data) {
      window.requestAnimationFrame(() => forceGraph3D?.zoomToFit(300, 34));
    }
  }

  function createForceGraph3D(attempt = 0) {
    const ForceGraph3D = window.ForceGraph3D;
    if (!ForceGraph3D || !force3dContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createForceGraph3D(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      force3dContainer?.setAttribute('hidden', '');
      showToast('A 3D Force Graph nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    force3dContainer.hidden = false;
    forceGraph3D = new ForceGraph3D(force3dContainer)
      .width(Math.max(force3dContainer.clientWidth, 320))
      .height(Math.max(force3dContainer.clientHeight, 420))
      .showNavInfo(false)
      .onNodeClick((node) => navigateTo(node.id))
      .onNodeHover((node) => { force3dContainer.style.cursor = node ? 'pointer' : 'grab'; });
    force3dResizeObserver = new ResizeObserver(() => {
      forceGraph3D?.width(Math.max(force3dContainer.clientWidth, 320)).height(Math.max(force3dContainer.clientHeight, 420));
    });
    force3dResizeObserver.observe(force3dContainer);
    renderForceGraph3D();
  }

  // A 3d-force-graph saját szimulációja dolgozik, de minden tick után a node-ok
  // gömbhéjra vetülnek. Így megmaradnak a force kapcsolatok, mégis forgatható
  // tudásgömböt kapunk a Globe.GL egyenletes atomelosztása helyett.
  function forceGraphSphereData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const nodeIds = new Set(visibleNodeIds);
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));
    forceGraphSphereNodes = matched.map((node, index) => {
      const progress = (index + .5) / Math.max(matched.length, 1);
      const y = 1 - 2 * progress;
      const ring = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = goldenAngle * index;
      return {
        ...node,
        name: node.title,
        val: Math.max(.7, (node.importance || .5) * 1.8),
        __forceSphereRenderVal: Math.max(.7, (node.importance || .5) * 1.8),
        x: Math.cos(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
        y: y * FORCE_SPHERE_SHELL_RADIUS,
        z: Math.sin(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
      };
    });
    return {
      nodes: forceGraphSphereNodes,
      links: knowledgeEdges
        .filter(({ source, target }) => nodeIds.has(source) && nodeIds.has(target))
        .map((edge) => ({ source: edge.source, target: edge.target })),
    };
  }

  function projectForceNodesToSphere() {
    forceGraphSphereNodes.forEach((node, index) => {
      const fallback = Math.abs(hash(node.id)) + index;
      const x = Number.isFinite(node.x) ? node.x : ((fallback % 17) - 8);
      const y = Number.isFinite(node.y) ? node.y : ((Math.floor(fallback / 17) % 17) - 8);
      const z = Number.isFinite(node.z) ? node.z : ((Math.floor(fallback / 289) % 17) - 8);
      const length = Math.hypot(x, y, z) || 1;
      node.x = x / length * FORCE_SPHERE_SHELL_RADIUS;
      node.y = y / length * FORCE_SPHERE_SHELL_RADIUS;
      node.z = z / length * FORCE_SPHERE_SHELL_RADIUS;
    });
  }

  function forceSphereEndpointId(endpoint) {
    return typeof endpoint === 'object' ? endpoint?.id : endpoint;
  }

  function smoothstep(start, end, value) {
    const progress = clamp((value - start) / (end - start), 0, 1);
    return progress * progress * (3 - 2 * progress);
  }

  function syncForceSphereVisualScale() {
    const camera = forceGraphSphere3D?.camera?.();
    const target = force3dSphereControls?.target || { x: 0, y: 0, z: 0 };
    const distance = Math.hypot(
      (camera?.position?.x || 0) - (target.x || 0),
      (camera?.position?.y || 0) - (target.y || 0),
      (camera?.position?.z || FORCE_SPHERE_BASE_CAMERA_DISTANCE) - (target.z || 0),
    ) || FORCE_SPHERE_BASE_CAMERA_DISTANCE;
    const scale = clamp(FORCE_SPHERE_BASE_CAMERA_DISTANCE / distance, .45, 2.25);
    mapCanvas?.style.setProperty('--force-sphere-scale', scale.toFixed(4));
  }

  // A gömb maga a CSS-rétegben sima marad. Ezzel szemben a WebGL-rétegben
  // minden orbit-forgatáskor csak az aktuális elülső félteke Atomjai és élei
  // kapnak láthatóságot; nincs polygon-mask és nincs elhúzható takaróobjektum.
  function syncForceSphereHorizonCulling(force = false) {
    if (!forceGraphSphere3D) return;
    syncForceSphereVisualScale();
    const camera = forceGraphSphere3D.camera?.();
    const target = force3dSphereControls?.target || { x: 0, y: 0, z: 0 };
    const viewX = (camera?.position?.x || 0) - (target.x || 0);
    const viewY = (camera?.position?.y || 0) - (target.y || 0);
    const viewZ = (camera?.position?.z || 0) - (target.z || 0);
    const viewLength = Math.hypot(viewX, viewY, viewZ) || 1;
    const visibleIds = new Set();
    const visualSignature = forceGraphSphereNodes.map((node) => {
      const nodeLength = Math.hypot(node.x || 0, node.y || 0, node.z || 0) || 1;
      const facing = ((node.x || 0) * viewX + (node.y || 0) * viewY + (node.z || 0) * viewZ) / (nodeLength * viewLength);
      const scaleProgress = smoothstep(FORCE_SPHERE_HORIZON, FORCE_SPHERE_SCALE_START, facing);
      const scale = FORCE_SPHERE_MIN_SCALE + (FORCE_SPHERE_MAX_SCALE - FORCE_SPHERE_MIN_SCALE) * scaleProgress;
      // A 3d-force-graph a val köbgyökéből képez sugarat, ezért köbösen
      // tároljuk a skálát: a képernyőn a grow/shrink lineárisnak hat.
      node.__forceSphereRenderVal = node.val * Math.pow(scale, 3);
      if (facing >= FORCE_SPHERE_HORIZON) visibleIds.add(node.id);
      return `${node.id}:${Math.round(scale * 18)}:${facing >= FORCE_SPHERE_HORIZON ? 1 : 0}`;
    }).sort();
    const visibleKey = visualSignature.join('|');
    if (!force && visibleKey === force3dSphereVisibilityKey) return;
    force3dSphereVisibilityKey = visibleKey;
    forceGraphSphere3D
      .nodeVal((node) => node.__forceSphereRenderVal ?? node.val)
      .nodeVisibility((node) => visibleIds.has(node.id))
      .linkVisibility((link) => visibleIds.has(forceSphereEndpointId(link.source)) && visibleIds.has(forceSphereEndpointId(link.target)));
  }

  function scheduleForceSphereHorizonCulling(force = false) {
    if (force) force3dSphereVisibilityKey = '';
    if (force3dSphereCullingFrame) return;
    force3dSphereCullingFrame = window.requestAnimationFrame(() => {
      force3dSphereCullingFrame = undefined;
      syncForceSphereHorizonCulling(force);
    });
  }

  function renderForceGraphSphere3D(animated = false) {
    const data = forceGraphSphereData();
    if (!forceGraphSphere3D) return;
    forceGraphSphere3D.graphData(data || { nodes: [], links: [] });
    if (data) window.requestAnimationFrame(() => {
      forceGraphSphere3D?.cameraPosition({ x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE }, { x: 0, y: 0, z: 0 }, animated ? 360 : 0);
      scheduleForceSphereHorizonCulling(true);
    });
  }

  function createForceGraphSphere3D(attempt = 0) {
    const ForceGraph3D = window.ForceGraph3D;
    if (!ForceGraph3D || !force3dSphereContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createForceGraphSphere3D(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      force3dSphereContainer?.setAttribute('hidden', '');
      showToast('A gömbhéjas 3D Force Graph nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    force3dSphereContainer.hidden = false;
    forceGraphSphere3D = new ForceGraph3D(force3dSphereContainer, { controlType: 'orbit' })
      .width(Math.max(force3dSphereContainer.clientWidth, 320))
      .height(Math.max(force3dSphereContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .showNavInfo(false)
      .nodeRelSize(FORCE_SPHERE_NODE_REL_SIZE)
      .nodeResolution(48)
      .nodeOpacity(1)
      .enableNodeDrag(false)
      .onNodeClick((node) => { if (node) navigateTo(node.id); })
      .onNodeHover((node) => { force3dSphereContainer.style.cursor = node ? 'pointer' : 'grab'; })
      .onEngineTick(projectForceNodesToSphere);
    force3dSphereControls = forceGraphSphere3D.controls?.();
    if (force3dSphereControls) {
      force3dSphereControls.enableDamping = true;
      force3dSphereControls.dampingFactor = .08;
      force3dSphereControls.enablePan = false;
      force3dSphereControls.autoRotate = true;
      force3dSphereControls.autoRotateSpeed = 2.2;
      force3dSphereControlsChangeHandler = () => { syncForceSphereVisualScale(); scheduleForceSphereHorizonCulling(); };
      force3dSphereControls.addEventListener('change', force3dSphereControlsChangeHandler);
    }
    force3dSphereResizeObserver = new ResizeObserver(() => {
      forceGraphSphere3D?.width(Math.max(force3dSphereContainer.clientWidth, 320)).height(Math.max(force3dSphereContainer.clientHeight, 420));
    });
    force3dSphereResizeObserver.observe(force3dSphereContainer);
    renderForceGraphSphere3D();
  }

  function syncViewportState() {
    if (!graph) return;
    state.zoom = clamp(graph.getZoom(), MIN_ZOOM, MAX_ZOOM);
    const [x, y] = graph.getPosition();
    state.panX = clamp(x, -260, 260); state.panY = clamp(y, -260, 260);
    persist();
  }

  function renderGraph(animated = false) {
    if (isFocusedG6View()) { renderFocusedG6Graph(animated); return; }
    if (isGlobeView()) { renderGlobe(animated); return; }
    if (isCardGlobeView()) { renderCardGlobe(animated); return; }
    if (isFocusedCardGlobeView()) { renderFocusedCardGlobe(animated); return; }
    if (isStaticAtomGlobeView()) { renderStaticAtomGlobe(animated); return; }
    if (isCytoscapeView()) { renderCytoscape(animated); return; }
    if (isForceSphereView()) { renderForceGraphSphere3D(animated); return; }
    if (isForce3DView()) { renderForceGraph3D(animated); return; }
    const data = localGraphData();
    if (!graphReady || !graph) return;
    if (!data) {
      graph.setData({ nodes: [], edges: [] });
      void graph.render();
      return;
    }
    graph.setData(data);
    void Promise.resolve(graph.render()).then(() => {
      if (state.visualization !== 'd3-force-3d') {
        // A G6 saját fókuszanimációja a kiválasztott node-ot középre hozza. Így a
        // natív G6 látvány megmarad, miközben koppintáskor ismét látható átmenet van.
        if (animated && typeof graph.focusElement === 'function') {
          void graph.focusElement(state.centerId, { duration: 460, easing: 'ease-in-out' }).then(syncViewportState);
          return;
        }
        graph.fitView({ padding: [36, 26, 54, 26], when: 'always' }, false);
        state.zoom = clamp(graph.getZoom(), MIN_ZOOM, MAX_ZOOM);
      } else {
        graph.zoomTo(state.zoom, animated ? { duration: 250, easing: 'ease-in-out' } : false, graph.getCanvasCenter());
        graph.translateTo([state.panX, state.panY], animated ? { duration: 250, easing: 'ease-in-out' } : false);
      }
    });
  }

  function createG6Graph(attempt = 0) {
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    mapContainer.hidden = false;
    const G6 = window.G6;
    if (!G6?.Graph) {
      if (attempt < 60) {
        window.requestAnimationFrame(() => createG6Graph(attempt + 1));
        return;
      }
      empty.hidden = false;
      mapContainer.hidden = true;
      showToast('A G6 térképmotor nem tölthető be.');
      return;
    }
    const options = {
      container: mapContainer,
      width: Math.max(mapContainer.clientWidth, 320),
      height: Math.max(mapContainer.clientHeight, 420),
      data: { nodes: [], edges: [] },
      animation: { duration: 260, easing: 'ease-in-out' },
      zoomRange: [MIN_ZOOM, MAX_ZOOM],
      behaviors: [{ type: 'drag-canvas' }, { type: 'zoom-canvas', enableOptimize: true }],
    };
    const layout = g6Layout();
    if (layout) options.layout = layout;
    graph = new G6.Graph(options);
    graph.on('node:click', (event) => {
      if (suppressGraphClick) { suppressGraphClick = false; return; }
      if (event.target?.id) navigateTo(event.target.id);
    });
    graph.on('node:pointerdown', (event) => {
      const id = event.target?.id;
      if (!id) return;
      window.clearTimeout(longPressTimer);
      longPressTimer = window.setTimeout(() => {
        suppressGraphClick = true; state.selectedId = id; state.sheetOpen = true; persist(); renderLayer();
      }, 520);
    });
    graph.on('node:pointerup', () => window.clearTimeout(longPressTimer));
    graph.on('node:pointerleave', () => window.clearTimeout(longPressTimer));
    graph.on('canvas:dblclick', () => zoomTo(state.zoom + .28));
    graph.on('aftertransform', syncViewportState);
    graphReady = true;
    resizeObserver = new ResizeObserver(() => {
      graph?.resize();
      renderGraph();
    });
    resizeObserver.observe(mapContainer);
    renderGraph();
  }

  function renderSearchResults() {
    const term = state.searchText.trim().toLocaleLowerCase('hu');
    clearSearch.hidden = !term;
    if (!term) { searchResults.hidden = true; searchResults.innerHTML = ''; return; }
    const found = knowledgeNodes.filter((node) => `${node.title} ${node.subtitle}`.toLocaleLowerCase('hu').includes(term)).slice(0, 5);
    searchResults.hidden = false;
    searchResults.innerHTML = found.length ? found.map((node) => `<button role="option" data-map-result="${node.id}" aria-label="Ugrás ide: ${node.title}"><span class="map-result-type map-result-${node.type}">${TYPE_META[node.type].icon}</span><span><strong>${node.title}</strong><small>${node.subtitle}</small></span></button>`).join('') : '<p>Nincs találat ebben a témában.</p>';
  }

  function sourceLabel(node) {
    const source = node.sourceName || 'Légzési elégtelenség jegyzet';
    const page = node.pageNumber ? ` · ${node.pageNumber}. oldal` : '';
    return `${source}${page}`;
  }

  function descriptionFor(node) {
    const descriptions = {
      do2: 'A szövetekhez időegység alatt eljutó oxigén mennyisége; a hemoglobin, a szaturáció és a perctérfogat együtt határozza meg.',
      oxygen_delivery: 'Az oxigénkínálat azt írja le, hogy mennyi oxigén jut el a szervezet szöveteihez.',
      ards: 'Súlyos, gyulladásos eredetű gázcserezavar, amelyben az alveolusok károsodása rontja az oxigenizációt.',
    };
    return descriptions[node.id] || `${node.title} a Légzési elégtelenség témán belüli ${TYPE_META[node.type].label.toLocaleLowerCase('hu')} elem. ${node.subtitle}.`;
  }

  function renderLayer() {
    const node = selectedNode();
    const parts = [];
    if (state.sheetOpen && node) {
      parts.push(`<div class="map-overlay map-sheet-overlay" data-map-action="close-sheet"><section class="map-bottom-sheet" data-map-sheet role="dialog" aria-modal="true" aria-label="${node.title} részletei"><button class="map-sheet-handle" data-sheet-handle aria-label="Részletpanel húzása vagy bezárása"></button><div class="map-sheet-heading"><div><span class="map-type-chip map-type-${node.type}">${TYPE_META[node.type].icon} ${TYPE_META[node.type].label}</span><h2>${node.title}</h2><p>${node.subtitle}</p></div><button class="map-node-favorite ${favoriteNodes.has(node.id) ? 'is-favorite' : ''}" data-map-action="toggle-node-favorite" aria-label="${node.title} kedvencnek jelölése">${favoriteNodes.has(node.id) ? '★' : '☆'}</button></div><p class="map-sheet-description">${descriptionFor(node)}</p><div class="map-detail-grid"><span><b>${relationCount(node.id)}</b> kapcsolat</span><span><b>${node.validated ? '✓' : '○'}</b> ${node.validated ? 'Validált' : 'Ellenőrzés alatt'}</span></div><div class="map-source"><span>Forrás</span><strong>${sourceLabel(node)}</strong><small>${node.noteId} · ${node.sectionId}</small></div><div class="map-sheet-actions"><button data-map-action="open-note">Jegyzet megnyitása</button><button data-map-action="show-path">Útvonal mutatása</button><button class="is-djinn" data-map-action="ask-djinn">✦ Kérdezd a Djinnt</button></div></section></div>`);
    }
    if (state.filtersOpen) {
      const types = FILTER_TYPES.map((type) => `<label class="map-filter-row"><span class="map-result-type map-result-${type}">${TYPE_META[type].icon}</span><span>${TYPE_META[type].label}</span><input type="checkbox" data-map-filter-type="${type}" ${state.selectedTypes.has(type) ? 'checked' : ''} aria-label="${TYPE_META[type].label} megjelenítése" /><i></i></label>`).join('');
      parts.push(`<div class="map-overlay map-filter-overlay" data-map-action="close-filters"><section class="map-filter-sheet" role="dialog" aria-modal="true" aria-label="Térkép szűrése"><button class="map-sheet-handle" data-map-action="close-filters" aria-label="Szűrők bezárása"></button><div class="map-panel-title"><div><span class="eyebrow">TUDÁSTÉR</span><h2>Szűrők</h2></div><button data-map-action="close-filters" aria-label="Bezárás">×</button></div><div class="map-filter-list">${types}</div><label class="map-filter-row map-filter-switch"><span>✓</span><span>Csak validált</span><input type="checkbox" data-map-filter-flag="validated" ${state.validatedOnly ? 'checked' : ''} /><i></i></label><label class="map-filter-row map-filter-switch"><span>★</span><span>Csak kedvencek</span><input type="checkbox" data-map-filter-flag="favorites" ${state.favoritesOnly ? 'checked' : ''} /><i></i></label><button class="map-reset-filters" data-map-action="reset-filters">Minden visszaállítása</button></section></div>`);
    }
    if (state.worldOpen) {
      const dots = knowledgeNodes.map((item, index) => { const p = pointFor(`${item.id}-${index}`, index, knowledgeNodes.length, 'background'); return `<circle cx="${p.x}" cy="${p.y}" r="${item.id === state.centerId ? 7 : 3.6}" class="${item.id === state.centerId ? 'is-current' : ''}" />`; }).join('');
      parts.push(`<div class="map-world-card" role="dialog" aria-label="Teljes tudástér áttekintése"><div><span>Teljes tématérkép</span><button data-map-action="close-world" aria-label="Áttekintő bezárása">×</button></div><svg viewBox="0 0 360 480" aria-hidden="true">${dots}</svg><button data-map-action="focus">Vissza az aktuális fókuszhoz</button></div>`);
    }
    if (state.noteOpen && node) {
      parts.push(`<section class="map-note-overlay" role="dialog" aria-modal="true" aria-label="${node.title} jegyzet"><header><button data-map-action="close-note" aria-label="Vissza a térképre">‹</button><div><span class="eyebrow">JEGYZET · KIEMELT SZEKCIÓ</span><h2>Légzési elégtelenség</h2></div><button data-map-action="ask-djinn" aria-label="Kérdezd a Djinnt">✦</button></header><article><span class="map-note-source">${sourceLabel(node)}</span><h1>${node.title}</h1><p class="map-note-highlight">${descriptionFor(node)}</p><p>Ez a kiemelt szekció a térképen kiválasztott tudáselemhez tartozik. A teljes jegyzetben további kapcsolódó fogalmak és forrásrészletek is elérhetők.</p><div class="map-note-links"><button data-map-action="show-path">Kapcsolódó útvonal</button><button data-map-action="close-note">Vissza a térképhez</button></div></article></section>`);
    }
    if (state.djinnOpen && node) {
      parts.push(`<div class="map-overlay map-djinn-overlay" data-map-action="close-djinn"><section class="map-djinn-sheet" role="dialog" aria-modal="true" aria-label="Djinn kérdés"><button class="map-sheet-handle" data-map-action="close-djinn" aria-label="Djinn panel bezárása"></button><div class="map-djinn-heading"><span>✦</span><div><h2>Djinn</h2><p>Kérdezz erről: <b>${node.title}</b></p></div></div><form data-map-djinn-form><div class="map-djinn-input"><input aria-label="Kérdés a Djinnhez" placeholder="Mit szeretnél tudni?" /><button aria-label="Kérdés elküldése">↑</button></div></form><div class="map-djinn-quick"><button data-map-djinn="explain">Magyarázd el</button><button data-map-djinn="related">Kapcsolódó tudás</button><button data-map-djinn="source">Mutasd a forrást</button></div><div class="map-djinn-answer" data-map-djinn-answer hidden></div></section></div>`);
    }
    layer.innerHTML = parts.join('');
    attachSheetDrag();
  }

  function attachSheetDrag() {
    const sheet = layer.querySelector('[data-map-sheet]');
    const handle = layer.querySelector('[data-sheet-handle]');
    if (!sheet || !handle) return;
    let startY = 0; let offset = 0;
    handle.addEventListener('pointerdown', (event) => {
      startY = event.clientY; offset = 0; handle.setPointerCapture?.(event.pointerId);
      const move = (moveEvent) => { offset = Math.max(0, moveEvent.clientY - startY); sheet.style.transform = `translateY(${offset}px)`; };
      const up = () => { sheet.style.transform = ''; if (offset > 96) { state.sheetOpen = false; persist(); renderLayer(); } handle.removeEventListener('pointermove', move); handle.removeEventListener('pointerup', up); };
      handle.addEventListener('pointermove', move); handle.addEventListener('pointerup', up, { once: true });
    });
  }

  function navigateTo(id, options = {}) {
    if (!nodeById.has(id)) return;
    if (options.breadcrumbIndex !== undefined) state.history = state.history.slice(0, options.breadcrumbIndex + 1);
    else if (!options.noHistory && state.history[state.history.length - 1] !== id) state.history.push(id);
    if (state.history.length > 12) state.history = state.history.slice(-12);
    state.centerId = id; state.selectedId = id; state.panX = 0; state.panY = 0;
    if (isFocusedCardGlobeView()) state.focusedGlobeId = id;
    state.pathMode = options.keepPath ? state.pathMode : false;
    state.sheetOpen = false;
    state.searchText = '';
    search.value = '';
    renderSearchResults(); renderGraph(true); persist(); renderLayer();
  }

  function goBack() {
    if (state.history.length < 2) return;
    state.history.pop();
    const previous = state.history[state.history.length - 1];
    state.centerId = previous; state.selectedId = previous; state.panX = 0; state.panY = 0; state.pathMode = false;
    if (isFocusedCardGlobeView()) state.focusedGlobeId = previous;
    renderGraph(true); persist(); renderLayer();
  }

  function resetFilters() {
    state.selectedTypes = new Set(FILTER_TYPES); state.validatedOnly = false; state.favoritesOnly = false;
    renderGraph(); persist(); renderLayer(); showToast('A térképszűrők visszaállítva.');
  }

  function zoomTo(nextZoom) {
    const next = clamp(nextZoom, MIN_ZOOM, MAX_ZOOM);
    if (next === state.zoom) return;
    const previous = state.zoom;
    state.zoom = next;
    if (isGlobeView() && globe) {
      const pov = globe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      globe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
    } else if (isCardGlobeView() && cardGlobe) {
      const pov = cardGlobe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      cardGlobe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
    } else if (isFocusedCardGlobeView() && focusedGlobe) {
      const pov = focusedGlobe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      focusedGlobe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
    } else if (isStaticAtomGlobeView() && staticAtomGlobe) {
      const pov = staticAtomGlobe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      staticAtomGlobe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
    } else if (isCytoscapeView() && cytoscapeGraph) {
      cytoscapeGraph.zoom({ level: next, renderedPosition: { x: cytoscapeContainer.clientWidth / 2, y: cytoscapeContainer.clientHeight / 2 } });
    } else if (isForceSphereView() && forceGraphSphere3D) {
      const camera = forceGraphSphere3D.cameraPosition();
      const multiplier = next > previous ? .82 : 1.2;
      forceGraphSphere3D.cameraPosition({ x: camera.x * multiplier, y: camera.y * multiplier, z: camera.z * multiplier }, undefined, 180);
    } else if (isForce3DView() && forceGraph3D) {
      const camera = forceGraph3D.cameraPosition();
      const multiplier = next > previous ? .82 : 1.2;
      forceGraph3D.cameraPosition({ x: camera.x * multiplier, y: camera.y * multiplier, z: camera.z * multiplier }, undefined, 180);
    } else if (graph) {
      void graph.zoomTo(next, { duration: 180, easing: 'ease-out' }, graph.getCanvasCenter());
    }
    persist();
  }

  function resetFocus() {
    state.panX = 0; state.panY = 0; state.zoom = 1;
    if (isGlobeView() && globe) {
      globe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 260);
    } else if (isCardGlobeView() && cardGlobe) {
      cardGlobe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 260);
    } else if (isFocusedCardGlobeView() && focusedGlobe) {
      const position = PERSISTENT_GLOBE_COORDINATES.get(state.focusedGlobeId);
      focusedGlobe.pointOfView({ lat: position.lat, lng: position.lng, altitude: 2.1 }, 260);
    } else if (isStaticAtomGlobeView() && staticAtomGlobe) {
      staticAtomGlobe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 260);
    } else if (isCytoscapeView() && cytoscapeGraph) {
      cytoscapeGraph.fit(cytoscapeGraph.elements(), 36);
    } else if (isForceSphereView() && forceGraphSphere3D) {
      forceGraphSphere3D.cameraPosition({ x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE }, { x: 0, y: 0, z: 0 }, 260);
    } else if (isForce3DView() && forceGraph3D) {
      forceGraph3D.zoomToFit(260, 34);
    } else if (isFocusedG6View() && graph) {
      void graph.zoomTo(1, { duration: 220, easing: 'ease-in-out' }, graph.getCanvasCenter());
      if (typeof graph.focusElement === 'function') {
        void graph.focusElement(state.centerId, { duration: 260, easing: 'ease-in-out' }).then(syncViewportState);
      }
    } else if (graph) {
      if (state.visualization === 'd3-force-3d') {
        void graph.zoomTo(1, { duration: 220, easing: 'ease-in-out' }, graph.getCanvasCenter());
        void graph.translateTo([0, 0], { duration: 220, easing: 'ease-in-out' });
      } else {
        void graph.fitView({ padding: [36, 26, 54, 26], when: 'always' }, { duration: 220, easing: 'ease-in-out' });
      }
    }
    persist(); showToast('A teljes gráf újra fókuszba került.');
  }

  function onClick(event) {
    if (state.layoutMenuOpen && !event.target.closest('.map-layout-picker')) {
      state.layoutMenuOpen = false;
      updateVisualizationSelector();
    }
    const result = event.target.closest('[data-map-result]');
    if (result) { navigateTo(result.dataset.mapResult); return; }
    const crumb = event.target.closest('[data-map-breadcrumb]');
    if (crumb) { navigateTo(state.history[Number(crumb.dataset.mapBreadcrumb)], { breadcrumbIndex: Number(crumb.dataset.mapBreadcrumb), keepPath: true }); return; }
    const panel = event.target.closest('.map-bottom-sheet, .map-filter-sheet, .map-djinn-sheet');
    const panelAction = event.target.closest('[data-map-action]');
    if (panel && (!panelAction || !panel.contains(panelAction))) return;
    const action = event.target.closest('[data-map-action]')?.dataset.mapAction;
    if (!action) return;
    if (action === 'clear-search') { state.searchText = ''; search.value = ''; renderSearchResults(); search.focus(); }
    if (action === 'toggle-layout-menu') { state.layoutMenuOpen = !state.layoutMenuOpen; updateVisualizationSelector(); }
    if (action === 'set-visualization') setVisualization(event.target.closest('[data-map-visualization]')?.dataset.mapVisualization);
    if (action === 'history-back') goBack();
    if (action === 'zoom-in') zoomTo(state.zoom + .22);
    if (action === 'zoom-out') zoomTo(state.zoom - .22);
    if (action === 'focus') { state.worldOpen = false; resetFocus(); renderLayer(); }
    if (action === 'open-sheet') { state.sheetOpen = true; state.filtersOpen = false; renderLayer(); persist(); }
    if (action === 'close-sheet') { state.sheetOpen = false; renderLayer(); persist(); }
    if (action === 'toggle-node-favorite') { const id = selectedNode().id; favoriteNodes.has(id) ? favoriteNodes.delete(id) : favoriteNodes.add(id); persist(); renderLayer(); renderGraph(); }
    if (action === 'show-path') { state.pathMode = state.history.length > 1; state.sheetOpen = false; state.noteOpen = false; renderGraph(); renderLayer(); persist(); showToast(state.pathMode ? 'A bejárt tudásútvonal kiemelve.' : 'Az útvonal az első kapcsolódó elem kiválasztása után jelenik meg.'); }
    if (action === 'close-path') { state.pathMode = false; renderGraph(); persist(); }
    if (action === 'filters') { state.filtersOpen = true; state.sheetOpen = false; renderLayer(); }
    if (action === 'close-filters') { state.filtersOpen = false; renderLayer(); }
    if (action === 'reset-filters') resetFilters();
    if (action === 'world') { state.worldOpen = true; renderLayer(); }
    if (action === 'close-world') { state.worldOpen = false; renderLayer(); }
    if (action === 'open-note') { state.noteOpen = true; state.sheetOpen = false; renderLayer(); }
    if (action === 'close-note') { state.noteOpen = false; renderLayer(); }
    if (action === 'ask-djinn') { state.djinnOpen = true; state.sheetOpen = false; state.noteOpen = false; renderLayer(); }
    if (action === 'close-djinn') { state.djinnOpen = false; renderLayer(); }
    if (action === 'toggle-topic-favorite') { topicIsFavorite = !topicIsFavorite; updateTopicFavorite(); persist(); showToast(topicIsFavorite ? 'A téma a kedvenceid közé került.' : 'A téma kikerült a kedvencek közül.'); }
    if (action === 'topic-menu') { const open = topicMenu.hidden; topicMenu.hidden = !open; topicMenuButton.setAttribute('aria-expanded', String(open)); }
    if (action === 'topic-edit' || action === 'topic-share' || action === 'topic-archive') { topicMenu.hidden = true; topicMenuButton.setAttribute('aria-expanded', 'false'); showToast({ 'topic-edit': 'Téma szerkesztése megnyitva.', 'topic-share': 'Megosztási link előkészítve.', 'topic-archive': 'A téma archiválva a mockupban.' }[action]); }
  }

  function onChange(event) {
    const type = event.target.dataset.mapFilterType;
    const flag = event.target.dataset.mapFilterFlag;
    if (type) { event.target.checked ? state.selectedTypes.add(type) : state.selectedTypes.delete(type); renderGraph(); persist(); }
    if (flag === 'validated') { state.validatedOnly = event.target.checked; renderGraph(); persist(); }
    if (flag === 'favorites') { state.favoritesOnly = event.target.checked; renderGraph(); persist(); }
  }

  function onSubmit(event) {
    const form = event.target.closest('[data-map-djinn-form]');
    if (!form) return;
    event.preventDefault();
    const question = form.querySelector('input').value.trim() || 'Magyarázd el';
    renderDjinnAnswer(question);
  }

  function renderDjinnAnswer(intent) {
    const answer = layer.querySelector('[data-map-djinn-answer]');
    if (!answer) return;
    const node = selectedNode();
    const normalized = intent.toLocaleLowerCase('hu');
    let response = `${node.title}: ${descriptionFor(node)}`;
    if (normalized.includes('kapcsol')) response = `${node.title} ${relationCount(node.id)} közvetlen kapcsolattal rendelkezik. A legerősebb útvonalak a térképen körülötte jelennek meg.`;
    if (normalized.includes('forrás')) response = `Forrás: ${sourceLabel(node)}. A releváns szekció azonosítója: ${node.sectionId}.`;
    answer.hidden = false; answer.textContent = response;
  }

  function onDjinnQuick(event) {
    const button = event.target.closest('[data-map-djinn]');
    if (!button) return;
    const label = { explain: 'Magyarázd el', related: 'Kapcsolódó tudás', source: 'Mutasd a forrást' }[button.dataset.mapDjinn];
    renderDjinnAnswer(label);
  }

  function onKeyDown(event) {
    if (event.key === 'Escape') {
      state.sheetOpen = false; state.filtersOpen = false; state.worldOpen = false; state.noteOpen = false; state.djinnOpen = false; state.layoutMenuOpen = false; topicMenu.hidden = true; updateVisualizationSelector(); renderLayer(); persist(); return;
    }
    if (event.target.matches?.('input')) return;
    if (event.key === 'Enter' && visibleNodeIds.length) {
      event.preventDefault();
      navigateTo(visibleNodeIds[keyboardIndex] || state.selectedId);
      return;
    }
    if (event.key === 'ArrowLeft' && !event.target.matches('input')) { event.preventDefault(); goBack(); return; }
    if (!['ArrowUp', 'ArrowDown', 'ArrowRight'].includes(event.key)) return;
    if (!visibleNodeIds.length) return;
    event.preventDefault();
    const delta = event.key === 'ArrowUp' ? -1 : 1;
    keyboardIndex = (keyboardIndex + delta + visibleNodeIds.length) % visibleNodeIds.length;
    state.selectedId = visibleNodeIds[keyboardIndex];
    showToast(`${nodeById.get(state.selectedId).title} kijelölve. Enter: navigáció.`);
  }

  search.addEventListener('input', () => { state.searchText = search.value; renderSearchResults(); });
  screen.addEventListener('click', onClick);
  screen.addEventListener('change', onChange);
  screen.addEventListener('submit', onSubmit);
  screen.addEventListener('click', onDjinnQuick);
  screen.addEventListener('keydown', onKeyDown);

  updateTopicFavorite(); updateVisualizationSelector(); renderSearchResults(); renderLayer();
  window.requestAnimationFrame(createActiveRenderer);
  return () => {
    window.clearTimeout(longPressTimer); persist();
    screen.removeEventListener('click', onClick); screen.removeEventListener('change', onChange); screen.removeEventListener('submit', onSubmit); screen.removeEventListener('click', onDjinnQuick);
    screen.removeEventListener('keydown', onKeyDown);
    destroyG6Graph();
    destroyGlobe();
    destroyCardGlobe();
    destroyFocusedCardGlobe();
    destroyStaticAtomGlobe();
    destroyCytoscape();
    destroyForceGraph3D();
    destroyForceGraphSphere3D();
  };
}
