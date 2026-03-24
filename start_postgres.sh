#!/usr/bin/env bash

source .env

pg_ctl start -D $DATA_FOLDER
