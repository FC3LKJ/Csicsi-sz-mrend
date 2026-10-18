#!/usr/bin/env bash
set -euo pipefail

LOG="${1:-access.log}"

if [[ ! -r "$LOG" ]]; then
    echo "hiba, fajl olvashatatlan: $LOG" >&2
    exit 1
fi

awk '
function pct(n) {
    return total ? sprintf("%.2f", 100 * n / total) : "0.00"
}

{
    ip = $1

    left = index($0, "[")
    right = index($0, "]")
    q1 = index($0, "\"")
    q2 = index(substr($0, q1 + 1), "\"") + q1

    time = substr($0, left + 1, right - left - 1)
    request = substr($0, q1 + 1, q2 - q1 - 1)
    rest = substr($0, q2 + 1)

    split(request, req, " ")
    sub(/^[[:space:]]+/, "", rest)
    split(rest, fields, " ")

    url = req[2]
    status = fields[1] + 0
    delay = fields[3] + 0

    total++

    if (!(ip in ip_count))
        unique_ips++
    ip_count[ip]++

    status_count[status]++
    response_sum += delay

    hour = substr(time, 1, 14)
    hour_count[hour]++

    if (status >= 400 && status < 500) {
        err4++
        error_count["4xx" SUBSEP url]++
    } else if (status >= 500 && status < 600) {
        err5++
        error_count["5xx" SUBSEP url]++
    }
}

END {
    print "=================================================="
    print "                 Jelentes"
    print "=================================================="

    printf "%-30s %10d\n", "osszesen:", total
    printf "%-30s %10d\n", "egyedi IP cimek:", unique_ips
    printf "%-30s %9.3f s\n", "Atlagos valaszido:", total ? response_sum / total : 0

    print ""
    print "--------------------------------------------------"
    print " top 10 IP cimek"
    print "--------------------------------------------------"
    printf "%-20s %12s %12s\n", "IP cimek", "keres", "szazalek"
    print "--------------------------------------------------"

    for (i = 1; i <= 10 && i <= unique_ips; i++) {
        max = -1
        best = ""

        for (ip in ip_count) {
            if (!(ip in shown_ip) && ip_count[ip] > max) {
                max = ip_count[ip]
                best = ip
            }
        }

        if (best == "")
            break

        shown_ip[best] = 1
        printf "%-20s %12d %11s%%\n", best, max, pct(max)
    }

    print ""
    print "--------------------------------------------------"
    print " status kodok"
    print "--------------------------------------------------"
    printf "%-15s %12s %12s\n", "code", "keres", "zazalek"
    print "--------------------------------------------------"

    for (s in status_count)
        printf "%-15s %12d %11s%%\n", s, status_count[s], pct(status_count[s])

    print ""
    print "--------------------------------------------------"
    print " hibak "
    print "--------------------------------------------------"
    printf "%-15s %12d %11s%%\n", "4xx errors:", err4, pct(err4)
    printf "%-15s %12d %11s%%\n", "5xx errors:", err5, pct(err5)

    print ""
    print "--------------------------------------------------"
    print " hiba url"
    print "--------------------------------------------------"
    printf "%-8s %-30s %10s\n", "TYPE", "URL", "COUNT"
    print "--------------------------------------------------"

    for (key in error_count) {
        split(key, parts, SUBSEP)
        printf "%-8s %-30s %10d\n", parts[1], parts[2], error_count[key]
    }

    print ""
    print "--------------------------------------------------"
    print " orankent"
    print "--------------------------------------------------"
    printf "%-20s %12s\n", "orak", "keres"
    print "--------------------------------------------------"

    for (hour in hour_count)
        printf "%-20s %12d\n", hour, hour_count[hour]

    print ""
    print "=================================================="

    if (total) {
        max = -1
        best = ""

        for (ip in ip_count) {
            if (ip_count[ip] > max) {
                max = ip_count[ip]
                best = ip
            }
        }

        printf "A legaktívabb IP a %s, ami az összes kérés %.2f%%-át adta.\n", best, 100 * max / total
    } else {
        print "Nincs feldolgozható kérés."
    }
}
' "$LOG"
