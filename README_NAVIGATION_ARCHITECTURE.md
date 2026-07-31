# Djinn – Tudásnavigációs architektúra

> Ez a dokumentum a Djinn továbbfejlesztett, célállapotbeli architektúráját írja le. A korábbi [README_OLD.md](README_OLD.md) történeti háttérként megmarad; ez a leírás a tudásnavigációs modell kanonikus jövőképét rögzíti.

## Áttekintés

A Djinn nem hagyományos jegyzetalkalmazás és nem klasszikus chatbot. Egy helyi tudásrendszer, amelyben a felhasználó Jegyzeteket ír, PDF-eket, képeket és más forrásokat importál. Ezekből a rendszer automatikusan bejárható tudáshálót épít.

A rendszer elsődleges célja nem a dokumentumok tárolása, hanem hogy a felhasználó gyorsan eljusson a számára releváns tudáselemekhez.

## Alapelv

A Djinn három, egymástól elkülönülő rétegből áll:

```text
Felhasználói tartalom
        ↓
Keresési index
        ↓
Navigation Graph
```

- A felhasználó tartalmat hoz létre és szerkeszt.
- A rendszer ebből belső Chunkokat, Atomokat és keresési indexeket készít.
- A Navigation Graph azt rögzíti, hogy egy tudáselemtől mely másik tudáselemek felé érdemes továbblépni.

## Jegyzetmodell és AI-feldolgozás

### Alapelv

A Djinnben a felhasználó elsődleges tudásegysége a **Jegyzet**, nem a Chunk. Minden szerkeszthető tartalom jegyzetként jelenik meg, függetlenül attól, hogyan jött létre.

Egy Jegyzet lehet:

- kézzel írt saját jegyzet;
- PDF-ből létrehozott jegyzet;
- AI által létrehozott jegyzet;
- teljes összefoglaló dokumentum;
- néhány soros megjegyzés;
- akár teljes tankönyvfejezet.

A rendszer nem korlátozza a Jegyzet méretét vagy szerkezetét. A kicsi és a nagy Jegyzet egyenrangú: ugyanúgy szerkeszthető, kereshető és hivatkozható.

```text
Jegyzet: DO2 definíció

ugyanolyan elsőrangú objektum, mint

Jegyzet: Légzési elégtelenség
  - definíció
  - típusok
  - ARDS
  - DO2 és VO2
  - NIV és intubáció
  - kezelés és összefoglalás
```

A felhasználó Témákat használ mappaként: ezek jegyzeteket és a Tudástárból hozzájuk kapcsolt tartalmakat gyűjtenek. A felhasználó nem épít gráfot és nem kezel belső keresési egységeket.

### A Chunk fogalmának szerepe

A korábbi architektúrában a Chunk látható felhasználói tudásegység volt. Az új modellben a Chunk fogalma kikerül a felhasználói felületről: a felhasználó kizárólag Jegyzetekkel dolgozik.

A `chunk` technikai, belső feldolgozási kifejezés marad. Nem önálló üzleti objektum, nem dokumentum és nem olyan elem, amelyet a felhasználó külön létrehozhatna, szerkeszthetne vagy listában láthatna.

### Belső AI-feldolgozás: Szekciók és Chunkok

A Jegyzet strukturált dokumentum. A felhasználó számára a **Szekció** a logikai szerkesztési egység, a **Chunk** pedig a motor belső indexelési egysége.

```text
Jegyzet
├── Szekció
│     └── belső Chunk
├── Szekció
│     └── belső Chunk
├── Szekció
│     └── belső Chunk
└── Szekció
      └── belső Chunk
```

Sok esetben egy Szekció és egy belső Chunk 1:1 kapcsolatban van, de ez nem kötelező. Egy hosszú Szekció több Chunkra bontható, míg egy rövid Szekció önmagában egyetlen Chunkot adhat.

Példa egy szerkeszthető Jegyzetre:

```markdown
# Definíció

...

# DO2

...

# VO2

...

# ARDS

...

# Kezelés
```

A motor ebből automatikusan külön belső Chunkokat képezhet a Definíció, DO2, VO2, ARDS és Kezelés Szekciókhoz. A felhasználónak semmilyen külön objektumot nem kell létrehoznia.

Nem kötelező a címsor sem. A szekcionálás determinisztikus szabályai lehetnek például:

```text
Új H1                 → új Szekció és Chunk
Új H2                 → új Szekció és Chunk
Hosszú új bekezdés    → szükség esetén új Chunk
Üres sor              → új Szekció
```

Jegyzet mentésekor a Djinn automatikusan feldolgozza a Szekciókat:

```text
Jegyzet
  ↓
Szekciók
  ↓
Chunkok
  ↓
Atomok
  ↓
Embedding
  ↓
Navigation Graph
```

A belső Chunk nem üzleti objektum, nem dokumentum, nem Jegyzet és nem fájl. Kizárólag az alábbi feladatokat szolgálja:

- a Jegyzet szerkezetének és a részleges frissítés határának meghatározása;
- Atomok kinyerése;
- AI-kontekstus előállítása;
- részleges, gyors újraindexelés.

Az Atom a Chunkokból kinyert, önálló belső tudáselem. A Navigation Graph csomópontjai Atomok, nem Chunkok. Sem a Chunk, sem az Atom nem jelenik meg önálló szerkeszthető objektumként a felhasználói felületen.

### Lokális, részleges frissítés

A Szekció–Chunk modell szerkesztéskor nem indexeli újra szükségtelenül a teljes Jegyzetet. Ha a felhasználó csak a `# DO2` Szekciót módosítja, akkor csak az ahhoz tartozó belső Chunkból kinyert Atomok, embeddingjeik és gráfkapcsolataik frissülnek.

Ez gyorsabb indexelést ad nagy összefoglaló Jegyzeteknél, miközben a felhasználó végig dokumentumszerű szerkesztőben dolgozik. A manuális chunkolás így természetes dokumentumszerkesztéssé válik: a felhasználó új címsort, Szekciót vagy blokkot készít, a rendszer pedig automatikusan létrehozza vagy frissíti a szükséges belső Chunkot.

### Offline működés

A Djinn AI nélkül is működik. A helyi GraphRAG-folyamat változatlan marad:

```text
Jegyzet
  ↓
Szekciók
  ↓
Chunkok
  ↓
Atomok
  ↓
Embedding
  ↓
HNSW
  ↓
Kapcsolódó Atomok
  ↓
Navigation Graph
```

Offline, navigációra használható jelöltek például az ugyanazon Jegyzethez vagy Szekcióhoz tartozó Atomok, közös tagok, közös kulcsszavak és embedding-hasonlóság. Ez megtartja az atom→atom kaszkádot, a nagy összefoglaló Jegyzeteket, a manuális kijelölést és az egyszerű felhasználói modellt.

### Manuális chunkolás: manuális Jegyzet-létrehozás

A manuális chunkolás funkció megmarad, de új jelentést kap. Korábban:

```text
PDF → Chunk
```

Az új modellben a felhasználó PDF-részletet jelöl ki, amelyből a rendszer önálló, szerkeszthető Jegyzetet készít:

```text
ARDS.pdf → Berlin kritériumok → Jegyzet
ARDS.pdf → PEEP              → Jegyzet
```

Minden kijelölt rész külön Jegyzetként tárolódik, és teljesen egyenrangú a kézzel írt vagy AI által létrehozott Jegyzetekkel.

### PDF-feldolgozási módok

#### 1. Automatikus

A PDF kizárólag AI-indexelésre kerül feldolgozásra:

```text
PDF → belső Chunkok → Atomok → Embedding → Navigation Graph
```

Ebben a módban nem jön létre külön Jegyzet; ez a leggyorsabb feldolgozási út.

#### 2. Félautomata

Az AI javaslatot tesz a dokumentum logikai felosztására. A felhasználó jóváhagyhatja vagy módosíthatja a javasolt részeket; minden elfogadott rész önálló Jegyzetté válik.

#### 3. Manuális

A felhasználó maga jelöl ki tetszőleges szövegrészeket. Minden kijelölés külön, szerkeszthető Jegyzetként tárolódik.

### Miért előnyös ez a modell?

Az architektúra teljesen elválasztja a felhasználói modellt az AI működésétől. A felhasználó fájlokat tölt fel, Jegyzeteket ír és Jegyzeteket szerkeszt. A rendszer ezzel párhuzamosan automatikusan Szekciókra és belső Chunkokra bontja a tartalmat, Atomokat nyer ki, embeddingeket készít, Navigation Graphot épít, összefüggéseket keres és természetes nyelvű válaszokat állít elő.

Így a felhasználónak nem kell ismernie a belső Chunkok, Atomok vagy embeddingek működését: ezek a Djinn belső infrastruktúrájának részei, miközben a felhasználói élmény egységes, Jegyzet-központú tudásrendszer marad.

## Atom Graph adatmodell

### Áttekintés

A Djinn tudásgráfjának alapegysége az **Atom**. Az Atom önálló tudáselem, amely a felhasználó Jegyzeteiből és dokumentumaiból kerül kinyerésre.

A rendszer nem használ doménspecifikus típusrendszert vagy ontológiát. Minden csomópont egységesen Atom.

### Atom

```text
Atom
---------
id
title
content
embedding
createdAt
updatedAt
```

Az Atom nem tárol típust vagy kategóriát.

### Strukturális kapcsolatok

Egy Atom több Chunkban, Jegyzetben és Témában is előfordulhat. Ezek több-a-többhöz kapcsolatok.

```text
Atom → Chunk

AtomChunk
---------
atomId
chunkId
```

```text
Atom → Jegyzet

AtomNote
--------
atomId
noteId
```

```text
Atom → Téma

AtomTopic
---------
atomId
topicId
```

### Atom → Atom kapcsolat

A tudásgráf élei két Atom között jönnek létre:

```text
AtomEdge
--------
sourceAtomId
targetAtomId
weight                  ← normalizált, strukturális bizonyíték-súly
```

Az Edge nem rendelkezik relációtípussal. Nem léteznek például `causes`, `defines`, `treats` vagy `depends_on` típusok. A gráf Atomokból és relációtípus nélküli kapcsolatokból áll; a végleges clusteringben a `weight` normalizált strukturális bizonyítéksúly.

### Weight

A `weight` nem szemantikai fontosság, hanem strukturális bizonyíték. Azt fejezi ki, hogy mennyire erős bizonyíték van a Djinn saját tudásbázisában arra, hogy két Atom összetartozik.

A `weight` kizárólag a tudásbázis szerkezetéből számolódik. Nem befolyásolja, hogy az egyik Atom definíció vagy kezelés, szakmailag fontosabb-e, illetve nem használ semmilyen ontológiai relációt.

#### A weight forrásai

A kapcsolat erősségét kizárólag forrás- és dokumentumstruktúrából származó bizonyítékok határozzák meg: azonos mondat vagy táblázatsor, azonos bekezdés vagy blokk, azonos Chunk, szomszédos Chunkok közös Szekció alatt, illetve közös dokumentum- vagy Szekciócím-kontextus. Pusztán azonos Jegyzet vagy Téma nem elegendő él létrehozásához.

A rendszer nem próbál szakmai vagy szemantikai fontosságot meghatározni. Több külön Chunk vagy független forrás azonos kapcsolatot bizonyítva növelheti a súlyt.

#### Mire használható?

A `weight` a gráf fontos bemeneti adata lehet. Felhasználható:

- az Atom–Atom kapcsolat erősségének tárolására;
- community detection algoritmusok bemeneteként;
- a node fontosságának, például weighted degree értékének számítására;
- az élek vizuális hangsúlyozására.

Így a gráf teljes viselkedése a felhasználó saját dokumentumszerkezetéből épül fel, nem egy előre definiált tudásmodellből.

#### Determinisztikus számítás

A nyers kontextuspontokat össze kell adni, a több Chunkból és független forrásból származó bizonyítékot korlátozottan összegezni, majd gyakorisági korrekcióval és rögzített normalizálással 0–1 közé képezni. A pontos képlet, küszöbök és algoritmusverzió a clusterverzió része; nem tartalmazhat runtime random értéket.

#### Bevezetési stratégia

Diagnosztikai vagy nagyon korai prototípusban a gráf átmenetileg lehet súly nélküli:

```text
AtomEdge
--------
sourceAtomId
targetAtomId
```

A súly nélküli AtomEdge létezése már önmagában strukturális kapcsolatot jelez, de ez nem elegendő a végleges Surface Cap képzéséhez. A production clustering súlyozott gráfot és determinisztikus Leiden-futtatást használ.

A végleges Surface Cap képzésben a normalizált `weight` kötelező bemenet. Súly nélküli gráf csak diagnosztikai vagy korai prototípus-fallback lehet; a production community-tagság nem épülhet kizárólag az AtomEdge létezésére.

### Alapelvek

- Az Atom a tudás legkisebb önálló egysége.
- Egy Atom több Chunkhoz, Jegyzethez és Témához is tartozhat.
- A gráf nem ontológia.
- A kapcsolatok nem rendelkeznek relációtípussal.
- Ha használunk `weight` mezőt, azt kizárólag a dokumentumstruktúrából származó bizonyíték határozza meg.
- A vizualizáció és a megjelenítés nem része az adatmodellnek.

### Kompakt elemszám-megjelenítés

Az elemszámok a tárolt adatmodellben mindig pontos egész számok maradnak. A felületen azonban ugyanazt a determinisztikus, kerekített formázót kell használni mindenhol, mert az Explore és a tudásgráf akár több millió atomot vagy kapcsolatot is tartalmazhat.

| Pontos érték | Megjelenítés |
| ---: | --- |
| `0–999` | `999` |
| `1 000–99 999` | `1,2 ezer`, `12 ezer` |
| `100 000–999 999` | `123 ezer` |
| `1 000 000–999 999 999` | `1,2 M`, `123 M` |
| `1 000 000 000` fölött | `1,2 Md`, `123 Md` |

A rövid forma legfeljebb három jelentős számjegyet használ, és mindig kerekít:

```text
123456      → 123 ezer
1234567     → 1,2 M
123456789   → 123 M
1234567890  → 1,2 Md
```

Kerekítés után a következő egységre kell lépni: `999 500` már `1 M`, nem `1000 ezer`. Ugyanazt a formázót kell használni a galaxis- és bolygóstatisztikákban, kártyákon, listákban, tooltipben és akadálymentes feliratokban. A rövid érték koppintással, hoverrel vagy részletező nézetben mindig egészítse ki a pontos, ezres csoportosítású értékkel, például `1 234 567 atom`.

## Két külön clustering-szint

A végleges tudáshierarchia:

```text
Galaxis → Bolygó → Atom → Street View
```

A **bolygó** valódi, tartós szemantikai cluster. Egy Atom egy adott clusterverzióban pontosan egy bolygóhoz tartozik. A bolygón belüli **Community Cap** ezzel szemben nem új tudáshierarchiai szint: csak lokális, újraszámítható renderelési segédstruktúra, amely a felszíni elrendezést olvashatóvá teszi.

### 1. Szemantikai cluster: ebből lesz a bolygó

A bolygót nem a bolygón elfoglalt hely, nem a Jegyzet címe és nem az Atom embeddingje határozza meg közvetlenül. A teljes, körülbelül 700 Atomot tartalmazó normalizált és súlyozott kapcsolati gráf alapján azok az Atomok kerülnek egy bolygóra, amelyek egymás között összességében erősebben kapcsolódnak, mint a bolygón kívüli Atomokhoz.

#### Globális normalizált Atom és előfordulás

Egy fogalom csak egyszer létezik globális Atomként. Ha az „oxigén” több fizikai, kémiai és egészségügyi Jegyzetben szerepel, ezek az előfordulások ugyanarra az Oxigén Atomra hivatkoznak; a Jegyzet, a Szekció és a belső Chunk bizonyítékot ad, nem birtokolja és nem duplikálja az Atomot.

A normalizálás determinisztikus előkészítő lépése lehet a kis- és nagybetűk, Unicode- és ékezetek, alsó indexek (`PaO₂` és `PaO2`), rövidítések és felhasználó által jóváhagyott aliasok egységesítése. Bizonytalan egyezést a rendszer nem vonhat össze automatikusan.

#### Forrásalapú élsúly

Az Atom-párok nyers együttállási pontjai:

| Közös kontextus | Nyers pont |
| --- | ---: |
| Azonos mondat vagy táblázatsor | `1,0` |
| Azonos bekezdés vagy blokk | `0,7` |
| Azonos Chunk | `0,4` |
| Szomszédos Chunkok, azonos Szekció alatt | `0,2` |
| Közös dokumentum- vagy Szekciócím kontextusa | `0,1` |

Csak az, hogy két Atom ugyanabban a dokumentumban szerepel, önmagában nem hoz létre élt. A cím vagy a Szekció kontextushorgony lehet, de nem kapcsolhatja össze automatikusan a dokumentum minden fogalmát. Több külön Chunk vagy független forrás azonos kapcsolatot bizonyítva növeli a súlyt.

#### Gyakorisági korrekció

A „beteg”, „kezelés”, „oxigén” és „vizsgálat” típusú általános Atomok nyers előfordulásszám alapján minden clusterbe behúznák magukat. PPMI-, IDF- vagy más rögzített gyakorisági normalizálás csökkentse ezt a torzítást: az „oxigén”–„beteg” gyakori együttállása kevésbé informatív, mint a ritkább „PaO₂”–„hypoxaemia” kapcsolat.

Az embedding csak jelöltkeresésre használható. Önmagában nem hoz létre AtomEdge-et, nem mondja meg a bolygótagságot és nem határozza meg a `weight` értékét.

#### Gyenge élek szűrése és Leiden

A teljes gráf gyenge éleit a bolygó-clusterezés előtt szűrni kell. Kiinduló szabály lehet Atomonként a legerősebb 8–20 él megtartása, a fontos összefüggő részek, backbone-kapcsolatok és hídkapcsolatok megőrzésével. Ez a **clusterező gráf** szűrése, nem a későbbi vizuális edge-LOD.

Ezután a szűrt, normalizált és súlyozott gráfon determinisztikus Leiden fusson. A cél a nagy belső és a kisebb kifelé vezető összesített súly. Az első, teljes gráfos futás használjon alacsonyabb `resolution` értéket, hogy stabil, nagyobb bolygó-clusterek jöjjenek létre.

Induló megjelenítési célként egy bolygó körülbelül 8–40 Atomot tartalmazhat. Öt Atom alatt a csoport a legerősebb szomszédjához összevonható; 60 Atom fölött magasabb `resolution` értékkel újrafelosztás mérlegelhető. Ezek olvashatósági célok, nem a szemantikai tagság önkényes felülírásai.

Például egy bolygó lehet a `PaO₂`, `SpO₂`, `hypoxaemia`, `oxigenizáció`, `vérgáz` és `oxigénterápia` együttese, ha ezt a forrásolt kapcsolati sűrűség indokolja.

#### Tartós tagság és hídatom

A bolygótagság menthető az ObjectBoxba, stabil bolygóazonosítóval és clusterverzióval. Egy Atom egyszerre csak egy ilyen bolygóhoz tartozhat.

Ha az Oxigén fizikához, kémiához és élettanhoz is kapcsolódik, ahhoz a bolygóhoz kerül, amelyhez a legerősebb normalizált belső affinitása tartozik. A többi bolygó felé vezető élei megmaradnak; az Oxigén hídatomként a saját bolygója peremén jelölhető, de nem duplikálható.

### 2. Community Cap: bolygón belüli vizuális rendezés

Miután a bolygó Atomjai már kiválasztásra kerültek, ugyanazon bolygó belső gráfján második, finomabb felosztás futtatható. Ez hozza létre a Surface Capeket, például mérési fogalmak, állapotok, kezelések vagy légzéstámogatási fogalmak vizuális körzeteit.

A cap:

- nem új bolygó;
- nem új adatmodell-entitás;
- nem új navigációs szint;
- nem tartós szemantikai tagság;
- nem jelenik meg külön képernyőként.

A cap-tagság újraszámítható és a renderelési seed része. Ugyanaz a Leiden algoritmus használható eltérő paraméterrel: a bolygó létrehozásakor alacsonyabb resolution és nagyobb, stabil csoportok; egy bolygón belül magasabb resolution és kisebb, vizuális csoportok.

Egy körülbelül 50 Atomot tartalmazó bolygón 2–4 cap alakulhat ki, vagy a capek egyáltalán nem jelennek meg, ha nincs értelmes vizuális felosztás. A 700 Atomot tartalmazó stresszteszt-bolygón több cap segít a felszín olvashatóságában; a végleges tudástérben azonban a 700 Atom várhatóan több valódi bolygóra oszlik.

### 3. A layout sorrendje

1. A teljes Atom-gráf eldönti, mely Atom melyik valódi bolygóhoz tartozik.
2. A bolygók az aggregált bolygógráfból galaxissá szerveződnek.
3. Egy kiválasztott bolygó belső gráfján opcionális Surface Capek készülnek.
4. A community cap-középpontok és cap-területek csak ezután kerülnek a gömbfelszínre.
5. Az Atomok a saját capjükön belül kapnak stabil vizuális pozíciót.

A gömbön elfoglalt hely nem módosíthatja visszamenőleg a szemantikai bolygótagságot.

### 4. Galaxis-cluster és bolygóközi stabilitás

A bolygók létrejötte után külön aggregált bolygógráf készül:

- egy node egy valódi bolygó;
- egy él két bolygó atomjai közötti keresztkapcsolatok összesített súlya;
- az aggregáció számolja a különböző atompárokat, a független forrásokat és a kapcsolat sokféleségét;
- egyetlen gyakori hídatom nem dominálhatja a bolygóközi súlyt.

Ezen a bolygógráfon is determinisztikus Leiden fusson. A galaxis egy olyan tartósabb csoport, amelyben a bolygók között sok, változatos és forrásolt keresztkapcsolat van. Induló megjelenítési célként egy galaxis körülbelül 3–10 bolygót tartalmazhat; ez megjelenítési cél, nem merev adatmodell-korlát.

A térkép stabilitása érdekében:

- ne fusson teljes újraclusterezés minden új mondat után;
- új Atom először a legerősebb affinitású meglévő bolygóhoz kerüljön;
- teljes újraszámítás jelentős, például körülbelül 5%-os gráfbővüléskor vagy explicit kérésre fusson;
- a régi és új bolygókat tagsági átfedéssel kell párosítani, hogy a stabil azonosító, név és vizuális seed megmaradjon;
- Atom csak akkor kerüljön át másik bolygóba, ha az új affinitása érdemben, például legalább 20%-kal meghaladja a jelenlegi kötődését.

Ez a hiszterézis megakadályozza, hogy egy kisebb új forrás minden alkalommal átrendezze az Explore térképét.

### 5. Explore-bejárás és kapcsolati folyosó

Az **Univerzum** az Explore-ban éppen vizsgált teljes gráf vagy szűrt részhalmazának konténere; nem új, tartós clusterezési szint. A felhasználói bejárás: `Galaxis → Bolygó → Atom → Street View`.

- **Galaxisnézet:** valódi bolygógömbök és az erős, aggregált bolygóközi kapcsolatok látszanak.
- **Bolygónézet:** a kiválasztott valódi bolygó nagyítva jelenik meg az atomjaival, belső éleivel és a fontos külső kapcsolatok hídatom-jelöléseivel. A külső élek nem változnak véletlen, lebegő célpontokká.
- **Atom Street View:** az Atomhoz tartozó releváns előfordulások, pontos mondat- vagy táblázatrészlet, befoglaló Szekció, forrás és oldalszám jelenik meg.
- **Él Street View:** csak azok a bizonyítékok jelennek meg, amelyek a két Atomot közös kontextusban támasztják alá.

A bolygó–bolygó kapcsolat nem statikus információs kártya és nem új hierarchiaszint, hanem ugyanannak a galaxisnak egy kiterjesztett perspektívája. A bolygónézetből induló, tapelhető külső szál mindig a súlyozott gráf tényleges szomszédos bolygójának valódi rootjához csatlakozik. Tap után ugyanabban a Three.js-térben a kamera animáltan csúszik úgy, hogy az eredeti és a valódi szomszédos bolygó együtt látszódjon; a nem releváns atomok és gyenge háttérkapcsolatok elhalványulnak. Nem hozható létre virtuális bolygó vagy lebegő corridor-card.

A külső kapcsolattal rendelkező hídatom finom külső gyűrűt vagy „más bolygóhoz is kapcsolódik” jelölést kaphat. Ennek aktiválása először a célbolygókat és a legerősebb célatomokat mutatja, nem a teljes külső gráfot.

A hídatomról a felhasználó kaszkádban haladhat tovább:

```text
galaxis → bolygó → atom → kapcsolódó bolygó → célatom → Street View-bizonyíték
```

Így távolról az derül ki, mely bolygók tartoznak össze, a kiterjesztett bolygónézetben az, mely atomok kötik össze őket, Street View-ban pedig az, mely forrásrészletek bizonyítják ezt.

Az interakció jelentése külön marad: Atomra koppintva az adott fogalom bizonyítékai nyílnak meg („mit írnak erről?”), élre koppintva pedig a két fogalom közös bizonyítékai („hol találkozik ez a két fogalom?”).

### 6. Végleges terminológia

| Réteg | Felhasználói modell | Belső renderer/adatmodell |
| --- | --- | --- |
| 1 | Galaxis | Galaxy cluster |
| 2 | Bolygó | Planet cluster |
| 3 | Atom | Atom node |
— | Street View | forrásbizonyíték-nézet |
— | nincs külön cap-nézet | Surface cap, csak lokális layout-segédstruktúra |

A „community” szót ezért elsősorban algoritmikus és renderer-belső értelemben használjuk. A felhasználó mentális modellje csak a Galaxis → Bolygó → Atom → Street View útvonalat látja.

Google Maps-analógiával: a galaxis országcsoport vagy nagy régió, a bolygó ország, a Community Cap város vagy körzet az országon belül, az Atom konkrét hely, a Street View pedig az adott helyhez tartozó konkrét forrásrészlet.

### 7. Determinisztikus clustering- és layoutstabilitás

Azonos gráfból azonos bolygó- és cap-tagságokhoz szükséges:

- stabil Atom-azonosító szerinti input-sorrend;
- fix Leiden-seed és algoritmusverzió;
- szinten belül rögzített `resolution`;
- fix minimum edge-weight küszöb;
- fix súlyszámítás és gyakorisági korrekció;
- egyértelmű döntetlenfeloldás;
- cache-elt, verziózott bolygó-, cap- és layout-eredmény.

A bolygó megnyitása önmagában nem indíthat új clusterezést. Teljes bolygó-clusterezés jelentős gráfbővüléskor vagy explicit kérésre fusson; a cap-layout újraszámítható, ha a bolygó belső gráfja vagy a renderelési policy megváltozik.

## Embedding

Az embedding **nem AI Graph**. Egyetlen feladata:

```text
Mi hasonlít ehhez?
```

Minden Atom embedding-vektort kap, amely az ObjectBox HNSW indexébe kerül.

```text
Atom
  ↓
Embedding
  ↓
HNSW
  ↓
20 legközelebbi Atom
```

Az eredmény kizárólag jelöltlista. Az embedding-közelség nem jelent definíciós, oksági, kezelési vagy más logikai kapcsolatot.

## Navigation Graph építése

Az AI a tartalom Atomokra bontásában és a válaszok előállításában vehet részt. A Navigation Graph kapcsolati súlya azonban nem AI által becsült szemantikai hasznosság: kizárólag az Atomok együtt-előfordulásából és dokumentumstruktúrájából származó bizonyítékot fejezi ki.

A HNSW az embedding-közelség alapján Atom-jelölteket adhat a kereséshez és a navigációhoz, de ez önmagában nem hoz létre AtomEdge-et, és nem a kapcsolat `weight` értéke.

A Navigation Graph egységes, általános kapcsolata:

```text
Atom A
  ↓
kapcsolódik
  ↓
Atom B

weight = strukturális bizonyíték erőssége
```

A Djinn ezért nem klasszikus, ontológiai Knowledge Graph. A Navigation Graph a tudástáron belüli, bizonyítékkal alátámasztott bejárási kapcsolatokat tárolja.

## Navigation Graph

A Navigation Graph célja a tudás bejárása. Nem logikai következtetést végez, nem univerzális ontológiát tart fenn, és nem relációtípusokkal próbálja leírni a világot.

Csak ezt válaszolja meg:

```text
innen
  ↓
érdemes
  ↓
oda
```

Példa navigációs útvonal:

```text
DO2
  ↓
Légzési elégtelenség
  ↓
Ellátási jegyzet
  ↓
Oxigén
  ↓
Oxigénterápia
```

## Query működése

A Query soha nem egyetlen teljes Jegyzetet küld közvetlenül az LLM-nek.

```text
Felhasználói kérdés
  ↓
Atom keresés
  ↓
Navigation Graph bejárás
  ↓
Kapcsolódó Atomok és forrásrészletek
  ↓
LLM
  ↓
Válasz
```

Példa kérdés:

> Mi a légzési elégtelenség?

A gráf összegyűjtheti:

```text
Definíció
  ↓
DO2 < VO2
  ↓
DO2 definíció
  ↓
VO2 definíció
```

Így a válasz nem csupán rövidítéseket ismétel, hanem feloldja a fogalmakat és a releváns tudásút alapján ad összefüggő magyarázatot.

## Miért nem akadémiai Knowledge Graph?

A Djinn általános jegyzetalkalmazás. Tartalmazhat többek között:

- orvostudományt;
- fizikát;
- matematikát;
- recepteket;
- programozást;
- történelmet;
- projektmenedzsmentet.

Ezért nincs univerzális relációhalmaz. Egy orvosi `treats` kapcsolat nem értelmezhető egy fizikajegyzetben, ahogyan egy merev `causes` reláció sem ír le minden recept-, történelmi vagy programozási összefüggést.

A Djinn kizárólag általános, súlyozott navigációs kapcsolatokat épít.

## Menüstruktúra

### Home

A Home feladata a gyors visszatérés, a folytatás és a napi munka támogatása.

Tartalma:

- legutóbbi jegyzetek;
- legutóbbi PDF;
- legutóbbi kép vagy más forrás;
- gyors létrehozás.

### Workspace

A Workspace a szerkesztői felület. Itt történik minden tartalom létrehozása és módosítása.

Felső child menüi:

- Témák;
- Jegyzetek;
- Tudástár.

A felhasználó itt ír, szerkeszt és töröl. A Workspace-ben nincs AI: a szerkesztési workflow nem teszi láthatóvá a gráf belső működését.

### Djinn

A Djinn természetes nyelvű lekérdező felület, nem chat. A felhasználó kérdést tesz fel, a rendszer pedig a helyi tudásból, a Navigation Graph bejárásával állít össze választ.

```text
Kérdés
  ↓
Navigation Graph
  ↓
LLM
  ↓
Válasz
```

A Djinn nem küld egyetlen teljes Jegyzetet sem közvetlenül az LLM-nek, és az LLM nem keres a teljes adatbázisban. A válasz kizárólag a lekérdezéshez összegyűjtött releváns Atomokból és azok visszamutató forrásrészleteiből készített, forrásolt kontextusra épül.

A válasz alatt mindig megjelenik:

- felhasznált Jegyzetek és forrásrészletek;
- források;
- kapcsolódó tudás;
- tudásútvonal.

Ezért a Djinn nem általános beszélgetésre, szerkesztésre vagy a tartalom létrehozására szolgál: az a Workspace feladata. A Djinn a meglévő tudásból gyűjt kontextust, és abból készít forrásolt, természetes nyelvű választ.

### Explore

Az Explore a Navigation Graph felülete. Nem egy zsúfolt node-edge diagram, hanem Google Maps-szerű tudástér.

A felhasználó:

- keres;
- zoomol;
- forgat;
- belép egy témába;
- mindig csak egy kis, releváns tudáskörnyéket lát.

Példa:

```text
Oxigén
  ↓
Légzés
  ↓
Légzési elégtelenség
  ↓
Ellátás
  ↓
Oxigénterápia
  ↓
Indikációk
```

## Explore nézetek

1. **Varázsgömb** – alapértelmezett 2.5D vagy 3D gömbnézet. Középen az aktuális fogalom, körülötte a kapcsolódó elemek. Interakciók: forgatás, pinch zoom, koppintás és dupla koppintás.
2. **2D térkép** – egyszerűsített gráfnézet gyengébb telefonokra.
3. **Lista** – minden kapcsolódó elem szűrhető felsorolásban.
4. **Tudásútvonal** – a Query által ténylegesen bejárt útvonal, például `Légzési elégtelenség → DO2 → Oxigénkínálat`.
5. **Részlet** – az eredeti dokumentum vagy Jegyzet megnyitása, benne a releváns forrásrészlet kiemelésével.

### Varázsgömb: adaptív tudáskártya-orientáció

A Varázsgömb opcionálisan Atomokat jelölő tudáskártyákat mutat a gömb felszínén. Ez megjelenítési viselkedés, nem része az Atom Graph adatmodellnek: a kártya színe, mérete és orientációja később szabadon változhat.

Két alapvető orientáció létezik.

#### 1. Billboard

A kártya mindig a kamera felé néz:

```text
camera

  □
  □
  □
```

Előnye, hogy a szöveg mindig jól olvasható. Hátránya, hogy a kártya a gömb felett lebegő elemnek hat; nem érződik úgy, mintha a felszín része lenne.

#### 2. Tangenciális, felületkövető orientáció

A Node normálvektora a gömb középpontjától kifelé mutat. Ha a Node pozíciója `P = (x, y, z)`, akkor:

```text
normal = normalize(P)
```

A kártya síkja erre a normálvektorra merőleges. Vagyis úgy fekszik rá a gömbre, mintha egy matricát ragasztanánk egy labdára:

```text
        □
      /
     /
    ●
   /
  O

O = a gömb középpontja
```

Ez jól közvetíti a felszíni elhelyezkedést, de a gömb szélén a teljesen tangenciális kártya erősen összenyomódik vagy élére fordul (`/////`, illetve `|||||`), ezért olvashatatlanná válik.

#### Adaptív hibrid: surface rotation + billboard rotation

A Djinn nem választ kizárólagos billboard vagy kizárólagos felületkövető módot. A két orientáció között quaternion-interpolációval, `slerp()`-pel vált:

```text
Surface quaternion
        ↓
   Quaternion.slerp()
        ↓
Billboard quaternion
```

Például `alpha = 0.2` esetén a kártya 20%-ban követi a gömb felszínét és 80%-ban a kamerát. Ettől a kártya a gömb részeként érződik, de szövege megmarad olvashatónak.

Az `alpha` értéke adaptív:

- a kamera közelében a billboard arány nagyobb, így a kiválasztott vagy megközelített Atom kifordul a felhasználó felé;
- távolabb a felületkövetés aránya nagyobb, így erősebb a gömbszerű térérzet;
- a horizont felé az orientáció fokozatosan újra billboard irányba tér vissza, hogy a kártyák ne pattanjanak ki-be és ne torzuljanak trapézzá.

Az orientáció mellett a kártya pozíciója, mérete és áttetszősége is a perspektívát követi: a kamerához közelebbi Atom nagyobb, a távolabbi kisebb és fokozatosan halványabb. A hátoldali Atomok és kapcsolataik csak forgatáskor válnak láthatóvá.

Ez a hibrid viselkedés adja a kívánt Google Earth-szerű hatást: a felhasználó egy gömb alakú tudástérben navigál, nem egy síkba fordított 3D node graphot néz.

## AI workflow

```text
Felhasználó
  ↓
Jegyzet
  ↓
Szekciók
  ↓
Chunkok
  ↓
Atomok
  ↓
Embedding
  ↓
HNSW
  ↓
Jelöltek
  ↓
Strukturális bizonyítékok
  ↓
AtomEdge-ek
  ↓
Navigation Graph
  ↓
Query
  ↓
LLM
```

## Felhasználói workflow

```text
Workspace
  ↓
Jegyzet
  ↓
Mentés
  ↓
Offline index
  ↓
Atom- és gráffrissítés
  ↓
Query
  ↓
Explore
  ↓
Dokumentum
```

## A Djinn filozófiája

A felhasználó feladata:

- tudást létrehozni;
- strukturált Jegyzeteket írni.

A Djinn feladata:

- a tudás automatikus indexelése;
- a tudáselemek közötti navigáció felépítése;
- a releváns kontextus összegyűjtése;
- természetes nyelvű válaszok előállítása.

A felhasználó soha nem épít gráfot. A gráf teljesen automatikusan, a háttérben épül és folyamatosan frissül.

Ez teszi lehetővé, hogy a Djinn ne egyszerű kereső vagy chatbot legyen, hanem AI-támogatott, navigálható személyes tudástér.
