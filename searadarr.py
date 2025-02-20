import requests
import json
import os

# Radarr API endpoint
radarr_url = "http://localhost:7878/api/v3"

# Your API key (replace with your actual API key)
api_key = "your_api_key_here"

# Number of movies to search in one batch
batch_size = 10

# File to store searched movie IDs
searched_movies_file = 'searched_movies.txt'

def radarr_api_request(endpoint, method='GET', data=None, params=None):
    headers = {
        'X-Api-Key': api_key,
        'Content-Type': 'application/json'
    }
    url = f"{radarr_url}/{endpoint}"
    
    if method == 'GET':
        response = requests.get(url, headers=headers, params=params)
    elif method == 'POST':
        response = requests.post(url, headers=headers, json=data)
    else:
        raise ValueError("Unsupported method")
    
    response.raise_for_status()
    return response.json()

def get_wanted_movies():
    all_missing = []
    all_cutoff = []
    page = 1
    page_size = 100  # Fetch 100 movies per page

    # Fetch all missing movies
    while True:
        params = {'page': page, 'pageSize': page_size}
        missing = radarr_api_request("wanted/missing", params=params)
        missing_movies = missing.get('records', [])
        all_missing.extend(missing_movies)
        if len(missing_movies) < page_size:  # Last page
            break
        page += 1
    
    # Reset page for cutoff
    page = 1
    while True:
        params = {'page': page, 'pageSize': page_size}
        cutoff = radarr_api_request("wanted/cutoff", params=params)
        cutoff_movies = cutoff.get('records', [])
        all_cutoff.extend(cutoff_movies)
        if len(cutoff_movies) < page_size:  # Last page
            break
        page += 1
    
    return all_missing + all_cutoff

def search_movie(movie_id):
    return radarr_api_request(f"command", method='POST', 
                              data={"name": "MoviesSearch", "movieIds": [movie_id]})

def load_searched_movies():
    if os.path.exists(searched_movies_file):
        with open(searched_movies_file, 'r') as f:
            return set(f.read().splitlines())
    return set()

def save_searched_movie(movie_id):
    with open(searched_movies_file, 'a') as f:
        f.write(f"{movie_id}\n")

def process_one_batch(movies):
    searched_movies = load_searched_movies()
    unsearched_movies = [movie for movie in movies if str(movie['id']) not in searched_movies]
    
    if unsearched_movies:
        batch = unsearched_movies[:batch_size]
        print(f"Searching for batch of {len(batch)} movies:")
        for movie in batch:
            movie_id = movie['id']
            print(f"  - Searching for {movie['title']} (ID: {movie_id})")
            try:
                search_movie(movie_id)  # Call the search function but don’t print the result
                save_searched_movie(str(movie_id))
            except requests.exceptions.HTTPError as e:
                print(f"    Error searching for movie ID {movie_id}: {e}")
        
        print("\nBatch search completed.")
    else:
        print("No new movies to search. All movies have been searched.")

if __name__ == "__main__":
    all_movies = get_wanted_movies()
    process_one_batch(all_movies)
