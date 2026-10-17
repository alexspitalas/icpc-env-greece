#!/bin/bash
# Refresh DNS caches and restart Squid proxy to pick up changes
# to allowed domains (e.g. grcpc.gr) without needing to reboot.

# Auto-elevate via sudo if run by an unprivileged user (contestant has NOPASSWD for this script)
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

echo "=================================================="
echo "    Refreshing ICPC Contest Network Connection    "
echo "=================================================="

# 1. Flush local DNS cache in systemd-resolved (if running)
echo "[1/3] Flushing local DNS cache..."
if command -v resolvectl >/dev/null 2>&1; then
    resolvectl flush-caches 2>/dev/null || true
elif command -v systemd-resolve >/dev/null 2>&1; then
    systemd-resolve --flush-caches 2>/dev/null || true
fi

# 2. Restart Squid proxy so it purges its in-memory IP cache
echo "[2/3] Restarting Squid proxy..."
if systemctl is-active --quiet squid 2>/dev/null; then
    systemctl restart squid
elif command -v squid >/dev/null 2>&1; then
    squid -k reconfigure 2>/dev/null || systemctl restart squid 2>/dev/null || true
fi

# 3. Check connection to all allowed domains
echo "[3/3] Checking connection to allowed domains..."

# Read allowed domains from squid acl file if available
DOMAINS=()
ACL_FILE="/etc/squid/acl_allowed_domains.txt"

if [ -f "$ACL_FILE" ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Strip leading dot and spaces
        d="${line#"."}"
        d="${d// /}"
        [ -n "$d" ] && DOMAINS+=("$d")
    done < "$ACL_FILE"
fi

# Fallback defaults if ACL file is missing or empty
if [ ${#DOMAINS[@]} -eq 0 ]; then
    DOMAINS=("grcpc.gr" "cppreference.com" "docs.python.org" "docs.oracle.com" "domjudge.org")
fi

FAILURES=0
SUCCESSES=0

for domain in "${DOMAINS[@]}"; do
    IP=$(getent ahosts "$domain" 2>/dev/null | awk '/STREAM/ { print $1 }' | head -n 1)
    
    # Choose port: 8050 for contest servers (grcpc.gr or local contest IP), standard 80/443 for others
    if [ "$domain" = "grcpc.gr" ] || [ "$domain" = "150.140.142.30" ]; then
        # Try port 8050 first, fallback to 80
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 4 -x http://127.0.0.1:3128 "http://$domain:8050/" 2>/dev/null || echo "000")
        target_display="$domain:8050"
        if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "504" ]; then
            FALLBACK_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 4 -x http://127.0.0.1:3128 "http://$domain/" 2>/dev/null || echo "000")
            if [ "$FALLBACK_CODE" != "000" ] && [ "$FALLBACK_CODE" != "502" ] && [ "$FALLBACK_CODE" != "503" ] && [ "$FALLBACK_CODE" != "504" ]; then
                HTTP_CODE="$FALLBACK_CODE"
                target_display="$domain:80"
            fi
        fi
    else
        target_display="$domain"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 4 -x http://127.0.0.1:3128 "http://$domain/" 2>/dev/null || echo "000")
    fi

    ip_info="${IP:-no IP}"
    if [ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "502" ] && [ "$HTTP_CODE" != "503" ] && [ "$HTTP_CODE" != "504" ]; then
        echo "  [OK]   $target_display ($ip_info) -> HTTP $HTTP_CODE"
        SUCCESSES=$((SUCCESSES + 1))
    else
        echo "  [FAIL] $target_display ($ip_info) -> HTTP $HTTP_CODE"
        FAILURES=$((FAILURES + 1))
    fi
done

echo "=================================================="
if [ "$FAILURES" -eq 0 ]; then
    echo " SUCCESS: All allowed domains are reachable!"
else
    echo " Completed with $SUCCESSES reachable, $FAILURES unreachable."
    echo " If contest sites remain unreachable, check network/Wi-Fi or ask a proctor."
fi
echo "=================================================="

if [ -t 0 ]; then
    echo ""
    read -t 10 -n 1 -s -r -p "Press any key to close (auto-close in 10s)..." || true
    echo ""
fi
