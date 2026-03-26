#!/usr/bin/env bash
source .env

set -e

pg_isready -d $DBNAME -p $PORT
