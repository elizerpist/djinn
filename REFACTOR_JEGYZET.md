# Djinn – kötelező chunkmodell-refaktor jegyzet

> **Munkaszerződés a következő refaktorhoz.** A README általános termékmodelljével együtt ez a fájl a chunkadatmodell, a bevitel és a szerkesztő megvalósításának kötelező alapja. Ha a jelenlegi kód ettől eltér, ezt a célt kell megvalósítani; nem szabad a jelenlegi szétválasztást továbbvinni.

## 0. A Jegyzetek menü változatlan kerete

A bottom nav bal szélső, első menüje **Jegyzetek** néven marad meg. A jelenlegi stílusát és funkcióit ez a refaktor nem módosítja.

- A FAB új **jegyzet** gyűjtőegységet hoz létre, amelyből jegyzetkártya készül.
- A jegyzetkártyába belépve a felhasználó chunkokat készít és kezel.
- A header hárompontos dropdownja, a jegyzetmappa-kezelés és a felső subheader mappasáv változatlan marad.
- A jegyzetkártyák drag and drop módszerrel rendezhetők.
- A hosszú koppintásos kijelölés és az ekkor elérhető context dropdown jelenlegi műveletei változatlanok maradnak.

Ebben a dokumentumban és korábbi tervekben a **téma** vagy `topic` a jegyzet-gyűjtőegység szinonimája. Nem külön adattípus és nem azonos a `NoteChunk` tartalmi objektummal.

## 1. Egy közös Chunk modell

Nincs külön felhasználói chunk és AI-chunk.

- a felhasználó által kézzel létrehozott elem is `Chunk`;
- a rendszer által asszisztáltan létrehozott elem is `Chunk`;
- az AI által kivont vagy javasolt elem is `Chunk`;
- importból érkező elem is `Chunk`.

Az eltérés nem adattípus, nem külön lista és nem külön editor. Kizárólag metaadat:

```text
creationMethod = manual_selection
               | assisted_selection
               | ai_generated
               | imported
```

A kinyerés végén az eredmény minden esetben ugyanaz: egy szerkeszthető, validálható `Chunk`, függetlenül attól, hogy ki jelölte ki a forrásterületet vagy ki állította elő az első változatot.

## 2. Pontosan két chunkfajta

A közös `Chunk` felső szintű típusa kétféle lehet:

```text
Chunk
├─ NoteChunk
└─ FlowchartChunk
```

### NoteChunk: az általános jegyzetchunk

A jelenlegi kevert, szövegalapú chunkok egységes utódja a `NoteChunk`. Ez az általános jegyzetobjektum: szabadon szerkeszthető és formázható, egyetlen közös editorban.

Egy `NoteChunk` tartalmazhat például:

- bekezdéseket és formázott szöveget;
- címet és szakaszt;
- táblázatot;
- rendezett vagy rendezetlen listát;
- további, később bevezetett rich-content blokkokat;
- forráshivatkozást, oldaltartományt és forrásterületet, ha dokumentumból jött;
- címkéket, fogalmakat, validációs állapotot és kapcsolódó témákat.

A **szöveg**, **táblázat** és **lista** nem külön tárolt chunktípus. Ezek egy `NoteChunk` tartalmi blokkjai vagy szerkesztési elemei. A felhasználó egy jegyzetchunkon belül szabadon alakíthatja a bekezdéseket, formázást, táblázatokat és listákat.

### FlowchartChunk: a folyamatábra-chunk

A jelenleg létező flowchart önálló második chunktípus marad: `FlowchartChunk`.

- saját gráfstruktúrája lehet node-okkal és élekkel;
- ugyanúgy kapcsolható témákhoz, forrásokhoz, fogalmakhoz és más chunkokhoz;
- ugyanúgy lehet validációs állapota, létrehozási módja és forráshivatkozása;
- nem külön tudásrendszer, hanem a közös Chunk modell egy másik megjelenítési és szerkesztési formája.

## 3. Egy bemeneti út és egy design

Nincs külön „user chunk”, „AI chunk” vagy „AI-import” UI. Egy közös létrehozási belépési pont, egy közös feldolgozási nyelv és egy közös design van.

```text
Új chunk / Chunkolás
  → létrehozási mód kiválasztása
  → forrás vagy tartomány megadása
  → ugyanaz a Chunk editor
  → mentés vagy ellenőrzés
  → Chunk
```

A létrehozási vagy kinyerési menüben lehet kiválasztani, hogy a kezdeti tartalmat:

- a felhasználó készíti kézzel;
- a rendszer asszisztálja;
- az AI javasolja vagy automatikusan állítja elő.

Ez a döntés kizárólag a kezdeti automatizálást szabályozza. Nem változtatja meg a végső objektum típusát, listabeli helyét, szerkeszthetőségét vagy validációját.

### PDF-forrásnézet és Jegyzethez kapcsolás

A Tudástárban a felhasználó PDF-eket tölt fel; a jelenlegi PDF-chunk kinyerési workflow a refaktor első szakaszában változatlan marad. Egy feldolgozott PDF megnyitása **PDF Chunkok** nézetet nyit.

Ez nem külön Jegyzetek menü és nem külön PDF-chunk adattípus. Ugyanaz a közös chunklista és Chunk editor jelenik meg, mint egy Jegyzet megnyitásakor, kizárólag más az aktív csoportosítás:

```text
Jegyzet nézet       → a Jegyzethez kapcsolt chunkok
PDF Chunkok nézet   → az adott PDF forrásához tartozó chunkok
```

Ezért a `NoteChunk` layoutja, szerkeszthetősége, rich-text formázása, tagkezelése, validációja és editorlogikája mindkét nézetben azonos. A PDF-forrás, oldaltartomány és forrásterület a chunk metaadata marad.

#### Jegyzetbe küldés

A PDF Chunkok nézetben a felhasználó chunkot vagy chunkokat küldhet egy Jegyzetbe:

```text
chunk hosszú koppintása
  → kijelölési mód
  → context dropdown / hárompontos menü
  → Jegyzetbe küldés
  → Jegyzetlista popup dialog
  → cél Jegyzet kiválasztása
  → chunk–Jegyzet kapcsolat létrehozása
```

A művelet nem másol és nem helyez át adatot. A chunk a PDF alatt továbbra is megmarad, és ugyanaz az objektum jelenik meg a kiválasztott Jegyzetben is. Egy chunk több Jegyzethez is kapcsolható.

## 4. Kötelező UI-szabályok

1. Minden `NoteChunk` ugyanabban a rich-text Chunk editorban nyílik meg.
2. Az AI által készített NoteChunk ugyanúgy szerkeszthető, mint a kézzel készített.
3. A felületen legfeljebb kis eredetjelölés látható: Kézi, Asszisztált, AI-javaslat vagy Importált.
4. Az eredetjelölés nem rangsorolhat, nem választhat szét listákat, és nem korlátozhat szerkesztést.
5. A `FlowchartChunk` a saját flowchart editorában nyílik meg, de a közös chunkműveleteket — témához kapcsolás, validálás, hivatkozás, keresés és kapcsolatépítés — ugyanúgy támogatja.
6. Egy forrásból származó kinyerés végén nem „AI-chunkokat”, hanem ellenőrzésre váró vagy már validált `Chunk` elemeket lát a felhasználó.

## 5. Refaktor-elfogadási feltételek

A refaktor csak akkor tekinthető késznek, ha az alábbiak mind teljesülnek:

- [ ] Nincs külön perzisztens felhasználói- és AI-chunk entitás.
- [ ] A közös Chunk modellen belül pontosan `NoteChunk` és `FlowchartChunk` áll rendelkezésre.
- [ ] A NoteChunk támogatja a szöveget, bekezdéseket, listákat és táblázatokat ugyanazon szerkesztőben.
- [ ] A létrehozási mód metaadat, nem adattípus vagy külön navigációs útvonal.
- [ ] Kézi, asszisztált és AI-kinyerés egyaránt ugyanabba a közös Chunk editorba vezet.
- [ ] A kinyerés eredménye minden módban szerkeszthető, validálható Chunk.
- [ ] A FlowchartChunk része a közös tudás- és kapcsolati rendszernek.
- [ ] Nincs külön user- vagy AI-chunk lista, design, menü vagy mentési logika.
- [ ] A jelenlegi PDF-chunk kinyerési workflow a refaktor első szakaszában változatlan marad.
- [ ] A PDF Chunkok és a Jegyzetek chunknézete ugyanazt a lista- és editorlogikát használja, csak a forrásszűrő különbözik.
- [ ] A Jegyzetbe küldés hosszú koppintásos kijelölésből, context menüből és Jegyzetlista-dialogból indítható.
- [ ] A Jegyzetbe küldés chunk–Jegyzet kapcsolatot hoz létre, nem másolatot vagy áthelyezést.

## 6. Egységes tagkezelés és kézi szövegkiemelés

A jelenlegi tagrendszer megmarad a jelenlegi, működő formájában. A jelenlegi `TextChunk` tagkezelése a kötelező referenciaimplementáció: az ott helyesen működő adatkezelési és szerkesztési módszert kell átvinni a közös chunkmodellbe, nem új vagy párhuzamos tagrendszert létrehozni.

### Kötelező egységesítés

- A `NoteChunk` ugyanazt a tagkezelési metódust használja, mint a jelenlegi `TextChunk`.
- A `FlowchartChunk` is ugyanebbe a tagrendszerbe kapcsolódik.
- A tagok kezelése, hozzáadása, eltávolítása és darabszáma mindenhol ugyanazt a jelentést hordozza.
- A refaktor során fel kell tárni azokat a helyeket, ahol a tagok ma eltérően vannak kezelve vagy jelölve, majd ezeket a `TextChunk` referencia-viselkedésére kell egységesíteni.

### Tagok vizuális jelölése

A tag **nem** változtatja meg automatikusan a chunk szövegének vagy flowchart-tartalmának háttérszínét.

- A chunk jobb felső sarkában egyetlen színes badge / index jelenik meg.
- A badge a hozzá tartozó tagek darabszámát mutatja.
- A badge színe a tagállapot vizuális jelölése; nem szövegkiemelési szín.
- Nincs tagonkénti automatikus content-highlight és nincs külön, tagtípusonként eltérő megjelenítés.

Ez a szabály a `NoteChunk` és a `FlowchartChunk` kártya- és részletező nézetében is azonos.

### Kézi kitöltés / szövegkiemelés a keyboard feletti railben

A tagtól független, felhasználói szövegkiemelés külön rich-text formázási művelet.

- A keyboard feletti szerkesztői rail kap **Kitöltés** műveletet.
- A felhasználó kijelöl egy szövegrészletet, majd a Kitöltéssel megváltoztatja annak háttérszínét.
- A kitöltési szín a kijelölt szöveg formázási adata; nem tag, nem validációs állapot és nem AI-eredetjelölés.
- A felhasználó a kitöltést később módosíthatja vagy eltávolíthatja.
- A viselkedés a `NoteChunk` rich-text editorában és a `FlowchartChunk` szerkeszthető szövegmezőiben — például node-feliratban vagy más kijelölhető tartalomban — is azonos.

### Tagok és kiemelés közötti határ

```text
Tag
  → strukturális kategória és jobb felső darabszámbadge

Kitöltés / highlight
  → a felhasználó által kijelölt szövegrész rich-text formázása
```

E két funkció nem helyettesítheti és nem módosíthatja egymást.

## 7. Refaktor-elfogadási feltételek kiegészítése

- [ ] A `TextChunk` jelenlegi tagkezelése felmért és referencia-viselkedésként dokumentált.
- [ ] A `NoteChunk` és `FlowchartChunk` ugyanazt a tagkezelési metódust használja.
- [ ] A tagok csak a jobb felső, színes darabszámbadge-ben jelennek meg; nem festik automatikusan a tartalmat.
- [ ] A keyboard feletti railben elérhető Kitöltés művelet a kijelölt szöveg háttérszínét módosítja.
- [ ] A Kitöltés működése tagfüggetlen, visszavonható és mindkét chunktípusban azonos.

## 8. Kifejezetten nincs most implementálva

Ez a fájl specifikáció és refaktor-iránytű. Nem engedélyezi önmagában a kódolást, adatbázis-migrációt vagy UI-átalakítást. A megvalósítás csak külön **„kódolj”** utasítás után, a checkpointos végrehajtási lista szerint indul.
