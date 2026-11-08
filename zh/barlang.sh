
#!/bin/bash

# ==========================================
# BARLANG.SH - Chat naploelemzo
# ==========================================

# ---------- HIBAKEZELES ----------

hiba() {
    echo "Hiba: $*" >&2
    exit 2
}

sugo() {
    cat <<'EOF'
Hasznalat:
  ./barlang.sh NAPLO [KAPCSOLOK]

Kapcsolok:

  -h
      Segitseg megjelenitese.

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

  --fotervezo
      A top 3 foszervezo pontozas alapjan.
  
  --tuntetes
      A tuntetes datuma es idopontja.

Peldak:

  ./barlang.sh chatlog --attekintes
  ./barlang.sh chatlog --kivel Bertold_a_Kovacs
  ./barlang.sh chatlog --beszelgetes Bertold_a_Kovacs Hilda_a_Konyvtaros
  ./barlang.sh chatlog --export export
  ./barlang.sh chatlog --keres szerdan
  ./barlang.sh chatlog --keres szerdan --csak-privat
  ./barlang.sh chatlog --tol 2026-11-01 --ig 2026-11-30
  ./barlang.sh chatlog --csatorna "#kozos"
  ./barlang.sh chatlog --fotervezo
  ./barlang.sh chatlog --tuntetes
EOF
}

# ---------- ARGUMENTUMOK ----------

[[ $# -eq 0 ]] && {
    sugo
    exit 0
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
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

        -h)
            sugo
            exit 0
            ;;
            
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

        --fotervezo)
            MODE="fotervezo"
            shift
            ;;
        
        --tuntetes)
            MODE="tuntetes"
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


# ---------- 6. FOTERVEZO PONTOZAS ----------

if [[ "$MODE" == "fotervezo" ]]; then

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
    hour = substr(time, 2, 5)

    if (hour ~ /^[0-9][0-9]$/ && hour >= 1 && hour <= 3)
        night[sender]++

    lower = tolower(message)

    # 3. Szervezesre utalo szavak
    if (lower ~ /(tuntet|sztrajk|gyules|szavaz|kovetel|szervez)/)
        complaints[sender]++
}

END { 

        # Hajnali aktivitas
        n = night[u] * 2
        if (n > 10)
            n = 10

        # Privat uzenetek
        p = privates[u]
        if (p > 10)
            p = 10

        score = n + p

        printf "%s\t%.2f\t%.2f\t%d\t%d\n", \
            u, n, p, \
            night[u], privates[u]
    }
}
' "$logfile" |
sort -t "$(printf '\t')" -k2,2nr |
head -n 3 |
awk -F '\t' '

BEGIN {
    printf "\n========== TOP 3 FOSZERVEZO ==========\n\n"

    printf "%-20s %8s %8s %8s %8s\n",
        "Resztvevo", "Osszes", "Panasz", "Hajnali", "Privat"

    print "--------------------------------------------------------------------------"
}

{
    printf "%-20s %8.2f %8.2f %8.2f %8.2f\n",
        $1, $2, $3, $4, $5

    printf "  Alapadatok: panasz=%d, hajnali=%d, privat=%d\n\n",
        $7, $8, $9
}
'

fi

exit 0
