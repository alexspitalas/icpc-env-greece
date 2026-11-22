#!/bin/bash

set -xeuo pipefail

# Default group for the VM in ansible. This lets you use group_vars/$VARIANT for site specific configuration
VARIANT=${1:-all}

SSHPORT=5222
SSH_BUILD_KEY="configs/imageadmin-ssh_key"
SSH_ICPCADMIN_KEY="files/secrets/icpcadmin@contestmanager"
PIDFILE="tmp/qemu.pid"
ALIVE=0

IMGFILE="output/$(date +%Y-%m-%d)_image-amd64.img"
if [[ $IMGFILE != 'all' ]]; then
  IMGFILE="output/$VARIANT-$(date +%Y-%m-%d)_image-amd64.img"
fi

BASEIMG="base-amd64.img"

# Copy to a raw disk image

function runssh() {
  ssh -i $SSH_BUILD_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  imageadmin@localhost -p$SSHPORT $@ 2>/dev/null
}

function cleanup() {
  if [ $ALIVE -eq 1 ]; then
    echo "Attempting graceful shutdown"
    runssh sudo poweroff
  else
    echo "Forcing shutdown(poweroff)"
    kill "$(cat $PIDFILE)"
  fi
  rm -f $PIDFILE
}

function waitforssh() {
  # wait for it to boot
  echo -n "Waiting for ssh "
  TIMEOUT=60
  X=0

  while [[ $X -lt $TIMEOUT ]]; do
    let X+=1
    set +e
    OUT=$(ssh -i $SSH_BUILD_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  imageadmin@localhost -p $SSHPORT echo "ok" 2>/dev/null)
    set -e
    if [[ "$OUT" == "ok" ]]; then
      ALIVE=1
      break
    fi
    echo -n "."
    sleep 1
  done
  echo ""

  if [ $ALIVE -eq 0 ]; then
    echo "Timed out waiting for host to respond"
    cleanup
    exit 1
  else
    echo "Host is alive! You can ssh in now"
  fi
}

ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo reboot

# Wait 5 seconds for reboot to happen so we don't ssh back in before it actually reboots
sleep 20
ALIVE=0
waitforssh

echo "Preparing image for distribution"
set -x
ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo bash -c "/icpc/scripts/makeDist.sh"

# Report free space on the image's root filesystem (warning only, never fails the build).
# "Avail" is what a normal user (contestant / VS Code) can still write, i.e. it already
# excludes the ext4 root-only reserve.
{ set +x; } 2>/dev/null
(
  set +euo pipefail
  MIN_FREE_GB=3
  DF_OUT=$(ssh -i "$SSH_ICPCADMIN_KEY" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes icpcadmin@localhost -p"$SSHPORT" "df -B1 --output=size,used,avail / | tail -n1" 2>/dev/null)
  FS_SIZE="" FS_USED="" FS_AVAIL=""
  read -r FS_SIZE FS_USED FS_AVAIL <<< "$DF_OUT"
  if [[ "$FS_SIZE" =~ ^[0-9]+$ && "$FS_USED" =~ ^[0-9]+$ && "$FS_AVAIL" =~ ^[0-9]+$ && "$FS_SIZE" -gt 0 ]]; then
    FS_RESERVED=$(( FS_SIZE - FS_USED - FS_AVAIL ))
    (( FS_RESERVED < 0 )) && FS_RESERVED=0
    gib() { awk -v b="$1" 'BEGIN { printf "%.2f GiB", b/1024/1024/1024 }'; }
    PCT_USED=$(awk -v u="$FS_USED" -v s="$FS_SIZE" 'BEGIN { printf "%.1f", 100*u/s }')
    echo "================================================================"
    echo " Root filesystem usage in the built image:"
    echo "   Size:              $(gib "$FS_SIZE")"
    echo "   Used:              $(gib "$FS_USED") (${PCT_USED}%)"
    echo "   Reserved for root: $(gib "$FS_RESERVED")"
    echo "   Free for users:    $(gib "$FS_AVAIL")"
    if (( FS_AVAIL < MIN_FREE_GB * 1024 * 1024 * 1024 )); then
      echo ""
      echo " WARNING: only $(gib "$FS_AVAIL") free for contestants (recommended >= ${MIN_FREE_GB} GiB)."
      echo " WARNING: VS Code/IDEs may hit 'No space left on device' during the contest."
      echo " WARNING: Consider a bigger image (-s for create_baseimg.sh) or fewer IDEs/tools."
    fi
    echo "================================================================"
  else
    echo "WARNING: could not read free space from the VM (df over ssh failed or returned unexpected output)."
  fi
) || true
set -x
ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo shutdown --poweroff --no-wall +1

# Dig holes in the file to make it sparse (i.e. smaller!)
fallocate -d $IMGFILE
echo "Image file created: $IMGFILE($(du -h $IMGFILE | cut -f1))"
exit 0
