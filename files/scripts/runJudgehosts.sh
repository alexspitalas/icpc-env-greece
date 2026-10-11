#!/bin/sh

# Set the DOMSERVER_BASEURL IP address
DOMSERVER_IP="192.168.31.200"
DOMSERVER_PORT="80"

# Set the password for all containers
JUDGEDAEMON_PASSWORD="your-secure-password"

# Set the hostname of the judgehost (different for each pc)
HOSTNAME="judgedaemon-0"

# Get the number of processors
NUM_PROCESSORS=$(nproc)

# Calculate the number of containers to spawn
CONTAINER_COUNT=$((NUM_PROCESSORS - 1))

# Loop to run Docker containers equal to the number of processors minus one
for i in $(seq 0 $((CONTAINER_COUNT - 1)))
do
    docker create --privileged \
        --name judgehost-$i \
        --hostname $HOSTNAME \
        -e DAEMON_ID=$i \
        -e CONTAINER_TIMEZONE=Europe/Athens \
        -e DOMSERVER_BASEURL=http://$DOMSERVER_IP:$DOMSERVER_PORT/ \
        -e JUDGEDAEMON_PASSWORD=$JUDGEDAEMON_PASSWORD \
        domjudge/judgehost:8.3.1
done
