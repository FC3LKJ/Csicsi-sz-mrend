csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh --help
Használat: ./logtool.sh [-q] [-h] [-f FILE] [-o FILE] [-s CODE] [-t N]

Kapcsolók:
  -q, --quiet       Csak az összesítő sor
  -h, --help        Használat
  -f, --file FILE   Bemeneti naplófájl
  -o, --output FILE Kimeneti fájl
  -s, --status CODE HTTP-státuszkód szerinti szűrés
  -t, --top N       Toplista hossza (alapértelmezés: 10)

Példák:
  ./logtool.sh -f access.log
  ./logtool.sh -f access.log -s 404
  ./logtool.sh -f access.log -t 20
  ./logtool.sh -f access.log -o logrep.txt
  ./logtool.sh -f access.log -q
  ./logtool.sh -f access.log -s 500 -q -o logrep.txt

---------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh
Hiba: A bemeneti fájl nem olvasható vagy nem létezik: access.log

Használat: ./logtool.sh [-q] [-h] [-f FILE] [-o FILE] [-s CODE] [-t N]

Kapcsolók:
  -q, --quiet       Csak az összesítő sor
  -h, --help        Használat
  -f, --file FILE   Bemeneti naplófájl
  -o, --output FILE Kimeneti fájl
  -s, --status CODE HTTP-státuszkód szerinti szűrés
  -t, --top N       Toplista hossza (alapértelmezés: 10)

Példák:
  ./logtool.sh -f access.log
  ./logtool.sh -f access.log -s 404
  ./logtool.sh -f access.log -t 20
  ./logtool.sh -f access.log -o logrep.txt
  ./logtool.sh -f access.log -q
  ./logtool.sh -f access.log -s 500 -q -o logrep.txt

----------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh -f nincs.log
Hiba: A bemeneti fájl nem olvasható vagy nem létezik: nincs.log

Használat: ./logtool.sh [-q] [-h] [-f FILE] [-o FILE] [-s CODE] [-t N]

Kapcsolók:
  -q, --quiet       Csak az összesítő sor
  -h, --help        Használat
  -f, --file FILE   Bemeneti naplófájl
  -o, --output FILE Kimeneti fájl
  -s, --status CODE HTTP-státuszkód szerinti szűrés
  -t, --top N       Toplista hossza (alapértelmezés: 10)

Példák:
  ./logtool.sh -f access.log
  ./logtool.sh -f access.log -s 404
  ./logtool.sh -f access.log -t 20
  ./logtool.sh -f access.log -o logrep.txt
  ./logtool.sh -f access.log -q
  ./logtool.sh -f access.log -s 500 -q -o logrep.txt

------------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh -f access.log -t 3
=== IP toplista ===
193.224.41.77               730    18.25%
10.0.145.200                  1     0.03%
10.100.30.127                 1     0.03%

=== HTTP-státusz ===
4xx hibak: 755 (18.88%)
5xx hibak: 1242 (31.05%)

=== Hibás URL-ek ===
500      /static/app.js                         73
500      /login                                 72
503      /index.html                            69

=== Óránkénti kérések ===
21/Sep/2026:1 1012
21/Sep/2026:2 847
22/Sep/2026:0 2118
22/Sep/2026:1 23

=== Válaszidő ===
Atlagos valaszido: 0.000 s
Osszesen 4000 keres, 755 darab 4xx es 1242 darab 5xx hiba.

-------------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh -f access.log -o riport.txt

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ cat riport.txt
=== IP toplista ===
193.224.41.77               730    18.25%
10.0.145.200                  1     0.03%
10.100.30.127                 1     0.03%
10.102.171.46                 1     0.03%
10.102.198.53                 1     0.03%
10.107.17.120                 1     0.03%
10.107.60.38                  1     0.03%
10.11.178.178                 1     0.03%
10.110.110.219                1     0.03%
10.112.142.77                 1     0.03%

=== HTTP-státusz ===
4xx hibak: 755 (18.88%)
5xx hibak: 1242 (31.05%)

=== Hibás URL-ek ===
500      /static/app.js                         73
500      /login                                 72
503      /index.html                            69
500      /index.html                            66
502      /index.html                            64
404      /static/app.js                         63
502      /api/v1/orders                         63
404      /kpek/logo.png                         62
502      /admin                                 62
502      /login                                 62

=== Óránkénti kérések ===
21/Sep/2026:1 1012
21/Sep/2026:2 847
22/Sep/2026:0 2118
22/Sep/2026:1 23

=== Válaszidő ===
Atlagos valaszido: 0.000 s
Osszesen 4000 keres, 755 darab 4xx es 1242 darab 5xx hiba.

---------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh -f access.log -q
Osszesen 4000 keres, 755 darab 4xx es 1242 darab 5xx hiba.

-------------------------------

csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$ ./logtool.sh -f access.log --izelevele
Hiba: Ismeretlen kapcsoló vagy argumentum: --izelevele

Használat: ./logtool.sh [-q] [-h] [-f FILE] [-o FILE] [-s CODE] [-t N]

Kapcsolók:
  -q, --quiet       Csak az összesítő sor
  -h, --help        Használat
  -f, --file FILE   Bemeneti naplófájl
  -o, --output FILE Kimeneti fájl
  -s, --status CODE HTTP-státuszkód szerinti szűrés
  -t, --top N       Toplista hossza (alapértelmezés: 10)

Példák:
  ./logtool.sh -f access.log
  ./logtool.sh -f access.log -s 404
  ./logtool.sh -f access.log -t 20
  ./logtool.sh -f access.log -o logrep.txt
  ./logtool.sh -f access.log -q
  ./logtool.sh -f access.log -s 500 -q -o logrep.txt
csaba@DESKTOP-3HABTRV:~/Csicsi-sz-mrend/hf05$