#!/usr/bin/env bash

source .env

ssh helios_pg "cd lab1 && export $(grep -v '^#' .env | xargs -0) && ${0}"
