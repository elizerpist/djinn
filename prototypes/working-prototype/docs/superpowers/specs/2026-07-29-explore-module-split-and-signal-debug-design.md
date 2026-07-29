# Explore modulbontás és jelút-diagnosztika

## Cél

A V5, V6 és V7 bolygónézetben a városkijelölés, a második tapos dehighlight és a Globe.gl arcs layer megbízhatóan működjön. A jelenlegi, túl nagy `assets/explore-galaxy-orb.js` felelősségei kisebb, önálló ESM modulokra válnak szét úgy, hogy a V5–V7 nem osztozik írható interakciós állapoton.

## Hatókör

- A V5–V7 highlight/dehighlight jelút javítása.
- A kijelölt város Globe.gl arcsData commitjának látható és visszaellenőrizhető kezelése.
- Körülbelül 100 px magas, görgethető, vágólapra másolható futásidejű debug-napló.
- Az Explore nagy fájl logikai bontása, elsődlegesen a V5–V7 útvonal körül.
- Az Universe és a knowledge-map bontása külön következő refaktorcsomag; ezek nem keverednek a működő Explore hibajavításba.

## Nem cél

- Node-layout, atompozíció, arc-geometria, kamera, címkestílus, community-logika vagy fénykarakter újratervezése.
- Új Globe/Three renderer, kamera, canvas vagy render loop létrehozása.
- V5–V7 UI-választóinak összevonása vagy implicit közös state létrehozása.

## Célarchitektúra

```text
assets/explore/
  planet-data.js                 # determinisztikus atom/él/layout/size számítás
  planet-variant-controller.js   # egy példány / V5, V6, V7: tap state machine
  planet-input-router.js         # pointer gesture → city ID, state nélkül
  planet-globe-arc-adapter.js    # selection adat → Globe arcsData commit/verify
  planet-signal-trace.js         # bounded, tiszta eseménynapló
  planet-debug-panel.js          # DOM panel + vágólap művelet
  planet-visuals.js              # V5/V6/V7 node context megjelenítés
assets/explore-galaxy-orb.js     # Globe bootstrap és a fenti modulok bekötése
```

### Állapothatárok

Minden V5-család változat `createPlanetVariantController(variant)` hívással saját controller-példányt kap. A controller kizárólag az adott mód `selectedCityId` és selection-adatát birtokolja. A `city-selection-arcs.js` csak tiszta, immutable selection payloadot állít elő.

### Jelút

`pointerdown/up` → `PlanetInputRouter` → city ID vagy elutasítás → adott variant controller `tap(cityId)` → `focus | replace | dehighlight` → `selectCityConnections` → `PlanetGlobeArcAdapter.commit` → `globe.arcsData(payload)` → commit-visszaolvasás → node visual refresh.

Minden határ struktúrált debug-eseményt ír: verzió, eseménytípus, city ID, gesture, selection darabszám, arc profile, commit eredmény és hiba.

### Globe arc commit szerződés

A V5/V6/V7 adapter minden változatban ugyanazt ellenőrzi:

1. A selection a saját controllerből érkezik.
2. A payload minden arcán valódi start/end lat/lng és explicit felszíni altitude szerepel.
3. Az adapter egyetlen `globe.arcsData(arcs)` commitot végez.
4. Commit után a getterből vagy adapter-owned snapshotból rögzíti az arcszámot.
5. Dehighlightnál kizárólag `arcsData([])` fut; régi arc nem maradhat a layeren.

## Hibatűrés és regresszióvédelem

- A pointer router nem tarthat selection state-et.
- A Globe adapter nem dönthet focusról.
- A debug panel olvassa, de nem módosíthatja a planet state-et.
- A trace maximum 200 sort tart meg; nem végez scene- vagy DOM-műveletet frame-enként.
- Minden új modul saját unit tesztet kap; a jelenlegi Explore modelltesztek az importokon át tovább futnak.

## Elfogadás

- V5/V6/V7-ben első tap után arany city + kontextus + arcok látszanak.
- Második tap ugyanarra a cityre minden módnál dehighlightol és kiüríti az arcokat.
- Más cityre tap váltja, nem összeadja a korábbi arcokat.
- A debug sáv részletesen mutatja az első és második tap teljes jelútját.
- A teljes napló egy gombbal másolható.
- A V5/V6/V7 közti váltás nem oszt meg írható pointer/focus/arc state-et.
