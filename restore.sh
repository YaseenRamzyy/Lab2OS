#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 dir malicious_dir"
    exit 1
fi

DIR="$1"
MAL_DIR="$2"

if [ -z "$(ls -A "$MAL_DIR")" ]; then
    echo "No malicious files to review."
    exit 0
fi

while true; do
    files=()
    for f in "$MAL_DIR"/*; do
        [ -f "$f" ] && files+=("$(basename "$f")")
    done

    [ ${#files[@]} -eq 0 ] && { echo "No malicious files to review."; exit 0; }

    echo "Files in quarantine:"
    for i in "${!files[@]}"; do
        echo "$((i+1)). ${files[$i]}"
    done

    read -p "Select a file number: " num
    # validate: must be a number in range
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#files[@]} ]; then
        echo "Invalid selection."
        continue
    fi
    file="${files[$((num-1))]}"

    echo "1) Restore  2) Delete permanently  3) Leave as is"
    read -p "Choice: " choice
    case "$choice" in
        1) mv "$MAL_DIR/$file" "$DIR/$file"
           echo "Restored $file to $DIR." ;;
        2) rm "$MAL_DIR/$file"
           echo "$file permanently deleted." ;;
        3) ;;   # do nothing, loop back to the list
        *) echo "Invalid choice." ;;
    esac
done
