#!/bin/bash

# Configuration
SERVER="localhost:9091"
USER="XXXX"
PASS="XXXX"
IGNORE_FILE="$HOME/.torrent_ignore_list"  # File to store ignored torrent IDs

# Time in seconds for seed cutoff (4 days)
SEED_CUTOFF=$((4 * 24 * 60 * 60))

# Use transmission-remote to get the list of torrents
TRANSMISSION_COMMAND="transmission-remote $SERVER -n $USER:$PASS"

# Create ignore file if it doesn't exist
[ -f "$IGNORE_FILE" ] || touch "$IGNORE_FILE"

# Get list of torrent IDs
TORRENT_ID_LIST=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $1}' | sed -e 's/[^0-9]*//g')

# Loop through each torrent ID
for TORRENT_ID in $TORRENT_ID_LIST; do
    # Check if torrent is in ignore list
    if grep -q "^${TORRENT_ID}$" "$IGNORE_FILE"; then
        TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
        echo "Skipping ignored torrent '$TORRENT_NAME' with ID $TORRENT_ID"
        continue
    fi

    # Get the seeding time for each torrent
    SEED_TIME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Seeding Time" | sed 's/.*(\(.*\) seconds)/\1/')
    
    # Check if SEED_TIME is empty (for torrents that haven't started seeding)
    if [ -z "$SEED_TIME" ]; then
        SEED_TIME=0
    fi
    
    # Get the name of the torrent
    TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
    
    # If the seeding time is greater than the cutoff, pause the torrent
    if [ $SEED_TIME -gt $SEED_CUTOFF ]; then
        echo "Pausing torrent '$TORRENT_NAME' with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
        $TRANSMISSION_COMMAND -t $TORRENT_ID --stop
    else
        echo "Keeping torrent '$TORRENT_NAME' active with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
    fi
done

