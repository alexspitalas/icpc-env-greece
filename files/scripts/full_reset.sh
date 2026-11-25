#!/bin/bash

# Remove the team wallpaper
rm -f /icpc/teamWallpaper.png

# Delete the printers/printer class
for PRINTER in $(lpstat -v | cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done
lpadmin -x ContestPrinter

# clear the user
/icpc/scripts/deleteUser.sh

# Ensure OpenSSH is allowed in UFW; keep firewall disabled on judgehosts (matches playbooks/firewall.yaml)
ufw allow OpenSSH || true
ufw --force disable || true

rm -f /icpc/setup-complete
rm -f /icpc/TEAM*
rm -f /icpc/SITE

# reset squid autologin (if squid is installed)
if [ -d /etc/squid ]; then
    echo "# Placeholder" > /etc/squid/autologin.conf
    chmod 640 /etc/squid/autologin.conf
    chown root:root /etc/squid/autologin.conf
fi

# clear self test report
rm -f /icpc/self_test_report
