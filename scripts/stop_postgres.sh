#!/usr/bin/env bash
source .env

pg_ctl stop -D $CLUSTER_FOLDER
