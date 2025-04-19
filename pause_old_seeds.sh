#!/bin/bash

# Configuration
SERVER="localhost:9091"
USER="XX"
PASS="XXXX"
IGNORE_FILE="$HOME/.torrent_ignore_list"
MIN_ACTIVE=10  # Minimum number of active torrents to keep
SEED_CUTOFF=$((4 * 24 * 60 * 60))

TRANSMISSION_COMMAND="transmission-remote $SERVER -n $USER:$PASS"

[ -f "$IGNORE_FILE" ] || touch "$IGNORE_FILE"

TORRENT_ID_LIST=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $1}' | sed -e 's/[^0-9]*//g')
TOTAL_TORRENTS=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | wc -l)
ACTIVE_COUNT=$($TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $9}' | grep -c -E "Seeding|Downloading|Up & Down|Idle")

echo "Total torrents: $TOTAL_TORRENTS"
echo "Statuses (column 9):"
$TRANSMISSION_COMMAND -l | sed -e '1d;$d' | awk '{print $9}' | sort | uniq -c
echo "Active torrents: $ACTIVE_COUNT"

if [ $ACTIVE_COUNT -le $MIN_ACTIVE ]; then
    MAX_PAUSE=0
    echo "Active torrents ($ACTIVE_COUNT) at or below minimum ($MIN_ACTIVE), no torrents will be paused"
else
    MAX_PAUSE=$((ACTIVE_COUNT - MIN_ACTIVE))
    echo "Can pause up to $MAX_PAUSE torrents"
fi

PAUSED_COUNT=0

if [ $MAX_PAUSE -eq 0 ]; then
    echo "No torrents will be paused"
    echo "Paused $PAUSED_COUNT torrents, $ACTIVE_COUNT torrents remain active (minimum: $MIN_ACTIVE)"
    exit 0
fi

for TORRENT_ID in $TORRENT_ID_LIST; do
    if [ $PAUSED_COUNT -ge $MAX_PAUSE ]; then
        echo "Reached maximum pause limit ($MAX_PAUSE), keeping remaining torrents active"
        break
    fi

    if grep -q "^${TORRENT_ID}$" "$IGNORE_FILE"; then
        TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
        echo "Skipping ignored torrent '$TORRENT_NAME' with ID $TORRENT_ID"
        continue
    fi

    STATUS=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "State:" | awk '{print $2}')
    if ! echo "$STATUS" | grep -q -E "Seeding|Idle|Up & Down"; then
        TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
        echo "Skipping non-seeding torrent '$TORRENT_NAME' with ID $TORRENT_ID (Status: $STATUS)"
        continue
    fi

    SEED_TIME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Seeding Time" | sed 's/.*(\(.*\) seconds)/\1/')
    [ -z "$SEED_TIME" ] && SEED_TIME=0
    TORRENT_NAME=$($TRANSMISSION_COMMAND -t $TORRENT_ID -i | grep "Name:" | cut -d ':' -f2- | sed 's/^ //')
    
    if [ $SEED_TIME -gt $SEED_CUTOFF ]; then
        echo "Pausing torrent '$TORRENT_NAME' with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
        $TRANSMISSION_COMMAND -t $TORRENT_ID --stop
        PAUSED_COUNT=$((PAUSED_COUNT + 1))
    else
        echo "Keeping torrent '$TORRENT_NAME' active with ID $TORRENT_ID, Seeding Time: $SEED_TIME seconds"
    fi
done

REMAINING_ACTIVE=$((ACTIVE_COUNT - PAUSED_COUNT))
echo "Paused $PAUSED_COUNT torrents, $REMAINING_ACTIVE torrents remain active (minimum: $MIN_ACTIVE)"
