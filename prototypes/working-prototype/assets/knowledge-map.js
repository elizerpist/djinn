/*
 * Djinn knowledge map prototype
 * -----------------------------
 * The two datasets below are deliberately independent from the renderer. In the
 * Flutter/ObjectBox app they can be replaced by Note/Section records and their
 * Navigation Graph edges without changing the interaction layer.
 */

import * as THREE from './vendor/three.module.min.js?rev=92';
import { buildFocusedG6V2RenderData } from './focused-g6-v2-render-data.js?rev=1';

// three-globe böngészős UMD buildje a globális THREE példányt használja.
// A projekt Three.js-je modulból érkezik, ezért előbb ugyanazt a példányt tesszük
// globálissá, majd egyszer töltjük be a részletes bolygó objektumot. Így nem jön
// létre második renderer vagy külön Globe.gl canvas.
if (typeof window !== 'undefined') {
  window.THREE = THREE;
  // A részletes bolygó opcionális LOD-réteg. Klasszikus scriptként töltjük be,
  // mert a ThreeGlobe UMD build így biztosan a globális, azonos Three példányt
  // használja, miközben a force-galaxis indulását nem blokkoljuk.
  if (!window.ThreeGlobe) {
    const threeGlobeScript = document.createElement('script');
    threeGlobeScript.src = './vendor/three-globe.min.js?rev=3';
    threeGlobeScript.async = true;
    threeGlobeScript.onerror = (error) => console.warn('ThreeGlobe LOD réteg nem tölthető be:', error);
    document.head.appendChild(threeGlobeScript);
  }
}

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

// A dropdown minden grafikus motorja ezt az egy, közös mock-adatbázist kapja.
// A csoporton belüli láncok a lokális tudásutat, a „közösségi híd” élek pedig
// a távolabbi témák közötti valódi keresztkapcsolatokat reprezentálják.
const KNOWLEDGE_EXPANSION_GROUPS = [
  { anchor: 'oxygenation', atoms: [['alveolar_ventilation', 'Alveoláris ventiláció', 'concept', 'Hatékony légtércsere'], ['minute_ventilation', 'Perctérfogat-ventiláció', 'measurement', 'Légzési percvolumen'], ['dead_space', 'Holttér', 'concept', 'Nem perfundált légtér'], ['lung_compliance', 'Tüdőcompliance', 'measurement', 'Tágulékonyság']] },
  { anchor: 'do2', atoms: [['fio2', 'FiO₂', 'measurement', 'Belégzett oxigénfrakció'], ['oxygen_content', 'Artériás oxigéntartalom', 'measurement', 'CaO₂'], ['tissue_perfusion', 'Szöveti perfúzió', 'concept', 'Kapilláris áramlás'], ['mixed_venous_oxygen', 'Vegyes vénás oxigén', 'measurement', 'SvO₂']] },
  { anchor: 'abg', atoms: [['ph', 'pH', 'measurement', 'Savasság mértéke'], ['bicarbonate', 'Bikarbonát', 'measurement', 'Metabolikus komponens'], ['base_excess', 'Bázistöbblet', 'measurement', 'Metabolikus eltérés'], ['anion_gap', 'Anion gap', 'measurement', 'Nem mért anionok']] },
  { anchor: 'mechanical_ventilation', atoms: [['airway_resistance', 'Légúti ellenállás', 'measurement', 'Áramlási akadály'], ['plateau_pressure', 'Platónyomás', 'measurement', 'Alveoláris nyomás'], ['driving_pressure', 'Driving pressure', 'measurement', 'Platón mínusz PEEP'], ['intrinsic_peep', 'Auto-PEEP', 'condition', 'Belső pozitív nyomás']] },
  { anchor: 'ards', atoms: [['berlin_criteria', 'Berlin kritériumok', 'concept', 'ARDS besorolás'], ['prone_position', 'Hason fektetés', 'procedure', 'Prone pozicionálás'], ['protective_ventilation', 'Protektív ventiláció', 'treatment', 'Alacsony tidal volume'], ['recruitment_maneuver', 'Recruitment manőver', 'procedure', 'Alveolus toborzás']] },
  { anchor: 'copd', atoms: [['copd_exacerbation', 'COPD exacerbáció', 'condition', 'Akut romlás'], ['bronchodilator', 'Bronchodilatátor', 'treatment', 'Hörgőtágítás'], ['corticosteroid', 'Kortikoszteroid', 'treatment', 'Gyulladáscsökkentés'], ['secretion_clearance', 'Váladékürítés', 'procedure', 'Légúti toalett']] },
  { anchor: 'pneumonia', atoms: [['respiratory_pathogen', 'Légúti kórokozó', 'source', 'Infekció eredete'], ['alveolar_inflammation', 'Alveoláris gyulladás', 'condition', 'Gázcsere-romlás'], ['consolidation', 'Konszolidáció', 'condition', 'Légtelen tüdőterület'], ['aspiration', 'Aspiráció', 'condition', 'Belégzett gyomortartalom']] },
  { anchor: 'abg', atoms: [['pulse_oximetry', 'Pulzoximetria', 'measurement', 'Folyamatos szaturáció'], ['capnography', 'Kapnográfia', 'measurement', 'Kilégzett CO₂'], ['lactate_clearance', 'Laktát clearance', 'measurement', 'Perfúziós válasz'], ['hemodynamic_monitoring', 'Hemodinamikai monitorozás', 'procedure', 'Keringési trendek']] },
  { anchor: 'mechanical_ventilation', atoms: [['ventilator_pneumonia', 'Ventilátor-asszociált pneumonia', 'condition', 'VAP szövődmény'], ['barotrauma', 'Barotrauma', 'condition', 'Nyomási sérülés'], ['volutrauma', 'Volutrauma', 'condition', 'Térfogati sérülés'], ['oxygen_toxicity', 'Oxigéntoxicitás', 'condition', 'Magas FiO₂ kockázat']] },
  { anchor: 'oxygen_therapy', atoms: [['high_flow_oxygen', 'High-flow oxigén', 'treatment', 'Nagy áramlású támogatás'], ['airway_suction', 'Légúti szívás', 'procedure', 'Váladék eltávolítás'], ['sedation', 'Szedáció', 'treatment', 'Komfort és szinkron'], ['weaning', 'Weaning', 'procedure', 'Gépi lélegeztetés elhagyása']] },
  { anchor: 'abg', atoms: [['chest_xray', 'Mellkasröntgen', 'source', 'Ágy melletti képalkotás'], ['ct_thorax', 'Mellkas CT', 'source', 'Részletes parenchyma'], ['lung_ultrasound', 'Tüdő ultrahang', 'source', 'B-vonalak és folyadék'], ['sputum_culture', 'Köpettenyésztés', 'source', 'Mikrobiológiai forrás']] },
  { anchor: 'resp_failure', atoms: [['dyspnea', 'Dyspnoe', 'symptom', 'Légszomj'], ['accessory_muscles', 'Segédlégző izmok', 'symptom', 'Fokozott légzési munka'], ['respiratory_fatigue', 'Légzési izomfáradás', 'condition', 'Ventilációs kimerülés'], ['fever', 'Láz', 'symptom', 'Fertőzéses jel']] },
  { anchor: 'resp_failure', atoms: [['icu_admission', 'Intenzív osztályos felvétel', 'procedure', 'Emelt szintű ellátás'], ['mortality_risk', 'Mortalitási kockázat', 'concept', 'Prognosztikai jel'], ['therapy_response', 'Terápiás válasz', 'measurement', 'Állapotváltozás'], ['follow_up', 'Követés', 'procedure', 'Kontroll és rehabilitáció']] },
  { anchor: 'cardiac_output', atoms: [['shock', 'Sokk', 'condition', 'Kritikus hipoperfúzió'], ['sepsis', 'Szepszis', 'condition', 'Szisztémás infekció'], ['fluid_balance', 'Folyadékegyensúly', 'measurement', 'Bevitel és ürítés'], ['vasopressor', 'Vazopresszor', 'treatment', 'Értónus-támogatás']] },
  { anchor: 'paco2', atoms: [['co2_narcosis', 'CO₂ narkózis', 'condition', 'Súlyos hiperkapnia'], ['delirium', 'Delírium', 'symptom', 'Akut tudatzavar'], ['gcs', 'Glasgow Coma Scale', 'measurement', 'Tudatosság pontszám'], ['airway_protection', 'Légútvédelem', 'procedure', 'Aspiráció megelőzése']] },
  { anchor: 'mechanical_ventilation', atoms: [['ventilator_mode', 'Ventilátor mód', 'procedure', 'Légzési stratégia'], ['pressure_support', 'Nyomástámogatás', 'treatment', 'Spontán légzés segítése'], ['flow_trigger', 'Flow trigger', 'measurement', 'Belégzési indítás'], ['humidification', 'Párásítás', 'procedure', 'Légúti nyálkahártya védelem']] },
  { anchor: 'peep', atoms: [['peep_titration_note', 'PEEP titrálási jegyzet', 'source', 'Beállítási döntések'], ['ards_summary', 'ARDS összefoglaló', 'source', 'Kiemelt tudásjegyzet'], ['blood_gas_worksheet', 'Vérgáz munkalap', 'source', 'Értelmezési segédlet'], ['oxygen_protocol', 'Oxigén protokoll', 'source', 'Ellátási útmutató']] },
];

let previousExpansionIds = [];
KNOWLEDGE_EXPANSION_GROUPS.forEach((group, groupIndex) => {
  const ids = group.atoms.map(([id, title, type, subtitle], atomIndex) => {
    knowledgeNodes.push({
      id,
      title,
      type,
      subtitle,
      noteId: `note_expand_${String(groupIndex + 1).padStart(2, '0')}`,
      sectionId: `section_expand_${String(groupIndex * 4 + atomIndex + 1).padStart(3, '0')}`,
      importance: Number((.58 + ((groupIndex * 7 + atomIndex * 5) % 31) / 100).toFixed(2)),
      validated: (groupIndex + atomIndex) % 5 !== 0,
    });
    return id;
  });
  knowledgeEdges.push({ source: group.anchor, target: ids[0], weight: .74, bidirectional: true, label: 'témakapcsolat' });
  knowledgeEdges.push({ source: group.anchor, target: ids[2], weight: .61, bidirectional: true, label: 'keresztkapcsolat' });
  for (let index = 0; index < ids.length - 1; index += 1) {
    knowledgeEdges.push({ source: ids[index], target: ids[index + 1], weight: Number((.7 - index * .04).toFixed(2)), bidirectional: true, label: 'helyi tudásút' });
  }
  if (previousExpansionIds.length) {
    knowledgeEdges.push({ source: previousExpansionIds[3], target: ids[1], weight: .57, bidirectional: true, label: 'közösségi híd' });
  }
  previousExpansionIds = ids;
});
knowledgeEdges.push(
  { source: 'oxygen_protocol', target: 'high_flow_oxygen', weight: .66, bidirectional: true, label: 'közösségi híd' },
  { source: 'berlin_criteria', target: 'lung_ultrasound', weight: .62, bidirectional: true, label: 'közösségi híd' },
);

// A második száz Atom nagyobb, több közösséget összekötő térképet ad minden
// renderernek. A kártyás lazy nézetek továbbra is csak a belőle kiválasztott
// lokális részgráfot jelenítik meg.
const KNOWLEDGE_SCALE_GROUPS = [
  { id: 'respiratory_mechanics', title: 'Légzési mechanika', anchor: 'resp_failure', subtitle: 'Légzési munka és ventiláció' },
  { id: 'pulmonary_circulation', title: 'Tüdőkeringés', anchor: 'cardiac_output', subtitle: 'Perfúziós útvonalak' },
  { id: 'oxygen_transport', title: 'Oxigéntranszport', anchor: 'oxygen_delivery', subtitle: 'Oxigénszállítás a szövetekhez' },
  { id: 'clinical_resp_exam', title: 'Klinikai légzésvizsgálat', anchor: 'resp_failure', subtitle: 'Megfigyelés és fizikális jelek' },
  { id: 'airway_obstruction', title: 'Légúti obstrukció', anchor: 'copd', subtitle: 'Áramlási akadályok' },
  { id: 'gas_exchange', title: 'Gázcsere', anchor: 'diffusion_disorder', subtitle: 'Diffúzió és ventiláció-perfúzió' },
  { id: 'ards_management', title: 'ARDS ellátás', anchor: 'ards', subtitle: 'Intenzív terápiás stratégia' },
  { id: 'respiratory_infection', title: 'Légúti infekció', anchor: 'pneumonia', subtitle: 'Fertőzéses tüdőkárosodás' },
  { id: 'pulmonary_fluid', title: 'Tüdőfolyadék', anchor: 'pulmonary_edema', subtitle: 'Alveoláris folyadék és pangás' },
  { id: 'niv_strategy', title: 'NIV stratégia', anchor: 'niv', subtitle: 'Non-invazív légzéstámogatás' },
  { id: 'invasive_ventilation', title: 'Invazív ventiláció', anchor: 'mechanical_ventilation', subtitle: 'Gépi légzéstámogatás' },
  { id: 'oxygen_support', title: 'Oxigéntámogatás', anchor: 'oxygen_therapy', subtitle: 'Oxigénadagolási eszközök' },
  { id: 'blood_gas_reasoning', title: 'Vérgáz értelmezés', anchor: 'abg', subtitle: 'Artériás vérgázból levont következtetések' },
  { id: 'acid_base_reasoning', title: 'Sav-bázis értelmezés', anchor: 'acid_base', subtitle: 'Primer eltérések és kompenzáció' },
  { id: 'tissue_hypoxia', title: 'Szöveti oxigénhiány', anchor: 'lactate', subtitle: 'Oxigénadósság és perfúzió' },
  { id: 'airway_consciousness', title: 'Tudat és légút', anchor: 'altered_consciousness', subtitle: 'Légútbiztonság és neurológia' },
  { id: 'hemodynamic_support', title: 'Hemodinamikai támogatás', anchor: 'cardiac_output', subtitle: 'Keringési stabilizálás' },
  { id: 'icu_workflow', title: 'Intenzív workflow', anchor: 'icu_admission', subtitle: 'Felvétel, monitorozás és döntések' },
  { id: 'diagnostic_pathway', title: 'Diagnosztikai útvonal', anchor: 'chest_xray', subtitle: 'Képalkotás és mintavétel' },
  { id: 'respiratory_recovery', title: 'Légzési rehabilitáció', anchor: 'weaning', subtitle: 'Felépülés és leválasztás' },
];

const KNOWLEDGE_SCALE_ROLES = [
  { id: 'core', title: 'alapfogalom', type: 'concept', subtitle: 'A témakör központi fogalma' },
  { id: 'measure', title: 'mérés', type: 'measurement', subtitle: 'Követéshez használt mérőszám' },
  { id: 'mechanism', title: 'mechanizmus', type: 'condition', subtitle: 'A változás mögötti folyamat' },
  { id: 'intervention', title: 'ellátási lépés', type: 'treatment', subtitle: 'Kapcsolódó terápiás lehetőség' },
  { id: 'reference', title: 'jegyzet', type: 'source', subtitle: 'Hivatkozható tudásforrás' },
];

let previousScaleIds = [];
KNOWLEDGE_SCALE_GROUPS.forEach((group, groupIndex) => {
  const ids = KNOWLEDGE_SCALE_ROLES.map((role, roleIndex) => {
    const id = `${group.id}_${role.id}`;
    knowledgeNodes.push({
      id,
      title: `${group.title} · ${role.title}`,
      type: role.type,
      subtitle: `${group.subtitle} · ${role.subtitle}`,
      noteId: `note_scale_${String(groupIndex + 1).padStart(2, '0')}`,
      sectionId: `section_scale_${String(groupIndex * KNOWLEDGE_SCALE_ROLES.length + roleIndex + 1).padStart(3, '0')}`,
      importance: Number((.56 + ((groupIndex * 11 + roleIndex * 7) % 34) / 100).toFixed(2)),
      validated: (groupIndex + roleIndex) % 6 !== 0,
    });
    return id;
  });
  knowledgeEdges.push(
    { source: group.anchor, target: ids[0], weight: .76, bidirectional: true, label: 'témakapcsolat' },
    { source: group.anchor, target: ids[2], weight: .66, bidirectional: true, label: 'keresztkapcsolat' },
    { source: ids[0], target: ids[3], weight: .58, bidirectional: true, label: 'helyi összefüggés' },
  );
  for (let index = 0; index < ids.length - 1; index += 1) {
    knowledgeEdges.push({ source: ids[index], target: ids[index + 1], weight: Number((.73 - index * .04).toFixed(2)), bidirectional: true, label: 'helyi tudásút' });
  }
  if (previousScaleIds.length) {
    knowledgeEdges.push({ source: previousScaleIds[4], target: ids[1], weight: .56, bidirectional: true, label: 'közösségi híd' });
  }
previousScaleIds = ids;
});

// A harmadik bővítés a nagy grafikus motorok terhelési és navigációs próbájához
// ad még ötszáz Atomot. Ezek a teljes adathalmaz részei, de a lazy nézetek
// továbbra is csak a lokálisan releváns részgráfot kérik le belőle.
const KNOWLEDGE_DEEP_GROUPS = [
  { id: 'acute_assessment', title: 'Akut állapotfelmérés', anchor: 'resp_failure', subtitle: 'Első klinikai döntések' },
  { id: 'hypoxemia_pathway', title: 'Hipoxémia útvonala', anchor: 'hypoxemic_failure', subtitle: 'Oxigenizációs eltérés' },
  { id: 'hypercapnia_pathway', title: 'Hiperkapnia útvonala', anchor: 'hypercapnic_failure', subtitle: 'Ventilációs elégtelenség' },
  { id: 'oxygen_delivery_chain', title: 'Oxigénkínálat lánca', anchor: 'oxygen_delivery', subtitle: 'Keringési oxigénszállítás' },
  { id: 'oxygen_consumption_chain', title: 'Oxigénigény lánca', anchor: 'oxygen_demand', subtitle: 'Szöveti felhasználás' },
  { id: 'hemoglobin_context', title: 'Hemoglobin kontextus', anchor: 'hemoglobin', subtitle: 'Oxigénkötés és kapacitás' },
  { id: 'saturation_context', title: 'Szaturáció kontextus', anchor: 'sao2', subtitle: 'Artériás oxigenizáció' },
  { id: 'pao2_context', title: 'PaO₂ értelmezés', anchor: 'pao2', subtitle: 'Parciális oxigénnyomás' },
  { id: 'paco2_context', title: 'PaCO₂ értelmezés', anchor: 'paco2', subtitle: 'Ventilációs jelző' },
  { id: 'perfusion_context', title: 'Perfúzió kontextus', anchor: 'cardiac_output', subtitle: 'Keringési áramlás' },
  { id: 'ards_detail', title: 'ARDS részletek', anchor: 'ards', subtitle: 'Súlyos tüdőkárosodás' },
  { id: 'copd_detail', title: 'COPD részletek', anchor: 'copd', subtitle: 'Obstruktív légúti állapot' },
  { id: 'pneumonia_detail', title: 'Pneumonia részletek', anchor: 'pneumonia', subtitle: 'Fertőzéses légzőszervi állapot' },
  { id: 'edema_detail', title: 'Tüdőödéma részletek', anchor: 'pulmonary_edema', subtitle: 'Alveoláris folyadék' },
  { id: 'niv_detail', title: 'NIV részletek', anchor: 'niv', subtitle: 'Non-invazív támogatás' },
  { id: 'ventilation_detail', title: 'Gépi ventiláció részletek', anchor: 'mechanical_ventilation', subtitle: 'Invazív légzéstámogatás' },
  { id: 'oxygen_therapy_detail', title: 'Oxigénterápia részletek', anchor: 'oxygen_therapy', subtitle: 'Oxigénadagolási stratégiák' },
  { id: 'peep_detail', title: 'PEEP részletek', anchor: 'peep', subtitle: 'Alveoláris nyomástámogatás' },
  { id: 'gas_exchange_detail', title: 'Gázcsere részletek', anchor: 'vq_mismatch', subtitle: 'Ventiláció és perfúzió' },
  { id: 'diffusion_detail', title: 'Diffúzió részletek', anchor: 'diffusion_disorder', subtitle: 'Alveolo-kapilláris átjutás' },
  { id: 'acid_base_detail', title: 'Sav-bázis részletek', anchor: 'acid_base', subtitle: 'Kompenzáció és eltérés' },
  { id: 'lactate_detail', title: 'Laktát részletek', anchor: 'lactate', subtitle: 'Szöveti oxigénadósság' },
  { id: 'abg_detail', title: 'Vérgáz részletek', anchor: 'abg', subtitle: 'Artériás mintavétel és értelmezés' },
  { id: 'icu_detail', title: 'Intenzív ellátás részletek', anchor: 'icu_admission', subtitle: 'Magas szintű megfigyelés' },
  { id: 'recovery_detail', title: 'Légzési felépülés részletek', anchor: 'weaning', subtitle: 'Leválasztás és követés' },
];

const KNOWLEDGE_DEEP_ROLES = [
  { id: 'core', title: 'alapfogalom', type: 'concept', subtitle: 'A témakör központi tudáseleme' },
  { id: 'anatomy', title: 'anatómia', type: 'concept', subtitle: 'Kapcsolódó szerkezeti háttér' },
  { id: 'physiology', title: 'élettan', type: 'concept', subtitle: 'Normális működési összefüggés' },
  { id: 'cause', title: 'okok', type: 'condition', subtitle: 'Lehetséges kiváltó tényezők' },
  { id: 'symptom', title: 'tünet', type: 'symptom', subtitle: 'Klinikailag megfigyelhető jel' },
  { id: 'measurement', title: 'mérés', type: 'measurement', subtitle: 'Követéshez használt paraméter' },
  { id: 'sample', title: 'mintavétel', type: 'procedure', subtitle: 'Vizsgálati adat nyerése' },
  { id: 'interpretation', title: 'értelmezés', type: 'concept', subtitle: 'Az eredmény értelmezési kerete' },
  { id: 'mechanism', title: 'mechanizmus', type: 'condition', subtitle: 'A háttérben zajló folyamat' },
  { id: 'differential', title: 'differenciálás', type: 'concept', subtitle: 'Elkülönítést segítő szempont' },
  { id: 'risk', title: 'kockázat', type: 'condition', subtitle: 'Romlást előrejelző tényező' },
  { id: 'monitoring', title: 'monitorozás', type: 'procedure', subtitle: 'Állapotkövetési lépés' },
  { id: 'first_step', title: 'első ellátás', type: 'treatment', subtitle: 'Korai beavatkozási lehetőség' },
  { id: 'therapy', title: 'terápia', type: 'treatment', subtitle: 'Célzott kezelési stratégia' },
  { id: 'device', title: 'eszköz', type: 'procedure', subtitle: 'Kapcsolódó ellátási eszköz' },
  { id: 'intervention', title: 'beavatkozás', type: 'procedure', subtitle: 'Specifikus klinikai lépés' },
  { id: 'complication', title: 'szövődmény', type: 'condition', subtitle: 'Lehetséges kedvezőtlen kimenet' },
  { id: 'trend', title: 'trend', type: 'measurement', subtitle: 'Időbeli változás értékelése' },
  { id: 'case', title: 'esetpélda', type: 'source', subtitle: 'Klinikai kontextust adó jegyzet' },
  { id: 'summary', title: 'összefoglaló', type: 'source', subtitle: 'Összekapcsoló tudásjegyzet' },
];

let previousDeepIds = [];
KNOWLEDGE_DEEP_GROUPS.forEach((group, groupIndex) => {
  const ids = KNOWLEDGE_DEEP_ROLES.map((role, roleIndex) => {
    const id = `${group.id}_${role.id}`;
    knowledgeNodes.push({
      id,
      title: `${group.title} · ${role.title}`,
      type: role.type,
      subtitle: `${group.subtitle} · ${role.subtitle}`,
      noteId: `note_deep_${String(groupIndex + 1).padStart(2, '0')}`,
      sectionId: `section_deep_${String(groupIndex * KNOWLEDGE_DEEP_ROLES.length + roleIndex + 1).padStart(3, '0')}`,
      importance: Number((.5 + ((groupIndex * 13 + roleIndex * 7) % 41) / 100).toFixed(2)),
      validated: (groupIndex * 3 + roleIndex) % 7 !== 0,
    });
    return id;
  });
  knowledgeEdges.push(
    { source: group.anchor, target: ids[0], weight: .69, bidirectional: true, label: 'témakapcsolat' },
    { source: group.anchor, target: ids[7], weight: .6, bidirectional: true, label: 'értelmezési kapcsolat' },
  );
  for (let index = 0; index < ids.length - 1; index += 1) {
    knowledgeEdges.push({ source: ids[index], target: ids[index + 1], weight: Number((.72 - index * .012).toFixed(2)), bidirectional: true, label: 'helyi tudásút' });
  }
  [[1, 7], [4, 11], [6, 14], [9, 17], [12, 19]].forEach(([sourceIndex, targetIndex]) => {
    knowledgeEdges.push({ source: ids[sourceIndex], target: ids[targetIndex], weight: .59, bidirectional: true, label: 'keresztkapcsolat' });
  });
  if (previousDeepIds.length) {
    knowledgeEdges.push({ source: previousDeepIds[19], target: ids[2], weight: .55, bidirectional: true, label: 'közösségi híd' });
  }
  previousDeepIds = ids;
});

const TYPE_META = {
  topic: { label: 'Téma', icon: '✦' }, concept: { label: 'Fogalom', icon: '◇' }, measurement: { label: 'Mérés', icon: '◌' },
  condition: { label: 'Állapot', icon: '◒' }, treatment: { label: 'Kezelés', icon: '＋' }, procedure: { label: 'Eljárás', icon: '↗' },
  source: { label: 'Forrás', icon: '▧' }, symptom: { label: 'Tünet', icon: '◔' },
};

const FILTER_TYPES = ['topic', 'concept', 'condition', 'measurement', 'treatment', 'procedure', 'source', 'symptom'];
const MIN_ZOOM = .15;
const MAX_ZOOM = 4;
// A 3D atomok gömbhéjon helyezkednek el. A hátsó féltekét nem egy poligonos
// takarógömb, hanem a kamera irányából számított horizont-levágás rejti el.
const FORCE_SPHERE_SHELL_RADIUS = 77;
const FORCE_SPHERE_NODE_REL_SIZE = 4;
const FORCE_SPHERE_NODE_RESOLUTION = 12;
const FORCE_SPHERE_CULLING_STEP_DEGREES = 2.5;
const D3_FORCE_3D_NODE_LIMIT = 120;
const D3_FORCE_3D_EDGE_LIMIT = 240;
const FORCE_SPHERE_HORIZON = -.22;
const FORCE_SPHERE_BASE_CAMERA_DISTANCE = 300;
const FORCE_SPHERE_CARD_CAMERA_DISTANCE = FORCE_SPHERE_SHELL_RADIUS * 2.55;
const FORCE_SPHERE_VISIBLE_CARD_COUNT = 7;
const FORCE_SPHERE_LAYERED_CARD_COUNT = 20;
const FORCE_SPHERE_PREFETCH_CARD_COUNT = 12;
const FORCE_SPHERE_CARD_POOL_SIZE = FORCE_SPHERE_LAYERED_CARD_COUNT + FORCE_SPHERE_PREFETCH_CARD_COUNT;
const FORCE_SPHERE_STREAM_STEP_DEGREES = 14;
const MORPH_CLUSTER_STATES = Object.freeze({
  OVERVIEW: 'overview',
  ZOOMING_IN: 'zooming-in',
  REVEALING_ATOMS: 'revealing-atoms',
  MORPHING_CARDS: 'morphing-cards',
  FOCUSED: 'focused',
  ZOOMING_OUT: 'zooming-out',
});
const MORPH_CLUSTER_DURATION = 1650;
const MORPH_CLUSTER_CAMERA_DISTANCE = FORCE_SPHERE_SHELL_RADIUS * 2.55;
// Ez nem cluster-adatmodell: ugyanazok az Atomok jelennek meg két eltérő
// részletességi szinten. Az overview kis gömböket, a fókuszállapot pedig
// ugyanazon anchorok kártya-morphját rajzolja.
const FORCE_GRAPH_MORPH_STATES = Object.freeze({
  OVERVIEW: 'overview',
  TRANSITION_TO_FOCUS: 'transition_to_focus',
  FOCUSED: 'focused',
  TRANSITION_TO_OVERVIEW: 'transition_to_overview',
});
const FORCE_GRAPH_MORPH_DURATION = 1120;
const FORCE_GRAPH_MORPH_NODE_LIMIT = 40;
const FORCE_GRAPH_MORPH_FIRST_RING_LIMIT = 6;
const FORCE_GRAPH_MORPH_SECOND_RING_PER_NODE = 2;
// A Planet zoom kizárólag vizuális átmenet: a 3D Force nézet kis gömbjei
// önálló bolygók. Koppintásra az egyik bolygó kitágul, majd a fehér hátterű
// G6 Fókuszált térképre oldódik fel.
const FORCE_GRAPH_PLANET_STATES = Object.freeze({
  OVERVIEW: 'overview',
  ZOOMING: 'zooming',
  HANDOFF: 'handoff',
});
const FORCE_GRAPH_PLANET_DURATION = 1450;
const FORCE_SPHERE_CARD_SLOTS = [
  { yaw: 0, pitch: 0 },
  { yaw: -38, pitch: 9 },
  { yaw: 38, pitch: 9 },
  { yaw: -44, pitch: -24 },
  { yaw: 44, pitch: -24 },
  { yaw: -16, pitch: 30 },
  { yaw: 16, pitch: 30 },
];

// A 3d-force-graph a `val` köbgyökéből képez sugarat. A fokszámot ezért egy
// jól kezelhető, logaritmikus sugárra képezzük, majd köbre emeljük. Így egy
// hub látványosan nagyobb, de nem nyomja el a kisebb tudáselemeket.
export function forceSphereNodeValue(degree, maxDegree = 1) {
  const safeMaxDegree = Math.max(1, maxDegree);
  const normalizedDegree = Math.min(1, Math.max(0, Math.log1p(Math.max(0, degree)) / Math.log1p(safeMaxDegree)));
  // A legnagyobb hub sugara az előzőnek körülbelül a fele. A hatvány közben
  // jobban széthúzza az alacsony és magas fokszámú Atomokat: a kevés éllel
  // rendelkező csomópontok finomak maradnak, a hubok kiemelkednek.
  const radius = .22 + (normalizedDegree ** 1.35) * .98;
  return radius ** 3;
}

export function forceSphereCardCameraDistance() {
  return FORCE_SPHERE_CARD_CAMERA_DISTANCE;
}

// A kártyás 3D Force nézet nem a teljes gömbön szétszórt helyeket használ.
// Ez a hét rögzített, több soros slot tölti ki a kamera előtti gömbsapkát.
export function forceSphereCardLayout() {
  return FORCE_SPHERE_CARD_SLOTS.map((slot) => ({ ...slot }));
}

// A streamelő V2-ben az Atom nem kap permanens világpozíciót. Csak a fix
// méretű renderpool slotja kap pillanatnyi helyet. A három sáv egyértelmű
// mentális térképet ad: Layer 1 = közvetlen környezet, Layer 2 = távolabbi
// kapcsolat a látható peremen, Layer 3 = a horizont mögötti következő hullám.
export function forceSphereCardLayerSlot(direction = { x: 1, y: 0 }, layer = 3, index = 0) {
  const x = Number(direction.x) || 0;
  const y = Number(direction.y) || 0;
  const horizontal = Math.abs(x) >= Math.abs(y);
  const sign = Math.sign(horizontal ? x : y) || 1;
  const lane = Math.abs(index) % 6;
  const stagger = [-40, -24, -8, 9, 25, 40][lane];
  const distance = layer === 2 ? 76 + (lane % 2) * 5 : 102 + (lane % 3) * 4;
  if (horizontal) return { yaw: sign * distance, pitch: stagger };
  return { yaw: stagger, pitch: sign * distance };
}

export function forceSphereCardEntrySlot(direction = { x: 1, y: 0 }, index = 0) {
  return forceSphereCardLayerSlot(direction, 3, index);
}
// A G6 v5 helyben tárolt csomagjának mind a 19 2D layoutja és három térbeli nézet.
// A G6 nézetek a könyvtár alapértelmezett node- és élstílusait használják; a Djinn
// felület csak a vásznon kívüli vezérlőket adja hozzá.
const VISUALIZATIONS = [
  { id: 'g6-focused-map', label: 'G6 · Fókuszált térkép', group: 'Navigáció', icon: '⌖', focusedG6: true },
  { id: 'g6-focused-map-dark', label: 'G6 · Fókuszált térkép · Deep-space violet', group: 'Navigáció', icon: '✦', focusedG6Dark: true },
  { id: 'g6-focused-map-v2', label: 'G6 · Fókuszált térkép v2', group: 'Navigáció', icon: '⌘', focusedG6V2: true },
  { id: 'g6-focused-map-v2-dark', label: 'G6 · Fókuszált térkép v2 · Deep-space violet', group: 'Navigáció', icon: '✦', focusedG6V2Dark: true },
  { id: 'd3-force-3d', label: 'D3 Force 3D', group: 'Térbeli', icon: '◈', threeD: true },
  { id: '3d-force-graph', label: '3D Force Graph', group: 'Térbeli', icon: '◉', force3d: true },
  { id: '3d-force-globe-demo', label: '3D Force · Inline Globe demo', group: 'Térbeli', icon: '◌', force3d: true, forceUniverseDemo: true },
  { id: '3d-force-graph-morph', label: '3D Force · Planet zoom', group: 'Térbeli', icon: '✧', force3d: true, forceGraphMorph: true },
  { id: '3d-force-globe', label: '3D Force · Gömbforgás', group: 'Térbeli', icon: '◍', force3d: true, forceSphere: true },
  { id: '3d-force-globe-cards', label: '3D Force · Gömbkártyák v2', group: 'Térbeli', icon: '▤', force3d: true, forceSphere: true, forceSphereCards: true },
  { id: '3d-force-globe-morph', label: '3D Force · Morph cluster', group: 'Térbeli', icon: '◌', force3d: true, forceSphere: true, forceSphereMorph: true },
  { id: 'globe-arc-links', label: 'Globe · Arc Links', group: 'Térbeli', icon: '◐', globe: true },
  { id: 'globe-knowledge-cards', label: 'Globe · Tudáskártyák', group: 'Térbeli', icon: '▤', cardGlobe: true },
  { id: 'globe-focused-cards', label: 'Globe · Fókuszált kártyák', group: 'Térbeli', icon: '◉', focusedCardGlobe: true },
  { id: 'globe-focused-mixed', label: 'Globe · Mixed', group: 'Térbeli', icon: '⌘', mixedFocusedGlobe: true },
  { id: 'globe-rolling-cards', label: 'Globe · Fókuszált kártyák v2', group: 'Térbeli', icon: '◒', rollingCardGlobe: true },
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
];
const VISUALIZATION_BY_ID = new Map(VISUALIZATIONS.map((item) => [item.id, item]));
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

// A V2 síkbeli nézet szándékosan nem teljes világtérkép: a V1 sűrű, jól
// olvasható fókuszrendezését őrzi meg, még kevesebb elsődleges kártyával.
export function buildFocusedG6V2Subgraph(focusId, nodes = knowledgeNodes, edges = knowledgeEdges, options = {}) {
  return buildFocusedG6Subgraph(focusId, nodes, edges, {
    ...options,
    firstRingLimit: options.firstRingLimit ?? 4,
    secondRingPerNode: options.secondRingPerNode ?? 1,
    maxNodes: options.maxNodes ?? 8,
  });
}

// A távolodás a térképi részletességet módosítja, nem pusztán a már látható
// kártyákat kicsinyíti. Emiatt a G6 V2 valódi térképérzetet kap: közel egy
// kis context, kifelé pedig egyre több második gyűrűs Atom jelenik meg.
export function focusedG6V2Lod(zoom = 1) {
  if (zoom >= .82) return { key: 'near', firstRingLimit: 4, secondRingPerNode: 1, maxNodes: 8 };
  if (zoom >= .48) return { key: 'mid', firstRingLimit: 6, secondRingPerNode: 2, maxNodes: 16 };
  return { key: 'far', firstRingLimit: 8, secondRingPerNode: 3, maxNodes: 28 };
}

const FOCUSED_G6_CARD_SIZES = {
  0: [124, 62],
  1: [96, 48],
  2: [78, 38],
};

export function focusedG6CardSize(level) {
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

// A V2 kártyái egy nagyobb, stabil világkoordináta-térben vannak. A belső
// gyűrű közel marad; a második gyűrű a normál nézetben többnyire a viewporton
// kívül van, majd a felhasználó kifelé zoomolásakor fokozatosan tárul fel.
export function focusedG6V2Positions(nodes, focusId, width, height) {
  const center = { x: width / 2, y: height / 2 };
  const positions = new Map([[focusId, { ...center, level: 0 }]]);
  const firstRing = nodes.filter((node) => node.focusDepth === 1).sort((a, b) => a.focusRank - b.focusRank || a.id.localeCompare(b.id));
  const secondRing = nodes.filter((node) => node.focusDepth === 2).sort((a, b) => a.focusParentIndex - b.focusParentIndex || a.focusRank - b.focusRank || a.id.localeCompare(b.id));
  firstRing.forEach((node, index) => {
    const angle = (Math.PI * 2 * (index + .5) / Math.max(firstRing.length, 1)) - Math.PI / 2;
    positions.set(node.id, { x: center.x + Math.cos(angle) * 155, y: center.y + Math.sin(angle) * 182, level: 1 });
  });
  secondRing.forEach((node, index) => {
    const angle = (Math.PI * 2 * (index + .5) / Math.max(secondRing.length, 1)) - Math.PI / 2 + ((node.focusParentIndex || 0) % 2 ? .11 : -.11);
    const radiusX = 390 + (index % 3) * 24;
    const radiusY = 430 + (index % 2) * 28;
    positions.set(node.id, { x: center.x + Math.cos(angle) * radiusX, y: center.y + Math.sin(angle) * radiusY, level: 2 });
  });
  return positions;
}

// A fókuszált G6 vászon lokális koordinátáit a kamera előtti gömbsapkára
// vetíti. A középső kártya a (0°, 0°) anchor, a térkép szélei pedig a
// gömbfelszín külső, még olvasható részére kerülnek.
export function projectFocusedMapPointToGlobeCap(position, width, height) {
  const centerX = width / 2;
  const centerY = height / 2;
  return {
    lat: ((centerY - position.y) / centerY) * 52,
    lng: ((position.x - centerX) / centerX) * 62,
  };
}

// A kártya PlaneGeometry-je a lokális +Z normálirányból indul. A közép 0-n
// marad, a szélek negatív Z-be hajlanak: a Globe.GL által kifelé fordított
// kártya szélei így a gömb felszíne felé követik vissza az ívet.
export function bendCardToSphereGeometry(geometry, radiusX, radiusY) {
  const positions = geometry?.attributes?.position;
  if (!positions || radiusX <= 0 || radiusY <= 0) return geometry;
  for (let index = 0; index < positions.count; index += 1) {
    const originalX = positions.getX(index);
    const originalY = positions.getY(index);
    const angleX = originalX / radiusX;
    const angleY = originalY / radiusY;
    const bentX = Math.sin(angleX) * radiusX;
    const bentY = Math.sin(angleY) * radiusY;
    const bentZ = (Math.cos(angleX) * radiusX - radiusX) + (Math.cos(angleY) * radiusY - radiusY);
    positions.setXYZ(index, bentX, bentY, bentZ);
  }
  positions.needsUpdate = true;
  geometry.computeVertexNormals?.();
  geometry.computeBoundingBox?.();
  geometry.computeBoundingSphere?.();
  return geometry;
}

// A V2 síkbeli térkép teljes világa. A fókusz és első gyűrű a kezdő
// viewportban van; a távolabbi közösségek tudatosan nagyobb gyűrűkön, a
// képernyőn kívül helyezkednek el. Pan és zoom ezért térképcsempe-szerűen
// tárja fel őket, egy távoli Atom kiválasztása pedig új világközéppontot ad.
export function focusedG6V2World(focusId, nodes = knowledgeNodes, edges = knowledgeEdges, viewport = { width: 360, height: 560 }) {
  const nodeMap = new Map(nodes.map((node) => [node.id, node]));
  const resolvedFocusId = nodeMap.has(focusId) ? focusId : nodes[0]?.id;
  if (!resolvedFocusId) return { focusId: undefined, nodes: [], edges: [] };
  const neighbors = new Map(nodes.map((node) => [node.id, []]));
  edges.forEach((edge) => {
    neighbors.get(edge.source)?.push({ id: edge.target, weight: edge.weight });
    if (edge.bidirectional !== false) neighbors.get(edge.target)?.push({ id: edge.source, weight: edge.weight });
  });
  neighbors.forEach((items) => items.sort((first, second) => second.weight - first.weight || first.id.localeCompare(second.id)));
  const depthById = new Map([[resolvedFocusId, 0]]);
  const queue = [resolvedFocusId];
  while (queue.length) {
    const currentId = queue.shift();
    const nextDepth = depthById.get(currentId) + 1;
    (neighbors.get(currentId) || []).forEach(({ id }) => {
      if (depthById.has(id)) return;
      depthById.set(id, nextDepth);
      queue.push(id);
    });
  }
  const groups = new Map();
  nodes.forEach((node) => {
    const depth = depthById.get(node.id) ?? 4;
    if (!groups.has(depth)) groups.set(depth, []);
    groups.get(depth).push(node);
  });
  groups.forEach((items, depth) => {
    if (depth === 1) {
      items.sort((first, second) => (neighbors.get(resolvedFocusId)?.findIndex((item) => item.id === first.id) ?? 0) - (neighbors.get(resolvedFocusId)?.findIndex((item) => item.id === second.id) ?? 0));
      return;
    }
    items.sort((first, second) => first.id.localeCompare(second.id));
  });
  const centerX = viewport.width / 2;
  const centerY = viewport.height / 2;
  const rotation = ((Math.abs(hash(resolvedFocusId)) % 360) * Math.PI) / 180;
  const worldNodes = [];
  groups.forEach((items, depth) => {
    const radiusX = depth === 0 ? 0 : 180 + (depth - 1) * 320;
    const radiusY = depth === 0 ? 0 : 210 + (depth - 1) * 350;
    items.forEach((node, index) => {
      const angle = depth === 0 ? 0 : rotation + (Math.PI * 2 * (index + .5) / items.length) - Math.PI / 2;
      worldNodes.push({
        ...node,
        contextDepth: depth,
        worldX: centerX + Math.cos(angle) * radiusX,
        worldY: centerY + Math.sin(angle) * radiusY,
      });
    });
  });
  return { focusId: resolvedFocusId, nodes: worldNodes, edges: [...edges] };
}

// A rolling nézet a korlátlan logikai koordinátát vetíti az aktuális, kamera
// előtti gömbsapkára. Nincs longitude-modulo: ugyanaz a vizuális irány később
// teljesen új Atomot kaphat, mert a forrás a virtualOffset, nem a 360 fok.
export function projectVirtualPointToSphereCap(localX, localY, radius, angularScale = .004) {
  const yaw = localX * angularScale;
  const pitch = localY * angularScale;
  return {
    x: radius * Math.sin(yaw) * Math.cos(pitch),
    y: radius * Math.sin(pitch),
    z: radius * Math.cos(yaw) * Math.cos(pitch),
  };
}

export function rollingSlotToGeo(pov, slot) {
  const lat = clamp((pov.lat || 0) + (slot.pitchOffset || 0), -80, 80);
  const cosLat = Math.max(.25, Math.cos(((pov.lat || 0) * Math.PI) / 180));
  const rawLng = (pov.lng || 0) + (slot.yawOffset || 0) / cosLat;
  const lng = ((rawLng + 180) % 360 + 360) % 360 - 180;
  return { lat, lng };
}

// A 3d-force-graph szimulációs koordinátájából készülő stabil gömbhéj-anchor.
// A renderer ebből állítja be a kártya pozícióját és a lokális felszíni
// normálhoz tartozó tangenciális orientációját.
export function forceSphereCardTransform(x, y, z, radius = FORCE_SPHERE_SHELL_RADIUS) {
  const length = Math.hypot(x, y, z) || 1;
  const normal = { x: x / length, y: y / length, z: z / length };
  return {
    normal,
    position: { x: normal.x * radius, y: normal.y * radius, z: normal.z * radius },
  };
}

// A +Z normálra forgatás önmagában nem rögzíti a kártya „fel” irányát, ezért
// a különböző felszíni pontokon véletlenszerűnek tűnő roll alakulhat ki.
// Ez a teljes tangenciális frame a kamerához képest egyenes, rendezett
// kártyagyűrűt biztosít a Morph nézetnek.
export function forceSphereStructuredCardFrame(normalInput, cameraUpInput = { x: 0, y: 1, z: 0 }) {
  const normalize = ({ x = 0, y = 0, z = 0 }) => {
    const length = Math.hypot(x, y, z) || 1;
    return { x: x / length, y: y / length, z: z / length };
  };
  const cross = (first, second) => ({
    x: first.y * second.z - first.z * second.y,
    y: first.z * second.x - first.x * second.z,
    z: first.x * second.y - first.y * second.x,
  });
  const normal = normalize(normalInput);
  let right = normalize(cross(cameraUpInput, normal));
  if (Math.hypot(right.x, right.y, right.z) < 1e-6 || Math.abs(normal.y) > .995) right = { x: 1, y: 0, z: 0 };
  const up = normalize(cross(normal, right));
  return { right, up, normal };
}

export function forceSphereZoomScale(cameraDistance, baseDistance = FORCE_SPHERE_BASE_CAMERA_DISTANCE) {
  const safeDistance = Math.max(Number(cameraDistance) || baseDistance, 1);
  return Math.min(2.25, Math.max(.45, baseDistance / safeDistance));
}

// A 3d-force-graph alapértelmezett linkje egyenes húr lenne. A kártyás
// gömbnézetben a link mintapontjai ugyanazon a gömbhéjon fekszenek, így az
// összeköttetés ténylegesen követi a lila gömb ívét.
export function buildForceSphereSurfaceLinkPoints(start, end, segments = 12, radius = FORCE_SPHERE_SHELL_RADIUS + 1.1) {
  const startNormal = new THREE.Vector3(start.x, start.y, start.z).normalize();
  const endNormal = new THREE.Vector3(end.x, end.y, end.z).normalize();
  const dot = THREE.MathUtils.clamp(startNormal.dot(endNormal), -1, 1);
  const angle = Math.acos(dot);
  const sinAngle = Math.sin(angle);
  const safeSegments = Math.max(2, Math.round(segments));
  const points = [];
  for (let index = 0; index <= safeSegments; index += 1) {
    const progress = index / safeSegments;
    const normal = Math.abs(sinAngle) < 1e-6
      ? startNormal.clone().lerp(endNormal, progress).normalize()
      : startNormal.clone().multiplyScalar(Math.sin((1 - progress) * angle) / sinAngle)
        .add(endNormal.clone().multiplyScalar(Math.sin(progress * angle) / sinAngle)).normalize();
    points.push({ x: normal.x * radius, y: normal.y * radius, z: normal.z * radius });
  }
  return points;
}

// A Globe.GL az ív geometriáját akkor is rajzolja, ha az egyik végpontot a
// gömb vagy annak kártyája már eltakarja. Ilyenkor a látható ívdarab úgy hat,
// mintha vakon érne véget. A kártyás nézetben csak két kamera felőli végpont
// közötti kapcsolat maradhat a renderelt Arc Links halmazban.
function globeSurfaceNormal({ lat, lng }) {
  const latitude = THREE.MathUtils.degToRad(lat);
  const longitude = THREE.MathUtils.degToRad(lng);
  return new THREE.Vector3(
    Math.cos(latitude) * Math.cos(longitude),
    Math.sin(latitude),
    Math.cos(latitude) * Math.sin(longitude),
  );
}

function globeCoordinatesFromNormal(normal) {
  const unit = normal.clone().normalize();
  return {
    lat: THREE.MathUtils.radToDeg(Math.asin(THREE.MathUtils.clamp(unit.y, -1, 1))),
    lng: THREE.MathUtils.radToDeg(Math.atan2(unit.z, unit.x)),
  };
}

// A Globe.GL Paths Layerét nagy körös mintapontokkal etetjük. A köztes
// pontok mindig a gömbhéjon vannak, ezért a kapcsolat a felszín ívét követi
// ahelyett, hogy Arc Links-ként kiemelkedne a térbe.
export function buildCardGlobeSurfacePath(start, end, segments = 16, altitude = .015) {
  const startNormal = globeSurfaceNormal(start);
  const endNormal = globeSurfaceNormal(end);
  const dot = THREE.MathUtils.clamp(startNormal.dot(endNormal), -1, 1);
  const angle = Math.acos(dot);
  const safeSegments = Math.max(2, Math.round(segments));
  const sinAngle = Math.sin(angle);
  const points = [];
  for (let index = 0; index <= safeSegments; index += 1) {
    if (index === 0) { points.push({ lat: start.lat, lng: start.lng, altitude }); continue; }
    if (index === safeSegments) { points.push({ lat: end.lat, lng: end.lng, altitude }); continue; }
    const progress = index / safeSegments;
    const normal = Math.abs(sinAngle) < 1e-6
      ? startNormal.clone().lerp(endNormal, progress).normalize()
      : startNormal.clone().multiplyScalar(Math.sin((1 - progress) * angle) / sinAngle)
        .add(endNormal.clone().multiplyScalar(Math.sin(progress * angle) / sinAngle)).normalize();
    points.push({ ...globeCoordinatesFromNormal(normal), altitude });
  }
  return points;
}

// Az Arc Layer azonos alapmagassága távoli kártyák között a gömbbe süllyedhet.
// A távolsággal arányosan magasabb csúcspontot adunk, miközben a közeli
// kapcsolatok továbbra is lapos, felszínközeli ívek maradnak.
export function globeFocusedAirArcAltitude(start, end, base = .12) {
  const startNormal = globeSurfaceNormal(start);
  const endNormal = globeSurfaceNormal(end);
  const angle = Math.acos(THREE.MathUtils.clamp(startNormal.dot(endNormal), -1, 1));
  const distanceRatio = angle / Math.PI;
  // Az Arc Layer csúcsa a gömbsugárhoz viszonyított relatív magasság. A
  // minimális légrés megakadályozza, hogy az ív a felszínbe vágjon, a távoli
  // végpontok pedig erősebben emelkednek, nem „földre fektetett” húrok.
  return THREE.MathUtils.clamp(base + Math.pow(distanceRatio, .9) * .40, base, .56);
}

export function filterCardGlobeArcs(edges, pointById, pov, horizonThreshold = .04) {
  const cameraNormal = globeSurfaceNormal(pov || { lat: 0, lng: 0 });
  const frontFacing = (point) => point && globeSurfaceNormal(point).dot(cameraNormal) > horizonThreshold;
  return edges.filter((edge) => frontFacing(pointById.get(edge.source)) && frontFacing(pointById.get(edge.target)));
}

// A még nem látott, de a jelenlegi részgráfhoz kapcsolódó Atomok prioritásos
// várólistája. A közvetlen fókuszkapcsolat, az edge weight és az újdonság
// együtt határozza meg a streamelés következő jelöltjét.
export function buildRollingFrontier(focusId, visibleIds, nodes = knowledgeNodes, edges = knowledgeEdges) {
  const knownIds = new Set(nodes.map((node) => node.id));
  const candidates = new Map();
  edges.forEach((edge) => {
    const pairs = edge.bidirectional === false ? [[edge.source, edge.target]] : [[edge.source, edge.target], [edge.target, edge.source]];
    pairs.forEach(([sourceId, targetId]) => {
      if (!visibleIds.has(sourceId) || visibleIds.has(targetId) || !knownIds.has(targetId)) return;
      const directFocusBonus = sourceId === focusId ? .35 : 0;
      const existing = candidates.get(targetId);
      const priority = edge.weight * .5 + directFocusBonus + .15;
      if (!existing || priority > existing.priority) candidates.set(targetId, { id: targetId, priority, via: sourceId, weight: edge.weight });
    });
  });
  return [...candidates.values()].sort((first, second) => second.priority - first.priority || second.weight - first.weight || first.id.localeCompare(second.id));
}

// A kártyás gömbök végleges elhelyezése nem force layout. A fókuszhoz mért
// gráftávolság adja a gömbi sávot, a közvetlen kapcsolat pedig saját szektort
// kap. Az eredmény tiszta adat: mind a Globe.GL, mind a 3d-force-graph
// ugyanebből építi fel a stabil, újrafelhasználható render-slotjait.
export function buildLayeredSphericalFocusLayout(focusId, nodes = knowledgeNodes, edges = knowledgeEdges, options = {}) {
  const nodeMap = new Map(nodes.map((node) => [node.id, node]));
  const resolvedFocusId = nodeMap.has(focusId) ? focusId : nodes[0]?.id;
  if (!resolvedFocusId) return [];
  const depth1Limit = options.depth1Limit ?? 6;
  const depth2PerBranch = options.depth2PerBranch ?? 2;
  const depth3Limit = options.depth3Limit ?? 12;
  const adjacency = new Map(nodes.map((node) => [node.id, []]));
  edges.forEach((edge) => {
    if (!adjacency.has(edge.source) || !adjacency.has(edge.target)) return;
    adjacency.get(edge.source).push({ id: edge.target, edge });
    if (edge.bidirectional !== false) adjacency.get(edge.target).push({ id: edge.source, edge });
  });
  adjacency.forEach((items) => items.sort((first, second) => second.edge.weight - first.edge.weight || first.id.localeCompare(second.id)));

  const usedIds = new Set([resolvedFocusId]);
  const details = [{ id: resolvedFocusId, depth: 0, branchId: resolvedFocusId, parentId: undefined, rank: 0, branchRank: 0 }];
  const depth1 = (adjacency.get(resolvedFocusId) || []).slice(0, depth1Limit);
  depth1.forEach((item, rank) => {
    if (usedIds.has(item.id)) return;
    usedIds.add(item.id);
    details.push({ id: item.id, depth: 1, branchId: item.id, parentId: resolvedFocusId, rank, branchRank: rank });
  });

  const depth1Details = details.filter((item) => item.depth === 1);
  depth1Details.forEach((parent) => {
    let childRank = 0;
    (adjacency.get(parent.id) || []).forEach((item) => {
      if (childRank >= depth2PerBranch || usedIds.has(item.id)) return;
      usedIds.add(item.id);
      details.push({ id: item.id, depth: 2, branchId: parent.branchId, parentId: parent.id, rank: childRank, branchRank: parent.branchRank });
      childRank += 1;
    });
  });

  const depth2Details = details.filter((item) => item.depth === 2);
  const frontierCandidates = new Map();
  [...depth2Details, ...depth1Details].forEach((parent) => {
    (adjacency.get(parent.id) || []).forEach((item) => {
      if (usedIds.has(item.id)) return;
      const existing = frontierCandidates.get(item.id);
      const candidate = {
        id: item.id,
        depth: 3,
        branchId: parent.branchId,
        parentId: parent.id,
        rank: 0,
        branchRank: parent.branchRank,
        weight: item.edge.weight,
      };
      if (!existing || candidate.weight > existing.weight || (candidate.weight === existing.weight && candidate.id.localeCompare(existing.id) < 0)) {
        frontierCandidates.set(item.id, candidate);
      }
    });
  });
  [...frontierCandidates.values()]
    .sort((first, second) => second.weight - first.weight || first.branchRank - second.branchRank || first.id.localeCompare(second.id))
    .slice(0, depth3Limit)
    .forEach((candidate, rank) => {
      usedIds.add(candidate.id);
      details.push({ ...candidate, rank });
    });

  const branchSlots = [
    { yaw: -36, pitch: 14 }, { yaw: 36, pitch: 14 },
    { yaw: -40, pitch: -20 }, { yaw: 40, pitch: -20 },
    { yaw: -12, pitch: 38 }, { yaw: 12, pitch: 38 },
  ];
  const clampBand = (value, min, max) => Math.max(min, Math.min(max, value));
  const positioned = new Map();
  positioned.set(resolvedFocusId, { yaw: 0, pitch: 0, angularDistance: 0 });
  depth1Details.forEach((item, index) => {
    const slot = branchSlots[index % branchSlots.length];
    positioned.set(item.id, { yaw: slot.yaw, pitch: slot.pitch, angularDistance: Math.hypot(slot.yaw, slot.pitch) });
  });
  depth2Details.forEach((item) => {
    const parent = positioned.get(item.parentId) || branchSlots[item.branchRank % branchSlots.length];
    const length = Math.hypot(parent.yaw, parent.pitch) || 1;
    const perpendicular = { yaw: -parent.pitch / length, pitch: parent.yaw / length };
    // A két azonos ágú másodlagos kártya ne ugyanarra a görbületi sávra
    // kerüljön: a szélesebb, determinisztikus eltolás elkerüli a kártyák
    // tényleges perspektivikus átfedését is.
    const side = item.rank % 2 === 0 ? -14 : 14;
    const yaw = clampBand(parent.yaw * 1.55 + perpendicular.yaw * side, -78, 78);
    const pitch = clampBand(parent.pitch * 1.55 + perpendicular.pitch * side, -58, 58);
    positioned.set(item.id, { yaw, pitch, angularDistance: Math.hypot(yaw, pitch) });
  });
  details.filter((item) => item.depth === 3).forEach((item, index) => {
    const branch = positioned.get(item.branchId) || branchSlots[item.branchRank % branchSlots.length];
    const sign = Math.sign(branch.yaw || (item.branchRank % 2 ? -1 : 1)) || 1;
    const yaw = sign * (96 + (index % 3) * 5);
    const pitch = clampBand(branch.pitch * 1.18 + (Math.floor(index / 3) - 2) * 12, -58, 58);
    positioned.set(item.id, { yaw, pitch, angularDistance: Math.hypot(yaw, pitch) });
  });
  return details.map((item) => ({ ...item, ...positioned.get(item.id) }));
}

// A fókusz körüli layout először helyi (kelet–észak) szögekkel készül. Ezt
// a segéd alakítja át Globe.GL-nek átadható, stabil földrajzi koordinátává.
// Nem equirectangular pixel-eltolás: nagy kör mentén, a fókusz érintősíkján
// halad, ezért pólus és dátumvonal közelében sem szakad szét az elrendezés.
export function destinationPointOnGlobe(originLat, originLng, angularDistance, bearing) {
  const originLatitude = THREE.MathUtils.degToRad(Number(originLat) || 0);
  const originLongitude = THREE.MathUtils.degToRad(Number(originLng) || 0);
  const distance = THREE.MathUtils.degToRad(Math.max(0, Number(angularDistance) || 0));
  const direction = THREE.MathUtils.degToRad(Number(bearing) || 0);
  const latitude = Math.asin(
    Math.sin(originLatitude) * Math.cos(distance)
    + Math.cos(originLatitude) * Math.sin(distance) * Math.cos(direction),
  );
  const longitude = originLongitude + Math.atan2(
    Math.sin(direction) * Math.sin(distance) * Math.cos(originLatitude),
    Math.cos(distance) - Math.sin(originLatitude) * Math.sin(latitude),
  );
  return {
    lat: THREE.MathUtils.radToDeg(latitude),
    lng: ((THREE.MathUtils.radToDeg(longitude) + 540) % 360) - 180,
  };
}

// Ez a Globe.GL-specifikus adapter választja szét a teljes gráfot az aktív
// Objects Layer kártyáira és a még csak lazy frontierként létező harmadik
// rétegre. A lat/lng egyszer fókuszváltáskor készül el; forgatás közben nem
// számolódik újra, kizárólag a Globe.GL kamerája tárja fel.
export function buildGlobeFocusedCardLayout(
  focusId,
  anchor = { lat: 0, lng: 0 },
  nodes = knowledgeNodes,
  edges = knowledgeEdges,
  options = {},
) {
  const sourceNodes = nodes.length ? nodes : knowledgeNodes;
  const sourceMap = new Map(sourceNodes.map((node) => [node.id, node]));
  const resolvedFocusId = sourceMap.has(focusId) ? focusId : sourceNodes[0]?.id;
  if (!resolvedFocusId) return { focusId: undefined, active: [], prefetched: [] };
  const normalizedAnchor = {
    lat: clamp(Number(anchor.lat) || 0, -89, 89),
    lng: ((Number(anchor.lng) || 0) + 540) % 360 - 180,
  };
  const layered = buildLayeredSphericalFocusLayout(resolvedFocusId, sourceNodes, edges, {
    depth1Limit: options.depth1Limit ?? 6,
    depth2PerBranch: options.depth2PerBranch ?? 2,
    depth3Limit: options.depth3Limit ?? 12,
  });
  const toCard = (item) => {
    const atom = sourceMap.get(item.id);
    const bearing = THREE.MathUtils.radToDeg(Math.atan2(item.yaw || 0, item.pitch || 0));
    const geo = item.depth === 0
      ? { ...normalizedAnchor }
      : destinationPointOnGlobe(normalizedAnchor.lat, normalizedAnchor.lng, item.angularDistance, bearing);
    return {
      ...atom,
      id: item.id,
      graphDepth: item.depth,
      parentId: item.parentId,
      branchId: item.branchId,
      bearing,
      angularDistance: item.angularDistance,
      lat: geo.lat,
      lng: geo.lng,
      geo,
      altitude: item.depth === 0 ? .018 : item.depth === 1 ? .014 : item.depth === 2 ? .011 : .009,
      cardTier: Math.min(item.depth, 2),
      renderState: item.depth === 3 ? 'prefetched' : 'active',
      readabilityFactor: item.depth === 0 ? .46 : item.depth === 1 ? .28 : .14,
    };
  };
  const cards = layered.map(toCard);
  return {
    focusId: resolvedFocusId,
    anchor: normalizedAnchor,
    active: cards.filter((card) => card.graphDepth < 3),
    prefetched: cards.filter((card) => card.graphDepth === 3),
  };
}

// A kamera előtti hét helyet akkor is feltöltjük, ha a fókuszatomnak kevesebb
// mint hat közvetlen kapcsolata van. Ilyenkor a már felvett Atomokból nyitjuk
// tovább a frontiert, de minden lépés a fókusztól induló, súlyozott úton marad.
export function buildRollingSlotAtoms(focusId, count = 7, nodes = knowledgeNodes, edges = knowledgeEdges) {
  const knownIds = new Set(nodes.map((node) => node.id));
  const resolvedFocusId = knownIds.has(focusId) ? focusId : nodes[0]?.id;
  if (!resolvedFocusId || count <= 0) return [];
  const atomIds = [resolvedFocusId];
  const selectedIds = new Set(atomIds);
  while (atomIds.length < count) {
    const next = buildRollingFrontier(resolvedFocusId, selectedIds, nodes, edges)[0];
    if (!next) break;
    atomIds.push(next.id);
    selectedIds.add(next.id);
  }
  return atomIds;
}

// A ForceGraph motorban a renderhely és az Atom szintén külön objektum. Az
// aktív Atom-sor ugyanazt a prioritásos frontier-szabályt követi, mint a
// Globe.GL változat, de a slotok Three.js transzformját a ForceGraph kezeli.
export function buildForceSphereSlotAtoms(focusId, count = FORCE_SPHERE_VISIBLE_CARD_COUNT, nodes = knowledgeNodes, edges = knowledgeEdges) {
  return buildRollingSlotAtoms(focusId, count, nodes, edges);
}

// A Morph cluster nem új gráfot talál ki: ugyanazt a súlyozott, hét elemű
// fókuszablakot készíti elő, amelynek atomgömbjei később kártyává alakulnak.
export function buildMorphClusterFocusAtoms(focusId, nodes = knowledgeNodes, edges = knowledgeEdges) {
  return buildForceSphereSlotAtoms(focusId, FORCE_SPHERE_VISIBLE_CARD_COUNT, nodes, edges);
}

// A rolling nézet soha nem teríti szét a teljes részgrafot a gömbön. Egyetlen
// fókusz és hat, erős context-kártya tölti ki a kamera előtti gömbsapkát. Az
// új Atomok csak akkor foglalják el ezeket a slotokat, amikor egy régi kártya
// a viewportból ténylegesen kilép.
export function buildRollingFocusedWindow(focusId, nodes = knowledgeNodes, edges = knowledgeEdges, offset = { x: 0, y: 0 }) {
  const knownIds = new Set(nodes.map((node) => node.id));
  const resolvedFocusId = knownIds.has(focusId) ? focusId : nodes[0]?.id;
  if (!resolvedFocusId) return [];
  const focus = { id: resolvedFocusId, virtualX: offset.x, virtualY: offset.y, layer: 'focus' };
  const context = buildRollingFrontier(resolvedFocusId, new Set([resolvedFocusId]), nodes, edges)
    .filter(({ via }) => via === resolvedFocusId)
    .slice(0, 6);
  const radiusX = 200;
  const radiusY = 160;
  return [focus, ...context.map((candidate, index) => {
    const angle = (Math.PI * 2 * index / Math.max(context.length, 1)) - Math.PI / 2;
    return {
      id: candidate.id,
      virtualX: offset.x + Math.cos(angle) * radiusX,
      virtualY: offset.y + Math.sin(angle) * radiusY,
      layer: 'context',
    };
  })];
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
  let rollingGlobeContainer = screen.querySelector('[data-map-globe-rolling-cards]');
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

  function ensureRollingGlobeContainer() {
    if (rollingGlobeContainer || !mapCanvas) return rollingGlobeContainer;
    rollingGlobeContainer = document.createElement('div');
    rollingGlobeContainer.className = 'knowledge-globe knowledge-globe-rolling-cards';
    rollingGlobeContainer.dataset.mapGlobeRollingCards = '';
    rollingGlobeContainer.tabIndex = 0;
    rollingGlobeContainer.setAttribute('role', 'application');
    rollingGlobeContainer.setAttribute('aria-label', 'Légzési elégtelenség végtelen, gördülő tudáskártya-gömbnézete');
    mapCanvas.prepend(rollingGlobeContainer);
    return rollingGlobeContainer;
  }

  // Ez a vizuális prototype mindig tiszta kezdőállapotból indul. A session
  // közben továbbra is lehet navigálni, de egy böngészőfrissítés nem visz
  // vissza egy esetleg túl nagy vagy félbehagyott 3D nézetbe.
  try { localStorage.removeItem(STORAGE_KEY); } catch { /* Privát böngészésben nincs tároló. */ }
  const stored = {};
  const state = {
    centerId: nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure',
    selectedId: nodeById.has(stored.selectedId) ? stored.selectedId : (nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure'),
    focusedGlobeId: nodeById.has(stored.focusedGlobeId) ? stored.focusedGlobeId : (nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure'),
    rollingGlobeId: nodeById.has(stored.rollingGlobeId) ? stored.rollingGlobeId : (nodeById.has(stored.centerId) ? stored.centerId : 'resp_failure'),
    virtualOffsetX: Number.isFinite(Number(stored.virtualOffsetX ?? stored.rollingOffsetX)) ? Number(stored.virtualOffsetX ?? stored.rollingOffsetX) : 0,
    virtualOffsetY: Number.isFinite(Number(stored.virtualOffsetY ?? stored.rollingOffsetY)) ? Number(stored.virtualOffsetY ?? stored.rollingOffsetY) : 0,
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
    visualization: 'g6-focused-map',
    layoutMenuOpen: false,
  };
  const favoriteNodes = new Set(safeRead(FAVORITES_KEY, []));
  let topicIsFavorite = safeRead(THEME_FAVORITE_KEY, false) === true;
  let graph;
  let focusedG6V2LastFocusId;
  let focusedG6V2LodKey = '';
  let forceGraph3D;
  const forceUniversePlanetViews = new Map();
  let forceUniverseDetailGlobe;
  let forceUniverseDetailPlanetId = null;
  let forceUniverseLodState = 'GALAXY';
  let forceUniverseCandidateSince = 0;
  let forceUniverseLodFrame;
  let forceUniverseControls;
  let forceUniverseControlsHandler;
  let forceUniverseTransitionFrame;
  let forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.OVERVIEW;
  let forceGraphMorphNodes = [];
  let forceGraphMorphLinks = [];
  let forceGraphMorphNodeById = new Map();
  const forceGraphMorphObjects = new Map();
  const forceGraphMorphLinkObjects = new Map();
  let forceGraphMorphCardGeometry;
  let forceGraphMorphSphereGeometry;
  let forceGraphMorphFocusIds = [];
  let forceGraphMorphFrame;
  let forceGraphMorphTransitionStartedAt = 0;
  let forceGraphMorphTransitionDirection = 1;
  let forceGraphMorphTargetPositions;
  let forceGraphMorphCameraStart;
  let forceGraphMorphCameraTarget;
  let forceGraphMorphPendingFocusId;
  let forceGraphPlanetState = FORCE_GRAPH_PLANET_STATES.OVERVIEW;
  let forceGraphPlanetNodes = [];
  let forceGraphPlanetLinks = [];
  let forceGraphPlanetNodeById = new Map();
  const forceGraphPlanetObjects = new Map();
  const forceGraphPlanetLinkObjects = new Map();
  let forceGraphPlanetFocusId;
  let forceGraphPlanetFrame;
  let forceGraphPlanetTransitionStartedAt = 0;
  let forceGraphPlanetSphereGeometry;
  let forceGraphSphere3D;
  let forceGraphSphereNodes = [];
  const forceSphereCardObjects = new Map();
  const forceSphereCardGeometryCache = new Map();
  const forceSphereCardSlots = [];
  const forceSphereSeenAtomIds = new Set();
  let forceSphereCardFrontier = [];
  let forceSphereCardFocusId;
  let forceSphereCardLastStreamNormal;
  let forceSphereCardStreamSerial = 0;
  let forceSphereCardCameraInitialized = false;
  let forceSphereCardViewportFrame;
  let forceSphereCardVisibilityKey = '';
  let forceSphereCardAvailableNodes = knowledgeNodes;
  let forceSphereCardAvailableEdges = knowledgeEdges;
  const forceSphereMorphObjects = new Map();
  const forceSphereMorphLinks = new Map();
  let forceSphereMorphNodes = [];
  let forceSphereMorphNodeById = new Map();
  let forceSphereMorphActiveLinks = [];
  let forceSphereMorphFocusIds = [];
  let forceSphereMorphState = MORPH_CLUSTER_STATES.OVERVIEW;
  let forceSphereMorphFrame;
  let forceSphereMorphTransitionStartedAt = 0;
  let forceSphereMorphDirection = 1;
  let forceSphereMorphCameraStart;
  let forceSphereMorphCameraTarget;
  let forceSphereMorphClusterScale = 1;
  let forceSphereMorphClusterOpacity = 1;
  let forceSphereMorphSphereGeometry;
  let globe;
  let cardGlobe;
  let cardGlobeObjects = [];
  let cardGlobeControls;
  let cardGlobeResizeObserver;
  let cardGlobePoints = [];
  let cardGlobeArcs = [];
  let cardGlobeArcVisibilityFrame;
  let cardGlobeArcVisibilityKey = '';
  let focusedGlobe;
  let focusedGlobeControls;
  let focusedGlobeLightingCleanup;
  let focusedGlobeResizeObserver;
  let focusedGlobePoints = [];
  let focusedGlobeLastFocusId;
  let mixedGlobeLastFocusId;
  let focusedGlobeLodKey = '';
  const focusedGlobeNodeCache = new Map();
  const focusedGlobeSpreadCache = new Map();
  const focusedGlobeObjectCache = new Map();
  const focusedCurvedGeometryCache = new Map();
  const ROLLING_FOCUS_CONTEXT_COUNT = 7;
  const ROLLING_ACTIVE_CARD_COUNT = 20;
  const ROLLING_PREFETCH_CARD_COUNT = 12;
  // A Globe Objects Layerben legfeljebb ennyi aktív, részletes kártya él.
  // A harmadik réteg csak előkészített adat, és a horizon közelében lép át
  // az Objects Layerbe. A cache ugyanazokat a Three.js objektumokat tartja
  // meg fókuszváltások között is.
  const ROLLING_CARD_POOL_SIZE = ROLLING_ACTIVE_CARD_COUNT + ROLLING_PREFETCH_CARD_COUNT;
  const ROLLING_STREAM_STEP_DEGREES = 12;
  const ROLLING_CARD_ALTITUDE = .025;
  const ROLLING_VISIBLE_FACING = .20;
  const ROLLING_PREFETCH_FACING = -.30;
  const ROLLING_HIDDEN_FACING = -.48;
  let rollingGlobe;
  let rollingGlobeControls;
  let rollingGlobeResizeObserver;
  const rollingGlobeObjectCache = new Map();
  const rollingGlobeFreeCards = [];
  const rollingCurvedGeometryCache = new Map();
  let rollingGlobeActiveCards = [];
  let rollingGlobePrefetchedCards = [];
  let rollingGlobeFrontier = [];
  let rollingGlobeActiveEdges = [];
  let rollingGlobeViewportFrame;
  let rollingGlobeLastMembershipKey = '';
  let rollingLatestPov = { lat: 0, lng: 0, altitude: 2.1 };
  let rollingGlobeLastStreamPov = { lat: 0, lng: 0 };
  let rollingFocusAnchor = { lat: 0, lng: 0 };
  let rollingFocusAnimationUntil = 0;
  let rollingFocusInteractionLocked = false;
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
  let forceSphereLastCullingNormal;
  let globeResizeObserver;
  let staticAtomGlobeResizeObserver;

  function persist() {
    safeWrite(STORAGE_KEY, {
      centerId: state.centerId, selectedId: state.selectedId, focusedGlobeId: state.focusedGlobeId, rollingGlobeId: state.rollingGlobeId, virtualOffsetX: state.virtualOffsetX, virtualOffsetY: state.virtualOffsetY, history: state.history, zoom: state.zoom, panX: state.panX, panY: state.panY,
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

  function isMixedFocusedGlobeView() { return state.visualization === 'globe-focused-mixed'; }

  function isRollingCardGlobeView() { return state.visualization === 'globe-rolling-cards'; }

  function isFocusedG6View() { return state.visualization === 'g6-focused-map' || state.visualization === 'g6-focused-map-dark'; }
  function isFocusedG6DarkView() { return state.visualization === 'g6-focused-map-dark'; }

  function isFocusedG6V2View() { return state.visualization === 'g6-focused-map-v2' || state.visualization === 'g6-focused-map-v2-dark'; }
  function isFocusedG6V2DarkView() { return state.visualization === 'g6-focused-map-v2-dark'; }

  function isStaticAtomGlobeView() { return state.visualization === 'globe-static-atoms'; }

  function isCytoscapeView() { return state.visualization === 'cytoscape-cose'; }

  function isAnyGlobeView() { return isGlobeView() || isCardGlobeView() || isFocusedCardGlobeView() || isMixedFocusedGlobeView() || isRollingCardGlobeView() || isStaticAtomGlobeView(); }

  function isForce3DView() { return state.visualization === '3d-force-graph'; }
  function isForceUniverseDemoView() { return state.visualization === '3d-force-globe-demo'; }

  function isForceGraphMorphView() { return state.visualization === '3d-force-graph-morph'; }

  function isForceSphereCardsView() { return state.visualization === '3d-force-globe-cards'; }

  function isForceSphereMorphView() { return state.visualization === '3d-force-globe-morph'; }

  function isForceSphereView() { return state.visualization === '3d-force-globe' || isForceSphereCardsView() || isForceSphereMorphView(); }

  function updateTopicFavorite() {
    topicFavorite.textContent = topicIsFavorite ? '★' : '☆';
    topicFavorite.setAttribute('aria-pressed', String(topicIsFavorite));
    topicFavorite.setAttribute('aria-label', topicIsFavorite ? 'Téma eltávolítása a kedvencek közül' : 'Téma kedvencnek jelölése');
  }

  function updateVisualizationSelector() {
    const current = VISUALIZATION_BY_ID.get(state.visualization) || VISUALIZATION_BY_ID.get('g6-focused-map');
    const trigger = screen.querySelector('[data-map-action="toggle-layout-menu"]');
    const currentLabel = screen.querySelector('[data-map-layout-current]');
    const menu = screen.querySelector('[data-map-layout-menu]');
    const options = screen.querySelector('[data-map-layout-options]');
    if (currentLabel) currentLabel.textContent = current.label;
    if (trigger) trigger.setAttribute('aria-expanded', String(state.layoutMenuOpen));
    if (menu) menu.hidden = !state.layoutMenuOpen;
    mapCanvas?.classList.toggle('is-globe-view', isAnyGlobeView());
    mapCanvas?.classList.toggle('is-force3d-view', isForce3DView() || isForceUniverseDemoView() || isForceGraphMorphView() || isForceSphereView());
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
    if (state.visualization === 'd3-force-3d' || isFocusedG6View() || isFocusedG6V2View() || isAnyGlobeView() || isForce3DView() || isForceUniverseDemoView() || isForceGraphMorphView() || isForceSphereView()) return undefined;
    const width = Math.max(mapContainer.clientWidth || 0, 320);
    const height = Math.max(mapContainer.clientHeight || 0, 420);
    const center = [width / 2, height / 2];
    const base = { type: state.visualization, width, height, center };
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
    return base;
  }

  function destroyG6Graph() {
    resizeObserver?.disconnect();
    resizeObserver = undefined;
    graphReady = false;
    focusedG6V2LastFocusId = undefined;
    focusedG6V2LodKey = '';
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
    if (cardGlobeArcVisibilityFrame) window.cancelAnimationFrame(cardGlobeArcVisibilityFrame);
    cardGlobeArcVisibilityFrame = undefined;
    cardGlobeArcVisibilityKey = '';
    cardGlobeArcs = [];
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
    focusedGlobeLightingCleanup?.();
    focusedGlobeLightingCleanup = undefined;
    focusedGlobeResizeObserver?.disconnect();
    focusedGlobeResizeObserver = undefined;
    focusedGlobe?.objectsData?.([]);
    disposeFocusedGlobeObjects();
    focusedGlobeControls = undefined;
    try { focusedGlobe?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    focusedGlobe = undefined;
    focusedGlobePoints = [];
    focusedGlobeLastFocusId = undefined;
    mixedGlobeLastFocusId = undefined;
    focusedGlobeLodKey = '';
    focusedGlobeNodeCache.clear();
    focusedGlobeSpreadCache.clear();
    focusedGlobeContainer?.replaceChildren();
    if (focusedGlobeContainer) focusedGlobeContainer.hidden = true;
  }

  function disposeRollingGlobeObjects() {
    const records = new Set([...rollingGlobeObjectCache.values(), ...rollingGlobeFreeCards]);
    records.forEach((record) => {
      record.texture?.dispose?.();
      record.material?.dispose?.();
    });
    rollingGlobeObjectCache.clear();
    rollingGlobeFreeCards.length = 0;
    rollingCurvedGeometryCache.forEach((geometry) => geometry.dispose?.());
    rollingCurvedGeometryCache.clear();
  }

  function destroyRollingCardGlobe() {
    rollingGlobeResizeObserver?.disconnect();
    rollingGlobeResizeObserver = undefined;
    if (rollingGlobeViewportFrame) window.cancelAnimationFrame(rollingGlobeViewportFrame);
    rollingGlobeViewportFrame = undefined;
    rollingGlobe?.objectsData?.([]);
    rollingGlobe?.arcsData?.([]);
    disposeRollingGlobeObjects();
    rollingGlobeControls = undefined;
    try { rollingGlobe?._destructor?.(); } catch { /* Egy másik nézet ettől még megnyitható. */ }
    rollingGlobe = undefined;
    rollingGlobeActiveCards = [];
    rollingGlobePrefetchedCards = [];
    rollingGlobeFrontier = [];
    rollingGlobeActiveEdges = [];
    rollingGlobeLastMembershipKey = '';
    rollingFocusAnchor = { lat: 0, lng: 0 };
    rollingFocusAnimationUntil = 0;
    rollingFocusInteractionLocked = false;
    rollingGlobeContainer?.replaceChildren();
    if (rollingGlobeContainer) rollingGlobeContainer.hidden = true;
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
    forceUniverseControls?.removeEventListener?.('change', forceUniverseControlsHandler);
    forceUniverseControls = undefined;
    forceUniverseControlsHandler = undefined;
    if (forceUniverseLodFrame) window.cancelAnimationFrame(forceUniverseLodFrame);
    if (forceUniverseTransitionFrame) window.cancelAnimationFrame(forceUniverseTransitionFrame);
    forceUniverseLodFrame = undefined;
    forceUniverseTransitionFrame = undefined;
    if (forceUniverseDetailGlobe) {
      forceUniverseDetailGlobe.removeFromParent?.();
      forceUniverseDetailGlobe.visible = false;
    }
    forceUniverseDetailGlobe = undefined;
    forceUniverseDetailPlanetId = null;
    forceUniverseLodState = 'GALAXY';
    forceUniversePlanetViews.clear();
    force3dResizeObserver?.disconnect();
    force3dResizeObserver = undefined;
    if (forceGraphPlanetFrame) window.cancelAnimationFrame(forceGraphPlanetFrame);
    forceGraphPlanetFrame = undefined;
    forceGraphPlanetObjects.forEach((group) => group.traverse((object) => {
      if (!object.isMesh) return;
      object.material?.dispose?.();
    }));
    forceGraphPlanetObjects.clear();
    forceGraphPlanetLinkObjects.forEach((line) => {
      line.geometry?.dispose?.();
      line.material?.dispose?.();
    });
    forceGraphPlanetLinkObjects.clear();
    forceGraphPlanetSphereGeometry?.dispose?.();
    forceGraphPlanetSphereGeometry = undefined;
    forceGraphPlanetNodes = [];
    forceGraphPlanetLinks = [];
    forceGraphPlanetNodeById = new Map();
    forceGraphPlanetFocusId = undefined;
    forceGraphPlanetTransitionStartedAt = 0;
    forceGraphPlanetState = FORCE_GRAPH_PLANET_STATES.OVERVIEW;
    mapCanvas?.classList.remove('is-force-planet-transition');
    mapCanvas?.style.removeProperty('--force-planet-map-progress');
    mapCanvas?.style.removeProperty('--force-morph-cluster-opacity');
    mapCanvas?.style.removeProperty('--force-sphere-scale');
    if (forceGraphMorphFrame) window.cancelAnimationFrame(forceGraphMorphFrame);
    forceGraphMorphFrame = undefined;
    forceGraphMorphObjects.forEach((group) => group.traverse((object) => {
      if (!object.isMesh) return;
      object.material?.map?.dispose?.();
      object.material?.dispose?.();
    }));
    forceGraphMorphObjects.clear();
    forceGraphMorphLinkObjects.forEach((line) => {
      line.geometry?.dispose?.();
      line.material?.dispose?.();
    });
    forceGraphMorphLinkObjects.clear();
    forceGraphMorphCardGeometry?.dispose?.();
    forceGraphMorphCardGeometry = undefined;
    forceGraphMorphSphereGeometry?.dispose?.();
    forceGraphMorphSphereGeometry = undefined;
    forceGraphMorphNodes = [];
    forceGraphMorphLinks = [];
    forceGraphMorphNodeById = new Map();
    forceGraphMorphFocusIds = [];
    forceGraphMorphTargetPositions = undefined;
    forceGraphMorphCameraStart = undefined;
    forceGraphMorphCameraTarget = undefined;
    forceGraphMorphPendingFocusId = undefined;
    forceGraphMorphTransitionStartedAt = 0;
    forceGraphMorphTransitionDirection = 1;
    forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.OVERVIEW;
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
    if (forceSphereCardViewportFrame) window.cancelAnimationFrame(forceSphereCardViewportFrame);
    forceSphereCardViewportFrame = undefined;
    if (forceSphereMorphFrame) window.cancelAnimationFrame(forceSphereMorphFrame);
    forceSphereMorphFrame = undefined;
    force3dSphereControls?.removeEventListener?.('change', force3dSphereControlsChangeHandler);
    force3dSphereControls = undefined;
    force3dSphereControlsChangeHandler = undefined;
    forceSphereLastCullingNormal = undefined;
    forceSphereCardObjects.forEach((root) => root.traverse((object) => {
      if (!object.isMesh) return;
      object.material?.map?.dispose?.();
      object.material?.dispose?.();
    }));
    forceSphereCardObjects.clear();
    forceSphereCardGeometryCache.forEach((geometry) => geometry.dispose?.());
    forceSphereCardGeometryCache.clear();
    forceSphereMorphObjects.forEach((root) => root.traverse((object) => {
      if (!object.isMesh) return;
      object.material?.map?.dispose?.();
      object.material?.dispose?.();
    }));
    forceSphereMorphObjects.clear();
    forceSphereMorphLinks.clear();
    forceSphereMorphSphereGeometry?.dispose?.();
    forceSphereMorphSphereGeometry = undefined;
    mapCanvas?.style.removeProperty('--force-sphere-scale');
    mapCanvas?.style.removeProperty('--force-morph-cluster-opacity');
    try { forceGraphSphere3D?._destructor?.(); } catch { /* A többi nézet ettől függetlenül váltható. */ }
    forceGraphSphere3D = undefined;
    forceGraphSphereNodes = [];
    forceSphereCardSlots.length = 0;
    forceSphereSeenAtomIds.clear();
    forceSphereCardFrontier = [];
    forceSphereCardFocusId = undefined;
    forceSphereCardLastStreamNormal = undefined;
    forceSphereCardStreamSerial = 0;
    forceSphereCardCameraInitialized = false;
    forceSphereCardVisibilityKey = '';
    forceSphereCardAvailableNodes = knowledgeNodes;
    forceSphereCardAvailableEdges = knowledgeEdges;
    forceSphereMorphNodes = [];
    forceSphereMorphNodeById = new Map();
    forceSphereMorphActiveLinks = [];
    forceSphereMorphFocusIds = [];
    forceSphereMorphState = MORPH_CLUSTER_STATES.OVERVIEW;
    forceSphereMorphTransitionStartedAt = 0;
    forceSphereMorphDirection = 1;
    forceSphereMorphCameraStart = undefined;
    forceSphereMorphCameraTarget = undefined;
    forceSphereMorphClusterScale = 1;
    forceSphereMorphClusterOpacity = 1;
    force3dSphereContainer?.replaceChildren();
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
  }

  function createActiveRenderer() {
    if (isGlobeView()) { createGlobe(); return; }
    if (isCardGlobeView()) { createCardGlobe(); return; }
    if (isFocusedCardGlobeView()) { createFocusedCardGlobe(); return; }
    if (isMixedFocusedGlobeView()) { createFocusedCardGlobe(); return; }
    if (isRollingCardGlobeView()) { createRollingCardGlobe(); return; }
    if (isStaticAtomGlobeView()) { createStaticAtomGlobe(); return; }
    if (isCytoscapeView()) { createCytoscape(); return; }
    if (isForceSphereView()) { createForceGraphSphere3D(); return; }
    if (isForceGraphMorphView()) { createForceGraphPlanet3D(); return; }
    if (isForce3DView() || isForceUniverseDemoView()) { createForceGraph3D(); return; }
    createG6Graph();
  }

  function setVisualization(visualization) {
    if (!VISUALIZATION_BY_ID.has(visualization)) return;
    if (state.visualization === visualization) { state.layoutMenuOpen = false; updateVisualizationSelector(); return; }
    state.visualization = visualization;
    if (visualization === 'globe-focused-cards' || visualization === 'globe-focused-mixed') state.focusedGlobeId = state.centerId;
    if (visualization === 'globe-rolling-cards') state.rollingGlobeId = state.centerId;
    state.layoutMenuOpen = false;
    state.zoom = 1; state.panX = 0; state.panY = 0;
    updateVisualizationSelector();
    persist();
    destroyG6Graph();
    destroyGlobe();
    destroyCardGlobe();
    destroyFocusedCardGlobe();
    destroyRollingCardGlobe();
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

  function graphNode(node, index, total, threeD = undefined) {
    const graphNode = {
      id: node.id,
      data: { ...node, z: threeD?.z || 0 },
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

  // A G6 D3 Force 3D csak vizuális preview. Hétszáz kártya és ezer él egy
  // mobil Canvas rendererben memória- és GPU-csúcsot okoz, ezért a leginkább
  // kapcsolt, determinisztikus részgráfot kapja. A többi megjelenítés továbbra
  // is a teljes közös adathalmazt használja.
  function compactD3Force3DNodes(nodes) {
    const allowedIds = new Set(nodes.map((node) => node.id));
    const degreeById = new Map(nodes.map((node) => [node.id, 0]));
    knowledgeEdges.forEach((edge) => {
      if (!allowedIds.has(edge.source) || !allowedIds.has(edge.target)) return;
      degreeById.set(edge.source, (degreeById.get(edge.source) || 0) + 1);
      degreeById.set(edge.target, (degreeById.get(edge.target) || 0) + 1);
    });
    return [...nodes]
      .sort((first, second) => {
        const firstFocus = first.id === state.centerId ? 1 : 0;
        const secondFocus = second.id === state.centerId ? 1 : 0;
        if (firstFocus !== secondFocus) return secondFocus - firstFocus;
        const degreeDelta = (degreeById.get(second.id) || 0) - (degreeById.get(first.id) || 0);
        if (degreeDelta) return degreeDelta;
        const importanceDelta = (second.importance || 0) - (first.importance || 0);
        return importanceDelta || first.id.localeCompare(second.id);
      })
      .slice(0, D3_FORCE_3D_NODE_LIMIT);
  }

  function fullGraphData(matched) {
    const isThreeD = state.visualization === 'd3-force-3d';
    const renderNodes = isThreeD ? compactD3Force3DNodes(matched) : matched;
    const projection = isThreeD ? threeDPositions(renderNodes) : undefined;
    const ordered = isThreeD ? [...renderNodes].sort((a, b) => projection.get(a.id).z - projection.get(b.id).z) : renderNodes;
    const nodes = ordered.map((node, index) => graphNode(node, index, ordered.length, projection?.get(node.id)));
    const nodeIds = new Set(renderNodes.map((node) => node.id));
    const rawEdges = knowledgeEdges
      .filter(({ source, target }) => nodeIds.has(source) && nodeIds.has(target))
      .sort((first, second) => second.weight - first.weight || first.source.localeCompare(second.source) || first.target.localeCompare(second.target));
    const edges = (isThreeD ? rawEdges.slice(0, D3_FORCE_3D_EDGE_LIMIT) : rawEdges).map((edge, index) => graphEdge(edge, index));
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
    return fullGraphData(matched);
  }

  // A G6-síkban megjelenő kártyák grafikus primitívek, nem HTML-overlayek. Így
  // a vászon pan/zoom gesztusai végig a G6-é maradnak, és a fókuszváltás csak
  // a lusta részgráf adathalmazát cseréli.
  function focusedG6GraphData(dark = false) {
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
    const colorsByDepth = dark ? {
      0: { fill: '#6B3EF6', stroke: '#B9B0E6', label: '#ECE7FF', shadow: '#2B1366' },
      1: { fill: '#B9B0E6', stroke: '#C9C4FF', label: '#21153F', shadow: '#6B3EF6' },
      2: { fill: '#8276BA', stroke: '#C9C4FF', label: '#ECE7FF', shadow: '#2B1366' },
    } : {
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
          stroke: dark ? (onPath ? '#ECE7FF' : '#C9C4FF') : (onPath ? '#7250e6' : '#b7a7dd'),
          lineWidth: onPath ? 3 : 1 + edge.weight * .7,
          opacity: onPath ? 1 : .48,
          endArrow: false,
        },
      };
    });
    return { focusId: subgraph.focusId, nodes, edges };
  }

  function renderFocusedG6Graph(animated = false) {
    const dark = isFocusedG6DarkView();
    mapContainer.style.background = dark ? '#0B0A17' : '';
    const data = focusedG6GraphData(dark);
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

  // A síkbeli V2 a V1 közeli, olvasható fókuszrendezését használja, de csak
  // néhány kiemelt útirányt tart meg. Kifelé zoomolva ugyanebből a stabil
  // világból fokozatosan több második gyűrűs irány kerül elő.
  function focusedG6V2GraphData(dark = false) {
    const lod = focusedG6V2Lod(state.zoom);
    const subgraph = buildFocusedG6V2Subgraph(state.centerId, knowledgeNodes, knowledgeEdges, { includeNode: matchesFilters, ...lod });
    const width = Math.max(mapContainer.clientWidth || 0, 320);
    const height = Math.max(mapContainer.clientHeight || 0, 420);
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
    return buildFocusedG6V2RenderData({
      focusId: state.centerId,
      nodes: knowledgeNodes,
      edges: knowledgeEdges,
      includeNode: matchesFilters,
      zoom: state.zoom,
      width,
      height,
      dark,
      pathMode: state.pathMode,
      isPathEdge: (source, target) => hasPathEdge(source, target, state.history),
      buildSubgraph: buildFocusedG6V2Subgraph,
      getLod: focusedG6V2Lod,
      getPositions: focusedG6V2Positions,
      getCardSize: focusedG6CardSize,
    });
  }

  function renderFocusedG6V2Graph(animated = false) {
    const dark = isFocusedG6V2DarkView();
    mapContainer.style.background = dark ? '#0B0A17' : '';
    const data = focusedG6V2GraphData(dark);
    if (!graphReady || !graph) return;
    if (!data) {
      graph.setData({ nodes: [], edges: [] });
      void graph.render();
      return;
    }
    graph.setData({ nodes: data.nodes, edges: data.edges });
    void Promise.resolve(graph.render()).then(() => {
      // A távoli kattintás új, a kiválasztott Atomra épített térképi világot
      // ad, majd a G6 animáltan oda helyezi a kamera fókuszát.
      const focusChanged = focusedG6V2LastFocusId !== data.focusId;
      focusedG6V2LastFocusId = data.focusId;
      focusedG6V2LodKey = data.lodKey;
      if ((focusChanged || animated) && typeof graph.focusElement === 'function') {
        void graph.focusElement(data.focusId, { duration: animated ? 460 : 0, easing: 'ease-in-out' }).then(syncViewportState);
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
    const directNeighborIds = new Set((neighborsById.get(state.centerId) || []).map((neighbor) => neighbor.id));
    cardGlobePoints = globePointData(matched).map((point) => {
      const cardTier = point.id === state.centerId ? 0 : directNeighborIds.has(point.id) ? 1 : 2;
      return {
        ...point,
        cardTier: cardTier,
        // Globe.GL-relatív magasság: éppen a felszín fölött, z-fighting nélkül.
        altitude: .012,
        visualScale: (cardTier === 0 ? 1.04 : cardTier === 1 ? .88 : .76) * (.74 + point.importance * .22),
      };
    });
    const pointById = new Map(cardGlobePoints.map((point) => [point.id, point]));
    cardGlobeArcs = knowledgeEdges
      .filter((edge) => pointById.has(edge.source) && pointById.has(edge.target))
      .map((edge) => {
        const start = pointById.get(edge.source);
        const end = pointById.get(edge.target);
        const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
        return {
          ...edge,
          startLat: start.lat, startLng: start.lng, endLat: end.lat, endLng: end.lng,
          color: '#ffffff',
          onPath,
        };
      });
    disposeCardGlobeObjects();
    cardGlobe
      .pointsData([])
      .pathsData([])
      .pathPoints('points')
      .pathPointLat('lat')
      .pathPointLng('lng')
      .pathPointAlt('altitude')
      .pathColor('color')
      .pathStroke(.22)
      .pathResolution(1)
      .pathTransitionDuration(0)
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
    cardGlobeArcVisibilityKey = '';
    renderVisibleCardGlobeArcs(true);
  }

  function renderVisibleCardGlobeArcs(force = false) {
    if (!cardGlobe) return;
    const pointById = new Map(cardGlobePoints.map((point) => [point.id, point]));
    const pov = cardGlobe.pointOfView?.() || { lat: 0, lng: 0 };
    const visibleEdges = filterCardGlobeArcs(cardGlobeArcs, pointById, pov);
    const key = visibleEdges.map((edge) => `${edge.source}:${edge.target}`).sort().join('|');
    if (!force && key === cardGlobeArcVisibilityKey) return;
    cardGlobeArcVisibilityKey = key;
    const paths = visibleEdges.map((edge) => {
      const start = pointById.get(edge.source);
      const end = pointById.get(edge.target);
      return {
        ...edge,
        points: buildCardGlobeSurfacePath(start, end, 18, .015),
        color: edge.color,
      };
    });
    cardGlobe.pathsData(paths);
  }

  function scheduleCardGlobeArcVisibility() {
    if (cardGlobeArcVisibilityFrame) return;
    cardGlobeArcVisibilityFrame = window.requestAnimationFrame(() => {
      cardGlobeArcVisibilityFrame = undefined;
      renderVisibleCardGlobeArcs();
    });
  }

  function knowledgeCardTierPalette(point) {
    const tiers = {
      0: { top: '#7954ed', bottom: '#6341d2', stroke: '#6341d2', meta: 'rgba(255,255,255,.72)', title: '#ffffff', subtitle: 'rgba(250,244,255,.84)' },
      1: { top: '#ffffff', bottom: '#faf8ff', stroke: '#d8cbed', meta: '#776c87', title: '#494154', subtitle: '#675e72' },
      2: { top: '#faf8ff', bottom: '#f2eef9', stroke: '#e7def5', meta: '#847a91', title: '#675e72', subtitle: '#847a90' },
    };
    if (Number.isInteger(point.cardTier)) return tiers[point.cardTier] || tiers[2];
    const selected = point.isFocused || point.id === state.selectedId;
    return selected
      ? { top: '#ECE7FF', bottom: '#D9D0FA', stroke: '#ffffff', meta: '#6B3EF6', title: '#2B1366', subtitle: '#4E3A87' }
      : { top: '#B9B0E6', bottom: '#8276BA', stroke: '#C9C4FF', meta: '#51457E', title: '#21153F', subtitle: '#45396F' };
  }

  function drawCardTexture(point) {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 256;
    const context = canvas.getContext('2d');
    const palette = knowledgeCardTierPalette(point);
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, palette.top);
    gradient.addColorStop(1, palette.bottom);
    context.fillStyle = gradient;
    context.roundRect?.(5, 5, 502, 246, 30);
    if (!context.roundRect) {
      context.beginPath();
      context.moveTo(35, 5); context.arcTo(507, 5, 507, 251, 30); context.arcTo(507, 251, 5, 251, 30);
      context.arcTo(5, 251, 5, 5, 30); context.arcTo(5, 5, 507, 5, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = 5;
    context.strokeStyle = palette.stroke;
    context.stroke();
    context.fillStyle = palette.meta;
    context.font = '700 27px system-ui, sans-serif';
    context.fillText(TYPE_META[point.type].label.toUpperCase(), 34, 54);
    context.fillStyle = palette.title;
    context.font = '800 49px system-ui, sans-serif';
    context.fillText(point.title.length > 22 ? `${point.title.slice(0, 21)}…` : point.title, 34, 120);
    context.fillStyle = palette.subtitle;
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
      object.material?.map?.dispose?.();
      object.material?.dispose?.();
    }));
    focusedGlobeObjectCache.clear();
    focusedCurvedGeometryCache.forEach((geometry) => geometry.dispose?.());
    focusedCurvedGeometryCache.clear();
  }

  function focusedCurvedCardGeometry() {
    const width = 37;
    const height = 18.5;
    const globeRadius = focusedGlobe?.getGlobeRadius?.() || 100;
    const radiusX = globeRadius * 1.15;
    const radiusY = globeRadius * 1.8;
    const key = `${width}:${height}:16:8:${Math.round(radiusX)}:${Math.round(radiusY)}`;
    const cached = focusedCurvedGeometryCache.get(key);
    if (cached) return cached;
    const geometry = new THREE.PlaneGeometry(37, 18.5, 16, 8);
    bendCardToSphereGeometry(geometry, radiusX, radiusY);
    focusedCurvedGeometryCache.set(key, geometry);
    return geometry;
  }

  // A Globe.GL az ezt visszaadó külső Groupot helyezi a lat/lng anchorra és
  // forgatja a felszín normáljára. A fókuszált változat belső meshe már nem
  // sík: a vertexei a gömb felé hajlanak, de a groupot továbbra is a Globe.GL
  // rögzíti az Atom földrajzi pozíciójához.
  function makeKnowledgeCardObject(point, { curved = false } = {}) {
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
    const card = new THREE.Mesh(curved ? focusedCurvedCardGeometry() : new THREE.PlaneGeometry(37, 18.5), material);
    card.userData.sharedFocusedGeometry = curved;
    // A görbített szélek a lokális negatív Z felé húzódnak. Ez a kis kiemelés
    // megakadályozza, hogy a szélek a felszínbe süllyedjenek vagy z-fightoljanak.
    if (curved) card.position.z = .9;
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
    const group = makeKnowledgeCardObject(point, { curved: true });
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
      .showGraticules(false)
      .onZoom(scheduleCardGlobeArcVisibility);
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

  function buildFocusedGlobeSpread(nodes, focusId, anchor) {
    const normalizedAnchor = anchor || PERSISTENT_GLOBE_COORDINATES.get(focusId) || { lat: 0, lng: 0 };
    const key = `${focusId}|${normalizedAnchor.lat.toFixed(4)}|${normalizedAnchor.lng.toFixed(4)}|${nodes.map((node) => node.id).sort().join(',')}`;
    const cached = focusedGlobeSpreadCache.get(key);
    if (cached) return cached;
    const anchorNormal = globeSurfaceNormal(normalizedAnchor);
    const orient = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), anchorNormal);
    const spread = new Map([[focusId, { lat: normalizedAnchor.lat, lng: normalizedAnchor.lng }]]);
    const others = nodes.filter((node) => node.id !== focusId).sort((a, b) => a.id.localeCompare(b.id));
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));
    others.forEach((node, index) => {
      // Fibonacci-gömb: nincs előre kiosztott világpozíció, az aktuális
      // fókusz köré készül új, egyenletes eloszlás elöl/hátul/oldalt.
      const t = (index + .5) / Math.max(others.length, 1);
      const z = 1 - 2 * t;
      const radius = Math.sqrt(Math.max(0, 1 - z * z));
      const theta = index * goldenAngle + (Math.abs(hash(`${focusId}:${node.id}`)) % 360) * Math.PI / 180 * .08;
      const local = new THREE.Vector3(radius * Math.cos(theta), radius * Math.sin(theta), z)
        .applyQuaternion(orient)
        .normalize();
      spread.set(node.id, globeCoordinatesFromNormal(local));
    });
    focusedGlobeSpreadCache.set(key, spread);
    return spread;
  }

  function focusedGlobePointData(nodes, focusId, spread = buildFocusedGlobeSpread(nodes, focusId)) {
    return nodes.map((node) => {
      const position = spread.get(node.id) || PERSISTENT_GLOBE_COORDINATES.get(node.id);
      let point = focusedGlobeNodeCache.get(node.id);
      if (!point) {
        point = { ...node, lat: position.lat, lng: position.lng, altitude: .025, visualScale: .9 + node.importance * .25 };
        focusedGlobeNodeCache.set(node.id, point);
      }
      point.lat = position.lat;
      point.lng = position.lng;
      point.isFocused = node.id === focusId;
      point.visualScale = (point.isFocused ? 1.16 : 1) * (.9 + node.importance * .25);
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

  // A fókusz és a kamera koordinátája változatlan marad. Csak az egymásra
  // kerülő környezeti kártyák kapnak kis, lokális gömbi eltolást; így a
  // fókuszba forgatás nem ugrik el, de két kártya nem renderelődik egymásra.
  function separateFocusedGlobeCards(points, focusId, anchor) {
    const resolvedAnchor = anchor || PERSISTENT_GLOBE_COORDINATES.get(focusId) || { lat: 0, lng: 0 };
    const cosLat = Math.max(.35, Math.cos(THREE.MathUtils.degToRad(resolvedAnchor.lat)));
    const items = points.map((point) => ({
      point,
      x: (((point.lng - resolvedAnchor.lng + 540) % 360) - 180) * cosLat,
      y: point.lat - resolvedAnchor.lat,
      fixed: point.id === focusId,
    }));
    for (let pass = 0; pass < 36; pass += 1) {
      let changed = false;
      for (let firstIndex = 0; firstIndex < items.length; firstIndex += 1) {
        for (let secondIndex = firstIndex + 1; secondIndex < items.length; secondIndex += 1) {
          const first = items[firstIndex];
          const second = items[secondIndex];
          let dx = second.x - first.x;
          let dy = second.y - first.y;
          let distance = Math.hypot(dx, dy);
          if (distance < .001) {
            const direction = Math.abs(hash(`${first.point.id}:${second.point.id}`)) % 2 ? 1 : -1;
            dx = direction;
            dy = .35 * direction;
            distance = Math.hypot(dx, dy);
          }
          const minimum = first.fixed || second.fixed ? 29 : 24;
          if (distance >= minimum) continue;
          const push = (minimum - distance) * .55;
          const ux = dx / distance;
          const uy = dy / distance;
          if (first.fixed) {
            second.x += ux * push;
            second.y += uy * push;
          } else if (second.fixed) {
            first.x -= ux * push;
            first.y -= uy * push;
          } else {
            first.x -= ux * push * .5;
            first.y -= uy * push * .5;
            second.x += ux * push * .5;
            second.y += uy * push * .5;
          }
          changed = true;
        }
      }
      if (!changed) break;
    }
    items.forEach(({ point, x, y, fixed }) => {
      if (fixed) return;
      point.lat = clamp(resolvedAnchor.lat + y, -78, 78);
      point.lng = ((resolvedAnchor.lng + x / cosLat + 540) % 360) - 180;
    });
    return points;
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
    const previousFocusPoint = focusedGlobeNodeCache.get(focusId);
    const focusAnchor = previousFocusPoint
      ? { lat: previousFocusPoint.lat, lng: previousFocusPoint.lng }
      : (PERSISTENT_GLOBE_COORDINATES.get(focusId) || { lat: 0, lng: 0 });
    const spread = buildFocusedGlobeSpread(subgraph.nodes, focusId, focusAnchor);
    focusedGlobePoints = separateFocusedGlobeCards(
      focusedGlobePointData(subgraph.nodes, focusId, spread),
      focusId,
      focusAnchor,
    );
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
        // A kártyák nem a gömb felszínén, hanem egy vékony légrétegen ülnek.
        // Az ív végpontjai is ugyanerről a rétegről induljanak, különben az
        // Arc Layer a gömb belsejébe süllyed, mielőtt felemelkedne.
        startAltitude: (start.altitude ?? .025) + .028,
        endAltitude: (end.altitude ?? .025) + .028,
        color: '#C9C4FF',
        altitude: onPath
          ? Math.max(.40, globeFocusedAirArcAltitude(start, end, .13))
          : globeFocusedAirArcAltitude(start, end, .12) + edge.weight * .025,
      };
    });
    focusedGlobe
      .pointsData([])
      .pathsData([])
      .arcsData(arcs)
      .arcStartLat('startLat')
      .arcStartLng('startLng')
      .arcStartAltitude('startAltitude')
      .arcEndLat('endLat')
      .arcEndLng('endLng')
      .arcEndAltitude('endAltitude')
      .arcColor('color')
      .arcAltitude('altitude')
      .arcStroke(.16)
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

    const focusPosition = focusAnchor;
    if (focusedGlobeLastFocusId !== focusId || animated) {
      focusedGlobe.pointOfView({ lat: focusPosition.lat, lng: focusPosition.lng, altitude: clamp(cameraAltitude, 1.05, 3.6) }, animated ? 700 : 0);
      focusedGlobeLastFocusId = focusId;
    }
    focusedGlobeLodKey = lod.key;
  }

  // A Mixed ugyanazt a fókusz + kontextus szűrést használja, mint a síkbeli
  // térkép. A G6-kártyák lokális koordinátái kerülnek a gömb kamera előtti
  // sapkájára, ezért a rendezés a térképből ismerős, miközben a kártyák és a
  // kapcsolatok valódi 3D görbületet követnek.
  function mixedGlobePointData(nodes, focusId) {
    const width = 360;
    const height = 560;
    const positions = focusedG6Positions(nodes, focusId, width, height);
    return nodes.map((node) => {
      const mapPosition = positions.get(node.id) || { x: width / 2, y: height / 2 };
      const capPosition = projectFocusedMapPointToGlobeCap(mapPosition, width, height);
      let point = focusedGlobeNodeCache.get(node.id);
      if (!point) {
        point = { ...node, ...capPosition, altitude: .025, visualScale: .8 };
        focusedGlobeNodeCache.set(node.id, point);
      }
      point.lat = capPosition.lat;
      point.lng = capPosition.lng;
      point.isFocused = node.id === focusId;
      point.visualScale = (point.isFocused ? 1.12 : 1) * (.74 + node.importance * .2);
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

  function mixedSurfacePaths(edges, pointsById) {
    return edges.map((edge, index) => {
      const start = pointsById.get(edge.source);
      const end = pointsById.get(edge.target);
      const direction = index % 2 ? 1 : -1;
      const midpoint = [
        (start.lat + end.lat) / 2 + direction * 2.4,
        (start.lng + end.lng) / 2 - direction * 3.2,
        .033,
      ];
      const onPath = state.pathMode && hasPathEdge(edge.source, edge.target, state.history);
      return {
        ...edge,
        points: [[start.lat, start.lng, .03], midpoint, [end.lat, end.lng, .03]],
        color: onPath ? '#fff9c9' : Math.max(start.focusDepth || 0, end.focusDepth || 0) <= 1 ? '#b7a7dd' : '#ddd6e9',
        stroke: onPath ? .22 : Math.max(start.focusDepth || 0, end.focusDepth || 0) <= 1 ? .13 : .09,
      };
    });
  }

  function renderFocusedMixedGlobe(animated = false) {
    const focusId = nodeById.has(state.focusedGlobeId) ? state.focusedGlobeId : state.centerId;
    state.focusedGlobeId = focusId;
    // A mixed layout a síkbeli fókuszált térkép stabil, legfeljebb kétgyűrűs
    // részgráfját használja; ez megőrzi az olvasható 3D card densityt.
    const subgraph = buildFocusedG6Subgraph(focusId, knowledgeNodes, knowledgeEdges, {
      includeNode: matchesFilters,
      firstRingLimit: 6,
      secondRingPerNode: 1,
      maxNodes: 12,
    });
    empty.hidden = subgraph.nodes.length > 0;
    mapContainer.hidden = true;
    if (focusedGlobeContainer) focusedGlobeContainer.hidden = !empty.hidden;
    if (!empty.hidden || !focusedGlobe) { visibleNodeIds = []; renderBreadcrumb(); return; }
    focusedGlobePoints = mixedGlobePointData(subgraph.nodes, focusId);
    visibleNodeIds = focusedGlobePoints.map((point) => point.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    const pointsById = new Map(focusedGlobePoints.map((point) => [point.id, point]));
    const paths = mixedSurfacePaths(subgraph.edges, pointsById);
    focusedGlobe
      .pointsData([])
      .arcsData([])
      .pathsData(paths)
      .pathPoints('points')
      .pathPointLat((point) => point[0])
      .pathPointLng((point) => point[1])
      .pathPointAlt((point) => point[2])
      .pathColor('color')
      .pathStroke('stroke')
      .pathDashLength(1)
      .pathDashGap(0)
      .pathDashAnimateTime(0)
      .pathTransitionDuration(0)
      .objectsData(focusedGlobePoints)
      .objectLat('lat')
      .objectLng('lng')
      .objectAltitude('altitude')
      .objectFacesSurface(true)
      .objectThreeObject(createFocusedKnowledgeCard)
      .onObjectClick((point) => navigateTo(point.id))
      .onObjectHover((point) => { focusedGlobeContainer.style.cursor = point ? 'pointer' : 'grab'; });
    if (mixedGlobeLastFocusId !== focusId || animated) {
      const altitude = clamp(focusedGlobe?.pointOfView?.().altitude || 2.1, 1.05, 3.6);
      focusedGlobe.pointOfView({ lat: 0, lng: 0, altitude }, animated ? 650 : 0);
      mixedGlobeLastFocusId = focusId;
    }
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
    const texture = `data:image/svg+xml;charset=utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512"><rect width="100%" height="100%" fill="#7546bd"/></svg>')}`;
    focusedGlobe = new Globe(focusedGlobeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(focusedGlobeContainer.clientWidth, 320))
      .height(Math.max(focusedGlobeContainer.clientHeight, 420))
      .backgroundColor('#0B0A17')
      .globeImageUrl(texture)
      .showAtmosphere(false)
      .showGraticules(false)
      .onGlobeReady(() => {
        const sourceMaterial = focusedGlobe.globeMaterial?.();
        focusedGlobe.globeMaterial(new THREE.MeshPhongMaterial({
          map: sourceMaterial?.map || null,
          color: '#6337d5',
          shininess: 45,
          specular: new THREE.Color('#bba8ff'),
        }));
      })
      // Zoom közben a kártyakészlet és a lokális pozíciók változatlanok
      // maradnak. Nem fut újra LOD-layout, ezért a kártyák nem ugranak és nem
      // tűnnek el pusztán attól, hogy távolabbról nézzük a gömböt.
      .onZoom(() => {});
    focusedGlobeContainer.style.background = '#0B0A17';
    focusedGlobeControls = focusedGlobe.controls?.();
    if (focusedGlobeControls) {
      focusedGlobeControls.enablePan = false;
      focusedGlobeControls.screenSpacePanning = false;
      focusedGlobeControls.target?.set?.(0, 0, 0);
      focusedGlobeControls.enableDamping = true;
      focusedGlobeControls.dampingFactor = .08;
    }
    const camera = focusedGlobe.camera();
    const controls = focusedGlobeControls;
    const scene = focusedGlobe.scene();
    const ambientLight = new THREE.AmbientLight(0x4b286f, .6);
    const keyLight = new THREE.DirectionalLight(0xf0eaff, 3.0);
    const lightTarget = new THREE.Object3D();
    scene.add(lightTarget);
    keyLight.target = lightTarget;
    focusedGlobe.lights([ambientLight, keyLight]);
    const cameraRelativeOffset = new THREE.Vector3(1.5, .25, 2.2);
    const worldOffset = new THREE.Vector3();
    const cameraQuaternion = new THREE.Quaternion();
    const updateCameraRelativeLighting = () => {
      const globeCenter = controls?.target || new THREE.Vector3();
      lightTarget.position.copy(globeCenter);
      camera.getWorldQuaternion(cameraQuaternion);
      worldOffset.copy(cameraRelativeOffset).applyQuaternion(cameraQuaternion).normalize().multiplyScalar(350);
      keyLight.position.copy(globeCenter).add(worldOffset);
      lightTarget.updateMatrixWorld();
      keyLight.updateMatrixWorld();
    };
    controls?.addEventListener?.('change', updateCameraRelativeLighting);
    updateCameraRelativeLighting();
    focusedGlobeLightingCleanup = () => {
      controls?.removeEventListener?.('change', updateCameraRelativeLighting);
      scene.remove(lightTarget);
    };
    focusedGlobeResizeObserver = new ResizeObserver(() => {
      focusedGlobe?.width(Math.max(focusedGlobeContainer.clientWidth, 320)).height(Math.max(focusedGlobeContainer.clientHeight, 420));
    });
    focusedGlobeResizeObserver.observe(focusedGlobeContainer);
    if (isMixedFocusedGlobeView()) renderFocusedMixedGlobe();
    else renderFocusedCardGlobe();
  }

  // A Globe.GL külső Object Groupját a könyvtár rögzíti a lat/lng anchorra.
  // A belső mesh sűrű, ívelt geometriája ettől külön követi a gömb felszínét.
  function rollingCurvedCardGeometry() {
    const width = 37;
    const height = 18.5;
    const globeRadius = rollingGlobe?.getGlobeRadius?.() || 100;
    const radiusX = globeRadius * 1.15;
    const radiusY = globeRadius * 1.8;
    const key = `${width}:${height}:16:8:${Math.round(radiusX)}:${Math.round(radiusY)}`;
    const cached = rollingCurvedGeometryCache.get(key);
    if (cached) return cached;
    const geometry = new THREE.PlaneGeometry(37, 18.5, 16, 8);
    bendCardToSphereGeometry(geometry, radiusX, radiusY);
    rollingCurvedGeometryCache.set(key, geometry);
    return geometry;
  }

  function drawRollingGlobeCardTexture(record, card) {
    const { canvas, context, texture } = record;
    const palette = knowledgeCardTierPalette(card);
    context.clearRect(0, 0, canvas.width, canvas.height);
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, palette.top);
    gradient.addColorStop(1, palette.bottom);
    context.fillStyle = gradient;
    context.beginPath();
    context.roundRect?.(5, 5, 502, 246, 30);
    if (!context.roundRect) {
      context.moveTo(35, 5); context.arcTo(507, 5, 507, 251, 30); context.arcTo(507, 251, 5, 251, 30);
      context.arcTo(5, 251, 5, 5, 30); context.arcTo(5, 5, 507, 5, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = 5;
    context.strokeStyle = palette.stroke;
    context.stroke();
    context.fillStyle = palette.meta;
    context.font = '700 27px system-ui, sans-serif';
    context.fillText(TYPE_META[card.type].label.toUpperCase(), 34, 54);
    context.fillStyle = palette.title;
    context.font = '800 49px system-ui, sans-serif';
    context.fillText(card.title.length > 22 ? `${card.title.slice(0, 21)}…` : card.title, 34, 120);
    context.fillStyle = palette.subtitle;
    context.font = '400 29px system-ui, sans-serif';
    context.fillText(card.subtitle.length > 31 ? `${card.subtitle.slice(0, 30)}…` : card.subtitle, 34, 173);
    texture.needsUpdate = true;
  }

  function createRollingGlobeCardRecord() {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 256;
    const context = canvas.getContext('2d');
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    const material = new THREE.MeshBasicMaterial({
      map: texture, transparent: true, depthTest: true, depthWrite: true, side: THREE.FrontSide,
    });
    const mesh = new THREE.Mesh(rollingCurvedCardGeometry(), material);
    mesh.position.z = .9;
    const object = new THREE.Group();
    object.add(mesh);
    return { object, mesh, material, canvas, context, texture, cardId: undefined, lastTier: undefined };
  }

  function ensureRollingGlobeCardPool() {
    while (rollingGlobeFreeCards.length + rollingGlobeObjectCache.size < ROLLING_CARD_POOL_SIZE) {
      rollingGlobeFreeCards.push(createRollingGlobeCardRecord());
    }
  }

  // Globe.GL a külső groupot helyezi el és forgatja; ez a factory ezért csak
  // valódi Three.js kártya-mesht ad vissza. Nincs DOM/CSS2D overlay és nincs
  // képernyőkoordinátás drag-állapot. Az object nem Atom-tulajdon: a korlátos
  // poolból kapja meg az épp aktív card, majd kilépéskor visszakerül oda.
  function createRollingGlobeCard(card) {
    const cached = rollingGlobeObjectCache.get(card.id);
    if (cached) return cached.object;
    ensureRollingGlobeCardPool();
    const record = rollingGlobeFreeCards.pop() || createRollingGlobeCardRecord();
    record.cardId = card.id;
    record.lastTier = undefined;
    record.object.name = `djinn-globe-focused-card-${card.id}`;
    record.object.userData.atomId = card.id;
    record.object.visible = true;
    rollingGlobeObjectCache.set(card.id, record);
    drawRollingGlobeCardTexture(record, card);
    return record.object;
  }

  function updateRollingGlobeCard(object, card) {
    const record = rollingGlobeObjectCache.get(card.id);
    if (!record) return;
    if (record.lastTier !== card.cardTier || card.id === state.selectedId) {
      drawRollingGlobeCardTexture(record, card);
      record.lastTier = card.cardTier;
    }
    const facing = card.facing ?? 1;
    const horizon = smoothstep(ROLLING_PREFETCH_FACING, ROLLING_VISIBLE_FACING, facing);
    const depthScale = card.graphDepth === 0 ? 1.10 : card.graphDepth === 1 ? .83 : .58;
    const perspectiveScale = .64 + .46 * smoothstep(-.04, .88, facing);
    object.visible = facing > ROLLING_PREFETCH_FACING;
    object.scale.setScalar(depthScale * perspectiveScale);
    record.material.opacity = horizon * (card.graphDepth >= 2 ? .84 : 1);
  }

  function rollingActiveCardById(id) {
    return rollingGlobeActiveCards.find((card) => card.id === id)
      || rollingGlobePrefetchedCards.find((card) => card.id === id);
  }

  function rebuildRollingGlobeFrontier() {
    const known = new Set([
      ...rollingGlobeActiveCards.map((card) => card.id),
      ...rollingGlobePrefetchedCards.map((card) => card.id),
    ]);
    rollingGlobeFrontier = buildRollingFrontier(
      state.rollingGlobeId,
      known,
      knowledgeNodes.filter(matchesFilters),
      knowledgeEdges,
    ).filter((item) => !known.has(item.id));
    return rollingGlobeFrontier;
  }

  function createRollingFrontierCard(candidate, index) {
    const atom = nodeById.get(candidate.id);
    if (!atom) return undefined;
    const parent = rollingActiveCardById(candidate.via);
    const seed = Math.abs(hash(`${state.rollingGlobeId}:${candidate.id}`));
    const parentBearing = parent?.bearing ?? ((seed % 360) - 180);
    const bearing = parentBearing + ((seed % 25) - 12);
    const angularDistance = 94 + (index % 4) * 4;
    const geo = destinationPointOnGlobe(rollingFocusAnchor.lat, rollingFocusAnchor.lng, angularDistance, bearing);
    return {
      ...atom,
      graphDepth: 3,
      parentId: candidate.via,
      branchId: parent?.branchId || candidate.via,
      bearing,
      angularDistance,
      lat: geo.lat,
      lng: geo.lng,
      geo,
      altitude: .009,
      cardTier: 2,
      renderState: 'prefetched',
      readabilityFactor: .10,
    };
  }

  function rebuildRollingGlobeEdges() {
    const cardsById = new Map(rollingGlobeActiveCards.map((card) => [card.id, card]));
    rollingGlobeActiveEdges = knowledgeEdges
      .filter((edge) => {
        const source = cardsById.get(edge.source);
        const target = cardsById.get(edge.target);
        if (!source || !target) return false;
        return source.parentId === target.id || target.parentId === source.id;
      })
      .sort((first, second) => second.weight - first.weight || first.source.localeCompare(second.source))
      .slice(0, 28)
      .map((edge) => ({ ...edge, sourceCard: cardsById.get(edge.source), targetCard: cardsById.get(edge.target) }));
  }

  function reclaimRollingGlobeObjects() {
    const activeIds = new Set(rollingGlobeActiveCards.map((card) => card.id));
    rollingGlobeObjectCache.forEach((record, id) => {
      if (activeIds.has(id)) return;
      rollingGlobeObjectCache.delete(id);
      record.cardId = undefined;
      record.lastTier = undefined;
      record.object.visible = false;
      rollingGlobeFreeCards.push(record);
    });
  }

  // Az Objects/Arc Layer listája kizárólag akkor változik, ha ténylegesen új
  // Atom lép be vagy elhagyja az aktív részgráfot. Forgatási frame-ben nem.
  function commitRollingGlobeData() {
    if (!rollingGlobe) return;
    const membershipKey = rollingGlobeActiveCards.map((card) => card.id).sort().join('|');
    if (membershipKey === rollingGlobeLastMembershipKey) return;
    rollingGlobeLastMembershipKey = membershipKey;
    reclaimRollingGlobeObjects();
    rebuildRollingGlobeEdges();
    rollingGlobe.objectsData(rollingGlobeActiveCards);
    rollingGlobe.arcsData(rollingGlobeActiveEdges);
  }

  function rebuildRollingFocus(focusId, { animated = false, anchor } = {}) {
    const validFocusId = nodeById.has(focusId) ? focusId : 'resp_failure';
    const selected = rollingActiveCardById(validFocusId);
    const nextAnchor = anchor || selected?.geo || { lat: rollingLatestPov.lat || 0, lng: rollingLatestPov.lng || 0 };
    state.rollingGlobeId = validFocusId;
    rollingFocusAnchor = { lat: nextAnchor.lat, lng: nextAnchor.lng };
    const layout = buildGlobeFocusedCardLayout(
      validFocusId,
      rollingFocusAnchor,
      knowledgeNodes.filter(matchesFilters),
      knowledgeEdges,
      { depth1Limit: ROLLING_FOCUS_CONTEXT_COUNT - 1, depth2PerBranch: 2, depth3Limit: ROLLING_PREFETCH_CARD_COUNT },
    );
    rollingGlobeActiveCards = layout.active.slice(0, ROLLING_ACTIVE_CARD_COUNT);
    rollingGlobePrefetchedCards = layout.prefetched.slice(0, ROLLING_PREFETCH_CARD_COUNT);
    rebuildRollingGlobeFrontier();
    rollingGlobeLastMembershipKey = '';
    rollingFocusAnimationUntil = (performance.now?.() || Date.now()) + (animated ? 900 : 0);
    commitRollingGlobeData();
    updateRollingGlobeCardVisuals(rollingLatestPov);
    if (animated && rollingGlobe) {
      rollingGlobe.pointOfView({ lat: rollingFocusAnchor.lat, lng: rollingFocusAnchor.lng, altitude: rollingLatestPov.altitude || 2.1 }, 900);
    }
  }

  function updateRollingGlobeCardVisuals(pov) {
    const cameraNormal = globeSurfaceNormal(pov);
    rollingGlobeActiveCards.forEach((card) => {
      card.facing = globeSurfaceNormal(card).dot(cameraNormal);
      card.renderState = card.facing > ROLLING_VISIBLE_FACING ? 'visible' : 'edge';
      const object = rollingGlobeObjectCache.get(card.id)?.object;
      if (object) updateRollingGlobeCard(object, card);
    });
  }

  function shortestRollingLngDelta(fromLng, toLng) {
    return ((toLng - fromLng + 540) % 360) - 180;
  }

  function streamRollingGlobeFrontier(pov) {
    if ((performance.now?.() || Date.now()) < rollingFocusAnimationUntil) return;
    const previous = rollingGlobeLastStreamPov;
    const yawDelta = shortestRollingLngDelta(previous.lng, pov.lng);
    const pitchDelta = pov.lat - previous.lat;
    if (Math.abs(yawDelta) < ROLLING_STREAM_STEP_DEGREES && Math.abs(pitchDelta) < ROLLING_STREAM_STEP_DEGREES) return;
    const cameraNormal = globeSurfaceNormal(pov);
    const promoted = rollingGlobePrefetchedCards
      .filter((card) => globeSurfaceNormal(card).dot(cameraNormal) > ROLLING_PREFETCH_FACING)
      .slice(0, 3);
    const promotedIds = new Set(promoted.map((card) => card.id));
    const hidden = rollingGlobeActiveCards
      .filter((card) => card.graphDepth > 0 && globeSurfaceNormal(card).dot(cameraNormal) < ROLLING_HIDDEN_FACING)
      .sort((first, second) => second.graphDepth - first.graphDepth || first.id.localeCompare(second.id));
    const leavingIds = new Set(hidden.slice(0, promoted.length).map((card) => card.id));
    if (promoted.length || leavingIds.size) {
      rollingGlobeActiveCards = [
        ...rollingGlobeActiveCards.filter((card) => !leavingIds.has(card.id)),
        ...promoted.map((card) => ({ ...card, renderState: 'active' })),
      ].slice(0, ROLLING_ACTIVE_CARD_COUNT);
      rollingGlobePrefetchedCards = rollingGlobePrefetchedCards.filter((card) => !promotedIds.has(card.id));
      rebuildRollingGlobeFrontier();
      while (rollingGlobePrefetchedCards.length < ROLLING_PREFETCH_CARD_COUNT && rollingGlobeFrontier.length) {
        const candidate = rollingGlobeFrontier.shift();
        const card = createRollingFrontierCard(candidate, rollingGlobePrefetchedCards.length);
        if (card) rollingGlobePrefetchedCards.push(card);
      }
      rollingGlobeLastMembershipKey = '';
      commitRollingGlobeData();
    }
    rollingGlobeLastStreamPov = { lat: pov.lat, lng: pov.lng };
  }

  function scheduleRollingGlobeViewportUpdate() {
    if (rollingGlobeViewportFrame) return;
    rollingGlobeViewportFrame = window.requestAnimationFrame(() => {
      rollingGlobeViewportFrame = undefined;
      updateRollingGlobeCardVisuals(rollingLatestPov);
      streamRollingGlobeFrontier(rollingLatestPov);
    });
  }

  function focusRollingGlobeCard(id) {
    const card = rollingActiveCardById(id);
    if (!card || rollingFocusInteractionLocked) return;
    rollingFocusInteractionLocked = true;
    if (state.history[state.history.length - 1] !== id) state.history.push(id);
    state.history = state.history.slice(-12);
    state.centerId = id;
    state.selectedId = id;
    state.rollingGlobeId = id;
    state.pathMode = false;
    state.sheetOpen = false;
    state.searchText = '';
    search.value = '';
    renderSearchResults();
    renderBreadcrumb();
    renderLayer();
    persist();
    rollingGlobeActiveCards.forEach((item) => {
      const record = rollingGlobeObjectCache.get(item.id);
      if (record) record.material.opacity *= item.id === id ? 1 : .28;
    });
    rollingGlobe?.pointOfView({ lat: card.lat, lng: card.lng, altitude: rollingLatestPov.altitude || 2.1 }, 900);
    window.setTimeout(() => {
      rebuildRollingFocus(id, { anchor: card.geo });
      renderRollingCardGlobe();
      rollingFocusInteractionLocked = false;
    }, 540);
  }

  function renderRollingCardGlobe() {
    const focusId = nodeById.has(state.rollingGlobeId) ? state.rollingGlobeId : state.centerId;
    if (!rollingGlobeActiveCards.length || rollingGlobeActiveCards[0]?.id !== focusId) rebuildRollingFocus(focusId);
    empty.hidden = rollingGlobeActiveCards.length > 0;
    mapContainer.hidden = true;
    if (rollingGlobeContainer) rollingGlobeContainer.hidden = !empty.hidden;
    visibleNodeIds = rollingGlobeActiveCards.filter((card) => (card.facing ?? 1) > ROLLING_PREFETCH_FACING).map((card) => card.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    updateRollingGlobeCardVisuals(rollingLatestPov);
  }

  function createRollingCardGlobe(attempt = 0) {
    ensureRollingGlobeContainer();
    const Globe = window.Globe;
    if (!Globe || !rollingGlobeContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createRollingCardGlobe(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      rollingGlobeContainer?.setAttribute('hidden', '');
      showToast('A fókuszált Globe-kártyanézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (cardGlobeContainer) cardGlobeContainer.hidden = true;
    if (focusedGlobeContainer) focusedGlobeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    rollingGlobeContainer.hidden = false;
    const texture = `data:image/svg+xml;charset=utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512"><defs><radialGradient id="g" cx="32%" cy="28%"><stop offset="0" stop-color="#b88bff"/><stop offset=".45" stop-color="#6f3eb2"/><stop offset="1" stop-color="#2a1457"/></radialGradient></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>')}`;
    rollingGlobe = new Globe(rollingGlobeContainer, { rendererConfig: { antialias: true, alpha: true }, waitForGlobeReady: false, animateIn: true })
      .width(Math.max(rollingGlobeContainer.clientWidth, 320))
      .height(Math.max(rollingGlobeContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)').globeImageUrl(texture)
      .showAtmosphere(true).atmosphereColor('#bb8aff').atmosphereAltitude(.17).showGraticules(false)
      .objectsData(rollingGlobeActiveCards)
      .objectLat((card) => card.lat)
      .objectLng((card) => card.lng)
      .objectAltitude((card) => card.altitude)
      .objectFacesSurface(true)
      .objectThreeObject(createRollingGlobeCard)
      .onObjectClick((card) => focusRollingGlobeCard(card.id))
      .arcsData(rollingGlobeActiveEdges)
      .arcStartLat((edge) => edge.sourceCard.lat)
      .arcStartLng((edge) => edge.sourceCard.lng)
      .arcEndLat((edge) => edge.targetCard.lat)
      .arcEndLng((edge) => edge.targetCard.lng)
      .arcStartAltitude(.014)
      .arcEndAltitude(.014)
      .arcAltitude(.015)
      .arcStroke(.08)
      .arcColor(() => '#f7f2ff')
      .arcsTransitionDuration(350)
      .onZoom((pov) => {
        rollingLatestPov = pov;
        scheduleRollingGlobeViewportUpdate();
      });
    rollingGlobeControls = rollingGlobe.controls?.();
    if (rollingGlobeControls) {
      rollingGlobeControls.enableRotate = true;
      rollingGlobeControls.enablePan = false;
      rollingGlobeControls.screenSpacePanning = false;
      rollingGlobeControls.enableDamping = true;
      rollingGlobeControls.dampingFactor = .08;
      rollingGlobeControls.rotateSpeed = .45;
      rollingGlobeControls.zoomSpeed = .65;
      rollingGlobeControls.target?.set?.(0, 0, 0);
    }
    rollingLatestPov = { lat: 0, lng: 0, altitude: 2.1 };
    rollingGlobeLastStreamPov = { lat: 0, lng: 0 };
    rollingGlobe.pointOfView(rollingLatestPov, 0);
    rollingGlobeResizeObserver = new ResizeObserver(() => {
      rollingGlobe?.width(Math.max(rollingGlobeContainer.clientWidth, 320)).height(Math.max(rollingGlobeContainer.clientHeight, 420));
      scheduleRollingGlobeViewportUpdate();
    });
    rollingGlobeResizeObserver.observe(rollingGlobeContainer);
    rebuildRollingFocus(state.rollingGlobeId);
    renderRollingCardGlobe();
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
  // A távoli node-ok egyszerű proxy-gömbök; a részletes bolygó ugyanebben a
  // scene/kamera/renderer univerzumban egyetlen újrahasznosított ThreeGlobe.
  const forceUniverseSphereGeometry = new THREE.SphereGeometry(1, 20, 14);
  const forceUniverseMaterialCache = new Map();
  const forceUniverseColors = { topic: '#6B3EF6', condition: '#8A63E8', measurement: '#B9B0E6', concept: '#7C4DFF', treatment: '#9B7BFF', procedure: '#8276BA', symptom: '#C58BDF', source: '#6D75C8' };

  function forceUniverseDegree(nodeId) {
    const ids = new Set();
    knowledgeEdges.forEach((edge) => {
      if (edge.source === nodeId) ids.add(edge.target);
      if (edge.target === nodeId) ids.add(edge.source);
    });
    return ids.size;
  }

  function forceUniverseRadius(nodeId) {
    const degrees = knowledgeNodes.map((node) => forceUniverseDegree(node.id));
    const min = Math.min(...degrees);
    const max = Math.max(...degrees);
    const degree = forceUniverseDegree(nodeId);
    const normalized = max <= min ? 0 : Math.sqrt(clamp((degree - min) / (max - min), 0, 1));
    return 2.2 + normalized * 5.2;
  }

  function forceUniverseMaterial(node) {
    const key = node.type || 'concept';
    if (!forceUniverseMaterialCache.has(key)) {
      forceUniverseMaterialCache.set(key, new THREE.MeshStandardMaterial({
        color: forceUniverseColors[key] || forceUniverseColors.concept,
        roughness: .65,
        metalness: .05,
        transparent: true,
        depthTest: true,
        depthWrite: true,
      }));
    }
    return forceUniverseMaterialCache.get(key).clone();
  }

  function createForceUniversePlanetNode(node) {
    const root = new THREE.Group();
    const radius = forceUniverseRadius(node.id);
    const proxySphere = new THREE.Mesh(forceUniverseSphereGeometry, forceUniverseMaterial(node));
    proxySphere.scale.setScalar(radius);
    proxySphere.castShadow = true;
    proxySphere.receiveShadow = true;
    const glow = new THREE.Mesh(forceUniverseSphereGeometry, new THREE.MeshBasicMaterial({ color: '#8f6bff', transparent: true, opacity: .12, depthWrite: false, side: THREE.BackSide }));
    glow.scale.setScalar(radius * 1.22);
    const selectionRing = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.16, Math.max(.18, radius * .045), 8, 36), new THREE.MeshBasicMaterial({ color: '#ECE7FF', transparent: true, opacity: .9, depthWrite: false }));
    selectionRing.rotation.x = Math.PI / 2;
    selectionRing.visible = false;
    root.add(proxySphere, glow, selectionRing);
    root.userData = { nodeId: node.id, baseRadius: radius, proxySphere, glow, selectionRing };
    forceUniversePlanetViews.set(node.id, { root, proxySphere, glow, selectionRing, baseRadius: radius });
    return root;
  }

  function updateForceUniverseVisuals() {
    const activeId = forceUniverseDetailPlanetId;
    const related = activeId ? new Set([activeId]) : null;
    if (activeId) knowledgeEdges.forEach((edge) => {
      if (edge.source === activeId) related.add(edge.target);
      if (edge.target === activeId) related.add(edge.source);
    });
    forceUniversePlanetViews.forEach((view, nodeId) => {
      const focused = nodeId === activeId;
      const opacity = !activeId ? 1 : (focused ? 1 : (related.has(nodeId) ? .72 : .16));
      if (view.proxySphere.material) {
        view.proxySphere.material.transparent = true;
        view.proxySphere.material.opacity = opacity;
      }
      if (view.glow?.material) view.glow.material.opacity = focused ? .32 : .08;
      if (view.selectionRing) view.selectionRing.visible = focused;
      if (view.glow) view.proxySphere.scale.setScalar(view.baseRadius * (focused ? 1.08 : 1));
    });
  }

  function configureForceUniverseDetailGlobe(node) {
    const ThreeGlobe = window.ThreeGlobe;
    if (!ThreeGlobe || forceUniverseDetailGlobe) return forceUniverseDetailGlobe;
    forceUniverseDetailGlobe = new ThreeGlobe({ animateIn: false, waitForGlobeReady: false })
      .showGlobe(true)
      .showAtmosphere(true)
      .atmosphereColor('#8f6bff')
      .atmosphereAltitude(.12)
      .globeImageUrl(null)
      .pointsData([])
      .arcsData([])
      .labelsData([]);
    const globeMaterial = new THREE.MeshStandardMaterial({ color: '#6337D5', roughness: .72, metalness: .04, emissive: '#25104e', emissiveIntensity: .18 });
    forceUniverseDetailGlobe.globeMaterial(globeMaterial);
    return forceUniverseDetailGlobe;
  }

  function attachForceUniverseDetail(node) {
    const view = forceUniversePlanetViews.get(node.id);
    const detailGlobe = configureForceUniverseDetailGlobe(node);
    if (!view || !detailGlobe) return false;
    detailGlobe.removeFromParent?.();
    view.root.add(detailGlobe);
    detailGlobe.position.set(0, 0, 0);
    const globeRadius = detailGlobe.getGlobeRadius?.() || 100;
    detailGlobe.scale.setScalar(view.baseRadius / globeRadius);
    // A részletes bolygó ugyanazt a fókuszált Globe-kártya adatmodellt kapja,
    // mint az utolsó screenshot: a force-galaxisban ezek az objektumok még nem
    // léteznek, csak a tap utáni inline morph során kerülnek a bolygóra.
    const focusId = nodeById.has(node.id) ? node.id : state.centerId;
    const subgraph = buildFocusedG6Subgraph(focusId, knowledgeNodes, knowledgeEdges, {
      firstRingLimit: 7,
      secondRingPerNode: 1,
      maxNodes: 14,
    });
    const points = focusedGlobePointData(subgraph.nodes, focusId);
    const pointById = new Map(points.map((point) => [point.id, point]));
    const arcs = subgraph.edges
      .map((edge) => ({ source: pointById.get(edge.source), target: pointById.get(edge.target) }))
      .filter((edge) => edge.source && edge.target);
    const createDetailPlanetObject = (point) => {
      if (point.renderCard) return createFocusedKnowledgeCard(point);
      const sphere = new THREE.Mesh(
        forceUniverseSphereGeometry,
        new THREE.MeshStandardMaterial({ color: '#9b7bff', roughness: .62, metalness: .04 })
      );
      sphere.scale.setScalar(2.8 + (point.importance || .5) * 1.4);
      return sphere;
    };
    detailGlobe
      .objectsData(points)
      .objectLat('lat')
      .objectLng('lng')
      .objectAltitude('altitude')
      .objectFacesSurface(true)
      .objectThreeObject(createDetailPlanetObject)
      .arcsData(arcs)
      .arcStartLat((edge) => edge.source.lat)
      .arcStartLng((edge) => edge.source.lng)
      .arcEndLat((edge) => edge.target.lat)
      .arcEndLng((edge) => edge.target.lng)
      .arcColor(() => '#ffffff')
      .arcStroke(.08)
      .arcDashLength(1)
      .arcDashGap(0)
      .arcDashAnimateTime(0)
      .arcsTransitionDuration(0)
      .onObjectClick?.((point) => {
        state.selectedId = point.id;
        points.forEach((item) => { item.isFocused = item.id === point.id; item.renderCard = item.id === point.id; });
        detailGlobe.objectsData(points);
      });
    detailGlobe.visible = true;
    return true;
  }

  function setForceUniverseTransition(progress) {
    const eased = progress < .5 ? 4 * progress * progress * progress : 1 - Math.pow(-2 * progress + 2, 3) / 2;
    const active = forceUniversePlanetViews.get(forceUniverseDetailPlanetId);
    if (active) {
      if (active.proxySphere.material) {
        active.proxySphere.material.transparent = true;
        active.proxySphere.material.opacity = 1 - eased;
      }
      if (active.glow?.material) active.glow.material.opacity = .12 + eased * .22;
      if (active.selectionRing) {
        active.selectionRing.visible = true;
        active.selectionRing.material.opacity = .4 + eased * .5;
      }
      if (forceUniverseDetailGlobe) {
        forceUniverseDetailGlobe.visible = true;
        forceUniverseDetailGlobe.children.forEach((child) => { if (child.material) child.material.transparent = true; });
        forceUniverseDetailGlobe.scale.setScalar((active.baseRadius / (forceUniverseDetailGlobe.getGlobeRadius?.() || 100)) * (.92 + eased * .08));
      }
    }
    forceUniversePlanetViews.forEach((view, id) => {
      if (id !== forceUniverseDetailPlanetId) {
        if (view.proxySphere.material) {
          view.proxySphere.material.transparent = true;
          view.proxySphere.material.opacity = .16 - eased * .06;
        }
        if (view.glow?.material) view.glow.material.opacity = .05;
      }
    });
    forceGraph3D?.linkOpacity?.(.28 - eased * .24);
  }

  function requestForceUniverseEntry(nodeId) {
    if (forceUniverseLodState !== 'GALAXY' || !forceGraph3D) return;
    const node = forceGraph3DData()?.nodes?.find((item) => item.id === nodeId);
    const view = forceUniversePlanetViews.get(nodeId);
    if (!node || !view) return;
    if (!window.ThreeGlobe) {
      // A tap már fókuszált, de a nagy vendor még tölthet. Az inline átmenetet
      // ugyanerről a node-ról indítjuk el, amint a ThreeGlobe elérhető lesz.
      window.setTimeout(() => requestForceUniverseEntry(nodeId), 120);
      return;
    }
    if (!attachForceUniverseDetail(node)) return;
    forceUniverseDetailPlanetId = nodeId;
    forceUniverseLodState = 'ENTERING_PLANET';
    updateForceUniverseVisuals();
    const start = performance.now();
    const tick = (now) => {
      const progress = clamp((now - start) / 440, 0, 1);
      setForceUniverseTransition(progress);
      if (progress < 1) forceUniverseTransitionFrame = requestAnimationFrame(tick);
      else forceUniverseLodState = 'PLANET';
    };
    forceUniverseTransitionFrame = requestAnimationFrame(tick);
  }

  function exitForceUniversePlanet() {
    if (forceUniverseLodState !== 'PLANET' || !forceUniverseDetailPlanetId) return;
    forceUniverseLodState = 'EXITING_PLANET';
    const start = performance.now();
    const tick = (now) => {
      const progress = clamp((now - start) / 380, 0, 1);
      setForceUniverseTransition(1 - progress);
      if (progress < 1) forceUniverseTransitionFrame = requestAnimationFrame(tick);
      else {
        forceUniverseDetailGlobe?.removeFromParent?.();
        if (forceUniverseDetailGlobe) forceUniverseDetailGlobe.visible = false;
        forceUniverseDetailPlanetId = null;
        forceUniverseLodState = 'GALAXY';
        updateForceUniverseVisuals();
        forceGraph3D?.linkOpacity?.(.45);
      }
    };
    forceUniverseTransitionFrame = requestAnimationFrame(tick);
  }

  function scheduleForceUniverseLod() {
    if (forceUniverseLodFrame) return;
    forceUniverseLodFrame = requestAnimationFrame(() => {
      forceUniverseLodFrame = undefined;
      updateForceUniverseLod();
    });
  }

  function updateForceUniverseLod() {
    if (!forceGraph3D || forceUniverseLodState === 'ENTERING_PLANET' || forceUniverseLodState === 'EXITING_PLANET') return;
    const camera = forceGraph3D.camera();
    if (forceUniverseDetailGlobe) {
      const rendererSize = new THREE.Vector2();
      forceGraph3D.renderer()?.getSize?.(rendererSize);
      forceUniverseDetailGlobe.rendererSize?.(rendererSize);
      forceUniverseDetailGlobe.setPointOfView?.(camera);
    }
    forceGraph3D.graphData().nodes.forEach((node) => ensureForceUniverseView(node));
    let candidate = null;
    forceUniversePlanetViews.forEach((view, id) => {
      const node = forceGraph3D.graphData().nodes.find((item) => item.id === id);
      if (!node || !Number.isFinite(node.x)) return;
      const world = new THREE.Vector3(node.x, node.y, node.z);
      const distance = camera.position.distanceTo(world);
      const projected = world.clone().project(camera);
      const centerDistance = Math.hypot(projected.x, projected.y);
      if (projected.z < -1 || projected.z > 1) return;
      const score = distance / Math.max(view.baseRadius, .001) * (1 + centerDistance * 2.5);
      if (!candidate || score < candidate.score) candidate = { id, node, distanceInRadii: distance / view.baseRadius, centerDistance, score };
    });
    // A gyári force node-ok csak a grafikon adatfrissítése után kapnak Three
    // objektumot. A zoom-küszöb vizsgálata ezért minden aktív galaxisponton
    // megpróbálja regisztrálni a proxy gömböt, nem csak a korábban tappelten.
    if (!candidate) {
      forceUniversePlanetViews.forEach((view, id) => {
        const node = forceGraph3D.graphData().nodes.find((item) => item.id === id);
        if (!node || !Number.isFinite(node.x)) return;
        const world = new THREE.Vector3(node.x, node.y, node.z);
        const distance = camera.position.distanceTo(world);
        const projected = world.clone().project(camera);
        const centerDistance = Math.hypot(projected.x, projected.y);
        if (projected.z < -1 || projected.z > 1) return;
        const score = distance / Math.max(view.baseRadius, .001) * (1 + centerDistance * 2.5);
        if (!candidate || score < candidate.score) candidate = { id, node, distanceInRadii: distance / view.baseRadius, centerDistance, score };
      });
    }
    if (forceUniverseLodState === 'PLANET') {
      if (!candidate || candidate.id !== forceUniverseDetailPlanetId || candidate.distanceInRadii > 10 || candidate.centerDistance > .58) exitForceUniversePlanet();
      return;
    }
    if (!candidate || candidate.distanceInRadii >= 7 || candidate.centerDistance >= .32) {
      forceUniverseCandidateSince = 0;
      return;
    }
    if (!forceUniverseCandidateSince) forceUniverseCandidateSince = performance.now();
    if (performance.now() - forceUniverseCandidateSince >= 120) requestForceUniverseEntry(candidate.id);
  }

  function ensureForceUniverseView(node) {
    if (!node) return null;
    const existing = forceUniversePlanetViews.get(node.id);
    if (existing) return existing;
    const root = node.__threeObj || node.__threeObject || node.__obj;
    if (!root) {
      // A gyári node objektuma kattintás pillanatában egyes build-ekben még
      // nem érhető el. Ilyenkor is legyen biztos tap-cél: ugyanabba a force
      // scene-be teszünk egy ideiglenes proxy groupot a node világpozíciójára.
      const fallback = createForceUniversePlanetNode(node);
      fallback.position.set(Number(node.x) || 0, Number(node.y) || 0, Number(node.z) || 0);
      forceGraph3D.scene?.().add(fallback);
      return forceUniversePlanetViews.get(node.id);
    }
    let mesh;
    root.traverse?.((object) => {
      if (!mesh && object.isMesh) mesh = object;
    });
    if (!mesh) return null;
    const degree = forceUniverseDegree(node.id);
    // A gyári force-node vizuális sugara nem az adat `val` mezője, ezért a
    // morph LOD-hoz egy stabil, képernyőn is értelmezhető proxy-sugarat használunk.
    // Így a fókusz-zoom után nem lép ki azonnal PLANET állapotból.
    const baseRadius = Math.max(4.8, Math.cbrt(Number(node.val) || 1) * 2.2);
    const view = {
      root,
      proxySphere: mesh,
      glow: null,
      selectionRing: null,
      baseRadius,
      degree,
    };
    forceUniversePlanetViews.set(node.id, view);
    return view;
  }

  function handleForceUniverseNodeClick(node) {
    if (!node || forceUniverseLodState !== 'GALAXY' || !forceGraph3D) return;
    const view = ensureForceUniverseView(node);
    if (!view) return;
    // A tap explicit fókuszgesztus: ne kelljen megvárni, hogy a kamera a
    // kézi zoom-dwell küszöböt is átlépje. A kamera animációja és a morph
    // ugyanarról a force-node pozícióról indul, ezért nincs nézetváltási vágás.
    requestForceUniverseEntry(node.id);
    node.fx = node.x; node.fy = node.y; node.fz = node.z;
    const camera = forceGraph3D.camera();
    const controls = forceGraph3D.controls();
    const direction = camera.position.clone().sub(controls.target).normalize();
    const distance = Math.max(view.baseRadius * 5.2, 26);
    forceGraph3D.cameraPosition(
      new THREE.Vector3(node.x, node.y, node.z).add(direction.multiplyScalar(distance)),
      new THREE.Vector3(node.x, node.y, node.z),
      720
    );
    forceUniverseCandidateSince = performance.now();
    controls.enabled = true;
    scheduleForceUniverseLod();
  }

  let forceUniverseDemoCache;
  function forceUniverseDemoData() {
    if (!forceUniverseDemoCache) {
      const nodes = Array.from({ length: 42 }, (_, index) => ({
        id: `demo-planet-${index + 1}`,
        name: `Planet ${index + 1}`,
      }));
      const links = [];
      for (let index = 1; index < nodes.length; index += 1) {
        links.push({ source: nodes[index - 1].id, target: nodes[index].id });
        if (index > 3 && index % 3 === 0) links.push({ source: nodes[index - 4].id, target: nodes[index].id });
      }
      forceUniverseDemoCache = { nodes, links };
    }
    empty.hidden = true;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = false;
    visibleNodeIds = forceUniverseDemoCache.nodes.map((node) => node.id);
    renderBreadcrumb();
    return forceUniverseDemoCache;
  }

  function forceGraph3DData() {
    if (isForceUniverseDemoView()) return forceUniverseDemoData();
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
      // A távoli nézet szándékosan a 3d-force-graph gyári galaxis-layoutja és
      // gyári gömbnode-ja. Nem vetítjük a teljes gráfot gömbhéjra.
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
      .linkOpacity(.45)
      .onNodeClick(handleForceUniverseNodeClick)
      .onNodeHover((node) => { force3dContainer.style.cursor = node ? 'pointer' : 'grab'; });
    // A dokumentált nodeThreeObject útvonalon kapjuk meg biztosan a saját
    // ThreeJS Object3D-t és így a tapelt gömb anchorját is. Ez csak az
    // adatmentes demo módban aktív; a normál 3D Force Graph gyári node-ja
    // változatlan marad.
    if (isForceUniverseDemoView()) {
      forceGraph3D
        .nodeThreeObject(createForceUniversePlanetNode)
        .nodeThreeObjectExtend(false)
        .nodeRelSize(4)
        .nodeResolution(18);
    }
    forceUniverseControls = forceGraph3D.controls?.();
    forceUniverseControlsHandler = scheduleForceUniverseLod;
    forceUniverseControls?.addEventListener?.('change', forceUniverseControlsHandler);
    force3dResizeObserver = new ResizeObserver(() => {
      forceGraph3D?.width(Math.max(force3dContainer.clientWidth, 320)).height(Math.max(force3dContainer.clientHeight, 420));
    });
    force3dResizeObserver.observe(force3dContainer);
    renderForceGraph3D();
  }

  // A Zoom morph a sima 3D Force Graph külön, kicsi demonstrációs testvére.
  // Ugyanazokat az Atomokat használja, de az overview csak kis gömböket és
  // vékony éleket rajzol. Tap után a kiválasztott Atom lokális környezete
  // kontrolláltan, azonos Three.js anchorokon alakul át kártyákká.
  function forceGraphMorphOverviewPosition(index, total, id) {
    const progress = (index + .5) / Math.max(total, 1);
    const phi = Math.acos(1 - 2 * progress);
    const theta = (Math.PI * (3 - Math.sqrt(5)) * index) + (Math.abs(hash(id)) % 19) * .025;
    const radius = 102 + (Math.abs(hash(`${id}:radius`)) % 17);
    return new THREE.Vector3(
      Math.cos(theta) * Math.sin(phi) * radius,
      Math.cos(phi) * radius,
      Math.sin(theta) * Math.sin(phi) * radius,
    );
  }

  function forceGraphMorphData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }

    const seed = nodeById.has(state.centerId) ? state.centerId : matched[0]?.id;
    const preview = buildFocusedG6Subgraph(seed, matched, knowledgeEdges, {
      firstRingLimit: 9,
      secondRingPerNode: 3,
      maxNodes: FORCE_GRAPH_MORPH_NODE_LIMIT,
    });
    const signature = preview.nodes.map((node) => node.id).join('|');
    const currentSignature = forceGraphMorphNodes.map((node) => node.id).join('|');
    if (signature !== currentSignature) {
      forceGraphMorphNodes = preview.nodes.map((atom, index) => {
        const overviewPosition = forceGraphMorphOverviewPosition(index, preview.nodes.length, atom.id);
        return {
          ...atom,
          atomId: atom.id,
          name: atom.title,
          val: 1,
          overviewPosition,
          renderPosition: overviewPosition.clone(),
          morphStartPosition: overviewPosition.clone(),
          morphTargetPosition: overviewPosition.clone(),
          x: overviewPosition.x,
          y: overviewPosition.y,
          z: overviewPosition.z,
          fx: overviewPosition.x,
          fy: overviewPosition.y,
          fz: overviewPosition.z,
        };
      });
      forceGraphMorphLinks = preview.edges.map((edge, index) => ({
        ...edge,
        id: `force-zoom-morph:${edge.source}:${edge.target}:${index}`,
      }));
      forceGraphMorphNodeById = new Map(forceGraphMorphNodes.map((node) => [node.id, node]));
      forceGraphMorphFocusIds = [];
      forceGraphMorphTargetPositions = undefined;
      forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.OVERVIEW;
    }
    visibleNodeIds = forceGraphMorphNodes.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    return { nodes: forceGraphMorphNodes, links: forceGraphMorphLinks };
  }

  function forceGraphMorphSphereMeshGeometry() {
    if (!forceGraphMorphSphereGeometry) forceGraphMorphSphereGeometry = new THREE.SphereGeometry(3.7, 18, 14);
    return forceGraphMorphSphereGeometry;
  }

  function forceGraphMorphCardMeshGeometry() {
    if (forceGraphMorphCardGeometry) return forceGraphMorphCardGeometry;
    forceGraphMorphCardGeometry = new THREE.PlaneGeometry(30, 15, 14, 7);
    // Finom üveglap-hajlítás: a kártya nem csak egy 2D overlay, de ennél a
    // tesztnézetnél a kamera felé olvasható marad.
    bendCardToSphereGeometry(forceGraphMorphCardGeometry, 176, 248);
    return forceGraphMorphCardGeometry;
  }

  function drawForceGraphMorphCard(group, atomId) {
    const atom = forceGraphMorphNodeById.get(atomId) || nodeById.get(atomId);
    const { context, canvas, texture } = group?.userData || {};
    if (!atom || !context || !canvas || !texture) return;
    const isFocus = atomId === forceGraphMorphFocusIds[0];
    const degree = relationCount(atomId);
    const palette = isFocus
      ? { top: '#ba91ff', bottom: '#5732ae', border: '#fff2b0', meta: 'rgba(255,255,255,.80)' }
      : degree > 6
        ? { top: '#fffdfd', bottom: '#e8dbff', border: '#f7efff', meta: '#7054a8' }
        : { top: '#c7aaff', bottom: '#7852c9', border: 'rgba(255,255,255,.84)', meta: 'rgba(255,255,255,.78)' };
    context.clearRect(0, 0, canvas.width, canvas.height);
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, palette.top); gradient.addColorStop(1, palette.bottom);
    context.fillStyle = gradient;
    context.beginPath();
    if (context.roundRect) context.roundRect(6, 6, 500, 244, 30);
    else {
      context.moveTo(36, 6); context.arcTo(506, 6, 506, 250, 30); context.arcTo(506, 250, 6, 250, 30);
      context.arcTo(6, 250, 6, 6, 30); context.arcTo(6, 6, 506, 6, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = isFocus ? 6 : 4;
    context.strokeStyle = palette.border;
    context.stroke();
    context.fillStyle = palette.meta;
    context.font = '700 26px system-ui, sans-serif';
    context.fillText(TYPE_META[atom.type]?.label?.toUpperCase() || 'ATOM', 34, 55);
    context.fillStyle = isFocus || degree <= 6 ? '#fff' : '#3d2865';
    context.font = '800 48px system-ui, sans-serif';
    context.fillText(atom.title.length > 22 ? `${atom.title.slice(0, 21)}…` : atom.title, 34, 120);
    context.fillStyle = isFocus || degree <= 6 ? 'rgba(251,246,255,.86)' : '#6a548a';
    context.font = '400 28px system-ui, sans-serif';
    context.fillText(atom.subtitle.length > 31 ? `${atom.subtitle.slice(0, 30)}…` : atom.subtitle, 34, 172);
    texture.needsUpdate = true;
  }

  function createForceGraphMorphAtom(node) {
    const cached = forceGraphMorphObjects.get(node.id);
    if (cached) return cached;
    const group = new THREE.Group();
    group.name = `djinn-force-zoom-morph-${node.id}`;
    const sphereMaterial = new THREE.MeshPhongMaterial({
      color: node.type === 'topic' ? '#d1a6ff' : '#9c72e8',
      emissive: '#2c1554',
      shininess: 82,
      transparent: true,
      opacity: 1,
    });
    const sphere = new THREE.Mesh(forceGraphMorphSphereMeshGeometry(), sphereMaterial);
    const canvas = document.createElement('canvas');
    canvas.width = 512; canvas.height = 256;
    const context = canvas.getContext('2d');
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    const cardMaterial = new THREE.MeshBasicMaterial({
      map: texture, transparent: true, depthTest: true, depthWrite: false, side: THREE.DoubleSide, opacity: 0,
    });
    const card = new THREE.Mesh(forceGraphMorphCardMeshGeometry(), cardMaterial);
    card.position.z = .8;
    card.scale.setScalar(.12);
    card.visible = false;
    group.add(sphere, card);
    group.userData = { atomId: node.id, sphere, sphereMaterial, card, cardMaterial, canvas, context, texture };
    drawForceGraphMorphCard(group, node.id);
    forceGraphMorphObjects.set(node.id, group);
    return group;
  }

  function updateForceGraphMorphAtomPosition(object, coordinates, node) {
    const position = node.renderPosition || new THREE.Vector3(coordinates.x || 0, coordinates.y || 0, coordinates.z || 0);
    object.position.copy(position);
    return true;
  }

  function forceGraphMorphEndpointId(endpoint) { return typeof endpoint === 'object' ? endpoint?.id : endpoint; }

  function forceGraphMorphLinkId(link) { return link?.id || `force-zoom-morph:${forceGraphMorphEndpointId(link?.source)}:${forceGraphMorphEndpointId(link?.target)}`; }

  function createForceGraphMorphLink(link) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(13 * 3), 3));
    const material = new THREE.LineBasicMaterial({ color: '#d9c2ff', transparent: true, opacity: .26 });
    const line = new THREE.Line(geometry, material);
    line.userData.linkId = forceGraphMorphLinkId(link);
    line.frustumCulled = false;
    forceGraphMorphLinkObjects.set(line.userData.linkId, line);
    return line;
  }

  function updateForceGraphMorphLink(line, coordinates, link) {
    const source = forceGraphMorphNodeById.get(forceGraphMorphEndpointId(link.source));
    const target = forceGraphMorphNodeById.get(forceGraphMorphEndpointId(link.target));
    if (!source || !target || !line?.geometry?.attributes?.position) return true;
    const start = source.renderPosition;
    const end = target.renderPosition;
    const relevant = forceGraphMorphFocusIds.includes(source.id) && forceGraphMorphFocusIds.includes(target.id);
    const curve = relevant ? forceGraphMorphCardProgress() : 0;
    const mid = start.clone().add(end).multiplyScalar(.5);
    const liftDirection = mid.lengthSq() > .001 ? mid.normalize() : new THREE.Vector3(0, 0, 1);
    const control = start.clone().lerp(end, .5).addScaledVector(liftDirection, (7 + start.distanceTo(end) * .14) * curve);
    const positions = line.geometry.attributes.position;
    for (let index = 0; index < 13; index += 1) {
      const t = index / 12;
      const point = start.clone().multiplyScalar((1 - t) * (1 - t))
        .addScaledVector(control, 2 * (1 - t) * t)
        .addScaledVector(end, t * t);
      positions.setXYZ(index, point.x, point.y, point.z);
    }
    positions.needsUpdate = true;
    line.geometry.computeBoundingSphere();
    line.material.color.set(relevant ? '#f4ebff' : '#bba0e8');
    line.material.opacity = relevant ? .18 + curve * .66 : .16 * (1 - curve);
    line.visible = line.material.opacity > .02;
    return true;
  }

  function forceGraphMorphCardProgress() {
    if (forceGraphMorphState === FORCE_GRAPH_MORPH_STATES.FOCUSED) return 1;
    if (forceGraphMorphState === FORCE_GRAPH_MORPH_STATES.OVERVIEW) return 0;
    const elapsed = Math.max(0, (performance.now?.() || Date.now()) - forceGraphMorphTransitionStartedAt);
    const raw = clamp(elapsed / FORCE_GRAPH_MORPH_DURATION, 0, 1);
    const eased = raw < .5 ? 4 * raw * raw * raw : 1 - Math.pow(-2 * raw + 2, 3) / 2;
    return forceGraphMorphTransitionDirection > 0 ? eased : 1 - eased;
  }

  function forceGraphMorphTargetLayout(focusId) {
    const context = buildLayeredSphericalFocusLayout(
      focusId,
      forceGraphMorphNodes,
      forceGraphMorphLinks,
      { depth1Limit: FORCE_GRAPH_MORPH_FIRST_RING_LIMIT, depth2PerBranch: FORCE_GRAPH_MORPH_SECOND_RING_PER_NODE, depth3Limit: 0 },
    );
    const focus = forceGraphMorphNodeById.get(context[0]?.id || focusId);
    const base = focus?.overviewPosition?.clone() || new THREE.Vector3();
    const targets = new Map(forceGraphMorphNodes.map((node) => [node.id, node.overviewPosition.clone()]));
    context.forEach((item) => {
      const yaw = THREE.MathUtils.degToRad(item.yaw || 0);
      const pitch = THREE.MathUtils.degToRad(item.pitch || 0);
      const radius = item.depth === 0 ? 0 : item.depth === 1 ? 58 : 100;
      const position = base.clone().add(new THREE.Vector3(
        Math.sin(yaw) * Math.cos(pitch) * radius,
        Math.sin(pitch) * radius,
        (Math.cos(yaw) * Math.cos(pitch) - 1) * radius,
      ));
      targets.set(item.id, position);
    });
    return { context, base, targets };
  }

  function applyForceGraphMorphTransition(positionProgress, visualCardProgress = positionProgress) {
    const movementProgress = clamp(positionProgress, 0, 1);
    const cardProgress = clamp(visualCardProgress, 0, 1);
    const focusSet = new Set(forceGraphMorphFocusIds);
    forceGraphMorphNodes.forEach((node) => {
      const object = forceGraphMorphObjects.get(node.id);
      if (!object) return;
      const start = node.morphStartPosition || node.renderPosition || node.overviewPosition;
      const target = node.morphTargetPosition || node.overviewPosition;
      const position = start.clone().lerp(target, movementProgress);
      node.renderPosition.copy(position);
      node.x = node.fx = position.x; node.y = node.fy = position.y; node.z = node.fz = position.z;
      object.position.copy(position);
      const local = focusSet.has(node.id);
      const sphereOpacity = local ? 1 - cardProgress : .84 - cardProgress * .62;
      object.userData.sphere.visible = sphereOpacity > .015;
      object.userData.sphereMaterial.opacity = sphereOpacity;
      object.userData.sphere.scale.setScalar(local ? 1 + cardProgress * .34 : 1 - cardProgress * .16);
      object.userData.card.visible = local && cardProgress > .01;
      object.userData.cardMaterial.opacity = local ? cardProgress : 0;
      const cardScale = node.id === forceGraphMorphFocusIds[0] ? 1.08 : .84;
      object.userData.card.scale.setScalar((.12 + cardProgress * .88) * cardScale);
    });
    forceGraphMorphLinks.forEach((link) => {
      const line = forceGraphMorphLinkObjects.get(forceGraphMorphLinkId(link));
      if (line) updateForceGraphMorphLink(line, {}, link);
    });
  }

  function runForceGraphMorphTransition(timestamp) {
    const raw = clamp((timestamp - forceGraphMorphTransitionStartedAt) / FORCE_GRAPH_MORPH_DURATION, 0, 1);
    const eased = raw < .5 ? 4 * raw * raw * raw : 1 - Math.pow(-2 * raw + 2, 3) / 2;
    applyForceGraphMorphTransition(eased, forceGraphMorphTransitionDirection > 0 ? eased : 1 - eased);
    if (raw < 1) {
      forceGraphMorphFrame = window.requestAnimationFrame(runForceGraphMorphTransition);
      return;
    }
    forceGraphMorphFrame = undefined;
    if (forceGraphMorphTransitionDirection > 0) {
      forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.FOCUSED;
      showToast('A kiválasztott Atom környezete kártyákká bontakozott ki.');
    } else {
      forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.OVERVIEW;
      forceGraphMorphFocusIds = [];
      forceGraphMorphTargetPositions = undefined;
      forceGraphMorphNodes.forEach((node) => {
        node.renderPosition.copy(node.overviewPosition);
        node.morphStartPosition.copy(node.overviewPosition);
        node.morphTargetPosition.copy(node.overviewPosition);
      });
      applyForceGraphMorphTransition(1, 0);
      const pendingFocusId = forceGraphMorphPendingFocusId;
      forceGraphMorphPendingFocusId = undefined;
      if (pendingFocusId) window.requestAnimationFrame(() => startForceGraphMorphFocus(pendingFocusId));
    }
  }

  function startForceGraphMorphFocus(atomId) {
    if (!isForceGraphMorphView() || forceGraphMorphState !== FORCE_GRAPH_MORPH_STATES.OVERVIEW) return;
    const focusId = forceGraphMorphNodeById.has(atomId) ? atomId : forceGraphMorphNodes[0]?.id;
    if (!focusId) return;
    const layout = forceGraphMorphTargetLayout(focusId);
    forceGraphMorphFocusIds = layout.context.map((item) => item.id);
    forceGraphMorphNodes.forEach((node) => {
      node.morphStartPosition = node.renderPosition.clone();
      node.morphTargetPosition = (layout.targets.get(node.id) || node.overviewPosition).clone();
    });
    forceGraphMorphFocusIds.forEach((id) => drawForceGraphMorphCard(forceGraphMorphObjects.get(id), id));
    forceGraphMorphTargetPositions = layout.targets;
    forceGraphMorphTransitionDirection = 1;
    forceGraphMorphTransitionStartedAt = performance.now?.() || Date.now();
    forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.TRANSITION_TO_FOCUS;
    state.selectedId = focusId;
    state.centerId = focusId;
    if (state.history[state.history.length - 1] !== focusId) state.history.push(focusId);
    state.history = state.history.slice(-12);
    renderBreadcrumb();
    persist();
    forceGraph3D?.cameraPosition(
      { x: layout.base.x, y: layout.base.y, z: layout.base.z + 245 },
      { x: layout.base.x, y: layout.base.y, z: layout.base.z },
      850,
    );
    if (forceGraphMorphFrame) window.cancelAnimationFrame(forceGraphMorphFrame);
    forceGraphMorphFrame = window.requestAnimationFrame(runForceGraphMorphTransition);
  }

  function exitForceGraphMorph({ thenFocus } = {}) {
    if (!isForceGraphMorphView() || forceGraphMorphState !== FORCE_GRAPH_MORPH_STATES.FOCUSED) return;
    forceGraphMorphNodes.forEach((node) => {
      node.morphStartPosition = node.renderPosition.clone();
      node.morphTargetPosition = node.overviewPosition.clone();
    });
    forceGraphMorphTransitionDirection = -1;
    forceGraphMorphPendingFocusId = thenFocus;
    forceGraphMorphTransitionStartedAt = performance.now?.() || Date.now();
    forceGraphMorphState = FORCE_GRAPH_MORPH_STATES.TRANSITION_TO_OVERVIEW;
    forceGraph3D?.cameraPosition({ x: 0, y: 0, z: 340 }, { x: 0, y: 0, z: 0 }, 820);
    if (forceGraphMorphFrame) window.cancelAnimationFrame(forceGraphMorphFrame);
    forceGraphMorphFrame = window.requestAnimationFrame(runForceGraphMorphTransition);
  }

  function handleForceGraphMorphNodeClick(node) {
    const atomId = node?.id;
    if (!atomId) return;
    if (forceGraphMorphState === FORCE_GRAPH_MORPH_STATES.OVERVIEW) {
      startForceGraphMorphFocus(atomId);
      return;
    }
    if (forceGraphMorphState === FORCE_GRAPH_MORPH_STATES.FOCUSED && atomId !== forceGraphMorphFocusIds[0]) {
      exitForceGraphMorph({ thenFocus: atomId });
    }
  }

  function renderForceGraphMorph3D(animated = false) {
    const data = forceGraphMorphData();
    if (!forceGraph3D) return;
    forceGraph3D.graphData(data || { nodes: [], links: [] });
    if (!data) return;
    window.requestAnimationFrame(() => {
      if (forceGraphMorphState !== FORCE_GRAPH_MORPH_STATES.OVERVIEW) return;
      forceGraph3D?.cameraPosition({ x: 0, y: 0, z: 340 }, { x: 0, y: 0, z: 0 }, animated ? 340 : 0);
      applyForceGraphMorphTransition(0, 0);
    });
  }

  function createForceGraphMorph3D(attempt = 0) {
    const ForceGraph3D = window.ForceGraph3D;
    if (!ForceGraph3D || !force3dContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createForceGraphMorph3D(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      force3dContainer?.setAttribute('hidden', '');
      showToast('A 3D Force Zoom morph nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    force3dContainer.hidden = false;
    forceGraph3D = new ForceGraph3D(force3dContainer, { controlType: 'orbit' })
      .width(Math.max(force3dContainer.clientWidth, 320))
      .height(Math.max(force3dContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .showNavInfo(false)
      .enableNodeDrag(false)
      .nodeThreeObject(createForceGraphMorphAtom)
      .nodeThreeObjectExtend(false)
      .nodePositionUpdate(updateForceGraphMorphAtomPosition)
      .linkThreeObject(createForceGraphMorphLink)
      .linkThreeObjectExtend(false)
      .linkPositionUpdate(updateForceGraphMorphLink)
      .warmupTicks(0)
      .cooldownTicks(1)
      .cooldownTime(50)
      .onNodeClick(handleForceGraphMorphNodeClick)
      .onNodeHover((node) => { force3dContainer.style.cursor = node ? 'pointer' : 'grab'; })
      .onBackgroundClick(() => {
        if (forceGraphMorphState === FORCE_GRAPH_MORPH_STATES.FOCUSED) exitForceGraphMorph();
      });
    force3dResizeObserver = new ResizeObserver(() => {
      forceGraph3D?.width(Math.max(force3dContainer.clientWidth, 320)).height(Math.max(force3dContainer.clientHeight, 420));
    });
    force3dResizeObserver.observe(force3dContainer);
    renderForceGraphMorph3D();
  }

  // Planet zoom: a pontoknak itt nincs tartalmi szerepük. Csak kis bolygók
  // egy látványos 3D Force overview-ben, amelyek közül bármelyik ugyanabba a
  // nagy, forgatható Gömbkártyák v2 világba vezet.
  function forceGraphPlanetData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }

    const seed = nodeById.has(state.centerId) ? state.centerId : matched[0]?.id;
    const preview = buildFocusedG6Subgraph(seed, matched, knowledgeEdges, {
      firstRingLimit: 9,
      secondRingPerNode: 3,
      maxNodes: FORCE_GRAPH_MORPH_NODE_LIMIT,
    });
    const signature = preview.nodes.map((node) => node.id).join('|');
    const currentSignature = forceGraphPlanetNodes.map((node) => node.id).join('|');
    if (signature !== currentSignature) {
      forceGraphPlanetNodes = preview.nodes.map((atom, index) => {
        const overviewPosition = forceGraphMorphOverviewPosition(index, preview.nodes.length, atom.id);
        return {
          id: atom.id,
          overviewPosition,
          renderPosition: overviewPosition.clone(),
          x: overviewPosition.x, y: overviewPosition.y, z: overviewPosition.z,
          fx: overviewPosition.x, fy: overviewPosition.y, fz: overviewPosition.z,
        };
      });
      forceGraphPlanetLinks = preview.edges.map((edge, index) => ({
        source: edge.source,
        target: edge.target,
        id: `force-planet:${edge.source}:${edge.target}:${index}`,
      }));
      forceGraphPlanetNodeById = new Map(forceGraphPlanetNodes.map((node) => [node.id, node]));
      forceGraphPlanetState = FORCE_GRAPH_PLANET_STATES.OVERVIEW;
      forceGraphPlanetFocusId = undefined;
    }
    visibleNodeIds = forceGraphPlanetNodes.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    return { nodes: forceGraphPlanetNodes, links: forceGraphPlanetLinks };
  }

  function forceGraphPlanetMeshGeometry() {
    if (!forceGraphPlanetSphereGeometry) forceGraphPlanetSphereGeometry = new THREE.SphereGeometry(3.8, 20, 16);
    return forceGraphPlanetSphereGeometry;
  }

  function createForceGraphPlanetNode(node) {
    const cached = forceGraphPlanetObjects.get(node.id);
    if (cached) return cached;
    const group = new THREE.Group();
    const material = new THREE.MeshPhongMaterial({
      color: '#bb8bff', emissive: '#2d115c', shininess: 96, transparent: true, opacity: .95,
    });
    const sphere = new THREE.Mesh(forceGraphPlanetMeshGeometry(), material);
    group.add(sphere);
    group.userData = { sphere, material };
    forceGraphPlanetObjects.set(node.id, group);
    return group;
  }

  function updateForceGraphPlanetNodePosition(object, coordinates, node) {
    const position = node.renderPosition || new THREE.Vector3(coordinates.x || 0, coordinates.y || 0, coordinates.z || 0);
    object.position.copy(position);
    return true;
  }

  function forceGraphPlanetEndpointId(endpoint) { return typeof endpoint === 'object' ? endpoint?.id : endpoint; }

  function createForceGraphPlanetLink(link) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(6), 3));
    const material = new THREE.LineBasicMaterial({ color: '#d8c6ff', transparent: true, opacity: .26 });
    const line = new THREE.Line(geometry, material);
    line.userData.linkId = link.id;
    forceGraphPlanetLinkObjects.set(link.id, line);
    return line;
  }

  function updateForceGraphPlanetLink(line, coordinates, link) {
    const source = forceGraphPlanetNodeById.get(forceGraphPlanetEndpointId(link.source));
    const target = forceGraphPlanetNodeById.get(forceGraphPlanetEndpointId(link.target));
    if (!source || !target || !line?.geometry?.attributes?.position) return true;
    const positions = line.geometry.attributes.position;
    positions.setXYZ(0, source.renderPosition.x, source.renderPosition.y, source.renderPosition.z);
    positions.setXYZ(1, target.renderPosition.x, target.renderPosition.y, target.renderPosition.z);
    positions.needsUpdate = true;
    line.geometry.computeBoundingSphere();
    const fade = forceGraphPlanetState === FORCE_GRAPH_PLANET_STATES.OVERVIEW ? 1 : 0;
    line.material.opacity = .26 * fade;
    return true;
  }

  function applyForceGraphPlanetProgress(progress) {
    const eased = clamp(progress, 0, 1);
    const mapReveal = smoothstep(.58, .97, eased);
    forceGraphPlanetNodes.forEach((node) => {
      const object = forceGraphPlanetObjects.get(node.id);
      if (!object) return;
      const selected = node.id === forceGraphPlanetFocusId;
      const scale = selected ? 1 + eased * 19 : Math.max(.025, 1 - eased * .975);
      object.scale.setScalar(scale);
      object.userData.material.opacity = selected
        ? Math.max(0, .96 * (1 - mapReveal))
        : Math.max(0, .92 * (1 - eased * 1.15));
      object.userData.sphere.visible = object.userData.material.opacity > .01;
    });
    forceGraphPlanetLinks.forEach((link) => {
      const line = forceGraphPlanetLinkObjects.get(link.id);
      if (line) updateForceGraphPlanetLink(line, {}, link);
    });
    // A végpont nem egy másik 3D világ: a fokozatosan felúszó fehér réteg
    // a G6 fókuszált térkép saját hátterével azonos, ezért az átadás egyetlen
    // zoom- és színátmenetként érződik.
    mapCanvas?.style.setProperty('--force-planet-map-progress', mapReveal.toFixed(3));
  }

  function finishForceGraphPlanetZoom() {
    if (forceGraphPlanetState !== FORCE_GRAPH_PLANET_STATES.ZOOMING) return;
    forceGraphPlanetState = FORCE_GRAPH_PLANET_STATES.HANDOFF;
    const focusId = forceGraphPlanetFocusId || state.centerId;
    state.centerId = focusId;
    state.selectedId = focusId;
    state.visualization = 'g6-focused-map';
    state.layoutMenuOpen = false;
    updateVisualizationSelector();
    persist();
    destroyForceGraph3D();
    window.requestAnimationFrame(createG6Graph);
    showToast('A bolygó fókuszált térképpé alakult.');
  }

  function runForceGraphPlanetZoom(timestamp) {
    const raw = clamp((timestamp - forceGraphPlanetTransitionStartedAt) / FORCE_GRAPH_PLANET_DURATION, 0, 1);
    const eased = raw < .5 ? 4 * raw * raw * raw : 1 - Math.pow(-2 * raw + 2, 3) / 2;
    applyForceGraphPlanetProgress(eased);
    if (raw < 1) {
      forceGraphPlanetFrame = window.requestAnimationFrame(runForceGraphPlanetZoom);
      return;
    }
    forceGraphPlanetFrame = undefined;
    finishForceGraphPlanetZoom();
  }

  function startForceGraphPlanetZoom(nodeId) {
    if (!isForceGraphMorphView() || forceGraphPlanetState !== FORCE_GRAPH_PLANET_STATES.OVERVIEW) return;
    const selected = forceGraphPlanetNodeById.get(nodeId);
    if (!selected) return;
    forceGraphPlanetFocusId = selected.id;
    forceGraphPlanetState = FORCE_GRAPH_PLANET_STATES.ZOOMING;
    state.selectedId = selected.id;
    state.centerId = selected.id;
    if (state.history[state.history.length - 1] !== selected.id) state.history.push(selected.id);
    state.history = state.history.slice(-12);
    renderBreadcrumb();
    persist();
    const currentCamera = forceGraph3D?.cameraPosition?.() || { x: 0, y: 0, z: 340 };
    const center = selected.renderPosition;
    const direction = new THREE.Vector3(currentCamera.x - center.x, currentCamera.y - center.y, currentCamera.z - center.z);
    if (direction.lengthSq() < .001) direction.set(0, 0, 1);
    direction.normalize();
    forceGraph3D?.controls?.() && (forceGraph3D.controls().enabled = false);
    forceGraph3D?.cameraPosition(
      center.clone().addScaledVector(direction, 112),
      center,
      FORCE_GRAPH_PLANET_DURATION,
    );
    mapCanvas?.classList.add('is-force3d-sphere-view', 'is-force-planet-transition');
    mapCanvas?.style.setProperty('--force-morph-cluster-opacity', '0');
    mapCanvas?.style.setProperty('--force-planet-map-progress', '0');
    forceGraphPlanetTransitionStartedAt = performance.now?.() || Date.now();
    if (forceGraphPlanetFrame) window.cancelAnimationFrame(forceGraphPlanetFrame);
    forceGraphPlanetFrame = window.requestAnimationFrame(runForceGraphPlanetZoom);
  }

  function renderForceGraphPlanet3D(animated = false) {
    const data = forceGraphPlanetData();
    if (!forceGraph3D) return;
    forceGraph3D.graphData(data || { nodes: [], links: [] });
    if (!data) return;
    window.requestAnimationFrame(() => {
      if (forceGraphPlanetState !== FORCE_GRAPH_PLANET_STATES.OVERVIEW) return;
      forceGraph3D?.cameraPosition({ x: 0, y: 0, z: 340 }, { x: 0, y: 0, z: 0 }, animated ? 320 : 0);
      applyForceGraphPlanetProgress(0);
    });
  }

  function createForceGraphPlanet3D(attempt = 0) {
    const ForceGraph3D = window.ForceGraph3D;
    if (!ForceGraph3D || !force3dContainer) {
      if (attempt < 60) { window.requestAnimationFrame(() => createForceGraphPlanet3D(attempt + 1)); return; }
      empty.hidden = false;
      mapContainer.hidden = true;
      force3dContainer?.setAttribute('hidden', '');
      showToast('A 3D Force Planet zoom nézet nem tölthető be.');
      return;
    }
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = true;
    force3dContainer.hidden = false;
    forceGraph3D = new ForceGraph3D(force3dContainer, { controlType: 'orbit' })
      .width(Math.max(force3dContainer.clientWidth, 320))
      .height(Math.max(force3dContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .showNavInfo(false)
      .enableNodeDrag(false)
      .nodeThreeObject(createForceGraphPlanetNode)
      .nodeThreeObjectExtend(false)
      .nodePositionUpdate(updateForceGraphPlanetNodePosition)
      .linkThreeObject(createForceGraphPlanetLink)
      .linkThreeObjectExtend(false)
      .linkPositionUpdate(updateForceGraphPlanetLink)
      .warmupTicks(0)
      .cooldownTicks(1)
      .cooldownTime(50)
      .onNodeClick((node) => startForceGraphPlanetZoom(node?.id))
      .onNodeHover((node) => { force3dContainer.style.cursor = node ? 'pointer' : 'grab'; });
    force3dResizeObserver = new ResizeObserver(() => {
      forceGraph3D?.width(Math.max(force3dContainer.clientWidth, 320)).height(Math.max(force3dContainer.clientHeight, 420));
    });
    force3dResizeObserver.observe(force3dContainer);
    renderForceGraphPlanet3D();
  }

  // A gömbforgásnál a háló nem force-szimulációból készül: a teljes Atomkészlet
  // determinisztikus Fibonacci-héjon kap rögzített pozíciót. Így a 3D motor
  // csak a kamerát és a WebGL renderelést kezeli, nem számol új fizikát minden
  // képkockában.
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
    const links = knowledgeEdges
      .filter(({ source, target }) => nodeIds.has(source) && nodeIds.has(target))
      .map((edge) => ({ source: edge.source, target: edge.target }));
    const degreeById = new Map(matched.map((node) => [node.id, 0]));
    links.forEach(({ source, target }) => {
      degreeById.set(source, (degreeById.get(source) || 0) + 1);
      degreeById.set(target, (degreeById.get(target) || 0) + 1);
    });
    const maxDegree = Math.max(1, ...degreeById.values());
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));
    forceGraphSphereNodes = matched.map((node, index) => {
      const progress = (index + .5) / Math.max(matched.length, 1);
      const y = 1 - 2 * progress;
      const ring = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = goldenAngle * index;
      const position = {
        x: Math.cos(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
        y: y * FORCE_SPHERE_SHELL_RADIUS,
        z: Math.sin(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
      };
      return {
        ...node,
        name: node.title,
        __forceSphereDegree: degreeById.get(node.id) || 0,
        val: forceSphereNodeValue(degreeById.get(node.id) || 0, maxDegree),
        x: position.x,
        y: position.y,
        z: position.z,
        fx: position.x, fy: position.y, fz: position.z,
      };
    });
    return {
      nodes: forceGraphSphereNodes,
      links,
    };
  }

  // A Morph nézetben a teljes cluster ugyanannyi, stabil atomgömbből áll,
  // mint a Gömbforgás. Csak a kiválasztott lokális környezet kap egy második,
  // előre elkészített kártyamesht ugyanazon Three.js anchoron.
  function forceSphereMorphData() {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (globeContainer) globeContainer.hidden = true;
    if (staticAtomGlobeContainer) staticAtomGlobeContainer.hidden = true;
    if (force3dContainer) force3dContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = !empty.hidden;
    if (!empty.hidden) { visibleNodeIds = []; renderBreadcrumb(); return null; }

    const wantedIds = matched.map((node) => node.id).join('|');
    const existingIds = forceSphereMorphNodes.map((node) => node.id).join('|');
    if (wantedIds !== existingIds) {
      const goldenAngle = Math.PI * (3 - Math.sqrt(5));
      forceSphereMorphNodes = matched.map((atom, index) => {
        const progress = (index + .5) / Math.max(matched.length, 1);
        const y = 1 - 2 * progress;
        const ring = Math.sqrt(Math.max(0, 1 - y * y));
        const theta = goldenAngle * index;
        const overviewPosition = new THREE.Vector3(
          Math.cos(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
          y * FORCE_SPHERE_SHELL_RADIUS,
          Math.sin(theta) * ring * FORCE_SPHERE_SHELL_RADIUS,
        );
        const overviewQuaternion = new THREE.Quaternion().setFromUnitVectors(
          new THREE.Vector3(0, 0, 1), overviewPosition.clone().normalize(),
        );
        return {
          ...atom,
          atomId: atom.id,
          name: atom.title,
          val: Math.max(.7, (atom.importance || .5) * 1.8),
          overviewPosition,
          overviewQuaternion,
          renderPosition: overviewPosition.clone(),
          renderQuaternion: overviewQuaternion.clone(),
          x: overviewPosition.x, y: overviewPosition.y, z: overviewPosition.z,
          fx: overviewPosition.x, fy: overviewPosition.y, fz: overviewPosition.z,
        };
      });
      forceSphereMorphNodeById = new Map(forceSphereMorphNodes.map((node) => [node.id, node]));
      forceSphereMorphFocusIds = [];
      forceSphereMorphActiveLinks = [];
      forceSphereMorphState = MORPH_CLUSTER_STATES.OVERVIEW;
    }
    visibleNodeIds = matched.map((node) => node.id);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    return { nodes: forceSphereMorphNodes, links: forceSphereMorphActiveLinks };
  }

  function morphSphereGeometry() {
    if (!forceSphereMorphSphereGeometry) forceSphereMorphSphereGeometry = new THREE.SphereGeometry(4.2, 28, 20);
    return forceSphereMorphSphereGeometry;
  }

  function createMorphSphereAtom(node) {
    const cached = forceSphereMorphObjects.get(node.id);
    if (cached) return cached;
    const group = new THREE.Group();
    group.name = `djinn-morph-cluster-atom-${node.id}`;
    const sphereMaterial = new THREE.MeshPhongMaterial({
      color: node.validated ? '#c79bff' : '#9d7acb',
      emissive: node.type === 'topic' ? '#5d27bc' : '#25113f',
      shininess: 86,
      transparent: true,
      opacity: 1,
    });
    const sphere = new THREE.Mesh(morphSphereGeometry(), sphereMaterial);
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 256;
    const context = canvas.getContext('2d');
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    const cardMaterial = new THREE.MeshBasicMaterial({
      map: texture, transparent: true, depthTest: true, depthWrite: false, side: THREE.FrontSide, opacity: 0,
    });
    const card = new THREE.Mesh(forceSphereCurvedCardGeometry(), cardMaterial);
    card.position.z = .78;
    card.scale.setScalar(.15);
    card.visible = false;
    group.add(sphere, card);
    group.userData = { atomId: node.id, sphere, sphereMaterial, card, cardMaterial, canvas, context, texture };
    redrawMorphSphereCard(group, node.id);
    forceSphereMorphObjects.set(node.id, group);
    return group;
  }

  function redrawMorphSphereCard(group, atomId) {
    const atom = nodeById.get(atomId);
    const { context, canvas, texture } = group?.userData || {};
    if (!atom || !context || !canvas || !texture) return;
    context.clearRect(0, 0, canvas.width, canvas.height);
    const selected = atom.id === forceSphereMorphFocusIds[0];
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, selected ? '#c29bff' : '#8d66dd');
    gradient.addColorStop(1, selected ? '#5830ab' : '#301264');
    context.fillStyle = gradient;
    context.beginPath();
    if (context.roundRect) context.roundRect(5, 5, 502, 246, 30);
    else {
      context.moveTo(35, 5); context.arcTo(507, 5, 507, 251, 30); context.arcTo(507, 251, 5, 251, 30);
      context.arcTo(5, 251, 5, 5, 30); context.arcTo(5, 5, 507, 5, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = 5;
    context.strokeStyle = selected ? '#fff0ae' : 'rgba(245,237,255,.86)';
    context.stroke();
    context.fillStyle = 'rgba(255,255,255,.72)';
    context.font = '700 27px system-ui, sans-serif';
    context.fillText(TYPE_META[atom.type].label.toUpperCase(), 34, 54);
    context.fillStyle = '#fff';
    context.font = '800 49px system-ui, sans-serif';
    context.fillText(atom.title.length > 22 ? `${atom.title.slice(0, 21)}…` : atom.title, 34, 120);
    context.fillStyle = 'rgba(250,244,255,.84)';
    context.font = '400 29px system-ui, sans-serif';
    context.fillText(atom.subtitle.length > 31 ? `${atom.subtitle.slice(0, 30)}…` : atom.subtitle, 34, 173);
    texture.needsUpdate = true;
  }

  function updateMorphSphereAtomPosition(object, coordinates, node) {
    const position = node.renderPosition || new THREE.Vector3(coordinates.x || 0, coordinates.y || 0, coordinates.z || 0);
    object.position.copy(position);
    if (node.renderQuaternion) object.quaternion.copy(node.renderQuaternion);
    return true;
  }

  function morphLinkId(link) { return link.id || `${forceSphereEndpointId(link.source)}:${forceSphereEndpointId(link.target)}`; }

  function createMorphSphereSurfaceLink(link) {
    const line = createForceSphereSurfaceLink(link);
    line.userData.morphLinkId = morphLinkId(link);
    line.material.opacity = 0;
    forceSphereMorphLinks.set(line.userData.morphLinkId, line);
    return line;
  }

  function updateMorphSphereSurfaceLink(line, coordinates, link) {
    updateForceSphereSurfaceLink(line, coordinates, link);
    line.material.opacity = 0;
    return true;
  }

  function morphClusterLinks(atomIds) {
    const visible = new Set(atomIds);
    return knowledgeEdges
      .filter((edge) => visible.has(edge.source) && visible.has(edge.target))
      .sort((first, second) => second.weight - first.weight || first.source.localeCompare(second.source))
      .slice(0, 10)
      .map((edge) => ({ ...edge, id: `morph:${edge.source}:${edge.target}` }));
  }

  function morphClusterTargetTransforms(atomIds) {
    const basis = forceSphereCameraBasis();
    return new Map(atomIds.map((id, index) => {
      const slot = FORCE_SPHERE_CARD_SLOTS[index] || FORCE_SPHERE_CARD_SLOTS[0];
      return [id, forceSphereMorphSlotTransform(slot, basis)];
    }));
  }

  function applyMorphClusterProgress(progress) {
    const transition = clamp(progress, 0, 1);
    const collapse = smoothstep(0, .26, transition);
    const reveal = smoothstep(.23, .62, transition);
    const cardMorph = smoothstep(.54, .9, transition);
    const clusterBloom = smoothstep(.08, .5, transition);
    const edgeProgress = smoothstep(.76, 1, transition);
    forceSphereMorphClusterScale = 1 + clusterBloom * .08;
    forceSphereMorphClusterOpacity = 1 - smoothstep(.25, .7, transition) * .82;
    syncForceSphereVisualScale();

    const targets = forceSphereMorphTargetTransforms;
    forceSphereMorphNodes.forEach((node) => {
      const object = forceSphereMorphObjects.get(node.id);
      if (!object) return;
      const focusIndex = forceSphereMorphFocusIds.indexOf(node.id);
      const isFocusedAtom = focusIndex >= 0;
      const start = node.overviewPosition;
      const target = targets?.get(node.id);
      if (isFocusedAtom && target) {
        const collapsed = start.clone().lerp(new THREE.Vector3(), collapse);
        const position = collapsed.lerp(target.position, reveal);
        node.renderPosition.copy(position);
        node.renderQuaternion.copy(target.quaternion);
        node.x = node.fx = position.x; node.y = node.fy = position.y; node.z = node.fz = position.z;
        object.position.copy(position); object.quaternion.copy(target.quaternion);
        const horizon = object.userData.horizonOpacity ?? 1;
        object.userData.sphere.visible = transition < .96 && horizon > .01;
        object.userData.sphereMaterial.userData.morphOpacity = (1 - cardMorph) * Math.max(.05, reveal);
        object.userData.sphereMaterial.opacity = object.userData.sphereMaterial.userData.morphOpacity * horizon;
        object.userData.sphere.scale.setScalar(1 + cardMorph * .35);
        object.userData.card.visible = cardMorph > .01;
        object.userData.cardMaterial.userData.morphOpacity = cardMorph;
        object.userData.cardMaterial.opacity = cardMorph * horizon;
        object.userData.card.scale.setScalar(.15 + cardMorph * .85);
      } else {
        node.renderPosition.copy(start); node.renderQuaternion.copy(node.overviewQuaternion);
        object.position.copy(start); object.quaternion.copy(node.overviewQuaternion);
        const horizon = object.userData.horizonOpacity ?? 1;
        object.userData.sphere.visible = horizon > .01;
        object.userData.sphereMaterial.userData.morphOpacity = 1 - transition * .84;
        object.userData.sphereMaterial.opacity = object.userData.sphereMaterial.userData.morphOpacity * horizon;
        object.userData.sphere.scale.setScalar(1 - transition * .1);
        object.userData.card.visible = false;
        object.userData.cardMaterial.opacity = 0;
      }
    });
    syncMorphSphereEdges(edgeProgress);
  }

  let forceSphereMorphTargetTransforms;

  function syncMorphSphereEdges(progress) {
    forceSphereMorphActiveLinks.forEach((link) => {
      const line = forceSphereMorphLinks.get(morphLinkId(link));
      const source = forceSphereMorphNodeById.get(forceSphereEndpointId(link.source));
      const target = forceSphereMorphNodeById.get(forceSphereEndpointId(link.target));
      if (!line || !source || !target) return;
      updateForceSphereSurfaceLink(line, { start: source.renderPosition, end: target.renderPosition }, link);
      line.material.opacity = progress * ((link.weight || 0) >= .9 ? .78 : .56);
      line.visible = progress > .01;
    });
  }

  function interpolateMorphCamera(progress) {
    const camera = forceGraphSphere3D?.camera?.();
    if (!camera || !forceSphereMorphCameraStart || !forceSphereMorphCameraTarget) return;
    camera.position.lerpVectors(forceSphereMorphCameraStart, forceSphereMorphCameraTarget, progress);
    camera.lookAt(0, 0, 0);
    force3dSphereControls?.target?.set(0, 0, 0);
    force3dSphereControls?.update?.();
  }

  function runMorphClusterTransition(timestamp) {
    const elapsed = Math.max(0, timestamp - forceSphereMorphTransitionStartedAt);
    const raw = clamp(elapsed / MORPH_CLUSTER_DURATION, 0, 1);
    const eased = raw < .5 ? 4 * raw * raw * raw : 1 - Math.pow(-2 * raw + 2, 3) / 2;
    const progress = forceSphereMorphDirection > 0 ? eased : 1 - eased;
    if (forceSphereMorphDirection > 0) {
      forceSphereMorphState = raw < .38 ? MORPH_CLUSTER_STATES.ZOOMING_IN : raw < .64 ? MORPH_CLUSTER_STATES.REVEALING_ATOMS : MORPH_CLUSTER_STATES.MORPHING_CARDS;
    } else forceSphereMorphState = MORPH_CLUSTER_STATES.ZOOMING_OUT;
    interpolateMorphCamera(progress);
    syncMorphSphereHorizon();
    applyMorphClusterProgress(progress);
    if (raw < 1) {
      forceSphereMorphFrame = window.requestAnimationFrame(runMorphClusterTransition);
      return;
    }
    forceSphereMorphFrame = undefined;
    if (forceSphereMorphDirection > 0) {
      forceSphereMorphState = MORPH_CLUSTER_STATES.FOCUSED;
      force3dSphereControls && (force3dSphereControls.enabled = true);
      showToast('A cluster atomjai kártyaként kibontva.');
    } else {
      forceSphereMorphState = MORPH_CLUSTER_STATES.OVERVIEW;
      forceSphereMorphActiveLinks = [];
      forceSphereMorphFocusIds = [];
      forceSphereMorphTargetTransforms = undefined;
      forceGraphSphere3D?.graphData({ nodes: forceSphereMorphNodes, links: [] });
      forceSphereMorphLinks.clear();
      force3dSphereControls && (force3dSphereControls.enabled = true);
      if (force3dSphereControls) force3dSphereControls.autoRotate = true;
    }
  }

  function focusMorphCluster(atomId) {
    if (!isForceSphereMorphView() || forceSphereMorphState !== MORPH_CLUSTER_STATES.OVERVIEW) return;
    const available = forceSphereMorphNodeById.has(atomId) ? atomId : forceSphereMorphNodes[0]?.id;
    if (!available) return;
    forceSphereMorphFocusIds = buildMorphClusterFocusAtoms(available, knowledgeNodes.filter(matchesFilters), knowledgeEdges);
    forceSphereMorphFocusIds.forEach((id) => redrawMorphSphereCard(forceSphereMorphObjects.get(id), id));
    forceSphereMorphActiveLinks = morphClusterLinks(forceSphereMorphFocusIds);
    forceSphereMorphTargetTransforms = morphClusterTargetTransforms(forceSphereMorphFocusIds);
    const camera = forceGraphSphere3D?.camera?.();
    if (!camera) return;
    forceSphereMorphCameraStart = camera.position.clone();
    forceSphereMorphCameraTarget = camera.position.clone().normalize().multiplyScalar(MORPH_CLUSTER_CAMERA_DISTANCE);
    forceSphereMorphDirection = 1;
    forceSphereMorphTransitionStartedAt = performance.now?.() || Date.now();
    forceSphereMorphState = MORPH_CLUSTER_STATES.ZOOMING_IN;
    if (force3dSphereControls) { force3dSphereControls.enabled = false; force3dSphereControls.autoRotate = false; }
    forceGraphSphere3D.graphData({ nodes: forceSphereMorphNodes, links: forceSphereMorphActiveLinks });
    if (forceSphereMorphFrame) window.cancelAnimationFrame(forceSphereMorphFrame);
    forceSphereMorphFrame = window.requestAnimationFrame(runMorphClusterTransition);
  }

  function exitMorphCluster() {
    if (!isForceSphereMorphView() || forceSphereMorphState !== MORPH_CLUSTER_STATES.FOCUSED) return;
    const camera = forceGraphSphere3D?.camera?.();
    if (!camera) return;
    forceSphereMorphCameraStart = camera.position.clone();
    forceSphereMorphCameraTarget = camera.position.clone().normalize().multiplyScalar(FORCE_SPHERE_BASE_CAMERA_DISTANCE);
    forceSphereMorphDirection = -1;
    forceSphereMorphTransitionStartedAt = performance.now?.() || Date.now();
    forceSphereMorphState = MORPH_CLUSTER_STATES.ZOOMING_OUT;
    if (force3dSphereControls) { force3dSphereControls.enabled = false; force3dSphereControls.autoRotate = false; }
    if (forceSphereMorphFrame) window.cancelAnimationFrame(forceSphereMorphFrame);
    forceSphereMorphFrame = window.requestAnimationFrame(runMorphClusterTransition);
  }

  function forceSphereCurvedCardGeometry() {
    const width = 24;
    const height = 12;
    const radiusX = FORCE_SPHERE_SHELL_RADIUS * 1.15;
    const radiusY = FORCE_SPHERE_SHELL_RADIUS * 1.8;
    const key = `${width}:${height}:12:6:${radiusX}:${radiusY}`;
    const cached = forceSphereCardGeometryCache.get(key);
    if (cached) return cached;
    const geometry = new THREE.PlaneGeometry(24, 12, 12, 6);
    bendCardToSphereGeometry(geometry, radiusX, radiusY);
    forceSphereCardGeometryCache.set(key, geometry);
    return geometry;
  }

  function forceSphereCameraBasis() {
    const camera = forceGraphSphere3D?.camera?.();
    const target = force3dSphereControls?.target || { x: 0, y: 0, z: 0 };
    const normal = new THREE.Vector3(
      (camera?.position?.x || 0) - (target.x || 0),
      (camera?.position?.y || 0) - (target.y || 0),
      (camera?.position?.z || FORCE_SPHERE_BASE_CAMERA_DISTANCE) - (target.z || 0),
    ).normalize();
    const cameraUp = new THREE.Vector3(0, 1, 0).applyQuaternion(camera?.quaternion || new THREE.Quaternion()).normalize();
    let right = new THREE.Vector3().crossVectors(cameraUp, normal).normalize();
    if (right.lengthSq() < 1e-6) right = new THREE.Vector3(1, 0, 0);
    const up = new THREE.Vector3().crossVectors(normal, right).normalize();
    return { normal, right, up };
  }

  // A 3d-force-graph saját induló kamerája túl távoli ehhez a mobilos,
  // fókuszált gömbnézethez. A kártyák ezért ugyanarról a közeli távolságról
  // indulnak és oda térnek vissza, mint a referencia Morph-kameraállás.
  function initializeForceSphereCardCamera() {
    if (!forceGraphSphere3D || forceSphereCardCameraInitialized) return;
    const target = { x: 0, y: 0, z: 0 };
    force3dSphereControls?.target?.set(0, 0, 0);
    forceGraphSphere3D.cameraPosition(
      { x: 0, y: 0, z: FORCE_SPHERE_CARD_CAMERA_DISTANCE },
      target,
      0,
    );
    const camera = forceGraphSphere3D.camera?.();
    camera?.position?.set(0, 0, FORCE_SPHERE_CARD_CAMERA_DISTANCE);
    camera?.lookAt?.(0, 0, 0);
    force3dSphereControls?.update?.();
    forceSphereCardCameraInitialized = true;
  }

  // A teljes tangenciális frame megakadályozza, hogy a kártyák a gömb különböző
  // pontjain más-más, véletlenszerűnek ható roll-szögben jelenjenek meg.
  function forceSphereCardSlotTransform(slot, basis = forceSphereCameraBasis()) {
    // A tan-alapú közelítés 90° után visszafordította a slotot a kamera elé.
    // A valódi gömbi sin/cos vetítésnél a 96°-os frontier garantáltan a
    // horizont mögé kerül, és csak forgatáskor tárul fel.
    return forceSphereCardEntryTransform({ yaw: slot.yaw, pitch: slot.pitch }, basis);
  }

  function forceSphereCardAnchorTransform(normalInput, preferredUp) {
    const normal = normalInput.clone().normalize();
    const frame = forceSphereStructuredCardFrame(normal, preferredUp);
    const right = new THREE.Vector3(frame.right.x, frame.right.y, frame.right.z);
    const up = new THREE.Vector3(frame.up.x, frame.up.y, frame.up.z);
    const matrix = new THREE.Matrix4().makeBasis(right, up, normal);
    return {
      position: normal.clone().multiplyScalar(FORCE_SPHERE_SHELL_RADIUS),
      quaternion: new THREE.Quaternion().setFromRotationMatrix(matrix),
      normal,
    };
  }

  // A normál front-halmaz helyett ez gömbi koordinátát használ, így a yaw
  // 90° fölött is valóban a hátoldalra jut. A belépő slot soha nem egy Atom
  // állandó XYZ-je: újrahasznosításkor kapja meg a következő Atom.
  function forceSphereCardEntryTransform(entry, basis = forceSphereCameraBasis()) {
    const yaw = THREE.MathUtils.degToRad(entry.yaw);
    const pitch = THREE.MathUtils.degToRad(entry.pitch);
    const normal = basis.normal.clone().multiplyScalar(Math.cos(yaw) * Math.cos(pitch))
      .addScaledVector(basis.right, Math.sin(yaw) * Math.cos(pitch))
      .addScaledVector(basis.up, Math.sin(pitch))
      .normalize();
    return forceSphereCardAnchorTransform(normal, basis.up);
  }

  // A Morph kártyái a kamera pillanatnyi „fel” irányához igazodnak. Ettől a
  // központi kártya mindig egyenes marad, a környező hat pedig rendezett
  // térképszerű gyűrűt alkot, ahelyett hogy különböző roll-szögben úszna.
  function forceSphereMorphSlotTransform(slot, basis = forceSphereCameraBasis()) {
    const yaw = THREE.MathUtils.degToRad(slot.yaw);
    const pitch = THREE.MathUtils.degToRad(slot.pitch);
    const normal = basis.normal.clone()
      .addScaledVector(basis.right, Math.tan(yaw))
      .addScaledVector(basis.up, Math.tan(pitch))
      .normalize();
    const frame = forceSphereStructuredCardFrame(normal, basis.up);
    const right = new THREE.Vector3(frame.right.x, frame.right.y, frame.right.z);
    const up = new THREE.Vector3(frame.up.x, frame.up.y, frame.up.z);
    const matrix = new THREE.Matrix4().makeBasis(right, up, normal);
    const quaternion = new THREE.Quaternion().setFromRotationMatrix(matrix);
    return { position: normal.clone().multiplyScalar(FORCE_SPHERE_SHELL_RADIUS), quaternion, normal };
  }

  function createForceSphereCard(node) {
    const cached = forceSphereCardObjects.get(node.id);
    if (cached) return cached;
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 256;
    const context = canvas.getContext('2d');
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    const material = new THREE.MeshBasicMaterial({
      map: texture, transparent: true, depthTest: true, depthWrite: false, side: THREE.FrontSide,
    });
    const group = new THREE.Group();
    group.name = `djinn-force-sphere-card-${node.id}`;
    const card = new THREE.Mesh(forceSphereCurvedCardGeometry(), material);
    card.position.z = .7;
    group.add(card);
    group.userData = { atomId: undefined, textureKey: '', canvas, context, texture, material, card };
    forceSphereCardObjects.set(node.id, group);
    redrawForceSphereCard(group, node.atomId);
    return group;
  }

  function redrawForceSphereCard(group, atomId) {
    const atom = nodeById.get(atomId);
    const { context, canvas, texture } = group?.userData || {};
    if (!atom || !context || !canvas || !texture) return;
    const selected = atom.id === state.selectedId;
    context.clearRect(0, 0, canvas.width, canvas.height);
    const gradient = context.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, selected ? '#b38aff' : '#875ed7');
    gradient.addColorStop(1, selected ? '#5423a4' : '#2d135e');
    context.fillStyle = gradient;
    context.beginPath();
    context.roundRect?.(5, 5, 502, 246, 30);
    if (!context.roundRect) {
      context.moveTo(35, 5); context.arcTo(507, 5, 507, 251, 30); context.arcTo(507, 251, 5, 251, 30);
      context.arcTo(5, 251, 5, 5, 30); context.arcTo(5, 5, 507, 5, 30); context.closePath();
    }
    context.fill();
    context.lineWidth = 5;
    context.strokeStyle = selected ? '#fff0ae' : 'rgba(245,237,255,.86)';
    context.stroke();
    context.fillStyle = 'rgba(255,255,255,.7)';
    context.font = '700 27px system-ui, sans-serif';
    context.fillText(TYPE_META[atom.type].label.toUpperCase(), 34, 54);
    context.fillStyle = '#fff';
    context.font = '800 49px system-ui, sans-serif';
    context.fillText(atom.title.length > 22 ? `${atom.title.slice(0, 21)}…` : atom.title, 34, 120);
    context.fillStyle = 'rgba(250,244,255,.8)';
    context.font = '400 29px system-ui, sans-serif';
    context.fillText(atom.subtitle.length > 31 ? `${atom.subtitle.slice(0, 30)}…` : atom.subtitle, 34, 173);
    texture.needsUpdate = true;
    group.userData.atomId = atom.id;
    group.userData.textureKey = `${atom.id}:${selected}`;
  }

  function updateForceSphereCardPosition(object, coordinates, node) {
    const position = node.renderPosition || new THREE.Vector3(coordinates.x || 0, coordinates.y || 0, coordinates.z || 0);
    object.position.copy(position);
    if (node.renderQuaternion) object.quaternion.copy(node.renderQuaternion);
    return true;
  }

  function createForceSphereSurfaceLink(link) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(13 * 3), 3));
    const material = new THREE.LineBasicMaterial({ color: '#d7b7ff', transparent: true, opacity: .7 });
    const line = new THREE.Line(geometry, material);
    line.frustumCulled = false;
    line.userData.weight = link.weight || 0;
    return line;
  }

  function updateForceSphereSurfaceLink(line, { start, end }, link) {
    if (!line?.geometry?.attributes?.position || !start || !end) return true;
    const points = buildForceSphereSurfaceLinkPoints(start, end, 12);
    const positions = line.geometry.attributes.position;
    points.forEach((point, index) => positions.setXYZ(index, point.x, point.y, point.z));
    positions.needsUpdate = true;
    line.geometry.computeBoundingSphere();
    const strong = (link.weight || 0) >= .9;
    line.material.color.set(strong ? '#f3eaff' : '#d7b7ff');
    line.material.opacity = strong ? .86 : .58;
    return true;
  }

  function ensureForceSphereCardSlots() {
    if (forceSphereCardSlots.length) return;
    for (let index = 0; index < FORCE_SPHERE_CARD_POOL_SIZE; index += 1) {
      const offset = FORCE_SPHERE_CARD_SLOTS[index] || {
        yaw: index === 7 ? -45 : index === 8 ? 45 : 0,
        pitch: index === 7 ? 4 : index === 8 ? 4 : 32,
      };
      const nodeData = {
        id: `force-sphere-card-slot-${index}`,
        atomId: null,
        name: '',
        val: 1,
        fx: 0, fy: 0, fz: 0,
        x: 0, y: 0, z: 0,
        renderPosition: new THREE.Vector3(),
        renderQuaternion: new THREE.Quaternion(),
        __forceSphereVisible: false,
      };
      forceSphereCardSlots.push({
        index,
        atomId: null,
        yaw: offset.yaw,
        pitch: offset.pitch,
        focus: false,
        state: 'hidden',
        transitionAt: 0,
        anchorNormal: null,
        anchorUp: null,
        layer: 3,
        depth: 3,
        branchId: undefined,
        parentId: undefined,
        layout: undefined,
        nodeData,
      });
    }
  }

  function positionForceSphereCardSlot(slot, basis, { reanchor = false, entry = null } = {}) {
    const node = slot.nodeData;
    const transform = entry
      ? forceSphereCardEntryTransform(entry, basis)
      : (reanchor || !slot.anchorNormal
        ? forceSphereCardSlotTransform(slot, basis)
        : forceSphereCardAnchorTransform(slot.anchorNormal, slot.anchorUp || basis.up));
    if (entry || reanchor || !slot.anchorNormal) {
      slot.anchorNormal = transform.normal.clone();
      slot.anchorUp = basis.up.clone();
    }
    node.renderPosition.copy(transform.position);
    node.renderQuaternion.copy(transform.quaternion);
    node.x = node.fx = transform.position.x;
    node.y = node.fy = transform.position.y;
    node.z = node.fz = transform.position.z;
    const object = forceSphereCardObjects.get(node.id);
    object?.position.copy(transform.position);
    object?.quaternion.copy(transform.quaternion);
  }

  function assignForceSphereCardSlot(slot, atomId, basis, {
    visible = false,
    state: nextState = 'visible',
    entry = null,
    layer = 3,
    layout = undefined,
  } = {}) {
    const atom = nodeById.get(atomId);
    slot.atomId = atom?.id || null;
    slot.focus = false;
    slot.state = atom ? nextState : 'hidden';
    slot.layer = atom ? layer : 3;
    slot.layout = atom ? layout : undefined;
    slot.depth = atom ? (layout?.depth ?? 3) : 3;
    slot.branchId = atom ? layout?.branchId : undefined;
    slot.parentId = atom ? layout?.parentId : undefined;
    if (layout) {
      slot.yaw = layout.yaw;
      slot.pitch = layout.pitch;
    }
    slot.transitionAt = performance.now?.() || Date.now();
    const node = slot.nodeData;
    node.atomId = atom?.id || null;
    node.name = atom?.title || '';
    node.val = atom ? Math.max(.7, (atom.importance || .5) * 1.8) : 0;
    node.__forceSphereLayer = slot.layer;
    node.__forceSphereDepth = slot.depth;
    node.__forceSphereParentId = slot.parentId;
    positionForceSphereCardSlot(slot, basis, { reanchor: true, entry });
    node.__forceSphereVisible = Boolean(atom && visible);
    const object = forceSphereCardObjects.get(node.id);
    if (object) {
      if (atom) redrawForceSphereCard(object, atom.id);
      object.visible = Boolean(atom && visible);
    }
  }

  function forceSphereVisibleSlots() {
    const basis = forceSphereCameraBasis();
    return forceSphereCardSlots.filter((slot) => slot.atomId && (slot.anchorNormal?.dot(basis.normal) ?? -1) >= .04);
  }

  function forceSphereCardStreamDirection(basis = forceSphereCameraBasis()) {
    if (!forceSphereCardLastStreamNormal) return { x: 1, y: 0 };
    const delta = basis.normal.clone().sub(forceSphereCardLastStreamNormal);
    const x = Math.sign(delta.dot(basis.right));
    const y = Math.sign(delta.dot(basis.up));
    return Math.abs(x) >= Math.abs(y) ? { x: x || 1, y: 0 } : { x: 0, y: y || 1 };
  }

  function refillForceSphereCardPrefetch(basis = forceSphereCameraBasis(), direction = forceSphereCardStreamDirection(basis), { initial = false } = {}) {
    const assigned = new Set(forceSphereCardSlots.map((slot) => slot.atomId).filter(Boolean));
    forceSphereCardFrontier = buildRollingFrontier(
      forceSphereCardFocusId,
      forceSphereSeenAtomIds,
      forceSphereCardAvailableNodes,
      forceSphereCardAvailableEdges,
    )
      .filter((item) => !assigned.has(item.id));
    forceSphereCardSlots.filter((slot) => !slot.atomId).forEach((slot, index) => {
      const next = forceSphereCardFrontier[index];
      const entryDirection = initial ? { x: 1, y: 0 } : direction;
      const layer = initial ? 2 : 3;
      const entry = forceSphereCardLayerSlot(entryDirection, layer, initial ? index * 2 : forceSphereCardStreamSerial++);
      assignForceSphereCardSlot(slot, next?.id, basis, {
        visible: false,
        state: 'prefetch',
        entry,
        layer,
        layout: next ? { depth: 3, branchId: next.via || forceSphereCardFocusId, parentId: next.via || forceSphereCardFocusId, yaw: entry.yaw, pitch: entry.pitch, angularDistance: Math.hypot(entry.yaw, entry.pitch) } : undefined,
      });
      if (next?.id) forceSphereSeenAtomIds.add(next.id);
    });
  }

  function activeForceSphereCardLinks() {
    const slotsByAtomId = new Map(forceSphereCardSlots.filter((slot) => slot.atomId).map((slot) => [slot.atomId, slot]));
    return forceSphereCardAvailableEdges
      .filter((edge) => {
        const source = slotsByAtomId.get(edge.source);
        const target = slotsByAtomId.get(edge.target);
        if (!source || !target) return false;
        // Csak a layoutban kijelölt szülő–gyerek tudásutak rajzolódnak ki.
        // A többi gráfél a frontier prioritását szolgálja, nem vizuális zajt.
        return source.parentId === target.atomId || target.parentId === source.atomId;
      })
      .sort((first, second) => second.weight - first.weight)
      .slice(0, 10)
      .map((edge) => ({
        id: `force-sphere-link-${edge.source}-${edge.target}`,
        source: slotsByAtomId.get(edge.source).nodeData.id,
        target: slotsByAtomId.get(edge.target).nodeData.id,
        weight: edge.weight,
      }));
  }

  function commitForceSphereCardGraph() {
    if (!forceGraphSphere3D) return;
    const nodes = forceSphereCardSlots.filter((slot) => slot.atomId).map((slot) => slot.nodeData);
    forceGraphSphereNodes = nodes;
    forceGraphSphere3D.graphData({ nodes, links: activeForceSphereCardLinks() });
  }

  function rebuildForceSphereCardFocus(focusId, { commit = true } = {}) {
    ensureForceSphereCardSlots();
    const basis = forceSphereCameraBasis();
    const layout = buildLayeredSphericalFocusLayout(
      focusId,
      forceSphereCardAvailableNodes,
      forceSphereCardAvailableEdges,
      {
        depth1Limit: FORCE_SPHERE_VISIBLE_CARD_COUNT - 1,
        depth2PerBranch: 2,
        depth3Limit: FORCE_SPHERE_PREFETCH_CARD_COUNT,
      },
    );
    forceSphereCardFocusId = layout[0]?.id;
    forceSphereSeenAtomIds.clear();
    forceSphereCardStreamSerial = 0;
    layout.forEach((item, index) => {
      assignForceSphereCardSlot(forceSphereCardSlots[index], item.id, basis, {
        visible: false,
        state: item.depth === 3 ? 'prefetch' : 'entering',
        layer: item.depth === 0 || item.depth === 1 ? 1 : item.depth === 2 ? 2 : 3,
        layout: item,
      });
      forceSphereSeenAtomIds.add(item.id);
    });
    forceSphereCardSlots.slice(layout.length).forEach((slot) => assignForceSphereCardSlot(slot, undefined, basis));
    refillForceSphereCardPrefetch(basis, { x: 1, y: 0 });
    forceSphereCardLastStreamNormal = basis.normal.clone();
    if (commit) commitForceSphereCardGraph();
  }

  function forceSphereFacingScore(slot, basis = forceSphereCameraBasis()) {
    return slot.anchorNormal?.dot(basis.normal) ?? -1;
  }

  function syncForceSphereCardVisuals() {
    if (!forceGraphSphere3D) return 0;
    // Ebben a nézetben a lila gömb CSS-réteg. Ugyanabból a kameratávolságból
    // kapja a skálát, mint amely a WebGL-kártyák perspektíváját vezérli.
    syncForceSphereVisualScale();
    const basis = forceSphereCameraBasis();
    const now = performance.now?.() || Date.now();
    let visibleCount = 0;
    forceSphereCardSlots.forEach((slot) => {
      if (!slot.atomId) return;
      const facing = forceSphereFacingScore(slot, basis);
      const scaleProgress = smoothstep(.02, .74, facing);
      const scale = .28 + .78 * scaleProgress;
      const elapsed = Math.max(0, now - slot.transitionAt);
      const fade = (slot.state === 'entering' || slot.state === 'prefetch') ? clamp(elapsed / 220, .08, 1) : 1;
      const visible = facing >= .04;
      if (visible && slot.state === 'prefetch') slot.state = 'visible';
      // A rétegek nem újrarajzolt objektumok: ugyanaz a kártya lép elő a
      // kamerához képest, így Layer 3 → Layer 2 → Layer 1 folytonos átmenet.
      slot.layer = facing >= .62 ? 1 : visible ? 2 : 3;
      slot.nodeData.__forceSphereVisible = visible;
      slot.nodeData.__forceSphereLayer = slot.layer;
      const object = forceSphereCardObjects.get(slot.nodeData.id);
      if (!object) return;
      object.visible = visible;
      const depthScale = slot.depth === 0 ? 1.08 : slot.depth === 1 ? .88 : slot.depth === 2 ? .68 : .52;
      const layerScale = slot.layer === 1 ? 1 : slot.layer === 2 ? .84 : .66;
      object.scale.setScalar((slot.atomId === state.selectedId ? 1.02 : .88) * depthScale * layerScale * scale * fade);
      if (visible) visibleCount += 1;
    });
    return visibleCount;
  }

  function forceSphereCameraTurnDegrees(currentNormal) {
    if (!forceSphereCardLastStreamNormal) return 0;
    return THREE.MathUtils.radToDeg(Math.acos(clamp(forceSphereCardLastStreamNormal.dot(currentNormal), -1, 1)));
  }

  function syncForceSphereCardVisibilityConfig(force = false) {
    if (!forceGraphSphere3D) return;
    const key = forceSphereCardSlots
      .filter((slot) => slot.atomId)
      .map((slot) => `${slot.nodeData.id}:${slot.nodeData.__forceSphereVisible ? 1 : 0}`)
      .join('|');
    if (!force && key === forceSphereCardVisibilityKey) return;
    forceSphereCardVisibilityKey = key;
    forceGraphSphere3D
      .nodeVisibility((node) => node.__forceSphereVisible !== false)
      .linkVisibility((link) => {
        const source = forceSphereCardSlots.find((slot) => slot.nodeData.id === forceSphereEndpointId(link.source));
        const target = forceSphereCardSlots.find((slot) => slot.nodeData.id === forceSphereEndpointId(link.target));
        return Boolean(
          source?.nodeData.__forceSphereVisible
          && target?.nodeData.__forceSphereVisible
          && (source.parentId === target.atomId || target.parentId === source.atomId),
        );
      });
  }

  function streamForceSphereCardSlots(basis, visibleCount) {
    const movedDegrees = forceSphereCameraTurnDegrees(basis.normal);
    if (movedDegrees < FORCE_SPHERE_STREAM_STEP_DEGREES) return false;
    const direction = forceSphereCardStreamDirection(basis);
    const activeSlots = forceSphereCardSlots.filter((slot) => slot.atomId);
    const activeIds = new Set(activeSlots.map((slot) => slot.atomId));
    const queuedIds = buildRollingFrontier(
      forceSphereCardFocusId,
      forceSphereSeenAtomIds,
      forceSphereCardAvailableNodes,
      forceSphereCardAvailableEdges,
    ).map((item) => item.id).filter((id) => !activeIds.has(id));
    // Nem a peremnél cserélünk. A slot előbb átmegy a hátoldalra, és csak ott
    // kap új Atomot. Az új kártya ezért a rejtett féltekéről, a horizonton át
    // lép be, nem a néző szeme előtt pattan fel.
    const slotsToRecycle = activeSlots
      .filter((slot) => forceSphereFacingScore(slot, basis) < -.58)
      .sort((first, second) => forceSphereFacingScore(first, basis) - forceSphereFacingScore(second, basis));
    let changed = false;
    slotsToRecycle.forEach((slot, index) => {
      const nextAtomId = queuedIds[index];
      if (!nextAtomId) return;
      activeIds.delete(slot.atomId);
      activeIds.add(nextAtomId);
      const entry = forceSphereCardLayerSlot(direction, 3, forceSphereCardStreamSerial++);
      assignForceSphereCardSlot(slot, nextAtomId, basis, {
        visible: false,
        state: 'prefetch',
        entry,
        layer: 3,
        layout: { depth: 3, branchId: slot.branchId || forceSphereCardFocusId, parentId: slot.atomId || forceSphereCardFocusId, yaw: entry.yaw, pitch: entry.pitch, angularDistance: Math.hypot(entry.yaw, entry.pitch) },
      });
      forceSphereSeenAtomIds.add(nextAtomId);
      changed = true;
    });
    refillForceSphereCardPrefetch(basis, direction);
    forceSphereCardLastStreamNormal = basis.normal.clone();
    if (changed) commitForceSphereCardGraph();
    return changed || visibleCount < FORCE_SPHERE_VISIBLE_CARD_COUNT;
  }

  function updateForceSphereCardViewport(force = false) {
    if (!forceGraphSphere3D || !forceSphereCardSlots.length) return;
    const basis = forceSphereCameraBasis();
    const visibleCount = syncForceSphereCardVisuals();
    const streamed = streamForceSphereCardSlots(basis, visibleCount);
    if (streamed) syncForceSphereCardVisuals();
    syncForceSphereCardVisibilityConfig(force || streamed);
  }

  function scheduleForceSphereCardViewport(force = false) {
    if (force) forceSphereCardVisibilityKey = '';
    if (forceSphereCardViewportFrame) return;
    forceSphereCardViewportFrame = window.requestAnimationFrame(() => {
      forceSphereCardViewportFrame = undefined;
      updateForceSphereCardViewport(force);
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
    const scale = forceSphereZoomScale(distance) * (isForceSphereMorphView() ? forceSphereMorphClusterScale : 1);
    mapCanvas?.style.setProperty('--force-sphere-scale', scale.toFixed(4));
    mapCanvas?.style.setProperty('--force-morph-cluster-opacity', String(isForceSphereMorphView() ? forceSphereMorphClusterOpacity : 1));
  }

  // A CSS-gömb csak hangulat- és clusterfelület, nem valódi depth-objektum.
  // Ezért a Morph saját objektumain is elvégezzük a horizonttesztet: a hátsó
  // atomok és kártyák fokozatosan tűnnek el, nem látszanak át a gömbön.
  function syncMorphSphereHorizon() {
    if (!forceGraphSphere3D || !isForceSphereMorphView()) return;
    const camera = forceGraphSphere3D.camera?.();
    const target = force3dSphereControls?.target || { x: 0, y: 0, z: 0 };
    const viewNormal = new THREE.Vector3(
      (camera?.position?.x || 0) - (target.x || 0),
      (camera?.position?.y || 0) - (target.y || 0),
      (camera?.position?.z || FORCE_SPHERE_BASE_CAMERA_DISTANCE) - (target.z || 0),
    ).normalize();
    forceSphereMorphNodes.forEach((node) => {
      const object = forceSphereMorphObjects.get(node.id);
      if (!object) return;
      const normal = (node.renderPosition || node.overviewPosition).clone().normalize();
      const horizon = smoothstep(-.18, .16, normal.dot(viewNormal));
      object.userData.horizonOpacity = horizon;
      if (forceSphereMorphState === MORPH_CLUSTER_STATES.OVERVIEW) {
        object.userData.sphere.visible = horizon > .01;
        object.userData.sphereMaterial.opacity = horizon;
      } else {
        object.visible = horizon > .01;
        object.userData.sphereMaterial.opacity = (object.userData.sphereMaterial.userData.morphOpacity ?? 1) * horizon;
        object.userData.cardMaterial.opacity = (object.userData.cardMaterial.userData.morphOpacity ?? 0) * horizon;
      }
    });
  }

  // A gömb maga a CSS-rétegben sima marad. A WebGL réteg horizont-levágása
  // csak érzékelhető kameraforduláskor fut: nem építi újra a node geometriát,
  // és nem változtatja frame-enként a sugárértékeket.
  function syncForceSphereHorizonCulling(force = false) {
    if (isForceSphereMorphView()) {
      syncForceSphereVisualScale();
      syncMorphSphereHorizon();
      return;
    }
    if (isForceSphereCardsView()) {
      updateForceSphereCardViewport(force);
      return;
    }
    if (!forceGraphSphere3D) return;
    syncForceSphereVisualScale();
    const camera = forceGraphSphere3D.camera?.();
    const target = force3dSphereControls?.target || { x: 0, y: 0, z: 0 };
    const viewX = (camera?.position?.x || 0) - (target.x || 0);
    const viewY = (camera?.position?.y || 0) - (target.y || 0);
    const viewZ = (camera?.position?.z || 0) - (target.z || 0);
    const viewLength = Math.hypot(viewX, viewY, viewZ) || 1;
    const viewNormal = new THREE.Vector3(viewX / viewLength, viewY / viewLength, viewZ / viewLength);
    const angularDelta = forceSphereLastCullingNormal
      ? THREE.MathUtils.radToDeg(Math.acos(clamp(forceSphereLastCullingNormal.dot(viewNormal), -1, 1)))
      : Infinity;
    if (!force && angularDelta < FORCE_SPHERE_CULLING_STEP_DEGREES) return;
    forceSphereLastCullingNormal = viewNormal;
    const visibleIds = new Set();
    forceGraphSphereNodes.forEach((node) => {
      const nodeLength = Math.hypot(node.x || 0, node.y || 0, node.z || 0) || 1;
      const facing = ((node.x || 0) * viewX + (node.y || 0) * viewY + (node.z || 0) * viewZ) / (nodeLength * viewLength);
      const isVisible = facing >= FORCE_SPHERE_HORIZON;
      if (isVisible) visibleIds.add(node.id);
    });
    forceGraphSphere3D
      .nodeVisibility((node) => visibleIds.has(node.id))
      .linkVisibility((link) => visibleIds.has(forceSphereEndpointId(link.source)) && visibleIds.has(forceSphereEndpointId(link.target)));
  }

  function scheduleForceSphereHorizonCulling(force = false) {
    if (isForceSphereMorphView()) {
      syncForceSphereVisualScale();
      syncMorphSphereHorizon();
      return;
    }
    if (isForceSphereCardsView()) {
      scheduleForceSphereCardViewport(force);
      return;
    }
    if (force) {
      forceSphereLastCullingNormal = undefined;
    }
    if (force3dSphereCullingFrame) return;
    force3dSphereCullingFrame = window.requestAnimationFrame(() => {
      force3dSphereCullingFrame = undefined;
      syncForceSphereHorizonCulling(force);
    });
  }

  function renderForceSphereCardGraph(animated = false) {
    const matched = knowledgeNodes.filter(matchesFilters);
    empty.hidden = matched.length > 0;
    mapContainer.hidden = true;
    if (force3dSphereContainer) force3dSphereContainer.hidden = !empty.hidden;
    if (!forceGraphSphere3D || !matched.length) {
      forceGraphSphere3D?.graphData({ nodes: [], links: [] });
      visibleNodeIds = [];
      renderBreadcrumb();
      return;
    }
    const allowedIds = new Set(matched.map((node) => node.id));
    forceSphereCardAvailableNodes = matched;
    forceSphereCardAvailableEdges = knowledgeEdges.filter((edge) => allowedIds.has(edge.source) && allowedIds.has(edge.target));
    initializeForceSphereCardCamera();
    const focusId = allowedIds.has(state.centerId) ? state.centerId : matched[0].id;
    const requiresRebuild = forceSphereCardFocusId !== focusId
      || forceSphereCardSlots.some((slot) => slot.atomId && !allowedIds.has(slot.atomId));
    if (requiresRebuild) rebuildForceSphereCardFocus(focusId);
    visibleNodeIds = forceSphereVisibleSlots().map((slot) => slot.atomId);
    keyboardIndex = Math.max(0, visibleNodeIds.indexOf(state.selectedId));
    renderBreadcrumb();
    scheduleForceSphereCardViewport(true);
    if (animated) {
      const camera = forceGraphSphere3D.cameraPosition();
      forceGraphSphere3D.cameraPosition(camera, { x: 0, y: 0, z: 0 }, 220);
    }
  }

  function renderForceGraphSphere3D(animated = false) {
    if (isForceSphereMorphView()) {
      renderForceSphereMorphGraph(animated);
      return;
    }
    if (isForceSphereCardsView()) {
      renderForceSphereCardGraph(animated);
      return;
    }
    const data = forceGraphSphereData();
    if (!forceGraphSphere3D) return;
    forceGraphSphere3D.graphData(data || { nodes: [], links: [] });
    if (data) window.requestAnimationFrame(() => {
      forceGraphSphere3D?.cameraPosition({ x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE }, { x: 0, y: 0, z: 0 }, animated ? 360 : 0);
      scheduleForceSphereHorizonCulling(true);
    });
  }

  function renderForceSphereMorphGraph(animated = false) {
    const data = forceSphereMorphData();
    if (!forceGraphSphere3D) return;
    forceGraphSphere3D.graphData(data || { nodes: [], links: [] });
    if (!data) return;
    window.requestAnimationFrame(() => {
      if (forceSphereMorphState === MORPH_CLUSTER_STATES.OVERVIEW) {
        forceGraphSphere3D?.cameraPosition(
          { x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE },
          { x: 0, y: 0, z: 0 },
          animated ? 360 : 0,
        );
        applyMorphClusterProgress(0);
        syncMorphSphereHorizon();
      }
      syncForceSphereVisualScale();
    });
  }

  function selectForceSphereCard(atomId) {
    if (!nodeById.has(atomId)) return;
    if (state.history[state.history.length - 1] !== atomId) state.history.push(atomId);
    if (state.history.length > 12) state.history = state.history.slice(-12);
    state.centerId = atomId;
    state.selectedId = atomId;
    state.sheetOpen = true;
    // A kiválasztott Atom a kamera előtti középső Morph-slotba kerül; a
    // legerősebb közvetlen kapcsolatok szabályos Layer 1 gyűrűt kapnak.
    rebuildForceSphereCardFocus(atomId);
    commitForceSphereCardGraph();
    scheduleForceSphereCardViewport(true);
    persist();
    renderBreadcrumb();
    renderLayer();
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
    const cardView = isForceSphereCardsView();
    const morphView = isForceSphereMorphView();
    forceGraphSphere3D = new ForceGraph3D(force3dSphereContainer, { controlType: 'orbit' })
      .width(Math.max(force3dSphereContainer.clientWidth, 320))
      .height(Math.max(force3dSphereContainer.clientHeight, 420))
      .backgroundColor('rgba(0,0,0,0)')
      .showNavInfo(false)
      .nodeRelSize(FORCE_SPHERE_NODE_REL_SIZE)
      .nodeResolution(cardView || morphView ? 32 : FORCE_SPHERE_NODE_RESOLUTION)
      .nodeOpacity(1)
      .enableNodeDrag(false)
      .onNodeClick((node) => {
        if (morphView) {
          if (forceSphereMorphState === MORPH_CLUSTER_STATES.OVERVIEW) focusMorphCluster(node?.id);
          else if (forceSphereMorphState === MORPH_CLUSTER_STATES.FOCUSED && node?.id && node.id !== forceSphereMorphFocusIds[0]) {
            exitMorphCluster();
            window.setTimeout(() => focusMorphCluster(node.id), MORPH_CLUSTER_DURATION + 30);
          }
          return;
        }
        const atomId = cardView ? node?.atomId : node?.id;
        if (cardView && atomId) { selectForceSphereCard(atomId); return; }
        if (atomId) navigateTo(atomId);
      })
      .onBackgroundClick(() => {
        if (!morphView) return;
        if (forceSphereMorphState === MORPH_CLUSTER_STATES.OVERVIEW) focusMorphCluster(state.centerId);
        else if (forceSphereMorphState === MORPH_CLUSTER_STATES.FOCUSED) exitMorphCluster();
      })
      .onNodeHover((node) => { force3dSphereContainer.style.cursor = node ? 'pointer' : 'grab'; });
    if (morphView) {
      forceGraphSphere3D
        .nodeThreeObject(createMorphSphereAtom)
        .nodeThreeObjectExtend(false)
        .nodePositionUpdate(updateMorphSphereAtomPosition)
        .linkThreeObject(createMorphSphereSurfaceLink)
        .linkThreeObjectExtend(false)
        .linkPositionUpdate(updateMorphSphereSurfaceLink)
        .warmupTicks(0)
        .cooldownTicks(1)
        .cooldownTime(50);
    } else if (cardView) {
      // A ForceGraph itt Three.js render-, kamera- és interakciós motorként
      // fut. A slotok saját pozíciói felülírják a force szimulációt.
      forceGraphSphere3D
        .nodeThreeObject(createForceSphereCard)
        .nodeThreeObjectExtend(false)
        .nodePositionUpdate(updateForceSphereCardPosition)
        .linkThreeObject(createForceSphereSurfaceLink)
        .linkThreeObjectExtend(false)
        .linkPositionUpdate(updateForceSphereSurfaceLink)
        .warmupTicks(0)
        .cooldownTicks(1)
        .cooldownTime(50);
    } else {
      // A rögzített fx/fy/fz koordináták mellett nincs folyamatos D3 fizika.
      forceGraphSphere3D
        .warmupTicks(0)
        .cooldownTicks(1)
        .cooldownTime(50);
    }
    force3dSphereControls = forceGraphSphere3D.controls?.();
    if (force3dSphereControls) {
      force3dSphereControls.enableDamping = true;
      force3dSphereControls.dampingFactor = .08;
      force3dSphereControls.enablePan = false;
      if (cardView || morphView) force3dSphereControls.enableZoom = false;
      force3dSphereControls.autoRotate = !cardView && !morphView;
      force3dSphereControls.autoRotateSpeed = 2.2;
      force3dSphereControlsChangeHandler = () => {
        if (morphView) { syncForceSphereVisualScale(); syncMorphSphereHorizon(); }
        else if (cardView) scheduleForceSphereCardViewport();
        else { syncForceSphereVisualScale(); scheduleForceSphereHorizonCulling(); }
      };
      force3dSphereControls.addEventListener('change', force3dSphereControlsChangeHandler);
    }
    force3dSphereResizeObserver = new ResizeObserver(() => {
      forceGraphSphere3D?.width(Math.max(force3dSphereContainer.clientWidth, 320)).height(Math.max(force3dSphereContainer.clientHeight, 420));
    });
    force3dSphereResizeObserver.observe(force3dSphereContainer);
    renderForceGraphSphere3D();
  }

  function syncViewportState() {
    // A G6 a destroy() közben még küldhet egy utolsó viewport-eseményt. Ilyenkor
    // az instance már belül leállt, ezért getZoom() hibát dobna nézetváltáskor.
    if (!graphReady || !graph) return;
    let graphZoom;
    let graphPosition;
    try {
      graphZoom = graph.getZoom();
      graphPosition = graph.getPosition();
    } catch {
      return;
    }
    state.zoom = clamp(graphZoom, MIN_ZOOM, MAX_ZOOM);
    const [x, y] = graphPosition;
    state.panX = clamp(x, -260, 260); state.panY = clamp(y, -260, 260);
    persist();
    // A G6 saját pinch/wheel zoomja is ezen az eseményen jut el az állapothoz.
    // Csak LOD-határ átlépésekor cserélünk adatot, ezért nem renderelünk újra
    // minden egyes zoom-képkockában.
    if (isFocusedG6V2View() && focusedG6V2Lod(state.zoom).key !== focusedG6V2LodKey) {
      window.requestAnimationFrame(() => {
        if (isFocusedG6V2View()) renderFocusedG6V2Graph(false);
      });
    }
  }

  function renderGraph(animated = false) {
    if (isFocusedG6View()) { renderFocusedG6Graph(animated); return; }
    if (isFocusedG6V2View()) { renderFocusedG6V2Graph(animated); return; }
    if (isGlobeView()) { renderGlobe(animated); return; }
    if (isCardGlobeView()) { renderCardGlobe(animated); return; }
    if (isFocusedCardGlobeView()) { renderFocusedCardGlobe(animated); return; }
    if (isMixedFocusedGlobeView()) { renderFocusedMixedGlobe(animated); return; }
    if (isRollingCardGlobeView()) { renderRollingCardGlobe(animated); return; }
    if (isStaticAtomGlobeView()) { renderStaticAtomGlobe(animated); return; }
    if (isCytoscapeView()) { renderCytoscape(animated); return; }
    if (isForceSphereView()) { renderForceGraphSphere3D(animated); return; }
    if (isForceGraphMorphView()) { renderForceGraphPlanet3D(animated); return; }
    if (isForce3DView() || isForceUniverseDemoView()) { renderForceGraph3D(animated); return; }
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
    if (isFocusedCardGlobeView() || isMixedFocusedGlobeView()) state.focusedGlobeId = id;
    if (isRollingCardGlobeView()) {
      state.rollingGlobeId = id;
      rebuildRollingFocus(id, { animated: true });
    }
    state.pathMode = options.keepPath ? state.pathMode : false;
    state.sheetOpen = false;
    state.searchText = '';
    search.value = '';
    renderSearchResults(); renderGraph(true); persist(); renderLayer();
  }

  function goBack() {
    if (isForceSphereMorphView() && forceSphereMorphState === MORPH_CLUSTER_STATES.FOCUSED) {
      exitMorphCluster();
      return;
    }
    if (isForceGraphMorphView() && forceGraphPlanetState === FORCE_GRAPH_PLANET_STATES.ZOOMING) {
      return;
    }
    if (state.history.length < 2) return;
    state.history.pop();
    const previous = state.history[state.history.length - 1];
    state.centerId = previous; state.selectedId = previous; state.panX = 0; state.panY = 0; state.pathMode = false;
    if (isFocusedCardGlobeView() || isMixedFocusedGlobeView()) state.focusedGlobeId = previous;
    if (isRollingCardGlobeView()) {
      state.rollingGlobeId = previous;
      rebuildRollingFocus(previous, { animated: true });
    }
    renderGraph(true); persist(); renderLayer();
  }

  function resetFilters() {
    state.selectedTypes = new Set(FILTER_TYPES); state.validatedOnly = false; state.favoritesOnly = false;
    renderGraph(); persist(); renderLayer(); showToast('A térképszűrők visszaállítva.');
  }

  function zoomTo(nextZoom) {
    if (isForceSphereCardsView() || isForceSphereMorphView()) {
      showToast('Ebben a fókuszált gömbnézetben a kamera zoomja rögzített.');
      return;
    }
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
    } else if (isMixedFocusedGlobeView() && focusedGlobe) {
      const pov = focusedGlobe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      focusedGlobe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
    } else if (isRollingCardGlobeView() && rollingGlobe) {
      const pov = rollingGlobe.pointOfView();
      const multiplier = next > previous ? .82 : 1.2;
      rollingGlobe.pointOfView({ ...pov, altitude: clamp((pov.altitude || 2.1) * multiplier, 1.05, 4.8) }, 180);
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
    } else if (isForceGraphMorphView() && forceGraph3D) {
      if (forceGraphPlanetState !== FORCE_GRAPH_PLANET_STATES.OVERVIEW) {
        showToast('A bolygóba történő zoom animációja már fut.');
        return;
      }
      const camera = forceGraph3D.cameraPosition();
      const multiplier = next > previous ? .82 : 1.2;
      forceGraph3D.cameraPosition({ x: camera.x * multiplier, y: camera.y * multiplier, z: camera.z * multiplier }, undefined, 180);
    } else if ((isForce3DView() || isForceUniverseDemoView()) && forceGraph3D) {
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
    } else if (isMixedFocusedGlobeView() && focusedGlobe) {
      focusedGlobe.pointOfView({ lat: 0, lng: 0, altitude: 2.1 }, 260);
    } else if (isRollingCardGlobeView() && rollingGlobe) {
      state.virtualOffsetX = 0;
      state.virtualOffsetY = 0;
      rebuildRollingFocus(state.rollingGlobeId, { preserve: false });
      rollingGlobe.pointOfView({ lat: 0, lng: 0, altitude: 2.1 }, 260);
      renderRollingCardGlobe();
    } else if (isStaticAtomGlobeView() && staticAtomGlobe) {
      staticAtomGlobe.pointOfView({ lat: 18, lng: 28, altitude: 2.1 }, 260);
    } else if (isCytoscapeView() && cytoscapeGraph) {
      cytoscapeGraph.fit(cytoscapeGraph.elements(), 36);
    } else if (isForceSphereMorphView() && forceGraphSphere3D) {
      if (forceSphereMorphState === MORPH_CLUSTER_STATES.FOCUSED) exitMorphCluster();
      else forceGraphSphere3D.cameraPosition({ x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE }, { x: 0, y: 0, z: 0 }, 260);
    } else if (isForceSphereCardsView() && forceGraphSphere3D) {
      forceSphereCardCameraInitialized = false;
      initializeForceSphereCardCamera();
      rebuildForceSphereCardFocus(state.centerId);
      scheduleForceSphereCardViewport(true);
    } else if (isForceSphereView() && forceGraphSphere3D) {
      forceGraphSphere3D.cameraPosition({ x: 0, y: 0, z: FORCE_SPHERE_BASE_CAMERA_DISTANCE }, { x: 0, y: 0, z: 0 }, 260);
    } else if (isForceGraphMorphView() && forceGraph3D) {
      if (forceGraphPlanetState === FORCE_GRAPH_PLANET_STATES.OVERVIEW) {
        forceGraph3D.cameraPosition({ x: 0, y: 0, z: 340 }, { x: 0, y: 0, z: 0 }, 260);
      }
    } else if ((isForce3DView() || isForceUniverseDemoView()) && forceGraph3D) {
      forceGraph3D.zoomToFit(260, 34);
    } else if ((isFocusedG6View() || isFocusedG6V2View()) && graph) {
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
    destroyRollingCardGlobe();
    destroyStaticAtomGlobe();
    destroyCytoscape();
    destroyForceGraph3D();
    destroyForceGraphSphere3D();
  };
}
