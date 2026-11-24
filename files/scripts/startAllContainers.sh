#!/bin/bash

# Check for any stopped containers
stopped_containers=$(docker ps -a -f status=exited -f status=created --format "{{.Names}}" | sort)

if [ -z "$stopped_containers" ]; then
    echo "No stopped containers found."
else
    # Start all stopped containers
    docker start $stopped_containers
    echo "Started the following containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
fi
