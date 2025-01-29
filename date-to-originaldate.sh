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

  case "$ext" in
    flac)
      local original_date=$(metaflac --show-tag=ORIGINALDATE "$file" | cut -d= -f2)
      local current_date=$(metaflac --show-tag=DATE "$file" | cut -d= -f2)
      ;;
    mp3|m4a|wav|wma)
      local original_date=$(exiftool -OriginalDate -s3 "$file")
      local current_date=$(exiftool -Date -s3 "$file")
      ;;
    *)
      echo "Skipping unsupported file type: $file"
      return
      ;;
  esac

  echo "DEBUG: File: $file"
  echo "DEBUG: ORIGINALDATE: $original_date"
  echo "DEBUG: DATE: $current_date"

  # Check if ORIGINALDATE exists
  if [[ -n "$original_date" ]]; then
    # Skip if DATE already matches ORIGINALDATE
    if [[ "$current_date" == "$original_date" ]]; then
      echo "DATE already matches ORIGINALDATE. Skipping: $file"
      return
    fi

    # Update DATE metadata
    case "$ext" in
      flac)
        metaflac --remove-tag=DATE --set-tag=DATE="$original_date" "$file"
        ;;
      mp3)
        id3v2 --year "$original_date" "$file"  # Use --year for mp3
        ;;
      m4a|wav|wma)
        exiftool -overwrite_original -Date="$original_date" "$file"
        ;;
    esac

    if [[ $? -eq 0 ]]; then
      echo "Updated DATE tag for: $file"
    else
      echo "Failed to update DATE tag for: $file"
    fi
  else
    echo "No ORIGINALDATE tag found in: $file"
    
    # Fall back to "Original Release Year" if no ORIGINALDATE
    local release_year=""
    if [[ "$ext" == "mp3" || "$ext" == "m4a" || "$ext" == "wma" ]]; then
      release_year=$(exiftool -OriginalReleaseYear -s3 "$file")
    fi

    if [[ -n "$release_year" ]]; then
      echo "Using Original Release Year as fallback: $release_year"
      
      # Update DATE metadata with the release year
      case "$ext" in
        flac)
          metaflac --remove-tag=DATE --set-tag=DATE="$release_year" "$file"
          ;;
        mp3)
          id3v2 --year "$release_year" "$file"  # Use --year for mp3
          ;;
        m4a|wav|wma)
          exiftool -overwrite_original -Date="$release_year" "$file"
          ;;
      esac

      if [[ $? -eq 0 ]]; then
        echo "Updated DATE tag with Original Release Year for: $file"
      else
        echo "Failed to update DATE tag with Original Release Year for: $file"
      fi
    else
      echo "No Original Release Year tag found in: $file"
    fi
  fi
}

# Process all files passed as arguments or in a directory
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <audio_file1> [audio_file2 ...] or $0 <directory>"
  exit 1
fi

if [[ -d "$1" ]]; then
  # Process all supported audio files in the directory
  find "$1" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.wav" -o -iname "*.wma" \) | while read -r file; do
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
