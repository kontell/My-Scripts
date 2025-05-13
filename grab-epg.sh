#!/bin/bash

# Define variables
EPG_GRABBER_PATH=~$HOME/epg
GUIDE_PATH=/media/guides/
CUTOFF_TIME=$(date -u -d '1 day ago' +%Y%m%d%H%M%S) # Generate timestamp for guide trim (UTC)
DAYS=${1:-9} # Set number of days to grab from argument (default to 9 if not provided)
LOCK_FILE=${GUIDE_PATH}/merge.lock

# Function to process each guide
process_guide() {
    local config=$1
    local channels=$2
    local max_conn=$3
    local site=$(basename "$(dirname "$config")")

    # Grab
    /usr/bin/node ${EPG_GRABBER_PATH}/node_modules/epg-grabber/bin/epg-grabber.js \
        --config=$config \
        --channels=$channels \
        --days=$DAYS \
        --max-connections=$max_conn \
        --output=${GUIDE_PATH}/tmp/${site}.xml

    # Format XML for readability
    xmllint --format ${GUIDE_PATH}/tmp/${site}.xml -o ${GUIDE_PATH}/tmp/${site}.xml

    # Fix icon placement and image fallback
    python3 ${EPG_GRABBER_PATH}/xmltv-order.py \
        ${GUIDE_PATH}/tmp/${site}.xml \
        ${GUIDE_PATH}/tmp/${site}.fixed.xml

    mv ${GUIDE_PATH}/tmp/${site}.fixed.xml ${GUIDE_PATH}/tmp/${site}.xml

    # Sort
    tv_sort \
        --by-channel \
        ${GUIDE_PATH}/tmp/${site}.xml \
        --output ${GUIDE_PATH}/tmp/${site}.sorted.xml \
        2> >(grep -v 'not expected here' >&2)

    # Merge with locking
    (
        # Wait for lock
        while ! mkdir $LOCK_FILE 2>/dev/null; do
            sleep 1
        done

        # Fix order of display-name
        sed -i -E '/<channel id=/ {N;N; s#(<channel id="[^"]+">\n)\s*<url>(.*?)</url>\n\s*<display-name>(.*?)</display-name>#\1  <display-name>\3</display-name>\n  <url>\2</url>#}' ${GUIDE_PATH}/guide.xml

        # Sort master guide
        tv_sort \
            --by-channel \
            ${GUIDE_PATH}/guide.xml \
            --output ${GUIDE_PATH}/guide.xml

        # Perform merge
        tv_merge \
            -i ${GUIDE_PATH}/guide.xml \
            -m ${GUIDE_PATH}/tmp/${site}.sorted.xml \
            -o ${GUIDE_PATH}/guide.xml

        # Release lock
        rmdir $LOCK_FILE
    )
}

# Process each guide in parallel
process_guide \
    ${EPG_GRABBER_PATH}/sites/sky.com/sky.com.config.js \
    ${EPG_GRABBER_PATH}/sites/sky.com/sky.com.channels.custom.xml \
    2 \
    &
process_guide \
    ${EPG_GRABBER_PATH}/sites/player.ee.co.uk/player.ee.co.uk.config.js \
    ${EPG_GRABBER_PATH}/sites/player.ee.co.uk/player.ee.co.uk.channels.custom.xml \
    1 \
    &
process_guide \
    ${EPG_GRABBER_PATH}/sites/dstv.com/dstv.com.config.js \
    ${EPG_GRABBER_PATH}/sites/dstv.com/dstv.com_za.channels.custom.xml \
    2 \
    &
process_guide \
    ${EPG_GRABBER_PATH}/sites/sky.co.nz/sky.co.nz.config.js \
    ${EPG_GRABBER_PATH}/sites/sky.co.nz/sky.co.nz.channels.custom.xml \
    1 \
    &
process_guide \
    ${EPG_GRABBER_PATH}/sites/tv24.co.uk/tv24.co.uk.config.js \
    ${EPG_GRABBER_PATH}/sites/tv24.co.uk/tv24.co.uk.channels.custom.xml \
    1 \
    &
process_guide \
    ${EPG_GRABBER_PATH}/sites/i.mjh.nz/i.mjh.nz.config.js \
    ${EPG_GRABBER_PATH}/sites/i.mjh.nz/i.mjh.nz_skysportnow.channels.custom.xml \
    1 \
    &

wait

# Reorder (otherwise tv_grep will error) & format
sed -i -E '/<channel id=/ {N;N; s#(<channel id="[^"]+">\n)\s*<url>(.*?)</url>\n\s*<display-name>(.*?)</display-name>#\1  <display-name>\3</display-name>\n  <url>\2</url>#}' ${GUIDE_PATH}/guide.xml
xmllint --format ${GUIDE_PATH}/guide.xml -o ${GUIDE_PATH}/guide.xml

# Trim old programs
tv_grep \
    --on-after $CUTOFF_TIME \
    ${GUIDE_PATH}/guide.xml \
    --output ${GUIDE_PATH}/guide.xml
