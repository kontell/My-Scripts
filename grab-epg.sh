#!/bin/bash

# Define variables
EPG_GRABBER_PATH="/home/user/epg"
GUIDE_PATH="/media//guides"
CUTOFF_TIME=$(date -u -d '1 day ago' +%Y%m%d%H%M%S) # Generate timestamp for guide trim (UTC)

# Set number of days from argument (default to 9 if not provided)
DAYS=${1:-9}

# Grab Sky Guide
/usr/bin/node ${EPG_GRABBER_PATH}/node_modules/epg-grabber/bin/epg-grabber.js \
   --config=${EPG_GRABBER_PATH}/sites/sky.com/sky.com.config.js \
   --channels=${EPG_GRABBER_PATH}/sites/sky.com/sky.com.channels.custom.xml \
   --days=$DAYS \
   --max-connections=5 \
   --output=${GUIDE_PATH}/tmp/{site}.xml \
   &

# Grab EE Guide
/usr/bin/node ${EPG_GRABBER_PATH}/node_modules/epg-grabber/bin/epg-grabber.js \
   --config=${EPG_GRABBER_PATH}/sites/player.ee.co.uk/player.ee.co.uk.config.js \
   --channels=${EPG_GRABBER_PATH}/sites/player.ee.co.uk/player.ee.co.uk.channels.custom.xml \
   --days=$DAYS \
   --max-connections=1 \
   --output=${GUIDE_PATH}/tmp/{site}.xml \
   &

# Grab DSTV Guide
/usr/bin/node ${EPG_GRABBER_PATH}/node_modules/epg-grabber/bin/epg-grabber.js \
   --config=${EPG_GRABBER_PATH}/sites/dstv.com/dstv.com.config.js \
   --channels=${EPG_GRABBER_PATH}/sites/dstv.com/dstv.com_za.channels.custom.xml \
   --days=$DAYS \
   --max-connections=3 \
   --output=${GUIDE_PATH}/tmp/{site}.xml \
   &

# Grab Sky NZ Guide
/usr/bin/node ${EPG_GRABBER_PATH}/node_modules/epg-grabber/bin/epg-grabber.js \
   --config=${EPG_GRABBER_PATH}/sites/sky.co.nz/sky.co.nz.config.js \
   --channels=${EPG_GRABBER_PATH}/sites/sky.co.nz/sky.co.nz.channels.custom.xml \
   --days=$DAYS \
   --max-connections=1 \
   --output=${GUIDE_PATH}/tmp/{site}.xml \

wait

# Sort Guides
tv_sort \
   --by-channel \
   ${GUIDE_PATH}/tmp/sky.com.xml \
   --output ${GUIDE_PATH}/tmp/sky.com.sorted.xml \
   &
tv_sort \
   --by-channel \
   ${GUIDE_PATH}/tmp/player.ee.co.uk.xml \
   --output ${GUIDE_PATH}/tmp/player.ee.co.uk.sorted.xml \
   &
tv_sort \
   --by-channel \
   ${GUIDE_PATH}/tmp/dstv.com.xml \
   --output ${GUIDE_PATH}/tmp/dstv.com.sorted.xml \
   &
tv_sort \
   --by-channel \
   ${GUIDE_PATH}/tmp/sky.co.nz.xml \
   --output ${GUIDE_PATH}/tmp/sky.co.nz.sorted.xml \

wait

# Merge Guides
tv_merge \
   -i ${GUIDE_PATH}/guide.xml \
   -m ${GUIDE_PATH}/tmp/sky.com.sorted.xml \
   -o ${GUIDE_PATH}/guide.xml
tv_merge \
   -i ${GUIDE_PATH}/guide.xml \
   -m ${GUIDE_PATH}/tmp/player.ee.co.uk.sorted.xml \
   -o ${GUIDE_PATH}/guide.xml
tv_merge \
   -i ${GUIDE_PATH}/guide.xml \
   -m ${GUIDE_PATH}/tmp/dstv.com.sorted.xml \
   -o ${GUIDE_PATH}/guide.xml
tv_merge \
   -i ${GUIDE_PATH}/guide.xml \
   -m ${GUIDE_PATH}/tmp/sky.co.nz.sorted.xml \
   -o ${GUIDE_PATH}/guide.xml

# Reordered <display-name> to be the first child inside <channel>
sed -i -E '/<channel id=/ {N;N; s#(<channel id="[^"]+">\n)\s*<url>(.*?)</url>\n\s*<display-name>(.*?)</display-name>#\1  <display-name>\3</display-name>\n  <url>\2</url>#}' ${GUIDE_PATH}/guide.xml

# Fix indentaiton
xmllint --format ${GUIDE_PATH}/guide.xml -o ${GUIDE_PATH}/guide.xml

# Trim Old Programs
tv_grep \
   --on-after "$CUTOFF_TIME" \
   ${GUIDE_PATH}/guide.xml \
   --output ${GUIDE_PATH}/guide.xml
