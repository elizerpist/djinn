# Universe morph tesztképernyő – design specifikáció

**Dátum:** 2026-07-27
**Állapot:** jóváhagyott tervezési irány, implementáció előtt
**Cél:** izolált, mock-adatos prototípus a három egymásba alakuló tudásvizualizáció tesztelésére.

## 1. Cél és hatókör

Egyetlen új fejlesztői tesztképernyő készül, ahol a felhasználó egyazon vizuális felületen három szint között navigál:

```text
3D Force Graph galaxis
  └─ nagy bolygó-node tap → kamera fókusz + zoom + inline morph
       └─ lila, ThreeGlobe-alapú bolygó sárga felszíni node-okkal
            └─ sárga node tap → kamera fókusz + zoom + shared-element morph
                 └─ lapos, G6-szerű mock térkép
```

Ez kizárólag motion-, render- és interakciós prototípus. Nincsen mögötte végleges adatmodell, ObjectBox, backend, dokumentumtartalom vagy szemantikai navigáció.

Nem módosulnak a meglévő production nézetek, az Explore/Workspace bottom navigation, a `Megjelenítés` dropdown, breadcrumb, kereső vagy meglévő route-ok viselkedése. A teszt csak külön fejlesztői hash route-on érhető el: `#universe-morph-test`.

## 2. Meglévő kód és új felelősségi határok

### Meglévő, újrahasznosítható referenciák

| Forrás | Felhasználás a tesztben |
| --- | --- |
| `prototypes/working-prototype/assets/knowledge-map.js` – `createForceGraph3D()` | 3D Force Graph inicializálás, kamera- és controls-hozzáférés mintája |
| `prototypes/working-prototype/assets/knowledge-map.js` – `createForceGraphSphere3D()` | gömbi node/edge megjelenés vizuális referenciája |
| `prototypes/working-prototype/assets/knowledge-map.js` – `createG6Graph()` | fókuszált, lapos térkép megjelenésének referenciája |
| `prototypes/working-prototype/assets/vendor/three-globe.min.js` | a részletes bolygó egyetlen, újrahasznosított `ThreeGlobe` példánya |

### Új, izolált modulok

```text
UniverseMorphTestScreen
├── GalaxyForceLayer           # 3d-force-graph, mock galaxis
├── PlanetThreeGlobeLayer      # egy reusable ThreeGlobe a force scene-ben
├── FlatMapGraphLayer          # inaktív, majd fokozatosan felfedett mock G6 térkép
├── MorphProxyLayer            # 3D sárga node → sík lila map-node shared element
├── UniverseCameraController   # kamera snapshot, fókusz- és zoom tweenek
├── UniverseMorphController    # állapotgép és layer átmenetek
└── TestDebugHud               # kizárólag tesztelési eszközök
```

A tesztképernyő saját fájlokban marad. A közös alkalmazás-indító csak a külön hash route felismeréséhez kap minimális, elkülönített belépési pontot.

## 3. Renderarchitektúra

### Galaxis → bolygó

A galaxis és a részletes bolygó **egyetlen** Three.js universe-ben működik:

```text
3d-force-graph
├── scene()
│   ├── force graph node-ok és edge-ek
│   └── selected planet root group
│       ├── proxy SphereGeometry
│       └── reusable ThreeGlobe detail object
├── camera()
├── renderer()
└── controls()
```

- Nem mountolunk külön standalone `Globe.gl` canvast.
- Nem hozunk létre második WebGL contextet a galaxishoz vagy bolygóhoz.
- Egyetlen `ThreeGlobe` objektum jön létre, kezdetben rejtett.
- A kiválasztott nagy force-node `THREE.Group` gyökeréhez csatlakozik és a proxy sugárhoz skálázódik.
- A proxy gömb és a `ThreeGlobe` rövid, ugyanazon világpozícióban történő crossfade/scale morphot kap.

### Bolygó → térkép

A lapos térkép külön 2D réteg lehet, mert a G6/canvas és a Three.js eltérő renderer. Ez azonban ugyanabban a tesztképernyő-konténerben, route-váltás nélkül, inaktív pointer rétegen marad.

A második átmenethez egyetlen DOM/CSS shared-element proxy használható:

1. a sárga Three.js gömb világpozícióját a kamera képernyőkoordinátájára projektáljuk;
2. a 3D gömb 80–140 ms alatt elhalványul;
3. a proxy ugyanott sárga körként megjelenik;
4. körből lekerekített lila map-node-dá nő;
5. a háttér, edge-ek és térképi node-ok szakaszosan jelennek meg;
6. a proxy átadja a szerepet a map központi node-jának.

Ez nem route-, screen- vagy modal-váltás.

## 4. Mock adatok és determinisztikusság

Minden mock adat a `TEST_SEED = 42` alapján determinisztikusan készül, ezért újratöltés után a vizuális elrendezés és a replay megismételhető.

| Szint | Node | Edge | Sajátosság |
| --- | ---: | ---: | --- |
| Galaxis | 180 | 260 | 8 nagy, egyértelműen tapelhető bolygó-node |
| Bolygó | 140 | 210 | Fibonacci-sphere elosztású sárga node-ok |
| Térkép | 28 | 42 | fókusz-node + közeli/távoli mock kapcsolatok |

A galaxis nagy bolygói stabil ID-t, nagyobb sugarat és erősebb glow-t kapnak. A sárga bolygófelszíni node-ok kisebb, külön hit-sphere-rel bővített raycast célok. Semmilyen tesztadat nem kerül a production adatmodellbe.

## 5. Állapotgép

```ts
type UniverseLevel =
  | 'GALAXY'
  | 'GALAXY_TO_PLANET'
  | 'PLANET'
  | 'PLANET_TO_MAP'
  | 'MAP'
  | 'MAP_TO_PLANET'
  | 'PLANET_TO_GALAXY';

type UniverseMorphState = {
  level: UniverseLevel;
  selectedGalaxyNodeId: string | null;
  selectedPlanetNodeId: string | null;
  transitionProgress: number;
  interactionLocked: boolean;
};
```

### Engedélyezett átmenetek

```text
GALAXY
  → GALAXY_TO_PLANET → PLANET
  → PLANET_TO_MAP    → MAP
  → MAP_TO_PLANET    → PLANET
  → PLANET_TO_GALAXY → GALAXY
```

Átmenet alatt a pointer interakció le van zárva. A `transitionProgress` requestAnimationFrame-ben frissül, nem React state-ben frame-enként. A debug HUD olvasható állapotot kaphat ritkított frissítéssel.

## 6. Interakció és kamera

### Galaxis-node tap

1. Csak nagy bolygó-node indíthat átmenetet.
2. A tap és drag szétválasztása: legfeljebb 8 px mozgás és 300 ms időtartam.
3. Azonnali kiválasztási visszajelzés: planet glow és kapcsolódó edge-ek erősödnek, háttér halványul.
4. A controls ideiglenesen tiltódik.
5. A kamera 450–650 ms alatt a kiválasztott node felé orientál és hozzá közelít.
6. A végén a node a képernyő közepe közelében van; ezután indul a 450–600 ms-os proxy gömb → lila ThreeGlobe morph.

A kiválasztott node nem teleportál: a kamera és controls target mozog. A node a transition idejére rögzíthető a force szimuláció aktuális koordinátáján.

### Bolygó-node tap

1. A 3D force scene bolygó root groupja fordul úgy, hogy a kiválasztott sárga node felületi normálja a kamera felé nézzen.
2. Ezután kontrollált zoom kerül a node-ra, miközben a node képernyőpozíciója stabilizálódik.
3. A közeli node-ok/edge-ek kiemelődnek, az irrelevánsak tompulnak.
4. Indul a 450–650 ms-os 3D sárga gömb → shared proxy → lapos lila map-node morph.

### Vissza navigáció

A HUD `Vissza` gombja minden lépést fordítva játszik le. A két kameraállapot (`galaxyCamera`, `planetCamera`) snapshotként tárolódik, ezért a visszatérés nem ugrik és visszaállítja az előző kontrollcélpontot.

## 7. Időzítés és vizuális átmenetek

### Galaxis → bolygó

| Idő | Történés |
| --- | --- |
| 0–100 ms | kiválasztási glow, háttérgalaxis tompítása |
| 0–650 ms | kamera fókusz + zoom |
| 650–1 200 ms | proxy sphere fade-out; ThreeGlobe fade-in és 0.92→1 scale |
| 850–1 200 ms | atmoszféra, sárga node-ok és kapcsolatok rövid staggerrel megjelennek |

A nem kiválasztott galaxisnode-ok nem tűnnek el teljesen: 0.10–0.18 opacity, a nem releváns edge-ek 0.02–0.05 opacity körül maradnak.

### Bolygó → térkép

| Progress | Történés |
| --- | --- |
| 0–35% | sárga 3D gömb fade-out, morf proxy jelenik meg |
| 30–60% | sötét térképi háttér és közeli edge-ek fade-in |
| 45–75% | közeli map-node-ok scale/opacity belépése |
| 65–100% | távoli node-ok, címkék és teljes mock térkép |

Easing minden fő átmenetnél: `cubic-bezier(0.2, 0, 0, 1)` vagy azzal egyenértékű `easeInOutCubic`.

## 8. Látvány

- Galaxis: sötét tér, lila/levendula gömb-node-ok, diszkrét edge-ek.
- Bolygó: lila, világos jobb felső oldalú gömb, mélylila árnyék, finom atmoszféra, sok sárga felszíni gömb és halvány felszíni kapcsolat.
- Térkép: a meglévő G6 fókuszált térkép v2 deep-space violet hangulata, lila kártya/node-ok és világos olvasható kapcsolatok.
- Teszt UI: kis, nem production Debug HUD; tartalmazza az aktuális szintet, progresszt, kiválasztott ID-kat, kamera-távolságot, FPS-t és a `Galaxy`, `Planet`, `Map`, `Reverse`, `Replay` vezérlőket.

## 9. Követelmény- és elfogadási checklist

| ID | Forrás | Kódterület | Elfogadási feltétel | Verifikáció | Állapot |
| --- | --- | --- | --- | --- | --- |
| UM-01 | Felhasználói prompt: külön tesztképernyő | új test route/screen | `#universe-morph-test` izoláltan megnyílik, production nézetek változatlanok | manuális hash-route teszt, diff review | NOT DONE |
| UM-02 | 1. szint | `GalaxyForceLayer` | 180 node, 260 edge, legalább 8 nagy tapelhető bolygó | determinisztikus mock-data teszt + manuális | NOT DONE |
| UM-03 | galaxis tap átmenet | kamera controller | tap → kiválasztás → sima fókusz + zoom, node nem teleportál | manuális képernyőfelvétel/screenshot | NOT DONE |
| UM-04 | galaxis → bolygó inline morph | force scene + `ThreeGlobe` | ugyanazon világpozíción lila részletes bolygó jelenik meg, nincs route/canvas villanás | scene/code inspect + manuális | NOT DONE |
| UM-05 | egy univerzum | render ownership | galaxishoz és bolygóhoz egy scene, kamera, renderer, controls, egy reusable `ThreeGlobe` tartozik | code inspect + WebGL context sanity check | NOT DONE |
| UM-06 | 2. szint | `PlanetThreeGlobeLayer` | 140 sárga, raycast-tapelhető felszíni node és 210 gömbkövető edge látszik | mock count teszt + manuális | NOT DONE |
| UM-07 | bolygó tap átmenet | planet controller | a kiválasztott sárga node szembefordul, zoomol, majd stable screen-positionről morfol | manuális | NOT DONE |
| UM-08 | 3. szint | `MorphProxyLayer`, `FlatMapGraphLayer` | sárga gömbből lila, sík map központi node lesz; a 28/42 mock gráf fokozatosan felfedődik | manuális + mock count teszt | NOT DONE |
| UM-09 | visszafelé működés | morph controller | Map→Planet→Galaxy animált, kamera snapshotok visszaállnak | manuális | NOT DONE |
| UM-10 | no route/screen switch | layer visibility | szintek között nincs navigáció, modal, fehér/fekete flash vagy app remount | manuális + code review | NOT DONE |
| UM-11 | interakció | tap/drag gate | drag és pinch nem indít node-tapot; transition alatt nincs második transition | célzott UI/manual teszt | NOT DONE |
| UM-12 | teljesítmény | all layers | nincs frame-enkénti React state update; rejtett layer nem kap pointer eseményt; force layout stabil a morph alatt | performance/code inspection | NOT DONE |
| UM-13 | scope guard | existing production components | Explore bottom nav, Workspace nav, dropdown, breadcrumb, kereső és production grafok érintetlenek | diff review | NOT DONE |

## 10. Verifikációs terv

1. Statikus ellenőrzés: JavaScript syntax check és célzott mock-data/state-machine unit teszt.
2. Kódellenőrzés: csak az új dev test fájlok plusz a minimális hash-route belépési pont változik.
3. Manuális mobilteszt:
   - nyisd meg `#universe-morph-test`;
   - tap egy nagy galaxisbolygóra;
   - ellenőrizd a kamera fókuszt, a force→ThreeGlobe inline morphot és a sárga node-okat;
   - forgasd a bolygót, tap egy sárga node-ra;
   - ellenőrizd a shared proxy átmenetet és a fokozatos map belépést;
   - `Reverse`-szel menj vissza mindkét szinten;
   - ismételd le reload nélkül a HUD segítségével.
4. Vizualis ellenőrzés: készül egy screenshot mindhárom stabil állapotról és legalább egy transition köztes állapotáról.
5. Teljesítmény: a Debug HUD FPS kijelzőjén ellenőrizhető, hogy a láthatatlan map layer nem vesz át inputot és nincs canvas/context-szaporodás.

## 11. Ismert technikai korlátok

- A bolygó → térkép átalakulás rendererhatáron történik, ezért a tökéletes vertex-level 3D deformáció helyett szándékosan shared-element proxy a stabil első megoldás.
- A tesztképernyő a meglévő renderkódot referencia- és mintaként használja; az első iterációban nem írja át a jelenlegi production grafikus motorokat.
- A ThreeGlobe csatolását és a globális `THREE` kompatibilitást a meglévő vendor betöltési sorrendhez kell igazítani, mert a könyvtár UMD csomagként van vendorizálva.

## 12. Nem célok

- valós atom-, edge-, dokumentum- vagy ObjectBox adat;
- végleges cluster-hierarchia;
- production Explore orb vagy jelenlegi dropdown módosítása;
- különálló globális navigáció a három szinthez;
- teljes lazy-render, search vagy content card rendszer.
