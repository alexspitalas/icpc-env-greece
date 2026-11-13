#!/bin/bash

# Configuration
SSHUSER="${SSHUSER:-icpcadmin}"
SSHPORT="${SSHPORT:-}"
SSHKEY="${SSHKEY:-}"

if [ -z "$SSHKEY" ] && [ -f "$PWD/files/secrets/icpcadmin@contestmanager" ]; then
  SSHKEY="$PWD/files/secrets/icpcadmin@contestmanager"
fi

# Parse leading numeric port argument if provided (e.g. ./connect2qemu.sh 2222)
if [[ $# -ge 1 && "$1" =~ ^[0-9]+$ ]]; then
  SSHPORT="$1"
  shift
fi

# Auto-detect port if not specified: test 5222 (build-final.sh) then 2222 (test_final.sh / runvm.sh)
if [ -z "$SSHPORT" ]; then
  if (echo >/dev/tcp/127.0.0.1/5222) 2>/dev/null; then
    SSHPORT=5222
  elif (echo >/dev/tcp/127.0.0.1/2222) 2>/dev/null; then
    SSHPORT=2222
  else
    SSHPORT=2222
  fi
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [ -n "$SSHKEY" ]; then
  chmod 0400 "$SSHKEY" 2>/dev/null || true
  SSH_OPTS+=(-i "$SSHKEY" -o IdentitiesOnly=yes)
fi

exec ssh "${SSH_OPTS[@]}" "${SSHUSER}@localhost" -p "$SSHPORT" "$@"
