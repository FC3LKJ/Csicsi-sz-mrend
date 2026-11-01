#!/usr/bin/env bash

set -Eeuo pipefail

DESTINATION="./downloads"
LOG_FILE="./download.log"

URLS=(
    "https://api.frankfurter.dev/v1/latest"
    "https://api.open-meteo.com/v1/forecast?latitude=47.5&longitude=19.05&current=temperature_2m"
    "https://date.nager.at/api/v3/PublicHolidays/2026/HU"
    "https://httpbin.org/status/500"
    "https://httpbin.org/delay/10"
    "https://ez.a.domain.biztosan.nem.letezik/valami.json"
)

FILENAMES=(
    "exchange-rates.json"
    "weather.json"
    "hungarian-holidays.json"
    "http-error.json"
    "delayed-response.json"
    "nonexistent-domain.json"
)

RETRY_DELAYS=(1 2 4)
WORKDIR=""
STATUS=()
INTERRUPTED=0

for i in "${!URLS[@]}"; do
    STATUS[i]="PENDING"
done

log() {
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" >> "$LOG_FILE" || true
}

cleanup() {
    local exit_code=$?

    trap - EXIT

    log "Script exiting with code: $exit_code"

    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        log "Removing temporary directory: $WORKDIR"

        if rm -rf -- "$WORKDIR"; then
            log "Temporary directory removed"
        else
            log "ERROR: Could not remove temporary directory"
        fi
    fi

    log "========== FINAL REPORT =========="
    for i in "${!URLS[@]}"; do
        case "${STATUS[$i]}" in
            SUCCESS)
                printf '[SUCCESS] %s\n' "${FILENAMES[$i]}"
                log "SUCCESS: ${FILENAMES[$i]}"
                ;;
            *)
                printf '[FAIL] %s\n' "${FILENAMES[$i]}"
                log "FAIL: ${FILENAMES[$i]} (status: ${STATUS[$i]})"
                ;;
        esac
    done

    log "=================================="
    exit "$exit_code"
}

handle_signal() {
    local signal="$1"
    local code="$2"
    INTERRUPTED=1
    log "Received signal: $signal"
    log "Stopping downloads..."

    exit "$code"
}

trap cleanup EXIT
trap 'handle_signal SIGINT 130' INT
trap 'handle_signal SIGTERM 143' TERM
trap 'handle_signal SIGHUP 129' HUP

log "========== DOWNLOAD START =========="

if [[ ${#URLS[@]} -ne ${#FILENAMES[@]} ]]; then
    log "ERROR: URL and filename counts don't match"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "ERROR: curl is not installed"
    exit 1
fi

declare -A SEEN=()

for filename in "${FILENAMES[@]}"; do

    if [[ -z "$filename" ||
          "$filename" == */* ||
          "$filename" == "." ||
          "$filename" == ".." ]]; then

        log "ERROR: Invalid filename: $filename"
        exit 1
    fi

    if [[ -n "${SEEN[$filename]+exists}" ]]; then
        log "ERROR: Duplicate filename: $filename"
        exit 1
    fi

    SEEN["$filename"]=1
done

mkdir -p -- "$DESTINATION"

for filename in "${FILENAMES[@]}"; do

    if [[ -e "$DESTINATION/$filename" ||
          -L "$DESTINATION/$filename" ]]; then

        log "ERROR: Destination file already exists: $filename"
        exit 1
    fi

done

WORKDIR="$(mktemp -d "$DESTINATION/.download.XXXXXX")"
log "Destination: $DESTINATION"
log "Temporary directory: $WORKDIR"
log "Files to download: ${#URLS[@]}"
download_file() {

    local index="$1"
    local url="${URLS[$index]}"
    local filename="${FILENAMES[$index]}"

    local part_file="$WORKDIR/$filename.part"
    local error_file="$WORKDIR/$filename.error"

    local attempt
    local retry_delay
    local curl_status

    log "Starting download: $filename"
    log "URL: $url"

    for attempt in 1 2 3 4; do

        log "Attempt $attempt/4: $filename"
        rm -f -- "$part_file" "$error_file"

        if curl \
            --fail \
            --location \
            --silent \
            --show-error \
            --connect-timeout 15 \
            --output "$part_file" \
            "$url" 2>"$error_file"; then

            log "Download completed: $filename"

            if mv -nT -- "$part_file" "$DESTINATION/$filename" &&
               [[ ! -e "$part_file" ]]; then

                STATUS[index]="SUCCESS"
                log "Atomically published: $DESTINATION/$filename"
                rm -f -- "$error_file"
                return 0
            fi

            log "ERROR: Could not publish $filename"
            rm -f -- "$part_file" "$error_file"
            STATUS[index]="FAILED"
            return 1

        else

            curl_status=$?
            log "Download failed: $filename (curl exit: $curl_status)"
            if [[ -s "$error_file" ]]; then
                while IFS= read -r line; do
                    log "curl: $line"
                done < "$error_file"
            fi
            rm -f -- "$part_file"

        fi

        if (( attempt < 4 )); then

            retry_delay="${RETRY_DELAYS[$((attempt - 1))]}"
            log "Retrying $filename in ${retry_delay}s"
            sleep "$retry_delay"

        fi

    done

    log "ERROR: All 4 attempts exhausted for $filename"

    rm -f -- "$part_file" "$error_file"

    STATUS[index]="FAILED"

    return 1
}

for i in "${!URLS[@]}"; do

    download_file "$i" || true

done

log "All download jobs processed"

failed_count=0

for i in "${!URLS[@]}"; do

    if [[ "${STATUS[$i]}" != "SUCCESS" ]]; then
        ((failed_count += 1))
    fi

done

if (( failed_count == 0 )); then

    log "All downloads successful"
    exit 0

else

    log "$failed_count download(s) failed"
    exit 1

fi
