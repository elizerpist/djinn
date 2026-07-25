# Djinn – egységes chunkmodell refaktor

> Kötelező munkaszerződés és végrehajtási checklist. A gyökér `README.md`
> termékmodelljével együtt ez a source of truth. Ha a jelenlegi kód vagy egy
> régi dokumentum ettől eltér, ez a modell az irányadó.

## Fogalmak

- **Jegyzet**: felhasználói gyűjtőegység. A régi leírásokban a téma vagy
  `topic` ennek szinonimája.
- **Chunk**: globálisan azonosítható tudáselem, amelyet forrásokhoz és egy vagy
  több Jegyzethez kapcsolatok kötnek.
- **NoteChunk / Jegyzetchunk**: szabadon szerkeszthető rich-content chunk.
  Bekezdés, címsor, lista és táblázat a tartalma, nem külön chunktípus.
- **FlowchartChunk**: gráfstruktúrájú chunk node-okkal és élekkel.
- **Létrehozási mód**: a chunk kezdeti előállításának metaadata; nem típus,
  jogosultság, lista vagy editor.

## Megváltoztathatatlan termékdöntések

1. A bottom nav első eleme **Jegyzetek** marad. A jelenlegi header, mappasáv,
   FAB, jegyzetkártyák, hosszú koppintásos kijelölés és context menü kerete
   változatlan.
2. Nincs külön user-, AI-, manuális-, OCR- vagy PDF-chunk adattípus.
3. Pontosan két végleges chunktípus létezik:
   `note_chunk` és `flowchart_chunk`.
4. A `manual_selection`, `assisted_selection`, `ai_generated` és `imported`
   értékek kizárólag `creationMethod` metaadatok.
5. A régi `text`, `paragraph`, `heading`, `list`, `table`, `mixed` és `score`
   chunkértékek csak adatmegőrző migrációs bemenetek. Mind `note_chunk`
   lesznek, miközben tartalmuk rich-content szekcióként megmarad.
6. A régi `flowchart`, flowchart node és flowchart edge adatok egyetlen
   `flowchart_chunk` tudáselem gráftartalmává állnak össze.
7. Egy PDF megnyitott chunklistája és egy Jegyzet chunklistája ugyanazt a
   kártya- és editorrendszert használja; csak a lekérdezési scope más.
8. A **Jegyzetbe küldés** kapcsolatot hoz létre. Nem másol és nem mozgat.
9. A tagek strukturális metaadatok. A chunk jobb felső badge-e a különböző
   tagek darabszámát mutatja; a tag nem festi ki a tartalmat.
10. A kézi **Kitöltés** rich-text formázás, amely a kijelölt szöveg
    háttérszínét tárolja. A tagoktól független és eltávolítható.
11. A jelenlegi PDF-kinyerési workflow működése ebben a refaktorban megmarad.
    A pipeline eredménye már az egységes Chunk modellbe kerül.
12. A chunk-létrehozó és chunk-export felület kizárólag a két kanonikus típust
    kínálhatja.

## Chunk-export alapmodell

Az export nem vezetheti vissza a megszüntetett chunktípusokat. A verziózott
exportcsomag minden eleménél az alábbi két érték egyikét írja:

```text
kind = note_chunk | flowchart_chunk
```

Egy `note_chunk` exportja a teljes rich-content struktúrát, a plain-text
keresési reprezentációt, a tageket, a kézi kitöltéseket, a validációt,
eredet-metaadatot és forráshivatkozást viszi. A `flowchart_chunk` ugyanezek
mellett a node-, port-, él- és elrendezési adatokat viszi.

Az export sheet alapjai:

1. scope: aktuális chunk, kijelölt chunkok, aktuális Jegyzet vagy aktuális
   PDF-forrás;
2. típusjelzés: Jegyzetchunk és Flowchart, olvasható darabszámmal;
3. formátum: Djinn JSON az adatvesztésmentes alapformátum, a PDF
   megjelenítési export marad külön művelet;
4. források: metaadatként beágyazva vagy kihagyva;
5. előnézet és export.

Az import a régi többtípusú csomagokat elfogadhatja és migrálhatja, de az új
export soha nem írhat `text`, `list`, `table`, `mixed`, `score` vagy külön
AI/user chunk típust.

## Elfogadási checklist

| ID | Forrás | Kódterület | Elfogadási feltétel | Ellenőrzés | Állapot |
| --- | --- | --- | --- | --- | --- |
| NAV-01 | Felhasználó: „bottom nav első menuje… Jegyzet” | `main_screen.dart`, `notes_screen.dart` | A Jegyzetek célhelye, FAB-ja, header menüje, mappasávja, jegyzetkártya-tap/long-press viselkedése nem regresszál. | Meglévő és célzott widgettesztek. | DONE |
| DM-01 | Felhasználó: „közös adatmodell” | chunk domain + ObjectBox | Egy globális Chunk entitás tárolja a kézi, asszisztált, AI és importált elemeket. | Sémavizsgálat, repository teszt. | DONE |
| DM-02 | Felhasználó: „csak 2 chunktípus” | chunk enumok, adapterek | A kanonikus `ChunkKind` pontosan `noteChunk` és `flowchartChunk`. | Enum- és szerializációs teszt, `rg`. | DONE |
| DM-03 | Felhasználó: „szöveg… táblázat… lista megy” | rich-content modell | Bekezdés, címsor, lista és táblázat `NoteChunk`-szekció, nem chunktípus. | Modell round-trip, legacy migrációs és kézi mentési teszt. | DONE |
| DM-04 | Felhasználó: „mindegy ki végezte” | `creationMethod` | A négy létrehozási mód metaadatként round-tripel; nem választ listát vagy editort. | Modell/repository/UI teszt. | DONE |
| DM-05 | „tiszta adat hátteret” | ObjectBox entitások/repository | Jegyzet- és PDF-chunk ugyanabban a globális chunk store-ban van; a Jegyzet csak kapcsolatokkal csoportosít. | Integrációs repository teszt. | DONE |
| DM-06 | „tiszta adat hátteret”, ugyanaz a chunk több scope-ban | flowchart projection + forrás-életciklus | Egy Jegyzethez kapcsolt, forrásától leválasztott Flowchart szerkesztése frissíti a node/edge projectiont; azonos ID-jű újrafeldolgozás explicit visszacsatolja az aktív PDF-forrást. | Natív ObjectBox regressziótesztek. | DONE |
| DM-07 | „tiszta adat hátteret”, Flowchart a két kanonikus típus egyike | ObjectBox Note repository + flowchart projection | Új vagy legacy Jegyzet-only Flowchartnál az M:N link a projekció előtt tartósul, ezért a flowchart/node/edge projection már az első mentés vagy migráció végén létezik. | Natív ObjectBox create/migrációs regresszióteszt. | DONE |
| MIG-01 | Meglévő felhasználói adat megőrzése | ObjectBox UID-k, legacy `notes.json` migráció | A régi DocumentChunk sorok UID-vesztés nélkül Chunk sorok maradnak; régi note JSON egyszer, idempotensen importálódik. | Régi payload fixture + kétszeri migráció teszt. | DONE |
| MIG-02 | Régi többtípusú chunkok | domain migrátor | text/heading/paragraph/list/table/mixed/score → NoteChunk; flowchart → FlowchartChunk, tartalomvesztés nélkül. | Paraméterezett migrációs teszt. | DONE |
| UI-01 | „egy bemenet, egy menu, egy design” | `note_chunk_fab.dart`, editor route | A létrehozó menüben csak Jegyzetchunk és Flowchart van; minden NoteChunk ugyanabban a rich editorban nyílik. | Widgetteszt és közvetlen kódvizsgálat. | DONE |
| UI-02 | AI/user nincs szeparálva | PDF chunklista | Nincs AI- és manuális chunklista/tab; egy lista mutat mindent, kis eredetjelöléssel. | Widgetteszt. | DONE |
| TAG-01 | TextChunk tagmódszer referencia | tag repository/model | NoteChunk és FlowchartChunk ugyanazt a tag registry/repository folyamatot használja. | Repository/model/editor teszt. | DONE |
| TAG-02 | „jobb felső színes badge” | shared chunk card | Egyetlen jobb felső badge mutatja az egyedi tagek számát mindkét típusnál. | Widgetteszt. | DONE |
| TAG-03 | „highlight szín sem lesz” | chunk rendererek | Taghozzárendelés nem állít text/background színt. | Render widgetteszt. | DONE |
| TAG-04 | „tagrendszer marad” | structured adapter + range/scoped tagek | A scoped tag nem léptetődik top-level taggé; részleges retag után minden `textRange` scoped hivatkozás létező range ID-ra mutat. | Adapter/model/editor regresszióteszt. | DONE |
| RICH-01 | „keyboard feletti rail… kitöltés” | egységes rich editor | Kijelölt szövegre Kitöltés beállítható, módosítható és eltávolítható. | Modell round-trip + editor widgetteszt. | DONE |
| RICH-02 | Flowchartban is azonos | flowchart node/edge szöveg | Flowchart szerkeszthető feliratain ugyanaz a kitöltési modell és rail művelet használható. | Flowchart editor widgetteszt. | DONE |
| PDF-01 | „egyelőre hagyd meg… workflow-t” | PDF import/feldolgozás | A meglévő kézi/AI/OCR indítási útvonalak tovább működnek, de közös Chunkot írnak. | Meglévő PDF pipeline tesztek. | DONE |
| PDF-02 | „ugyanannak az appelemnek… másik szempont” | chunk list/card/editor | PDF- és Jegyzet-scope ugyanazt a közös listakártyát és editor routert használja. | Adapter- és widgetteszt. | DONE |
| PDF-03 | README: „Mentéskor ezek mind ugyanazt a `note_chunk` modellt írják” | kézi PDF chunk editor + mixed parser | A kézzel választott lista egy list sectiont, a táblázat egy table sectiont ment; a markdown elválasztósor nem válik adattá. | Parser unit- és mentés utáni repository/widgetteszt. | DONE |
| LINK-01 | „longtap… Jegyzetbe küldés” | PDF chunklista | Hosszú koppintás kijelölési módot nyit; context menüben megjelenik a Jegyzetbe küldés; dialog listázza a Jegyzeteket. | Widgetteszt. | DONE |
| LINK-02 | „nem másolás… több témában” | Chunk–Jegyzet relation | A művelet ugyanazon chunk ID-hoz idempotens kapcsolatot hoz létre; több Jegyzet támogatott; PDF scope megmarad. | ObjectBox integrációs teszt. | DONE |
| EXP-01 | Aktuális kiegészítés | export domain/sheet | A chunk-export szerződés és UI csak NoteChunk/FlowchartChunk típust ismer. | Export service + widgetteszt. | DONE |
| EXP-02 | README exportalapok | import/export migráció | Új export schema v2 két típust ír; legacy többtípusú import NoteChunkká migrálható. | Golden JSON round-trip teszt. | DONE |
| EXP-03 | Meglévő PDF export | PDF export | A vizuális PDF-export mindkét kanonikus típust rendereli; bekezdés/lista/tábla rich contentként, a táblaméretek megőrzésével marad. | Meglévő + új PDF export tesztek. | DONE |
| EXP-04 | README exportalapok: forrásmetaadat kapcsoló | Jegyzet/PDF JSON export | Kikapcsolt forrásmetaadatnál sem a `source`, sem az oldaladat nem kerül a csomagba. | Repository- és widget-regresszióteszt. | DONE |
| EXP-05 | README exportalapok: négy scope | export sheet + production belépési pontok | Az aktuális chunk, kijelölt chunkok, aktuális Jegyzet és aktuális PDF scope production UI-ból elérhető; az exportált subset megfelel a scope-nak. | Export sheet- és PDF chunklista widgetteszt. | DONE |
| DOC-01 | Source of truth | `README.md`, ez a fájl | A README részletesen tartalmazza a két típust, migrációt, kapcsolati modellt és exportot; nincs ellentmondó aktív leírás. | Dokumentációs `rg`, kézi újraolvasás. | DONE |
| QA-01 | AGENTS.md | teljes projekt | `flutter analyze` és a teljes `flutter test` zöld Ubuntu/proot alatt. | Friss parancskimenet. | DONE |
| CI-01 | Felhasználó: végén push/build/download | Git/GitHub Actions | Egy végső commit kerül a feature ágra, push után online APK-build zöld. | Git SHA + Actions run. | DONE |
| APK-01 | Felhasználó: Download/djinn | artifact | A buildelt APK a `/storage/emulated/0/Download/djinn` könyvtárban van és SHA256 rögzített. | Fájl- és checksum-ellenőrzés. | DONE |

### Friss ellenőrzési bizonyíték

- 2026-07-25: `flutter analyze` Ubuntu/proot alatt: **No issues found**.
- 2026-07-25: `dart run build_runner build` a generált ObjectBox-modellt
  konzisztensnek találta.
- 2026-07-25: a végső, javítás utáni teljes `flutter test` Ubuntu/proot alatt:
  **561 sikeres, 28 kihagyott, 0 hibás**.
- A 28 kihagyás kizárólag a telefonos Ubuntu hoston nem elérhető natív
  `libobjectbox.so`-t igénylő ObjectBox-integrációs eset. A sémakontinuitás,
  codec, memóriás repository és UI-tesztek helyben lefutottak; a natív
  ObjectBox-eseteket – köztük az új Jegyzet-only Flowchart create/update és
  legacy migrációs projekciótesztet – a `CI-01` x64 GitHub Actions futása
  sikeresen ellenőrizte.
- A végső read-only code review a projekciós hívássorrend javítása után
  **READY** verdiktet adott.
- `git diff --check`: tiszta.
- GitHub Actions run `30174571433`: a backendteszt, az ObjectBox-generálás,
  az analyze, a teljes x64 Flutter/ObjectBox tesztcsomag és az ARM64 debug
  APK-build sikeres.
- A buildelt `djinn-debug-172b4f7.apk` a kért
  `/storage/emulated/0/Download/djinn` könyvtárba került; SHA-256:
  `53809b368621c90b5750f346cbcaef1ade35d4a0979198764b9c982b8a637209`.

## Végrehajtási terv és checkpointok

### CP0 – baseline és források

- A legfrissebb, bottom-navos ág a megvalósítás alapja.
- A régi munkafa és az ott lévő, ettől független módosítások érintetlenek.
- Baseline analyze/test eredmény rögzítve.

### CP1 – domain és adatmegőrző háttér

- Közös `ChunkKind`, `ChunkCreationMethod`, forrás- és validációs metaadat.
- A jelenlegi DocumentChunk ObjectBox UID-jének megőrzésével globális
  Chunk entitás.
- Jegyzet-gyűjtő, Jegyzet–Chunk kapcsolat és mappák ObjectBoxban.
- Idempotens régi `notes.json` és régi chunk-wire migráció.

### CP2 – NoteChunk rich content és FlowchartChunk

- Minden legacy szöveg/lista/tábla/kevert elem egységes NoteChunk struktúra.
- Csak Jegyzetchunk/Flowchart létrehozó menü.
- Közös editor router és közös kártya.

### CP3 – tagek és Kitöltés

- Közös tagmódszer, darabszám-badge, tagvezérelt kiemelés eltávolítása.
- Perzisztens rich-text kitöltési range-ek.
- Ugyanaz az alapmechanizmus flowchart feliratoknál.

### CP4 – PDF scope és Jegyzetbe küldés

- Egyesített PDF chunklista, eredet csak metaadat.
- Long-press multi-select, Jegyzetbe küldés dialog, idempotens relation.
- Jegyzet megnyitásakor ugyanaz a PDF-chunk ugyanazzal az ID-val jelenik meg.

### CP5 – két-típusú export

- Djinn chunk export schema v2 és legacy importer.
- Scope/típus/forrás alapokat tartalmazó export sheet.
- Meglévő PDF export kompatibilis az egységes rich-content modellel.

### CP6 – lezárás

- Célzott, majd teljes analyze/test.
- Checklist és README újbóli ellenőrzése; csak valós `DONE` státuszok.
- Egy commit, feature branch push, GitHub Actions build és APK-letöltés.

## Kifejezetten későbbi munka

A teljes Chunk Studio, új AI-feldolgozási konfiguráció, automatikus
chunkjavaslat-review és OCR-újratervezés a README szerinti következő fázis.
Ebben a refaktorban a meglévő kinyerési workflow megmarad.
