#!/usr/bin/env bash

source .env

if ! bash ./is_ready.sh; then
    echo "db id down";
    exit 1;
fi

source ./scripts/set_param.sh

set_conf synchronous_commit off
set_conf fsync off
