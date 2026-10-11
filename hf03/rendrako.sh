#!/usr/bin/env bash

set -u
export LC_ALL=C

ROOT="."
DO_SORT=0

usage() {
    printf 'Használat: %s [könyvtár] [--rendezd] [--help]\n' "$0" >&2
    exit "${1:-2}"
}

for arg in "$@"; do
    case "$arg" in
        --help)
            usage 0
            ;;
        --rendezd)
            DO_SORT=1
            ;;
        -*)
            printf 'Hiba: ismeretlen kapcsoló: %s\n' "$arg" >&2
            usage
            ;;
        *)
            if [[ "$ROOT" != "." || "${ROOT_SET:-0}" == 1 ]]; then
                printf 'Hiba: csak egy könyvtár adható meg.\n' >&2
                usage
            fi
            ROOT="$arg"
            ROOT_SET=1
            ;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    printf 'Hiba: a könyvtár nem létezik: %s\n' "$ROOT" >&2
    exit 1
fi

ROOT="$(cd -- "$ROOT" && pwd -P)" || exit 1
DEST="$ROOT/_rendezett"

count_type() {
    find "$ROOT" -path "$DEST" -prune -o \
        -type "$1" -printf '.' 2>/dev/null | wc -c
}

echo "Könyvtár: $ROOT"

echo
echo "fileok"
printf 'Fájlok: %s\n' "$(count_type f)"
printf 'Könyvtárak: %s\n' "$(count_type d)"

echo
echo "top5"
find "$ROOT" -path "$DEST" -prune -o \
    -type f -printf '%s\t%p\n' 2>/dev/null |
    sort -nr -k1,1 |
    head -n 5 |
    while IFS=$'\t' read -r size file; do
        printf '%12s bájt  %s\n' "$size" "$file"
    done

echo
echo "regi"
find "$ROOT" -path "$DEST" -prune -o \
    -type f -mtime +29 -printf '.' 2>/dev/null |
    wc -c

echo
echo "ures"
find "$ROOT" -path "$DEST" -prune -o \
    -type f -empty -print 2>/dev/null

echo
echo "kiterjesztes"
find "$ROOT" -path "$DEST" -prune -o \
    -type f -printf '%f\0' 2>/dev/null |
    while IFS= read -r -d '' file; do
        base="${file##*/}"
        if [[ "$base" != *.* || "$base" =~ ^\.[^.]+$ ]]; then
            printf '%s\n' '[nincs kiterjesztés]'
        else
            printf '.%s\n' "${base##*.}"
        fi
    done |
    sort |
    uniq -c |
    sort -rn

echo
echo "mindenki"
find "$ROOT" -path "$DEST" -prune -o \
    -type f -perm -o+w -print 2>/dev/null

if [[ "$DO_SORT" -eq 1 ]]; then
    echo

    if ! mkdir -p -- "$DEST"; then
        printf 'Hiba: nem hozhato letre: %s\n' "$DEST" >&2
        exit 1
    fi

    changed=0
    while IFS= read -r -d '' file; do
        if chmod o-w -- "$file"; then
            printf 'Jogosultság javítva: %s\n' "$file"
            ((changed += 1))
        else
            printf 'Hiba a jogosultsag modositasakor: %s\n' "$file" >&2
        fi
    done < <(
        find "$ROOT" -path "$DEST" -prune -o \
            -type f -perm -o+w -print0 2>/dev/null
    )

    printf 'Módosított fájlok: %d\n' "$changed"

    copied=0
    failed=0

    while IFS= read -r -d '' file; do
        rel="${file#"$ROOT"/}"
        base="${rel##*/}"

        if [[ "$base" != *.* || "$base" =~ ^\.[^.]+$ ]]; then
            folder="_egyeb"
        else
            folder="${base##*.}"
        fi

        target_dir="$DEST/$folder/$(dirname -- "$rel")"
        target="$target_dir/$base"

        if ! mkdir -p -- "$target_dir"; then
            printf 'Hiba a célmappa létrehozásakor: %s\n' "$target_dir" >&2
            ((failed += 1))
            continue
        fi

        if [[ -e "$target" || -L "$target" ]]; then
            printf 'Kihagyva, már létezik: %s\n' "$target"
            continue
        fi

        if cp -p -- "$file" "$target"; then
            printf 'Másolva: %s -> %s\n' "$file" "$target"
            ((copied += 1))
        else
            printf 'Hiba másoláskor: %s\n' "$file" >&2
            ((failed += 1))
        fi
    done < <(
        find "$ROOT" -path "$DEST" -prune -o \
            -type f -print0 2>/dev/null
    )

    printf 'Másolt : %d\n' "$copied"
fi

echo
echo "done."
