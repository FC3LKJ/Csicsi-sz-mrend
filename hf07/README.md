# HF07 – Mentés és visszatöltés

## Fájlok és könyvtárak

- `mentes.sh`: tömörített mentés, SHA-256, metaadatok, retenció, zárolás és naplózás.
- `visszatoltes.sh`: listázás, SHA-256 ellenőrzés, biztonságos visszatöltés és `--proba`.
- `forras/teszt.txt`: próbaadat.
- `mentesek/`: az elkészült mentések helye.

Projektkönyvtár: `/home/csicsi/Dokumentumok/GitHub/Csicsi-sz-mrend/hf07`.

## Használat

A projekt `hf07` könyvtárából:

```bash
chmod +x mentes.sh visszatoltes.sh
./mentes.sh "$PWD/forras" "$PWD/mentesek" 7
./visszatoltes.sh "$PWD/mentesek" --lista
./visszatoltes.sh "$PWD/mentesek" --proba --legutobbi "$PWD/vissza"
./visszatoltes.sh "$PWD/mentesek" --legutobbi "$PWD/vissza"
```

Az archívum neve `mentes-ÉÉÉÉ-HH-NN-ÓÓPP.tar.gz`. A script egy percen belül nem ír felül korábbi mentést. A visszatöltés már létező célkönyvtárat nem ír felül. A `--proba` nem ír a visszatöltés célkönyvtárába.

## Cron – naponta 03:00

Cron-bejegyzés:

```cron
0 3 * * * /home/csicsi/Dokumentumok/GitHub/Csicsi-sz-mrend/hf07/mentes.sh /home/csicsi/Dokumentumok/GitHub/Csicsi-sz-mrend/hf07/forras /home/csicsi/Dokumentumok/GitHub/Csicsi-sz-mrend/hf07/mentesek 7 >> /home/csicsi/Dokumentumok/GitHub/Csicsi-sz-mrend/hf07/mentesek/cron.log 2>&1
```

A bejegyzés telepítése: `crontab -e`. Ellenőrzés: `crontab -l`. A futás naplója a `mentesek/mentes.log` fájlba kerül.

## Mentési napló – tesztkimenet

Tesztkörnyezetben rögzített naplórészlet:

```text
2026-11-08 19:42:04 INDUL: forrás=/tmp/tmp.sjK2zq2h58/src cél=/tmp/tmp.sjK2zq2h58/back megtart=7
2026-11-08 19:42:04 KESZ: mentes-2026-11-08-1942.tar.gz méret=149 bájt fájlok=1
2026-11-08 19:42:04 BEFEJEZVE
```

## Sérült archívum visszatöltése – tesztkimenet

Egy archívummásolat egy bájtjának módosítása utáni ellenőrzés:

```text
2026-11-08 19:42:04 ELLENŐRZÉS: mentes-2026-11-08-1942
mentes-2026-11-08-1942.tar.gz: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
2026-11-08 19:42:04 ELUTASÍTVA: hibás SHA-256: mentes-2026-11-08-1942
```

Az ellenőrzés sikertelensége miatt a visszatöltés nem kezdődött meg.

## További beadási ellenőrzések

- **Retenció:** 10 eltérő dátumú mentés után a 7 legújabb archívumnak kell megmaradnia. A dátum átírásakor a `.sha256` és `.meta` fájlneveket, valamint a `.sha256` belső fájlnevét is frissíteni kell.
- **Zárolás:** ha egy mentés már fut, a második példánynak `Már fut egy mentés.` üzenettel le kell állnia.
- **Próba:** `--proba` esetén a visszatöltési célmappa nem jöhet létre.
- **ShellCheck:** `shellcheck mentes.sh visszatoltes.sh` (siker esetén 0 kilépési kód).
- **Cron:** a valódi ütemezés és a `crontab -l` kimenet csak a felhasználó gépén ellenőrizhető.

A napló- és ellenőrzési részletek tesztkörnyezetből származnak. A helyi cron-futás és a további tesztek külön ellenőrizendők.
