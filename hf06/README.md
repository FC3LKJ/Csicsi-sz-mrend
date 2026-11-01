set -euo pipefall

set -e:
kilép, ha hibára fut bármi, és nem folytatja a futást

set -u:
az üres változókat hibának tekinti

set -o pipefall:
a bash alapból minden pipe-olt utasítássorozatnak a legutolsó visszatérési kódját adja vissza, tehát ha egy hibát dobna, de az utolsó nullával tér vissza, akkor nullát adna vissza
a set -o pipefall ezt megváltoztatja, és visszaadja a hibakódot

Megoldás a curl hibákra:
ha a curl egy if feltétele, akkor le tudom kezelni a hibát anélkül, hogy a set -euo pipefall megszakítaná a futást

[Futás](image.png)