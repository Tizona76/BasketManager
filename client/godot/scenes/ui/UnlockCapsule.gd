extends Control

signal unlock_paid(amount_spent: int)

const SaveRef = preload("res://scripts/Save.gd")
const PL = preload("res://scripts/PlayerLife.gd")

@onready var BtnUnlock: Button = get_node_or_null("BtnUnlock") as Button
@onready var LblAmount: Label = get_node_or_null("LblAmount") as Label
@onready var ImgToken: TextureRect = get_node_or_null("ImgToken") as TextureRect

@export var amount: int = 10

func _ready() -> void:
	if BtnUnlock != null:
		BtnUnlock.text = "Unlock"
		BtnUnlock.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		BtnUnlock.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		BtnUnlock.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

		var sb_normal := StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.95, 0.52, 0.12, 1)
		sb_normal.corner_radius_top_left = 18
		sb_normal.corner_radius_top_right = 18
		sb_normal.corner_radius_bottom_right = 18
		sb_normal.corner_radius_bottom_left = 18
		sb_normal.content_margin_left = 6
		sb_normal.content_margin_right = -6

		var sb_hover := StyleBoxFlat.new()
		sb_hover.bg_color = Color(1.0, 0.60, 0.18, 1)
		sb_hover.corner_radius_top_left = 18
		sb_hover.corner_radius_top_right = 18
		sb_hover.corner_radius_bottom_right = 18
		sb_hover.corner_radius_bottom_left = 18
		sb_hover.content_margin_left = 8
		sb_hover.content_margin_right = -6

		var sb_pressed := StyleBoxFlat.new()
		sb_pressed.bg_color = Color(0.85, 0.42, 0.08, 1)
		sb_pressed.corner_radius_top_left = 18
		sb_pressed.corner_radius_top_right = 18
		sb_pressed.corner_radius_bottom_right = 18
		sb_pressed.corner_radius_bottom_left = 18
		sb_pressed.content_margin_left = 6
		sb_pressed.content_margin_right = -6

		BtnUnlock.add_theme_stylebox_override("normal", sb_normal)
		BtnUnlock.add_theme_stylebox_override("hover", sb_hover)
		BtnUnlock.add_theme_stylebox_override("pressed", sb_pressed)
		if not BtnUnlock.pressed.is_connected(_on_btn_unlock_pressed):
			BtnUnlock.pressed.connect(_on_btn_unlock_pressed)

	if LblAmount != null:
		LblAmount.text = str(amount)

func set_amount(v: int) -> void:
	amount = maxi(0, int(v))
	if LblAmount != null:
		LblAmount.text = str(amount)


func _on_btn_unlock_pressed() -> void:
	var spend_amount: int = maxi(0, int(amount))
	if spend_amount <= 0:
		return

	var d: Dictionary = SaveRef.read_dict()
	if d.is_empty():
		return

	if not PL.can_spend_tokens(d, spend_amount):
		return

	emit_signal("unlock_paid", spend_amount)


func _refresh_tokens_hud_from_save(d: Dictionary) -> void:
	var tokens_ui: int = PL.get_tokens(d)
	var root: Node = get_tree().current_scene
	if root == null:
		root = self

	for n in root.find_children("LblHudTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = "Tokens " + str(tokens_ui)

	for n in root.find_children("LblTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = str(tokens_ui)
