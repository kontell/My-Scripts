## grab-epg.sh
This uses the iptv-org [epg](https://github.com/iptv-org/epg/) project to grab multiple epgs, merge them into a single file and trim old data.

Edit the script with the location of the epg github project you pulled along with the path to store your guide data. Add the script xmltv-order.py to the EPG directory. Adjust the sites/ lists of channels as required.

The script uses xmltv-util for merging & trimming.

By default the script pulls 9 days of data but the number of days can be passed with an argument: `bash grab-epg.sh 1`
