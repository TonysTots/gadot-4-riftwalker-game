extends Node

# Signals to tell the Login Menu what happened
signal login_success(user_data: Dictionary)
signal login_failed(error_message: String)

# Placeholder URL (You will change this later when you pick Supabase/Python)
const API_URL = "https://example.com/api/login"
const API_KEY = "optional_key_if_using_supabase" 

# Create the HTTP node strictly for code use
@onready var http_request: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# The function your Login Button calls
func login(email, password) -> void:
	# 1. Cancel any existing request
	http_request.cancel_request()
	
	# 2. Prepare data
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	var headers = ["Content-Type: application/json"]
	
	# 3. Send request (POST is standard for logins)
	var error = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		login_failed.emit("Connection Error: Could not send request.")

# The function that runs when the website replies
func _on_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var response_text = body.get_string_from_utf8()
		var response_dict = JSON.parse_string(response_text)
		
		# Store the token globally so you can use it for scores later
		if response_dict and response_dict.has("access_token"):
			Global.access_token = response_dict["access_token"]
			login_success.emit(response_dict)
		else:
			# Fallback if the server sends 200 but weird data
			login_success.emit({}) 
	else:
		login_failed.emit("Login Failed. Code: " + str(response_code))
