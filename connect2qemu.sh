#!/bin/bash

SSHPORT=5222
SSHKEY="$PWD/configs/imageadmin-ssh_key"

chmod 0400 "$SSHKEY"
sudo ssh -i "$SSHKEY" -o  IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p $SSHPORT "$@"
