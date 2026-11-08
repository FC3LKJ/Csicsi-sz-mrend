#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C
umask 077

usage() {
  echo "Használat: $0 MENTES_KONYVTAR --lista | [--proba] MENTESNEV|--legutobbi CEL_KONYVTAR" >&2
  exit 2
}
(( $# >= 2 )) || usage
store=$1; shift
[[ -d $store ]] || usage
store=$(realpath -e -- "$store")
log="$store/visszatoltes.log"
logmsg() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$log"; }

if [[ ${1:-} == --lista ]]; then
  (( $# == 1 )) || usage
  shopt -s nullglob
  for archive in "$store"/mentes-????-??-??-????.tar.gz; do
    file=${archive##*/}
    printf '%s | %s bájt\n' "${file%.tar.gz}" "$(stat -c %s -- "$archive")"
  done | sort -r
  exit 0
fi
trial=0
if [[ ${1:-} == --proba ]]; then trial=1; shift; fi
(( $# == 2 )) || usage
choice=$1 target=$2
if [[ $choice == --legutobbi ]]; then
  mapfile -t names < <(find "$store" -maxdepth 1 -type f -regextype posix-extended \
    -regex '.*/mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.tar\.gz' -printf '%f\n' | sort -r)
  (( ${#names[@]} > 0 )) || { echo 'Nincs mentés.' >&2; exit 1; }
  choice=${names[0]%.tar.gz}
else
  choice=${choice%.tar.gz}
fi
[[ $choice =~ ^mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]] || usage
archive="$store/$choice.tar.gz"
checksum="$store/$choice.sha256"
[[ -f $archive && -f $checksum ]] || { echo 'Hiányzik az archívum vagy a checksum.' >&2; exit 1; }
logmsg "ELLENŐRZÉS: $choice"
# A sha256sum -c csak a saját mappában találja meg a relatív nevet.
if ! (cd "$store" && sha256sum -c -- "$choice.sha256"); then
  logmsg "ELUTASÍTVA: hibás SHA-256: $choice"
  exit 1
fi
# A tar fájllistájában nem engedünk abszolút, kilépő vagy speciális útvonalakat.
if ! python3 - "$archive" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1], 'r:gz') as tf:
    for m in tf:
        p = m.name
        parts = p.split('/')
        if (p.startswith('/') or '..' in parts or
                not (m.isfile() or m.isdir()) or
                any(part == '' for part in parts if p != './')):
            sys.exit(1)
PY
then
  logmsg 'ELUTASÍTVA: veszélyes archívumbejegyzés'
  exit 1
fi
if (( trial )); then
  printf 'PRÓBA: visszatöltés célja: %s\n' "$target"
  tar -tzf "$archive"
  printf 'PRÓBA: nem történt írás a célkönyvtárba.\n'
  exit 0
fi
# Nem írunk felül: kizárólag nem létező célkönyvtárba állítunk vissza.
[[ ! -e $target && ! -L $target ]] || {
  logmsg "ELUTASÍTVA: a cél már létezik: $target"
  exit 1
}
mkdir -p -- "$target"
if ! tar -C "$target" --no-same-owner --no-same-permissions -xzf "$archive"; then
  logmsg "HIBA: visszatöltés sikertelen, a részleges cél ellenőrzendő: $target"
  exit 1
fi
logmsg "VISSZATÖLTVE: $choice -> $target"
