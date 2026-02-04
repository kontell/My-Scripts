# My Scripts

Some random scripts

## retardate.sh
Musicbrainz uses the specific release date for the year/ date tags of albums. This script changes the year/ date to the original release date.

Usage: `bash retardate.sh /media/music`

Optionally add --days flag to only process files that have been modified recently, handy for speeding up regular jobs.

`bash retardate.sh /media/music --days 1`

## grab-epg.sh
This uses the iptv-org [epg](https://github.com/iptv-org/epg/) project to grab multiple epgs, merge them into a single file and trim old data.

Edit the script with the location of the epg github project you pulled along with the path to store your guide data. Add the script xmltv-order.py to the EPG directory. Adjust the sites/ lists of channels as required.

The script uses xmltv-util for merging & trimming.

By default the script pulls 9 days of data but the number of days can be passed with an argument: `bash grab-epg.sh 1`

## pause-old-seeds.sh
Pauses torrents in transmission that have been seeding for a given period of time (ignore list is available)
