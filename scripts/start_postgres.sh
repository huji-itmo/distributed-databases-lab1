#!/usr/bin/env bash
source .env

pg_ctl -D $CLUSTER_FOLDER start
