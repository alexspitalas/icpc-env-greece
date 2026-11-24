#!/bin/bash

# Remove the team wallpaper
rm -f /icpc/teamWallpaper.png

# Delete the printers/printer class
for PRINTER in $(lpstat -v | cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done
lpadmin -x ContestPrinter

# Re-apply configured print server if set in /icpc/PRINT_*
if [ -x /icpc/scripts/printing_configure ]; then
  /icpc/scripts/printing_configure
fi

# clear saved DOMjudge credentials and print team name before recreating the user so .netrc is not restored
rm -f /icpc/domjudge_credentials
rm -f /icpc/PRINT_TEAM

# clear the user
/icpc/scripts/deleteUser.sh
rm -f /home/contestant/.netrc

# make sure the firewall is on and reloaded (ensuring xt_owner UID rules are current)
ufw --force enable
ufw reload >/dev/null 2>&1 || true

rm -f /icpc/setup-complete
rm -f /icpc/TEAM*
rm -f /icpc/SITE

# reset squid autologin and reload squid if running
if [ -x /icpc/scripts/domjudge_apply_creds ]; then
  /icpc/scripts/domjudge_apply_creds --reload-squid
else
  echo "# Placeholder" > /etc/squid/autologin.conf
  chmod 640 /etc/squid/autologin.conf
  if getent group proxy >/dev/null 2>&1; then
    chown root:proxy /etc/squid/autologin.conf
  else
    chown root:root /etc/squid/autologin.conf
  fi
fi

# clear self test report
rm -f /icpc/self_test_report
