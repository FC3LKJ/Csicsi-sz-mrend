#!/usr/bin/env bash
# Használat: ./general-log.sh NEPTUN > access.log
set -euo pipefail
SEED="$(printf '%s' "${1:?adj meg egy Neptun-kódot}" | cksum | awk '{print $1}')"
awk -v seed="$SEED" 'BEGIN {
  srand(seed)
  nu = split("/index.html /api/v1/users /api/v1/orders /login /admin /static/app.js /kpek/logo.png", ut, " ")
  mn = split("GET GET GET POST POST PUT DELETE", md, " ")
  ns = split("200 200 200 200 301 404 403 500 502 503", st, " ")
  for (i = 0; i < 4000; i++) {
    ip = sprintf("%d.%d.%d.%d", 10+int(rand()*40), int(rand()*256), int(rand()*256), int(rand()*254)+1)
    if (rand() < 0.18) ip = "193.224.41.77"          # a gyanús vendég
    t = 1790000000 + i*17 + int(rand()*11)
    printf "%s - - [%s] \"%s %s HTTP/1.1\" %s %d\n", ip,
      strftime("%d/%b/%Y:%H:%M:%S +0200", t),
      md[int(rand()*mn)+1], ut[int(rand()*nu)+1], st[int(rand()*ns)+1],
      200+int(rand()*90000), rand()*2.5
  }
}'