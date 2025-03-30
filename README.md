# My Scripts

Some random scripts

## date-to-originaldate
Musicbrainz uses the specific release date for the year/ date tags for albums. This script changes the year/ date to the original release date.

Usage: bash date-to-originaldate.sh /media/music

Optionally add --days flag to only process files that have been modified recently, handy for speeding up regular jobs.

bash date-to-originaldate.sh /media/music --days 1
