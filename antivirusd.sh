#!/bin/bash
if [ $# -ne 3 ]; then
	echo "Usage: $0 dir malicious_dir interval-secs"
	exit 1
fi

DIR="$1"
MAL_DIR="$2"
INTERVAL="$3"

WHITELIST="whitelist.txt"

touch "$WHITELIST"      # create it if it doesn't exist

# ---- FLAGGED LISTS ----
EXTENSIONS="exe bat vbs scr ps1"
KEYWORDS="virus|trojan|malware|worm|ransomware"
# -----------------------

mkdir -p "$MAL_DIR"

is_malicious() {
	local file="$1"
	local ext="${file##*.}"

	echo "DEBUG: Checking file: $file"
	echo "DEBUG: Extension: $ext"
	echo "DEBUG: Extensions: $EXTENSIONS"

	# Rule 1: Extensions (if the file actually has dot)
	if [[ "$file" == *.* ]]; then
		for e in $EXTENSIONS; do
			echo "DEBUG: Comparing '$ext' with '$e'"
			if [ "$ext" = "$e" ]; then
				echo "DEBUG: MATCH $file has malicious extension"
				return 0
			fi
		done
	fi

	# Rule 2: keywords in  content (case-insensitive)
	grep -aqiE "$KEYWORDS" "$file" && return 0

	return 1
}

scan() {
	for path in "$DIR"/*; do
		[ -f "$path" ] || continue
		name=$(basename "$path")

		# Skip files the user marked as safe

        	if grep -qxF "$name" "$WHITELIST"; then
            		continue
        	fi

		if is_malicious "$path"; then
			echo "$name is malicious and it is DELETED"
			cp "$path" "$MAL_DIR/$name"
			rm "$path"
		fi
	done
}


while true; do
	if [ ! -f directory-info.last ]; then
		# First run we scan immediatley
		scan
		ls -l "$DIR" > directory-info.last
	else
		ls -l "$DIR" > directory-info.new
		if ! diff -q directory-info.last directory-info.new > /dev/null; then
			scan
			cp directory-info.new directory-info.last
		fi
	fi
	sleep "$INTERVAL"
done

