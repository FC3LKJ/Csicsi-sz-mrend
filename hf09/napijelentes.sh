#!/usr/bin/env bash
set -u
set -o pipefail

FORMATUM="szoveg"
FORCE_REFRESH=0
MAX_TIME="${MAX_TIME:-10}"
CACHE_TTL=3600

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.napijelentes-cache}"

FRANKFURTER_URL="${FRANKFURTER_URL:-https://api.frankfurter.dev/v1/latest?base=EUR&symbols=HUF,USD}"
OPEN_METEO_URL="${OPEN_METEO_URL:-https://api.open-meteo.com/v1/forecast?latitude=47.5&longitude=19.05&daily=temperature_2m_max,temperature_2m_min&timezone=Europe%2FBudapest}"
HOLIDAYS_URL="${HOLIDAYS_URL:-https://date.nager.at/api/v3/PublicHolidays/2026/HU}"

usage() {
    cat <<'EOF'
Használat: napijelentes.sh [--formatum szoveg|json] [--frissits]

  --formatum szoveg|json  Kimeneti formátum (alapértelmezés: szoveg)
  --frissits              A gyorsítótár figyelmen kívül hagyása
  -h, --help              Súgó
EOF
}

while (($# > 0)); do
    case "$1" in
        --formatum)
            if (($# < 2)); then
                printf 'Hiba: a --formatum kapcsoló értéket vár.\n' >&2
                exit 2
            fi
            FORMATUM="$2"
            shift 2
            ;;
        --frissits)
            FORCE_REFRESH=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Hiba: ismeretlen kapcsoló: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$FORMATUM" != "szoveg" && "$FORMATUM" != "json" ]]; then
    printf 'Hiba: a formátum csak „szoveg” vagy „json” lehet.\n' >&2
    exit 2
fi

for command_name in curl jq date stat; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Hiba: a szükséges program nem található: %s\n' "$command_name" >&2
        exit 2
    fi
done

if ! mkdir -p -- "$CACHE_DIR"; then
    printf 'Hiba: a cache könyvtár nem hozható létre: %s\n' "$CACHE_DIR" >&2
    exit 2
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/napijelentes.XXXXXX")" || {
    printf 'Hiba: ideiglenes könyvtár nem hozható létre.\n' >&2
    exit 2
}
cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

TODAY="$(TZ=Europe/Budapest date +%F)"
TOMORROW="$(TZ=Europe/Budapest date -d 'tomorrow' +%F)"

fetch_json() {
    local cache_key="$1"
    local url="$2"
    local destination="$3"
    local cache_file="$CACHE_DIR/$cache_key.json"
    local download_file="$TMP_DIR/$cache_key.download"
    local now mtime age

    if ((FORCE_REFRESH == 0)) && [[ -f "$cache_file" ]]; then
        now="$(date +%s)"
        mtime="$(stat -c %Y -- "$cache_file" 2>/dev/null || printf '0')"
        age=$((now - mtime))
        if ((age >= 0 && age < CACHE_TTL)); then
            cp -- "$cache_file" "$destination"
            return 0
        fi
    fi

    if curl --fail --silent --show-error --location \
        --max-time "$MAX_TIME" "$url" --output "$download_file" \
        2>"$TMP_DIR/$cache_key.curl-error"; then
        if jq -e . "$download_file" >/dev/null 2>&1; then
            if mv -- "$download_file" "$cache_file"; then
                cp -- "$cache_file" "$destination"
                return 0
            fi
            printf 'Figyelmeztetés: a %s cache nem frissíthető.\n' "$cache_key" >&2
        else
            printf 'Figyelmeztetés: a %s API érvénytelen JSON-t adott.\n' "$cache_key" >&2
        fi
    else
        printf 'Figyelmeztetés: a %s API nem érhető el vagy HTTP-hibát adott.\n' "$cache_key" >&2
    fi

    if [[ -f "$cache_file" ]] && jq -e . "$cache_file" >/dev/null 2>&1; then
        printf '  Korábbi cache-adat használata: %s\n' "$cache_key" >&2
        cp -- "$cache_file" "$destination"
        return 0
    fi

    return 1
}

RATE_OK=0
WEATHER_OK=0
HOLIDAY_OK=0

if fetch_json "arfolyam" "$FRANKFURTER_URL" "$TMP_DIR/rates.json"; then
    RATE_OK=1
fi
if fetch_json "idojaras" "$OPEN_METEO_URL" "$TMP_DIR/weather.json"; then
    WEATHER_OK=1
fi
if fetch_json "unnepnapok" "$HOLIDAYS_URL" "$TMP_DIR/holidays.json"; then
    HOLIDAY_OK=1
fi

if ((RATE_OK == 0 && WEATHER_OK == 0 && HOLIDAY_OK == 0)); then
    printf 'Hiba: egyik adatforrásból sem sikerült érvényes adatot lekérni, és használható cache sincs.\n' >&2
    exit 1
fi

UNAVAILABLE='"nem elérhető"'

EUR_HUF="$UNAVAILABLE"
EUR_USD="$UNAVAILABLE"
RATE_DATE="nem elérhető"
if ((RATE_OK)); then
    EUR_HUF="$(jq -c 'if (.rates.HUF | type) == "number" then .rates.HUF else "nem elérhető" end' "$TMP_DIR/rates.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
    EUR_USD="$(jq -c 'if (.rates.USD | type) == "number" then .rates.USD else "nem elérhető" end' "$TMP_DIR/rates.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
    RATE_DATE="$(jq -r 'if (.date | type) == "string" then .date else "nem elérhető" end' "$TMP_DIR/rates.json" 2>/dev/null || printf 'nem elérhető')"
fi

TEMP_MAX_TODAY="$UNAVAILABLE"
TEMP_MIN_TODAY="$UNAVAILABLE"
TEMP_MAX_TOMORROW="$UNAVAILABLE"
TEMP_MIN_TOMORROW="$UNAVAILABLE"
if ((WEATHER_OK)); then
    TEMP_MAX_TODAY="$(jq -c --arg today "$TODAY" '
        (.daily // {}) as $d |
        ($d.time // []) as $t |
        (if ($t | type) == "array" then ($t | index($today)) else null end) as $i |
        if $i == null then "nem elérhető"
        elif (($d.temperature_2m_max // []) | type) == "array" then ($d.temperature_2m_max[$i] // "nem elérhető")
        else "nem elérhető" end
    ' "$TMP_DIR/weather.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
    TEMP_MIN_TODAY="$(jq -c --arg today "$TODAY" '
        (.daily // {}) as $d |
        ($d.time // []) as $t |
        (if ($t | type) == "array" then ($t | index($today)) else null end) as $i |
        if $i == null then "nem elérhető"
        elif (($d.temperature_2m_min // []) | type) == "array" then ($d.temperature_2m_min[$i] // "nem elérhető")
        else "nem elérhető" end
    ' "$TMP_DIR/weather.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
    TEMP_MAX_TOMORROW="$(jq -c --arg tomorrow "$TOMORROW" '
        (.daily // {}) as $d |
        ($d.time // []) as $t |
        (if ($t | type) == "array" then ($t | index($tomorrow)) else null end) as $i |
        if $i == null then "nem elérhető"
        elif (($d.temperature_2m_max // []) | type) == "array" then ($d.temperature_2m_max[$i] // "nem elérhető")
        else "nem elérhető" end
    ' "$TMP_DIR/weather.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
    TEMP_MIN_TOMORROW="$(jq -c --arg tomorrow "$TOMORROW" '
        (.daily // {}) as $d |
        ($d.time // []) as $t |
        (if ($t | type) == "array" then ($t | index($tomorrow)) else null end) as $i |
        if $i == null then "nem elérhető"
        elif (($d.temperature_2m_min // []) | type) == "array" then ($d.temperature_2m_min[$i] // "nem elérhető")
        else "nem elérhető" end
    ' "$TMP_DIR/weather.json" 2>/dev/null || printf '%s' "$UNAVAILABLE")"
fi

HOLIDAY_NAME="nem elérhető"
HOLIDAY_DATE="nem elérhető"
HOLIDAY_DAYS="$UNAVAILABLE"
if ((HOLIDAY_OK)); then
    HOLIDAY_OBJECT="$(jq -c --arg today "$TODAY" '
        if type == "array" then
            [.[] | select(type == "object" and ((.date // "") | type == "string") and .date > $today)]
            | sort_by(.date) | .[0] // empty
        else empty end
    ' "$TMP_DIR/holidays.json" 2>/dev/null || true)"

    if [[ -n "$HOLIDAY_OBJECT" ]]; then
        HOLIDAY_NAME="$(jq -r '(.localName // .name // "nem elérhető") | if type == "string" then . else "nem elérhető" end' <<<"$HOLIDAY_OBJECT" 2>/dev/null || printf 'nem elérhető')"
        HOLIDAY_DATE="$(jq -r 'if (.date | type) == "string" then .date else "nem elérhető" end' <<<"$HOLIDAY_OBJECT" 2>/dev/null || printf 'nem elérhető')"
        if [[ "$HOLIDAY_DATE" != "nem elérhető" ]]; then
            today_epoch="$(date -u -d "$TODAY" +%s)"
            holiday_epoch="$(date -u -d "$HOLIDAY_DATE" +%s 2>/dev/null || printf '0')"
            if ((holiday_epoch > 0)); then
                HOLIDAY_DAYS="$(((holiday_epoch - today_epoch) / 86400))"
            fi
        fi
    fi
fi

if [[ "$FORMATUM" == "json" ]]; then
    jq -n \
        --arg generated "$TODAY" \
        --arg rate_date "$RATE_DATE" \
        --argjson eur_huf "$EUR_HUF" \
        --argjson eur_usd "$EUR_USD" \
        --arg today "$TODAY" \
        --arg tomorrow "$TOMORROW" \
        --argjson max_today "$TEMP_MAX_TODAY" \
        --argjson min_today "$TEMP_MIN_TODAY" \
        --argjson max_tomorrow "$TEMP_MAX_TOMORROW" \
        --argjson min_tomorrow "$TEMP_MIN_TOMORROW" \
        --arg holiday_name "$HOLIDAY_NAME" \
        --arg holiday_date "$HOLIDAY_DATE" \
        --argjson holiday_days "$HOLIDAY_DAYS" \
        '{
            keszult: $generated,
            arfolyam: {
                datum: $rate_date,
                EUR_HUF: $eur_huf,
                EUR_USD: $eur_usd
            },
            idojaras: {
                hely: "Budapest",
                ma: {datum: $today, maximum_C: $max_today, minimum_C: $min_today},
                holnap: {datum: $tomorrow, maximum_C: $max_tomorrow, minimum_C: $min_tomorrow}
            },
            következő_unnepnap: {
                nev: $holiday_name,
                datum: $holiday_date,
                napok_mulva: $holiday_days
            }
        }'
else
    printf 'NAPI JELENTÉS – Budapest\n'
    printf 'Készült: %s\n\n' "$TODAY"
    printf 'ÁRFOLYAM (adat dátuma: %s)\n' "$RATE_DATE"
    printf '  1 EUR = %s HUF\n' "$(jq -r . <<<"$EUR_HUF")"
    printf '  1 EUR = %s USD\n\n' "$(jq -r . <<<"$EUR_USD")"
    printf 'IDŐJÁRÁS – Budapest\n'
    printf '  Ma (%s): maximum %s °C, minimum %s °C\n' "$TODAY" "$(jq -r . <<<"$TEMP_MAX_TODAY")" "$(jq -r . <<<"$TEMP_MIN_TODAY")"
    printf '  Holnap (%s): maximum %s °C, minimum %s °C\n\n' "$TOMORROW" "$(jq -r . <<<"$TEMP_MAX_TOMORROW")" "$(jq -r . <<<"$TEMP_MIN_TOMORROW")"
    printf 'KÖVETKEZŐ MAGYAR ÜNNEPNAP\n'
    if [[ "$HOLIDAY_DAYS" == '"nem elérhető"' ]]; then
        printf '  %s\n' "$HOLIDAY_NAME"
    else
        printf '  %s (%s) – %s nap múlva\n' "$HOLIDAY_NAME" "$HOLIDAY_DATE" "$(jq -r . <<<"$HOLIDAY_DAYS")"
    fi
fi
