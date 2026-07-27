#!/bin/bash

set -xeuo pipefail

# Default group for the VM in ansible. This lets you use group_vars/$VARIANT for site specific configuration
VARIANT=${1:-all}

SSHPORT=5222
SSH_BUILD_KEY="configs/imageadmin-ssh_key"
SSH_ICPCADMIN_KEY="files/secrets/icpcadmin@contestmanager"
PIDFILE="tmp/qemu.pid"
ALIVE=0

# Resources for the build VM. The provisioning run is mostly apt/dpkg and archive
# extraction, so giving it more than one core and more than 1G of RAM cuts a large
# chunk off the build time. Override from the environment on smaller build hosts,
# e.g. SMP=2 MEM=2048 ./build-final.sh
SMP=${SMP:-$(nproc)}
MEM=${MEM:-4096}

IMGFILE="output/$(date +%Y-%m-%d)_image-amd64.img"
if [[ $IMGFILE != 'all' ]]; then
  IMGFILE="output/$VARIANT-$(date +%Y-%m-%d)_image-amd64.img"
fi

BASEIMG="base-amd64.img"

# Copy to a raw disk image
qemu-img convert -O raw output/$BASEIMG $IMGFILE

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

qemu-system-x86_64 -smp $SMP -m $MEM -drive file="$IMGFILE",index=0,media=disk,format=raw --enable-kvm -netdev user,id=vnet,ipv6=off,hostfwd=tcp::$SSHPORT-:22 -device virtio-net-pci,netdev=vnet --daemonize --pidfile $PIDFILE -vnc :0 -vga qxl -spice port=5901,disable-ticketing=on -usbdevice tablet -cpu host
#qemu-system-x86_64 -smp 1 -m 1024 -drive file="$IMGFILE",index=0,media=disk,format=raw -global isa-fdc.driveA= --enable-kvm -net user,hostfwd=tcp::$SSHPORT-:22 -net nic --daemonize --pidfile $PIDFILE -vnc :0 -vga qxl -spice port=5901,disable-ticketing -usbdevice tablet

ALIVE=0
waitforssh

echo "Running ansible"
INVENTORY_FILE=$(mktemp)
cat <<EOF > $INVENTORY_FILE
vm ansible_port=$SSHPORT ansible_host=127.0.0.1
[$VARIANT]
vm
EOF

ANSIBLE_HOST_KEY_CHECKING=False time ansible-playbook -i $INVENTORY_FILE  --ssh-extra-args="-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --diff --become -u imageadmin --private-key $SSH_BUILD_KEY main.yml
rm -f $INVENTORY_FILE

ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo reboot

# Wait 5 seconds for reboot to happen so we don't ssh back in before it actually reboots
sleep 20
ALIVE=0
waitforssh

echo "Preparing image for distribution"
set -x
ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo bash -c "/icpc/scripts/makeDist.sh"
ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo shutdown --poweroff --no-wall +1

# Dig holes in the file to make it sparse (i.e. smaller!)
fallocate -d $IMGFILE
echo "Image file created: $IMGFILE($(du -h $IMGFILE | cut -f1))"
exit 0
