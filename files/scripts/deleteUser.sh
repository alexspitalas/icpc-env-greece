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

# BACKUP: Preserve important system/config files BEFORE deleting
echo "Backing up critical files..."

# Backup JetBrains license
if [[ -d /home/contestant/.config/JetBrains ]]; then
    mkdir -p /root/.config
    cp -r /home/contestant/.config/JetBrains /root/.config/
    echo "✓ JetBrains config backed up"
fi

# Backup system desktop entries (in case they get deleted)
if [[ -d /usr/share/applications ]]; then
    mkdir -p /root/backup_desktop_entries
    cp /usr/share/applications/*.desktop /root/backup_desktop_entries/ 2>/dev/null || true
    echo "✓ Desktop entries backed up"
fi

# DELETE: Remove contestant files and user
echo "Deleting team files..."
find / -user contestant ! -path "*/.config/*" -delete

echo "Deleting contestant user"
userdel contestant
rm -rf /home/contestant

echo "Recreating contestant user"
useradd -d /home/contestant -m contestant -G lpadmin -s /bin/bash
passwd -d contestant

# RESTORE: Bring back important files
echo "Restoring critical files..."

# Restore JetBrains license
if [[ -d /root/.config/JetBrains ]]; then
    mkdir -p /home/contestant/.config
    cp -r /root/.config/JetBrains /home/contestant/.config/
    chown -R contestant:contestant /home/contestant/.config/JetBrains
    chmod -R 0755 /home/contestant/.config/JetBrains  # Changed from 0600 to 0755
    chmod 0644 /home/contestant/.config/JetBrains/CLion*/clion.key  # License file readable
    echo "✓ JetBrains license restored with correct permissions"
fi

# Ensure .config has correct permissions
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