#!/bin/bash
# Cleans up temporary files, etc and makes it ready for imaging

UTILDIR="/icpc"

# remove the git repositories
rm -rf /etc/skel/.git
rm -rf /home/icpcadmin/.git

# Cleanup 'imageadmin' things
killall -9 -u imageadmin
sleep 5
rm -rf /home/imageadmin
userdel imageadmin

# Delete proxy settings for apt(if any)
rm -f /etc/apt/apt.conf.d/01proxy

# Kill all the user processes(and wait for them to die)
killall -9 -u contestant
sleep 5

# Reset the team(and any defaults)
$UTILDIR/scripts/deleteUser.sh

# Ensure firstboot setup runs on the distributed image
rm -f $UTILDIR/setup-complete

# Clear legacy TEAM and SITE markers unless pre-configured via DOMjudge credentials
if [ ! -s "$UTILDIR/domjudge_credentials" ]; then
  rm -f "$UTILDIR"/TEAM* "$UTILDIR/SITE"
else
  rm -f "$UTILDIR/SITE"
fi

# Remove the team wallpaper
rm -f $UTILDIR/teamWallpaper.png

# Delete the printers/printer class
for PRINTER in $(lpstat -v | cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done
lpadmin -x ContestPrinter

# Re-apply configured print server if set in /icpc/PRINT_*
if [ -x "$UTILDIR/scripts/printing_configure" ]; then
  "$UTILDIR/scripts/printing_configure"
fi

# Cleanup apt cache/unnecessary package
apt-get autoremove --purge -y
apt-get clean

# Remove 'apt-get update' data
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial

# enable the firewall
ufw --force enable

# Delete /etc/machine-id so the image generates a new one on boot
echo "" > /etc/machine-id

# Remove build-VM persistent journal logs (present when install_target == "ssd")
if [ -d /var/log/journal ]; then
  systemctl stop systemd-journald.socket systemd-journald.service 2>/dev/null || true
  rm -rf /var/log/journal/*
fi

# Remove build-VM logs (ansible runs, apt, syslog from the build...) so the image
# ships with an empty /var/log. Binary archive logs (sysstat/pcp) and rotated/compressed
# logs are deleted; live text logs are truncated in place to preserve ownership/permissions.
rm -rf /var/log/sysstat/* /var/log/pcp/* /var/crash/* 2>/dev/null || true
find /var/log -type f -regextype posix-extended \( -name '*.gz' -o -name '*.xz' -o -name '*.zst' -o -name '*.old' -o -regex '.*\.[0-9]+' \) -delete 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true

# Lower the ext4 root-only reserved blocks from the default 5% to 1%.
# Contestant programs (VS Code etc.) run as a normal user and see "No space left on
# device" once usage reaches 100% minus this reserve. On a ~28GB root that's ~1.1GB
# handed back to contestants; 1% is still plenty for root to recover a full disk.
sync
ROOTDEV=$(findmnt -n -o SOURCE /)
if [ -n "$ROOTDEV" ] && [ "$(findmnt -n -o FSTYPE /)" = "ext4" ]; then
  tune2fs -m 1 "$ROOTDEV" || true
  sync
fi

# make sure wireguard config is wiped so it can be generated for each system on boot
#systemctl stop wg-setup
#wg-quick down contest
#rm -f /etc/wireguard/contest.conf

# Free up space(just to make the image smaller)
dd if=/dev/zero of=/empty bs=1M || true
rm -f /empty
sync
