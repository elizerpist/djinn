# Note Atom Search Design

## Cel

A keresoben es a chat valaszaiban a jegyzetekbol keszult talalatok legyenek pontosak, magyarazhatoak es interaktivak. A rendszer ne probalja kitalalni, hogy egy chunk "definicio", "terapia", "magyarazat" vagy barmilyen mas szerep. A chunkok a user altal letrehozott, szabad tartalmi egysegek. A keresesi motor feladata az, hogy strukturalt atomokat talaljon, azok kapcsolatait kovesse, es minden talalathoz megmutassa, miert kerult be.

Az AI ertelmezheti a talalatok jelentest. A keresesi es graph retegek csak visszakeresnek, kapcsolnak es indokolnak.

## Alapelvek

1. Nincsenek chunk kategoriak.
   A rendszer nem vezet be olyan szerepeket, mint `definition`, `therapy`, `facet`, `rule`, `explanation`. Ezek akkor sem valnak keresesi modda, ha a szovegben szerepel a "definicio", "terapia", `<`, `=`, vagy mas hasonlo jel.

2. A chunk szerkesztesi egyseg, az atom keresesi egyseg.
   A user chunkokat hoz letre es rendez. A keresesi index kisebb, megjelenitheto evidence atomokra bontja ezeket.

3. Minden talalat kap indokot.
   Ne csak score legyen. A UI-nak es az AI-nak is latszania kell, hogy a talalat direkt egyezes, jegyzeten beluli kaszkad, flowchart ag, tablazat oszlop, kulso direkt talalat, vagy mas magyarazhato kapcsolat miatt jott be.

4. A kaszkadnak hatara van.
   A fo jegyzeten belul mehet melyebb kapcsolati terjesztes. Mas jegyzetbol automatikusan csak direkt atom johet be. Ez gatolja meg, hogy egy altalanos szo, peldaul `oxigen`, behuzza az egesz app oxigenes tartalmat.

5. A teljes chunk kontextus opt-in.
   Ha egy chunk kevert tartalmu, peldaul bolognai mondatok es legzesi elegtelenseg mondatok vannak benne, akkor a keresesi talalat csak a relevans atomokat mutatja. A teljes chunkot a user kulon nyithatja meg kontextusnak.

## Evidence Atomok

Az indexelt evidence atom tipusa ezek egyike:

- `text_sentence`: szovegchunkbol szarmazo mondat vagy rovid szovegszegmens.
- `list_item`: lista chunk egy eleme.
- `table_cell`: tablazat egy cellaja, a hozza tartozo fejlecekkel.
- `table_row`: tablazat egy sora, ha a sor egesze a relevans bizonyitek.
- `flowchart_node`: flowchart node, peldaul dontes vagy process box.
- `flowchart_edge`: flowchart kapcsolat, ag vagy process kapcsolat.

Nem lesz `hidden_note_sentence` atom. A "Rejtett jegyzet:" szoveg nem kulon rendszerfogalom, hanem sima szoveg a chunkban, ezert `text_sentence` atomkent kezelendo.

## Talalati Indokok

Minden atomhoz egy vagy tobb indok tartozhat:

- `direct_query`: az atom szovege direkt egyezik a queryvel.
- `note_scope`: a talalat a primer jegyzet scope-jaban van.
- `chunk_title`: a chunk cime egyezik vagy segiti az egyezest.
- `list_item_match`: listaelemben tortent egyezes.
- `table_column`: tablazat oszlopfejlec segitette a talalatot.
- `table_cell`: cellaertekben tortent egyezes.
- `flowchart_branch`: flowchart dontesi ag aktivalt kapcsolatot.
- `process_link`: egy process node vagy edge miatt kerult be kapcsolt atom.
- `external_direct`: mas jegyzetbol szarmazo direkt query egyezes.

Ezek nem kategoriak es nem szemantikai szerepek. Ezek audit-indokok: azt irjak le, milyen uton kerult be az atom.

## Atomizalasi Szabalyok

### Szovegchunk

A szovegchunk mondatokra vagy rovid szovegszegmensekre bomlik. Minden atom megtartja:

- a note azonositojat,
- a chunk azonositojat,
- a chunk cimet,
- a forras poziciojat vagy offsetjet,
- es egy hivatkozast, amivel a teljes chunk megnyithato.

Pelda: ha egy szovegchunkban van bolognai receptmondat es legzesi elegtelenseg definicio jellegu mondat, akkor `bolognai` kereseskor csak a bolognai mondat atomjai jelennek meg alapbol.

### Listachunk

A lista minden eleme kulon `list_item` atom. A lista cime es a jegyzet scope-ja metadata. A teljes lista csak akkor nyilik meg, ha a user keri.

Pelda: ha ugyanabban a listaban van `bolognai hozzavalok`, `DO2 = oxigenkinalat` es `VO2 = oxigenigeny`, akkor `bolognai` kereseskor csak a bolognai listaelem direkt talalat. A DO2/VO2 elemek nem jelennek meg, hacsak nincs direkt egyezes, tag vagy mas explicit kapcsolat.

### Tablazat

A tablazat atomizalasa nem elegedhet meg a cella nyers ertekevel. Egy `table_cell` keresheto szovege:

`[chunk title] + [row header] + [column header] + [cell value]`

Ez azert kell, mert egy cella erteke lehet csak `O2`, mikozben a jelentese az oszlopfejlecbol derul ki, peldaul `sulyos legzesi elegtelenseg`.

Pelda: ha a terapia tablazat egyik oszlopa `enyhe legzesi elegtelenseg`, a masik `sulyos legzesi elegtelenseg`, es a sulyos cellaban csak `O2` szerepel, akkor `sulyos legzesi elegtelenseg` kereseskor a sulyos cella jo talalat, mert az oszlopfejlec egyezik.

### Flowchart

A flowchart node-ok `flowchart_node`, a kapcsolatok `flowchart_edge` atomok. A dontesi agak es process kapcsolatok indokolt kaszkadot indithatnak a primer jegyzeten belul.

Pelda: `sulyos legzesi elegtelenseg` kereseskor a flowchart `sulyos? igen` aga aktiv lehet. Ha ez az ag `Oxigen` process node-ba vezet, akkor a primer jegyzeten beluli oxigenhez kapcsolodo tablazat atomjai behuzhatoak `process_link` indokkal.

## Query Scope Es Kaszkad

### Altalanos tema

Query: `legzesi elegtelenseg`

Elvart mukodes:

- a `Legzesi elegtelenseg` jegyzet primer scope-pa valik,
- a jegyzet relevans chunkjai es atomjai csoportositva megjelennek,
- mas jegyzetbol csak direkt atomok jonnek be,
- a kulso talalat nem indit automatikus mely kaszkadot.

### Pontositott tema

Query: `legzesi elegtelenseg definicio`

Elvart mukodes:

- a rendszer nem kezeli a `definicio` szot szerepkent vagy kategoriakent,
- direkt szovegegyezes es kapcsolt atomok jonnek be,
- ha a definicio jellegu szovegben `DO2 < VO2` szerepel, es ugyanabban a primer jegyzetben van `DO2 = oxigenkinalat` es `VO2 = oxigenigeny`, ezek behuzhatoak kaszkaddal,
- nem jon be az egesz jegyzet,
- nem jon be kulso, csak tavolrol kapcsolodo pelda, peldaul Berodual, ha nincs direkt egyezes.

### Allapot onmagaban

Query: `sulyos`

Elvart mukodes:

- ez tul altalanos ahhoz, hogy automatikusan mely kaszkad induljon,
- a rendszer direkt talalatokat csoportosit,
- a user valaszthat egy talalatot, peldaul a `sulyos` flowchart agat vagy egy tablazat oszlopot,
- csak a user valasztasa utan indul uj scope.

### Allapot plusz tema

Query: `sulyos legzesi elegtelenseg`

Elvart mukodes:

- a primer jegyzetben aktiv a sulyos legzesi elegtelenseghez tartozo flowchart ag,
- a flowchartbol kovetkezo `Oxigen` process behuzhatja a primer jegyzet relevans tablazat atomjait,
- a sulyos oszlop akkor is talalat, ha a cellaban csak `O2` szerepel, mert az oszlopfejlec egyezik,
- az enyhe oszlop oxigenes cellaja is megjelenhet, ha a primer jegyzeten beluli process kapcsolat oda vezet, de mas indokkal, peldaul `process_link`,
- mas jegyzetbol a Berodual indikacio megjelenhet, ha direkt tartalmazza a `sulyos legzesi elegtelenseg` kifejezest,
- mas jegyzetek altalanos oxigenes tartalmai nem jelennek meg automatikusan.

## Kulso Jegyzetek Szabalya

Kulso jegyzetbol alapbol csak direkt atom johet be. Ez lehet peldaul:

- gyogyszertablazatban `Berodual` sor,
- indikacio cella: `sulyos legzesi elegtelenseg`,
- vagy barmely mas atom, amely kozvetlenul egyezik a queryvel.

Kulso direkt talalat nem indit tovabbi automatikus kaszkadot. Ha a user ranyit egy kulso atomra vagy uj scope-ot indit belole, akkor mar lehet kulon keresesi utvonal.

Pelda: `sulyos legzesi elegtelenseg` query nem huzhatja be az osszes mas jegyzetben levo `oxigen` tartalmat csak azert, mert a primer flowchartban az oxigen process kovetkezik. Ha a user az `Oxigen` talalatra koppint es uj scope-ot indit, akkor az mar `Oxigen`-scope, es akkor mas jegyzetek oxigenes atomjai is megjelenhetnek.

## Tagrendszer Kapcsolata

A tag nem kategoria, hanem user altal letrehozott kapcsolatjelolo. A tag azt mondja ki, hogy ket vagy tobb atom, chunk, node vagy szovegresz osszetartozik.

Pelda: ha a user azt akarja, hogy `bolognai` kereseskor a hozzavalok is megjelenjenek, akkor a hozzavalokat explicit taggel vagy kapcsolattal kell osszekotni a bolognai szoveggel. A keresomotor nem probalja automatikusan kitalalni a receptstruktura teljes jelentest.

## Chat UI

A chat UI ne csak lapos citation listat mutasson, hanem interaktiv talalati fat.

Javasolt hierarchia:

```text
Legzesi elegtelenseg
  Szoveg chunk
    "legzesi elegtelenseg, amikor DO2 < VO2"
      indok: direct_query, note_scope
  Magyarazat
    "DO2 = oxigenkinalat"
      indok: process_link vagy note_scope
    "VO2 = oxigenigeny"
      indok: process_link vagy note_scope
  Flowchart
    "Sulyos? igen -> Oxigen"
      indok: flowchart_branch, process_link
  Terapia tablazat
    "Sulyos legzesi elegtelenseg / O2"
      indok: table_column, table_cell
Mas jegyzetbol direkt talalat
  Gyogyszertablazat
    "Berodual indikacio: sulyos legzesi elegtelenseg"
      indok: external_direct
```

Minden talalati atomnal legyen:

- forras jegyzet,
- chunk cim,
- atom tipus,
- indok chipek,
- rovid szoveg,
- `teljes chunk megnyitasa`,
- `uj scope inditasa ebbol`,
- es citation/copy lehetoseg.

A teljes chunk megnyitasa kulon user dontes. Kevert chunk eseten az irrelevans reszek alapbol nem jelennek meg a valasz bizonyitekai kozott.

## Jelenlegi Mukodesbol Kiszedendo

A keresesi motorbol ki kell venni minden olyan heurisztikat, amely a kovetkezoket szemantikai szerepkent kezeli:

- `definicio`,
- `terapia`,
- `magyarazat`,
- `facet`,
- `<`,
- `=`,
- vagy hasonlo role/facet jel.

Ezek maradhatnak literal query tokenek vagy gyenge egyezesi jelek, de nem valthatnak keresesi modot. Ha szemantikai ertelmezes kell, azt az AI reteg vegezze a visszakapott atomokbol es indokokbol.

## Nem Cel

- Nem lesz chunk-hierarchia az elso lepesben.
- Nem lesz automatikus chunk-kategoria felismeres.
- Nem lesz app-szintu, korlatlan kaszkad.
- Nem lesz `hidden_note_sentence` atom.
- Nem kell a keresomotornak megtanulnia, hogy mi definicio, terapia, magyarazat, recept vagy indikacio.

## Elfogadasi Feltetelek

1. `bolognai` kereseskor alapbol csak a bolognai direkt atomok jelennek meg, nem a kevert chunk teljes, irrelevans tartalma.
2. `legzesi elegtelenseg` kereseskor a primer jegyzet csoportositva megjelenik, de kulso jegyzetekbol csak direkt atomok jonnek be.
3. `legzesi elegtelenseg definicio` kereseskor a `definicio` nem role filter, hanem query token; a DO2/VO2 kapcsolt atomok csak indokolt, primer jegyzeten beluli kaszkaddal jonnek be.
4. `sulyos` kereseskor nincs automatikus mely kaszkad; a usernek kell scope-ot valasztania.
5. `sulyos legzesi elegtelenseg` kereseskor a primer jegyzet flowchart aga es a kapcsolt tablazat atomjai megjelenhetnek, kulso oxigenes jegyzetek viszont nem jonnek be automatikusan.
6. Egy `O2` cella visszakeresheto, ha a tablazat oszlopfejlece tartalmazza a query relevans reszet.
7. Minden megjelenitett atomhoz latszik legalabb egy talalati indok.
8. A chat UI-ban a user atomrol atomra latja, mi miert kerult be, es kulon tud teljes chunkot nyitni vagy uj scope-ot inditani.
