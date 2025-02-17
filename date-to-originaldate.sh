#!/bin/bash

# Ensure required tools are installed
if ! command -v exiftool &> /dev/null && ! command -v id3v2 &> /dev/null; then
  echo "Neither ExifTool nor id3v2 is installed. Please install one of them and try again."
  exit 1
fi

if ! command -v metaflac &> /dev/null; then
  echo "metaflac is not installed. Please install it and try again."
  exit 1
fi

# Function to process a single file
process_file() {
  local file="$1"
  local ext="${file##*.}"
  local modified=false

  case "$ext" in
    flac)
      local original_date=$(metaflac --show-tag=ORIGINALDATE "$file" | cut -d= -f2)
      local current_date=$(metaflac --show-tag=DATE "$file" | cut -d= -f2)

      # Check if ORIGINALDATE exists
      if [[ -n "$original_date" ]]; then
        # Skip if DATE already matches ORIGINALDATE
        if [[ "$current_date" == "$original_date" ]]; then
          return
        else
          # Update DATE metadata
          metaflac --remove-tag=DATE --set-tag=DATE="$original_date" "$file"
          if [[ $? -eq 0 ]]; then
            modified=true
          fi
        fi
      fi
      ;;
    mp3|m4a|wav)
      local original_date=$(exiftool -OriginalDate -s3 "$file")
      local current_year=$(exiftool -Year -s3 "$file")  # Retrieve Year instead of Date

      # Check if ORIGINALDATE exists
      if [[ -n "$original_date" ]]; then
        # Extract just the year from the ORIGINALDATE
        local original_year=$(echo "$original_date" | cut -d- -f1)

        # Skip if YEAR already matches ORIGINALYEAR
        if [[ "$current_year" == "$original_year" ]]; then
          return
        else
          # Update YEAR metadata
          case "$ext" in
            mp3)
              id3v2 --year "$original_year" "$file"  # Use --year for mp3
              ;;
            m4a|wav)
              exiftool -overwrite_original -Year="$original_year" "$file"  # Update Year instead of Date
              ;;
          esac

          if [[ $? -eq 0 ]]; then
            modified=true
          fi
        fi
      else
        # Fall back to "Original Release Year" if no ORIGINALDATE
        local release_year=""
        if [[ "$ext" == "mp3" || "$ext" == "m4a" ]]; then
          release_year=$(exiftool -OriginalReleaseYear -s3 "$file")
        fi

        if [[ -n "$release_year" ]]; then
          # Skip if YEAR already matches Original Release Year
          if [[ "$current_year" == "$release_year" ]]; then
            return
          else
            # Update YEAR metadata with the release year
            case "$ext" in
              mp3)
                id3v2 --year "$release_year" "$file"  # Use --year for mp3
                ;;
              m4a|wav)
                exiftool -overwrite_original -Year="$release_year" "$file"  # Update Year instead of Date
                ;;
            esac

            if [[ $? -eq 0 ]]; then
              modified=true
            fi
          fi
        fi
      fi
      ;;
    *)
      return
      ;;
  esac

  if [[ "$modified" == true ]]; then
    echo "Updated tag for: $file"
  fi
}

# Process all files passed as arguments or in a directory
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <audio_file1> [audio_file2 ...] or $0 <directory>"
  exit 1
fi

if [[ -d "$1" ]]; then
  # Process all supported audio files in the directory
  find "$1" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.wav" \) | while read -r file; do
    process_file "$file"
  done
else
  # Process individual files
  for file in "$@"; do
    if [[ -f "$file" ]]; then
      process_file "$file"
    else
      echo "File not found: $file"
    fi
  done
fi

echo "Done."
