extends Control

const PlayerLife = preload("res://scripts/PlayerLife.gd")
const StadiumDataRef = preload("res://scripts/StadiumData.gd")
const BM_DEBUG_ENABLE_TOKEN_PACK_GRANTS := false
const BM_SHOW_TOKEN_HISTORY_BUTTON := true
const BM_SKIP_FINAL_RESULT_TOKEN_COST_DISPLAY := 1
const BM_AUTO_SAVE_LINEUP_TOKEN_COST_DISPLAY := 8
const HOME_ARENA_COST := 15
const TOKEN_ICON_PATH := "res://assets/images/token.png"
const API_BASE := "https://api.basketmanager-game.com"
const CHECKOUT_SESSION_PATH := "/v1/payments/create_checkout_session"
const AUTH_REFRESH_PATH := "/v1/auth/refresh"
const CLOUD_LOAD_PATH := "/v1/cloud/load"
const TOKEN_STORE_PACK_IDS := {
	25: "starter",
	75: "club",
	150: "manager"
}
const TOKEN_STORE_PACKS := {
	25: {"name_key": "club_tokens.store.starter_pack", "fallback_name": "STARTER PACK", "price": "0.99 €"},
	75: {"name_key": "club_tokens.store.club_pack", "fallback_name": "CLUB PACK", "price": "2.99 €"},
	150: {"name_key": "club_tokens.store.manager_pack", "fallback_name": "MANAGER PACK", "price": "4.99 €"}
}
const OPEN_PAYMENT_BUTTON_WIDTH := 440.0
const PAYMENT_READY_POPUP_WIDTH := 900.0
const PURCHASE_CONFIRM_POPUP_WIDTH := 720.0
const PURCHASE_CONFIRM_BUTTON_WIDTH := 430.0
const PURCHASE_CONFIRM_CONTENT_WIDTH := 404.0
const TOKEN_PROGRESS_MESSAGES := [
	{"minimum_tokens": 250, "message_key": "club_tokens.progress.250"},
	{"minimum_tokens": 100, "message_key": "club_tokens.progress.100"},
	{"minimum_tokens": 50, "message_key": "club_tokens.progress.50"},
	{"minimum_tokens": 25, "message_key": "club_tokens.progress.25"},
	{"minimum_tokens": 10, "message_key": "club_tokens.progress.10"},
	{"minimum_tokens": 8, "message_key": "club_tokens.progress.8"},
	{"minimum_tokens": 1, "message_key": "club_tokens.progress.1"},
	{"minimum_tokens": 0, "message_key": "club_tokens.progress.0"}
]

@onready var Title: Label = get_node_or_null("UI/Title") as Label
@onready var BtnBack: Button = get_node_or_null("UI/BtnBack") as Button
@onready var Pkg1: Button = get_node_or_null("UI/Packages/Pkg100") as Button
@onready var Pkg2: Button = get_node_or_null("UI/Packages/Pkg300") as Button
@onready var Pkg3: Button = get_node_or_null("UI/Packages/Pkg800") as Button
@onready var Packages: Control = get_node_or_null("UI/Packages") as Control
@onready var LblStatus: Label = get_node_or_null("UI/LblStatus") as Label
@onready var PopupConfirm: Panel = get_node_or_null("UI/PopupConfirm") as Panel
@onready var LblConfirm: Label = get_node_or_null("UI/PopupConfirm/LblConfirm") as Label
@onready var BtnConfirm: Button = get_node_or_null("UI/PopupConfirm/BtnConfirm") as Button
@onready var BtnCancel: Button = get_node_or_null("UI/PopupConfirm/BtnCancel") as Button

var _pending_tokens_amount: int = 0
var _pending_checkout_url: String = ""
var _pending_checkout_career_id: String = ""
var _checkout_session_request_in_flight: bool = false
var _checkout_auth_retry_done: bool = false
var _checkout_auth_request_in_flight: bool = false
var _payment_refresh_request_in_flight: bool = false
var _payment_waiting_for_refresh: bool = false
var _tokens_before_payment: int = 0
var _expected_payment_tokens: int = 0
var _return_refresh_done: bool = false
var _payment_confirmation_shown: bool = false
var _btn_buy_club_tokens: Button = null
var _is_token_purchase_screen: bool = false
var _club_identity_preview_badge_id: String = ""
var _club_tokens_active_section: String = "overview"
var _club_tokens_cards_scroll: ScrollContainer = null
var _home_arena_show_congratulations: bool = false

func _active_career_id() -> String:
	if ProfileManager == null or not ProfileManager.has_method("get_active_career_id"):
		return ""
	return str(ProfileManager.get_active_career_id()).strip_edges()


func _payment_response_matches_pending_career(data: Dictionary) -> bool:
	var expected := str(_pending_checkout_career_id).strip_edges()
	var current := _active_career_id()
	var returned := str(data.get("career_id", "")).strip_edges()
	if expected == "" or current != expected:
		print("[STRIPE_UX][CAREER_GUARD] ignored refresh expected=", expected, " current=", current)
		return false
	if returned != "" and returned != expected:
		print("[STRIPE_UX][CAREER_GUARD] ignored refresh expected=", expected, " returned=", returned)
		return false
	return true

func _bm_play_club_tokens_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("play_music"):
		am.call("play_music", "res://audio/music/club-tokens.mp3", true, false)

func _ready() -> void:
	_bm_play_club_tokens_music()
	if BtnBack != null and not BtnBack.pressed.is_connected(_on_back):
		BtnBack.pressed.connect(_on_back)
		BtnBack.text = tr("menu.back")
		BtnBack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		BtnBack.offset_left = 30.0
		BtnBack.offset_top = -86.0
		BtnBack.offset_right = 230.0
		BtnBack.offset_bottom = -26.0
		BtnBack.add_theme_font_size_override("font_size", 24)
		BtnBack.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		var back_style := StyleBoxFlat.new()
		back_style.bg_color = Color(0.82, 0.08, 0.12, 1.0)
		back_style.border_color = Color(1.0, 0.18, 0.20, 1.0)
		back_style.border_width_left = 2
		back_style.border_width_top = 2
		back_style.border_width_right = 2
		back_style.border_width_bottom = 4
		back_style.corner_radius_top_left = 10
		back_style.corner_radius_top_right = 10
		back_style.corner_radius_bottom_left = 10
		back_style.corner_radius_bottom_right = 10
		var back_hover := back_style.duplicate() as StyleBoxFlat
		back_hover.bg_color = Color(0.92, 0.10, 0.15, 1.0)
		var back_pressed := back_style.duplicate() as StyleBoxFlat
		back_pressed.bg_color = Color(0.62, 0.04, 0.08, 1.0)
		BtnBack.add_theme_stylebox_override("normal", back_style)
		BtnBack.add_theme_stylebox_override("hover", back_hover)
		BtnBack.add_theme_stylebox_override("pressed", back_pressed)

	if Title != null:
		Title.text = tr("club_tokens.title")
		Title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		Title.offset_left = 0.0
		Title.offset_top = 40.0
		Title.offset_right = 0.0
		Title.offset_bottom = 92.0
		Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if LblStatus != null:
		LblStatus.visible = false
	if Packages != null:
		Packages.visible = false
	if PopupConfirm != null:
		PopupConfirm.visible = false
	if BtnConfirm != null:
		BtnConfirm.visible = true
		if not BtnConfirm.pressed.is_connected(_on_confirm_purchase):
			BtnConfirm.pressed.connect(_on_confirm_purchase)
	if BtnCancel != null:
		BtnCancel.visible = true
		if not BtnCancel.pressed.is_connected(_on_cancel_purchase):
			BtnCancel.pressed.connect(_on_cancel_purchase)
	if Pkg1 != null and not Pkg1.pressed.is_connected(_on_pkg_100):
		Pkg1.pressed.connect(_on_pkg_100)
	if Pkg2 != null and not Pkg2.pressed.is_connected(_on_pkg_300):
		Pkg2.pressed.connect(_on_pkg_300)
	if Pkg3 != null and not Pkg3.pressed.is_connected(_on_pkg_800):
		Pkg3.pressed.connect(_on_pkg_800)
	_style_token_purchase_ui()

	_build_club_tokens_info_screen()


func _make_purchase_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _get_token_store_pack(amount: int) -> Dictionary:
	var pack_any: Variant = TOKEN_STORE_PACKS.get(int(amount), {})
	if typeof(pack_any) == TYPE_DICTIONARY:
		return pack_any as Dictionary
	return {}


func _get_token_store_pack_name(amount: int) -> String:
	var pack := _get_token_store_pack(amount)
	var key := str(pack.get("name_key", ""))
	var fallback := str(pack.get("fallback_name", "PACK"))
	return _club_tokens_tr(key, fallback)


func _get_token_store_pack_price(amount: int) -> String:
	return str(_get_token_store_pack(amount).get("price", ""))


func _make_purchase_pack_label(text: String, font_size: int, color: Color, outline: int = 3) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	lbl.add_theme_constant_override("outline_size", outline)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	return lbl


func _clear_purchase_pack_button_content(btn: Button) -> void:
	for child in btn.get_children():
		if child.name == "TokenPackContent" or child.name == "TokenPackTitle":
			child.queue_free()


func _style_token_pack_button(btn: Button, amount: int) -> void:
	if btn == null:
		return
	_clear_purchase_pack_button_content(btn)
	btn.text = ""
	btn.custom_minimum_size = Vector2(240, 86)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.icon = null
	var normal := _make_purchase_button_style(Color(0.05, 0.30, 0.78, 0.96), Color(1.0, 0.72, 0.20, 0.95))
	var hover := _make_purchase_button_style(Color(0.08, 0.45, 1.0, 1.0), Color(1.0, 0.88, 0.32, 1.0))
	var pressed := _make_purchase_button_style(Color(0.03, 0.20, 0.55, 1.0), Color(1.0, 0.62, 0.16, 1.0))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	var title_above := _make_purchase_pack_label(_get_token_store_pack_name(amount), 17, Color(1.0, 0.86, 0.34, 1.0), 3)
	title_above.name = "TokenPackTitle"
	title_above.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_above.position = Vector2(0, -28)
	title_above.size = Vector2(240, 24)
	title_above.custom_minimum_size = Vector2(240, 24)
	title_above.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_child(title_above)

	var box := VBoxContainer.new()
	box.name = "TokenPackContent"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8.0
	box.offset_top = 4.0
	box.offset_right = -8.0
	box.offset_bottom = -4.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	btn.add_child(box)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.custom_minimum_size = Vector2(210, 24)
	top_row.add_theme_constant_override("separation", 6)
	box.add_child(top_row)
	var price_lbl := _make_purchase_pack_label(_get_token_store_pack_price(amount), 21, Color(0.88, 0.96, 1.0, 1.0), 3)
	price_lbl.custom_minimum_size = Vector2(74, 24)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(price_lbl)

	var amount_row := HBoxContainer.new()
	amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.custom_minimum_size = Vector2(210, 34)
	amount_row.add_theme_constant_override("separation", 6)
	box.add_child(amount_row)
	var amount_lbl := _make_purchase_pack_label(str(amount), 32, Color(1.0, 0.92, 0.68, 1.0), 4)
	amount_lbl.custom_minimum_size = Vector2(66, 36)
	amount_row.add_child(amount_lbl)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(31, 31)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TOKEN_ICON_PATH):
		icon.texture = load(TOKEN_ICON_PATH) as Texture2D
	amount_row.add_child(icon)


func _style_purchase_action_button(btn: Button, bg: Color, border: Color) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(150, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var normal := _make_purchase_button_style(bg, border)
	var hover := _make_purchase_button_style(bg.lightened(0.10), border.lightened(0.10))
	var pressed := _make_purchase_button_style(bg.darkened(0.12), border)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_token_purchase_ui() -> void:
	_style_token_pack_button(Pkg1, 25)
	_style_token_pack_button(Pkg2, 75)
	_style_token_pack_button(Pkg3, 150)
	if PopupConfirm != null:
		PopupConfirm.offset_left = 560.0
		PopupConfirm.offset_top = 170.0
		PopupConfirm.offset_right = 1020.0
		PopupConfirm.offset_bottom = 450.0
		var popup_sb := StyleBoxFlat.new()
		popup_sb.bg_color = Color(0.018, 0.026, 0.055, 0.98)
		popup_sb.border_color = Color(1.0, 0.72, 0.20, 0.95)
		popup_sb.border_width_left = 2
		popup_sb.border_width_top = 2
		popup_sb.border_width_right = 2
		popup_sb.border_width_bottom = 2
		popup_sb.corner_radius_top_left = 22
		popup_sb.corner_radius_top_right = 22
		popup_sb.corner_radius_bottom_left = 22
		popup_sb.corner_radius_bottom_right = 22
		PopupConfirm.add_theme_stylebox_override("panel", popup_sb)
	if LblConfirm != null:
		LblConfirm.visible = false
	if BtnConfirm != null:
		BtnConfirm.text = _club_tokens_tr("club_tokens.store.continue", "Continue")
		BtnConfirm.offset_top = 190.0
		BtnConfirm.offset_bottom = 246.0
	if BtnCancel != null:
		BtnCancel.offset_top = 190.0
		BtnCancel.offset_bottom = 246.0
	_style_purchase_action_button(BtnCancel, Color(0.78, 0.10, 0.16, 1.0), Color(1.0, 0.28, 0.34, 1.0))
	_style_purchase_action_button(BtnConfirm, Color(0.06, 0.62, 0.22, 1.0), Color(0.32, 1.0, 0.48, 1.0))


func _restore_purchase_popup_layout() -> void:
	if PopupConfirm == null:
		return
	var viewport_width := get_viewport_rect().size.x
	var popup_width := PURCHASE_CONFIRM_POPUP_WIDTH
	var left := maxf(0.0, (viewport_width - popup_width) * 0.5)
	PopupConfirm.offset_left = left
	PopupConfirm.offset_top = 170.0
	PopupConfirm.offset_right = left + popup_width
	PopupConfirm.offset_bottom = 450.0
	var content := PopupConfirm.get_node_or_null("PurchaseConfirmContent") as Control
	if content != null:
		content.position.x = maxf(28.0, (popup_width - PURCHASE_CONFIRM_CONTENT_WIDTH) * 0.5)


func _set_payment_ready_popup_layout() -> void:
	if PopupConfirm == null:
		return
	var viewport_width := get_viewport_rect().size.x
	var left := maxf(0.0, (viewport_width - PAYMENT_READY_POPUP_WIDTH) * 0.5)
	PopupConfirm.offset_left = left
	PopupConfirm.offset_right = left + PAYMENT_READY_POPUP_WIDTH
	PopupConfirm.offset_top = 170.0
	PopupConfirm.offset_bottom = 450.0
	var content := PopupConfirm.get_node_or_null("PurchaseConfirmContent") as Control
	if content != null:
		content.position.x = maxf(28.0, (PAYMENT_READY_POPUP_WIDTH - PURCHASE_CONFIRM_CONTENT_WIDTH) * 0.5)


func _restore_confirm_button_layout() -> void:
	if BtnConfirm == null or PopupConfirm == null:
		return
	var popup_width := PopupConfirm.offset_right - PopupConfirm.offset_left
	var left := maxf(0.0, (popup_width - PURCHASE_CONFIRM_BUTTON_WIDTH) * 0.5)
	BtnConfirm.custom_minimum_size = Vector2(PURCHASE_CONFIRM_BUTTON_WIDTH, 56)
	BtnConfirm.offset_left = left
	BtnConfirm.offset_right = left + PURCHASE_CONFIRM_BUTTON_WIDTH
	BtnConfirm.offset_top = 190.0
	BtnConfirm.offset_bottom = 246.0


func _center_open_payment_button_on_screen() -> void:
	if BtnConfirm == null or PopupConfirm == null:
		return
	var popup_width := PopupConfirm.offset_right - PopupConfirm.offset_left
	var left := maxf(0.0, (popup_width - OPEN_PAYMENT_BUTTON_WIDTH) * 0.5)
	BtnConfirm.custom_minimum_size = Vector2(OPEN_PAYMENT_BUTTON_WIDTH, 56)
	BtnConfirm.offset_left = left
	BtnConfirm.offset_right = left + OPEN_PAYMENT_BUTTON_WIDTH
	BtnConfirm.offset_top = 190.0
	BtnConfirm.offset_bottom = 246.0


func _clear_purchase_confirm_content() -> void:
	if PopupConfirm == null:
		return
	for child in PopupConfirm.get_children():
		if str(child.name).begins_with("PurchaseConfirmContent"):
			if child is CanvasItem:
				(child as CanvasItem).visible = false
			PopupConfirm.remove_child(child)
			child.queue_free()


func _set_purchase_confirm_content(amount: int) -> void:
	if PopupConfirm == null:
		return
	_clear_purchase_confirm_content()
	var box := VBoxContainer.new()
	box.name = "PurchaseConfirmContent"
	var popup_width := PopupConfirm.offset_right - PopupConfirm.offset_left
	box.position = Vector2(maxf(28.0, (popup_width - PURCHASE_CONFIRM_CONTENT_WIDTH) * 0.5), 28)
	box.size = Vector2(PURCHASE_CONFIRM_CONTENT_WIDTH, 150)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7)
	PopupConfirm.add_child(box)
	var title := _make_info_label(_club_tokens_tr("club_tokens.store.purchase_title", "Purchase Club Tokens"), 24, Color(1.0, 0.90, 0.62, 1.0), 3)
	title.custom_minimum_size = Vector2(404, 30)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(404, 38)
	box.add_child(row)
	var amount_lbl := _make_info_label(str(amount), 32, Color(1.0, 0.82, 0.25, 1.0), 4)
	amount_lbl.custom_minimum_size = Vector2(78, 38)
	amount_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(amount_lbl)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TOKEN_ICON_PATH):
		icon.texture = load(TOKEN_ICON_PATH) as Texture2D
	row.add_child(icon)
	var price_lbl := _make_info_label(_get_token_store_pack_price(amount), 22, Color(0.88, 0.96, 1.0, 1.0), 3)
	price_lbl.custom_minimum_size = Vector2(404, 28)
	box.add_child(price_lbl)
	var note_lbl := _make_info_label(_club_tokens_tr("club_tokens.store.secure_payment", "Continue to secure payment"), 18, Color(0.74, 0.82, 0.92, 0.90), 2)
	note_lbl.custom_minimum_size = Vector2(404, 24)
	box.add_child(note_lbl)


func _set_payment_opened_content() -> void:
	if PopupConfirm == null:
		return
	_clear_purchase_confirm_content()
	var box := VBoxContainer.new()
	box.name = "PurchaseConfirmContent"
	box.position = Vector2(78, 28)
	box.size = Vector2(604, 150)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	PopupConfirm.add_child(box)
	var msg := _make_info_label(_club_tokens_tr("club_tokens.stripe.payment_opened", "Payment page opened\nComplete your payment in the new tab, then return here."), 22, Color(0.90, 0.96, 1.0, 1.0), 3)
	msg.custom_minimum_size = Vector2(604, 118)
	box.add_child(msg)


func _set_payment_confirmed_content(tokens_added: int, new_balance: int) -> void:
	if PopupConfirm == null:
		return
	_clear_purchase_confirm_content()
	if BtnCancel != null:
		BtnCancel.visible = false
	var box := VBoxContainer.new()
	box.name = "PurchaseConfirmContent"
	box.position = Vector2(78, 28)
	box.size = Vector2(604, 150)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	PopupConfirm.add_child(box)
	var added_line := str(tokens_added) + " Club Tokens have been added to your wallet."
	var balance_line := "New balance: " + str(new_balance) + " Club Tokens"
	var txt := "🎉 Congratulations!\n" + added_line + "\n" + balance_line
	var msg := _make_info_label(txt, 24, Color(0.80, 1.0, 0.82, 1.0), 3)
	msg.custom_minimum_size = Vector2(604, 118)
	box.add_child(msg)


func _get_current_token_balance() -> int:
	var save: Dictionary = PlayerLife.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return 0
	return PlayerLife.get_tokens(save)


func _format_buy_payment_button_text(amount: int) -> String:
	return "Confirm " + str(amount) + " Tokens"


func _set_refresh_payment_button() -> void:
	_set_payment_ready_popup_layout()
	if BtnConfirm != null:
		BtnConfirm.text = _club_tokens_tr("club_tokens.stripe.check_refresh", "Check payment and refresh tokens")
		BtnConfirm.disabled = false
		_center_open_payment_button_on_screen()


func _set_close_payment_button() -> void:
	_set_payment_ready_popup_layout()
	if BtnConfirm != null:
		BtnConfirm.text = _club_tokens_tr("club_tokens.store.continue", "Continue")
		BtnConfirm.disabled = false
		_center_open_payment_button_on_screen()


func _reset_payment_attempt_state() -> void:
	_pending_checkout_url = ""
	_checkout_session_request_in_flight = false
	_checkout_auth_retry_done = false
	_checkout_auth_request_in_flight = false
	_payment_refresh_request_in_flight = false
	_payment_waiting_for_refresh = false
	_return_refresh_done = false
	_payment_confirmation_shown = false
	_tokens_before_payment = 0
	_expected_payment_tokens = 0


func _show_payment_pending_state() -> void:
	_payment_waiting_for_refresh = true
	_return_refresh_done = false
	_payment_confirmation_shown = false
	_set_payment_opened_content()
	_set_refresh_payment_button()
	_set_status(_club_tokens_tr("club_tokens.stripe.payment_opened_status", "Payment page opened. Complete your payment in the new tab, then return here."))


func _open_purchase_confirm(amount: int) -> void:
	_pending_tokens_amount = amount
	_reset_payment_attempt_state()
	_restore_purchase_popup_layout()
	_set_purchase_confirm_content(amount)
	if BtnCancel != null:
		BtnCancel.visible = true
	if BtnConfirm != null:
		BtnConfirm.text = _format_buy_payment_button_text(amount)
		BtnConfirm.disabled = false
		_restore_confirm_button_layout()
	if PopupConfirm != null:
		PopupConfirm.visible = true


func _show_token_purchase_confetti() -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	var old := ui.get_node_or_null("TokenPurchaseConfetti")
	if old != null:
		old.queue_free()
	var layer := Control.new()
	layer.name = "TokenPurchaseConfetti"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 250
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(layer)
	var colors := [
		Color(1.0, 0.78, 0.18, 1.0),
		Color(0.18, 0.82, 1.0, 1.0),
		Color(0.25, 1.0, 0.42, 1.0),
		Color(1.0, 0.28, 0.42, 1.0),
		Color(0.72, 0.42, 1.0, 1.0)
	]
	var points := [
		Vector2(510, 150), Vector2(600, 125), Vector2(690, 150),
		Vector2(545, 205), Vector2(640, 190), Vector2(735, 212),
		Vector2(500, 280), Vector2(610, 265), Vector2(720, 292),
		Vector2(555, 350), Vector2(660, 338), Vector2(760, 365)
	]
	for i in range(points.size()):
		var piece := Label.new()
		piece.text = "✦"
		piece.position = points[i]
		piece.add_theme_font_size_override("font_size", 24 + (i % 3) * 5)
		piece.add_theme_color_override("font_color", colors[i % colors.size()])
		piece.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		piece.add_theme_constant_override("shadow_outline_size", 4)
		layer.add_child(piece)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position", points[i] + Vector2((i % 5 - 2) * 24, 70 + (i % 4) * 18), 2.8)
		tw.parallel().tween_property(piece, "modulate:a", 0.0, 2.8)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(layer):
		layer.queue_free()


func _club_tokens_tr(key: String, fallback: String) -> String:
	var v := tr(key)
	if v == key or v.strip_edges() == "":
		return fallback
	return v


func _token_history_reason_text(reason: String) -> String:
	var raw := str(reason).strip_edges()
	if raw == "":
		return _club_tokens_tr("club_tokens.history.reason.reward", "Token reward")
	if raw.begins_with("tokens.history.") or raw.begins_with("club_tokens.history."):
		return _club_tokens_tr(raw, raw)
	if raw == "missions_auto_claim" or raw.begins_with("mission_"):
		return _club_tokens_tr("club_tokens.history.reason.mission", "Mission completed")
	if raw.begins_with("tournament_reward_"):
		return _club_tokens_tr("club_tokens.history.reason.tournament", "Tournament reward")
	if raw.begins_with("shop_debug_pkg_"):
		return _club_tokens_tr("club_tokens.history.reason.token_pack", "Token pack")
	if raw.begins_with("club_badge_"):
		return _club_tokens_tr("club_tokens.history.reason.club_identity", "Club Identity")
	if raw == "auto_save_match_selection_season":
		return _club_tokens_tr("club_tokens.history.reason.auto_save_lineup", "Auto Save Lineup")
	if raw == "skip_final_result":
		return _club_tokens_tr("club_tokens.history.reason.skip_match_summary", "Skip Match Summary")
	return raw.capitalize().replace("_", " ")


func _token_history_amount_text(amount: int) -> String:
	var sign := "+" if amount > 0 else ""
	return sign + str(amount) + " " + _club_tokens_tr("club_tokens.history.tokens", "Tokens")


func _make_info_label(text: String, font_size: int, color: Color = Color(1, 1, 1, 1), outline: int = 4) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	lbl.add_theme_constant_override("outline_size", outline)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_section_card(title: String, lines: Array[String]) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 160)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.88)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.74, 0.22, 0.65)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_make_info_label(title, 25, Color(1.0, 0.82, 0.28, 1.0), 5))
	for line in lines:
		box.add_child(_make_info_label("✓ " + line, 22, Color(0.96, 0.98, 1.0, 1.0), 3))
	return card


func _make_dashboard_card(title: String, subtitle: String, action: String, affordable: bool = true) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.88)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.95, 0.50, 0.72) if affordable else Color(1.0, 0.74, 0.22, 0.55)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var title_lbl := _make_info_label(title, 23, Color(1.0, 1.0, 1.0, 1.0), 3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_box.add_child(title_lbl)

	var subtitle_lbl := _make_info_label(subtitle, 19, Color(0.86, 0.92, 1.0, 0.92), 2)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_box.add_child(subtitle_lbl)

	if action.strip_edges() != "":
		var cost_lbl := _make_info_label(action, 20, Color(0.42, 1.0, 0.58, 1.0) if affordable else Color(1.0, 0.82, 0.28, 1.0), 3)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_box.add_child(cost_lbl)
	return card


func _make_dashboard_section(title: String, entries: Array[Dictionary]) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_lbl := _make_info_label(title, 24, Color(1.0, 0.82, 0.28, 1.0), 5)
	title_lbl.add_theme_color_override("font_shadow_color", Color(1.0, 0.62, 0.12, 0.85))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 0)
	title_lbl.add_theme_constant_override("shadow_outline_size", 10)
	section.add_child(title_lbl)
	for entry in entries:
		section.add_child(_make_dashboard_card(
			str(entry.get("title", "")),
			str(entry.get("benefit", entry.get("subtitle", ""))),
			str(entry.get("token_cost", entry.get("action", ""))),
			bool(entry.get("affordable", true))
		))
	return section


func _make_club_tokens_category_card(title: String, subtitle: String, button_text: String, badge_texture_path: String, section_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 390)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.90)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.74, 0.22, 0.72)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var badge := TextureRect.new()
	badge.custom_minimum_size = Vector2(110, 110)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if badge_texture_path != "" and ResourceLoader.exists(badge_texture_path):
		badge.texture = load(badge_texture_path) as Texture2D
	box.add_child(badge)

	var title_lbl := _make_info_label(title, 28, Color(1.0, 0.86, 0.34, 1.0), 5)
	title_lbl.custom_minimum_size = Vector2(320, 44)
	box.add_child(title_lbl)

	var subtitle_lbl := _make_info_label(subtitle, 20, Color(0.88, 0.95, 1.0, 0.98), 3)
	subtitle_lbl.custom_minimum_size = Vector2(320, 58)
	subtitle_lbl.add_theme_color_override("font_shadow_color", Color(0.20, 0.55, 1.0, 0.45))
	subtitle_lbl.add_theme_constant_override("shadow_offset_x", 0)
	subtitle_lbl.add_theme_constant_override("shadow_offset_y", 0)
	subtitle_lbl.add_theme_constant_override("shadow_outline_size", 6)
	box.add_child(subtitle_lbl)

	var cta := _make_hub_nav_button(button_text, section_id, true)
	cta.custom_minimum_size = Vector2(300, 50)
	cta.add_theme_font_size_override("font_size", 19)
	cta.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	cta.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	cta.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	cta.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.80))
	cta.add_theme_constant_override("outline_size", 3)
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(cta)
	return card


func _make_club_tokens_category_cards() -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.name = "ClubTokensCategoryCards"
	cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	var save := PlayerLife.load_savegame()
	var equipped_badge_id := PlayerLife.get_equipped_club_badge_id(save)
	var equipped_badge_path := PlayerLife.get_club_badge_texture_path(save, equipped_badge_id)
	if equipped_badge_path == "" or not ResourceLoader.exists(equipped_badge_path):
		equipped_badge_path = PlayerLife.get_club_badge_texture_path_for_level("starter_crest_01", 1)
	cards.add_child(_make_club_tokens_category_card(
		_club_tokens_tr("club_identity.title", "Club Identity"),
		_club_tokens_tr("club_identity.overview_subtitle", "Customize your club badge and build your identity."),
		_club_tokens_tr("club_identity.setup_cta", "SET UP CLUB IDENTITY"),
		equipped_badge_path,
		"club_identity"
	))
	cards.add_child(_make_club_tokens_category_card(
		_club_tokens_tr("home_arena.title", "HOME ARENA"),
		_club_tokens_tr("home_arena.overview_subtitle", "Transform your home games into a premium arena."),
		_club_tokens_tr("home_arena.setup_cta", "SET UP HOME ARENA"),
		"res://assets/images/backgrounds/home_arena.png",
		"home_arena"
	))
	return cards


func _make_club_tokens_cards_arrow(text: String, direction: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(44, 84)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.22, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	btn.add_theme_constant_override("outline_size", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.86)
	sb.border_color = Color(1.0, 0.74, 0.22, 0.74)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.05, 0.16, 0.36, 0.95)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.02, 0.10, 0.24, 1.0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(func():
		if _club_tokens_cards_scroll == null or not is_instance_valid(_club_tokens_cards_scroll):
			return
		var target := _club_tokens_cards_scroll.scroll_horizontal + direction * 390
		_club_tokens_cards_scroll.scroll_horizontal = maxi(0, target)
	)
	return btn


func _format_token_cost(cost: int) -> String:
	var amount := maxi(0, int(cost))
	var key := "club_tokens.cost.token" if amount == 1 else "club_tokens.cost.tokens"
	var txt := _club_tokens_tr(key, "{amount} Token" if amount == 1 else "{amount} Tokens")
	return txt.replace("{amount}", str(amount))


func _get_token_progress_message_key(balance: int) -> String:
	var token_count := maxi(0, int(balance))
	for row in TOKEN_PROGRESS_MESSAGES:
		if token_count >= int(row.get("minimum_tokens", 0)):
			return str(row.get("message_key", "club_tokens.progress.0"))
	return "club_tokens.progress.0"


func _make_token_opportunity(title_key: String, title_fallback: String, benefit_key: String, benefit_fallback: String, token_cost: int, balance: int, priority: int, available: bool = true) -> Dictionary:
	return {
		"title": _club_tokens_tr(title_key, title_fallback),
		"benefit": _club_tokens_tr(benefit_key, benefit_fallback),
		"token_cost": _format_token_cost(token_cost) if available else _club_tokens_tr("club_tokens.status.coming_soon", "Coming soon"),
		"affordable": available and balance >= token_cost,
		"available": available,
		"priority": priority
	}


func _append_coach_token_opportunities(entries: Array[Dictionary], save: Dictionary, balance: int) -> void:
	if not PlayerLife.is_coachs_unlocked(save):
		return
	var coachs: Dictionary = save.get("coachs", {}) as Dictionary
	var owned: Array = coachs.get("owned", []) as Array
	var coach_ids := ["coach_junior", "coach_confirme", "coach_elite"]
	var coach_title_keys := {
		"coach_junior": "club_tokens.opportunity.coach_junior",
		"coach_confirme": "club_tokens.opportunity.coach_confirme",
		"coach_elite": "club_tokens.opportunity.coach_elite"
	}
	var coach_benefit_keys := {
		"coach_junior": "club_tokens.benefit.coach_junior",
		"coach_confirme": "club_tokens.benefit.coach_confirme",
		"coach_elite": "club_tokens.benefit.coach_elite"
	}
	var coach_priority := {
		"coach_junior": 20,
		"coach_confirme": 30,
		"coach_elite": 40
	}
	for coach_id in coach_ids:
		if owned.has(coach_id):
			continue
		var data := PlayerLife.get_coach_price_data(coach_id)
		if data.is_empty():
			continue
		entries.append(_make_token_opportunity(
			str(coach_title_keys.get(coach_id, "")),
			str(data.get("label", coach_id)),
			str(coach_benefit_keys.get(coach_id, "")),
			"Improve your players faster",
			maxi(0, int(data.get("tokens_cost", 0))),
			balance,
			int(coach_priority.get(coach_id, 50)),
			true
		))


func _append_match_token_opportunities(entries: Array[Dictionary], save: Dictionary, balance: int) -> void:
	if int(save.get("season_number", 1)) < 2:
		return
	entries.append(_make_token_opportunity(
		"club_tokens.opportunity.skip_final_result",
		"Skip Match Summary",
		"club_tokens.benefit.skip_final_result",
		"Jump directly to your next decision without watching the post-match sequence.",
		BM_SKIP_FINAL_RESULT_TOKEN_COST_DISPLAY,
		balance,
		60,
		true
	))


func _append_lineup_token_opportunities(entries: Array[Dictionary], save: Dictionary, balance: int) -> void:
	var roster_reset: Dictionary = save.get("roster_reset", {}) as Dictionary
	if bool(roster_reset.get("auto_save_match_selection_paid", false)):
		return
	entries.append(_make_token_opportunity(
		"club_tokens.opportunity.auto_save_lineup",
		"Auto Save Lineup",
		"club_tokens.benefit.auto_save_lineup",
		"Save time before every match by automatically reusing your previous lineup.",
		BM_AUTO_SAVE_LINEUP_TOKEN_COST_DISPLAY,
		balance,
		70,
		true
	))


func _append_stadium_token_opportunities(entries: Array[Dictionary], save: Dictionary, balance: int) -> void:
	var stadium: Dictionary = save.get("stadium", {}) as Dictionary
	if not bool(stadium.get("travaux_en_cours", false)):
		return
	var target_ng := int(stadium.get("travaux_cible_ng", 0))
	var target_ns := int(stadium.get("travaux_cible_ns", 0))
	var level_key := StadiumDataRef.level_key(target_ng, target_ns)
	var cost := int(StadiumDataRef.ACCELERATION_TOKENS.get(level_key, 0))
	if cost <= 0:
		return
	entries.append(_make_token_opportunity(
		"club_tokens.opportunity.speed_up_stadium",
		"Speed Up Stadium Upgrade",
		"club_tokens.benefit.speed_up_stadium",
		"Finish stadium construction earlier and enjoy the benefits before your biggest matches.",
		cost,
		balance,
		10,
		true
	))


func _append_sponsors_token_opportunities(entries: Array[Dictionary], save: Dictionary, balance: int) -> void:
	if PlayerLife.get_club_level(save) >= 5:
		return
	entries.append(_make_token_opportunity(
		"club_tokens.opportunity.premium_sponsors",
		"Premium Sponsors",
		"club_tokens.benefit.premium_sponsors",
		"Unlock higher-value sponsorship contracts to increase your club income.",
		0,
		balance,
		90,
		false
	))


func _get_available_token_opportunities(save: Dictionary, balance: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if typeof(save) != TYPE_DICTIONARY:
		return entries

	PlayerLife.ensure_progression_wallet_schema(save)
	_append_stadium_token_opportunities(entries, save, balance)
	_append_coach_token_opportunities(entries, save, balance)
	_append_match_token_opportunities(entries, save, balance)
	_append_lineup_token_opportunities(entries, save, balance)
	_append_sponsors_token_opportunities(entries, save, balance)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 100)) < int(b.get("priority", 100))
	)
	return entries


func _get_token_history_entries(save: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if typeof(save) != TYPE_DICTIONARY:
		return lines

	if save.has("token_history") and typeof(save["token_history"]) == TYPE_ARRAY:
		var history: Array = save["token_history"] as Array
		for i in range(history.size() - 1, -1, -1):
			var raw = history[i]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw as Dictionary
			var amount := int(item.get("amount", 0))
			var reason := str(item.get("reason_key", item.get("reason", ""))).strip_edges()
			if amount != 0:
				lines.append(_token_history_reason_text(reason) + "  " + _token_history_amount_text(amount))

	if lines.is_empty() and save.has("pending_season_reward_popup") and typeof(save["pending_season_reward_popup"]) == TYPE_DICTIONARY:
		var pending: Dictionary = save["pending_season_reward_popup"] as Dictionary
		var tokens := int(pending.get("tokens", 0))
		if tokens > 0:
			lines.append(_club_tokens_tr("club_tokens.history.season_reward", "Season reward") + "  " + _token_history_amount_text(tokens))
	if lines.is_empty():
		var balance := PlayerLife.get_tokens(save)
		if balance > 0:
			lines.append(_club_tokens_tr("club_tokens.history.previous_balance", "Tokens already earned") + "  " + str(balance) + " " + _club_tokens_tr("club_tokens.history.tokens", "Tokens"))
	return lines


func _show_token_history_popup() -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	var old := ui.get_node_or_null("ClubTokensHistoryPopup")
	if old != null:
		old.queue_free()

	var save: Dictionary = PlayerLife.load_savegame()
	var lines := _get_token_history_entries(save)
	if lines.is_empty():
		lines.append(_club_tokens_tr("club_tokens.history.empty", "No token history yet."))

	var popup := PanelContainer.new()
	popup.name = "ClubTokensHistoryPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -260.0
	popup.offset_top = -170.0
	popup.offset_right = 260.0
	popup.offset_bottom = 170.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.96)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.74, 0.22, 0.85)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	popup.add_theme_stylebox_override("panel", sb)
	ui.add_child(popup)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	popup.add_child(box)
	box.add_child(_make_info_label(_club_tokens_tr("club_tokens.history", "History"), 26, Color(1.0, 0.82, 0.28, 1.0), 5))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 205)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(scroll)

	var history_box := VBoxContainer.new()
	history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_box.add_theme_constant_override("separation", 8)
	scroll.add_child(history_box)

	for line in lines:
		history_box.add_child(_make_info_label(line, 20, Color(0.96, 0.98, 1.0, 1.0), 3))

	var close_btn := Button.new()
	close_btn.text = _club_tokens_tr("club_tokens.history.close", "Close")
	close_btn.custom_minimum_size = Vector2(170, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)
	box.add_child(close_btn)


func _add_history_button(root: Control) -> void:
	if not BM_SHOW_TOKEN_HISTORY_BUTTON:
		return
	var ui := root.get_parent() as Control
	if ui == null:
		return
	var old := ui.get_node_or_null("BtnClubTokensHistory")
	if old != null:
		old.queue_free()
	var btn := Button.new()
	btn.name = "BtnClubTokensHistory"
	btn.text = _club_tokens_tr("club_tokens.history", "History")
	btn.custom_minimum_size = Vector2(190, 54)
	btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn.offset_left = -230.0
	btn.offset_top = -86.0
	btn.offset_right = -30.0
	btn.offset_bottom = -26.0
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.45, 0.06, 1.0)
	style.border_color = Color(1.0, 0.78, 0.22, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.55, 0.08, 1.0)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.78, 0.30, 0.03, 1.0)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(_show_token_history_popup)
	ui.add_child(btn)


func _set_club_tokens_main_visible(visible: bool) -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	var info_root := ui.get_node_or_null("ClubTokensInfoRoot")
	if info_root != null:
		info_root.visible = visible
	var balance_card := ui.get_node_or_null("ClubTokensBalanceCard")
	if balance_card != null:
		balance_card.visible = visible
	var history_btn := ui.get_node_or_null("BtnClubTokensHistory")
	if history_btn != null:
		history_btn.visible = visible
	if _btn_buy_club_tokens != null and is_instance_valid(_btn_buy_club_tokens):
		_btn_buy_club_tokens.visible = visible


func _club_identity_badge_name(badge_id: String) -> String:
	var idx := int(str(badge_id).replace("starter_crest_", ""))
	var txt := _club_tokens_tr("club_identity.badge_name", "Badge {number}")
	return txt.replace("{number}", str(idx))


func _make_club_identity_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 44)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.25)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.10)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.16)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _make_club_identity_token_icon(size: int = 24) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TOKEN_ICON_PATH):
		icon.texture = load(TOKEN_ICON_PATH) as Texture2D
	return icon


func _make_club_identity_token_cost_row(cost: int, font_size: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_txt := str(cost)
	var label_width := maxf(float(font_size + 16), float(cost_txt.length()) * float(font_size) * 0.72 + 18.0)
	row.custom_minimum_size = Vector2(label_width + float(font_size + 18) + 16.0, font_size + 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var lbl := _make_info_label(cost_txt, font_size, Color(1.0, 0.86, 0.32, 1.0), 3)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.custom_minimum_size = Vector2(label_width, font_size + 8)
	row.add_child(lbl)
	row.add_child(_make_club_identity_token_icon(font_size + 2))
	return row


func _make_club_identity_confirm_cost_row(confirm_txt: String, cost: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	var parts := confirm_txt.split("{cost}", false, 1)
	var prefix := confirm_txt
	var suffix := ""
	if parts.size() >= 2:
		prefix = str(parts[0])
		suffix = str(parts[1])
	suffix = suffix.replace("Tokens", "").replace("Token", "").strip_edges()
	if suffix == "?" or suffix == "¿" or suffix == "؟":
		suffix = ""
	var prefix_lbl := _make_info_label(prefix.strip_edges(), 24, Color(1.0, 0.94, 0.74, 1.0), 4)
	prefix_lbl.custom_minimum_size = Vector2(460, 36)
	prefix_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prefix_lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(180, 34)
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var cost_lbl := Label.new()
	cost_lbl.text = str(cost)
	cost_lbl.custom_minimum_size = Vector2(56, 34)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_lbl.add_theme_font_size_override("font_size", 24)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
	cost_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	cost_lbl.add_theme_constant_override("outline_size", 4)
	row.add_child(cost_lbl)
	row.add_child(_make_club_identity_token_icon(28))
	if suffix != "":
		var suffix_lbl := _make_info_label(suffix, 24, Color(1.0, 0.94, 0.74, 1.0), 4)
		suffix_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(suffix_lbl)
	return box


func _refresh_club_identity_screen() -> void:
	_club_tokens_active_section = "club_identity"
	_build_club_tokens_info_screen()


func _club_identity_write_and_refresh(save: Dictionary) -> void:
	PlayerLife.write_savegame(save)
	_refresh_club_identity_screen()


func _show_club_identity_message(root: Control, key: String, fallback: String, color: Color = Color(1.0, 0.35, 0.30, 1.0)) -> void:
	var lbl := root.get_node_or_null("ClubIdentityMessage") as Label
	if lbl == null:
		return
	lbl.text = _club_tokens_tr(key, fallback)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 22)


func _show_club_identity_upgrade_confirm(root: Control, badge_id: String, cost: int) -> void:
	_show_club_identity_action_confirm(root, badge_id, PlayerLife.CLUB_BADGE_ACTION_UPGRADE, cost)


func _show_club_identity_unlock_confirm(root: Control, badge_id: String, cost: int) -> void:
	_show_club_identity_action_confirm(root, badge_id, PlayerLife.CLUB_BADGE_ACTION_SWITCH, cost)


func _club_identity_action_label(action: String) -> String:
	match action:
		PlayerLife.CLUB_BADGE_ACTION_SWITCH:
			return _club_tokens_tr("club_identity.action_change", "Change")
		PlayerLife.CLUB_BADGE_ACTION_UPGRADE:
			return _club_tokens_tr("club_identity.action_upgrade", "Upgrade")
		PlayerLife.CLUB_BADGE_ACTION_SWITCH_UPGRADE:
			return _club_tokens_tr("club_identity.action_change_upgrade", "Change + Upgrade")
	return ""


func _show_club_identity_action_confirm(root: Control, badge_id: String, action: String, cost: int) -> void:
	var old := root.get_node_or_null("ClubIdentityConfirmPopup")
	if old != null:
		old.queue_free()
	var popup := PanelContainer.new()
	popup.name = "ClubIdentityConfirmPopup"
	popup.z_index = 300
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -260.0
	popup.offset_top = -145.0
	popup.offset_right = 260.0
	popup.offset_bottom = 145.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.018, 0.024, 0.045, 0.98)
	sb.border_color = Color(1.0, 0.72, 0.22, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	popup.add_theme_stylebox_override("panel", sb)
	root.add_child(popup)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	popup.add_child(box)
	var action_label := _club_identity_action_label(action)
	var confirm_txt := _club_tokens_tr("club_identity.action_confirm", "{action} for {cost} Tokens?")
	confirm_txt = confirm_txt.replace("{action}", action_label)
	box.add_child(_make_club_identity_confirm_cost_row(confirm_txt, cost))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var cancel_btn := _make_club_identity_button(_club_tokens_tr("club_identity.cancel", "Cancel"), Color(0.74, 0.10, 0.16, 1.0))
	cancel_btn.pressed.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)
	row.add_child(cancel_btn)
	var confirm_btn := _make_club_identity_button(_club_tokens_tr("club_identity.confirm", "Confirm"), Color(0.08, 0.62, 0.22, 1.0))
	confirm_btn.pressed.connect(func():
		var save := PlayerLife.load_savegame()
		if not PlayerLife.apply_club_badge_action(save, badge_id, action):
			_show_club_identity_message(root, "club_identity.not_enough_tokens", "Not enough tokens")
			if is_instance_valid(popup):
				popup.queue_free()
			return
		_club_identity_preview_badge_id = badge_id
		_club_identity_write_and_refresh(save)
	)
	row.add_child(confirm_btn)


func _apply_club_identity_selection(root: Control) -> void:
	var grid := root.get_node_or_null("ClubIdentityBadgeGrid") as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		var card := child as PanelContainer
		if card == null:
			continue
		var badge_id := str(card.get_meta("club_identity_badge_id", ""))
		var selected := badge_id == _club_identity_preview_badge_id
		card.scale = Vector2(1.5, 1.5) if selected else Vector2.ONE
		card.z_index = 20 if selected else 0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var current_style := card.get_theme_stylebox("panel")
		if current_style is StyleBoxFlat:
			var sb := (current_style as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.border_color = Color(0.20, 0.95, 0.42, 0.95) if selected else Color(1.0, 0.74, 0.22, 0.55)
			card.add_theme_stylebox_override("panel", sb)


func _make_club_identity_badge_card(root: Control, save: Dictionary, badge_id: String) -> PanelContainer:
	var is_selected := _club_identity_preview_badge_id == badge_id
	var card := PanelContainer.new()
	card.set_meta("club_identity_badge_id", badge_id)
	card.custom_minimum_size = Vector2(184, 247)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(92, 124)
	if is_selected:
		card.scale = Vector2(1.5, 1.5)
		card.z_index = 20
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_club_identity_preview_badge_id = "" if _club_identity_preview_badge_id == badge_id else badge_id
				_apply_club_identity_selection(root)
	)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.90)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.20, 0.95, 0.42, 0.95) if is_selected else Color(1.0, 0.74, 0.22, 0.55)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var tex_path := PlayerLife.get_club_badge_texture_path(save, badge_id)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(100, 100)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path) as Texture2D
	icon.modulate = Color(1.12, 1.12, 1.12, 1.0)
	box.add_child(icon)
	box.add_child(_make_info_label(_club_identity_badge_name(badge_id), 18, Color(1, 1, 1, 1), 3))
	var level_txt := _club_tokens_tr("club_identity.level", "Level {level}").replace("{level}", "1")
	box.add_child(_make_info_label(level_txt, 16, Color(1.0, 0.82, 0.28, 1.0), 3))
	var unlock_cost := PlayerLife.get_base_badge_unlock_cost(badge_id)
	box.add_child(_make_club_identity_token_cost_row(unlock_cost, 17))
	var unlock_btn := _make_club_identity_button(_club_tokens_tr("club_identity.unlock", "Unlock"), Color(0.95, 0.45, 0.06, 1.0))
	unlock_btn.custom_minimum_size = Vector2(130, 36)
	unlock_btn.add_theme_font_size_override("font_size", 17)
	unlock_btn.pressed.connect(func():
		_show_club_identity_unlock_confirm(root, badge_id, unlock_cost)
	)
	box.add_child(unlock_btn)
	return card


func _make_club_identity_owned_card(root: Control, save: Dictionary, badge_id: String) -> PanelContainer:
	var is_selected := PlayerLife.get_equipped_club_badge_id(save) == badge_id
	var level := PlayerLife.get_club_badge_level(save, badge_id)
	var card_size := Vector2(325, 140) if is_selected else Vector2(260, 112)
	var row_size := Vector2(295, 92) if is_selected else Vector2(236, 74)
	var icon_size := 98 if is_selected else 78
	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = card_size * 0.5
	if is_selected:
		card.z_index = 20
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var s := PlayerLife.load_savegame()
				if PlayerLife.equip_club_badge(s, badge_id):
					_club_identity_preview_badge_id = badge_id
					_club_identity_write_and_refresh(s)
	)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.90)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.20, 0.95, 0.42, 0.95) if is_selected else Color(1.0, 0.74, 0.22, 0.55)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var title_lbl := _make_info_label("%s - Lv %d" % [_club_identity_badge_name(badge_id), level], 20 if is_selected else 16, Color(1, 1, 1, 1), 2)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_lbl)

	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = row_size
	box.add_child(row)
	var tex_path := PlayerLife.get_club_badge_texture_path(save, badge_id)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -float(icon_size) * 0.5
	icon.offset_top = -float(icon_size) * 0.5
	icon.offset_right = float(icon_size) * 0.5
	icon.offset_bottom = float(icon_size) * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path) as Texture2D
	row.add_child(icon)
	return card


func _make_club_identity_action_card(root: Control, save: Dictionary, badge_id: String, target_level: int, action: String, enabled: bool) -> PanelContainer:
	var equipped := PlayerLife.get_equipped_club_badge_id(save)
	var is_selected := enabled and action == "" and badge_id == equipped
	var is_previewed := _club_identity_preview_badge_id == "%s:%d" % [badge_id, target_level]
	var card := PanelContainer.new()
	card.set_meta("club_identity_badge_id", badge_id)
	card.set_meta("club_identity_target_level", target_level)
	card.custom_minimum_size = Vector2(250, 290)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(125, 145)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_club_identity_preview_badge_id = "%s:%d" % [badge_id, target_level]
				_apply_club_identity_action_selection(root)
				_show_club_identity_zoom_overlay(root, card, save, badge_id, target_level, action, enabled)
	)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.92) if enabled else Color(0.025, 0.03, 0.055, 0.52)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.20, 0.95, 0.42, 0.95) if (is_selected or is_previewed) else Color(1.0, 0.74, 0.22, 0.52)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var tex_path := PlayerLife.get_club_badge_texture_path_for_level(badge_id, target_level)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(108, 108)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path) as Texture2D
	icon.modulate = Color(1.15, 1.15, 1.15, 1.0) if enabled else Color(0.60, 0.60, 0.64, 0.78)
	box.add_child(icon)
	box.add_child(_make_info_label(_club_identity_badge_name(badge_id), 18, Color(1, 1, 1, 1), 2))
	if is_selected:
		box.add_child(_make_info_label(_club_tokens_tr("club_identity.selected", "Selected"), 18, Color(0.25, 1.0, 0.48, 1.0), 2))
		return card
	if not enabled:
		box.add_child(_make_info_label(_club_tokens_tr("club_identity.unavailable", "Next step"), 16, Color(0.70, 0.76, 0.86, 0.70), 2))
		return card

	var action_label := _club_identity_action_label(action)
	var cost := PlayerLife.get_badge_action_cost(save, badge_id, action)
	box.add_child(_make_club_identity_token_cost_row(cost, 20))
	var btn := _make_club_identity_button(action_label, Color(0.95, 0.45, 0.06, 1.0))
	btn.custom_minimum_size = Vector2(190, 40)
	btn.add_theme_font_size_override("font_size", 17)
	btn.disabled = cost <= 0
	btn.pressed.connect(func():
		_show_club_identity_action_confirm(root, badge_id, action, cost)
	)
	box.add_child(btn)
	return card


func _clear_club_identity_zoom_overlay(root: Control) -> void:
	var old := root.get_node_or_null("ClubIdentityZoomOverlay")
	if old != null:
		old.queue_free()


func _show_club_identity_zoom_overlay(root: Control, source_card: Control, save: Dictionary, badge_id: String, target_level: int, action: String, enabled: bool) -> void:
	_clear_club_identity_zoom_overlay(root)
	var equipped := PlayerLife.get_equipped_club_badge_id(save)
	var is_selected := enabled and action == "" and badge_id == equipped
	var overlay := PanelContainer.new()
	overlay.name = "ClubIdentityZoomOverlay"
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_clear_club_identity_zoom_overlay(root)
	)
	var overlay_size := Vector2(430, 499)
	overlay.custom_minimum_size = overlay_size
	overlay.size = overlay_size
	var root_rect := root.get_global_rect()
	var source_rect := source_card.get_global_rect()
	var pos := source_rect.position - root_rect.position + source_rect.size * 0.5 - overlay_size * 0.5
	pos.x = clampf(pos.x, 0.0, maxf(0.0, root.size.x - overlay_size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, root.size.y - overlay_size.y))
	overlay.position = pos
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.97) if enabled else Color(0.025, 0.03, 0.055, 0.76)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.20, 0.95, 0.42, 0.95)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	overlay.add_theme_stylebox_override("panel", sb)
	root.add_child(overlay)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	overlay.add_child(box)

	var tex_path := PlayerLife.get_club_badge_texture_path_for_level(badge_id, target_level)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(186, 186)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path) as Texture2D
	icon.modulate = Color(1.15, 1.15, 1.15, 1.0) if enabled else Color(0.60, 0.60, 0.64, 0.78)
	box.add_child(icon)
	box.add_child(_make_info_label(_club_identity_badge_name(badge_id), 31, Color(1, 1, 1, 1), 4))
	if is_selected:
		box.add_child(_make_info_label(_club_tokens_tr("club_identity.selected", "Selected"), 31, Color(0.25, 1.0, 0.48, 1.0), 4))
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					_clear_club_identity_zoom_overlay(root)
		)
		return
	if not enabled:
		box.add_child(_make_info_label(_club_tokens_tr("club_identity.unavailable", "Next step"), 27, Color(0.70, 0.76, 0.86, 0.70), 3))
		return

	var action_label := _club_identity_action_label(action)
	var cost := PlayerLife.get_badge_action_cost(save, badge_id, action)
	box.add_child(_make_club_identity_token_cost_row(cost, 33))
	var btn := _make_club_identity_button(action_label, Color(0.95, 0.45, 0.06, 1.0))
	btn.custom_minimum_size = Vector2(327, 69)
	btn.add_theme_font_size_override("font_size", 29)
	btn.disabled = cost <= 0
	btn.pressed.connect(func():
		_show_club_identity_action_confirm(root, badge_id, action, cost)
	)
	box.add_child(btn)


func _apply_club_identity_action_selection(root: Control) -> void:
	var levels_box := root.get_node_or_null("ClubIdentityLevelScroller/ClubIdentityLevelsBox") as VBoxContainer
	if levels_box == null:
		return
	for section in levels_box.get_children():
		for node in section.get_children():
			var grid := node as GridContainer
			if grid == null:
				continue
			for child in grid.get_children():
				var card := child as PanelContainer
				if card == null:
					continue
				var badge_id := str(card.get_meta("club_identity_badge_id", ""))
				var target_level := int(card.get_meta("club_identity_target_level", 0))
				var previewed := _club_identity_preview_badge_id == "%s:%d" % [badge_id, target_level]
				card.scale = Vector2.ONE
				card.z_index = 0
				var current_style := card.get_theme_stylebox("panel")
				if current_style is StyleBoxFlat:
					var sb := (current_style as StyleBoxFlat).duplicate() as StyleBoxFlat
					sb.border_color = Color(0.20, 0.95, 0.42, 0.95) if previewed else Color(1.0, 0.74, 0.22, 0.52)
					card.add_theme_stylebox_override("panel", sb)


func _make_club_identity_level_section(root: Control, save: Dictionary, target_level: int) -> VBoxContainer:
	var equipped := PlayerLife.get_equipped_club_badge_id(save)
	var current_level := PlayerLife.get_club_badge_level(save, equipped)
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var title_txt := _club_tokens_tr("club_identity.level", "Level {level}").replace("{level}", str(target_level)).to_upper()
	section.add_child(_make_info_label(title_txt, 23, Color(1.0, 0.82, 0.28, 1.0), 4))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	section.add_child(grid)
	for badge_id in PlayerLife.get_club_identity_badge_ids():
		var action := ""
		var enabled := true
		if target_level == current_level:
			if badge_id == equipped:
				action = ""
			else:
				action = PlayerLife.CLUB_BADGE_ACTION_SWITCH
		elif target_level == current_level + 1:
			if badge_id == equipped:
				action = PlayerLife.CLUB_BADGE_ACTION_UPGRADE
			else:
				action = PlayerLife.CLUB_BADGE_ACTION_SWITCH_UPGRADE
		else:
			enabled = false
		grid.add_child(_make_club_identity_action_card(root, save, badge_id, target_level, action, enabled))
	return section


func _show_club_identity_screen() -> void:
	_club_tokens_active_section = "club_identity"
	_build_club_tokens_info_screen()


func _show_home_arena_screen() -> void:
	_club_tokens_active_section = "home_arena"
	_build_club_tokens_info_screen()


func _get_arena_identity(save: Dictionary) -> Dictionary:
	var arena_any: Variant = save.get("arena_identity", {})
	if typeof(arena_any) == TYPE_DICTIONARY:
		return arena_any as Dictionary
	return {}


func _is_home_arena_selected(save: Dictionary) -> bool:
	var arena := _get_arena_identity(save)
	return bool(arena.get("home_arena_owned", false)) and bool(arena.get("home_arena_selected", false))


func _set_home_arena_selected(save: Dictionary) -> void:
	var arena := _get_arena_identity(save)
	arena["home_arena_owned"] = true
	arena["home_arena_selected"] = true
	save["arena_identity"] = arena


func _make_hub_nav_button(label: String, section_id: String, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(190, 54)
	btn.disabled = not enabled
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.78, 0.88, 0.62))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var active := section_id == _club_tokens_active_section
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.20, 0.48, 1.0) if active else Color(0.08, 0.36, 0.72, 0.98)
	sb.border_color = Color(0.42, 0.86, 1.0, 0.95) if active else Color(1.0, 0.74, 0.22, 0.70)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 4 if active else 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.04, 0.24, 0.56, 1.0) if active else Color(0.09, 0.44, 0.86, 1.0)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.20, 0.48, 1.0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", sb)
	if active:
		btn.add_theme_color_override("font_shadow_color", Color(0.35, 0.85, 1.0, 1.0))
		btn.add_theme_constant_override("shadow_offset_x", 0)
		btn.add_theme_constant_override("shadow_offset_y", 0)
		btn.add_theme_constant_override("shadow_outline_size", 14)
	if enabled:
		btn.pressed.connect(func():
			_club_tokens_active_section = section_id
			if section_id == "club_identity":
				_show_club_identity_screen()
			elif section_id == "home_arena":
				_show_home_arena_screen()
			else:
				_build_club_tokens_info_screen()
		)
	return btn


func _add_club_tokens_side_nav(root: Control) -> void:
	var nav := VBoxContainer.new()
	nav.name = "ClubTokensSideNav"
	nav.position = Vector2(0, 54)
	nav.size = Vector2(205, 360)
	nav.add_theme_constant_override("separation", 12)
	root.add_child(nav)
	nav.add_child(_make_hub_nav_button(_club_tokens_tr("club_tokens.nav.overview", "Overview"), "overview", true))
	nav.add_child(_make_hub_nav_button(_club_tokens_tr("club_identity.title", "Club Identity"), "club_identity", true))


func _populate_overview_panel(root: Control, save: Dictionary, balance: int) -> void:
	var box := VBoxContainer.new()
	box.name = "ClubTokensOverviewBox"
	box.position = Vector2(-58, 0)
	box.size = Vector2(970, 580)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	var progress_message := _make_info_label(_club_tokens_tr(_get_token_progress_message_key(balance), "Congratulations on your first Club Tokens!"), 26, Color(1.0, 0.88, 0.42, 1.0), 4)
	progress_message.custom_minimum_size = Vector2(960, 42)
	progress_message.add_theme_color_override("font_shadow_color", Color(1.0, 0.66, 0.12, 0.95))
	progress_message.add_theme_constant_override("shadow_offset_x", 0)
	progress_message.add_theme_constant_override("shadow_offset_y", 0)
	progress_message.add_theme_constant_override("shadow_outline_size", 14)
	box.add_child(progress_message)

	var cards_nav := HBoxContainer.new()
	cards_nav.name = "ClubTokensCardsHorizontalNav"
	cards_nav.custom_minimum_size = Vector2(970, 430)
	cards_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_nav.add_theme_constant_override("separation", 22)
	box.add_child(cards_nav)

	cards_nav.add_child(_make_club_tokens_cards_arrow("‹", -1))

	_club_tokens_cards_scroll = ScrollContainer.new()
	_club_tokens_cards_scroll.name = "ClubTokensCardsScroller"
	_club_tokens_cards_scroll.custom_minimum_size = Vector2(860, 430)
	_club_tokens_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_club_tokens_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_club_tokens_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_nav.add_child(_club_tokens_cards_scroll)

	var category_cards := _make_club_tokens_category_cards()
	category_cards.custom_minimum_size = Vector2(860, 430)
	_club_tokens_cards_scroll.add_child(category_cards)

	cards_nav.add_child(_make_club_tokens_cards_arrow("›", 1))
	_add_buy_club_tokens_access(box)


func _populate_home_arena_panel(root: Control) -> void:
	var save := PlayerLife.load_savegame()
	var selected := _is_home_arena_selected(save)
	var box := VBoxContainer.new()
	box.name = "HomeArenaPlaceholderBox"
	box.position = Vector2(58, 30)
	box.size = Vector2(730, 500)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	root.add_child(box)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(520, 245)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/images/backgrounds/home_arena.png"):
		preview.texture = load("res://assets/images/backgrounds/home_arena.png") as Texture2D
	box.add_child(preview)

	var title_lbl := _make_info_label(_club_tokens_tr("home_arena.title", "HOME ARENA"), 32, Color(1.0, 0.86, 0.34, 1.0), 5)
	title_lbl.custom_minimum_size = Vector2(700, 48)
	box.add_child(title_lbl)

	var subtitle_lbl := _make_info_label(_club_tokens_tr("home_arena.overview_subtitle", "Transform your home games into a premium arena."), 22, Color(0.88, 0.95, 1.0, 0.98), 3)
	subtitle_lbl.custom_minimum_size = Vector2(700, 36)
	subtitle_lbl.add_theme_color_override("font_shadow_color", Color(0.20, 0.55, 1.0, 0.45))
	subtitle_lbl.add_theme_constant_override("shadow_offset_x", 0)
	subtitle_lbl.add_theme_constant_override("shadow_offset_y", 0)
	subtitle_lbl.add_theme_constant_override("shadow_outline_size", 6)
	box.add_child(subtitle_lbl)

	if selected:
		var selected_btn := _make_hub_nav_button(_club_tokens_tr("home_arena.selected", "SELECTED"), "home_arena_selected", false)
		selected_btn.custom_minimum_size = Vector2(300, 54)
		selected_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(selected_btn)
	else:
		box.add_child(_make_club_identity_token_cost_row(HOME_ARENA_COST, 22))
		var select_btn := _make_club_identity_button(_club_tokens_tr("home_arena.select", "SELECT"), Color(0.95, 0.45, 0.06, 1.0))
		select_btn.custom_minimum_size = Vector2(300, 54)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		select_btn.pressed.connect(func():
			_show_home_arena_confirm(root)
		)
		box.add_child(select_btn)

	var msg := _make_info_label("", 22, Color(1.0, 0.35, 0.30, 1.0), 3)
	msg.name = "HomeArenaMessage"
	msg.custom_minimum_size = Vector2(700, 30)
	box.add_child(msg)
	if _home_arena_show_congratulations:
		_home_arena_show_congratulations = false
		_show_home_arena_message(root, "home_arena.congratulations", "Congratulations!", Color(0.35, 1.0, 0.48, 1.0))


func _show_home_arena_message(root: Control, key: String, fallback: String, color: Color = Color(1.0, 0.35, 0.30, 1.0)) -> void:
	var lbl := root.get_node_or_null("HomeArenaPlaceholderBox/HomeArenaMessage") as Label
	if lbl == null:
		return
	lbl.text = _club_tokens_tr(key, fallback)
	lbl.add_theme_color_override("font_color", color)


func _show_home_arena_confirm(root: Control) -> void:
	var old := root.get_node_or_null("HomeArenaConfirmPopup")
	if old != null:
		old.queue_free()
	var popup := PanelContainer.new()
	popup.name = "HomeArenaConfirmPopup"
	popup.z_index = 300
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -260.0
	popup.offset_top = -145.0
	popup.offset_right = 260.0
	popup.offset_bottom = 145.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.018, 0.024, 0.045, 0.98)
	sb.border_color = Color(1.0, 0.72, 0.22, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	popup.add_theme_stylebox_override("panel", sb)
	root.add_child(popup)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	popup.add_child(box)

	var confirm_txt := _club_tokens_tr("home_arena.confirm_select", "Select Home Arena for {cost} Tokens?")
	box.add_child(_make_club_identity_confirm_cost_row(confirm_txt, HOME_ARENA_COST))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var cancel_btn := _make_club_identity_button(_club_tokens_tr("club_identity.cancel", "Cancel"), Color(0.74, 0.10, 0.16, 1.0))
	cancel_btn.pressed.connect(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)
	row.add_child(cancel_btn)
	var confirm_btn := _make_club_identity_button(_club_tokens_tr("club_identity.confirm", "Confirm"), Color(0.08, 0.62, 0.22, 1.0))
	confirm_btn.pressed.connect(func():
		var save := PlayerLife.load_savegame()
		if not PlayerLife.spend_tokens(save, HOME_ARENA_COST, "home_arena_select"):
			_show_home_arena_message(root, "club_identity.not_enough_tokens", "Not enough tokens")
			if is_instance_valid(popup):
				popup.queue_free()
			return
		_set_home_arena_selected(save)
		PlayerLife.write_savegame(save)
		_home_arena_show_congratulations = true
		_build_club_tokens_info_screen()
	)
	row.add_child(confirm_btn)


func _add_hub_main_panel_background(root: Control) -> void:
	var bg := Panel.new()
	bg.name = "ClubTokensMainPanelBlackBg"
	bg.position = Vector2.ZERO
	bg.size = Vector2(850, root.size.y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	sb.border_color = Color(1.0, 0.74, 0.22, 0.45)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	bg.add_theme_stylebox_override("panel", sb)
	root.add_child(bg)


func _populate_club_identity_panel(root: Control) -> void:
	if Title != null:
		Title.text = tr("club_tokens.title")

	var save := PlayerLife.load_savegame()
	PlayerLife.ensure_progression_wallet_schema(save)
	var equipped := PlayerLife.get_equipped_club_badge_id(save)
	if _club_identity_preview_badge_id.strip_edges() == "":
		_club_identity_preview_badge_id = equipped

	var scroller := ScrollContainer.new()
	scroller.name = "ClubIdentityLevelScroller"
	scroller.position = Vector2(32, 22)
	scroller.size = Vector2(790, 520)
	root.add_child(scroller)
	var levels_box := VBoxContainer.new()
	levels_box.name = "ClubIdentityLevelsBox"
	levels_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_box.add_theme_constant_override("separation", 18)
	scroller.add_child(levels_box)
	for level in range(1, PlayerLife.CLUB_IDENTITY_MAX_BADGE_LEVEL + 1):
		levels_box.add_child(_make_club_identity_level_section(root, save, level))

	var msg := _make_info_label("", 22, Color(1.0, 0.35, 0.30, 1.0), 3)
	msg.name = "ClubIdentityMessage"
	msg.position = Vector2(46, 540)
	msg.size = Vector2(760, 34)
	root.add_child(msg)


func _build_club_tokens_info_screen() -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	var old := ui.get_node_or_null("ClubTokensInfoRoot")
	if old != null:
		old.visible = false
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.remove_child(old)
		old.queue_free()
	var old_balance := ui.get_node_or_null("ClubTokensBalanceCard")
	if old_balance != null:
		old_balance.queue_free()
	var old_history := ui.get_node_or_null("BtnClubTokensHistory")
	if old_history != null:
		old_history.queue_free()

	var root := Control.new()
	root.name = "ClubTokensInfoRoot"
	root.position = Vector2(70, 110)
	root.size = Vector2(1090, 580)
	ui.add_child(root)

	var save: Dictionary = PlayerLife.load_savegame()
	var balance := 0
	if typeof(save) == TYPE_DICTIONARY:
		balance = PlayerLife.get_tokens(save)

	var balance_title := _club_tokens_tr("club_tokens.balance", "Balance")
	var balance_card := PanelContainer.new()
	balance_card.name = "ClubTokensBalanceCard"
	balance_card.custom_minimum_size = Vector2(220, 86)
	balance_card.size = Vector2(220, 86)
	balance_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	balance_card.offset_left = -252.0
	balance_card.offset_top = 34.0
	balance_card.offset_right = -32.0
	balance_card.offset_bottom = 120.0
	var balance_sb := StyleBoxFlat.new()
	balance_sb.bg_color = Color(0.03, 0.16, 0.38, 0.92)
	balance_sb.border_width_left = 2
	balance_sb.border_width_top = 2
	balance_sb.border_width_right = 2
	balance_sb.border_width_bottom = 2
	balance_sb.border_color = Color(1.0, 0.72, 0.20, 0.85)
	balance_sb.corner_radius_top_left = 18
	balance_sb.corner_radius_top_right = 18
	balance_sb.corner_radius_bottom_left = 18
	balance_sb.corner_radius_bottom_right = 18
	balance_sb.content_margin_left = 14
	balance_sb.content_margin_right = 14
	balance_sb.content_margin_top = 7
	balance_sb.content_margin_bottom = 7
	balance_card.add_theme_stylebox_override("panel", balance_sb)
	ui.add_child(balance_card)

	var balance_box := VBoxContainer.new()
	balance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_box.add_theme_constant_override("separation", 3)
	balance_card.add_child(balance_box)
	var balance_title_lbl := _make_info_label(balance_title, 21, Color(1.0, 0.82, 0.28, 1.0), 4)
	balance_box.add_child(balance_title_lbl)
	var balance_value_row := HBoxContainer.new()
	balance_value_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_value_row.custom_minimum_size = Vector2(160, 32)
	balance_value_row.add_theme_constant_override("separation", 10)
	balance_box.add_child(balance_value_row)
	var balance_lbl := Label.new()
	balance_lbl.text = str(balance)
	balance_lbl.custom_minimum_size = Vector2(86, 32)
	balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance_lbl.add_theme_font_size_override("font_size", 28)
	balance_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0))
	balance_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	balance_lbl.add_theme_constant_override("outline_size", 5)
	balance_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	balance_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_value_row.add_child(balance_lbl)
	var token_icon := TextureRect.new()
	token_icon.texture = load("res://assets/images/token.png") as Texture2D
	token_icon.custom_minimum_size = Vector2(28, 28)
	token_icon.size = Vector2(28, 28)
	token_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	token_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_icon.stretch_mode = TextureRect.STRETCH_SCALE
	balance_value_row.add_child(token_icon)

	var main_panel := Control.new()
	main_panel.name = "ClubTokensMainPanel"
	main_panel.position = Vector2(225, 0)
	main_panel.size = Vector2(850, 580)
	root.add_child(main_panel)

	if _club_tokens_active_section == "club_identity":
		_add_hub_main_panel_background(main_panel)
		_populate_club_identity_panel(main_panel)
	elif _club_tokens_active_section == "home_arena":
		_add_hub_main_panel_background(main_panel)
		_populate_home_arena_panel(main_panel)
	else:
		_club_tokens_active_section = "overview"
		_populate_overview_panel(main_panel, save, balance)

	_add_history_button(root)


func _add_buy_club_tokens_access(root: VBoxContainer) -> void:
	_btn_buy_club_tokens = Button.new()
	_btn_buy_club_tokens.name = "BtnBuyClubTokens"
	var buy_text := _club_tokens_tr("club_tokens.buy", "BUY CLUB TOKENS")
	_btn_buy_club_tokens.text = buy_text
	_btn_buy_club_tokens.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn_buy_club_tokens.custom_minimum_size = Vector2(360, 87)
	_btn_buy_club_tokens.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_buy_club_tokens.add_theme_font_size_override("font_size", 24)
	_btn_buy_club_tokens.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_btn_buy_club_tokens.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_btn_buy_club_tokens.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	_btn_buy_club_tokens.add_theme_color_override("font_outline_color", Color(1.0, 0.80, 0.16, 0.95))
	_btn_buy_club_tokens.add_theme_color_override("font_shadow_color", Color(1.0, 0.80, 0.16, 1.0))
	_btn_buy_club_tokens.add_theme_constant_override("outline_size", 3)
	_btn_buy_club_tokens.add_theme_constant_override("shadow_offset_x", 0)
	_btn_buy_club_tokens.add_theme_constant_override("shadow_offset_y", 0)
	_btn_buy_club_tokens.add_theme_constant_override("shadow_outline_size", 16)
	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = Color(0.08, 0.62, 0.22, 1.0)
	buy_style.border_color = Color(0.45, 1.0, 0.55, 0.95)
	buy_style.border_width_left = 2
	buy_style.border_width_top = 2
	buy_style.border_width_right = 2
	buy_style.border_width_bottom = 4
	buy_style.corner_radius_top_left = 12
	buy_style.corner_radius_top_right = 12
	buy_style.corner_radius_bottom_left = 12
	buy_style.corner_radius_bottom_right = 12
	buy_style.content_margin_right = 24
	var buy_hover := buy_style.duplicate() as StyleBoxFlat
	buy_hover.bg_color = Color(0.10, 0.72, 0.28, 1.0)
	var buy_pressed := buy_style.duplicate() as StyleBoxFlat
	buy_pressed.bg_color = Color(0.04, 0.44, 0.15, 1.0)
	_btn_buy_club_tokens.add_theme_stylebox_override("normal", buy_style)
	_btn_buy_club_tokens.add_theme_stylebox_override("hover", buy_hover)
	_btn_buy_club_tokens.add_theme_stylebox_override("pressed", buy_pressed)
	_btn_buy_club_tokens.pressed.connect(_show_existing_token_packs)
	if ResourceLoader.exists(TOKEN_ICON_PATH):
		_btn_buy_club_tokens.icon = load(TOKEN_ICON_PATH) as Texture2D
		_btn_buy_club_tokens.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_btn_buy_club_tokens.expand_icon = true
		_btn_buy_club_tokens.add_theme_constant_override("icon_max_width", 44)
		_btn_buy_club_tokens.add_theme_constant_override("h_separation", 8)
	root.add_child(_btn_buy_club_tokens)


func _show_existing_token_packs() -> void:
	if Packages == null:
		return
	_is_token_purchase_screen = true
	var ui := get_node_or_null("UI") as Control
	if ui != null:
		var info_root := ui.get_node_or_null("ClubTokensInfoRoot")
		if info_root != null:
			info_root.visible = false
		var balance_card := ui.get_node_or_null("ClubTokensBalanceCard")
		if balance_card != null:
			balance_card.visible = false
	if LblStatus != null:
		LblStatus.visible = true
	Packages.visible = true
	Packages.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var package_width := 300.0
	var package_left := (get_viewport_rect().size.x - package_width) * 0.5
	Packages.offset_left = package_left
	Packages.offset_top = 170.0
	Packages.offset_right = package_left + package_width
	Packages.offset_bottom = 500.0
	Packages.alignment = BoxContainer.ALIGNMENT_CENTER
	Packages.add_theme_constant_override("separation", 58)
	if _btn_buy_club_tokens != null and is_instance_valid(_btn_buy_club_tokens):
		_btn_buy_club_tokens.visible = false

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_WINDOW_FOCUS_IN:
		return
	if not _payment_waiting_for_refresh or _payment_refresh_request_in_flight or _return_refresh_done or _payment_confirmation_shown:
		return
	_return_refresh_done = true
	call_deferred("_request_payment_cloud_load")


func _on_back() -> void:
	if _is_token_purchase_screen:
		_is_token_purchase_screen = false
		_pending_tokens_amount = 0
		if PopupConfirm != null:
			PopupConfirm.visible = false
		if Packages != null:
			Packages.visible = false
		if LblStatus != null:
			LblStatus.visible = false
		var ui := get_node_or_null("UI") as Control
		if ui != null:
			var info_root := ui.get_node_or_null("ClubTokensInfoRoot")
			if info_root != null:
				info_root.visible = true
			var balance_card := ui.get_node_or_null("ClubTokensBalanceCard")
			if balance_card != null:
				balance_card.visible = true
		if _btn_buy_club_tokens != null and is_instance_valid(_btn_buy_club_tokens):
			_btn_buy_club_tokens.visible = true
		return
	if _club_tokens_active_section == "club_identity" or _club_tokens_active_section == "home_arena":
		_club_tokens_active_section = "overview"
		_build_club_tokens_info_screen()
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://scenes/Menu.tscn")

func _set_status(txt: String) -> void:
	if LblStatus != null:
		LblStatus.text = txt
	print("[SHOP][DEBUG] ", txt)

func _on_pkg_100() -> void:
	_open_purchase_confirm(25)

func _on_pkg_300() -> void:
	_open_purchase_confirm(75)

func _on_confirm_purchase() -> void:
	if _payment_confirmation_shown:
		_pending_tokens_amount = 0
		_restore_purchase_popup_layout()
		if PopupConfirm != null:
			PopupConfirm.visible = false
		if LblStatus != null:
			LblStatus.visible = false
		_build_club_tokens_info_screen()
		_reset_payment_attempt_state()
		return

	if _payment_waiting_for_refresh:
		_request_payment_cloud_load()
		return

	if _pending_checkout_url.strip_edges() != "":
		var checkout_url := _pending_checkout_url.strip_edges()
		print("[STRIPE_UX] OPEN_CHECKOUT_URL_CALL")
		var checkout_opened := _open_checkout_url(checkout_url)
		print("[STRIPE_UX] OPEN_CHECKOUT_URL_RESULT=", str(checkout_opened).to_lower())
		if not checkout_opened:
			_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))
			return
		_pending_checkout_url = ""
		_show_payment_pending_state()
		return

	if _checkout_session_request_in_flight or _checkout_auth_request_in_flight:
		return

	if _pending_tokens_amount <= 0:
		_set_status(_club_tokens_tr("club_tokens.stripe.no_pending_pack", "No pending package"))
		if PopupConfirm != null:
			PopupConfirm.visible = false
		return

	var pack_id := str(TOKEN_STORE_PACK_IDS.get(_pending_tokens_amount, "")).strip_edges()
	if pack_id == "":
		_set_status(_club_tokens_tr("club_tokens.stripe.unknown_pack", "Unknown token package"))
		return

	var career_id := _active_career_id()
	if career_id == "":
		_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))
		print("[STRIPE_UX] CHECKOUT_SKIP missing active career_id")
		return

	var puuid := str(Session.profile_uuid).strip_edges()
	if puuid == "":
		_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))
		print("[STRIPE_UX] CHECKOUT_SKIP missing profile_uuid")
		return

	var access := str(Session.access_token).strip_edges()
	print("[STRIPE_UX] BUY_CLICK pack_id=", pack_id, " career_id=", career_id)
	print("[STRIPE_UX] AUTH_PRESENT=", str(access.length() >= 20).to_lower())
	if access.length() < 20:
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))
		return

	_expected_payment_tokens = _pending_tokens_amount
	_pending_checkout_career_id = career_id
	_tokens_before_payment = _get_current_token_balance()
	_checkout_session_request_in_flight = true
	if BtnConfirm != null:
		BtnConfirm.disabled = true
	_set_status(_club_tokens_tr("club_tokens.stripe.creating_session", "Preparing secure payment..."))

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_checkout_session_completed(http, result, response_code, body)
	)

	var headers := PackedStringArray([
		"Authorization: Bearer " + access,
		"Accept: application/json",
		"Content-Type: application/json"
	])
	var body_txt := JSON.stringify({
		"profile_uuid": puuid,
		"career_id": career_id,
		"pack_id": pack_id
	})
	print("[STRIPE_UX] REQUEST_START endpoint=", API_BASE + CHECKOUT_SESSION_PATH)
	var err := http.request(API_BASE + CHECKOUT_SESSION_PATH, headers, HTTPClient.METHOD_POST, body_txt)
	print("[STRIPE_UX] REQUEST_CALL_RESULT=", err)
	if err != OK:
		_checkout_session_request_in_flight = false
		_pending_checkout_career_id = ""
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		http.queue_free()
		_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))



func _is_checkout_invalid_token_response(result: int, response_code: int, raw_body: String) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and response_code == 401 and raw_body.find("INVALID_TOKEN") != -1


func _request_checkout_auth_refresh_or_guest() -> void:
	if _checkout_auth_request_in_flight:
		return
	var refresh := str(Session.refresh_token).strip_edges()
	if refresh.length() < 10:
		_checkout_auth_retry_done = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))
		return

	_checkout_auth_request_in_flight = true
	if BtnConfirm != null:
		BtnConfirm.disabled = true
	_set_status(_club_tokens_tr("club_tokens.stripe.refreshing_session", "Refreshing secure session..."))

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_checkout_auth_completed(http, result, response_code, body)
	)

	var body_txt := JSON.stringify({"refresh_token": refresh})
	print("[STRIPE_UX] AUTH_RETRY_START refresh=true")
	var err := http.request(API_BASE + AUTH_REFRESH_PATH, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body_txt)
	if err != OK:
		_checkout_auth_request_in_flight = false
		_checkout_auth_retry_done = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		http.queue_free()
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))


func _on_checkout_auth_completed(http: HTTPRequest, result: int, response_code: int, body: PackedByteArray) -> void:
	_checkout_auth_request_in_flight = false
	if is_instance_valid(http):
		http.queue_free()
	var raw_body := body.get_string_from_utf8()
	print("[STRIPE_UX] AUTH_RETRY_RESULT=", result, " code=", response_code)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_checkout_auth_retry_done = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))
		return

	var parsed: Variant = JSON.parse_string(raw_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		_checkout_auth_retry_done = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))
		return

	var data: Dictionary = parsed as Dictionary
	var access := str(data.get("access_token", "")).strip_edges()
	if access.length() < 20:
		_checkout_auth_retry_done = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))
		return

	var refresh := str(data.get("refresh_token", "")).strip_edges()
	if refresh == "":
		refresh = str(Session.refresh_token).strip_edges()
	var token_type := str(data.get("token_type", "Bearer")).strip_edges()
	Session.set_tokens(access, refresh, token_type)
	print("[STRIPE_UX] AUTH_RETRY_OK access_len=", Session.access_token.length())
	call_deferred("_on_confirm_purchase")


func _on_checkout_session_completed(http: HTTPRequest, result: int, response_code: int, body: PackedByteArray) -> void:
	print("[STRIPE_UX] CALLBACK_ENTERED")
	print("[STRIPE_UX] HTTP_RESULT=", result)
	print("[STRIPE_UX] HTTP_CODE=", response_code)
	print("[STRIPE_UX] BODY_SIZE=", body.size())
	var raw_body := body.get_string_from_utf8()
	print("[STRIPE_UX] RAW_BODY=", raw_body)
	_checkout_session_request_in_flight = false
	if is_instance_valid(http):
		http.queue_free()
	if BtnConfirm != null:
		BtnConfirm.disabled = false

	if _is_checkout_invalid_token_response(result, response_code, raw_body) and not _checkout_auth_retry_done:
		_checkout_auth_retry_done = true
		_request_checkout_auth_refresh_or_guest()
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_pending_checkout_career_id = ""
		if BtnConfirm != null:
			BtnConfirm.text = _format_buy_payment_button_text(_pending_tokens_amount)
			_restore_confirm_button_layout()
		_set_status(_club_tokens_tr("club_tokens.stripe.session_failed", "Payment request failed. Please try again."))
		return

	var parsed: Variant = JSON.parse_string(raw_body)
	var json_parse_ok := typeof(parsed) == TYPE_DICTIONARY
	print("[STRIPE_UX] JSON_PARSE_OK=", str(json_parse_ok).to_lower())
	print("[STRIPE_UX] JSON_TYPE=", type_string(typeof(parsed)))
	if not json_parse_ok:
		_pending_checkout_career_id = ""
		_set_status(_club_tokens_tr("club_tokens.stripe.response_invalid", "Payment response invalid. Please try again."))
		return

	var data: Dictionary = parsed as Dictionary
	var checkout_url := str(data.get("url", "")).strip_edges()
	print("[STRIPE_UX] RESPONSE_OK=", str(bool(data.get("ok", false))).to_lower())
	print("[STRIPE_UX] URL_PRESENT=", str(checkout_url != "").to_lower())
	print("[STRIPE_UX] URL_LENGTH=", checkout_url.length())
	print("[STRIPE_UX] URL_PREFIX=", checkout_url.substr(0, 32))
	if checkout_url == "":
		_pending_checkout_career_id = ""
		_set_status(_club_tokens_tr("club_tokens.stripe.url_missing", "Payment URL missing. Please try again."))
		return

	_pending_checkout_url = checkout_url
	_set_payment_ready_popup_layout()
	if BtnConfirm != null:
		BtnConfirm.text = _club_tokens_tr("club_tokens.stripe.open_secure_payment", "Open secure payment")
		BtnConfirm.disabled = false
		_center_open_payment_button_on_screen()
	_set_status(_club_tokens_tr("club_tokens.stripe.open_blocked", "Secure payment is ready. Tap Open secure payment."))


func _open_checkout_url(checkout_url: String) -> bool:
	if OS.has_feature("web"):
		var js := """
(function(url) {
	try {
		window.open(url, '_blank');
		return 'OPEN_CALLED';
	} catch (e) { return 'JS_EXCEPTION:' + (e && e.message ? e.message : String(e)); }
})(%s);
""" % JSON.stringify(checkout_url)
		var js_result := str(JavaScriptBridge.eval(js, true))
		print("[STRIPE_UX] CHECKOUT_OPEN_JS_RESULT=", js_result)
		return js_result == "OPEN_CALLED"
	var err := OS.shell_open(checkout_url)
	print("[STRIPE_UX] DESKTOP_OPEN_RESULT=", err)
	return err == OK

func _request_payment_cloud_load() -> void:
	if _payment_refresh_request_in_flight or _payment_confirmation_shown:
		return
	var access := str(Session.access_token).strip_edges()
	if access.length() < 20:
		_set_status(_club_tokens_tr("club_tokens.stripe.login_required", "Login required"))
		return
	var puuid := str(Session.profile_uuid).strip_edges()
	if puuid == "":
		_set_status(_club_tokens_tr("club_tokens.stripe.refresh_failed", "Payment refresh failed. Please try again."))
		return
	var career_id := str(_pending_checkout_career_id).strip_edges()
	if career_id == "":
		career_id = _active_career_id()
	if career_id == "":
		print("[STRIPE_UX] PAYMENT_REFRESH_SKIP missing active career_id")
		_set_status(_club_tokens_tr("club_tokens.stripe.refresh_failed", "Payment refresh failed. Please try again."))
		return
	_pending_checkout_career_id = career_id

	_payment_refresh_request_in_flight = true
	if BtnConfirm != null:
		BtnConfirm.disabled = true
	_set_status("Synchronizing your Club Tokens...")

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_payment_cloud_load_completed(http, result, response_code, body)
	)
	var headers := PackedStringArray([
		"Authorization: Bearer " + access,
		"Accept: application/json"
	])
	var url := API_BASE + CLOUD_LOAD_PATH + "?profile_uuid=%s&career_id=%s" % [puuid.uri_encode(), career_id.uri_encode()]
	var err := http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_payment_refresh_request_in_flight = false
		if BtnConfirm != null:
			BtnConfirm.disabled = false
		http.queue_free()
		_set_status(_club_tokens_tr("club_tokens.stripe.refresh_failed", "Payment refresh failed. Please try again."))


func _on_payment_cloud_load_completed(http: HTTPRequest, result: int, response_code: int, body: PackedByteArray) -> void:
	_payment_refresh_request_in_flight = false
	if is_instance_valid(http):
		http.queue_free()
	if BtnConfirm != null:
		BtnConfirm.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))
		return
	var data: Dictionary = parsed as Dictionary
	if not _payment_response_matches_pending_career(data):
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))
		return
	if bool(data.get("found", true)) == false or not data.has("blob") or typeof(data.get("blob")) != TYPE_DICTIONARY:
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))
		return

	var server_blob: Dictionary = data.get("blob") as Dictionary
	if not server_blob.has("wallet") or typeof(server_blob.get("wallet")) != TYPE_DICTIONARY:
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))
		return
	var server_wallet: Dictionary = server_blob.get("wallet") as Dictionary
	var server_tokens: int = int(server_wallet.get("tokens", _get_current_token_balance()))
	var local_save: Dictionary = PlayerLife.load_savegame()
	if typeof(local_save) != TYPE_DICTIONARY:
		local_save = {}
	if not local_save.has("wallet") or typeof(local_save.get("wallet")) != TYPE_DICTIONARY:
		local_save["wallet"] = {}
	var local_wallet: Dictionary = local_save.get("wallet") as Dictionary
	local_wallet["tokens"] = server_tokens
	local_save["wallet"] = local_wallet
	PlayerLife.write_savegame(local_save)
	print("[CLOUD][PAYMENT] wallet.tokens applied")
	if Packages != null:
		Packages.visible = false
	var ui := get_node_or_null("UI") as Control
	if ui != null:
		var info_root := ui.get_node_or_null("ClubTokensInfoRoot")
		if info_root != null:
			info_root.visible = false
		var balance_card := ui.get_node_or_null("ClubTokensBalanceCard")
		if balance_card != null:
			balance_card.visible = false
	if _btn_buy_club_tokens != null and is_instance_valid(_btn_buy_club_tokens):
		_btn_buy_club_tokens.visible = false
	_is_token_purchase_screen = false

	var after_tokens := server_tokens
	var added := after_tokens - _tokens_before_payment
	if added > 0 and _expected_payment_tokens > 0 and added != _expected_payment_tokens:
		added = _expected_payment_tokens
	if added > 0:
		_payment_confirmation_shown = true
		_pending_checkout_career_id = ""
		_payment_waiting_for_refresh = false
		_return_refresh_done = true
		_set_payment_confirmed_content(added, after_tokens)
		_set_close_payment_button()
		if PopupConfirm != null:
			PopupConfirm.visible = true
			PopupConfirm.z_index = 500
			PopupConfirm.move_to_front()
		if LblStatus != null:
			LblStatus.visible = false
	else:
		_set_payment_opened_content()
		_set_refresh_payment_button()
		_set_status(_club_tokens_tr("club_tokens.stripe.still_confirming", "Payment is still being confirmed. This usually takes only a few seconds."))


func _on_cancel_purchase() -> void:
	_pending_tokens_amount = 0
	_pending_checkout_career_id = ""
	_reset_payment_attempt_state()
	_restore_purchase_popup_layout()
	if BtnConfirm != null:
		BtnConfirm.text = _club_tokens_tr("club_tokens.store.continue", "Continue")
		BtnConfirm.disabled = false
		_restore_confirm_button_layout()
	if PopupConfirm != null:
		PopupConfirm.visible = false
	_set_status(_club_tokens_tr("club_tokens.stripe.cancelled", "Payment cancelled"))


func _on_pkg_800() -> void:
	_open_purchase_confirm(150)
