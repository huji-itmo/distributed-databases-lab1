#!/usr/bin/env bash

source .env

if ! bash ./scripts/is_ready.sh; then
    echo "db id down";
    exit 1;
fi

source ./scripts/set_param.sh

set_conf synchronous_commit on
set_conf fsync on
