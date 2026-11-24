#!/bin/bash

# Kill all the user processes(and wait for them to die)
killall -9 -u contestant 2>/dev/null || true
sleep 5

# Prefer the built-in partition's GPT PARTUUID so a contestant USB stick labeled ICPC is never matched
DISK=""
if [[ -s /icpc/ICPC_PARTUUID ]]; then
    ICPC_PARTUUID="$(tr -d '[:space:]' < /icpc/ICPC_PARTUUID)"
    if [[ -n "$ICPC_PARTUUID" ]]; then
        DISK=$(blkid -t "PARTUUID=$ICPC_PARTUUID" -o device 2>/dev/null | head -n1 || true)
    fi
else
    DISK=$(blkid -L "ICPC" 2>/dev/null || true)
fi
if [[ -n "$DISK" && -b "$DISK" ]]; then
    echo "Wiping FAT32 Partition ($DISK)"
    umount "$DISK" 2>/dev/null || true
    mkfs.vfat "$DISK" -n ICPC
fi

# BACKUP: Preserve system desktop entries before recreating the user
echo "Backing up critical files..."

# Remove any legacy JetBrains backup under /root/.config (never back up user-controlled
# ~/.config/JetBrains as root — JetBrains defaults and CLion's clion.key live in /etc/skel/.config/JetBrains).
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

# Preserve contestant's numeric UID/GID so active iptables `--uid-owner contestant` rules never drift
OLD_UID=$(id -u contestant 2>/dev/null || true)
OLD_GID=$(id -g contestant 2>/dev/null || true)

echo "Deleting contestant user"
userdel -f -r contestant 2>/dev/null || true
rm -rf /home/contestant

echo "Recreating contestant user"
if [[ "$OLD_UID" =~ ^[0-9]+$ && "$OLD_GID" =~ ^[0-9]+$ ]]; then
    getent group contestant >/dev/null 2>&1 || groupadd -g "$OLD_GID" contestant 2>/dev/null || groupadd contestant
    useradd -u "$OLD_UID" -g contestant -d /home/contestant -m contestant -s /bin/bash
else
    useradd -d /home/contestant -m contestant -s /bin/bash
fi
passwd -d contestant

# Reload UFW if active so kernel xt_owner rules are guaranteed to match contestant's UID without rebooting
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q 'Status: active'; then
    ufw reload >/dev/null 2>&1 || true
fi

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