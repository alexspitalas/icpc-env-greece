#!/bin/bash

# Define the source and destination directories (resolve relative to script location)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source="$SCRIPT_DIR/scripts"
destination="/home/contestant/Desktop"

# Check if the source directory exists
if [ ! -d "$source" ]; then
    echo "Source directory $source does not exist."
    exit 1
fi

# Check if the destination directory exists, if not, create it
if [ ! -d "$destination" ]; then
    echo "Destination directory $destination does not exist. Creating it now."
    mkdir -p "$destination"
fi

# Copy all files from the source directory to the destination directory
if cp "$source"/* "$destination"; then
    if [ "$(id -u)" -eq 0 ] && id contestant >/dev/null 2>&1; then
        chown -R contestant:contestant "$destination"
    fi
    echo "Copied all files from $source to $destination."
else
    echo "Failed to copy files from $source to $destination."
    exit 1
fi
