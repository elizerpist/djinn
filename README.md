# Djinn

Djinn egy általános, local-first jegyzetalkalmazás, vektoros tudásgráf és
forrásolt tudáslekérdező rendszer. Saját jegyzeteket, feltöltött PDF-eket,
képeket, OCR-rel kinyert részleteket és folyamatábrákat ugyanabban a helyi,
kereshető tudástérben kezel.

A termék nem kötődik egyetlen szakterülethez. Használható személyes
tudásbázisként, tanuláshoz, kutatáshoz, projekt- és munkajegyzetekhez,
dokumentumfeldolgozáshoz, illetve megfelelően validált forrásokkal
döntéstámogatásra. Egy AI által megfogalmazott válasz önmagában nem forrás:
minden lényeges állítást vissza kell tudni vezetni az eredeti jegyzethez,
chunkhoz vagy dokumentumoldalhoz.

> **Source of truth**
>
> Ez a README a Djinn egyetlen kanonikus, általános termék- és
> architektúraleírása. A végrehajtás tételes elfogadási jegyzéke a
> `REFACTOR_JEGYZET.md`. A korábbi, egymásnak részben ellentmondó dátumozott
> specifikációk és tervek eltávolításra kerültek; a `docs/superpowers/README.md`
> csak erre a két kanonikus fájlra mutató index. Ha a régi kód vagy adat eltér,
> az itt leírt modell az irányadó.

## A termék alapelve

Djinnben a tudás nem elszigetelt fájlok gyűjteménye, hanem globálisan
azonosítható, összekapcsolható tudáselemek hálózata.

```text
Jegyzet vagy forrásdokumentum
  └─ Chunk
      ├─ szerkeszthető tartalom
      ├─ forrás és validáció
      ├─ tagek, fogalmak és kulcsszavak
      ├─ vektorreprezentáció
      └─ gráfkapcsolatok más chunkokhoz és fogalmakhoz
```

A rendszer elsődleges tudásegysége a **Chunk**. A felhasználó által írt, kézi
kijelölésből származó, OCR-rel segített, AI által javasolt vagy importált chunk
egyenrangú. Az eredete metaadat, nem külön adattípus, külön adatbázis vagy külön
felhasználói felület.

## Kötelező fogalmak

- **Jegyzet**: felhasználói gyűjtő- és munkaterület. A korábbi leírásokban a
  **téma** vagy `topic` ennek szinonimája. Nem azonos a `NoteChunk` típussal.
- **Chunk**: globálisan azonosítható tudáselem, amelyet forrásokhoz és egy vagy
  több Jegyzethez kapcsolatok kötnek.
- **Jegyzetchunk / `note_chunk`**: szabadon szerkeszthető rich-content chunk.
  Bekezdés, címsor, lista és táblázat a belső tartalma, nem külön chunktípus.
- **Flowchart chunk / `flowchart_chunk`**: egyetlen gráftartalmú chunk,
  node-okkal, élekkel, címkékkel és elrendezéssel.
- **Létrehozási mód**: a chunk kezdeti előállításának nyomkövetési metaadata.
  Nem határozza meg a kártyát, editort, listát vagy rangot.
- **Forrás**: saját Jegyzet, PDF, kép vagy importált fájl, valamint az abból
  származó oldal-, terület- és eredetiszöveg-adat.
- **Validáció**: annak állapota, hogy a tudáselem felülvizsgálatlan,
  szerkesztett, elfogadott vagy elutasított.

## Elsődleges navigáció

A három elsődleges termékfunkció ugyanazt a helyi tudásbázist más nézőpontból
kezeli:

1. **Jegyzetek** – jelentés és felhasználói munkakörnyezet szerinti nézet;
2. **Tudástár** – az eredeti források és feldolgozásuk szerinti nézet;
3. **Kérdezz** – keresési, gráfbejárási és forrásolt kérdés-válasz nézet.

A jelenlegi alkalmazásban a Kérdezz célhely felirata még **Chat**, és a
**Beállítások** külön negyedik bottom-nav célhely. Ez implementációs elnevezés,
nem külön tudásmodell. A Jegyzetek a bottom nav bal szélső, első eleme.

| Nézet | Alapkérdés | Lekérdezési scope |
| --- | --- | --- |
| Jegyzetek | Milyen jelentésbeli vagy munkakörnyezetben használom ezt a tudást? | Egy Jegyzethez kapcsolt, több forrásból származó chunkok |
| Tudástár | Milyen forrásaim vannak, és milyen tudás származik belőlük? | Egy dokumentumhoz vagy más forráshoz tartozó chunkok |
| Kérdezz | Mit tud a rendszer erről a kérdésről? | Teljes vagy kiválasztott tudásbázis, majd vektoros keresés és gráfbővítés |

Ez nem három adatbázis. Ugyanaz a chunk megjelenhet a PDF-je alatt, több
Jegyzetben, keresési találatként és egy forrásolt válasz hivatkozásaként.

## Jegyzetek

### Szerep

A Jegyzetek menü a felhasználó által kialakított tudás- és munkaterületeket
mutatja. Egy Jegyzet egy tárgyhoz, projekthez, kutatási kérdéshez vagy
érdeklődési körhöz tartozó chunkokat fog össze.

A Jegyzet nem másolja és nem birtokolja a chunkot. Egy kapcsolótáblán keresztül
hivatkozik rá, ezért ugyanaz a PDF-chunk például egyszerre kapcsolható az
„Android”, az „Adatbiztonság” és egy projekt Jegyzetéhez.

### Jegyzetek főképernyő

A meglévő képernyő stílusa és műveleti hierarchiája megmarad.

#### Header

- bal oldalon Djinn logó és a **Jegyzetek** cím;
- jobb oldalon hárompontos dropdown;
- normál állapotban rendezési, import-, export- és mappaműveletek;
- hosszú koppintásos kijelölésnél a jelenlegi context műveletek.

#### Subheader és mappák

A header alatti mappasáv chipekkel mutatja az összes Jegyzetet és a létrehozott
mappákat. Innen hozható létre új mappa, váltható az aktív mappa, illetve a sáv
elrejthető vagy megjeleníthető. A mappa a Jegyzeteket rendezi; nem mozgatja a
forrásfájlt vagy a chunkot.

A célmodell támogatja a Jegyzetek manuális drag-and-drop sorrendjét. Amíg ez
nincs minden tárolási útvonalon véglegesítve, a meglévő idő- és névalapú
rendezés az aktív működés.

#### Jegyzetkártyák és FAB

- A body Jegyzetkártyákat mutat.
- Egyetlen koppintás megnyitja a Jegyzet chunklistáját.
- Hosszú koppintás kijelölési módba lép.
- A képernyő FAB-ja új **Jegyzet-gyűjtőegységet** hoz létre.
- A FAB ezen a szinten nem chunktípust választ; chunkot a megnyitott Jegyzetben
  lehet létrehozni.

Egy kártyán a cím, rövid tartalmi előnézet, módosítási idő, validáció és
később forrás-/chunkszám jelenhet meg. Archiválás vagy Jegyzet-egyesítés csak
akkor tekinthető kész funkciónak, ha a UI és a kapcsolati művelet is
implementálva van; a fogalmi modell ettől függetlenül változatlan.

### Megnyitott Jegyzet

A megnyitott Jegyzet egy kevert chunklistát mutat. Saját, PDF-, OCR-,
asszisztált, AI-javaslatból jóváhagyott vagy importált elem egymás mellett
jelenhet meg. A kártya és az editor kiválasztását kizárólag a két kanonikus
`ChunkKind` vezérli.

A chunk létrehozó FAB pontosan két lehetőséget kínál:

1. **Jegyzetchunk**
2. **Flowchart chunk**

Bekezdés, lista és táblázat a Jegyzetchunkon belül hozható létre és szabadon
keverhető. Nincs külön Szövegchunk, Listachunk, Táblázatchunk, User chunk vagy
AI chunk.

## Tudástár

### Szerep

A Tudástár forrásközpontú. PDF-eket, képeket, szkennelt dokumentumokat és más
támogatott importokat kezel. A főképernyő forráskártyákat mutat, nem egy
ömlesztett globális chunklistát.

Egy forráskártya a fájlnevet, típust, feldolgozási állapotot, importálási időt,
chunkszámot, hibát és mappakapcsolatot jelenítheti meg. A dokumentumok
mappázhatók, kijelölhetők és tömeges műveletekkel kezelhetők.

### PDF és a hozzá tartozó chunklista

A PDF-kártya tartalmi része a **PDF chunkok** nézetet nyitja meg; a külön
forrásikon a PDF-preview útvonalára vezethet. A PDF chunklista nem második
Jegyzet menü és nem külön adatmodell:

```text
Jegyzet megnyitása → az adott Jegyzethez kapcsolt chunkok
PDF megnyitása     → az adott PDF-forráshoz tartozó chunkok
```

A két nézet ugyanazt a közös kártyarendszert és ugyanazt a két editorcsaládot
használja. A PDF-listában nincs AI-, manuális- vagy lokális tab. A
`creationMethod` kis eredetjelölésként látható lehet, de nem választ külön
listát.

### Jegyzetbe küldés

A PDF chunklistában:

1. hosszú koppintás kijelöli a chunkot;
2. további chunkok is kijelölhetők;
3. a hárompontos kijelölési menüben megjelenik a **Jegyzetbe küldés**;
4. egy dialog felsorolja a Jegyzeteket;
5. a választás idempotens Chunk–Jegyzet kapcsolatot hoz létre.

Ez nem másolás és nem mozgatás. A chunk globális azonosítója, PDF-forrása,
eredeti szövege és oldalszáma megmarad; csak új tagsági él készül. Ugyanaz a
chunk több Jegyzetbe is elküldhető.

## Kérdezz és keresés

A Kérdezz nézet a saját tudásbázishoz intézett természetes nyelvű kérdések
felülete. Az AI opcionális megfogalmazási és következtetési réteg ugyanazon
helyi kereső és gráf fölött.

Lehetséges scope-ok:

- teljes tudásbázis;
- kiválasztott Jegyzet;
- kiválasztott forrás;
- kiválasztott chunkok;
- aktuálisan megnyitott tartalom.

Gyors lekérdezési célok lehetnek az összefoglalás, kapcsolódó tudáselemek,
kulcsfogalmak, forrás-összehasonlítás, ellentmondások, hiányzó információk,
eljárási lépések vagy tanulókérdések keresése.

A válaszkártyának a válasz mellett a felhasznált chunkokat,
forráshivatkozásokat, PDF-oldalszámokat, validációs figyelmeztetést és
kapcsolódó kérdéseket is meg kell mutatnia. A forráshivatkozás visszavezet az
eredeti chunkhoz, Jegyzet-környezethez vagy PDF-oldalhoz.

Online módban a modell összefüggő választ fogalmaz. Offline módban a rendszer
strukturált találatokat, logikai kapcsolatokat és forráslistát ad. A két mód
nem használ külön tudásbázist.

## Pontosan két chunktípus

### Közös absztrakt Chunk

A kanonikus domain modell:

```text
Chunk
├─ id
├─ kind = note_chunk | flowchart_chunk
├─ creationMethod
├─ validationState
├─ source
├─ createdAt / updatedAt
└─ content
```

Engedélyezett létrehozási módok:

| Érték | Jelentés |
| --- | --- |
| `manual_selection` | A felhasználó határozta meg a kezdeti tartományt vagy hozta létre a tartalmat. |
| `assisted_selection` | A rendszer PDF-szövegréteggel, OCR-rel vagy szerkezeti segítséggel támogatta a kijelölést. |
| `ai_generated` | Az AI állította elő a kezdeti chunkjavaslatot. |
| `imported` | Külső vagy régi Djinn-csomagból érkezett. |

Ezek provenance értékek. Az AI által készített Jegyzetchunk és a kézzel írt
Jegyzetchunk ugyanabban a store-ban, ugyanazzal a szerkezettel és ugyanabban az
editorban él.

### Jegyzetchunk

A `note_chunk` egy rich-content konténer. Rendezett szekciói lehetnek:

- bekezdés vagy címsor;
- dinamikus vagy statikus lista;
- táblázat;
- ezek tetszőleges sorrendű kombinációja.

Megőrzi a szövegformázást, behúzást, címsorszintet, listaállapotot,
táblázatméretet, tageket, keresési metaadatot és a felhasználói kitöltéseket.
Az örökölt `text`, `paragraph`, `heading`, `list`, `table`, `mixed`, `score`,
`image_region` és hasonló értékek csak migrációs bemenetek. Betöltéskor
`note_chunk` lesz belőlük, a lista- vagy táblázatszerkezet elvesztése nélkül.

### Flowchart chunk

A `flowchart_chunk` egy teljes folyamatábra egyetlen tudáselemként. Tartalmazza:

- stabil node- és élazonosítókat;
- node-feliratokat, alakzatot, pozíciót és sorrendet;
- élek forrás- és cél-node-ját, feliratát és sorrendjét;
- címkéket, kitöltéseket, validációt és forrásmetaadatot.

A régi flowchart node/edge sorok az általános gráf belső részei és legacy
tárolási kompatibilitási elemei; a felhasználói chunklistában egyetlen
Flowchart chunk jelenik meg.

## Egységes editor és kártya

Minden nem-flowchart legacy tartalom a közös rich Jegyzetchunk editorban nyílik
meg. A paragraph/list/table választás szerkesztési szerkezet, nem új objektum.
A flowchartok a közös Flowchart editorban nyílnak meg. A Jegyzet- és
PDF-scope ugyanazokat az editorokat használja.

Egy chunkkártya:

- a kanonikus típust és tartalmi előnézetet mutatja;
- kinyitható és szerkesztőbe nyitható;
- validációs és opcionális eredetjelölést mutat;
- a jobb felső sarokban egyetlen színes badge-ben jelzi az egyedi tagek
  darabszámát;
- nem festi ki automatikusan a tartalmat a tag színével.

## Tagek és kézi Kitöltés

A tagek strukturális keresési és csoportosítási metaadatok. Ugyanaz a tag
registry és tagkezelő sheet szolgálja ki a Jegyzetchunkot és a Flowchart
chunkot. A chunk-, range-, listaelem-, táblázatcella-, node- és élcímkék
egyedi darabszáma beleszámít a kártya badge-ébe.

A tag és a vizuális kiemelés két külön fogalom:

- a tag nem állít automatikus szöveg- vagy háttérszínt;
- a **Kitöltés** a felhasználó explicit rich-text formázása;
- a billentyűzet feletti railen a kijelölt szövegrész háttere beállítható,
  más színre módosítható vagy törölhető;
- a kitöltési range a szöveggel együtt perzisztál;
- ugyanez a modell működik bekezdésben, listaelemben, táblázatcellában,
  flowchart-node és flowchart-él szerkeszthető feliratában.

## PDF-kivonás és chunkkészítés

### Jelenlegi kompatibilis workflow

A refaktor nem szünteti meg a már működő PDF-feldolgozási útvonalakat:

- kézi PDF-terület kijelölése;
- PDF-szövegréteg és helyi OCR;
- lokális táblázat- és flowchart-felismerés;
- AI-alapú dokumentumkinyerés;
- kinyert tartalom szerkesztése és validálása.

A kézi szerkesztő első szintjén csak **Jegyzetchunk** és **Flowchart chunk**
választható. Jegyzetchunknál egy második, szerkezeti lépésben választható
szabad szöveg, lista vagy táblázat. Mentéskor ezek mind ugyanazt a
`note_chunk` modellt írják.

### Egységes célfolyamat

A végleges termékben a PDF **Chunkolás** művelete három automatizálási
belépési módot ad:

1. **Kézi kijelölés**
2. **Asszisztált kijelölés**
3. **Automatikus feldolgozás**

Mindhárom ugyanabba az editorba, ugyanabba a két `ChunkKind` egyikébe és
ugyanabba a validációs folyamatba érkezik. A különbség csak az, hogy a
forrásterületet és a chunkhatárt a felhasználó, a rendszer segítséggel vagy az
AI határozza meg.

### Chunk Studio – következő fázis

A teljes Chunk Studio még külön fejlesztési egység. A tervezett mobil
munkafelület nézetei:

| Nézet | Feladat |
| --- | --- |
| Dokumentum | PDF-preview, zoom, oldalléptetés, területkijelölés és chunk-overlay |
| Chunkok | javaslatok, mentett chunkok, egyesítés, szétválasztás és szerkesztés |
| Ellenőrzés | bizonytalan, OCR-hibás vagy jóváhagyásra váró elemek |
| Feldolgozás | automatikus futtatások, tartomány, cél, részletesség és munkamenetek |

Az automatikus feldolgozás konfigurációja tartományt, chunkolási célt,
részletességet és mentési módot választ. Az AI-javaslatok alapértelmezésben
ellenőrző felületre kerülnek. A folyamat a felhasználónak ellenőrizhető
állapotokat mutat, nem a modell belső gondolatmenetét.

## Chunk-export és import

### Kanonikus JSON schema v2

Az adatvesztésmentes export minden eleme csak ezt írhatja:

```text
kind = note_chunk | flowchart_chunk
```

Egy exportált elem tartalmazza:

- a teljes szerkeszthető rich-content vagy flowchart struktúrát;
- a plain-text keresési reprezentációt;
- `creationMethod` és validációs állapot;
- tagek és kézi kitöltési range-ek;
- opcionális forrástípus, forrásazonosító, oldal-/oldaltartomány,
  forrásterület és eredeti kivont szöveg;
- az embeddinget és modellmetaadatot, ha rendelkezésre áll.

Az export sheet alapjai:

- scope: aktuális chunk, kijelölt chunkok, aktuális Jegyzet vagy aktuális
  PDF-forrás;
- pontosan két típuskártya és darabszám;
- forrásmetaadatok be- vagy kikapcsolása;
- schema v2 előnézet;
- JSON export.

A megnyitott Jegyzet hárompontos menüjében a **Chunk export (JSON)**, a PDF
chunknézet appbarjában és kijelölési menüjében a **Chunk export** érhető el.
A vizuális Jegyzet → PDF export ettől külön művelet marad.

Az új export nem írhat `text`, `list`, `table`, `mixed`, `score`, külön
AI-chunk vagy user-chunk típust. A legacy schema v1 és korábbi többtípusú
csomagok importálhatók; a betöltő azokat a két kanonikus típusra migrálja.

## Helyi adattárolás

### ObjectBox mint elsődleges store

Az Android alkalmazás az app saját tárhelyén ObjectBox adatbázist használ.
A PDF-ek app-private másolatként maradnak a készüléken. Az API-kulcsok nem az
ObjectBoxban, hanem `flutter_secure_storage` alatt vannak.

A fizikailag UID-stabil `DocumentChunkEntity` a közös, globális Chunk-tábla.
A név egy kompatibilitási ablakban megmarad, de a szemantikája már nem
PDF-specifikus. A kanonikus mezők:

- globális `publicId`;
- `chunkKind`;
- `creationMethod`;
- validáció;
- szerkeszthető strukturált content JSON;
- plain text és változatlan eredeti szöveg;
- tagek;
- forrásdokumentum, oldal, oldaltartomány és terület;
- létrehozási és módosítási idő.

A Jegyzetek külön `NoteEntity` gyűjtők. A `ChunkNoteLinkEntity` explicit M:N
kapcsolatot tárol Jegyzet és Chunk között, sorrenddel és hozzáadási idővel.
Determinista linkazonosító teszi idempotenssé a Jegyzetbe küldést.

```text
NoteEntity ──< ChunkNoteLinkEntity >── DocumentChunkEntity
                                         │
                                         ├─ ChunkEmbeddingEntity
                                         ├─ KnowledgeEvidenceEntity
                                         └─ forrásdokumentum/metaadat
```

### Adatmegőrző migráció

- A régi ObjectBox `DocumentChunkEntity` entity- és property UID-k megmaradnak.
- Induláskor az örökölt chunk wire-értékek idempotensen kanonizálódnak.
- A kapcsolódó audit- és chunkból származó tudásgráf-node típus is
  `note_chunk` vagy `flowchart_chunk` lesz.
- A régi flowchartokhoz egyetlen szülő Flowchart chunk készül.
- A korábbi `notes.json` egyszer, tranzakcióban importálódik ObjectBoxba.
- A migráció csak sikeres ellenőrzés után ír tartós markert.
- A legacy JSON-fájl helyreállítási forrásként megmarad; nem törlődik.

## A vektoros tudásgráf konkrét megvalósítása

### Reprezentációs rétegek

A Djinn ugyanazt a tudást több, egymást kiegészítő rétegben tárolja:

1. **Chunk content** – az olvasható és szerkeszthető tudáselem.
2. **Keresési metaadat** – cím, szekció, tagek, aliasok, szerep és
   normalizálható kulcsszavak.
3. **Embedding** – a chunk jelentésének 3072 dimenziós floatvektora.
4. **Knowledge node** – kereshető fogalmi vagy chunkszintű gráfcsomópont.
5. **Knowledge edge** – irányított, típusos és súlyozható logikai kapcsolat.
6. **Evidence** – a kapcsolatot vagy node-ot az eredeti chunkhoz, mondathoz és
   oldalhoz visszakötő bizonyíték.

Az ObjectBox `ChunkEmbeddingEntity.vector` mezőjén HNSW-index működik
3072 dimenzióval és koszinusz-távolsággal. A keresés ezért nem hasonlít össze
minden chunkot minden másikkal; a közelítő index gyorsan ad szemantikailag
közeli jelölteket.

### Hogyan kapcsolódnak a kulcsszavak, mondatok és jegyzetrészek?

#### 1. Explicit szerkezeti kapcsolatok

A forrás és a felhasználói műveletek determinisztikus kapcsolatokat adnak:

- Jegyzet–Chunk tagság;
- dokumentum–Chunk forráshivatkozás;
- chunk–szekció `part_of` él;
- dokumentumsorrendből származó `continues` él;
- flowchart node-ok közötti irányított folyamatél;
- kézzel létrehozott vagy jóváhagyott kapcsolat.

Ezekhez nem kell AI, és nem függnek a megfogalmazás hasonlóságától.

#### 2. Lexikai és metaadat-kapcsolatok

A tagek, aliasok, normalizált címkék, keresési szerepek, szekciócímek és
kulcsszavak szó szerinti vagy normalizált egyezést adnak. A helyi offline
kereső ezekből súlyozott találatot épít. Ez köti össze például egy rövidítést
annak teljes alakjával vagy két, azonos taggel jelölt jegyzetrészt.

#### 3. Szemantikai vektorközelség

A mondatok és chunkok embeddingjei a jelentésbeli közelséget kódolják. A
kérdés is embeddinget kap, majd az ObjectBox HNSW top találatokat keres. Így
eltérő szavakkal megfogalmazott, de azonos jelentésű részek is egymás mellé
kerülhetnek.

A vektorközelség önmagában jelölt kapcsolat, nem bizonyított logikai állítás.
Nem jelenti automatikusan, hogy két chunk alátámasztja vagy cáfolja egymást.

#### 4. Gráfbővítés

A vektoros vagy kulcsszavas seed találatok után a helyi retriever a
`KnowledgeEdgeEntity` kapcsolatok mentén kontrolláltan hozzáad kapcsolódó
evidence-elemeket. Így egy jó szemantikus találat mellé bekerülhet a
szekciókörnyezete, előző/következő része, kapcsolódó flowchartlépése vagy más
explicit tudáselem.

A bővítés limitált, deduplikált, validáció- és forrástudatos. Elutasított
chunk vagy flowchart-elem nem kerülhet válaszforrásba.

#### 5. Magasabb szintű logikai élek

A gráf általános `relationType` mezője később többek között `same_concept`,
`supports`, `contradicts`, `depends_on`, `causes` és hasonló kapcsolatokat is
kezelhet. Ezeket determinisztikus szabály, felhasználói művelet vagy opcionális
AI-javaslat hozhatja létre, de a kapcsolatnak evidence-et és validációs
állapotot kell kapnia.

Az automatikus, általános állítás- és ellentmondásfelismerés még nem teljes
termékfunkció. A jelenlegi implementáció biztosan kezeli a forrás-, tagsági-,
szekció-, sorrend- és flowchartkapcsolatokat, valamint a vektoros és hibrid
visszakeresést.

### Lekérdezési folyamat

```text
Kérdés
  → normalizálás / opcionális embedding
  → kulcsszavas, vektoros vagy hibrid seed találatok
  → minimum hasonlósági és validációs szűrés
  → limitált gráfbővítés
  → deduplikált evidence-csomag
  → strukturált offline eredmény vagy AI által megfogalmazott válasz
  → kliensoldali hivatkozás-ellenőrzés
  → opcionális groundedness-ellenőrzés
```

A válaszmodell csak a visszakeresett helyi evidence-et kapja, nem a teljes
adatbázist és nem automatikus internetes keresést. A kliens ellenőrzi, hogy a
modell által hivatkozott azonosítók valóban a visszakeresett elemek között
vannak-e. Elégtelen forrás, hibás hivatkozás vagy sikertelen
groundedness-ellenőrzés esetén a rendszer fail-closed módon elutasíthatja a
választ.

## Flowchartok

A Flowchart chunk egyszerre szerkeszthető vizuális tartalom és explicit gráf.
A node-ok és élek stabil azonosítókat, sorrendet, pozíciót és validációt
kapnak. A `flow_to` jellegű irány megmondja, melyik lépésből melyik következik,
ezért a folyamat nem csak képként, hanem bejárható logikaként is használható.

A szerkesztő node- és élcímkéket, alakzatokat, pozíciót, kapcsolatokat, tageket
és kézi kitöltéseket kezel. Az örökölt külön node/edge ObjectBox sorok a
folyamatgráf részletei; a chunklistában a teljes ábra egy kártya.

## AI-szolgáltatók, offline mód és adatvédelem

Djinn local-first, de nem minden feldolgozás offline:

- a Jegyzetek, dokumentumok, chunkok, vektorok, gráf és chatelőzmények
  elsődlegesen a készüléken maradnak;
- a helyi PDF-szöveg/OCR, offline kulcsszavas és lokális vektorkeresés nem
  igényel külső szervert;
- AI-feldolgozáskor a kiválasztott dokumentum vagy releváns chunkok a választott
  szolgáltatóhoz kerülhetnek;
- az app közvetlen kliensadapterrel támogat OpenAI- és Gemini-szolgáltatót;
- a szolgáltatónkénti API-kulcsok a platform biztonságos tárában maradnak;
- a felületnek meg kell különböztetnie a teljesen helyi és külső AI-hívást
  használó műveleteket.

A létrehozási szolgáltató vagy modell nem chunktípus. Szolgáltatóváltás után is
ugyanaz a globális Chunk és ugyanaz a forráskapcsolat marad.

## Opcionális backend

A `backend/` külön FastAPI-alapú szerveres prototípus. Qdrantot,
PostgreSQL-t, LangGraph válaszfolyamot és NeMo Guardrails ellenőrzést tud
használni. A Flutter Android alkalmazás elsődleges local-first útvonala nem
vált automatikusan erre a backendre, és a backend leírása nem írja felül a
kanonikus Chunk modellt.

A szerveres futtatás részletei a `backend/README.md` történeti/üzemeltetési
leírásában vannak.

## Megvalósítási állapot

| Terület | Állapot ebben a kódbázisban |
| --- | --- |
| Jegyzetek, mappasáv, kártyák, FAB, kijelölési menü | Működik; a meglévő UX megmaradt. |
| Globális két-típusú Chunk domain | Megvalósítva. |
| ObjectBox Jegyzet-, mappa- és Chunk–Jegyzet kapcsolati háttér | Megvalósítva. |
| Legacy note/chunktípus migráció | Megvalósítva, idempotens és adatmegőrző. |
| Egységes rich Jegyzetchunk editor | Megvalósítva. |
| Flowchart chunk editor | Megvalósítva. |
| Közös tag badge, tagfüggetlen Kitöltés | Megvalósítva mindkét típusra. |
| Egyesített PDF chunklista | Megvalósítva; nincs AI/manuális tab. |
| PDF chunk → Jegyzet kapcsolat | Megvalósítva long-press kijelöléssel. |
| Chunk JSON schema v2 export/import | Megvalósítva; két kanonikus típus. |
| PDF-import, kézi, helyi OCR és AI-feldolgozási útvonalak | Meglévő workflow-k megmaradtak. |
| ObjectBox HNSW, offline/kulcsszavas/hibrid keresés és gráfbővítés | Működő helyi infrastruktúra. |
| OpenAI és Gemini kliensadapter | Megvalósítva; modellképességtől függő korlátokkal. |
| Általános automatikus fogalom-, supports- és contradiction-gráf | Részleges infrastruktúra; további fejlesztés. |
| Teljes Chunk Studio és feldolgozási munkamenetek | Következő külön refaktorfázis. |
| Minden scope-ra kész Kérdezz eredménykártya | Fokozatosan fejlesztendő. |

Az aktuális refaktor tételes, bizonyítékhoz kötött készültségi állapota a
`REFACTOR_JEGYZET.md` checklistjében található. A fenti „Megvalósítva” sorok
csak akkor véglegesek, ha a checklist ellenőrzése és a teljes tesztfutás zöld.

## Projektstruktúra

```text
lib/
  main.dart                  Android alkalmazásindítás és dependency wiring
  src/chunks/                Kanonikus Chunk domain és ObjectBox codec
  src/notes/                 Jegyzetek, M:N chunkkapcsolat, rich editor és PDF-export
  src/knowledge/             Forrásimport, PDF/OCR/AI feldolgozás és PDF chunk UI
  src/local_store/           ObjectBox entitások és store-nyitás
  src/rag/                   Vektoros, offline és hibrid retrieval, hivatkozás-ellenőrzés
  src/search/                Keresési felület
  src/flowchart/             Flowchart modellek, validáció és szerkesztők
  src/chat/                  Kérdezz/Chat munkamenetek és válasz UI
  src/ai/, src/openai/,
  src/google/                Providerfüggetlen AI-szerződés, OpenAI és Gemini
  src/settings/              Beállítások és biztonságos API-kulcskezelés
  src/shared/chunks/         Közös chunkkártya, drag handle és export sheet
  src/debug/                 Alkalmazáson belüli diagnosztika
backend/                     Opcionális FastAPI/Qdrant/PostgreSQL prototípus
test/                        Flutter unit-, repository- és widgettesztek
docs/superpowers/README.md   Index a két kanonikus dokumentumhoz
.github/workflows/           Online Android build
```

## Fejlesztés és ellenőrzés

A fejlesztési célplatform Android. Termux/Android ARM64 alatt a
Termux-host Flutter/Dart bináris TLS-alignment hibába futhat, ezért az elemzés
és a teszt Ubuntu prootban fusson:

```bash
proot-distro login ubuntu -- bash -lc \
  'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && \
   /home/flutteruser/flutter/bin/flutter pub get && \
   /home/flutteruser/flutter/bin/flutter analyze && \
   /home/flutteruser/flutter/bin/flutter test'
```

Helyi APK-build ezen a telefonos ARM64/Termux környezeten nem támogatott. Az
APK-t a `.github/workflows/android-native-build.yml` GitHub Actions workflow
építi. A tesztek injektált fake klienseket használnak, és alapértelmezésben nem
indítanak élő AI-hívást.

## Dokumentációs szabály

- Általános termék-, navigációs, adatmodell- és architektúradöntés ebbe a
  README-be kerül.
- Az aktuális nagy refaktor végrehajtási követelménye a
  `REFACTOR_JEGYZET.md` stabil azonosítójú checklistjébe kerül.
- Dátumozott terv csak végrehajtási segédlet lehet; nem lehet új párhuzamos
  source of truth.
- Régi tervben szereplő 3, 4 vagy 5 chunktípus, AI/manuális külön lista vagy
  tagvezérelt tartalomszínezés kifejezetten felülírt döntés.
- Új termékdöntés csak explicit felhasználói utasítással módosíthatja ezt a
  dokumentumot.
