# Explore felfedezési dashboard – design specifikáció

**Dátum:** 2026-07-28

## Cél

Az Explore képernyő ne a Workspace dokumentum- és jegyzetlistáját másolja, hanem azt válaszolja meg: **„Mit érdemes most felfedeznem?”**

## Információs hierarchia

1. Az Explore fejléc és a három meglévő tab változatlanul marad.
2. Az élő galaxis/bolygó előnézet marad a képernyő első vizuális belépési pontja.
3. A galaxis alatt jelenik meg a prioritás szerinti felfedezési feed:
   - **Mai felfedezés:** egy kiemelt, rövid insight: új vagy erős kapcsolat, magyarázattal és navigációs CTA-val.
   - **Folytasd, ahol abbahagytad:** 2–3 korábbi fókuszpont vagy tudásútvonal.
   - **Érdekes kapcsolatok:** erős vagy meglepő Atom–Atom hidak, a strukturális evidence rövid indoklásával.
   - **Tudásutak:** rövid, olvasható Atom-sorozatok, amelyek az Explore/Universe nézethez vezetnek.
   - **Növekvő témák:** vízszintes community chipek új anyaggal vagy új kapcsolatokkal.

## Tabok

| Tab | Tartalom |
| --- | --- |
| Áttekintés | A teljes discovery feed a fenti sorrendben. |
| Fogalmak | Rangolt atomlista: fontosság, frissesség, közösség szerinti chipek és rövid kontextus. |
| Kapcsolatok | Kiemelt hidak, közösségek közötti kapcsolatok és új/erős edge-ek. |

A mostani prototípusban mindhárom tab mock, determinisztikus adatokkal működhet. Tabváltás ne route-váltás legyen.

## Interakció

- A „Mai felfedezés”, a kapcsolat- és útvonal-kártyák a meglévő `workspace-topic-connections` tudástérképre vezetnek.
- A galaxisablak saját expand/collapse viselkedése megmarad.
- A `Universe` bottom-nav új tesztnézete és a Workspace funkciói változatlanok maradnak.

## Vizuális irány

- A képernyő háttere marad világos, puha lila-neutralitással.
- A galaxisablak marad mélylila-fekete, mint vizuális portál.
- A discovery feed világos kártyákból épül, egyetlen erősebb lila fókuszkártyával.
- A kapcsolatok és útvonalak színe a Djinn lila–levendula palettából jön; ne legyen sok, versengő telített szín.
- A dokumentum- és forrás-metaadat másodlagos; az Atomok és kapcsolataik kerülnek előtérbe.

## Korlátok

- Nem módosul a Workspace, a `Megjelenítés` dropdown, a bottom-nav, a Universe Morph tesztképernyő és az Explore galaxis-orb renderkódja.
- Nem készül backend, adatbázis-lekérdezés vagy új adatmodell.
- Nem kerül a képernyőre teljes jegyzet-, forrás- vagy fájllista.

## Elfogadási checklist

| ID | Követelmény | Kódterület | Ellenőrzés | Állapot |
| --- | --- | --- | --- | --- |
| EXP-01 | A galaxisablak az Explore elsődleges vizuális belépési pontja marad | `screens/explore.html` | meglévő galaxisblokk változatlan; Android screenshot még szükséges | PARTIAL |
| EXP-02 | Áttekintésen Mai felfedezés, Folytasd, Érdekes kapcsolatok, Tudásutak és Növekvő témák látszanak | Explore markup/CSS | static markup teszt sikeres; Android screenshot még szükséges | PARTIAL |
| EXP-03 | Fogalmak és Kapcsolatok tabok route-váltás nélkül cserélik a helyi contentet | Explore JS | lokális tab-controller code review kész; kézi interakciós teszt még szükséges | PARTIAL |
| EXP-04 | A discovery kártyák a meglévő tudástérképre vezetnek | közös `data-route` | static route-attribútum teszt sikeres; kézi click teszt még szükséges | PARTIAL |
| EXP-05 | Nem változik a Workspace, dropdown, Universe teszt vagy Explore orb logikája | scoped diff | célzott diff review kész; manuális regressziós teszt még szükséges | PARTIAL |
