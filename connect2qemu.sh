#!/bin/bash
VARIANT=${1:-all}
SSHPORT=5222
SSHKEY="$PWD/configs/imageadmin-ssh_key"
SSH_ICPCADMIN_KEY="files/secrets/icpcadmin@contestmanager"
IMGFILE="output/$(date +%Y-%m-%d)_image-amd64.img"
if [[ $IMGFILE != 'all' ]]; then
  IMGFILE="output/$VARIANT-$(date +%Y-%m-%d)_image-amd64.img"
fi
#chmod 0400 "$SSHKEY"
#sudo ssh -i "$SSHKEY" -o  IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p $SSHPORT "$@"
ssh -i $SSH_ICPCADMIN_KEY -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes  icpcadmin@localhost -p$SSHPORT sudo shutdown --poweroff --no-wall +1

# Dig holes in the file to make it sparse (i.e. smaller!)
fallocate -d $IMGFILE
echo "Image file created: $IMGFILE($(du -h $IMGFILE | cut -f1))"
exit 0
