# My Scripts

Some random scripts

## date-to-originaldate.sh
Musicbrainz uses the specific release date for the year/ date tags of albums. This script changes the year/ date to the original release date.

Usage: `bash date-to-originaldate.sh /media/music`

Optionally add --days flag to only process files that have been modified recently, handy for speeding up regular jobs.

`bash date-to-originaldate.sh /media/music --days 1`

## grab-epg.sh
This uses the iptv-org [epg](https://github.com/iptv-org/epg/) project to grab multiple epgs, merge them into a single file and trim old data.

Edit the script with the location of the epg github project you pulled along with the path to store your guide data. Adjust the sites/ lists of channels as required.

The script uses xmltv-util for merging & trimming.

By default the script pulls 9 days of data but the number of days can be passed with an argument: `sh grab-epg.sh 1`

## music-remove-empty-dir.sh
Scans a music library and returns a list of directories without music files and gives an option to delete them.

## pause-old-seeds.sh
Pauses torrents in transmission that have been seeding for a given period of time (ignore list is available)

## searadarr_cf.py
In Radarr films that have not met their custom format threshold do not show up in wanted/ cutoff unmet. This script triggers a batch search of films that have met their quality requirements but have not met their custom format threshold.

## searadarr_wanted.py
Triggers a batch automatic search of films in Radarr which show up in wanted/missing or wanted/cutoff unmet.
