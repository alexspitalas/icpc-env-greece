#!/bin/bash
# Update DOMjudge team username and password without changing the server URL
# or needing to reboot / reset the account.

# Auto-elevate via sudo if run by an unprivileged user (contestant has NOPASSWD for this script)
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")"
fi

if [ "$(tr -d '[:space:]' < /icpc/DOMJUDGE_ENABLED 2>/dev/null | tr '[:upper:]' '[:lower:]')" != "true" ]; then
    echo "DOMjudge mode is not enabled on this image (/icpc/DOMJUDGE_ENABLED != true)."
    if [ -t 0 ]; then
        read -n 1 -s -r -p "Press any key to close..." || true
        echo ""
    fi
    exit 0
fi

unset ICPC_DIR CONTESTANT_HOME SQUID_DIR PROFILE_D_DIR GUIDE_DIR

/icpc/scripts/icpc_setup --domjudge-creds-only

if [ -t 0 ]; then
    echo ""
    read -t 5 -n 1 -s -r -p "Press any key to close (auto-close in 5s)..." || true
    echo ""
fi
