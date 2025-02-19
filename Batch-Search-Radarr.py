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

def radarr_api_request(endpoint, method='GET', data=None):
    headers = {
        'X-Api-Key': api_key,
        'Content-Type': 'application/json'
    }
    url = f"{radarr_url}/{endpoint}"
    
    if method == 'GET':
        response = requests.get(url, headers=headers)
    elif method == 'POST':
        response = requests.post(url, headers=headers, json=data)
    elif method == 'PUT':
        response = requests.put(url, headers=headers, json=data)
    elif method == 'DELETE':
        response = requests.delete(url, headers=headers)
    else:
        raise ValueError("Unsupported method")
    
    response.raise_for_status()
    return response.json()

def get_wanted_movies():
    missing = radarr_api_request("wanted/missing")
    cutoff = radarr_api_request("wanted/cutoff")
    
    # Combine both lists
    return missing.get('records', []) + cutoff.get('records', [])

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
    batch = [movie for movie in movies if str(movie['id']) not in searched_movies]
    
    if batch:
        print(f"Searching for batch of {min(len(batch), batch_size)} movies:")
        counter = 0
        for movie in batch:
            if counter >= batch_size:
                break
            movie_id = movie['id']
            print(f"  - Searching for {movie['title']} (ID: {movie_id})")
            try:
                search_result = search_movie(movie_id)
                print(f"    Search initiated for movie ID {movie_id}: {search_result}")
                save_searched_movie(str(movie_id))
            except requests.exceptions.HTTPError as e:
                print(f"    Error searching for movie ID {movie_id}: {e}")
            counter += 1
        
        print("\nBatch search completed.")
    else:
        print("No new movies to search. All movies have been searched.")

if __name__ == "__main__":
    all_movies = get_wanted_movies()
    process_one_batch(all_movies)
