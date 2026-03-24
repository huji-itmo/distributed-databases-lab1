#!/usr/bin/env bash

source .env

pg_ctl reload -D $CLUSTER_FOLDER
