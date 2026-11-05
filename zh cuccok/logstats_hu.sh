# Futtatás a Bash értelmezővel.
#!/usr/bin/env bash
# Szigorú hibakezelés: hiba esetén leáll, nem definiált változó hiba, pipe-hiba figyelése.
set -euo pipefail
# A pipe az ugye az Altgr + W: | 
# A pipe arra való, hogy az egyik parancs kimenetét a másik parancs bemeneteként használjuk.
# A set -e azt jelenti, hogy ha bármelyik parancs hibát jelez, a script leáll.
# A set -u azt jelenti, hogy ha egy nem definiált változót próbálunk használni, az hiba lesz.
# A set -o pipefail azt jelenti, hogy ha egy pipe-ban bármelyik parancs hibát jelez, az egész pipe hibának számít.
# Az alapértelmezett viselkedése a pipe-nak az, hogy csak az utolsó parancs visszatérési értékét nézi, és ha az sikeres, akkor a pipe sikeresnek számít, függetlenül attól, hogy az előző parancsok hibát jeleztek-e.
# A set -o pipefail ezt megváltoztatja, és ha bármelyik parancs hibát jelez, az egész pipe hibának számít.

# Alapértelmezett naplófájl.
LOG="access.log"
# Opcionális kimeneti fájl az utolsó összefoglaló mondatnak.
OUTPUT=""
# Alapértelmezett toplistahossz.
TOP=10
# 0: teljes riport; 1: csak összefoglaló.
QUIET=0
# Itt tároljuk az utolsó kiírt mondatot.
SUMMARY=""

# Hibakezelő függvény.
fail() {
# Hibaüzenet kiírása a standard hibakimenetre.
    printf '%s\n' "$1" >&2
# Kilépés hibakóddal.
    exit 2
}

# Súgó szöveg kiírása.
usage() {
# Több soros súgó.
# Ez itt gyakorlatilag egy ideiglenes fájl, amit a cat parancs olvas be, és kiír a standard kimenetre.
    cat <<EOF
Usage: $0 [-q] [-f FILE] [-o FILE] [-t N]
  -q, --quiet       Csak az utolsó összefoglaló mondat
  -f, --file FILE   Bemeneti access log
  -o, --output FILE Az összefoglaló mentése fájlba
  -t, --top N       Toplista hossza
EOF
# Sikeres kilépés.
    exit 0
}

# Amíg van feldolgozatlan argumentum.
while (($#)); do
# Az aktuális kapcsoló vizsgálata.
    case "$1" in
# Csendes mód kapcsoló.
        -q|--quiet)
# Csendes mód bekapcsolása.
            QUIET=1
# A feldolgozott argumentum eltávolítása.
            shift
# Eset vége.
            ;;
# Súgó kapcsoló.
        -h|--help)
# Súgó kiírása és kilépés.
            usage
            ;;
# Bemeneti fájl kapcsoló.
        -f|--file)
# Kötelező fájlnév ellenőrzése.
            (($# >= 2)) || fail "Missing input filename."
# A naplófájl beállítása.
            LOG="$2"
# Kapcsoló és érték eltávolítása.
            shift 2
            ;;
# Kimeneti fájl kapcsoló.
        -o|--output)
# Kötelező fájlnév ellenőrzése.
            (($# >= 2)) || fail "Missing output filename."
# Kimeneti fájl beállítása.
            OUTPUT="$2"
            shift 2
            ;;
# Toplista hosszának kapcsolója.
        -t|--top)
# Kötelező érték ellenőrzése.
            (($# >= 2)) || fail "Missing top-list length."
# Csak pozitív egész szám elfogadása.
            [[ "$2" =~ ^[1-9][0-9]*$ ]] ||
# Hiba pozitív egész nélkül.
                fail "Top-list length must be a positive integer."
# Toplista hosszának beállítása.
            TOP="$2"
            shift 2
            ;;
# Ismeretlen kapcsoló.
        *)
# Hibás argumentum kezelése.
            fail "Unknown option or argument: $1"
            ;;
# case lezárása.
    esac
# while lezárása.
done

# A napló létezésének és olvashatóságának ellenőrzése.
[[ -r "$LOG" && -f "$LOG" ]] ||
    fail "Input file is not readable or does not exist: $LOG"

# A bemenet felülírásának megakadályozása.
[[ -z "$OUTPUT" || "$OUTPUT" != "$LOG" ]] ||
    fail "Output file must not be the same as the input file."

# 1. riport: egyedi IP-címek száma.
report_unique_ips() {
# A függvény argumentumának mentése.
    local file="$1"
# Címsor kiírása.
    printf '%s\n' "=== Unique IPs ==="
# AWK riport.
    awk '
# Csak nem üres sorok.
        NF {
# Az első mező, az IP, kulcsként való rögzítése.
            ip[$1]
        }
# Feldolgozás után.
        END {
# A tömb kulcsainak száma = egyedi IP-k száma.
            printf "Unique IPs: %d\n", length(ip)
        }
# AWK futtatása a naplófájlon.
    ' "$file"
}

# 2. riport: legaktívabb IP-címek.
report_top_ips() {
    local file="$1"
# Hány elem jelenjen meg.
    local top="$2"
    printf '\n%s\n' "=== Top $top active IPs ==="
# A Bash változó átadása az AWK-nak.
    awk -v top="$top" '
        NF {
# Kérések számolása IP-nként.
            count[$1]++
# Összes kérés számolása.
            total++
        }
        END {
# Rekordszámláló.
            n = 0
# Összes IP végigvétele.
            for (ip in count)
# Szám és IP tárolása egy rekordban.
                rows[n++] = count[ip] SUBSEP ip

# Egyszerű csökkenő rendezés.
            for (i = 0; i < n; i++) {
                for (j = i + 1; j < n; j++) {
# Rekord szétbontása.
                    split(rows[i], a, SUBSEP)
                    split(rows[j], b, SUBSEP)
# Csere, ha a második nagyobb.
                    if (b[1] + 0 > a[1] + 0) {
                        tmp = rows[i]
                        rows[i] = rows[j]
                        rows[j] = tmp
                    }
                }
            }

# Ne próbáljon többet kiírni, mint amennyi van.
            limit = (n < top ? n : top)
            for (i = 0; i < limit; i++) {
                split(rows[i], a, SUBSEP)
# IP, kérésszám és százalék formázása.
                printf "%-20s %10d %8.2f%%\n",
# Nullával való osztás elkerülése.
                    a[2], a[1], total ? 100 * a[1] / total : 0
            }
        }
    ' "$file"
}

# 3. riport: státuszkódok darabszáma és százaléka.
report_status_codes() {
    local file="$1"
    printf '\n%s\n' "=== HTTP status codes ==="
    awk '
        {
# Az idézőjel megkeresése.
            q = index($0, "\"")
# Nincs idézőjel: sor kihagyása.
            if (!q) next
# Záró idézőjel keresése.
            r = index(substr($0, q + 1), "\"")
            if (!r) next
# A kérés utáni rész kivágása.
            rest = substr($0, q + r + 1)
# Vezető szóközök törlése.
            sub(/^[[:space:]]+/, "", rest)
# Mezőkre bontás.
            split(rest, f, /[[:space:]]+/)
# Státuszkód számmá alakítása.
            code = f[1] + 0
# Érvénytelen kód kihagyása.
            if (code < 100 || code > 599) next
# Kód megszámolása.
            status[code]++
# Érvényes kérések száma.
            total++
        }
        END {
            for (code in status)
# Darabszám és százalék kiírása.
                printf "HTTP %d: %d requests, %.2f%%\n",
                    code, status[code],
                    total ? 100 * status[code] / total : 0
        }
# Státuszkód szerinti numerikus rendezés.
    ' "$file" | sort -k2,2n
}

# 4. riport: 4xx és 5xx hibák, URL-enként.
report_errors() {
    local file="$1"
    local top="$2"
    printf '\n%s\n' "=== HTTP errors ==="
    awk '
        {
            q = index($0, "\"")
            if (!q) next
            r = index(substr($0, q + 1), "\"")
            if (!r) next
# Az idézett HTTP kérés kivágása.
            request = substr($0, q + 1, r - 1)
# Metódus, URL és protokoll szétválasztása.
            split(request, req, " ")
            rest = substr($0, q + r + 1)
            sub(/^[[:space:]]+/, "", rest)
            split(rest, f, /[[:space:]]+/)
            code = f[1] + 0
            if (code < 100 || code > 599) next
            total++
# 4xx hiba.
            if (code >= 400 && code < 500) {
# 4xx darabszám.
                err4++
# 4xx hibák URL-enként.
                url4[req[2]]++
            }
# 5xx hiba.
            if (code >= 500 && code < 600) {
# 5xx darabszám.
                err5++
# 5xx hibák URL-enként.
                url5[req[2]]++
            }
        }
        END {
            printf "4xx errors: %d (%.2f%%)\n",
                err4, total ? 100 * err4 / total : 0
            printf "5xx errors: %d (%.2f%%)\n",
                err5, total ? 100 * err5 / total : 0
            printf "\nTop URLs with 4xx errors:\n"
            for (url in url4)
                printf "%d %s\n", url4[url], url
            printf "\nTop URLs with 5xx errors:\n"
            for (url in url5)
                printf "%d %s\n", url5[url], url
        }
    ' "$file" |
# Csökkenő rendezés darabszám szerint.
    sort -k1,1nr |
# Két lista miatt a kétszeres korlát.
    head -n "$((top * 2))"
}

# 5. riport: óránkénti kérések és legforgalmasabb óra.
report_hourly() {
    local file="$1"
    printf '\n%s\n' "=== Hourly requests ==="
    awk '
        {
# Időbélyeg nyitó zárójele.
            l = index($0, "[")
            if (!l) next
# Záró zárójel.
            r = index(substr($0, l + 1), "]")
            if (!r) next
# Dátum és óra kivágása.
            hour = substr($0, l + 1, 13)
# Óránkénti számolás.
            count[hour]++
        }
        END {
            busiest = ""
            busiest_count = 0
            for (hour in count) {
                printf "%s: %d requests\n", hour, count[hour]
# Legnagyobb érték keresése.
                if (count[hour] > busiest_count) {
                    busiest = hour
                    busiest_count = count[hour]
                }
            }
            if (busiest != "")
# Legforgalmasabb óra kiírása.
                printf "Busiest hour: %s (%d requests)\n",
                    busiest, busiest_count
        }
# Időrendi rendezés.
    ' "$file" | sort
}

# 6. riport: átlagos válaszidő összesen, 200 és 500 kódokra.
report_response_times() {
    local file="$1"
    printf '\n%s\n' "=== Response times ==="
    awk '
        {
            q = index($0, "\"")
            if (!q) next
            r = index(substr($0, q + 1), "\"")
            if (!r) next
            rest = substr($0, q + r + 1)
            sub(/^[[:space:]]+/, "", rest)
            split(rest, f, /[[:space:]]+/)
# Státuszkód.
            code = f[1] + 0
# Válaszidő a harmadik mezőben.
            time = f[3] + 0
            if (code < 100 || code > 599) next
            total++
# Összesített válaszidő.
            total_sum += time
            if (code == 200) {
                ok++
                ok_sum += time
            }
            if (code == 500) {
                server_error++
                server_error_sum += time
            }
        }
        END {
            printf "Average response time: %.3f s\n",
                total ? total_sum / total : 0
            printf "Average response time for HTTP 200: %.3f s\n",
                ok ? ok_sum / ok : 0
            printf "Average response time for HTTP 500: %.3f s\n",
                server_error ? server_error_sum / server_error : 0
        }
    ' "$file"
}

# Utolsó mondat előállítása és tárolása.
report_summary() {
    local file="$1"
# A kimenet változóba mentése.
    SUMMARY="$(awk '
        {
            q = index($0, "\"")
            if (!q) next
            r = index(substr($0, q + 1), "\"")
            if (!r) next
            rest = substr($0, q + r + 1)
            sub(/^[[:space:]]+/, "", rest)
            split(rest, f, /[[:space:]]+/)
            code = f[1] + 0
            if (code < 100 || code > 599) next
            total++
            if (code >= 400 && code < 500) err4++
            if (code >= 500 && code < 600) err5++
        }
        END {
            printf "In total %d requests, %d 4xx errors and %d 5xx errors.",
                total, err4, err5
        }
    ' "$file)"
# Az összefoglaló kiírása.
    printf '\n%s\n' "$SUMMARY"
}

# Összes riport futtatása.
run_reports() {
    local file="$1"
    local top="$2"
    report_unique_ips "$file"
    report_top_ips "$file" "$top"
    report_status_codes "$file"
    report_errors "$file" "$top"
    report_hourly "$file"
    report_response_times "$file"
    report_summary "$file"
}

# Csendes mód esetén csak összefoglaló.
if ((QUIET)); then
    report_summary "$LOG"
else
    run_reports "$LOG" "$TOP"
fi

# Az összefoglaló elérhetővé tétele a környezetben.
export SUMMARY
# Ez nem volt feladat végül.

# Ha van kimeneti fájl.
if [[ -n "$OUTPUT" ]]; then
# Az összefoglaló fájlba írása.
    printf '%s\n' "$SUMMARY" > "$OUTPUT"
fi
