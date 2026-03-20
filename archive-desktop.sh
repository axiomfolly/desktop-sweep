#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$HOME/Desktop"
ARCHIVE_DIR_NAME="Archive"
ARCHIVE_DIR="$DESKTOP_DIR/$ARCHIVE_DIR_NAME"
CONFIG_FILE="$ARCHIVE_DIR/config.cfg"

# Defaults (overridden by config.cfg if present)
ENABLED=true
LOG_ENABLED=true
AGE_THRESHOLD_DAYS=30
SKIP_FILES=""
SKIP_EXTENSIONS=""

DRY_RUN=false

load_config() {
    [[ -f "$CONFIG_FILE" ]] || return 0
    while IFS='=' read -r key value; do
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | xargs)"
        [[ -z "$key" || "$key" == \#* ]] && continue
        case "$key" in
            ENABLED)            ENABLED="$value" ;;
            LOG_ENABLED)        LOG_ENABLED="$value" ;;
            AGE_THRESHOLD_DAYS) AGE_THRESHOLD_DAYS="$value" ;;
            SKIP_FILES)         SKIP_FILES="$value" ;;
            SKIP_EXTENSIONS)    SKIP_EXTENSIONS="$value" ;;
        esac
    done < "$CONFIG_FILE"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Moves files from ~/Desktop into ~/Desktop/Archive/YYYY-MM/ subfolders
based on each file's last-modified date. Reads configuration from
~/Desktop/Archive/config.cfg if present.

Options:
  --dry-run   Show what would be moved without moving anything
  --help      Show this help message
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help)    usage ;;
        *)         echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

mkdir -p "$ARCHIVE_DIR"
load_config

if [[ "$ENABLED" != true ]]; then
    echo "Desktop Sweep is disabled (ENABLED=$ENABLED). Exiting."
    exit 0
fi

LOG_FILE="$ARCHIVE_DIR/archive.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $msg"
    elif [[ "$LOG_ENABLED" == true ]]; then
        echo "$msg" | tee -a "$LOG_FILE"
    fi
}

resolve_conflict() {
    local dest="$1"
    if [[ ! -e "$dest" ]]; then
        echo "$dest"
        return
    fi
    local dir base ext timestamp
    dir="$(dirname "$dest")"
    base="$(basename "$dest")"
    timestamp="$(date '+%Y%m%d%H%M%S')"

    if [[ "$base" == *.* ]]; then
        ext=".${base##*.}"
        base="${base%.*}"
    else
        ext=""
    fi
    echo "${dir}/${base}_${timestamp}${ext}"
}

is_skipped_file() {
    local filename="$1"
    [[ -z "$SKIP_FILES" ]] && return 1
    IFS=',' read -ra entries <<< "$SKIP_FILES"
    for entry in "${entries[@]}"; do
        entry="$(echo "$entry" | xargs)"
        [[ "$filename" == "$entry" ]] && return 0
    done
    return 1
}

is_skipped_extension() {
    local filename="$1"
    [[ -z "$SKIP_EXTENSIONS" ]] && return 1
    local ext="${filename##*.}"
    [[ "$filename" == "$ext" ]] && return 1  # no extension
    ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    IFS=',' read -ra entries <<< "$SKIP_EXTENSIONS"
    for entry in "${entries[@]}"; do
        entry="$(echo "$entry" | xargs | tr '[:upper:]' '[:lower:]')"
        [[ "$ext" == "$entry" ]] && return 0
    done
    return 1
}

if (( AGE_THRESHOLD_DAYS > 0 )); then
    cutoff_epoch=$(date -v-${AGE_THRESHOLD_DAYS}d '+%s')
else
    cutoff_epoch=$(date '+%s')
fi
moved=0
skipped=0

log "Starting desktop archive scan (dry_run=$DRY_RUN, threshold=${AGE_THRESHOLD_DAYS}d, log=$LOG_ENABLED)"

while IFS= read -r -d '' file; do
    filename="$(basename "$file")"
    mod_epoch=$(stat -f '%m' "$file")

    if is_skipped_file "$filename"; then
        skipped=$((skipped + 1))
        log "SKIP (config): $filename"
        continue
    fi

    if is_skipped_extension "$filename"; then
        skipped=$((skipped + 1))
        log "SKIP (extension): $filename"
        continue
    fi

    if (( AGE_THRESHOLD_DAYS > 0 )) && (( mod_epoch > cutoff_epoch )); then
        skipped=$((skipped + 1))
        log "SKIP (recent): $filename"
        continue
    fi

    dest_subdir=$(date -r "$mod_epoch" '+%Y-%m')
    dest_dir="$ARCHIVE_DIR/$dest_subdir"
    dest_path="$dest_dir/$filename"
    dest_path="$(resolve_conflict "$dest_path")"

    if [[ "$DRY_RUN" == true ]]; then
        log "WOULD MOVE: $filename -> $dest_subdir/"
    else
        mkdir -p "$dest_dir"
        mv "$file" "$dest_path"
        log "MOVED: $filename -> $dest_path"
    fi
    moved=$((moved + 1))
done < <(find "$DESKTOP_DIR" -maxdepth 1 -mindepth 1 -not -name '.*' -not -name 'DS_Store' -not -iname "$ARCHIVE_DIR_NAME" -type f -print0)

log "Done. Moved: $moved, Skipped: $skipped"
