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

# --- STATE ---
var selected_item_to_buy: Item
var msg_timer_id: int = 0

const BORDER_TEXTURE_PATH: String = "res://assets/sprites/Border EB.png"
const MAP_SCENE_PATH: String = "res://UI/map_screen.tscn"
const TITLE_SCENE_PATH: String = "res://UI/title_screen.tscn"

func _ready() -> void:
	ScreenFade.fade_into_game() 
	
	_setup_ui()
	_populate_shop()
	
	Audio.store_bell.play()

func _setup_ui() -> void:
	close_button.pressed.connect(_on_close_pressed)
	cancel_button.pressed.connect(_on_cancel_popup_pressed)
	
	setup_button_sounds(close_button)
	setup_button_sounds(cancel_button)
	
	update_ui()

func update_ui() -> void:
	coin_label.text = "Coins: " + str(Global.coins)

func _populate_shop() -> void:
	for child in shop_grid.get_children():
		child.queue_free()
	
	for item in items_for_sale:
		create_item_listing(item)

func create_item_listing(item: Item) -> void:
	# 1. Create the Box with Border
	var item_box: PanelContainer = PanelContainer.new()
	var style: StyleBoxTexture = _create_border_style()
	item_box.add_theme_stylebox_override("panel", style)
	
	shop_grid.add_child(item_box)
	
	# 2. Add Margins
	var margins: MarginContainer = MarginContainer.new()
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_left", 10)
	margins.add_theme_constant_override("margin_bottom", 10)
	margins.add_theme_constant_override("margin_right", 10)
	item_box.add_child(margins)
	
	# 3. Create Inner Layout
	var vbox: VBoxContainer = VBoxContainer.new()
	margins.add_child(vbox)
	
	# Icon
	if item.icon:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = item.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64) 
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)
	
	# Name
	var name_lbl: Label = Label.new()
	name_lbl.text = item.actionName
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	# Price
	var price_lbl: Label = Label.new()
	price_lbl.text = str(item.price) + " G"
	price_lbl.modulate = Color.YELLOW
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_lbl)
	
	# Select Button
	var select_btn: Button = Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(_on_item_selected.bind(item))
	setup_button_sounds(select_btn)
	vbox.add_child(select_btn)

func _create_border_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(BORDER_TEXTURE_PATH)
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	style.expand_margin_left = 5
	style.expand_margin_top = 5
	style.expand_margin_right = 5
	style.expand_margin_bottom = 5
	return style

# --- POPUP LOGIC ---

func _on_item_selected(item: Item) -> void:
	Audio.btn_pressed.play()
	selected_item_to_buy = item
	
	popup_title.text = "Buy " + item.actionName + " for whom?"
	popup_title.modulate = Color.WHITE
	
	# Refresh Buttons
	for child in char_buttons_container.get_children():
		child.queue_free()
	
	for buyer in buyers:
		var btn: Button = Button.new()
		btn.text = buyer.name
		btn.pressed.connect(_on_confirm_buy.bind(buyer))
		setup_button_sounds(btn)
		char_buttons_container.add_child(btn)
	
	buy_popup.show()
	if char_buttons_container.get_child_count() > 0:
		(char_buttons_container.get_child(0) as Button).grab_focus()

func _on_confirm_buy(buyer: AllyStats) -> void:
	if selected_item_to_buy == null: return
	
	if Global.coins >= selected_item_to_buy.price:
		_process_transaction(buyer)
	else:
		_show_insufficient_funds()

func _process_transaction(buyer: AllyStats) -> void:
	Global.coins -= selected_item_to_buy.price
	buyer.items.append(selected_item_to_buy)
	
	Audio.btn_pressed.play() 
	Audio.purchase.play()
	
	Global.save_game()
	update_ui()
	
	buy_popup.hide()

func _show_insufficient_funds() -> void:
	msg_timer_id += 1
	var my_id: int = msg_timer_id
	
	Audio.denied.play()
	buy_popup.hide()
	
	coin_label.hide()
	insufficient_funds.show()
	
	await get_tree().create_timer(2.0).timeout
	
	if my_id == msg_timer_id:
		insufficient_funds.hide()
		coin_label.show()

func _on_cancel_popup_pressed() -> void:
	Audio.btn_pressed.play()
	buy_popup.hide()

func _on_close_pressed() -> void:
	Audio.btn_pressed.play()
	Audio.store_bell.play()
	
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	
	if Global.map_data != null:
		get_tree().change_scene_to_file(MAP_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)

func setup_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: Audio.btn_mov.play())
	button.focus_entered.connect(func() -> void: Audio.btn_mov.play())
