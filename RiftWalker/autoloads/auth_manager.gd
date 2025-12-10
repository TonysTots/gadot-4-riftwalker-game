extends Node

# --- SIGNALS ---
## Emitted when login completes successfully, passing the received user data.
signal login_success(user_data: Dictionary)
## Emitted when login fails, passing an error message.
signal login_failed(error_message: String)
## Emitted when leaderboard data is received.
signal leaderboard_received(data: Array)

# --- CONSTANTS ---
## Development API URL (Localhost).
const DEV_API_URL: String = "http://localhost:5296/api"
## Production API URL (Placeholder).
const PROD_API_URL: String = "https://riftwalker-api.example.com/api" 
## Active API URL. Change this to PROD_API_URL for release.
const API_URL: String = DEV_API_URL

## Secret salt for hashing integrity checks.
## WARNING: In a real production game, never store secrets in client-side code like this.
const SECRET_SALT: String = "RIFTWALKER_SECRET_SALT_2025"

# --- NODES ---
## HTTPRequest node used for login and general API calls.
@onready var http_request: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# --- AUTHENTICATION ---

## Initiates a login request using Username and DeviceID.
func login(username: String) -> void:
	http_request.cancel_request()
	
	print("[AuthManager] Logging in: %s (Device: %s)" % [username, Global.device_id])
	
	var body: String = JSON.stringify({
		"Username": username, 
		"DeviceId": Global.device_id
	})
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var error: Error = http_request.request(API_URL + "/login", headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		login_failed.emit("Connection Error: Could not send request (Error %s)" % error)

## Handles the endpoint response for Login actions.
func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	if response_code == 200:
		var response_text: String = body_bytes.get_string_from_utf8()
		var response_dict = JSON.parse_string(response_text)
		
		# Validate response structure
		if response_dict is Dictionary:
			# Cache critical session data
			if response_dict.has("access_token"):
				Global.access_token = str(response_dict["access_token"])
			
			if response_dict.has("user_id"):
				Global.user_id = str(response_dict["user_id"])
				# Auto-Sync: Download latest save from cloud
				download_save(Global.SAVE_PATH)
			
			if response_dict.has("username"):
				Global.current_username = str(response_dict["username"])
				Global.save_game()
			
			login_success.emit(response_dict)
		else:
			login_success.emit({}) 
	else:
		login_failed.emit("Login Failed. HTTP Code: %d" % response_code)

# --- ANTI-CHEAT & LEADERBOARDS ---

## Uploads run results to the server with integrity hashing.
## [round_reached]: The highest round *actively reached* (so if on Round 10, calculate for 9 completed).
func upload_run_data(round_reached: int, total_coins: int, character_name: String) -> void:
	if Global.access_token == "" or Global.user_id == "":
		print("[AuthManager] Cannot upload score: Not logged in.")
		return
		
	# Submit 'completed' rounds (Current - 1)
	var completed_round: int = max(0, round_reached - 1)
	
	# Integrity Check: SALT + Round + Coins
	var raw_string: String = SECRET_SALT + str(completed_round) + str(total_coins)
	var hashed_string: String = raw_string.sha256_text() 
	
	var data: Dictionary = {
		"user_id": Global.user_id,
		"highest_round": completed_round,
		"total_coins": total_coins,
		"character_class": character_name
	}
	
	var body: String = JSON.stringify(data)
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"X-Integrity-Hash: " + hashed_string
	]
	
	# Use ephemeral request to avoid blocking login flow
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_res, _code, _head, _body_bytes): req.queue_free())
	
	req.request(API_URL + "/upload-run", headers, HTTPClient.METHOD_POST, body)

## Fetches the current global leaderboard.
func get_leaderboard() -> void:
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_res, response_code, _head, body_bytes):
		if response_code == 200:
			var json = JSON.parse_string(body_bytes.get_string_from_utf8())
			if json is Array:
				leaderboard_received.emit(json)
			else:
				leaderboard_received.emit([])
		else:
			leaderboard_received.emit([])
		req.queue_free()
	)
	
	req.request(API_URL + "/leaderboard")

# --- CLOUD SAVES ---

## Uploads the local save file to the cloud.
## Uses multipart/form-data simulation.
func upload_save(file_path: String) -> void:
	if Global.user_id == "": return 
	
	if not FileAccess.file_exists(file_path):
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var file_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close() 
	
	# Multipart Body Construction
	var boundary: String = "GodotUploadBoundary"
	var body: PackedByteArray = PackedByteArray()
	
	# 1. User ID Field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n").to_utf8_buffer())
	body.append_array(Global.user_id.to_utf8_buffer())
	body.append_array(("\r\n").to_utf8_buffer())
	
	# 2. File Field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"save_file\"; filename=\"savegame.save\"\r\n").to_utf8_buffer())
	body.append_array(("Content-Type: application/octet-stream\r\n\r\n").to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(("\r\n").to_utf8_buffer())
	
	# 3. Footer
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
	
	var headers: PackedStringArray = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_res, code, _head, _body_bytes):
		if code == 200:
			print("[AuthManager] Cloud Save Uploaded.")
		else:
			print("[AuthManager] Cloud Upload Failed: %d" % code)
		req.queue_free()
	)
	
	req.request_raw(API_URL + "/save/upload", headers, HTTPClient.METHOD_POST, body)

## Downloads the save file from the cloud and overwrites the local copy.
func download_save(target_path: String) -> void:
	if Global.user_id == "": return
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_res, response_code, _head, body_bytes):
		if response_code == 200:
			var file = FileAccess.open(target_path, FileAccess.WRITE)
			file.store_buffer(body_bytes)
			file.close()
			
			print("[AuthManager] Cloud Save Downloaded. Reloading globals...")
			Global.load_game() 
		else:
			print("[AuthManager] No Cloud Save found (Code %d)." % response_code)
		req.queue_free()
	)
	
	req.request(API_URL + "/save/" + Global.user_id)
