# Djinn – Tudásnavigációs architektúra

> Ez a dokumentum a Djinn továbbfejlesztett, célállapotbeli architektúráját írja le. A meglévő [README.md](README.md) megmarad; ez a leírás a tudásnavigációs modell kanonikus jövőképét rögzíti.

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
weight?                 ← opcionális, későbbi strukturális súly
```

Az Edge nem rendelkezik relációtípussal. Nem léteznek például `causes`, `defines`, `treats` vagy `depends_on` típusok. A gráf Atomokból és relációtípus nélküli kapcsolatokból áll; a strukturális `weight` később, szükség esetén vezethető be.

### Weight

A `weight` nem szemantikai fontosság, hanem strukturális bizonyíték. Azt fejezi ki, hogy mennyire erős bizonyíték van a Djinn saját tudásbázisában arra, hogy két Atom összetartozik.

A `weight` kizárólag a tudásbázis szerkezetéből számolódik. Nem befolyásolja, hogy az egyik Atom definíció vagy kezelés, szakmailag fontosabb-e, illetve nem használ semmilyen ontológiai relációt.

#### A weight forrásai

A kapcsolat erősségét kizárólag dokumentumstruktúrából származó bizonyítékok határozzák meg. Ilyen bizonyíték lehet például, ha az Atomok:

- ugyanabban a mondatban szerepelnek;
- ugyanabban a bekezdésben szerepelnek;
- ugyanabban a Chunkban szerepelnek;
- ugyanabban a Jegyzetben szerepelnek;
- ugyanabban a Témában szerepelnek;
- több különböző helyen ismét együtt fordulnak elő.

A rendszer nem próbál szakmai vagy szemantikai fontosságot meghatározni.

#### Mire használható?

A `weight` a gráf fontos bemeneti adata lehet. Felhasználható:

- az Atom–Atom kapcsolat erősségének tárolására;
- community detection algoritmusok bemeneteként;
- a node fontosságának, például weighted degree értékének számítására;
- az élek vizuális hangsúlyozására.

Így a gráf teljes viselkedése a felhasználó saját dokumentumszerkezetéből épül fel, nem egy előre definiált tudásmodellből.

#### Determinisztikus, opcionális számítás

Ha a valós használati adatok alapján szükség van súlyozásra, a `weight` determinisztikusan számolható. Két Atom, `A` és `B` esetén:

```text
S = közös mondatok száma
P = közös bekezdések száma
C = közös Chunkok száma
N = közös Jegyzetek száma
T = közös Témák száma
```

A nyers strukturális pontszám:

```text
score = 8S + 4P + 2C + N + 0.25T
```

A 0–1 közé eső normalizált súly például:

```text
weight = 1 - e^(-score / k)
k = 10
```

Példák:

```text
Oxigén ↔ PaO₂
S = 2, P = 2, C = 1, N = 1, T = 1
score = 8×2 + 4×2 + 2×1 + 1 + 0.25 = 27.25
weight ≈ 0.93

Oxigén ↔ Oxigénterápia
S = 0, P = 1, C = 1, N = 1, T = 1
score = 0 + 4 + 2 + 1 + 0.25 = 7.25
weight ≈ 0.52
```

Ez a képlet nem szemantikai ítéletet ad, csak az együtt-előfordulás dokumentumszerkezeti erősségét normalizálja.

#### Bevezetési stratégia

Az első verzióban a gráf lehet súly nélküli:

```text
AtomEdge
--------
sourceAtomId
targetAtomId
```

Az AtomEdge létezése már önmagában azt jelenti, hogy van strukturális kapcsolat. A gráfelméleti algoritmusok, például a Louvain community detection, súly nélküli gráfon is használhatók.

A `weight` csak akkor kerüljön bevezetésre, amikor nagyobb, valós tudásbázison mérhető, hogy a strukturális súlyozás tényleg javítja a klaszterezést vagy a navigációt. Ez megelőzi, hogy egy elegáns, de zajt termelő képlet túl korán az adatmodell kötelező részévé váljon.

### Alapelvek

- Az Atom a tudás legkisebb önálló egysége.
- Egy Atom több Chunkhoz, Jegyzethez és Témához is tartozhat.
- A gráf nem ontológia.
- A kapcsolatok nem rendelkeznek relációtípussal.
- Ha használunk `weight` mezőt, azt kizárólag a dokumentumstruktúrából származó bizonyíték határozza meg.
- A vizualizáció és a megjelenítés nem része az adatmodellnek.

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
