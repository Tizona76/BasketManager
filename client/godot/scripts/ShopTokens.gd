extends Control

const PlayerLife = preload("res://scripts/PlayerLife.gd")

@onready var BtnBack: Button = get_node_or_null("UI/BtnBack") as Button
@onready var Pkg1: Button = get_node_or_null("UI/Packages/Pkg100") as Button
@onready var Pkg2: Button = get_node_or_null("UI/Packages/Pkg300") as Button
@onready var Pkg3: Button = get_node_or_null("UI/Packages/Pkg800") as Button
@onready var LblStatus: Label = get_node_or_null("UI/LblStatus") as Label
@onready var PopupConfirm: Panel = get_node_or_null("UI/PopupConfirm") as Panel
@onready var LblConfirm: Label = get_node_or_null("UI/PopupConfirm/LblConfirm") as Label
@onready var BtnConfirm: Button = get_node_or_null("UI/PopupConfirm/BtnConfirm") as Button
@onready var BtnCancel: Button = get_node_or_null("UI/PopupConfirm/BtnCancel") as Button

var _pending_tokens_amount: int = 0

func _ready() -> void:
	if BtnBack != null and not BtnBack.pressed.is_connected(_on_back):
		BtnBack.pressed.connect(_on_back)

	if BtnConfirm != null and not BtnConfirm.pressed.is_connected(_on_confirm_purchase):
		BtnConfirm.pressed.connect(_on_confirm_purchase)
	if BtnCancel != null and not BtnCancel.pressed.is_connected(_on_cancel_purchase):
		BtnCancel.pressed.connect(_on_cancel_purchase)
	if PopupConfirm != null:
		PopupConfirm.visible = false

	if Pkg1 != null and not Pkg1.pressed.is_connected(_on_pkg_100):
		Pkg1.pressed.connect(_on_pkg_100)
	if Pkg2 != null and not Pkg2.pressed.is_connected(_on_pkg_300):
		Pkg2.pressed.connect(_on_pkg_300)
	if Pkg3 != null and not Pkg3.pressed.is_connected(_on_pkg_800):
		Pkg3.pressed.connect(_on_pkg_800)

func _on_back() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://scenes/Menu.tscn")

func _set_status(txt: String) -> void:
	if LblStatus != null:
		LblStatus.text = txt
	print("[SHOP][DEBUG] ", txt)

func _on_pkg_100() -> void:
	_pending_tokens_amount = 100
	if LblConfirm != null:
		LblConfirm.text = "Confirm %d Tokens ?" % _pending_tokens_amount
	if PopupConfirm != null:
		PopupConfirm.visible = true
	_set_status("DEBUG confirm popup opened: +100 tokens")

func _on_pkg_300() -> void:
	_pending_tokens_amount = 300
	if LblConfirm != null:
		LblConfirm.text = "Confirm %d Tokens ?" % _pending_tokens_amount
	if PopupConfirm != null:
		PopupConfirm.visible = true
	_set_status("DEBUG confirm popup opened: +300 tokens")

func _on_confirm_purchase() -> void:
	if _pending_tokens_amount <= 0:
		_set_status("DEBUG no pending package")
		if PopupConfirm != null:
			PopupConfirm.visible = false
		return
	var save: Dictionary = PlayerLife.load_savegame()
	PlayerLife.add_tokens(save, _pending_tokens_amount, "shop_debug_pkg_%d" % _pending_tokens_amount)
	PlayerLife.write_savegame(save)
	_set_status("DEBUG package applied: +%d tokens" % _pending_tokens_amount)
	_pending_tokens_amount = 0
	if PopupConfirm != null:
		PopupConfirm.visible = false

func _on_cancel_purchase() -> void:
	_pending_tokens_amount = 0
	if PopupConfirm != null:
		PopupConfirm.visible = false
	_set_status("DEBUG purchase cancelled")

func _on_pkg_800() -> void:
	_pending_tokens_amount = 800
	if LblConfirm != null:
		LblConfirm.text = "Confirm %d Tokens ?" % _pending_tokens_amount
	if PopupConfirm != null:
		PopupConfirm.visible = true
	_set_status("DEBUG confirm popup opened: +800 tokens")
