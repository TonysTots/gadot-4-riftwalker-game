extends Node

# Signals to tell the Login Menu what happened
signal login_success(user_data: Dictionary)
signal login_failed(error_message: String)

# Placeholder URL (Update this when your teammate gives you the real one!)
const API_URL = "https://example.com/api" 
const API_KEY = "optional_key_if_using_supabase" 

# Create the HTTP node strictly for code use
@onready var http_request: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# The function your Login Button calls
func login(email, password) -> void:
	http_request.cancel_request()
	
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	var headers = ["Content-Type: application/json"]
	
	# Send request (POST is standard for logins)
	# Note the "/login" added to the API_URL
	var error = http_request.request(API_URL + "/login", headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		login_failed.emit("Connection Error: Could not send request.")

# --- NEW FUNCTION: Upload Stats ---
func upload_run_data(round_reached: int, total_coins: int, character_name: String) -> void:
	if Global.access_token == "" or Global.user_id == "":
		print("Cannot upload score: Not logged in.")
		return

	# 1. Prepare the JSON body exactly as the C# class expects it
	var data = {
		"user_id": Global.user_id,
		"highest_round": round_reached,
		"total_coins": total_coins,
		"character_class": character_name
	}
	
	var body = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	
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
			
			login_success.emit(response_dict)
		else:
			login_success.emit({}) 
	else:
		login_failed.emit("Login Failed. Code: " + str(response_code))
