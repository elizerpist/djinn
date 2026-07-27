# Universe alsó navigációs belépési pont – design specifikáció

**Dátum:** 2026-07-27
**Állapot:** felhasználó által jóváhagyott irány

## Cél

A korábban csak hash URL-en elérhető Universe Morph tesztképernyő kapjon látható belépési pontot a mobil alsó navigációjában.

## Elhelyezés és viselkedés

- A meglévő hat navigációs elem megmarad.
- Új, hetedik elem kerül a `Workspace` és az `Én` közé.
- A felirat: `Universe`.
- Az ikon: `◉`.
- Koppintáskor a meglévő `#universe-morph-test` hash route nyílik meg.
- Az `Universe` elem kizárólag ezen a route-on kap `is-active` állapotot.
- A Universe képernyő vissza gombja továbbra is a Workspace-felfedezés nézetbe visz; a bottom nav nem kap további állapot- vagy route-logikát.

## Hatókör és korlátok

- Csak az `index.html` alsó navigációs markupját, valamint szükség esetén az aktív-nav route leképezését módosítjuk.
- A Universe Morph képernyő, annak renderkódja, mock adatai és animációi változatlanok maradnak.
- Nem módosul a meglévő Explore galaxis-orb, a Workspace dropdown, a breadcrumb, a kereső vagy más production képernyő.
- Nem jön létre új WebGL context vagy új route; a gomb kizárólag a már létező route-ra navigál.

## Elfogadási checklist

| ID | Követelmény | Kódterület | Ellenőrzés | Állapot |
| --- | --- | --- | --- | --- |
| UNAV-01 | `Universe` menüpont a Workspace és Én között jelenik meg | `index.html` bottom nav | markup + mobil screenshot | NOT DONE |
| UNAV-02 | a menüpont a `#universe-morph-test` képernyőt nyitja | közös `data-route` delegálás | route teszt | NOT DONE |
| UNAV-03 | a kiválasztott állapot csak Universe route-on aktív | `app.js` active-nav | route teszt + screenshot | NOT DONE |
| UNAV-04 | a meglévő hat menüpont viselkedése nem változik | nav markup + app route logika | diff review + manuális | NOT DONE |
