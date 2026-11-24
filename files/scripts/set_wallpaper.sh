#!/bin/bash
# Reliably apply the ICPC wallpaper across all XFCE monitors and workspaces.
# Runs via /etc/xdg/autostart/icpc_autostart.desktop at session login.

WALLPAPER="/icpc/wallpaper.png"
if [ -f "/icpc/teamWallpaper.png" ]; then
  WALLPAPER="/icpc/teamWallpaper.png"
fi
[ -f "$WALLPAPER" ] || exit 0

command -v xfconf-query >/dev/null 2>&1 || exit 0

# Wait for xfdesktop and xfconfd (D-Bus) to finish starting (avoids the first-login
# race where autostart runs before xfdesktop initializes its monitor properties).
# Use `xfconf-query -l` (all channels) because `xfce4-desktop` may not exist yet on a fresh profile.
UID_NUM="$(id -u)"
for _ in $(seq 1 30); do
  if pgrep -u "$UID_NUM" -x xfdesktop >/dev/null 2>&1 \
     && xfconf-query -l >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

set_prefix() {
  local prefix="$1"
  xfconf-query -c xfce4-desktop -p "${prefix}/last-image" --create -t string -s "$WALLPAPER" 2>/dev/null || true
  # Ensure image-style is not 0 ("None"); default to 5 ("Zoomed") if unset or 0.
  local style
  style="$(xfconf-query -c xfce4-desktop -p "${prefix}/image-style" 2>/dev/null || true)"
  if [ -z "$style" ] || [ "$style" = "0" ]; then
    xfconf-query -c xfce4-desktop -p "${prefix}/image-style" --create -t int -s 5 2>/dev/null || true
  fi
}

apply_wallpaper() {
  local props prop prefix ws_count ws mon

  props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null || true)"

  # 1. Update every existing last-image / image-path property in xfce4-desktop.
  while IFS= read -r prop; do
    [ -n "$prop" ] || continue
    xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" 2>/dev/null || true
    prefix="${prop%/*}"
    if [ -n "$prefix" ] && [ "$prefix" != "$prop" ]; then
      local style
      style="$(xfconf-query -c xfce4-desktop -p "${prefix}/image-style" 2>/dev/null || true)"
      if [ -z "$style" ] || [ "$style" = "0" ]; then
        xfconf-query -c xfce4-desktop -p "${prefix}/image-style" --create -t int -s 5 2>/dev/null || true
      fi
    fi
  done < <(printf '%s\n' "$props" | grep -E '/(last-image|image-path)$' || true)

  # 2. Ensure every existing /backdrop/screenN/monitorX/workspaceM branch has last-image set
  #    (XFCE 4.18 may create monitor branches without a last-image key on first login).
  while IFS= read -r prefix; do
    [ -n "$prefix" ] || continue
    set_prefix "$prefix"
  done < <(printf '%s\n' "$props" | sed -nE 's#^(/backdrop/screen[0-9]+/monitor[^/]+/workspace[0-9]+)/.*#\1#p' | sort -u)

  # 3. Explicitly create/set properties for every connected XRandR monitor (plus monitor0)
  #    even if xfdesktop has not written monitor keys to xfconf yet on a fresh home dir.
  ws_count="$(xfconf-query -c xfwm4 -p /general/workspace_count 2>/dev/null || echo 1)"
  if ! [[ "$ws_count" =~ ^[0-9]+$ ]] || [ "$ws_count" -lt 1 ]; then
    ws_count=1
  elif [ "$ws_count" -gt 8 ]; then
    ws_count=8
  fi

  local monitors=("0")
  if command -v xrandr >/dev/null 2>&1; then
    while IFS= read -r mon; do
      [ -n "$mon" ] && monitors+=("$mon")
    done < <(xrandr --query 2>/dev/null | awk '/ connected/{print $1}' | sort -u)
  fi

  for mon in "${monitors[@]}"; do
    for ((ws = 0; ws < ws_count; ws++)); do
      set_prefix "/backdrop/screen0/monitor${mon}/workspace${ws}"
    done
  done
}

apply_wallpaper
# Re-apply once after a brief delay to catch monitors that finish initializing late.
sleep 2
apply_wallpaper
