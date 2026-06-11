#!/bin/bash
# Set the contest wallpaper for the current XFCE session.
#
# This runs from /etc/xdg/autostart on login. The previous version only updated
# xfce4-desktop properties that already existed (xfconf-query --list | grep
# last-image); on a fresh session those properties may not exist yet, so it set
# nothing and the wallpaper appeared "randomly". We now wait for xfdesktop and
# create the property explicitly as a fallback.

WALLPAPER="/icpc/wallpaper.png"
# Allow a per-team override if one was placed by the reset/setup scripts.
[ -f /icpc/teamWallpaper.png ] && WALLPAPER="/icpc/teamWallpaper.png"

# Wait (up to ~30s) for xfdesktop to be running before touching xfconf.
for _ in $(seq 1 30); do
    pgrep -x xfdesktop >/dev/null 2>&1 && break
    sleep 1
done

# Update every existing last-image property (covers all monitors/workspaces)...
mapfile -t props < <(xfconf-query --channel xfce4-desktop --list 2>/dev/null | grep 'last-image')
for p in "${props[@]}"; do
    xfconf-query --channel xfce4-desktop --property "$p" --set "$WALLPAPER"
done

# ...and make sure monitor0 is set even if no property existed yet.
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/last-image \
    --create -t string -s "$WALLPAPER"
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-style \
    --create -t int -s 3
