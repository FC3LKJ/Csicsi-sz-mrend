#!/usr/bin/env bash
set -euo pipefail

LOG="access.log"
OUTPUT=""
STATUS_CODE=""
TOP=10
QUIET=0

usage() {
    cat <<EOF
Használat: $0 [-q] [-h] [-f FILE] [-o FILE] [-s CODE] [-t N]

Kapcsolók:
  -q, --quiet       Csak az összesítő sor
  -h, --help        Használat
  -f, --file FILE   Bemeneti naplófájl
  -o, --output FILE Kimeneti fájl
  -s, --status CODE HTTP-státuszkód szerinti szűrés
  -t, --top N       Toplista hossza (alapértelmezés: 10)

Példák:
  $0 -f access.log
  $0 -f access.log -s 404
  $0 -f access.log -t 20
  $0 -f access.log -o logrep.txt
  $0 -f access.log -q
  $0 -f access.log -s 500 -q -o logrep.txt
EOF
}

fail() {
    printf 'Hiba: %s\n\n' "$1" >&2
    usage >&2
    exit 2
}

while (($#)); do
    case "$1" in
        -q|--quiet)
            QUIET=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -f|--file)
            (($# >= 2)) || fail "Hiányzó bemeneti fájlnév."
            [[ -n "$2" && "$2" != -* ]] ||
                fail "Érvénytelen bemeneti fájlnév."
            LOG="$2"
            shift 2
            ;;
        -o|--output)
            (($# >= 2)) || fail "Hiányzó kimeneti fájlnév."
            [[ -n "$2" && "$2" != -* ]] ||
                fail "Érvénytelen kimeneti fájlnév."
            OUTPUT="$2"
            shift 2
            ;;
        -s|--status)
            (($# >= 2)) || fail "Hiányzó HTTP-státuszkód."
            [[ "$2" =~ ^[1-5][0-9]{2}$ ]] ||
                fail "Érvénytelen HTTP-státuszkód."
            STATUS_CODE="$2"
            shift 2
            ;;
        -t|--top)
            (($# >= 2)) || fail "Hiányzó toplistahossz."
            [[ "$2" =~ ^[1-9][0-9]*$ ]] ||
                fail "A toplistahossz pozitív egész legyen."
            TOP="$2"
            shift 2
            ;;
        *)
            fail "Ismeretlen kapcsoló vagy argumentum: $1"
            ;;
    esac
done

[[ -r "$LOG" && -f "$LOG" ]] ||
    fail "A bemeneti fájl nem olvasható vagy nem létezik: $LOG"

[[ -z "$OUTPUT" || "$OUTPUT" != "$LOG" ]] ||
    fail "A kimeneti fájl nem lehet azonos a bemeneti fájllal."

report_status() {
    local file="$1" wanted="$2"

    awk -v wanted="$wanted" '
    {
        q=index($0,"\""); if (!q) next
        r=index(substr($0,q+1),"\""); if (!r) next
        rest=substr($0,q+r+1)
        sub(/^[[:space:]]+/,"",rest)
        split(rest,f,/[[:space:]]+/)
        code=f[1]+0
        if (code<100 || code>599) next
        total++
        if (code==wanted) count++
    }
    END {
        printf "HTTP %s: %d keres, %.2f%%\n",
            wanted,count,total?100*count/total:0
    }' "$file"
}

report_ip() {
    local file="$1" top="$2"

    awk '
    NF {
        count[$1]++
        total++
    }
    END {
        for (ip in count)
            printf "%d %s %.2f\n",
                count[ip],ip,total?100*count[ip]/total:0
    }' "$file" |
        sort -k1,1nr |
        awk -v top="$top" '
        NR <= top {
        printf "%-20s %10d %8s%%\n",$2,$1,$3
        }'
}

report_errors() {
    local file="$1"

    awk '
    {
        q=index($0,"\""); if (!q) next
        r=index(substr($0,q+1),"\""); if (!r) next
        rest=substr($0,q+r+1)
        sub(/^[[:space:]]+/,"",rest)
        split(rest,f,/[[:space:]]+/)
        code=f[1]+0
        if (code<100 || code>599) next
        total++
        if (code>=400 && code<500) err4++
        if (code>=500 && code<600) err5++
    }
    END {
        printf "4xx hibak: %d (%.2f%%)\n",
            err4,total?100*err4/total:0
        printf "5xx hibak: %d (%.2f%%)\n",
            err5,total?100*err5/total:0
    }' "$file"
}

report_error_urls() {
    local file="$1" wanted="$2" top="$3"

    awk -v wanted="$wanted" '
    {
        q=index($0,"\""); if (!q) next
        r=index(substr($0,q+1),"\""); if (!r) next
        request=substr($0,q+1,r-1)
        split(request,req," ")
        rest=substr($0,q+r+1)
        sub(/^[[:space:]]+/,"",rest)
        split(rest,f,/[[:space:]]+/)
        code=f[1]+0
        if (code<100 || code>599) next
        if (code>=400 && code<600 &&
            (wanted=="" || code==wanted))
            count[code SUBSEP req[2]]++
    }
    END {
        for (key in count) {
            split(key,p,SUBSEP)
            printf "%d %s %s\n",count[key],p[1],p[2]
        }
    }' "$file" |
        sort -k1,1nr |
        head -n "$top" |
        awk '{printf "%-8s %-30s %10d\n",$2,$3,$1}'
}

report_hourly() {
    local file="$1"

    awk '
    {
        l=index($0,"[")
        if (!l) next
        r=index(substr($0,l+1),"]")
        if (!r) next
        hour=substr($0,l+1,13)
        count[hour]++
    }
    END {
        for (hour in count)
            printf "%s %d\n",hour,count[hour]
    }' "$file" | sort
}

report_average() {
    local file="$1"

    awk '
    {
        q=index($0,"\""); if (!q) next
        r=index(substr($0,q+1),"\""); if (!r) next
        rest=substr($0,q+r+1)
        sub(/^[[:space:]]+/,"",rest)
        split(rest,f,/[[:space:]]+/)
        total++
        sum+=f[3]+0
    }
    END {
        printf "Atlagos valaszido: %.3f s\n",
            total?sum/total:0
    }' "$file"
}

report_summary() {
    local file="$1"

    awk '
    {
        q=index($0,"\""); if (!q) next
        r=index(substr($0,q+1),"\""); if (!r) next
        rest=substr($0,q+r+1)
        sub(/^[[:space:]]+/,"",rest)
        split(rest,f,/[[:space:]]+/)
        code=f[1]+0
        if (code<100 || code>599) next
        total++
        if (code>=400 && code<500) err4++
        if (code>=500 && code<600) err5++
    }
    END {
        printf "Osszesen %d keres, %d darab 4xx es %d darab 5xx hiba.\n",
            total,err4,err5
    }' "$file"
}

run_reports() {
    local file="$1" wanted="$2" top="$3"

    printf '%s\n' "=== IP toplista ==="
    report_ip "$file" "$top"

    printf '\n%s\n' "=== HTTP-státusz ==="
    if [[ -n "$wanted" ]]; then
        report_status "$file" "$wanted"
    else
        report_errors "$file"
    fi

    printf '\n%s\n' "=== Hibás URL-ek ==="
    report_error_urls "$file" "$wanted" "$top"

    printf '\n%s\n' "=== Óránkénti kérések ==="
    report_hourly "$file"

    printf '\n%s\n' "=== Válaszidő ==="
    report_average "$file"

    report_summary "$file"
}

if (( QUIET )); then
    if [[ -n "$OUTPUT" ]]; then
        report_summary "$LOG" > "$OUTPUT"
    else
        report_summary "$LOG"
    fi
elif [[ -n "$OUTPUT" ]]; then
    run_reports "$LOG" "$STATUS_CODE" "$TOP" > "$OUTPUT"
else
    run_reports "$LOG" "$STATUS_CODE" "$TOP"
fi
