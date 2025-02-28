import requests
import json
import os
import sys
from pathlib import Path

# Configuration
RADARR_URL = "http://localhost:7878/api/v3"
API_KEY = "your_api_key_here"
QUALITY_PROFILE_NAME = "1080p"
ALLOWED_QUALITIES = ["HDTV-1080p", "WEBRip 1080p", "WEBDL 1080p", "Bluray-1080p", "Remux-1080p"]
MAX_CUSTOM_SCORE = 5
BATCH_SIZE = 5

# File paths for storing data
MOVIE_LIST_FILE = "/opt/searadarr/filtered_movies_cf.json"
SEARCHED_MOVIES_FILE = "/opt/searadarr/searched_movies_cf.txt"

# Headers for API requests
HEADERS = {"X-Api-Key": API_KEY}

def get_quality_profile_id():
    """Retrieve the quality profile ID for the specified 1080p profile."""
    response = requests.get(f"{RADARR_URL}/qualityprofile", headers=HEADERS)
    if response.status_code == 200:
        profiles = response.json()
        for profile in profiles:
            if profile["name"] == QUALITY_PROFILE_NAME:
                return profile["id"]
        raise Exception(f"Quality profile '{QUALITY_PROFILE_NAME}' not found.")
    raise Exception(f"Failed to fetch quality profiles - Status: {response.status_code}")

def fetch_all_movies():
    """Fetch all movies from Radarr."""
    response = requests.get(f"{RADARR_URL}/movie", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    raise Exception("Failed to fetch movies from Radarr.")

def get_movie_file_details(movie_file_id):
    """Fetch detailed movie file info to get accurate customFormatScore."""
    response = requests.get(f"{RADARR_URL}/moviefile/{movie_file_id}", headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    print(f"Failed to fetch movie file details for ID {movie_file_id} - Status: {response.status_code}")
    return None

def filter_movies(movies, quality_profile_id):
    """Filter movies based on quality profile, file quality, and custom format score."""
    filtered_movies = []
    for movie in movies:
        if movie.get("qualityProfileId") != quality_profile_id:
            continue
        if "movieFile" not in movie:
            continue
        file_quality = movie["movieFile"]["quality"]["quality"]["name"]
        if file_quality not in ALLOWED_QUALITIES:
            continue

        # Fetch accurate custom format score from /moviefile
        movie_file_id = movie["movieFile"]["id"]
        detailed_file = get_movie_file_details(movie_file_id)
        custom_score = detailed_file.get("customFormatScore") if detailed_file else 0

        print(f"Movie: {movie['title']}")
        print(f"  Quality: {file_quality}")
        print(f"  CustomFormatScore: {custom_score}")

        if custom_score > MAX_CUSTOM_SCORE:
            continue

        filtered_movies.append({
            "id": movie["id"],
            "title": movie["title"],
            "quality": file_quality,
            "customFormatScore": custom_score
        })
    return filtered_movies

def save_movie_list(movies):
    """Save the filtered movie list to a JSON file."""
    with open(MOVIE_LIST_FILE, "w") as f:
        json.dump(movies, f, indent=4)
    print(f"Saved {len(movies)} movies to {MOVIE_LIST_FILE}")

def load_movie_list():
    """Load the filtered movie list from a JSON file."""
    if not os.path.exists(MOVIE_LIST_FILE):
        raise Exception(f"No existing movie list found at {MOVIE_LIST_FILE}. Please generate one first.")
    with open(MOVIE_LIST_FILE, "r") as f:
        return json.load(f)

def load_searched_movies():
    """Load the set of previously searched movie IDs."""
    searched = set()
    if os.path.exists(SEARCHED_MOVIES_FILE):
        with open(SEARCHED_MOVIES_FILE, "r") as f:
            for line in f:
                if line.strip():
                    searched.add(int(line.strip()))
    return searched

def save_searched_movie(movie_id):
    """Append a searched movie ID to the file."""
    with open(SEARCHED_MOVIES_FILE, "a") as f:
        f.write(f"{movie_id}\n")

def search_movies(movie_list, batch_size):
    """Perform an automatic search for a batch of movies."""
    searched_movies = load_searched_movies()
    to_search = [m for m in movie_list if m["id"] not in searched_movies][:batch_size]
    
    if not to_search:
        print("No new movies to search for.")
        return
    
    for movie in to_search:
        payload = {"movieIds": [movie["id"]]}
        response = requests.post(f"{RADARR_URL}/command", headers=HEADERS, json={"name": "MoviesSearch", **payload})
        if response.status_code == 201:
            print(f"Triggered search for '{movie['title']}' (ID: {movie['id']})")
            save_searched_movie(movie["id"])
        else:
            print(f"Failed to search for '{movie['title']}' (ID: {movie['id']}) - Status: {response.status_code}")
    
    print(f"Completed search for {len(to_search)} movies.")

def main():
    # Default to option 2 (use existing list) if no argument provided
    choice = sys.argv[1] if len(sys.argv) > 1 else "2"
    
    if choice == "1":
        print("Generating new movie list...")
        quality_profile_id = get_quality_profile_id()
        all_movies = fetch_all_movies()
        filtered_movies = filter_movies(all_movies, quality_profile_id)
        save_movie_list(filtered_movies)
        print(f"Found {len(filtered_movies)} movies matching criteria.")
        search_movies(filtered_movies, BATCH_SIZE)
    
    elif choice == "2":
        print("Loading existing movie list...")
        filtered_movies = load_movie_list()
        print(f"Loaded {len(filtered_movies)} movies from {MOVIE_LIST_FILE}.")
        search_movies(filtered_movies, BATCH_SIZE)
    
    else:
        print(f"Invalid choice: {choice}. Use '1' for new list or '2' for existing list.")
        sys.exit(1)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


