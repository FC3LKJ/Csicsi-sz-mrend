#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C
umask 077

usage() { echo "Használat: $0 FORRAS_KONYVTAR CEL_KONYVTAR [MEGTARTANDO_DB]" >&2; exit 2; }
(( $# == 2 || $# == 3 )) || usage
src=$1 dest=$2 keep=${3:-7}
[[ -d $src && $keep =~ ^[0-9]+$ ]] && (( 10#$keep > 0 )) || usage
keep=$((10#$keep))
mkdir -p -- "$dest"
src=$(realpath -e -- "$src")
dest=$(realpath -e -- "$dest")
[[ $dest != "$src" && $dest != "$src/"* ]] || { echo 'A cél nem lehet a forrás része.' >&2; exit 2; }
log="$dest/mentes.log"
exec 9>"$dest/.mentes.lock"
if ! flock -n 9; then
  printf '%s Már fut egy mentés.\n' "$(date '+%F %T')" | tee -a "$log" >&2
  exit 1
fi
logmsg() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$log"; }
tmp=''
cleanup() { [[ -z $tmp ]] || rm -f -- "$tmp" "$tmp.sha256" "$tmp.meta"; }
trap cleanup EXIT
trap 'logmsg "HIBA: mentés sikertelen (sor: $LINENO)"' ERR
logmsg "INDUL: forrás=$src cél=$dest megtart=$keep"
stamp=$(date '+%Y-%m-%d-%H%M')
base="mentes-$stamp"
# Egy percen belüli új futás ne írja felül a korábbit.
if [[ -e "$dest/$base.tar.gz" ]]; then
  logmsg "HIBA: már létezik ez a perces mentés: $base"
  exit 1
fi
tmp=$(mktemp "$dest/.mentes-temp.XXXXXXXX")
# A forrás könyvtár tartalmát tároljuk, nem a teljes abszolút elérési utat.
tar -C "$src" -czf "$tmp" -- .
bytes=$(stat -c %s -- "$tmp")
count=$(tar -tzf "$tmp" | awk '$0 !~ /\/$/ {n++} END {print n+0}')
printf '%s  %s\n' "$(sha256sum "$tmp" | awk '{print $1}')" "$base.tar.gz" > "$tmp.sha256"
printf 'keszult=%s\nmeret_bajt=%s\nfajlok_szama=%s\nforras=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$bytes" "$count" "$src" > "$tmp.meta"
# A checksum csak a végleges archívum nevére hivatkozik.
mv -n -- "$tmp" "$dest/$base.tar.gz"
mv -n -- "$tmp.sha256" "$dest/$base.sha256"
mv -n -- "$tmp.meta" "$dest/$base.meta"
tmp=''
logmsg "KESZ: $base.tar.gz méret=$bytes bájt fájlok=$count"

# Csak a szabályos dátumformátumú archívumokat vesszük figyelembe.
mapfile -d '' -t backups < <(find "$dest" -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.tar\.gz' \
  -printf '%f\0' | sort -z)
remove=$(( ${#backups[@]} - keep ))
for ((i=0; i<remove; i++)); do
  name=${backups[i]%.tar.gz}
  rm -f -- "$dest/$name.tar.gz" "$dest/$name.sha256" "$dest/$name.meta"
  logmsg "RETENCIÓ: törölve $name"
done
logmsg 'BEFEJEZVE'
