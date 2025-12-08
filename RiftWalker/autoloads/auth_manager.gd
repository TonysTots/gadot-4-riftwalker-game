extends Node

# Signals to tell the Login Menu what happened
signal login_success(user_data: Dictionary)
signal login_failed(error_message: String)
signal leaderboard_received(data: Array) # --- NEW ---

# Placeholder URL (Update this when your teammate gives you the real one!)
const API_URL = "http://localhost:5296/api" 
const API_KEY = "optional_key_if_using_supabase" 

# Create the HTTP node strictly for code use
@onready var http_request: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# The function your Login Button calls
func login(username) -> void:
	http_request.cancel_request()
	
	print("Logging in with: ", username, " DeviceID: ", Global.device_id)
	
	var body = JSON.stringify({
		"Username": username, 
		"DeviceId": Global.device_id
	})
	
	var headers = ["Content-Type: application/json"]
	
	# Send request (POST is standard for logins)
	# Note the "/login" added to the API_URL
	var error = http_request.request(API_URL + "/login", headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		login_failed.emit("Connection Error: Could not send request.")

const SECRET_SALT = "RIFTWALKER_SECRET_SALT_2025"

# --- NEW FUNCTION: Upload Stats ---
func upload_run_data(round_reached: int, total_coins: int, character_name: String) -> void:
	if Global.access_token == "" or Global.user_id == "":
		print("Cannot upload score: Not logged in.")
		return
		
	# --- ANTI-CHEAT: Calculate Hash ---
	# We upload (round_reached - 1) because the leaderboard should show "Highest *Completed* Round".
	# If we are on Round 10 (reached), we have completed 9.
	# If we just beat Round 9, we are on 10. The user wants to see "9".
	var completed_round = max(0, round_reached - 1)
	
	# String: SALT + round + coins
	var raw_string = SECRET_SALT + str(completed_round) + str(total_coins)
	var hashed_string = raw_string.sha256_text() # Godot built-in SHA256 helper
	
	# 1. Prepare the JSON body exactly as the C# class expects it
	var data = {
		"user_id": Global.user_id,
		"highest_round": completed_round,
		"total_coins": total_coins,
		"character_class": character_name
	}
	
	var body = JSON.stringify(data)
	var headers = [
		"Content-Type: application/json",
		"X-Integrity-Hash: " + hashed_string
	]
	
	# 2. Send POST request
	# We create a temporary request node to avoid conflict with login requests
	var upload_req = HTTPRequest.new()
	add_child(upload_req)
	upload_req.request_completed.connect(func(_result, _code, _headers, _body): upload_req.queue_free())
	
	upload_req.request(API_URL + "/upload-run", headers, HTTPClient.METHOD_POST, body)

# The function that runs when the website replies
func _on_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var response_text = body.get_string_from_utf8()
		var response_dict = JSON.parse_string(response_text)
		
		if response_dict:
			# Store the token globally
			if response_dict.has("access_token"):
				Global.access_token = response_dict["access_token"]
			
			# --- NEW: Store the User ID globally ---
			if response_dict.has("user_id"):
				Global.user_id = str(response_dict["user_id"])
				# --- NEW: Trigger Cloud Sync ---
				download_save(Global.SAVE_PATH)
			
			if response_dict.has("username"):
				Global.current_username = response_dict["username"]
				Global.save_game()
			
			login_success.emit(response_dict)
		else:
			login_success.emit({}) 
	else:
		login_failed.emit("Login Failed. Code: " + str(response_code))

# --- NEW: Leaderboard Fetch ---
func get_leaderboard() -> void:
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, body):
		if response_code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			leaderboard_received.emit(json)
		else:
			leaderboard_received.emit([])
		req.queue_free()
	)
	
	req.request(API_URL + "/leaderboard")

# --- NEW: Cloud Saves ---
func upload_save(file_path: String) -> void:
	if Global.user_id == "": return # Not logged in
	
	if not FileAccess.file_exists(file_path):
		print("No save file to upload.")
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var file_bytes = file.get_buffer(file.get_length())
	file.close() # Close manually just in case
	
	# Godot 4 multipart upload is tricky. 
	# For simplicity, we will assume we can send raw bytes if the server supported it,
	# BUT our server expects FormFile.
	# Godot HTTPRequest doesn't natively support easy multipart construction.
	# HACK: For this specific project, let's just make the backend accept raw binary body 
	# OR construct a manual multipart body.
	#
	# Actually, constructing manual multipart is verbose.
	# LET'S MODIFY THE SERVER TO ACCEPT RAW BYTES for simplicity if possible?
	# User agreed to "overwrite" logic.
	#
	# Let's try constructing a simple multipart body manually.
	
	var boundary = "GodotUploadBoundary"
	var body = PackedByteArray()
	
	# 1. Add user_id field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n").to_utf8_buffer())
	body.append_array(Global.user_id.to_utf8_buffer())
	body.append_array(("\r\n").to_utf8_buffer())
	
	# 2. Add file field
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"save_file\"; filename=\"savegame.save\"\r\n").to_utf8_buffer())
	body.append_array(("Content-Type: application/octet-stream\r\n\r\n").to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(("\r\n").to_utf8_buffer())
	
	# 3. Validation
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())
	
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, _body):
		if response_code == 200:
			print("Cloud Save Uploaded Successfully!")
		else:
			print("Cloud Save Failed: " + str(response_code))
		req.queue_free()
	)
	
	req.request_raw(API_URL + "/save/upload", headers, HTTPClient.METHOD_POST, body)

func download_save(target_path: String) -> void:
	if Global.user_id == "": return
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, response_code, _headers, body):
		if response_code == 200:
			var file = FileAccess.open(target_path, FileAccess.WRITE)
			file.store_buffer(body)
			file.close() # Ensure flush
			print("Cloud Save Downloaded. Reloading globals...")
			Global.load_game() # Force reload of variables
		else:
			print("No Cloud Save found (or error): " + str(response_code))
		req.queue_free()
	)
	
	req.request(API_URL + "/save/" + Global.user_id)
