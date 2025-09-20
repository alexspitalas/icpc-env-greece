#!/bin/bash
set -e

# List of contest hosts to allow
HOSTS=(
  "grcpc.gr"
  "grcpc.upatras.gr"
)

# Resolve each host and apply UFW rules
for host in "${HOSTS[@]}"; do
  # Lookup unique IP addresses for this host
  IPS=$(getent ahosts "$host" \
        | awk '/STREAM/ { print $1 }' \
        | sort -u)

  # Apply allow rules for each resolved IP
  for ip in $IPS; do
    ufw allow from "$ip" comment "Allow inbound to $host"
    ufw allow out   to "$ip" comment "Allow outbound to $host"
  done
done


# Existing static rules
ufw allow from 155.207.131.147
ufw allow out to 155.207.131.147 
ufw allow from 150.140.140.3
ufw allow out to 150.140.140.3
ufw allow from 147.102.38.187 
ufw allow out to 147.102.38.187
ufw allow from 192.168.0.0/16 
ufw allow out to 192.168.0.0/16
ufw allow from 150.140.142.45 
ufw allow out to 150.140.142.45 
ufw allow ssh

# Default policy
ufw default deny incoming
ufw default deny outgoing


ufw reload


