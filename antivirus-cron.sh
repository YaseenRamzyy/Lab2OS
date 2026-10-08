#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 dir malicious_dir"
    exit 1
fi

DIR="$1"
MAL_DIR="$2"

# Keep state files next to this script, regardless of where cron runs it

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAST="$SCRIPT_DIR/directory-info.last"
NEW="$SCRIPT_DIR/directory-info.new"
WHITELIST="$SCRIPT_DIR/whitelist.txt"

# ---- Flagged lists ----
EXTENSIONS="exe bat vbs scr ps1"
KEYWORDS="virus|trojan|malware|worm|ransomware"

mkdir -p "$MAL_DIR"
touch "$WHITELIST"

is_malicious() {
    local file="$1"
    local ext="${file##*.}"

    if [[ "$file" == *.* ]]; then
        for e in $EXTENSIONS; do
            [ "$ext" = "$e" ] && return 0
        done
    fi

    grep -aqiE "$KEYWORDS" "$file" && return 0
    return 1
}

scan() {
    for path in "$DIR"/*; do
        [ -f "$path" ] || continue
        name=$(basename "$path")

        grep -qxF "$name" "$WHITELIST" && continue

        if is_malicious "$path"; then
            echo "$name is malicious and it is DELETED"
            cp "$path" "$MAL_DIR/$name"
            rm "$path"
        fi
    done
}

# Single pass (cron handles the repetition)

if [ ! -f "$LAST" ]; then
    scan
    ls -l "$DIR" > "$LAST"
else
    ls -l "$DIR" > "$NEW"
    if ! diff -q "$LAST" "$NEW" > /dev/null; then
        scan
        cp "$NEW" "$LAST"
    fi
fi
