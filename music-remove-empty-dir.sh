#!/bin/bash

# Define the directory to search
search_dir="/media/music"

echo "Here's the list of directories without music files that would be deleted in $search_dir:"
find "$search_dir" -type d -exec sh -c '
    for dir do
        if [ -z "$(find "$dir" -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" \))">
            echo "$dir"
        fi
    done' sh {} + | sort

echo -n "Do you want to delete these directories? (y/n): "
read answer
if [ "$answer" != "${answer#[Yy]}" ]; then
    echo "Deleting directories..."
    find "$search_dir" -type d -exec sh -c '
        for dir do
            if [ -z "$(find "$dir" -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.wma" >
                rm -r "$dir"
            fi
        done' sh {} +
    echo "Deletion completed."
else
    echo "Deletion cancelled."
fi


