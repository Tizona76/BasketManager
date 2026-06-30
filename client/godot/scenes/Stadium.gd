extends Control


const PlayerLife := preload("res://scripts/PlayerLife.gd")

# BM_HOME_TWO_BUTTONS_MODE_V1
# false = accueil actuel inchangé : Play Instantly / Resume / Sign Up.
# true = futur accueil simplifié : Play Instantly / My Team.
const BM_HOME_TWO_BUTTONS_MODE := false

# --- BM: stadium screen patch (minimal) ---
var _bm_stadium_patch_v1 := true

@onready var BtnRetour: Button = get_node_or_null("BtnRetour") as Button
@onready var Menu: CanvasItem = get_node_or_null("Menu") as CanvasItem
@onready var BtnConfirmer: CanvasItem = get_node_or_null("BtnConfirmer") as CanvasItem
@onready var LangBar: CanvasItem = get_node_or_null("LangBar") as CanvasItem
# --- /BM ---

func _bm_setup_stadium_screen() -> void:
	# Cache l'UI "Accueil" (drapeaux + reprendre/créer + confirmer)
	if Menu != null:
		Menu.visible = false
	if BtnConfirmer != null:
		BtnConfirmer.visible = false
	if LangBar != null:
		LangBar.visible = false

		# Bouton Retour (traduction si dispo, sinon fallback)
		if BtnRetour != null:
			BtnRetour.visible = true
			BtnRetour.disabled = false
			BtnRetour.text = tr("btn.back") if tr("btn.back") != "btn.back" else "Retour"
			BtnRetour.add_theme_font_size_override("font_size", 24 if _bm_is_mobile_layout() else 22)
			if not BtnRetour.pressed.is_connected(_on_btn_retour):
				BtnRetour.pressed.connect(_on_btn_retour)

func _on_btn_retour() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuSaison.tscn")

	# disabled auto change_scene_to_file("res://scenes/MenuSaison.tscn")
# ou extends ce que tu veux, mais SANS super._ready() si pas de parent custom

signal action_requested(action: String)

@onready var btn_reprendre: Button = $Menu/BtnReprendre
@onready var btn_inscrire: Button = $Menu/BtnInscrire
@onready var btn_play_instantly: Button = $BtnPlayInstantly
@onready var lang_bar: HBoxContainer = $LangBar
@onready var popup_stadium_intro: Panel = get_node_or_null("Overlays/PopupStadiumIntro") as Panel
@onready var btn_close_stadium_intro: Button = get_node_or_null("Overlays/PopupStadiumIntro/BtnCloseStadiumIntro") as Button
@onready var lbl_stadium_intro: RichTextLabel = get_node_or_null("Overlays/PopupStadiumIntro/LblStadiumIntro") as RichTextLabel

const FLAG_SIZE := Vector2(56, 38)

const FLAG_TO_LOCALE := {
	"BtnLangFR": "fr",
	"BtnLangEN": "en",
	"BtnLangES": "es",
	"BtnLangIT": "it",
	"BtnLangPT": "pt",
}

const LOCALE_LABEL := {
	"fr": "Français",
	"en": "English",
	"es": "Español",
	"it": "Italiano",
	"pt": "Português",
}


func _bm_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	return OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0

func _make_play_btn_style(bg: Color, border: Color, shadow_a: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, shadow_a)
	sb.shadow_size = 5
	return sb

func _bm_make_neon_entry_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_bottom = bottom_w
	sb.border_color = glow
	sb.shadow_color = Color(glow.r, glow.g, glow.b, 0.34)
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _bm_apply_neon_entry_button(btn: Button, primary: bool = false) -> void:
	if btn == null:
		return

	var bg := Color(0.03, 0.16, 0.38, 0.98)
	var glow := Color(1.0, 0.05, 0.06, 0.92)
	var normal := _bm_make_neon_entry_style(bg, glow, 4, 8)
	var hover := _bm_make_neon_entry_style(Color(0.05, 0.24, 0.55, 0.98), Color(1.0, 0.12, 0.12, 1.0), 6, 14)
	var pressed := _bm_make_neon_entry_style(Color(0.02, 0.11, 0.28, 1.0), Color(0.85, 0.02, 0.03, 1.0), 5, 6)
	var disabled := _bm_make_neon_entry_style(Color(0.08, 0.08, 0.09, 0.70), Color(0.45, 0.08, 0.08, 0.55), 3, 3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	btn.add_theme_font_size_override("font_size", 26 if primary else 22)
	btn.custom_minimum_size = Vector2(330, 68) if primary else Vector2(260, 72)


func _style_play_instantly_button() -> void:
	_bm_apply_neon_entry_button(btn_play_instantly, true)
	_bm_apply_neon_entry_button(btn_reprendre, false)
	_bm_apply_neon_entry_button(btn_inscrire, false)
	if _bm_is_mobile_layout():
		if btn_play_instantly != null:
			btn_play_instantly.custom_minimum_size = Vector2(413, 85)
			btn_play_instantly.add_theme_font_size_override("font_size", 33)
		if btn_reprendre != null:
			btn_reprendre.custom_minimum_size = Vector2(325, 90)
			btn_reprendre.add_theme_font_size_override("font_size", 28)
		if btn_inscrire != null:
			btn_inscrire.custom_minimum_size = Vector2(325, 90)
			btn_inscrire.add_theme_font_size_override("font_size", 28)



func _stadium_apply_i18n_action_buttons() -> void:
	var _map := {
		"stadium_btn_ticketing": [
			"UI/BtnBilletterie", "UI/BtnTicketing", "BtnBilletterie", "BtnTicketing"
		],
		"stadium_btn_shop": [
			"UI/BtnBoutique", "UI/BtnShop", "BtnBoutique", "BtnShop"
		],
		"stadium_btn_upgrade": [
			"UI/BtnEvolutionStade", "UI/BtnUpgrade", "BtnEvolutionStade", "BtnUpgrade"
		]
	}
	for _key in _map.keys():
		for _path in _map[_key]:
			var _n := get_node_or_null(_path)
			if _n != null and _n is Button:
				(_n as Button).text = tr(_key)
				break

func _ready() -> void:
	_stadium_apply_i18n_action_buttons()
	call_deferred("_ensure_ticketing_confirm_button")
	# FIX: évite que le BG demi-terrain de Menu (BG_TEST) reste visible derrière Stadium
	var menu_node := get_tree().root.get_node_or_null("Main/ScreenRoot/Menu")
	if menu_node != null and menu_node is CanvasItem:
		(menu_node as CanvasItem).visible = false
	_bm_hide_underlay_halfcourt()
	_apply_i18n()
	_style_play_instantly_button()

	# BM_ENTRY_SINGLE_PLAY_ONLY_V1
	if btn_reprendre != null:
		btn_reprendre.visible = false
		btn_reprendre.disabled = true
		btn_reprendre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_inscrire != null:
		btn_inscrire.visible = false
		btn_inscrire.disabled = true
		btn_inscrire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_play_instantly != null:
		btn_play_instantly.visible = true
		btn_play_instantly.disabled = false

	if btn_reprendre != null:
		if BM_HOME_TWO_BUTTONS_MODE:
			btn_reprendre.pressed.connect(_bm_my_team_pressed)
		else:
			btn_reprendre.pressed.connect(func(): emit_signal("action_requested", "resume"))
	if btn_inscrire != null:
		btn_inscrire.pressed.connect(func(): emit_signal("action_requested", "signup"))
	if btn_play_instantly != null:
		btn_play_instantly.pressed.connect(func(): emit_signal("action_requested", "play_instantly"))

	_bind_flag_clicks()

	call_deferred("_apply_flags_size")
	if lang_bar != null and not lang_bar.resized.is_connected(_on_langbar_resized):
		lang_bar.resized.connect(_on_langbar_resized)

	_ensure_entry_button_hover_tooltip()
	_bind_entry_button_hover_tooltips()

# BM_MY_TEAM_ROUTING_HELPER_V1
# Non utilisé tant que BM_HOME_TWO_BUTTONS_MODE reste false.

func _bm_has_real_team_name() -> bool:
	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	return str(d.get("team_name", "")).strip_edges() != ""


func _bm_my_team_pressed() -> void:
	if _bm_has_real_team_name():
		emit_signal("action_requested", "resume")
	else:
		emit_signal("action_requested", "signup")


func _bm_my_team_button_text() -> String:
	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) == TYPE_DICTIONARY:
		var tn := str(d.get("team_name", "")).strip_edges()
		if tn != "":
			return tn
	return tr("STADIUM_CREATE_MY_TEAM")


func _bm_apply_home_two_buttons_mode() -> void:
	if not BM_HOME_TWO_BUTTONS_MODE:
		return

	if btn_reprendre != null:
		btn_reprendre.text = _bm_my_team_button_text()
		btn_reprendre.tooltip_text = tr("menu.resume_game.tooltip")

	if btn_inscrire != null:
		btn_inscrire.visible = false
		btn_inscrire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_inscrire.disabled = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_i18n()

func _apply_i18n() -> void:
	if btn_reprendre != null:
		btn_reprendre.text = tr("STADIUM_RESUME")
		btn_reprendre.tooltip_text = tr("menu.resume_game.tooltip")
	if btn_inscrire != null:
		btn_inscrire.text = tr("STADIUM_SIGNUP")
		btn_inscrire.tooltip_text = tr("menu.create_team.tooltip")
	if btn_play_instantly != null:
		btn_play_instantly.text = "Play instantly"
		btn_play_instantly.tooltip_text = tr("menu.play_instantly.tooltip")
	_bm_apply_home_two_buttons_mode()
	_apply_flag_tooltips()
	_update_entry_button_hover_tooltips()

var _entry_hover_tooltip: PanelContainer = null
var _entry_hover_tooltip_label: Label = null

func _ensure_entry_button_hover_tooltip() -> void:
	if _entry_hover_tooltip != null and is_instance_valid(_entry_hover_tooltip):
		return

	_entry_hover_tooltip = PanelContainer.new()
	_entry_hover_tooltip.name = "EntryHoverTooltip"
	_entry_hover_tooltip.visible = false
	_entry_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_hover_tooltip.z_index = 50
	add_child(_entry_hover_tooltip)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.18, 0.96)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.55, 0.95, 0.95)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_entry_hover_tooltip.add_theme_stylebox_override("panel", sb)

	_entry_hover_tooltip_label = Label.new()
	_entry_hover_tooltip_label.name = "EntryHoverTooltipLabel"
	_entry_hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_hover_tooltip_label.custom_minimum_size = Vector2(420, 0)
	_entry_hover_tooltip_label.add_theme_font_size_override("font_size", 24)
	_entry_hover_tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_entry_hover_tooltip.add_child(_entry_hover_tooltip_label)

func _show_entry_button_hover_tooltip(btn: Control, txt: String, mobile_extra_x: float = 0.0) -> void:
	_ensure_entry_button_hover_tooltip()
	if _entry_hover_tooltip == null or _entry_hover_tooltip_label == null or btn == null:
		return
	_entry_hover_tooltip_label.text = txt
	_entry_hover_tooltip.visible = true
	await get_tree().process_frame
	var mobile_offset := mobile_extra_x if _bm_is_mobile_layout() else 0.0
	var pos := btn.global_position + Vector2(btn.size.x + 16.0 + mobile_offset, (btn.size.y * 0.5) - (_entry_hover_tooltip.size.y * 0.5))
	_entry_hover_tooltip.global_position = pos

func _hide_entry_button_hover_tooltip() -> void:
	if _entry_hover_tooltip != null:
		_entry_hover_tooltip.visible = false

func _bind_entry_button_hover_tooltips() -> void:
	if btn_reprendre != null and not btn_reprendre.mouse_entered.is_connected(_on_btn_reprendre_mouse_entered):
		btn_reprendre.mouse_entered.connect(_on_btn_reprendre_mouse_entered)
		btn_reprendre.mouse_exited.connect(_hide_entry_button_hover_tooltip)
	if btn_inscrire != null and not btn_inscrire.mouse_entered.is_connected(_on_btn_inscrire_mouse_entered):
		btn_inscrire.mouse_entered.connect(_on_btn_inscrire_mouse_entered)
		btn_inscrire.mouse_exited.connect(_hide_entry_button_hover_tooltip)
	if btn_play_instantly != null and not btn_play_instantly.mouse_entered.is_connected(_on_btn_play_instantly_mouse_entered):
		btn_play_instantly.mouse_entered.connect(_on_btn_play_instantly_mouse_entered)
		btn_play_instantly.mouse_exited.connect(_hide_entry_button_hover_tooltip)

func _update_entry_button_hover_tooltips() -> void:
	if btn_reprendre != null:
		btn_reprendre.tooltip_text = ""
	if btn_inscrire != null:
		btn_inscrire.tooltip_text = ""
	if btn_play_instantly != null:
		btn_play_instantly.tooltip_text = ""

func _on_btn_reprendre_mouse_entered() -> void:
	_show_entry_button_hover_tooltip(btn_reprendre, tr("menu.resume_game.tooltip"))

func _on_btn_inscrire_mouse_entered() -> void:
	_ensure_entry_button_hover_tooltip()
	if _entry_hover_tooltip == null or _entry_hover_tooltip_label == null or btn_inscrire == null:
		return
	_entry_hover_tooltip_label.text = tr("menu.create_team.tooltip")
	_entry_hover_tooltip.visible = true
	await get_tree().process_frame
	var pos := btn_inscrire.global_position + Vector2(0.0, -_entry_hover_tooltip.size.y - 12.0)
	_entry_hover_tooltip.global_position = pos

func _on_btn_play_instantly_mouse_entered() -> void:
	_show_entry_button_hover_tooltip(btn_play_instantly, tr("menu.play_instantly.tooltip"), 180.0)

func _bind_flag_clicks() -> void:
	if lang_bar == null:
		return

	for child in lang_bar.get_children():
		if not (child is BaseButton):
			continue

		var b := child as BaseButton
		var loc := str(FLAG_TO_LOCALE.get(b.name, "")).strip_edges()
		if loc == "":
			continue

		# évite double-connect
		if b.pressed.is_connected(_on_flag_pressed):
			b.pressed.disconnect(_on_flag_pressed)

		b.pressed.connect(func(): _on_flag_pressed(loc))

func _on_flag_pressed(locale_code: String) -> void:
	TranslationServer.set_locale(locale_code)
	I18nSvc.apply_all() # ← IMPORTANT


func _apply_flag_tooltips() -> void:
	if lang_bar == null:
		return
	for child in lang_bar.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		var loc := str(FLAG_TO_LOCALE.get(c.name, "")).strip_edges()
		if loc != "":
			c.tooltip_text = str(LOCALE_LABEL.get(loc, loc))

func _on_langbar_resized() -> void:
	_apply_flags_size()

func _apply_flags_size() -> void:
	if lang_bar == null:
		return

	for c in lang_bar.get_children():
		if not (c is Control):
			continue
		var ctrl := c as Control

		ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ctrl.size_flags_stretch_ratio = 0.0
		ctrl.custom_minimum_size = FLAG_SIZE
		ctrl.size = FLAG_SIZE

		if ctrl is TextureButton:
			var tb := ctrl as TextureButton
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.mouse_filter = Control.MOUSE_FILTER_STOP
		elif ctrl is Button:
			var b := ctrl as Button
			b.text = ""
			b.mouse_filter = Control.MOUSE_FILTER_STOP



# ------------------------------------------------------------
# UNDERLAY CLEANUP (Stadium only)
# Cache le "demi-terrain" (ou tout CanvasItem persistant) qui resterait visible sous l'écran drapeaux.
# Ne touche PAS aux boutons/drapeaux. Restaure à la sortie de Stadium.
# ------------------------------------------------------------
var _bm_hidden_underlays: Array[CanvasItem] = []

func _bm_hide_underlay_halfcourt() -> void:
	_bm_hidden_underlays.clear()

	# On limite la recherche à Main/ScreenRoot pour éviter tout effet de bord.
	var root := get_tree().root
	var main := root.get_node_or_null("Main")
	if main == null:
		return

	# Cibles probables (noms fréquents). Si un de ces nodes existe et est visible => on le masque.
	var candidate_paths := [
		"ScreenRoot/DemiTerrain",
		"ScreenRoot/HalfCourt",
		"ScreenRoot/BG_TEST",
		"ScreenRoot/DemiTerrainBG",
		"ScreenRoot/UI/DemiTerrain",
		"ScreenRoot/UI/HalfCourt",
		"ScreenRoot/UI/BG_TEST",
	]

	for rel in candidate_paths:
		var n := main.get_node_or_null(rel)
		if n != null and (n is CanvasItem):
			var ci := n as CanvasItem
			if ci.visible:
				ci.visible = false
				_bm_hidden_underlays.append(ci)

func _exit_tree() -> void:
	# Restaure ce qu'on a caché uniquement pour Stadium
	for ci in _bm_hidden_underlays:
		if ci != null:
			ci.visible = true
	_bm_hidden_underlays.clear()


# BM_TICKETING_CONFIRM_V2 -----------------------------------------------------
func _ensure_ticketing_confirm_button() -> void:
	var panel := find_child("PanelTicketing", true, false)
	if panel == null:
		return

	var vbox := panel.find_child("VBox", true, false)
	if vbox == null:
		return

	var btn := vbox.get_node_or_null("BtnConfirmTicketing")
	if btn == null:
		btn = Button.new()
		btn.name = "BtnConfirmTicketing"
		btn.text = "Confirmer"
		btn.custom_minimum_size = Vector2(0, 46)
		vbox.add_child(btn)

	if not btn.pressed.is_connected(_on_confirm_ticketing_pressed):
		btn.pressed.connect(_on_confirm_ticketing_pressed)

func _le_int(n: Node) -> int:
	if n == null:
		return 0
	var t := ""
	if n.has_method("get_text"):
		t = str(n.call("get_text"))
	else:
		t = str(n.get("text"))
	t = t.strip_edges()
	return int(t) if t.is_valid_int() else 0

func _on_confirm_ticketing_pressed() -> void:
	var save := PlayerLife.load_savegame()
	PlayerLife.ensure_finance_schema(save)

	var price_a := find_child("PriceA", true, false)
	var price_b := find_child("PriceB", true, false)
	var price_c := find_child("PriceC", true, false)
	var seats_a := find_child("SeatsA", true, false)
	var seats_b := find_child("SeatsB", true, false)
	var seats_c := find_child("SeatsC", true, false)

	var t := {}
	t["price_a"] = max(0, _le_int(price_a))
	t["price_b"] = max(0, _le_int(price_b))
	t["price_c"] = max(0, _le_int(price_c))
	t["seats_a"] = max(0, _le_int(seats_a))
	t["seats_b"] = max(0, _le_int(seats_b))
	t["seats_c"] = max(0, _le_int(seats_c))

	save["ticketing"] = t
	PlayerLife.write_savegame(save)
	print("[STADIUM][TICKETING] confirmed -> ", t)
# ---------------------------------------------------------------------------

func _show_stadium_intro_popup() -> void:
	if popup_stadium_intro != null:
		popup_stadium_intro.visible = true
		popup_stadium_intro.mouse_filter = Control.MOUSE_FILTER_STOP

	if lbl_stadium_intro != null:
		lbl_stadium_intro.bbcode_enabled = true
		var _title := tr("stadium_intro_title")
		if _title == "" or _title == "stadium_intro_title":
			_title = "Stadium"

		var _capacity := tr("stadium_intro_capacity")
		if _capacity == "" or _capacity == "stadium_intro_capacity":
			_capacity = ">> Manage your stadium and increase its capacity"

		var _shop := tr("stadium_intro_shop")
		if _shop == "" or _shop == "stadium_intro_shop":
			_shop = ">> Shop: set your prices to generate revenue"

		var _ticketing := tr("stadium_intro_ticketing")
		if _ticketing == "" or _ticketing == "stadium_intro_ticketing":
			_ticketing = ">> Ticketing: adjust prices and seat numbers to optimize your earnings"

		lbl_stadium_intro.text = "[center][font_size=22][b]" + _title + "[/b][/font_size][/center]\n\n" + _capacity + "\n" + _shop + "\n" + _ticketing

	if btn_close_stadium_intro != null:
		btn_close_stadium_intro.text = "OK"
		btn_close_stadium_intro.text = tr("popup_intro_close")
		var _sb_close := StyleBoxFlat.new()
		_sb_close.bg_color = Color(0.20, 0.55, 0.95, 1.0)
		_sb_close.corner_radius_top_left = 12
		_sb_close.corner_radius_top_right = 12
		_sb_close.corner_radius_bottom_left = 12
		_sb_close.corner_radius_bottom_right = 12
		_sb_close.content_margin_left = 16
		_sb_close.content_margin_right = 16
		_sb_close.content_margin_top = 8
		_sb_close.content_margin_bottom = 8
		btn_close_stadium_intro.add_theme_stylebox_override("normal", _sb_close)

		var _sb_close_hover := _sb_close.duplicate()
		_sb_close_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
		btn_close_stadium_intro.add_theme_stylebox_override("hover", _sb_close_hover)

		btn_close_stadium_intro.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if not btn_close_stadium_intro.pressed.is_connected(_on_close_stadium_intro_pressed):
			btn_close_stadium_intro.pressed.connect(_on_close_stadium_intro_pressed)

func _on_close_stadium_intro_pressed() -> void:
	if popup_stadium_intro != null:
		popup_stadium_intro.visible = false
		popup_stadium_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
