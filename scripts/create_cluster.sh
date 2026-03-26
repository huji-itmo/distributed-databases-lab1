#!/usr/bin/env bash
source .env

rm -rf $CLUSTER_FOLDER

mkdir -p $CLUSTER_FOLDER

initdb \
    -D $CLUSTER_FOLDER \
    --locale ru_RU.UTF-8 \
    -c port=$PORT
    # --encoding=WIN1251 \
