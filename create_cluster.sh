#!/usr/bin/env bash

source .env

rm -rf $CLUSTER_FOLDER

mkdir -p $CLUSTER_FOLDER

initdb \
    -D $CLUSTER_FOLDER \
    --locale ru_RU.CP1251 \
    --encoding=WIN1251 \
    -c port=$PORT
