#!/usr/bin/env bash

source .env

export LOCAL_MOUNT_FOLDER=remote_mount

mkdir -p $LOCAL_MOUNT_FOLDER

echo sshfs -v helios_pg:/var/db/${VM_USERNAME}/lab1 $LOCAL_MOUNT_FOLDER

sshfs -v helios_pg:/var/db/${VM_USERNAME}/lab1 $LOCAL_MOUNT_FOLDER
