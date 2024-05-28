#!/bin/sh

CONFIG_FILE="scripts/config.yml"
GLOBALS_FILE="scripts/globals.yml"
TEMP_GLOBALS_FILE="scripts/globals_temp.yml"

insert_overrides() {
    _KEY="$(echo "$1" | cut -d':' -f1)"
    _FOUND=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "#$_KEY"; then
            _VALUE="$(cat "$CONFIG_FILE" | yq -r ".$_KEY")"
            echo "$_KEY: $_VALUE"
        fi
    done < "$GLOBALS_FILE"
}

for key in $(awk '/^[a-zA-Z_]/ {print $1}' $CONFIG_FILE); do
    insert_overrides $key
done
