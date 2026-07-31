# Djinn

> **Történeti README.** Ez a fájl a korábbi termék- és implementációs leírást őrzi. A kanonikus, jelenlegi tudásnavigációs szerződés a [README_NAVIGATION_ARCHITECTURE.md](README_NAVIGATION_ARCHITECTURE.md) fájlban található.

Djinn egy általános, local-first jegyzet- és tudásgráf-alkalmazás. A felhasználó saját jegyzeteket, feltöltött dokumentumokat, PDF-ekből készített részleteket és folyamatábrákat egy közös, kereshető tudástérben kezel.

Nem egy konkrét szakterülethez kötött termék. Használható személyes tudásbázisként, kutatási vagy munkahelyi jegyzeteléshez, dokumentumok feldolgozásához, illetve megfelelő, ellenőrzött forrásokkal döntéstámogatáshoz. A rendszerben a generált szöveg nem önmagában hiteles forrás: az állításokat az eredeti jegyzethez vagy dokumentumrészlethez kell vissza lehessen kötni.

Ez a README a projekt egyetlen kanonikus általános leírása. Szándékosan külön kezeli a termékcélt, a jelenleg működő funkciókat és a még fejlesztendő részeket.

## Webes fejlesztői előnézet

A böngészős UI-refaktorhoz külön Flutter webes belépési pont tartozik: `lib/main_web.dart`. Ez szándékosan nem tölti be az Androidos, natív ObjectBox-tárolót, mert az nem fordítható JavaScriptre. Az Android-alkalmazás indítási útvonala változatlanul `lib/main.dart`.

Termuxból a debug szerver indítása:

```sh
./tool/start_web_debug.sh
```

Ez a szervert a `http://127.0.0.1:8080` címen indítja; ezt Android Chrome-ban lehet megnyitni. Másik porthoz például: `DJINN_WEB_PORT=8081 ./tool/start_web_debug.sh`.

## Elsődleges navigáció és tudásmodell

> **Source of truth:** ez a szakasz határozza meg a Djinn elsődleges navigációját, a chunkok helyét az adatmodellben és a fő felhasználói műveleteket. A későbbi képernyő-, adatmodell- vagy keresési döntésnek ezzel összhangban kell állnia. Ha a jelenlegi implementáció ettől eltér, ez a termékszerződés az irányadó.

A Djinn alsó navigációja három elsődleges funkció köré épül:

1. **Jegyzetek**
2. **Tudástár**
3. **Kérdezz**

A három menü ugyanazt a tudásbázist különböző nézőpontokból kezeli.

- A **Jegyzetek** a tudást jelentés és felhasználói kontextus szerint rendezi.
- A **Tudástár** az eredeti forrásokat és azok feldolgozott tartalmát kezeli.
- A **Kérdezz** a teljes vagy kiválasztott tudásbázis lekérdezésére és feltárására szolgál.

A rendszer elsődleges tudásegysége a **chunk**. A chunkok UI-szinten egyenrangúak attól függetlenül, hogy saját jegyzetből, PDF-ből, képből, OCR-feldolgozásból vagy más importált forrásból származnak. A forrás típusa és helye a chunk metaadata; nem határozza meg a chunk értékét vagy rangját.

### Jegyzetek

#### Cél

A Jegyzetek menü a felhasználó által kialakított tudás- és munkaterületeket mutatja. A menüben létrehozott **jegyzet** gyűjtőegység: adott tárgyhoz, projekthez, kutatási kérdéshez vagy érdeklődési körhöz tartozó chunkokat fog össze.

A dokumentáció korábbi részeiben előforduló **téma** vagy `topic` ezzel a gyűjtőegységgel szinonim. Nem jelent külön adattípust, és nem azonos a tartalmi `NoteChunk` típussal.

A jegyzet nem birtokolja és nem másolja a chunkokat, hanem hivatkozik rájuk. Ugyanaz a chunk szükség esetén több jegyzethez is kapcsolható. Egy PDF egyik chunkja például tartozhat az „Adatbázis-migráció” jegyzethez, egy másik ugyanabból a PDF-ből a „DevOps” jegyzethez, egy harmadik pedig egyszerre több jegyzethez.

#### Főképernyő

A Jegyzetek a bottom nav bal szélső, első eleme. A jelenlegi menüstílus, funkciók és műveleti hierarchia ezen a képernyőn változatlan marad; a közelgő refaktor kizárólag az adatmodellt és a chunkokat érinti. A Jegyzetek menü a jegyzetkártyák áttekintője, egy kártya megnyitása a kiválasztott jegyzet chunknézetére vezet.

##### Header

A fejléc bal oldalán a Djinn logója és a **Jegyzetek** menücím jelenik meg. A jobb oldali hárompontos dropdown menü a nézet szintű rendezési és műveleti lehetőségeket tartalmazza. Itt érhetők el például a rendezési módok, jegyzet- és jegyzetmappa-kezelés, valamint kijelölt jegyzetek esetén a tömeges műveletek.

##### Subheader: mappák és rendezés

A header alatt külön subheader terület biztosít mappaszerű szervezést. Ez tartalmazza a mappachipeket, az aktív mappa egyértelmű jelölését és az **Új mappa** gombot. A mappa a jegyzetek felhasználói rendszerezésére szolgál; nem módosítja a jegyzet chunkkapcsolatait vagy az eredeti források helyét.

A jegyzetek a kiválasztott mappán vagy nézeten belül drag and drop művelettel manuális sorrendbe rendezhetők. Ez a kézzel beállított sorrend a rendezési lehetőségek egyikeként megőrizhető.

##### Jegyzetkártyák

A body jegyzetkártyákat jelenít meg. Egy jegyzetkártya tartalmazhatja:

- a téma nevét;
- opcionális leírását;
- a kapcsolódó chunkok számát;
- a felhasznált források számát;
- az utolsó módosítás idejét;
- opcionális kiemelt fogalmakat vagy címkéket;
- validációra váró elemek számát.

A jegyzetek rendezhetők:

- legutóbb használt;
- létrehozási idő;
- név;
- elemszám;
- manuális sorrend szerint.

A jegyzetkártyára történő egyszeri koppintás megnyitja a jegyzet chunknézetét, ahol a felhasználó chunkokat készíthet és kezelhet. A hosszú koppintás kijelöli a jegyzetet; ilyenkor a jelenlegi context dropdown és műveletei megmaradnak, például az áthelyezés mappába, archiválás, törlés vagy egyesítés.

A képernyő lebegő műveleti gombja (FAB) új jegyzet-gyűjtőegységet és annak jegyzetkártyáját hozza létre. Ez nem `NoteChunk` létrehozása: a felhasználó a létrejött jegyzetkártyába belépve készít és kezel chunkokat.

A felhasználó új jegyzetet hozhat létre, meglévőt átnevezhet, archiválhat, törölhet vagy más jegyzettel egyesíthet.

#### Jegyzet részletező képernyő: Chunkok

Egy jegyzetkártya megnyitása a jegyzet Chunkok nézetére vezet. Itt alapértelmezésben kevert chunklista jelenik meg. A listában egymás mellett szerepelhet:

- saját jegyzetből létrehozott chunk;
- PDF-ből származó chunk;
- képből vagy OCR-ből származó chunk;
- más importált forrásból származó chunk;
- később AI által létrehozott, külön jelölt összefoglaló vagy tudáselem.

A chunkkártyák alapvető megjelenése egységes. A kártya fő része maga a tartalom, alatta pedig a forrásinformáció látható.

Egy chunkkártya elemei:

- a chunk szövege vagy rövid előnézete;
- forrás neve;
- forrástípus;
- PDF esetén oldalszám;
- kép esetén az eredeti fájl neve;
- létrehozás vagy importálás ideje;
- validációs állapot;
- opcionális címkék;
- opcionális kapcsolódó fogalmak;
- több témához tartozás jelzése.

#### Interakciók

A felhasználó egy chunkra koppintva:

- megnyithatja a teljes chunkot;
- megtekintheti az eredeti forrást;
- PDF esetén a megfelelő oldalra ugorhat;
- szerkesztheti a saját tartalmat;
- módosíthatja a chunk témakapcsolatait;
- további témákhoz adhatja;
- eltávolíthatja az aktuális témából;
- kapcsolatot hozhat létre más chunkokkal;
- validálhatja, elutasíthatja vagy javíthatja;
- kiindulópontként használhatja egy kérdéshez;
- új saját jegyzetet vagy összefoglalót készíthet belőle.

A téma tartalma szűrhető:

- forrástípus szerint;
- forrásfájl szerint;
- validációs állapot szerint;
- saját vagy importált tartalom szerint;
- címkék és fogalmak alapján.

A lista rendezhető relevancia, időrend, forrás, dokumentumsorrend vagy manuális sorrend szerint.

#### Alternatív nézet

A kevert chunklista mellett elérhető forrás szerinti csoportosítás. Ebben a nézetben a felhasználó azt látja, hogy az adott témán belüli chunkok mely PDF-ekből, képekből vagy saját jegyzetekből származnak.

Ez csak megjelenítési mód. A téma alapegysége továbbra is a chunk, nem a dokumentum.

**A Jegyzetek alapelve:** a chunk a tartalom, a forrás a kontextus, a jegyzet pedig a felhasználó által kialakított gyűjtő- és jelentésbeli kapcsolat.

### Tudástár

#### Cél

A Tudástár az alkalmazásba bekerült eredeti források központi kezelőfelülete. Itt jelennek meg például:

- PDF-dokumentumok;
- képek és fotók;
- szkennelt dokumentumok;
- importált szövegfájlok;
- egyéb támogatott forrástípusok.

A Tudástár elsődlegesen forrásközpontú, míg a Jegyzetek menü tudás- és chunkközpontú. Ezért a két menü nem egymás másolata: a Jegyzetek azt mutatja meg, hogy egy tudáselem milyen kontextushoz tartozik, a Tudástár pedig azt, hogy az információ honnan származik.

#### Főképernyő

A Tudástár főképernyő alapértelmezésben forráskártyákat jelenít meg, nem ömlesztett chunklistát. Egy forráskártya tartalmazhatja:

- a fájl nevét;
- a forrás típusát;
- bélyegképet vagy fájlikont;
- PDF esetén az oldalszámot;
- a kinyert chunkok számát;
- a feldolgozás állapotát;
- az importálás idejét;
- a kapcsolódó jegyzetek számát;
- validációra váró chunkok számát;
- feldolgozási hibát vagy figyelmeztetést.

A források szűrhetők fájltípus, feldolgozási állapot, jegyzethez rendelt vagy még nem rendezett állapot, validációs állapot és importálási dátum szerint. Rendezési lehetőségek: legújabb, név, fájltípus, elemszám és legutóbb megnyitott.

#### Forrás részletező képernyő

Egy PDF vagy más forrás megnyitásakor a felhasználó hozzáfér az adott forrásból létrejött chunkokhoz. A képernyő tartalmazhatja:

- a forrás előnézetét;
- alapvető fájlinformációkat;
- feldolgozási állapotot;
- a forrás chunkjainak listáját;
- a kapcsolódó jegyzeteket;
- a még egyik jegyzethez sem rendelt chunkokat;
- a validációra váró elemeket.

A forráson belül a chunkok az eredeti dokumentumsorrend szerint jelenhetnek meg. PDF esetén minden chunk mellett látható lehet az oldalszám, szekciócím, rövid szövegelőnézet, validációs állapot és a kapcsolódó jegyzetek.

#### PDF chunknézet: ugyanaz a chunkkomponens, forrásszűréssel

A Tudástárba a felhasználó PDF-eket tölt fel. A jelenlegi PDF → chunk kinyerési workflow egyelőre változatlan marad. Ha a PDF-ből már létrejöttek chunkok, a PDF-kártyára koppintás a **PDF Chunkok** nézetet nyitja meg.

Ez nem külön vagy másodrendű Jegyzetek menü. A PDF Chunkok nézet ugyanannak az alkalmazáskomponensnek a másik szempont szerinti csoportosítása:

```text
Jegyzet megnyitása
  → az adott jegyzethez kapcsolt chunkok

PDF megnyitása a Tudástárból
  → kizárólag az adott PDF forrásához tartozó chunkok
```

Mivel csak egyféle `NoteChunk` létezik, a két lista layoutja, kártyamegjelenése, szerkeszthetősége, tagjelölése, validációja és Chunk editora azonos. A különbség kizárólag a lista aktív szűrője és a navigáció kiindulópontja. A PDF-ből származó chunk ugyanúgy szerkeszthető, mint egy Jegyzetből megnyitott chunk; eredeti PDF-forrása megmarad metaadatként.

#### Chunkok Jegyzetekbe küldése

A Tudástár központi funkciója, hogy a felhasználó az egyes PDF-chunkokat Jegyzetekhez kapcsolhatja. Ez történhet:

- egyesével;
- több chunk kijelölésével;
- teljes dokumentumszakasz kijelölésével;
- később automatikus vagy AI által javasolt besorolás elfogadásával.

PDF Chunkok nézetben a konkrét interakció:

1. a felhasználó egy chunkot hosszú koppintással kijelöl;
2. egy vagy több kijelölt chunknál megjelenik a context dropdown / hárompontos menü;
3. a felhasználó a **Jegyzetbe küldés** műveletet választja;
4. felugró Jegyzetlista-dialog jelenik meg;
5. a felhasználó kiválasztja a cél Jegyzetet;
6. a rendszer létrehozza a chunk és a Jegyzet kapcsolatát.

Például az első chunk az „Android” Jegyzethez, a második az „Adatbiztonság” Jegyzethez, a harmadik pedig egyszerre mindkettőhöz kapcsolható.

A Jegyzetbe küldés nem másolás és nem fizikai áthelyezés. Ugyanaz a chunk a Tudástárban a saját PDF-forrása alatt marad, miközben egy vagy több Jegyzetben is megjelenhet.

#### Interakciók

Egy forrással kapcsolatban a felhasználó:

- megnyithatja;
- átnevezheti;
- újrafeldolgozhatja;
- törölheti;
- megtekintheti a chunkjait;
- kijelölhet chunkokat;
- Jegyzetekbe küldhet chunkokat;
- eltávolíthat jegyzetkapcsolatokat;
- validálhatja a kinyert tartalmat;
- új kérdést indíthat a teljes forrásra vagy kijelölt chunkokra;
- exportálhatja vagy megoszthatja az eredeti fájlt, amennyiben ez támogatott.

**A Tudástár alapelve:** a forrás tartósan megmarad, a chunkjai pedig szabadon kapcsolhatók egy vagy több Jegyzethez.

### Kérdezz

#### Cél és működési módok

A Kérdezz menü a Djinn tudásbázisának lekérdező és feltáró felülete. A felhasználó természetes nyelvű kérdéseket tehet fel saját jegyzeteiről, dokumentumairól és a közöttük létrejött kapcsolatokról.

A funkció két móddal rendelkezhet:

- **online vagy aktív AI-mód:** a megtalált és összekapcsolt tudáselemekből természetesebb, összefüggő választ fogalmaz;
- **offline mód:** a helyi keresés és a gráfmotor strukturált formában adja vissza az összetartozó tudáselemeket, kapcsolatokat és forrásokat.

Mindkét mód ugyanazt a helyi tudásbázist, vektorindexet és gráfmotort használja. A két mód UI-ja alapvetően azonos: a felhasználó ugyanazon a felületen kérdez és ugyanazon típusú válaszkártyát kap; a működési mód csak visszafogott állapotjelzés.

#### Kezdőképernyő és keresési tartomány

A Kérdezz főképernyő tartalmazza:

- a kérdésbeviteli mezőt;
- küldés gombot;
- opcionális hangbevitelt;
- a keresési tartomány kiválasztását;
- gyors lekérdezési műveleteket;
- korábbi kérdéseket vagy munkameneteket;
- az online vagy offline állapot visszafogott jelzését.

A keresési tartomány lehet:

- teljes tudásbázis;
- kiválasztott téma;
- kiválasztott forrás;
- kiválasztott chunkok;
- aktuálisan megnyitott tartalom.

A kérdésmező mellett vagy fölött scope chip mutatja az aktív tartományt, például „Minden tudás”, „Android téma”, „migration.pdf” vagy „3 kijelölt elem”.

#### Gyors műveletek

Az üres kezdőképernyőn vagy a kérdésmező közelében előre definiált lekérdezési módok jelenhetnek meg:

- Összefoglalás;
- Kapcsolódó tudáselemek;
- Ellentmondások keresése;
- Hiányzó információk;
- Kulcsfogalmak;
- Források összehasonlítása;
- Folyamat vagy lépések feltárása;
- Kérdések generálása a tanuláshoz;
- Jegyzet készítése a találatokból.

Ezek akkor is segítik a felhasználót, ha nem akar pontos kérdést megfogalmazni.

#### Beszélgetési és eredményfelület

A felület használhat chatbuborékokat, de a Djinn válasza elsősorban összetett eredménykártya. A felhasználói kérdés egyszerű buborékban jelenhet meg, a rendszer válasza pedig nagyobb, strukturált kártya.

A válaszkártya elemei:

- közvetlen válasz vagy eredményösszefoglaló;
- bizonyosság vagy validációs állapot jelzése;
- felhasznált források;
- hivatkozott chunkok;
- PDF-oldalszámok;
- kapcsolódó fogalmak;
- kapcsolódó vagy következő kérdések;
- esetleges ellentmondások;
- nem ellenőrzött elemekre vonatkozó figyelmeztetés.

Offline módban a közvetlen válasz strukturáltabb lehet: kapcsolódó állítások, logikai kapcsolatok, releváns chunkok és forráslista. AI-módban ugyanez az információ összefüggő, természetes nyelvű válasz formájában jelenhet meg. A vizuális struktúra nem változik jelentősen.

#### Forráshivatkozások és válasz utáni műveletek

Minden lényeges válaszhoz forrásokat kell kapcsolni. A forráshivatkozás megnyithatja:

- az eredeti chunkot;
- a chunk témán belüli környezetét;
- az eredeti PDF megfelelő oldalát;
- a forrás teljes részletező képernyőjét.

Egy válasz vagy találati csoport után a felhasználó:

- új kérdést tehet fel vagy pontosíthatja az előzőt;
- másik témára vagy forrásra szűkíthet;
- megnyithatja a forrásokat;
- jegyzetté alakíthatja a választ;
- új saját chunkot hozhat létre;
- egy témához mentheti az eredményt;
- új témát készíthet belőle;
- chunkok közötti kapcsolatot hozhat létre;
- később flowchartot vagy más strukturált elemet készíthet;
- megjelölheti a választ hasznosnak, hibásnak vagy ellenőrzendőnek.

#### Előzmények

A Kérdezz menü korábbi lekérdezési munkameneteket kezelhet. Egy munkamenet tartalmazhatja a kérdések sorrendjét, a használt keresési tartományt, a válaszokat, a felhasznált forrásokat, valamint a létrehozott jegyzeteket és témakapcsolatokat. Az előzményekből egy kérdezési folyamat újranyitható és folytatható.

**A Kérdezz alapelve:** a felhasználó nem külön AI-t vagy gráfmotort használ, hanem a saját tudásához intéz kérdést. Az AI csak opcionális megfogalmazási és következtetési réteg ugyanazon helyi tudásmotor fölött.

### A három menü kapcsolata

A három fő menü nem három külön adatbázist kezel. Ugyanazon tudáselemek különböző nézeteit és műveleteit adja.

| Menü | Alapkérdés | Struktúra |
| --- | --- | --- |
| Jegyzetek | Milyen jelentésbeli vagy munkakörnyezetben akarom használni ezt a tudást? | Jegyzet → különböző forrásokból származó, kevert chunklista |
| Tudástár | Milyen forrásokat töltöttem fel, és milyen tudáselemek származnak belőlük? | Forrás → a forrásból származó chunkok |
| Kérdezz | Mit tud a rendszer a kérdésemről a kiválasztott vagy teljes tudásbázis alapján? | Kérdés → keresés és gráfbejárás → releváns chunkok és kapcsolatok → strukturált vagy természetes nyelvű válasz → források és további műveletek |

A felhasználó szabadon mozoghat a három nézet között:

- tudástári chunkot témához kapcsolhat;
- témabeli chunk eredeti forrását megnyithatja;
- témából vagy forrásból közvetlenül kérdést indíthat;
- válaszból új jegyzetet vagy témakapcsolatot hozhat létre;
- forráshivatkozásból visszatérhet a Tudástárba vagy a Jegyzetekhez.

Ez a felépítés biztosítja, hogy a Djinn egyszerre működjön személyes jegyzetalkalmazásként, forráskezelőként, szemantikus tudásbázisként és helyi tudáslekérdező rendszerként.

A chunk létrehozási, kinyerési és validációs folyamat kötelező, részletes specifikációja az **Egységes chunkmodell és feldolgozási életciklus** fejezetben található.


## Termékmodell

Djinnben a tudás nem elszigetelt fájlokból áll, hanem összekapcsolható egységek hálójából:

~~~text
Saját jegyzet vagy forrásdokumentum
  └─ rész / chunk
      └─ mondat vagy forrásrészlet
          └─ fogalom, kulcsszó, entitás
              └─ más kapcsolódó jegyzetek, chunkok és folyamatok
~~~

A felhasználó jegyzeteket hoz létre, dokumentumot importál, vagy egy dokumentumból több ellenőrizhető chunkot állít elő. A chunkok forrás-, oldal-, szakasz- és validációs metaadatot hordozhatnak. Így a keresés nem csak szó szerinti egyezést ad vissza, hanem jelentésben és logikában kapcsolódó részeket is.

## Fő felhasználási esetek

- Saját jegyzetek írása, szervezése, címkézése és összekapcsolása.
- PDF-ek és később más dokumentumok importja a telefonról vagy helyi tárhelyről.
- A forrásanyag feldarabolása visszakereshető, hivatkozható chunkokra.
- Egy fogalomhoz kapcsolódó jegyzetek, PDF-részletek, folyamatlépések és korábbi beszélgetések megtalálása.
- Forrásolt kérdés-válasz és tudásbázis-navigáció.
- Folyamatábrák olvasása, szerkesztése és emberi validálása.
- Dokumentum- vagy fogalomkörre szűkített tudástár, amely döntéstámogató feladatok alapja is lehet.

## Tudásgráf

Djinn két egymást kiegészítő réteggel épít kapcsolatokat.

### Szemantikus vektorréteg

Minden kereshető chunkból embedding, vagyis jelentést reprezentáló numerikus vektor készül. Ugyanazzal a modellel a kérdés vagy egy új jegyzet is vektort kap. A rendszer ezért olyan részeket is egymáshoz tud rendelni, amelyek eltérő szavakat használnak, de ugyanarról a fogalomról szólnak.

Például egy saját jegyzetben szereplő „adatbázis-séma átállás” és egy dokumentumban szereplő „database migration strategy” között akkor is lehet kapcsolat, ha szó szerinti kulcsszóegyezés nincs.

A jelenlegi helyi megvalósításban az ObjectBox HNSW vektorindexe tárolja az embeddingeket. A visszakeresés koszinusz-távolság alapján keresi a közeli chunkokat, majd minimális hasonlósági küszöb és találati limit szűri az eredményt. Az alapbeállítás legfeljebb nyolc, legalább `0.72` hasonlóságú találatot használ.

### Explicit tudásgráf

A vektoros közelség kapcsolatjelölteket ad; az explicit gráf rögzíti, hogy a kapcsolat mit jelent és milyen forrás támasztja alá.

~~~text
Note ─contains→ Chunk ─contains→ SourceSpan
Chunk ─mentions→ Concept
Chunk ─semantic_similar→ Chunk
Chunk ─supports / contradicts / depends_on / causes→ Chunk
FlowchartNode ─flow_to→ FlowchartNode
~~~

A céladatmodellben egy kapcsolat legalább a következőket hordozza:

| Mező | Szerep |
| --- | --- |
| `sourceId`, `targetId` | A kapcsolat két végpontja. |
| `relationType` | Például `contains`, `mentions`, `same_concept`, `supports`, `contradicts`, `depends_on`, `causes` vagy `flow_to`. |
| `weight` és `confidence` | A szemantikus közelség vagy az elemzés biztonsága. |
| `evidence` | Az eredeti mondat vagy forrásrészlet, amely a kapcsolatot igazolja. |
| `validationState` | Automatikus, felülvizsgálandó, elfogadott vagy elutasított állapot. |

A kapcsolatépítés célfolyamata:

1. A dokumentum vagy jegyzet fejezetekre, bekezdésekre, mondatokra és chunkokra bomlik.
2. A rendszer kulcsszavakat, fogalmakat és entitásokat azonosít, majd normalizálja az alakváltozatokat, rövidítéseket és szinonimákat.
3. Determinisztikus élek készülnek közös címke, hivatkozás, azonos fogalom, közös forrás vagy felhasználó által létrehozott link alapján.
4. A vektorindex közeli chunkjelölteket ad. Nem minden chunkot hasonlítunk minden másikhoz: a HNSW-index csak a reális jelölteket szolgáltatja.
5. Opcionális AI-réteg címkézi a jelölt kapcsolatot, például részletezés, alátámasztás, ellentmondás, ok-okozat vagy folyamatlépés formájában.
6. A felhasználó elfogadhatja, átírhatja vagy elutasíthatja a kapcsolatot.

Lekérdezéskor először a vektoros top találatok érkeznek, majd a rendszer kontrolláltan egy vagy két gráfugrással kibővítheti a kontextust. Egy találat mellé így elérhetővé válhat az eredeti jegyzet, az azt alátámasztó PDF-részlet, egy kapcsolódó fogalom vagy egy folyamat következő lépése. A gráfbejárásnak mindig típus-, bizalmi és forrásszűréssel kell működnie, hogy ne gyűjtsön össze ellenőrizetlenül nagy vagy irreleváns kontextust.

### Kompakt elemszám-megjelenítés

A tudásbázis adatai a háttérben mindig pontos egész számként maradnak meg. A felületen azonban az atomok, kapcsolatok, közösségek és egyéb elemszámok nem jelenhetnek meg korlátlan hosszúságban, mert a gráf akár több millió elemet is tartalmazhat.

Ezért minden felület ugyanazt a determinisztikus, kerekített formázási szabályt használja:

| Pontos érték | Megjelenítés |
| ---: | --- |
| `0–999` | `999` |
| `1 000–99 999` | `1,2 ezer`, `12 ezer` |
| `100 000–999 999` | `123 ezer` |
| `1 000 000–999 999 999` | `1,2 M`, `123 M` |
| `1 000 000 000` fölött | `1,2 Md`, `123 Md` |

A megjelenítés legfeljebb három jelentős számjegyet használ, és mindig kerekít. Példák:

~~~text
123456      → 123 ezer
1234567     → 1,2 M
123456789   → 123 M
1234567890  → 1,2 Md
~~~

Kerekítés után a következő egységre kell normalizálni: `999 500` már `1 M`, nem `1000 ezer`. Ugyanazt a formázót kell használni a Tudásgalaxis statisztikáiban, kártyákon, listákban, tooltipben és akadálymentes feliratokban.

A rövid érték mellett koppintással, hoverrel vagy részletező nézetben mindig elérhető a teljes szám ezres csoportosítással, például: `1 234 567 atom`. A rövid forma kizárólag a helytakarékos vizuális megjelenítésre szolgál; a pontos érték nem veszhet el.

## Végleges atomhierarchia és Explore-bejárás

Az Explore nézet egységes, többszintű fogalomgráfot mutat. A hierarchia nem a jegyzetekből vagy a megjelenítésből indul ki, hanem egy globális, normalizált fogalomgráfból:

| Szint | Jelentés | Megjelenítés |
| --- | --- | --- |
| **Univerzum** | Az aktuálisan vizsgált teljes gráf vagy annak szűrt részhalmaza. | Az Explore teljes bejárható tere. |
| **Galaxis** | Egymással erősen összekapcsolódó bolygók második szintű közössége. | Bolygók és összesített bolygóközi kapcsolati folyosók. |
| **Bolygó** | Sűrűn kapcsolódó fogalmi atomok első szintű közössége. | Atomok, belső élek és hídatom-jelölések. |
| **Atom** | Egyetlen globális, normalizált fogalom, például `PaO₂`, oxigén vagy `RACE score`. | Egy kártya/gömb; egy clusterverzióban pontosan egy bolygóhoz tartozik. |
| **Street View** | Bizonyítéknézet, nem új hierarchiaszint. | Az atomhoz vagy élhez tartozó chunkok, mondatok, táblázatrészek és forráshelyek. |

### Globális atomok és előfordulások

Egy fogalom csak egyszer létezik. Ha az „oxigén” több fizikai, kémiai és egészségügyi jegyzetben szerepel, ezek az előfordulások ugyanarra az Oxigén atomra hivatkoznak; a jegyzet nem birtokolja és nem duplikálja az atomot. A normalizálás AI nélkül is elvégezhető kis- és nagybetű-, Unicode- és alsóindex-normalizálással, rövidítésszótárral, jóváhagyott aliasokkal és a dokumentumban explicit rövidítésekkel. Bizonytalan egyezést a rendszer nem von össze automatikusan.

### Forrásolt atomélek és súlyozás

Atomok között csak forrásbizonyíték alapján jöhet létre él. A kezdeti nyers együttállási pontok:

| Közös kontextus | Nyers pont |
| --- | ---: |
| Ugyanaz a mondat vagy táblázatsor | `1,0` |
| Ugyanaz a bekezdés vagy blokk | `0,7` |
| Ugyanaz a chunk | `0,4` |
| Szomszédos chunkok, közös szekció alatt | `0,2` |
| Közös dokumentum- vagy szekciócím kontextusa | `0,1` |

Az, hogy két fogalom pusztán ugyanabban a dokumentumban szerepel, önmagában nem hoz létre élt. A címek és szekciók kontextushorgonyként működnek, így egy távoli Stroke-definíció és egy RACE score táblázat gyenge, de valódi szerkezeti kapcsolatot kaphat anélkül, hogy a dokumentum minden fogalma teljes gráffá kapcsolódna.

A végleges edge weight a nyers pontok összegéből és normalizálásából készül. Figyelembe kell venni a különböző chunkok és független források számát, a fogalmak külön-külön gyakoriságát és a kapcsolat változatosságát. PPMI- vagy IDF-szerű korrekció csökkenti az olyan általános fogalmak torzítását, mint az „oxigén” vagy a „beteg”. Az él eredeti bizonyítéklistája koppintással mindig megnyitható.

### Bolygók és hídfogalmak

A súlyozott fogalomgráfon determinisztikus Leiden community detection fut. A bemeneti sorrend atomazonosító szerint stabil, a seed, resolution, küszöbök és algoritmusverzió rögzített. Megjelenítési célként egy bolygó körülbelül 8–40 atomot tartalmaz; az 5 alatti közösség összevonható, a 60 fölötti magasabb resolutionnel továbbosztható.

Egy hídfogalom, például az Oxigén, csak egy bolygóhoz tartozik: ahhoz, amelyhez a legerősebb normalizált belső affinitása kapcsolja. A többi bolygó felé mutató élek nem vesznek el, hanem bolygóközi keresztélként maradnak meg. A hídatom a saját bolygója peremén, a külső kapcsolatai irányában helyezhető el, duplikáció nélkül.

### Galaxisok

A bolygók után aggregált bolygógráf készül. Ebben egy node egy bolygó, egy él pedig a két bolygó atomjai közötti keresztkapcsolatok összesített súlyát képviseli. Az aggregáció számolja az eltérő atompárokat, a független forrásokat és a kapcsolat sokféleségét, ezért egyetlen gyakori hídfogalom nem dominálhatja a galaxist. Ezen a bolygógráfon is determinisztikus Leiden fut; egy galaxis induló megjelenítési célja körülbelül 3–10 bolygó.

Az elrendezés stabilitása érdekében nem fut újra teljes klaszterezés minden új mondat után. Az új atom először a legerősebb affinitású bolygóhoz kerül, teljes újraclusterezés pedig jelentős, például 5%-os gráfbővüléskor vagy kézi kérésre történik. A régi és új közösségeket tagsági átfedéssel kell párosítani; a stabil azonosító, név és vizuális seed megmarad. Atom csak akkor kerüljön át, ha az új affinitás például legalább 20%-kal meghaladja a jelenlegi kötődését.

### Explore nézetek és kapcsolati folyosó

- **Galaxisnézet:** a felhasználó bolygógömböket és erős, aggregált bolygóközi kapcsolatokat lát.
- **Bolygónézet:** a kiválasztott bolygó felnagyul; megjelennek az atomok, a belső élek és a fontos keresztkapcsolatok, míg a külső kapcsolatok hídatom-jelölésként maradnak visszafogottan láthatók.
- **Atom Street View:** az atom minden releváns előfordulását, pontos mondat- vagy táblázatrészletét, szekcióját, forrását és oldalszámát mutatja.
- **Él Street View:** csak azokat a bizonyítékokat mutatja, amelyek a két atomot közös kontextusban támasztják alá.

A galaxisban a bolygó–bolygó él nem névtelen vonal, hanem összecsukott **kapcsolati folyosó**. Bolygónézetben a kiválasztott bolygó pereméről kifelé vezető, tapelhető 3D szálak a súlyozott fogalomgráf tényleges bolygószomszédaira mutatnak; virtuális vagy véletlen célpont nem használható. A szálra koppintva nem információs kártya nyílik: ugyanabban a Three.js/galaxis-térben a kamera animáltan középre csúszik, és a kiválasztott valódi planet root mellett a valódi szomszédos planet root is láthatóvá válik. Ez a folyosó nem új hierarchiaszint, hanem ugyanannak a galaxisnak egy kiterjesztett perspektívája. A kétbolygós nézetben a többi atom és a gyenge háttérkapcsolatok elhalványulnak; a konkrét hídatom- és bizonyítékbontás csak a következő interakciós rétegben történik. Például: `parciális nyomás → PaO₂`, `diffúzió → alveoláris gázcsere`.

Bolygónézetben a külső kapcsolatok nem árasztják el a gömböt. A hídatom kap egy külső gyűrűt vagy „más bolygóhoz is kapcsolódik” jelölést, amely koppintásra megmutatja a célbolygókat és a legerősebb célatomokat. A bejárás kaszkádja:

~~~text
galaxis → bolygó → atom → kapcsolódó bolygó → célatom → Street View-bizonyíték
~~~

Így minden zoomszint más kérdésre válaszol: távolról mely közösségek tartoznak össze, közelebbről mely atomok kötik össze őket, Street View-ban pedig mely forrásrészletek bizonyítják a kapcsolatot.

## Egységes chunkmodell és feldolgozási életciklus

> **Kötelező adatmodell-refaktor / source of truth:** a rendszerben nem lehet külön „felhasználói jegyzetchunk” és külön „AI-chunk” entitás vagy külön véglegesítési folyamat. Egyetlen `Chunk` típus létezik. A különbség kizárólag a létrehozás kezdeti automatizálásában és a `creationMethod` metaadatban van. Ez a szakasz elsőbbséget élvez minden korábbi vagy jelenlegi, ettől eltérő adattárolási megoldással szemben.

A probléma nem a három feldolgozási lehetőség létezése, hanem az, ha három eltérő mentális modellként jelennek meg:

- kézi módban a felhasználó kijelöl, lát, szerkeszt és ment;
- asszisztált módban kijelöl, a rendszer kivonja vagy javítja, majd szerkeszt és ment;
- AI-módban pedig egy gomb után láthatatlan háttérművelet történik.

Az automatikus AI-feldolgozás ezért nem külön, láthatatlan művelet, hanem ugyanannak az egységes chunkkészítési folyamatnak egy másik belépési módja. Mindhárom út ugyanabba a chunkstruktúrába, ugyanabba a Chunk editorba és ugyanabba a validációs folyamatba érkezik.

### Egységes belépési pont: Chunkolás

A PDF-nézetben elérhető **Chunkolás** művelet alsó sheetet nyit három móddal:

| Mód | Kezdeti kontroll | Eredmény |
| --- | --- | --- |
| **Kézi kijelölés** | A felhasználó téglalappal jelöl ki PDF-területet a szövegrétegben vagy OCR-kimenetben. | A kivont részlet azonnal szerkeszthető Chunk editorban nyílik meg; mentéskor egy chunk készül. |
| **Asszisztált kijelölés** | A felhasználó hozzávetőlegesen jelöl ki területet vagy bekezdést. | A rendszer logikai szöveghatárokat keres, összevonja a sortöréseket, felismeri a címet, és címet, címkéket, fogalmakat javasol; minden mentés előtt szerkeszthető. |
| **Automatikus feldolgozás** | A felhasználó feldolgozási tartományt és célokat választ. | Az AI chunkjavaslatokat készít; ezek először ellenőrző felületre kerülnek, nem válnak automatikusan végleges chunkká. |

A PDF hárompontos menüjében maradhat **AI-chunkolás indítása** gyors művelet, de ez is konfigurációs sheetet nyit, nem indít azonnal háttérfeldolgozást.

### Automatikus feldolgozás konfigurációja

Az AI-feldolgozás sheetben a felhasználó a következőket állítja be.

#### Tartomány

- aktuális oldal;
- konkrét oldaltartomány, például `4–12`;
- aktuális fejezet;
- teljes dokumentum.

#### Chunkolási cél

- általános tudáselemek;
- tanulási jegyzetek;
- kutatási állítások;
- eljárások és lépések;
- definíciók és fogalmak;
- saját beállítás.

Nincs univerzálisan jó chunkolás: ugyanaz a dokumentum másképp tagolható tanuláshoz, visszakereséshez vagy döntéstámogatáshoz.

#### Részletesség

A felület egyszerű, háromállású választót ad:

- **Nagyobb chunkok**;
- **Kiegyensúlyozott**;
- **Kisebb, részletes chunkok**.

A háttérben ez tokenméretet, szemantikai határokat, átfedést és szerkezeti felismerést vezérelhet, de ezek nem jelennek meg technikai paraméterként a felhasználónak.

#### Mentési mód

- **Javaslatként, ellenőrzésre** — alapértelmezett;
- **Automatikus mentés**;
- **Csak előnézet**.

Az automatikus mentés sem hozhat létre külön adattípust: ugyanazokat a chunkokat menti, megfelelő validációs állapottal és teljes forrás-visszaköthetőséggel.

### Chunk Studio: közös feldolgozási munkatér

A PDF-preview és a chunkszerkesztő között **Chunk Studio / Feldolgozás** munkaterület van. Ez nem különálló funkcióhalmaz, hanem a forrás feldolgozási életciklusa.

Mobilon nem valódi osztott képernyő, hanem két, egymás között váltható nézet:

| Dokumentum | Chunkok |
| --- | --- |
| PDF-preview, oldalléptetés és zoom. | Javasolt és mentett chunkok listája. |
| Szöveg- vagy területkijelölés. | Egyesítés, szétválasztás, törlés. |
| Chunkok vizuális jelölése a PDF-en. | Cím és szöveg szerkesztése. |
| AI által felismert határok és már mentett chunkok halvány keretei. | Oldalszám, forrásterület, címkék, fogalmak és validációs állapot. |

A felső tabok például: **PDF | Chunkok (18) | Ellenőrzés (5)**. Így az AI eredménye látható, ellenőrizhető munkatárgy, nem rejtett importfolyamat.

### Látható feldolgozási állapot

Az AI belső gondolatmenetét nem mutatjuk. A felhasználó azt látja, hogy a rendszer milyen ellenőrizhető lépést végzett el és mire vár:

1. Szövegréteg elemzése;
2. dokumentumszerkezet felismerése;
3. fejezetek és címsorok azonosítása;
4. chunkhatárok létrehozása;
5. címek és kulcsfogalmak generálása;
6. javaslatok elkészültek.

A folyamat vége nem puszta snackbar. Példa összegzés:

> **24 chunkjavaslat készült**<br>
> 18 nagy bizonyosságú · 4 ellenőrzendő · 2 OCR-problémás<br>
> **Javaslatok áttekintése**

### A Chunk közös objektum

Minden kézi, asszisztált, AI által generált vagy importált chunk ugyanazokat a lényegi mezőket kapja:

| Mező | Szerep |
| --- | --- |
| `sourceDocumentId` | Az eredeti dokumentum vagy saját jegyzetforrás azonosítója. |
| `pageRange` | Oldalszám vagy oldaltartomány, ha a forrás lapozható. |
| `sourceRegion` | Forrásterület koordinátái vagy hivatkozása. |
| `extractedText` | Az eredetileg kivont, változatlan szöveg. |
| `editedText` | A felhasználó által szerkesztett, megjelenített szöveg. |
| `title`, `section` | A chunk címe és dokumentumszakasza. |
| `tags`, `concepts` | Címkék és kapcsolódó fogalmak. |
| `creationMethod` | A létrehozás kezdeti módja. |
| `confidence` | Kinyerési vagy javaslati bizalmi érték. |
| `validationState` | Javasolt, ellenőrzendő, validált vagy elutasított állapot. |

Az engedélyezett `creationMethod` értékek:

| Érték | Jelentés | Opcionális UI-jelölés |
| --- | --- | --- |
| `manual_selection` | A forrásterületet és határt a felhasználó határozta meg. | Kézi |
| `assisted_selection` | A felhasználói kijelölést a rendszer strukturálta vagy egészítette ki. | Asszisztált |
| `ai_generated` | Az AI jelölte ki a tartományt és javasolta a chunkot. | AI-javaslat |
| `imported` | Más rendszerből vagy támogatott importból érkezett. | Importált |

A létrehozási mód hasznos nyomkövetési metaadat, de nem rangsorolja a chunkot és nem hoz létre külön képernyőt vagy külön editor-t. Felhasználói jóváhagyás után mindegyik egyszerűen validált chunk.

### Egységes Chunk editor

A jelenlegi slide-up jegyzetsheet megmaradhat alapként, de mindenhol **Chunk editor** néven működik, nem külön „jegyzet” szerkesztőként.

Felül megjelenik:

- a forrás neve és oldala;
- előnézeti kivágás;
- a Kézi, Asszisztált vagy AI-javaslat jelölés.

Középen szerkeszthető:

- chunkcím;
- chunk szövege;
- szekció;
- címkék;
- kapcsolódó fogalmak.

Alapműveletek alul: **Mentés**, **Mentés és következő**, **Elvetés**.

AI-javaslatnál további műveletek:

- egyesítés az előző chunkkal;
- szétválasztás;
- forrásterület megnyitása;
- eredeti kivont szöveg visszaállítása.

### PDF-nézet műveleti hierarchiája

#### Header

- vissza;
- dokumentum neve;
- feldolgozási állapot;
- hárompontos menü.

A hárompontos menüben: Dokumentum adatai, OCR újrafuttatása, AI-chunkolás, chunkok újragenerálása, export és törlés.

#### PDF body

- maga a PDF;
- opcionális chunkhatár-overlayek;
- kijelölési eszköz;
- oldalszám;
- keresés.

#### Alsó műveleti sáv

A leggyakoribb belépési pontok: **Kijelölés**, **Chunkok**, **AI-feldolgozás**. Az AI-feldolgozás elsődleges funkció, ezért nem lehet kizárólag a hárompontos menübe rejtve.

### Feldolgozási munkamenet

Az automatikus feldolgozás tartós **feldolgozási munkamenethez** kapcsolódik, nem közvetlenül egy visszavonhatatlan chunkhalmazt ír létre. Példa:

~~~text
Modern Android Architecture.pdf
Feldolgozás #2
Tartomány: teljes dokumentum
Mód: AI, kiegyensúlyozott
34 javaslat · 7 ellenőrzendő · 12 jóváhagyva
~~~

Egy munkamenet lehetővé teszi, hogy a felhasználó később visszatérjen, megszakítsa vagy folytassa a munkát; egy új AI-futtatás ne írja felül automatikusan a korábbit; két feldolgozási változat összehasonlítható legyen; és a rendszer pontosan nyomon kövesse, mi lett már jóváhagyva.

### PDF-részletező végső struktúrája

A Tudástárban egy PDF megnyitása után a felső szintű tabok:

| Tab | Tartalom |
| --- | --- |
| **Áttekintés** | Fájlinformációk, feldolgozási állapot, chunkok száma, validálatlan elemek és kapcsolódó témák. |
| **Dokumentum** | PDF-preview, kézi és asszisztált kijelölés, chunk-overlay. |
| **Chunkok** | Minden mentett chunk, státusz- és létrehozásimód-szűrés, tömeges kijelölés és export. |
| **Feldolgozás** | Új AI-feldolgozás, futó és korábbi munkamenetek, javaslatok ellenőrzése és OCR-problémák. |

### Végleges elnevezések és alapelv

A felhasználói felületen a három belépési mód neve:

1. **Kézi kijelölés**;
2. **Asszisztált kijelölés**;
3. **Automatikus feldolgozás**.

Nem szükséges minden felületen háromféle „chunkolásként” bemutatni őket. A felhasználó számára az a lényeg, hogy mennyi kontrollt ad át a rendszernek. A konzisztencia kulcsa: minden út ugyanabban az editorban, ugyanazzal az adattípussal és validációval hoz létre javasolt vagy szerkeszthető chunkot. A különbség kizárólag az, hogy a forrásterületet és a chunkhatárokat a felhasználó, a rendszer segítsége vagy az AI határozza meg.

## Jelenlegi, működő helyi megvalósítás

A Flutter alkalmazás elsődleges útvonala helyi, Android APK-ból is használható mód. Termux, szerver vagy külön vektoradatbázis nem szükséges a helyi tudástár megnyitásához.

### Adattárolás

Az alkalmazás ObjectBox adatbázist nyit az alkalmazás saját tárhelyén. A jelenlegi entitások többek között:

- beszélgetésszálak, üzenetek és hivatkozások;
- importált dokumentumok és feldolgozási állapotuk;
- szöveges dokumentumchunkok, oldalszámok és szakaszcímek;
- chunkembeddingek és HNSW vektorindex;
- flowchartok, node-ok, élek és validációs állapotuk;
- feldolgozási jobok és alkalmazásbeállítások.

Az API-kulcs nem az ObjectBoxban, hanem a `flutter_secure_storage` platform biztonságos tárában marad. A PDF-eket az app saját dokumentumkönyvtárába másolja.

### PDF → chunk → vektor útvonal

~~~text
Telefonról kiválasztott PDF
  → app-private másolat
  → strukturált OpenAI Responses API feldolgozás
  → oldal- és szakasztudatos chunkok
  → chunkonként embedding
  → ObjectBox dokumentum-, chunk- és vektortárolás
~~~

Az OpenAI-kérés strukturált JSON-választ kér `id`, `text`, `page_number` és `section_title` mezőkkel. A jelenlegi APK-kódban a PDF-import után ez az automatikus feldolgozás indul el, ha van API-kulcs.

A kézi, félautomata és külön OCR-folyamat a termékcél része, de még nincs teljesen kiépítve. Ugyanez igaz az önálló `Note`, `Concept` és `KnowledgeEdge` entitásokra: a vektoros réteg és a flowchart-gráf már létezik, az általános jegyzetgráf még fejlesztési irány.

### Keresés és forrásolt válasz

1. A kérdés embeddinget kap.
2. Az ObjectBox legközelebbi chunkokat, illetve később gráf-node-okat keres.
3. A találatoknak át kell menniük a hasonlósági küszöbön és a validációs szűrésen; elutasított flowchart-elem nem használható.
4. A válaszmodell csak a kiválasztott forrásrészleteket kapja meg, nem a teljes dokumentumtárat és nem internetes keresést.
5. A modell strukturált válaszban visszaadja a felhasznált forrásazonosítókat.
6. A kliens ellenőrzi, hogy minden hivatkozás valóban a visszakeresett eredmények között van-e.
7. Opcionálisan második groundedness-ellenőrzés vizsgálja, hogy a válasz teljes egészében alátámasztható-e.

Ha nincs API-kulcs, nincs feldolgozott tudástár, nincs elég hasonló forrás, a hivatkozások hibásak vagy a groundedness-ellenőrzés elbukik, az alkalmazás elutasító választ ad ahelyett, hogy külső vagy kitalált tudásra támaszkodna.

## Folyamatábrák

A flowchartok Djinnben explicit gráfként tárolhatók: a node-ok és az élek stabil azonosítókat, címkéket, egymásra mutató kapcsolatokat és validációs állapotot kapnak. Ez nem pusztán vizuális rajz: a `flow_to` élek logikai útvonalat is jelentenek.

A jelenlegi alkalmazásban elérhető validációs lista és egyszerű szerkesztő. Egy node vagy él lehet felülvizsgálatlan, részben validált, elfogadott vagy elutasított. A kereső az elutasított elemeket kizárja, a csak részben validált elemek használatakor figyelmeztetést tud megjeleníteni.

Az automatikus flowchart-felismerés, OCR, fejlettebb mobil megjelenítés és a teljes gráfszerkesztő további fejlesztési irány.

## Adatvédelem és AI-hívások

Djinn local-first rendszer:

- a tudástár, a PDF-másolatok, a chunkok, a vektorok és a chatelőzmények elsődlegesen a készüléken maradnak;
- AI-feldolgozás vagy AI-válasz esetén a felhasználó által engedélyezett PDF, illetve a kiválasztott releváns chunkok elhagyhatják a készüléket a választott szolgáltató felé;
- a szolgáltatói API-kulcs a készülék biztonságos tárában van;
- a rendszernek egyértelműen jeleznie kell, mely feldolgozási mód küld adatot külső szolgáltatóhoz, és melyik működik teljesen helyben.

A jelenlegi kliens közvetlenül OpenAI-t támogat. Más szolgáltatók, többek között Gemini, a célarchitektúrában szerepelnek, de nem tekinthetők jelenleg bekötött futtatási módnak.

## Opcionális backend

A repó `backend/` könyvtára külön FastAPI-alapú, szerveres útvonal prototípusa. Qdrant vektortárolót, PostgreSQL metaadat- és audit-tárat, LangGraph válaszfolyamot és NeMo Guardrails ellenőrzéseket tud használni.

Az elérhető backend-végpontok: `/health`, `/system/readiness`, `/conversations`, `/knowledge/documents`, `/knowledge/status` és `/chat`. A jelenlegi Flutter-alkalmazás elsődleges helyi módja nem vált át erre a backendre automatikusan; a szerveres útvonal önálló, későbbi vagy speciális telepítési lehetőség.

## Jelenlegi állapot és roadmap

Az alábbi táblázat az aktuális kódbázis megvalósítási állapotát mutatja. Nem írja felül a fenti, kötelező navigációs és tudásmodell-szerződést.

| Terület | Állapot |
| --- | --- |
| PDF-import, app-private tárolás, strukturált AI-chunkolás | Működik helyi módban. |
| Helyi ObjectBox dokumentum-, chunk-, embedding- és chat-tárolás | Működik. |
| Szemantikus vektoros visszakeresés és hivatkozás-ellenőrzés | Működik. |
| Opcionális groundedness-ellenőrzés | Működik, beállításból kapcsolható. |
| Flowchart entitások, validáció és egyszerű szerkesztés | Részben működik. |
| Önálló saját jegyzetek, fogalmak és általános `KnowledgeEdge` gráf | Kötelező termékmodell; a jelenlegi kódban még megvalósítandó. |
| Kézi és félautomata chunk-szerkesztő | Tervezett. |
| Külön OCR-folyamat és bizonytalansági kezelés | Tervezett. |
| Dokumentummappák, kijelöléses batch műveletek, PDF-nézegető | Tervezett. |
| Chunk-export/import és offline, nem LLM-alapú keresés | Tervezett. |
| Gemini és hangalapú STT/TTS mód | Tervezett. |
| Szerveres Qdrant/PostgreSQL/Guardrails futtatás | Prototípus a repóban, nem az APK alapértelmezett útvonala. |

## Projektstruktúra

~~~text
lib/
  main.dart                 Alkalmazásindítás és függőségek összeállítása
  src/chat/                 Beszélgetések, üzenetek, hivatkozások és chat UI
  src/knowledge/            Dokumentumimport, feldolgozás és tudástár UI
  src/rag/                  Vektorkeresés, forrásbizonyíték és hivatkozás-ellenőrzés
  src/local_store/          ObjectBox entitások és adatbázisnyitás
  src/openai/               OpenAI kliens és strukturált API-szerződések
  src/flowchart/            Folyamatábra-modellek, validáció és szerkesztők
  src/settings/             Beállítások és biztonságos kulcstárolás
  src/debug/                Alkalmazáson belüli debug konzol
backend/
  app/                      FastAPI, RAG-prototípus, indexelés és guardrails
  tests/                    Backendtesztek
test/                       Flutter egység- és widgettesztek
android/, ios/, web/, linux/, macos/, windows/
                            Flutter platformprojekt-fájlok
.github/workflows/          Online Android build workflow
~~~

## Fejlesztés és ellenőrzés

A Flutter-projekt fejlesztési célplatformja Android, de Flutter platformmappák más célrendszerekhez is jelen vannak. Termux/Android ARM64 alatt a Flutter teszt és az elemzés Ubuntu proot környezetben fusson:

~~~bash
proot-distro login ubuntu -- bash -lc \
  'cd /data/data/com.termux/files/home/ubuntu/flutteruser/flutterapps/djinn && \
   /home/flutteruser/flutter/bin/flutter pub get && \
   /home/flutteruser/flutter/bin/flutter analyze && \
   /home/flutteruser/flutter/bin/flutter test'
~~~

Helyi APK-build Termuxon nem támogatott. Android APK-t GitHub Actionsben kell építeni és onnan letölteni. A tesztek fiktív OpenAI-klienst használnak, ezért alapesetben nem indítanak élő API-hívást és nem fogyasztanak szolgáltatói kreditet.

## Dokumentációs szabály

Ez a README tartalmazza a termék általános célját, architektúráját, aktuális állapotát és fejlesztési irányát. Részletes jövőbeli változtatáshoz a munka előtt új, célhoz kötött specifikáció és implementációs terv készülhet, de nem írhatja felül ezt a kanonikus termékmeghatározást hallgatólagosan.
