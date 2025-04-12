#!/bin/bash

# Configuration
SERVER="localhost:9091"
USER="XX"
PASS="XXXX"
IGNORE_FILE="$HOME/.torrent_ignore_list"  # File to store ignored torrent IDs
MIN_ACTIVE=10  # Minimum number of active torrents to keep

# Time in seconds for seed cutoff (4 days)
SEED_CUTOFF=$((4 * 24 * 60 * 60))

# Use transmission-remote to get the list of torrents
TRANSMISSION_COMMAND="transmission-remote $SERVER -n $USER:$PASS"

# Create ignore file if it doesn't exist
[ -f "$IGNORE_FILE" ] || touch "$IGNORE_FILE"

# Get list of torrent IDs and count active torrents
TORRENT_ID_LIST=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $1}' | sed -e 's/[^0-9]*//g')
TOTAL_TORRENTS=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | wc -l)
# Count torrents in Seeding, Downloading, Up & Down, or Idle states
ACTIVE_COUNT=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $9}' | grep -c -E "Seeding|Downloading|Up & Down|Idle")

# Log torrent information for debugging
echo "Total torrents: $TOTAL_TORRENTS"
echo "Statuses (column 9):"
$TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $9}' | sort | uniq -c
echo "Active torrents (Seeding/Downloading/Up & Down/Idle): $ACTIVE_COUNT"

# Calculate maximum number of torrents we can pause
if [ $ACTIVE_COUNT -ge $MIN_ACTIVE ]; then
    MAX_PAUSE=$((ACTIVE_COUNT - MIN_ACTIVE))
else
    MAX_PAUSE=$ACTIVE_COUNT
    echo "Warning: Active torrents ($ACTIVE_COUNT) below minimum ($MIN_ACTIVE), will pause only eligible torrents"
fi

PAUSED_COUNT=0

# Skip pausing if no torrents are active
if [ $ACTIVE_COUNT -eq 0 ]; then
    echo "No active torrents found, nothing to pause"
    exit 0
fi

echo "Can pause up to $MAX_PAUSE torrents"

# Loop through each torrent ID
for TORRENT_ID in $TORRENT_ID_LIST; do
    # Check if we've reached the pause limit
    if [ $PAUSED_COUNT -ge $MAX_PAUSE ]; then
        echo "Reached maximum pause limit ($MAX_PAUSE), keeping remaining torrents active"
        break
    fi

    # Check if torrent is in ignore list
    if grep -q "^${TORRENT_ID}$" "$IGNORE_FILE"; then
        TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
        echo "Skipping ignored torrent '$TORRENT_NAME' with ID $TORRENT_ID"
        continue
    fi

    # Get torrent status from detailed info (more reliable)
    STATUS=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "State:" | awk '{print $2}')

    # Only process torrents that could be seeding
    if ! echo "$STATUS" | grep -q -E "Seeding|Idle|Up & Down"; then
        TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
        echo "Skipping non-seeding torrent '$TORRENT_NAME' with ID $TORRENT_ID (Status: $STATUS)"
        continue
    fi

    # Get the seeding time for each torrent
    SEED_TIME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Seeding Time" | sed 's/.*(\(.*\) seconds)/\1/')
    
    # Check if SEED_TIME is empty
    if [ -z "$SEED_TIME" ]; then
        SEED_TIME=0
    fi
    
    # Get the name of the torrent
    TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
    
    # If the seeding time is greater than the cutoff, pause the torrent
    if [ $SEED_TIME -gt $SEED_CUTOFF ]; then
        echo "Pausing torrent '$TORRENT_NAME' with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
        $TRANSMISSION_COMMAND -t $TORRENT_ID --stop
        ((PAUSED_COUNT++))
    else
        echo "Keeping torrent '$TORRENT_NAME' active with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
    fi
done

echo "Paused $PAUSED_COUNT torrents, maintaining at least $MIN_ACTIVE active torrents"
