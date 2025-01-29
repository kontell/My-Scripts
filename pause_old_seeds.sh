#!/bin/bash

# Configuration
SERVER="localhost:9091"
USER="XXXX"
PASS="XXXX"

# Time in seconds for seed cutoff (3 days)
SEED_CUTOFF=$((4 * 24 * 60 * 60))

# Use transmission-remote to get the list of torrents
TRANSMISSION_COMMAND="transmission-remote $SERVER -n $USER:$PASS"

# Get list of torrent IDs
TORRENT_ID_LIST=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $1}' | sed -e 's/[^0-9]*//g')

# Loop through each torrent ID
for TORRENT_ID in $TORRENT_ID_LIST; do
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

