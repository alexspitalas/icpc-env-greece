#!/bin/bash

# Remove the team wallpaper
rm -f /icpc/teamWallpaper.png

# Delete the printers/printer class
for PRINTER in $(lpstat -v | cut -d ' ' -f 3 | tr -d ':')
do
  lpadmin -x $PRINTER
done
lpadmin -x ContestPrinter

# clear saved DOMjudge credentials and print team name before recreating the user so .netrc is not restored
rm -f /icpc/domjudge_credentials
rm -f /icpc/PRINT_TEAM

# clear the user
/icpc/scripts/deleteUser.sh
rm -f /home/contestant/.netrc

# make sure the firewall is on
ufw --force enable

rm -f /icpc/setup-complete
rm -f /icpc/TEAM*
rm -f /icpc/SITE

# reset squid autologin
echo "# Placeholder" > /etc/squid/autologin.conf
chmod 640 /etc/squid/autologin.conf
if getent group proxy >/dev/null 2>&1; then
  chown root:proxy /etc/squid/autologin.conf
else
  chown root:root /etc/squid/autologin.conf
fi

# clear self test report
rm -f /icpc/self_test_report
