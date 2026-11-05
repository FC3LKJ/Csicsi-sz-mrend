
#!/bin/bash

# ==========================================
# HUTOOR.SH - Chat naploelemzo
# ==========================================

# ---------- HIBAKEZELES ----------

hiba() {
    echo "Hiba: $*" >&2
    exit 2
}

sugo() {
    cat <<'EOF'
Hasznalat:
  ./hutoor.sh NAPLO [KAPCSOLOK]

Kapcsolok:

  --help
      Segitseg megjelenitese.

  --attekintes
      A naplo statisztikaja.

  --kivel NEV
      Egy felhasznalo osszes uzenete.

  --beszelgetes A B
      Ket felhasznalo privat beszelgetese idorendben.

  --export MAPPA
      Resztvevonkent kulon fajlba exportal.

  --keres MINTA
      Szovegkereses (kis/nagybetu fuggetlen, regex).

  --tol DATUM
      Kereses kezdodatuma (YYYY-MM-DD).

  --ig DATUM
      Kereses vegdatum (YYYY-MM-DD).

  --csatorna NEV
      Csatorna szerinti szures.

  --csak-privat
      Csak privat uzenetek.

  --gyanustott
      A top 3 gyanusitott pontozas alapjan.

Peldak:

  ./hutoor.sh chat.log --attekintes
  ./hutoor.sh chat.log --kivel Bence_305
  ./hutoor.sh chat.log --beszelgetes Bence_305 Zsofi_310
  ./hutoor.sh chat.log --export export
  ./hutoor.sh chat.log --keres sajt
  ./hutoor.sh chat.log --keres sajt --csak-privat
  ./hutoor.sh chat.log --tol 2026-03-01 --ig 2026-03-31
  ./hutoor.sh chat.log --csatorna "#konyha"
  ./hutoor.sh chat.log --gyanustott
EOF
}

# ---------- ARGUMENTUMOK ----------

[[ $# -eq 0 ]] && {
    sugo
    exit 0
}

if [[ "$1" == "--help" ]]; then
    sugo
    exit 0
fi

logfile="$1"
shift

[[ -f "$logfile" ]] || hiba "Nem talalhato a naplofajl: $logfile"
[[ -r "$logfile" ]] || hiba "A naplofajl nem olvashato."

MODE="attekintes"

KIVEL=""
A=""
B=""
MAPPA=""
MINTA=""
TOL=""
IG=""
CSATORNA=""
CSAK_PRIVAT=0

while [[ $# -gt 0 ]]; do
    case "$1" in

        --help)
            sugo
            exit 0
            ;;

        --attekintes)
            MODE="attekintes"
            shift
            ;;

        --kivel)
            [[ $# -ge 2 ]] || hiba "Hianyzik a nev a --kivel utan."
            MODE="kivel"
            KIVEL="$2"
            shift 2
            ;;

        --beszelgetes)
            [[ $# -ge 3 ]] || hiba "Ket nev szukseges."
            MODE="beszelgetes"
            A="$2"
            B="$3"
            shift 3
            ;;

        --export)
            [[ $# -ge 2 ]] || hiba "Hianyzik a mappa."
            MODE="export"
            MAPPA="$2"
            shift 2
            ;;

        --keres)
            [[ $# -ge 2 ]] || hiba "Hianyzik a keresesi minta."
            MODE="keres"
            MINTA="$2"
            shift 2
            ;;

        --tol)
            [[ $# -ge 2 ]] || hiba "Hianyzik a datum."
            TOL="$2"
            shift 2
            ;;

        --ig)
            [[ $# -ge 2 ]] || hiba "Hianyzik a datum."
            IG="$2"
            shift 2
            ;;

        --csatorna)
            [[ $# -ge 2 ]] || hiba "Hianyzik a csatorna neve."
            CSATORNA="$2"
            shift 2
            ;;

        --csak-privat)
            CSAK_PRIVAT=1
            shift
            ;;

        --gyanustott)
            MODE="gyanustott"
            shift
            ;;

        *)
            hiba "Ismeretlen kapcsolo: $1"
            ;;
    esac
done

# Datum ellenorzese

for datum in "$TOL" "$IG"; do
    if [[ -n "$datum" ]]; then
        [[ "$datum" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
            hiba "Hibas datumformatum: $datum"
    fi
done

# ---------- KOZOS UZENETFELDOLGOZO ----------

# A naplo ket formatuma:
#
# 2026-03-11T22:41:08 #emelet3 <Kata_312> szoveg
#
# 2026-03-12T09:02:11 @Kata_312 -> @Zsofi_310 : szoveg


# ---------- 1. ATTEKINTES ----------

if [[ "$MODE" == "attekintes" ]]; then

awk '
function parse(line, a, n, p) {
    delete a
    n = split(line, a, /[[:space:]]+/)

    time = a[1]
    channel = ""
    sender = ""
    recipient = ""
    message = ""
    type = ""

    if (a[2] ~ /^#/) {
        type = "channel"
        channel = a[2]
        sender = a[3]
        gsub(/[<>]/, "", sender)

        message = line
        sub(/^[^ ]+[[:space:]]+#[^ ]+[[:space:]]+<[^>]+>[[:space:]]*/, "", message)

    } else if (a[2] ~ /^@/ && a[3] == "->") {
        type = "private"
        sender = a[2]
        recipient = a[4]

        gsub(/^@/, "", sender)
        gsub(/^@/, "", recipient)

        p = index(line, ": ")
        if (p > 0)
            message = substr(line, p + 2)
    } else {
        return 0
    }

    return 1
}

{
    if (!parse($0))
        next

    total++

    if (type == "private")
        privat++

    if (!(sender in users))
        resztvevok++

    users[sender]++

    if (type == "private")
        users[recipient]++

    if (!(sender in first_seen)) {
        first_seen[sender] = 1
    }

    if (first == "" || time < first)
        first = time

    if (last == "" || time > last)
        last = time

    if (type == "channel")
        channels[channel]++
}

END {
    printf "\n========== ATTEKINTES ==========\n\n"

    printf "Osszes uzenet:       %d\n", total
    printf "Privat uzenet:       %d\n", privat
    printf "Csatornauzenet:      %d\n", total - privat
    printf "Resztvevok szama:    %d\n", length(users)

    printf "Elso uzenet:         %s\n", first
    printf "Utolso uzenet:       %s\n", last

    printf "\n--- Resztvevok ---\n"
    printf "%-25s %10s\n", "Nev", "Uzenetek"
    print "--------------------------------------"

    for (u in users)
        printf "%-25s %10d\n", u, users[u]

    printf "\n--- Csatornak ---\n"
    printf "%-25s %10s\n", "Csatorna", "Uzenetek"
    print "--------------------------------------"

    for (c in channels)
        printf "%-25s %10d\n", c, channels[c]

    printf "\n"
}
' "$logfile"

fi


# ---------- 2. KI KINEK ----------

if [[ "$MODE" == "kivel" ]]; then

awk -v who="$KIVEL" '
{
    line = $0
    n = split(line, a, /[[:space:]]+/)

    sender = ""
    recipient = ""

    if (a[2] ~ /^#/) {
        sender = a[3]
        gsub(/[<>]/, "", sender)

    } else if (a[2] ~ /^@/) {
        sender = a[2]
        recipient = a[4]

        gsub(/^@/, "", sender)
        gsub(/^@/, "", recipient)
    } else {
        next
    }

    if (sender == who || recipient == who) {
        print line
        count++
    }
}

END {
    printf "\nTalalatok: %d\n", count
}
' "$logfile"

fi


# ---------- 3. BESZELGETES ----------

if [[ "$MODE" == "beszelgetes" ]]; then

awk -v auser="$A" -v buser="$B" '
{
    n = split($0, a, /[[:space:]]+/)

    if (a[2] !~ /^@/ || a[3] != "->")
        next

    sender = a[2]
    recipient = a[4]

    gsub(/^@/, "", sender)
    gsub(/^@/, "", recipient)

    if ((sender == auser && recipient == buser) ||
        (sender == buser && recipient == auser)) {
        print
        count++
    }
}

END {
    printf "\nPrivat uzenetek szama: %d\n", count
}
' "$logfile"

fi


# ---------- 4. EXPORT ----------

if [[ "$MODE" == "export" ]]; then

mkdir -p "$MAPPA" || hiba "Nem sikerult letrehozni a mappat."

awk -v dir="$MAPPA" '
{
    n = split($0, a, /[[:space:]]+/)

    sender = ""
    recipient = ""

    if (a[2] ~ /^#/) {
        sender = a[3]
        gsub(/[<>]/, "", sender)

    } else if (a[2] ~ /^@/) {
        sender = a[2]
        recipient = a[4]

        gsub(/^@/, "", sender)
        gsub(/^@/, "", recipient)
    } else {
        next
    }

    if (sender != "") {
        file = sender
        gsub(/[^a-zA-Z0-9_.-]/, "_", file)
        print $0 >> (dir "/" file ".log")
        close(dir "/" file ".log")
    }

    if (recipient != "") {
        file = recipient
        gsub(/[^a-zA-Z0-9_.-]/, "_", file)
        print $0 >> (dir "/" file ".log")
        close(dir "/" file ".log")
    }
}

END {
    print "Exportalas kesz."
}
' "$logfile"

fi


# ---------- 5. KERESES ----------

if [[ "$MODE" == "keres" ]]; then

awk \
-v pattern="$MINTA" \
-v tol="$TOL" \
-v ig="$IG" \
-v channel="$CSATORNA" \
-v onlyprivate="$CSAK_PRIVAT" '

BEGIN {
    IGNORECASE = 1
    count = 0
}

{
    line = $0
    n = split(line, a, /[[:space:]]+/)

    time = a[1]
    date = substr(time, 1, 10)

    sender = ""
    recipient = ""
    ch = ""
    type = ""

    if (a[2] ~ /^#/) {
        type = "channel"
        ch = a[2]
        sender = a[3]
        gsub(/[<>]/, "", sender)

    } else if (a[2] ~ /^@/ && a[3] == "->") {
        type = "private"
        sender = a[2]
        recipient = a[4]

        gsub(/^@/, "", sender)
        gsub(/^@/, "", recipient)

    } else {
        next
    }

    if (tol != "" && date < tol)
        next

    if (ig != "" && date > ig)
        next

    if (channel != "" && ch != channel)
        next

    if (onlyprivate && type != "private")
        next

    if (pattern != "" && tolower(line) !~ tolower(pattern))
        next

    print line
    count++
}

END {
    printf "\nTalalatok szama: %d\n", count
}
' "$logfile"

fi


# ---------- 6. GYANUSITOTT PONTOZAS ----------

if [[ "$MODE" == "gyanustott" ]]; then

awk '
{
    n = split($0, a, /[[:space:]]+/)

    sender = ""
    recipient = ""
    message = ""
    time = a[1]
    type = ""

    if (a[2] ~ /^#/) {
        type = "channel"
        sender = a[3]
        gsub(/[<>]/, "", sender)

        message = $0
        sub(/^[^ ]+[[:space:]]+#[^ ]+[[:space:]]+<[^>]+>[[:space:]]*/, "", message)

    } else if (a[2] ~ /^@/ && a[3] == "->") {
        type = "private"
        sender = a[2]
        recipient = a[4]

        gsub(/^@/, "", sender)
        gsub(/^@/, "", recipient)

        p = index($0, ": ")
        if (p > 0)
            message = substr($0, p + 2)

    } else {
        next
    }

    users[sender]++
    total++

    # 1. Privat uzenetek szama
    if (type == "private")
        privates[sender]++

    # 2. Hajnali aktivitas (01:00-03:59)
    hour = substr(time, 12, 2)

    if (hour ~ /^[0-9][0-9]$/ && hour >= 1 && hour <= 3)
        night[sender]++

    lower = tolower(message)

    # 3. Panaszok felismerese
    if (lower ~ /(panasz|elegem|ideges|bosszant|szar|rossz|megint|miert|miért)/)
        complaints[sender]++

    # 4. Kerdes nelkuli mentegetozes
    if (
        lower ~ /(nem en|nem én|nem voltam|azt hittem|nem tudtam|elfelejt|bocs|ne haragudj|veletlen|véletlen|csak)/ &&
        index(message, "?") == 0
    )
        excuses[sender]++
}

END {
    # Atlagos panaszarany
    for (u in users) {
        rate = complaints[u] / users[u]
        avg += rate
        count++
    }

    if (count > 0)
        avg /= count

    for (u in users) {

        rate = complaints[u] / users[u]

        # Kevés panasz
        low = 0

        if (avg > 0 && rate < avg)
            low = (avg - rate) / avg * 5

        if (low > 5)
            low = 5

        # Hajnali aktivitas
        n = night[u] * 2
        if (n > 10)
            n = 10

        # Mentegetozes
        e = excuses[u] * 3
        if (e > 15)
            e = 15

        # Privat uzenetek
        p = privates[u]
        if (p > 10)
            p = 10

        score = low + n + e + p

        printf "%s\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d\t%d\t%d\n", \
            u, score, low, n, e, p, \
            complaints[u], night[u], excuses[u], privates[u]
    }
}
' "$logfile" |
sort -t "$(printf '\t')" -k2,2nr |
head -n 3 |
awk -F '\t' '

BEGIN {
    printf "\n========== TOP 3 GYANUSITOTT ==========\n\n"

    printf "%-20s %8s %8s %8s %8s %8s\n",
        "Resztvevo", "Osszes", "Panasz", "Hajnali", "Menteget", "Privat"

    print "--------------------------------------------------------------------------"
}

{
    printf "%-20s %8.2f %8.2f %8.2f %8.2f %8.2f\n",
        $1, $2, $3, $4, $5, $6

    printf "  Alapadatok: panasz=%d, hajnali=%d, mentegetozes=%d, privat=%d\n\n",
        $7, $8, $9, $10
}
'

fi

exit 0
