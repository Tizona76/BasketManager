extends Control

const PlayerLife := preload("res://scripts/PlayerLife.gd")

const _TEAMNAME_BG_NODE := "__BG_JOUEURS__"
const _TEAMNAME_BG_PATH := "res://assets/images/backgrounds/joueurs.png"

func _ensure_bg_joueurs() -> void:
	# Ajoute un fond "joueurs.png" derrière tout, sans casser l'UI
	if get_node_or_null(_TEAMNAME_BG_NODE) != null:
		return

	var tex := load(_TEAMNAME_BG_PATH)
	if tex == null:
		push_error("[TEAMNAME] missing bg: " + _TEAMNAME_BG_PATH)
		return

	var tr := TextureRect.new()
	tr.name = _TEAMNAME_BG_NODE
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.anchor_left = 0.0
	tr.anchor_top = 0.0
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left = 0.0
	tr.offset_top = 0.0
	tr.offset_right = 0.0
	tr.offset_bottom = 0.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Mets le fond tout en dessous
	# ✅ Si un ColorRect/Panel noir existe déjà (fond par défaut), on le neutralise
	var cr := find_child("ColorRect", true, false)
	if cr != null and cr is ColorRect:
		(cr as ColorRect).color.a = 0.0

	add_child(tr)
	move_child(tr, 0)


signal submit_team_name(team_name: String)
signal back_requested()
signal action_requested(action: String)

@onready var input_team: LineEdit = $Center/Box/WrapInput/InputTeam
@onready var btn_confirm: Button = $Center/Box/BtnConfirmer
@onready var btn_back: Button = get_node_or_null("Center/Box/BtnRetour") as Button
@onready var menu_entry: HBoxContainer = get_node_or_null("Menu") as HBoxContainer
@onready var btn_reprendre_entry: Button = get_node_or_null("Menu/BtnReprendre") as Button
@onready var btn_inscrire_entry: Button = get_node_or_null("Menu/BtnInscrire") as Button
@onready var btn_play_instantly_entry: Button = get_node_or_null("Center/Box/BtnPlayInstantly") as Button
@onready var lang_bar_entry: HBoxContainer = get_node_or_null("LangBar") as HBoxContainer

@onready var lbl_title: Label = get_node_or_null("Center/Box/LblTitle") as Label


var _dlg: AcceptDialog
var _dlg_edit: LineEdit# Si tu as un Label visible “Choisis le nom…”, on le récupère (best effort)
var _entry_hover_tooltip: PanelContainer = null
var _entry_hover_tooltip_label: Label = null
var _flag_hover_tooltip: PanelContainer = null
var _flag_hover_tooltip_label: Label = null
var _teamname_caret_blink_timer: Timer = null
var _teamname_caret_blink_visible := true
var _teamname_popup_caret_blink_timer: Timer = null
var _teamname_popup_caret_blink_visible := true

const FLAG_SIZE := Vector2(58, 44)
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



func _bm_make_create_team_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
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


func _bm_style_create_team_button() -> void:
	if btn_confirm == null:
		return

	var normal := _bm_make_create_team_style(Color(0.03, 0.16, 0.38, 0.98), Color(1.0, 0.05, 0.06, 0.92), 4, 8)
	var hover := _bm_make_create_team_style(Color(0.05, 0.24, 0.55, 0.98), Color(1.0, 0.12, 0.12, 1.0), 6, 14)
	var pressed := _bm_make_create_team_style(Color(0.02, 0.11, 0.28, 1.0), Color(0.85, 0.02, 0.03, 1.0), 5, 6)
	var disabled := _bm_make_create_team_style(Color(0.08, 0.08, 0.09, 0.70), Color(0.45, 0.08, 0.08, 0.55), 3, 3)

	btn_confirm.add_theme_stylebox_override("normal", normal)
	btn_confirm.add_theme_stylebox_override("hover", hover)
	btn_confirm.add_theme_stylebox_override("pressed", pressed)
	btn_confirm.add_theme_stylebox_override("disabled", disabled)
	btn_confirm.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_confirm.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_confirm.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_confirm.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	btn_confirm.add_theme_font_size_override("font_size", 26)
	btn_confirm.custom_minimum_size = Vector2(330, 68)

	if btn_play_instantly_entry != null:
		btn_play_instantly_entry.add_theme_stylebox_override("normal", normal)
		btn_play_instantly_entry.add_theme_stylebox_override("hover", hover)
		btn_play_instantly_entry.add_theme_stylebox_override("pressed", pressed)
		btn_play_instantly_entry.add_theme_stylebox_override("disabled", disabled)
		btn_play_instantly_entry.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_play_instantly_entry.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn_play_instantly_entry.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn_play_instantly_entry.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
		btn_play_instantly_entry.add_theme_font_size_override("font_size", 26)
		btn_play_instantly_entry.custom_minimum_size = Vector2(330, 68)


func _bm_make_back_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10

	# léger dégradé visuel simulé via border bas
	sb.border_width_bottom = bottom_w
	sb.border_color = Color(0.6, 0.0, 0.0, 1.0)

	# glow neutre (gris/noir)
	sb.shadow_color = glow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, 4)

	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _bm_style_back_button() -> void:
	if btn_back == null:
		return

	var normal := _bm_make_back_button_style(Color(0.9, 0.05, 0.05, 1.0), Color(0,0,0,0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.1, 0.1, 1.0), Color(0,0,0,0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.7, 0.02, 0.02, 1.0), Color(0,0,0,0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.4, 0.1, 0.1, 0.6), Color(0,0,0,0.2), 2, 2)

	btn_back.add_theme_stylebox_override("normal", normal)
	btn_back.add_theme_stylebox_override("hover", hover)
	btn_back.add_theme_stylebox_override("pressed", pressed)
	btn_back.add_theme_stylebox_override("disabled", disabled)

	btn_back.add_theme_color_override("font_color", Color(1,1,1,1))
	btn_back.add_theme_color_override("font_hover_color", Color(1,1,1,1))
	btn_back.add_theme_color_override("font_pressed_color", Color(1,1,1,1))
	btn_back.add_theme_color_override("font_disabled_color", Color(1,1,1,0.5))

	btn_back.add_theme_font_size_override("font_size", 22)
	btn_back.custom_minimum_size = Vector2(260, 56)


func _bm_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	return OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0


func _bm_apply_mobile_layout() -> void:
	if not _bm_is_mobile_layout():
		return

	if input_team != null:
		input_team.custom_minimum_size = Vector2(413, 70)
		input_team.add_theme_font_size_override("font_size", 32)

	if btn_confirm != null:
		btn_confirm.custom_minimum_size = Vector2(413, 85)
		btn_confirm.add_theme_font_size_override("font_size", 33)
	if btn_reprendre_entry != null:
		btn_reprendre_entry.custom_minimum_size = Vector2(325, 90)
		btn_reprendre_entry.add_theme_font_size_override("font_size", 28)
	if btn_inscrire_entry != null:
		btn_inscrire_entry.custom_minimum_size = Vector2(325, 90)
		btn_inscrire_entry.add_theme_font_size_override("font_size", 28)
	if btn_play_instantly_entry != null:
		btn_play_instantly_entry.custom_minimum_size = Vector2(413, 85)
		btn_play_instantly_entry.add_theme_font_size_override("font_size", 33)


func _bm_style_teamname_input_focus() -> void:
	if input_team == null:
		return
	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = Color(1, 1, 1, 0.0)
	focus_sb.border_width_left = 0
	focus_sb.border_width_top = 0
	focus_sb.border_width_right = 0
	focus_sb.border_width_bottom = 0
	focus_sb.content_margin_left = 0
	focus_sb.content_margin_right = 0
	focus_sb.content_margin_top = 0
	focus_sb.content_margin_bottom = 0
	input_team.add_theme_stylebox_override("focus", focus_sb)


func _bm_teamname_input_placeholder_text() -> String:
	var ph := tr("teamname.placeholder")
	if ph == "teamname.placeholder":
		ph = "Create team name"
	return ph


func _bm_ensure_teamname_caret_blink_timer() -> void:
	if _teamname_caret_blink_timer != null and is_instance_valid(_teamname_caret_blink_timer):
		return
	_teamname_caret_blink_timer = Timer.new()
	_teamname_caret_blink_timer.wait_time = 0.45
	_teamname_caret_blink_timer.one_shot = false
	_teamname_caret_blink_timer.autostart = false
	add_child(_teamname_caret_blink_timer)
	_teamname_caret_blink_timer.timeout.connect(_bm_teamname_input_caret_blink_tick)


func _bm_start_teamname_input_caret_blink() -> void:
	if input_team == null or input_team.text.strip_edges() != "":
		return
	_bm_ensure_teamname_caret_blink_timer()
	_teamname_caret_blink_visible = true
	input_team.placeholder_text = "_"
	_teamname_caret_blink_timer.start()


func _bm_stop_teamname_input_caret_blink(restore_placeholder: bool) -> void:
	if _teamname_caret_blink_timer != null and is_instance_valid(_teamname_caret_blink_timer):
		_teamname_caret_blink_timer.stop()
	_teamname_caret_blink_visible = true
	if restore_placeholder and input_team != null and input_team.text.strip_edges() == "":
		input_team.placeholder_text = _bm_teamname_input_placeholder_text()


func _bm_teamname_input_caret_blink_tick() -> void:
	if input_team == null or input_team.text.strip_edges() != "" or not input_team.has_focus():
		_bm_stop_teamname_input_caret_blink(false)
		return
	_teamname_caret_blink_visible = not _teamname_caret_blink_visible
	input_team.placeholder_text = "_" if _teamname_caret_blink_visible else ""


func _bm_teamname_input_text_changed(_new_text: String) -> void:
	if input_team == null:
		return
	if input_team.text.strip_edges() == "" and input_team.has_focus():
		_bm_start_teamname_input_caret_blink()
	else:
		_bm_stop_teamname_input_caret_blink(false)


func _bm_ensure_teamname_popup_caret_blink_timer() -> void:
	if _teamname_popup_caret_blink_timer != null and is_instance_valid(_teamname_popup_caret_blink_timer):
		return
	_teamname_popup_caret_blink_timer = Timer.new()
	_teamname_popup_caret_blink_timer.wait_time = 0.45
	_teamname_popup_caret_blink_timer.one_shot = false
	_teamname_popup_caret_blink_timer.autostart = false
	add_child(_teamname_popup_caret_blink_timer)
	_teamname_popup_caret_blink_timer.timeout.connect(_bm_teamname_popup_caret_blink_tick)


func _bm_start_teamname_popup_caret_blink() -> void:
	if _dlg_edit == null or _dlg_edit.text.strip_edges() != "":
		return
	_bm_ensure_teamname_popup_caret_blink_timer()
	_teamname_popup_caret_blink_visible = true
	_dlg_edit.placeholder_text = "_"
	_teamname_popup_caret_blink_timer.start()


func _bm_stop_teamname_popup_caret_blink() -> void:
	if _teamname_popup_caret_blink_timer != null and is_instance_valid(_teamname_popup_caret_blink_timer):
		_teamname_popup_caret_blink_timer.stop()
	_teamname_popup_caret_blink_visible = true
	if _dlg_edit != null:
		_dlg_edit.placeholder_text = ""


func _bm_teamname_popup_caret_blink_tick() -> void:
	if _dlg_edit == null or _dlg_edit.text.strip_edges() != "" or not _dlg_edit.has_focus():
		_bm_stop_teamname_popup_caret_blink()
		return
	_teamname_popup_caret_blink_visible = not _teamname_popup_caret_blink_visible
	_dlg_edit.placeholder_text = "_" if _teamname_popup_caret_blink_visible else ""


func _bm_teamname_input_focus_entered() -> void:
	_bm_start_teamname_input_caret_blink()


func _bm_teamname_input_focus_exited() -> void:
	_bm_stop_teamname_input_caret_blink(true)


# BM_TEAMNAME_SINGLE_PLAY_ENTRY_V1
var _bm_single_play_revealed := false

func _bm_set_teamname_form_visible(v: bool) -> void:
	_bm_single_play_revealed = v
	for n in [
		get_node_or_null("Center/Box/LblTitle"),
		get_node_or_null("Center/Box/LblTeamNameInput"),
		get_node_or_null("Center/Box/WrapInput"),
		get_node_or_null("Center/Box/SpaceAfterInput")
	]:
		if n != null and n is CanvasItem:
			(n as CanvasItem).visible = v
	if input_team != null:
		input_team.editable = v
		input_team.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

	var tn := _bm_entry_real_team_name()

	if btn_confirm != null:
		if v:
			var c := tr("teamname.create")
			if c == "teamname.create":
				c = tr("TEAMNAME_CREATE")
			btn_confirm.text = c
			btn_confirm.tooltip_text = ""
		else:
			if tn != "":
				btn_confirm.text = tn
				btn_confirm.tooltip_text = ""
			else:
				btn_confirm.text = "Play Instantly"
				btn_confirm.tooltip_text = ""

	if btn_play_instantly_entry != null:
		if v:
			btn_play_instantly_entry.visible = false
			btn_play_instantly_entry.disabled = true
			btn_play_instantly_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif tn != "":
			btn_play_instantly_entry.visible = false
			btn_play_instantly_entry.disabled = true
			btn_play_instantly_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var nt := tr("teamname.create_new_team")
			if nt == "teamname.create_new_team" or nt.strip_edges() == "":
				nt = "Create New Team"
			btn_play_instantly_entry.text = nt
			btn_play_instantly_entry.tooltip_text = ""
		else:
			btn_play_instantly_entry.visible = false
			btn_play_instantly_entry.disabled = true
			btn_play_instantly_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bm_single_play_pressed() -> void:
	if not _bm_single_play_revealed:
		if _bm_entry_real_team_name() != "":
			emit_signal("action_requested", "resume")
			return
		_bm_set_teamname_form_visible(true)
		if input_team != null:
			input_team.grab_focus()
		return
	_on_confirm()


func _ready() -> void:
	print("[TEAMNAME] _ready reached")
	call_deferred("_bm_teamname_apply_mobile_plus15")
	_ensure_bg_joueurs()
	_setup_fallback_dialog()
	call_deferred("_focus_input")
	call_deferred("_bm_apply_mobile_layout")
	call_deferred("_ensure_teamname_center_ball")

	if btn_confirm != null:
		btn_confirm.pressed.connect(_bm_single_play_pressed)

	if btn_inscrire_entry != null and not btn_inscrire_entry.pressed.is_connected(_on_entry_signup_pressed):
		btn_inscrire_entry.pressed.connect(_on_entry_signup_pressed)
	if btn_back != null:
		btn_back.pressed.connect(func(): emit_signal("back_requested"))
	if input_team != null:
		input_team.text_submitted.connect(func(_t): _on_confirm())
		if not input_team.focus_entered.is_connected(_bm_teamname_input_focus_entered):
			input_team.focus_entered.connect(_bm_teamname_input_focus_entered)
		if not input_team.focus_exited.is_connected(_bm_teamname_input_focus_exited):
			input_team.focus_exited.connect(_bm_teamname_input_focus_exited)
		if not input_team.text_changed.is_connected(_bm_teamname_input_text_changed):
			input_team.text_changed.connect(_bm_teamname_input_text_changed)
		_bm_style_teamname_input_focus()


	_apply_i18n()
	_bm_style_back_button()
	_bm_style_create_team_button()
	_bm_setup_entry_duplicates()
	if _bm_entry_real_team_name() == "":
		_bm_set_teamname_form_visible(true)
	else:
		_bm_set_teamname_form_visible(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_i18n()


# BM_ENTRY_TWO_BUTTONS_MODE_V1
func _bm_entry_real_team_name() -> String:
	var d: Dictionary = PlayerLife.load_savegame()
	var tn := str(d.get("team_name", "")).strip_edges()
	return tn


func _bm_entry_my_team_button_text() -> String:
	var tn := _bm_entry_real_team_name()
	if tn != "":
		return tn
	return tr("STADIUM_CREATE_MY_TEAM")


func _apply_i18n() -> void:
	# Titre (Label) si présent dans la scène
	if lbl_title != null:
		var t := tr("teamname.title")
		if t == "teamname.title":
			t = tr("TEAMNAME_TITLE") # fallback ancien
		lbl_title.text = t

	# Boutons
	if btn_confirm != null:
		if _bm_entry_real_team_name() != "":
			btn_confirm.text = _bm_entry_real_team_name()
		elif _bm_single_play_revealed:
			var c := tr("teamname.create")
			if c == "teamname.create":
				c = tr("TEAMNAME_CREATE")
			btn_confirm.text = c
		else:
			btn_confirm.text = "Play Instantly"

	if btn_back != null:
		var b := tr("teamname.back")
		if b == "teamname.back":
			b = tr("BTN_BACK")
		btn_back.text = b

	# Placeholder du champ principal uniquement.
	if input_team != null:
		input_team.placeholder_text = _bm_teamname_input_placeholder_text()

		if btn_reprendre_entry != null:
			btn_reprendre_entry.text = tr("STADIUM_RESUME")
			btn_reprendre_entry.tooltip_text = tr("menu.resume_game.tooltip")
		if btn_inscrire_entry != null:
			if _bm_entry_real_team_name() != "":
				btn_inscrire_entry.text = "Create New Team"
				btn_inscrire_entry.tooltip_text = ""
			else:
				btn_inscrire_entry.text = tr("STADIUM_SIGNUP")
				btn_inscrire_entry.tooltip_text = tr("menu.create_team.tooltip")
		if btn_play_instantly_entry != null:
			if _bm_entry_real_team_name() != "":
				var nt := tr("teamname.create_new_team")
				if nt == "teamname.create_new_team" or nt.strip_edges() == "":
					nt = "Create New Team"
				btn_play_instantly_entry.text = nt
				btn_play_instantly_entry.tooltip_text = ""
			else:
				btn_play_instantly_entry.text = "Play instantly"
				btn_play_instantly_entry.tooltip_text = tr("menu.play_instantly.tooltip")
		_apply_entry_flag_tooltips()

	# Fallback dialog (AcceptDialog)
	if _dlg != null:
		var dt := tr("teamname.title")
		if dt == "teamname.title":
			dt = tr("TEAMNAME_TITLE")
		_dlg.title = dt
		_dlg.dialog_text = ""

		if _dlg_edit != null:
			_dlg_edit.placeholder_text = ""

		var ok := _dlg.get_ok_button()
		if ok != null:
			var v := tr("selection.validate")
			if v == "selection.validate":
				v = tr("BTN_VALIDATE_SELECTION")

				ok.text = v


func _bm_setup_entry_duplicates() -> void:
	_bm_raise_entry_duplicate_controls()
	_bm_style_entry_duplicate_button(btn_reprendre_entry, false)
	_bm_style_entry_duplicate_button(btn_inscrire_entry, false)
	if btn_reprendre_entry != null:
		btn_reprendre_entry.visible = false
		btn_reprendre_entry.disabled = true
		btn_reprendre_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_inscrire_entry != null:
		if _bm_entry_real_team_name() != "":
			btn_inscrire_entry.visible = false
			btn_inscrire_entry.disabled = true
			btn_inscrire_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			btn_inscrire_entry.visible = false
			btn_inscrire_entry.disabled = true
			btn_inscrire_entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_play_instantly_entry != null and not btn_play_instantly_entry.pressed.is_connected(_on_entry_play_instantly_pressed):
		btn_play_instantly_entry.pressed.connect(_on_entry_play_instantly_pressed)
	_bind_entry_flag_clicks()
	_apply_entry_flags_size()
	_apply_entry_flag_tooltips()
	_bind_entry_flag_hover_tooltips()
	_bind_entry_button_hover_tooltips()

	if btn_play_instantly_entry != null:
		var tn := _bm_entry_real_team_name()
		btn_play_instantly_entry.visible = tn != ""
		btn_play_instantly_entry.disabled = tn == ""
		btn_play_instantly_entry.mouse_filter = Control.MOUSE_FILTER_STOP if tn != "" else Control.MOUSE_FILTER_IGNORE
		btn_play_instantly_entry.text = "Continue " + tn


func _bm_raise_entry_duplicate_controls() -> void:
	for n in [menu_entry, btn_play_instantly_entry, lang_bar_entry]:
		if n == null:
			continue
		var c := n as Control
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.z_index = 100
		move_child(c, get_child_count() - 1)
	for b in [btn_reprendre_entry, btn_inscrire_entry]:
		if b != null:
			b.mouse_filter = Control.MOUSE_FILTER_STOP


func _bm_style_entry_duplicate_button(btn: Button, primary: bool) -> void:
	if btn == null:
		return
	var normal := _bm_make_create_team_style(Color(0.03, 0.16, 0.38, 0.98), Color(1.0, 0.05, 0.06, 0.92), 4, 8)
	var hover := _bm_make_create_team_style(Color(0.05, 0.24, 0.55, 0.98), Color(1.0, 0.12, 0.12, 1.0), 6, 14)
	var pressed := _bm_make_create_team_style(Color(0.02, 0.11, 0.28, 1.0), Color(0.85, 0.02, 0.03, 1.0), 5, 6)
	var disabled := _bm_make_create_team_style(Color(0.08, 0.08, 0.09, 0.70), Color(0.45, 0.08, 0.08, 0.55), 3, 3)
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


func _on_entry_resume_pressed() -> void:
	print("[RESUME_BTN] _on_entry_resume_pressed")
	emit_signal("action_requested", "resume")


func _on_entry_signup_pressed() -> void:
	if _bm_entry_real_team_name() != "":
		_on_create_new_team_pressed()
		return
	emit_signal("action_requested", "signup")


func _on_create_new_team_pressed() -> void:
	_bm_set_teamname_form_visible(true)
	if input_team != null:
		input_team.text = ""
		input_team.grab_focus()


func _on_entry_play_instantly_pressed() -> void:
	if _bm_entry_real_team_name() != "":
		_on_create_new_team_pressed()
		return
	print("[PLAY_BTN] _on_entry_play_instantly_pressed")
	emit_signal("action_requested", "play_instantly")


func _bind_entry_flag_clicks() -> void:
	if lang_bar_entry == null:
		return
	for child in lang_bar_entry.get_children():
		if not (child is BaseButton):
			continue
		var b := child as BaseButton
		var loc := str(FLAG_TO_LOCALE.get(b.name, "")).strip_edges()
		if loc == "":
			continue
		b.pressed.connect(func(): _on_entry_flag_pressed(loc))


func _on_entry_flag_pressed(locale_code: String) -> void:
	TranslationServer.set_locale(locale_code)
	I18nSvc.apply_all()
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)


func _apply_entry_flag_tooltips() -> void:
	if lang_bar_entry == null:
		return
	for child in lang_bar_entry.get_children():
		if child is Control:
			var loc := str(FLAG_TO_LOCALE.get(child.name, "")).strip_edges()
			if loc != "":
				(child as Control).tooltip_text = ""


func _apply_entry_flags_size() -> void:
	if lang_bar_entry == null:
		return
	for child in lang_bar_entry.get_children():
		if child is Control:
			var ctrl := child as Control
			ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ctrl.size_flags_stretch_ratio = 0.0
			ctrl.custom_minimum_size = FLAG_SIZE
			ctrl.size = FLAG_SIZE
			ctrl.scale = Vector2(0.72, 0.72)
			if ctrl is TextureButton:
				(ctrl as TextureButton).ignore_texture_size = true


func _ensure_flag_hover_tooltip() -> void:
	if _flag_hover_tooltip != null and is_instance_valid(_flag_hover_tooltip):
		return
	_flag_hover_tooltip = PanelContainer.new()
	_flag_hover_tooltip.name = "TeamNameFlagHoverTooltip"
	_flag_hover_tooltip.visible = false
	_flag_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flag_hover_tooltip.z_index = 160
	add_child(_flag_hover_tooltip)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.18, 0.96)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_flag_hover_tooltip.add_theme_stylebox_override("panel", sb)
	_flag_hover_tooltip_label = Label.new()
	_flag_hover_tooltip_label.add_theme_font_size_override("font_size", 21)
	_flag_hover_tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_flag_hover_tooltip.add_child(_flag_hover_tooltip_label)


func _show_flag_hover_tooltip(btn: Control, txt: String) -> void:
	_ensure_flag_hover_tooltip()
	if _flag_hover_tooltip == null or _flag_hover_tooltip_label == null or btn == null:
		return
	_flag_hover_tooltip_label.text = txt
	_flag_hover_tooltip.visible = true
	await get_tree().process_frame
	_flag_hover_tooltip.global_position = btn.global_position + Vector2((btn.size.x * 0.5) - (_flag_hover_tooltip.size.x * 0.5), btn.size.y + 8.0)


func _hide_flag_hover_tooltip() -> void:
	if _flag_hover_tooltip != null:
		_flag_hover_tooltip.visible = false


func _bind_entry_flag_hover_tooltips() -> void:
	if lang_bar_entry == null:
		return
	for child in lang_bar_entry.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		var loc := str(FLAG_TO_LOCALE.get(c.name, "")).strip_edges()
		if loc == "":
			continue
		var cb_enter := Callable(self, "_show_flag_hover_tooltip").bind(c, str(LOCALE_LABEL.get(loc, loc)))
		if not c.mouse_entered.is_connected(cb_enter):
			c.mouse_entered.connect(cb_enter)
		if not c.mouse_exited.is_connected(_hide_flag_hover_tooltip):
			c.mouse_exited.connect(_hide_flag_hover_tooltip)


func _ensure_entry_button_hover_tooltip() -> void:
	if _entry_hover_tooltip != null and is_instance_valid(_entry_hover_tooltip):
		return
	_entry_hover_tooltip = PanelContainer.new()
	_entry_hover_tooltip.name = "TeamNameEntryHoverTooltip"
	_entry_hover_tooltip.visible = false
	_entry_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_hover_tooltip.z_index = 150
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
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_entry_hover_tooltip.add_theme_stylebox_override("panel", sb)
	_entry_hover_tooltip_label = Label.new()
	_entry_hover_tooltip_label.name = "TeamNameEntryHoverTooltipLabel"
	_entry_hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_entry_hover_tooltip_label.custom_minimum_size = Vector2.ZERO
	_entry_hover_tooltip_label.add_theme_font_size_override("font_size", 28)
	_entry_hover_tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_entry_hover_tooltip.add_child(_entry_hover_tooltip_label)


func _show_entry_button_hover_tooltip(btn: Control, txt: String, placement: String = "right") -> void:
	_ensure_entry_button_hover_tooltip()
	if _entry_hover_tooltip == null or _entry_hover_tooltip_label == null or btn == null:
		return
	_entry_hover_tooltip.custom_minimum_size = Vector2.ZERO
	_entry_hover_tooltip_label.custom_minimum_size = Vector2.ZERO
	_entry_hover_tooltip.reset_size()
	_entry_hover_tooltip_label.reset_size()
	_entry_hover_tooltip_label.text = txt

	_entry_hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_entry_hover_tooltip_label.size = Vector2.ZERO
	_entry_hover_tooltip_label.custom_minimum_size = Vector2.ZERO
	_entry_hover_tooltip_label.reset_size()

	print(
		"[TOOLTIP] panel=", _entry_hover_tooltip.size,
		" label=", _entry_hover_tooltip_label.size,
		" text=", txt
	)

	_entry_hover_tooltip.visible = true
	await get_tree().process_frame
	if placement == "above":
		_entry_hover_tooltip.global_position = btn.global_position + Vector2((btn.size.x * 0.5) - (_entry_hover_tooltip.size.x * 0.5), -_entry_hover_tooltip.size.y - 12.0)
	elif placement == "above_right":
		_entry_hover_tooltip.global_position = btn.global_position + Vector2((btn.size.x * 0.5) - (_entry_hover_tooltip.size.x * 0.5) + 45.0, -_entry_hover_tooltip.size.y - 12.0)
	elif placement == "below_play_instantly":
		var mobile_offset := 180.0 if _bm_is_mobile_layout() else 0.0
		_entry_hover_tooltip.global_position = btn.global_position + Vector2((btn.size.x * 0.5) - (_entry_hover_tooltip.size.x * 0.5) + mobile_offset, btn.size.y + 12.0)
	elif placement == "left":
		_entry_hover_tooltip.global_position = btn.global_position + Vector2(-_entry_hover_tooltip.size.x - 16.0, (btn.size.y * 0.5) - (_entry_hover_tooltip.size.y * 0.5))
	elif placement == "right_play_instantly":
		var mobile_offset := 36.0 if _bm_is_mobile_layout() else 0.0
		_entry_hover_tooltip.global_position = btn.global_position + Vector2(btn.size.x + 16.0 + mobile_offset, (btn.size.y * 0.5) - (_entry_hover_tooltip.size.y * 0.5))
	else:
		_entry_hover_tooltip.global_position = btn.global_position + Vector2(btn.size.x + 16.0, (btn.size.y * 0.5) - (_entry_hover_tooltip.size.y * 0.5))


func _hide_entry_button_hover_tooltip() -> void:
	if _entry_hover_tooltip != null:
		_entry_hover_tooltip.visible = false


func _bind_entry_button_hover_tooltips() -> void:
	if btn_confirm != null and not btn_confirm.mouse_entered.is_connected(_on_confirm_play_instantly_mouse_entered):
		btn_confirm.tooltip_text = ""
		btn_confirm.mouse_entered.connect(_on_confirm_play_instantly_mouse_entered)
		btn_confirm.mouse_exited.connect(_hide_entry_button_hover_tooltip)
	if btn_reprendre_entry != null and not btn_reprendre_entry.mouse_entered.is_connected(_on_entry_resume_mouse_entered):
		btn_reprendre_entry.tooltip_text = ""
		btn_reprendre_entry.mouse_entered.connect(_on_entry_resume_mouse_entered)
		btn_reprendre_entry.mouse_exited.connect(_hide_entry_button_hover_tooltip)
	if btn_inscrire_entry != null and not btn_inscrire_entry.mouse_entered.is_connected(_on_entry_signup_mouse_entered):
		btn_inscrire_entry.tooltip_text = ""
		btn_inscrire_entry.mouse_entered.connect(_on_entry_signup_mouse_entered)
		btn_inscrire_entry.mouse_exited.connect(_hide_entry_button_hover_tooltip)
	if btn_play_instantly_entry != null and not btn_play_instantly_entry.mouse_entered.is_connected(_on_entry_play_instantly_mouse_entered):
		btn_play_instantly_entry.tooltip_text = ""
		btn_play_instantly_entry.mouse_entered.connect(_on_entry_play_instantly_mouse_entered)
		btn_play_instantly_entry.mouse_exited.connect(_hide_entry_button_hover_tooltip)


func _on_confirm_play_instantly_mouse_entered() -> void:
	var tn := _bm_entry_real_team_name()
	print("[HOVER BTN] text=", btn_confirm.text, " team=", tn)
	if tn != "":
		var tt := tr("menu.continue_team.tooltip")
		if tt == "menu.continue_team.tooltip" or tt.strip_edges() == "":
			tt = "Continue your progress with {team}"
		_show_entry_button_hover_tooltip(
			btn_confirm,
			tt.format({"team": tn}),
			"below_play_instantly"
		)
	else:
		_show_entry_button_hover_tooltip(
			btn_confirm,
			tr("menu.play_instantly.tooltip"),
			"below_play_instantly"
		)


func _on_entry_resume_mouse_entered() -> void:
	_show_entry_button_hover_tooltip(btn_reprendre_entry, tr("menu.resume_game.tooltip"), "above_right")


func _on_entry_signup_mouse_entered() -> void:
	_show_entry_button_hover_tooltip(btn_inscrire_entry, tr("menu.create_team.tooltip"), "above")


func _on_entry_play_instantly_mouse_entered() -> void:
	if _bm_entry_real_team_name() != "":
		_show_entry_button_hover_tooltip(btn_play_instantly_entry, tr("teamname.create_new_team.tooltip"), "right_play_instantly")
	else:
		_show_entry_button_hover_tooltip(btn_play_instantly_entry, tr("menu.play_instantly.tooltip"), "right_play_instantly")


func _ensure_teamname_center_ball() -> void:
	if get_node_or_null("ImgBallTeamName") != null:
		return

	var tex := load("res://assets/images/ballon.png") as Texture2D
	if tex == null:
		push_error("[TEAMNAME] missing ball: res://assets/images/ballon.png")
		return

	var ball := TextureRect.new()
	ball.name = "ImgBallTeamName"
	ball.texture = tex
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.custom_minimum_size = Vector2(72, 72)
	ball.size = Vector2(72, 72)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball.z_index = 50
	add_child(ball)

	await get_tree().process_frame

	await get_tree().process_frame

	if input_team == null:
		return

	var input_pos := input_team.global_position
	var input_size := input_team.size

	ball.position = Vector2(
		input_pos.x + (input_size.x - ball.size.x) * 0.5,
		input_pos.y - 118.0
	)

	var base_y := ball.position.y
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(ball, "position:y", base_y - 18.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "position:y", base_y, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.10)


func _setup_fallback_dialog() -> void:
	_dlg = AcceptDialog.new()
	_dlg.title = "Nom de l'équipe"
	_dlg.dialog_text = ""
	add_child(_dlg)
	_dlg.min_size = Vector2i(485, 146)

	# Cache le dialog dès sa création
	_dlg.hide()

	_dlg_edit = LineEdit.new()
	_dlg_edit.custom_minimum_size = Vector2(320, 0)
	_dlg_edit.placeholder_text = ""
	var edit_bg := StyleBoxFlat.new()
	edit_bg.bg_color = Color(1, 1, 1, 1)
	edit_bg.border_width_left = 1
	edit_bg.border_width_top = 1
	edit_bg.border_width_right = 1
	edit_bg.border_width_bottom = 1
	edit_bg.border_color = Color(0.2, 0.2, 0.2, 1)
	edit_bg.corner_radius_top_left = 6
	edit_bg.corner_radius_top_right = 6
	edit_bg.corner_radius_bottom_left = 6
	edit_bg.corner_radius_bottom_right = 6
	_dlg_edit.add_theme_stylebox_override("normal", edit_bg)
	_dlg_edit.add_theme_stylebox_override("focus", edit_bg)
	_dlg_edit.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_dlg_edit.add_theme_color_override("font_placeholder_color", Color(0, 0, 0, 1))
	var edit_base_fs: int = int(_dlg_edit.get_theme_font_size("font_size"))
	_dlg_edit.add_theme_font_size_override("font_size", (edit_base_fs + 10) if edit_base_fs > 0 else 26)

	# Godot 4.5 : insérer dans le conteneur interne via le parent du label
	var content: Node = _dlg.get_label().get_parent()
	content.add_child(_dlg_edit)

	# Entrée valide dans la popup
	_dlg.register_text_enter(_dlg_edit)

	_dlg.get_ok_button().text = tr("teamname.confirm_team_name")
	_bm_style_teamname_fallback_dialog_title()
	_bm_teamname_apply_mobile_empty_name_popup()
	_dlg.confirmed.connect(_on_fallback_confirmed)


func _bm_style_teamname_fallback_dialog_title() -> void:
	if _dlg == null:
		return
	var dlg_label := _dlg.get_label()
	if dlg_label != null:
		dlg_label.add_theme_font_size_override("font_size", 30)
	_dlg.add_theme_font_size_override("title_font_size", 30)


func _bm_teamname_apply_mobile_empty_name_popup() -> void:
	if _bm_teamname_is_mobile_layout():
		_dlg.min_size = Vector2i(485, 146)
		_dlg_edit.custom_minimum_size = Vector2(414, 50)
		_dlg_edit.editable = true
		_dlg_edit.focus_mode = Control.FOCUS_ALL
		_dlg_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		_dlg_edit.virtual_keyboard_enabled = true
		if not _dlg_edit.gui_input.is_connected(_bm_teamname_popup_input_tap_focus):
			_dlg_edit.gui_input.connect(_bm_teamname_popup_input_tap_focus)
		_dlg_edit.add_theme_font_size_override("font_size", 36)
		var ok_btn := _dlg.get_ok_button()
		if ok_btn != null:
			var ok_fs: int = int(ok_btn.get_theme_font_size("font_size"))
			ok_btn.add_theme_font_size_override("font_size", (ok_fs + 6) if ok_fs > 0 else 22)



func _bm_teamname_input_tap_focus(event: InputEvent) -> void:
	if input_team == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_bm_start_teamname_input_caret_blink()
			input_team.editable = true
			input_team.focus_mode = Control.FOCUS_ALL
			input_team.mouse_filter = Control.MOUSE_FILTER_STOP
			input_team.virtual_keyboard_enabled = true
			_bm_open_html_input()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_bm_start_teamname_input_caret_blink()
			input_team.editable = true
			input_team.focus_mode = Control.FOCUS_ALL
			input_team.mouse_filter = Control.MOUSE_FILTER_STOP
			input_team.virtual_keyboard_enabled = true
			_bm_open_html_input()
			get_viewport().set_input_as_handled()

func _focus_input() -> void:
	if input_team == null:
		print("[TEAMNAME] InputTeam missing")
		return

	# Best effort focus DOM (Web)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function(){
				try{
					const c = document.querySelector('canvas');
					if (c) { c.tabIndex = 0; c.focus(); }
				}catch(e){}
			})();
		""")

	input_team.editable = true
	input_team.focus_mode = Control.FOCUS_ALL
	input_team.mouse_filter = Control.MOUSE_FILTER_STOP
	input_team.virtual_keyboard_enabled = true
	if not input_team.gui_input.is_connected(_bm_teamname_input_tap_focus):
		input_team.gui_input.connect(_bm_teamname_input_tap_focus)


func _on_confirm() -> void:
	if input_team == null:
		print("[TEAMNAME] InputTeam missing")
		return

	var team_name: String = input_team.text.strip_edges()
	if team_name == "":
		_open_fallback_dialog()
		return

	if btn_confirm != null:
		btn_confirm.disabled = true
	if btn_back != null:
		btn_back.disabled = true
	input_team.editable = false

	print("[TEAMNAME] EMIT submit_team_name =", team_name)
	emit_signal("submit_team_name", team_name)
	print("[TEAMNAME] EMIT done")


func _open_fallback_dialog() -> void:
	_dlg_edit.text = ""
	_bm_start_teamname_popup_caret_blink()
	_bm_style_teamname_fallback_dialog_title()
	_bm_teamname_apply_mobile_empty_name_popup()
	if _bm_teamname_is_mobile_layout():
		_dlg.popup_centered(Vector2i(485, 146))
		call_deferred("_bm_teamname_focus_popup_edit_mobile")
	else:
		_dlg.popup_centered()
		_dlg_edit.grab_focus()


func _bm_teamname_focus_popup_edit_mobile() -> void:
	if not _bm_teamname_is_mobile_layout():
		return
	if _dlg_edit == null:
		return
	await get_tree().process_frame
	_dlg_edit.grab_focus()
	_bm_open_html_popup_input()
	if OS.has_feature("android") or OS.has_feature("ios"):
		var edit_rect := Rect2(_dlg_edit.global_position, _dlg_edit.size)
		DisplayServer.virtual_keyboard_show(_dlg_edit.text, edit_rect)


func _bm_teamname_popup_input_tap_focus(event: InputEvent) -> void:
	if _dlg_edit == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dlg_edit.grab_focus()
			_bm_start_teamname_popup_caret_blink()
			_bm_open_html_popup_input()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_dlg_edit.grab_focus()
			_bm_start_teamname_popup_caret_blink()
			_bm_open_html_popup_input()
			get_viewport().set_input_as_handled()


func _on_fallback_confirmed() -> void:
	var team_name: String = _dlg_edit.text.strip_edges()
	if team_name == "":
		_open_fallback_dialog()
		return

	# Synchronise aussi le LineEdit principal
	if input_team != null:
		input_team.text = team_name

	emit_signal("submit_team_name", team_name)


# --- BM MOBILE HTML INPUT BRIDGE ---
func _bm_open_html_input() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		var input = document.getElementById('bm_team_input');
		if (!input) {
			input = document.createElement('input');
			input.id = 'bm_team_input';
			input.type = 'text';
			input.style.position = 'absolute';
			input.style.top = '0px';
			input.style.left = '0px';
			input.style.width = '1px';
			input.style.height = '1px';
			input.style.fontSize = '1px';
			input.style.opacity = '0';
				input.style.background = 'transparent';
				input.style.border = '0';
				input.style.outline = 'none';
				input.style.color = 'transparent';
				input.style.caretColor = 'transparent';
				input.style.zIndex = 9999;
			document.body.appendChild(input);
		}
		input.value = '';
		input.focus();

		input.onblur = function() {
			var val = input.value;
			input.remove();
			godot.call('bm_set_team_name', val);
		};
	""")

func bm_set_team_name(val):
	if input_team != null:
		input_team.text = val


func _bm_open_html_popup_input() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		var input = document.getElementById('bm_team_popup_input');
		if (!input) {
			input = document.createElement('input');
			input.id = 'bm_team_popup_input';
			input.type = 'text';
			input.style.position = 'absolute';
			input.style.top = '40%';
			input.style.left = '10%';
			input.style.width = '80%';
			input.style.height = '50px';
			input.style.fontSize = '36px';
			input.style.zIndex = 9999;
			document.body.appendChild(input);
		}
		input.value = '';
		input.placeholder = '';
		input.focus();

		input.onblur = function() {
			var val = input.value;
			input.remove();
			godot.call('bm_set_popup_team_name', val);
		};
	""")


func bm_set_popup_team_name(val):
	if _dlg_edit != null:
		_dlg_edit.text = val
	# --- END ---

func _bm_teamname_is_mobile_layout() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _bm_teamname_apply_mobile_plus15() -> void:
	if not _bm_teamname_is_mobile_layout():
		return
	_bm_teamname_scale_controls_plus15(self)


func _bm_teamname_scale_controls_plus15(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Button or child is TextureButton or child is LineEdit:
			var c: Control = child as Control
			if not c.has_meta("bm_mobile_plus15_done"):
				c.set_meta("bm_mobile_plus15_done", true)
				var base_min: Vector2 = c.custom_minimum_size
				if base_min == Vector2.ZERO:
					base_min = c.size
				if base_min.x < 1.0:
					base_min.x = 160.0
				if base_min.y < 1.0:
					base_min.y = 56.0
				c.custom_minimum_size = base_min * 1.15

				if child is Button:
					var b: Button = child as Button
					var fs: int = int(b.get_theme_font_size("font_size"))
					if fs > 0:
						b.add_theme_font_size_override("font_size", int(round(float(fs) * 1.15)))

				if child is LineEdit:
					var le: LineEdit = child as LineEdit
					var fs_le: int = int(le.get_theme_font_size("font_size"))
					if fs_le > 0:
						le.add_theme_font_size_override("font_size", int(round(float(fs_le) * 1.15)))

		_bm_teamname_scale_controls_plus15(child)
