#!/usr/bin/env bash

source .env

mkdir -p $DATA_FOLDER

dbinit \
    -D $DATA_FOLDER \
    -l $LOG_FILE \
    --locale ru_RU.CP1251 \
    --encoding=WIN1251 \
    -c port=$PORT
