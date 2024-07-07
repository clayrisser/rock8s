#!/bin/sh

sudo pveum user token remove "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f1)" "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f2)"
