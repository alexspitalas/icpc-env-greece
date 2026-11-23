#!/bin/bash

# Kill all the user processes(and wait for them to die)
killall -9 -u contestant
sleep 5

DISK=$(blkid -L "ICPC")
if [[ $? == 0 ]]; then
    echo "Wiping FAT32 Partition"
    umount $DISK
    mkfs.vfat $DISK -n ICPC
fi

# BACKUP: Preserve system desktop entries before recreating the user
echo "Backing up critical files..."

# Remove any legacy JetBrains backup under /root/.config (never back up user-controlled
# ~/.config/JetBrains as root — CLion's clion.key is recreated at login by autostart and
# IntelliJ defaults live in /etc/skel/.config/JetBrains).
rm -rf /root/.config/JetBrains

# Backup system desktop entries (in case they get deleted)
if [[ -d /usr/share/applications ]]; then
    mkdir -p /root/backup_desktop_entries
    cp /usr/share/applications/*.desktop /root/backup_desktop_entries/ 2>/dev/null || true
    echo "✓ Desktop entries backed up"
fi

# DELETE: Remove contestant files and user
echo "Deleting team files..."
#find / -user contestant ! -path "*/.config/*" -delete

echo "Deleting contestant user"
userdel -f -r contestant 2>/dev/null || true
rm -rf /home/contestant

echo "Recreating contestant user"
useradd -d /home/contestant -m contestant -s /bin/bash
passwd -d contestant

# Ensure DOMjudge Squid autologin/API auth stays synced (and no ~/.netrc exists)
if [[ -x /icpc/scripts/domjudge_apply_creds ]]; then
    /icpc/scripts/domjudge_apply_creds --reload-squid
fi

# RESTORE: Bring back important files
echo "Restoring critical files..."

# Ensure .config exists with correct permissions
mkdir -p /home/contestant/.config
chmod 0755 /home/contestant/.config
chown contestant:contestant /home/contestant/.config

# Restore system desktop entries if missing
if [[ ! -f /usr/share/applications/clion.desktop ]] && [[ -d /root/backup_desktop_entries ]]; then
    cp /root/backup_desktop_entries/*.desktop /usr/share/applications/
    echo "✓ Desktop entries restored"
fi

# Recreate Desktop folder with shortcuts
echo "Recreating user Desktop shortcuts..."
mkdir -p /home/contestant/Desktop

# Copy templates if they exist
if [[ -d /root/DesktopTemplates ]]; then
    cp /root/DesktopTemplates/*.desktop /home/contestant/Desktop/
fi

# Set correct ownership and permissions
chown -R contestant:contestant /home/contestant/Desktop
chmod 0755 /home/contestant/Desktop
chmod +x /home/contestant/Desktop/*.desktop

echo "✓ Team reset complete. CLion license and desktop entries preserved."