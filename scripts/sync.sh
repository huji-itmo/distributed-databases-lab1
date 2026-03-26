#!/usr/bin/env bash

source .env

rsync ./ -av helios_pg:/var/db/${VM_USERNAME}/lab1
