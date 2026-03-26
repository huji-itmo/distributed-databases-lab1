#!/usr/bin/env bash
source .env

set_conf() {
    key="$1"
    value="$2"
    echo "SET $key = $value"
    $PSQL -h localhost -c "ALTER SYSTEM SET $key = '$value';"
}
