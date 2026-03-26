#!/usr/bin/env bash
source .env

if ! bash ./is_ready.sh; then
    echo "db id down";
    exit 1;
fi

source ./scripts/set_param.sh

PARAMS_FILE="./params.conf"

# Check if params file exists
if [[ ! -f "$PARAMS_FILE" ]]; then
    echo "Error: $PARAMS_FILE not found!"
    exit 1
fi

echo "Starting configuration update using $PARAMS_FILE..."

# Read the file line by line
while IFS='=' read -r key value; do

    # Skip empty lines and comments (lines starting with #)
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

    # Trim leading/trailing whitespace from key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    # Skip if key is empty after trimming
    [[ -z "$key" ]] && continue

    # Evaluate the value to resolve shell expansions like $(pwd)
    # Note: Only do this on trusted config files
    eval "resolved_value=$value"

    # Apply the configuration using the provided function
    set_conf "$key" "$resolved_value"

done < "$PARAMS_FILE"

# bash ./scripts/reload_postgres.sh
