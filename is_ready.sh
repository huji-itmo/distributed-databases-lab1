#!/usr/bin/env bash

set -e

source .env

pg_isready -d $DBNAME -p $PORT
