extends CanvasLayer

# --- DATA ---
@export var items_for_sale: Array[Item] 
@export var buyers: Array[AllyStats]

# --- MAIN NODES ---
@onready var coin_label: Label = %Coins
@onready var shop_grid: GridContainer = %ShopGrid
@onready var close_button: Button = %Close
@onready var insufficient_funds: Label = %InsufficientFunds

# --- POPUP NODES ---
@onready var buy_popup: PanelContainer = $BuyPopup
@onready var popup_title: Label = $BuyPopup/VBoxContainer/TitleLabel
@onready var char_buttons_container: VBoxContainer = $BuyPopup/VBoxContainer/CharacterButtons
@onready var cancel_button: Button = $BuyPopup/VBoxContainer/CancelButton

# State to remember what we are trying to buy
var selected_item_to_buy: Item

# Tracks which "Insufficient Funds" timer is currently active
var msg_timer_id: int = 0

func _ready() -> void:
	ScreenFade.fade_into_game() # 1. Fade In
	update_ui()
	Audio.store_bell.play()
	
	# Clear placeholders
	for child in shop_grid.get_children():
		child.queue_free()
	
	# Generate the shop shelf
	for item in items_for_sale:
		create_item_listing(item)
		
	close_button.pressed.connect(_on_close_pressed)
	cancel_button.pressed.connect(_on_cancel_popup_pressed)
	setup_button_sounds(close_button)
	setup_button_sounds(cancel_button)

func update_ui() -> void:
	coin_label.text = "Coins: " + str(Global.coins)

# --- 3. LAYOUT REDESIGN: Main Shelf ---
func create_item_listing(item: Item) -> void:
	# 1. Create the Box
	var item_box = PanelContainer.new()
	
	# --- NEW: CUSTOM BORDER STYLE ---
	var style = StyleBoxTexture.new()
	# Make sure this path matches exactly where your file is!
	style.texture = load("res://assets/sprites/Border EB.png")
	
	# 5px Texture Margins (This protects the corners from stretching)
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	
	# 5px Expand Margins (This makes the border draw 10px outside the box bounds)
	style.expand_margin_left = 5
	style.expand_margin_top = 5
	style.expand_margin_right = 5
	style.expand_margin_bottom = 5
	
	# Apply the style to this specific panel
	item_box.add_theme_stylebox_override("panel", style)
	# --------------------------------
	
	shop_grid.add_child(item_box)
	
	# 2. Add Margins (To keep text away from the border edges)
	var margins = MarginContainer.new()
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_left", 10)
	margins.add_theme_constant_override("margin_bottom", 10)
	margins.add_theme_constant_override("margin_right", 10)
	item_box.add_child(margins)
	
	# 3. Create the Layout inside the Margins
	var vbox = VBoxContainer.new()
	margins.add_child(vbox)
	
	# --- ICON DISPLAY ---
	if item.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = item.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64) 
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.actionName
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	# Price
	var price_lbl = Label.new()
	price_lbl.text = str(item.price) + " G"
	price_lbl.modulate = Color.YELLOW
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_lbl)
	
	# Select Button
	var select_btn = Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(_on_item_selected.bind(item))
	setup_button_sounds(select_btn)
	vbox.add_child(select_btn)

# --- POPUP LOGIC ---
func _on_item_selected(item: Item) -> void:
	Audio.btn_pressed.play()
	selected_item_to_buy = item
	
	# 1. Update Popup Text & Reset Color
	popup_title.text = "Buy " + item.actionName + " for whom?"
	popup_title.modulate = Color.WHITE # --- NEW: Reset color on open ---
	
	# 2. Clear old buttons from previous opens
	for child in char_buttons_container.get_children():
		child.queue_free()
	
	# 3. Generate NEW buttons for each character
	for buyer in buyers:
		var btn = Button.new()
		btn.text = buyer.name
		btn.pressed.connect(_on_confirm_buy.bind(buyer))
		setup_button_sounds(btn)
		char_buttons_container.add_child(btn)
	
	# 4. Show Popup
	buy_popup.show()
	if char_buttons_container.get_child_count() > 0:
		char_buttons_container.get_child(0).grab_focus()

func _on_confirm_buy(buyer: AllyStats) -> void:
	if selected_item_to_buy == null: return
	
	if Global.coins >= selected_item_to_buy.price:
		# Transaction
		Global.coins -= selected_item_to_buy.price
		buyer.items.append(selected_item_to_buy)
		
		# Feedback
		Audio.btn_pressed.play() 
		Audio.purchase.play()
		Global.save_game()
		update_ui()
		
		print("Bought item for " + buyer.name)
		buy_popup.hide()
	else:
		# 1. Increment the ID. This effectively "invalidates" any previous timers running.
		msg_timer_id += 1
		var my_id = msg_timer_id
		
		Audio.denied.play() # Assuming you have this sound
		buy_popup.hide()
		
		# 2. Show the warning
		coin_label.hide()
		insufficient_funds.show()
		
		# 3. Wait for 2 seconds
		await get_tree().create_timer(2.0).timeout
		
		# 4. Check: Are we still the latest timer?
		if my_id == msg_timer_id:
			insufficient_funds.hide()
			coin_label.show()

func _on_cancel_popup_pressed() -> void:
	Audio.btn_pressed.play()
	buy_popup.hide()

func _on_close_pressed() -> void:
	Audio.btn_pressed.play()
	Audio.store_bell.play()
	# 1. Fade Out
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://UI/title_screen.tscn")

# --- 2. AUDIO HELPER ---
func setup_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
	button.focus_entered.connect(func(): Audio.btn_mov.play())
