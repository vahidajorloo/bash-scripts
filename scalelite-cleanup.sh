#!/bin/bash

# Path to the directory where recordings are stored
BASE_DIR="/mnt/scalelite-recordings/var/bigbluebutton/published/presentation"

# Number of days (N): directories older than this will be deleted
DAYS_OLD=30  # <-- Change this as needed

# Safety check: ensure the directory exists
if [ -d "$BASE_DIR" ]; then
    echo "Deleting directories older than $DAYS_OLD days in $BASE_DIR ..."
    find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +$DAYS_OLD -exec rm -rf {} +
    echo "Cleanup complete."
else
    echo "Error: Directory $BASE_DIR does not exist."
    exit 1
fi
