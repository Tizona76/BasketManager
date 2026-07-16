extends Control
const PlayerLife := preload("res://scripts/PlayerLife.gd")
const SponsorDataRef := preload("res://scripts/SponsorData.gd")

# BM_SKIP_FINAL_RESULT_TOKEN_MODE_V1
# false = mode test actuel inchangé.
# true = bouton disponible seulement dès Saison 2, coût 1 token.
const BM_SKIP_FINAL_RESULT_TOKEN_MODE := true
const BM_SKIP_FINAL_RESULT_TOKEN_COST := 1
const BM_GENERIC_FUNNEL_URL := "https://api.basketmanager-game.com/v1/funnel/event"
const BM_GENERIC_FUNNEL_MAX_RETRIES := 2
const HOME_ARENA_MATCH_BACKGROUND_PATH := "res://assets/images/backgrounds/home_arena.png"
const BM_COACH_INSIGHTS_DEBUG := true

@onready var lbl_temps: Label = $LabelTemps
@onready var lbl_score: Label = $LabelScore
@onready var lbl_info: Label = $LabelInfo
@onready var timer: Timer = $Timer
@onready var btn_retour: Button = $BtnRetour

var lbl_match_result: Label = null
var btn_current_lineup: Button = null
var current_lineup_popup: Control = null
var _match_progress_info_after_countdown: String = ""
var _bm_lbl_info_base_position: Vector2 = Vector2.ZERO
var _bm_lbl_info_base_size: Vector2 = Vector2.ZERO
var _bm_lbl_info_base_font_size: int = 22
static var _bm_last_coach_insight_family: String = ""
static var _bm_last_coach_insight_player: String = ""


func _bm_make_back_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_bottom = bottom_w
	sb.border_color = Color(0.60, 0.0, 0.0, 1.0)
	sb.shadow_color = glow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _bm_style_btn_retour() -> void:
	if btn_retour == null:
		return

	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)

	btn_retour.add_theme_stylebox_override("normal", normal)
	btn_retour.add_theme_stylebox_override("hover", hover)
	btn_retour.add_theme_stylebox_override("pressed", pressed)
	btn_retour.add_theme_stylebox_override("disabled", disabled)
	btn_retour.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	btn_retour.add_theme_font_size_override("font_size", 22)

func _bm_matchsim_tr_fallback(key: String, fallback: String) -> String:
	var txt := tr(key)
	if txt == key or txt.strip_edges() == "":
		return fallback
	return txt


func _bm_style_btn_skip_final_result_active() -> void:
	if btn_skip == null:
		return
	btn_skip.visible = true
	btn_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_final := StyleBoxFlat.new()
	sb_final.bg_color = Color(1.00, 0.48, 0.02, 1.0)
	sb_final.set_corner_radius_all(14)
	sb_final.set_border_width_all(2)
	sb_final.border_color = Color(1.0, 0.95, 0.35, 0.95)
	sb_final.shadow_color = Color(1.0, 0.45, 0.0, 0.55)
	sb_final.shadow_size = 14
	sb_final.shadow_offset = Vector2(0, 5)
	sb_final.content_margin_top = -2
	sb_final.content_margin_bottom = 18
	btn_skip.add_theme_stylebox_override("normal", sb_final)
	btn_skip.add_theme_stylebox_override("hover", sb_final)
	btn_skip.add_theme_stylebox_override("pressed", sb_final)
	btn_skip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_skip.add_theme_font_size_override("font_size", 24 if _bm_matchsim_is_mobile_layout() else 22)
	btn_skip.custom_minimum_size = Vector2(maxf(btn_skip.custom_minimum_size.x, 215.0), 84.0)
	btn_skip.size = Vector2(215.0, 84.0)
	btn_skip.position.x = (get_viewport_rect().size.x - btn_skip.size.x) * 0.5
	btn_skip.text = _bm_matchsim_tr_fallback("matchsim.get_final_result", "Get Final Result") + "\n"

	var old_capsule := btn_skip.get_node_or_null("VisualUnlockCapsule")
	if old_capsule != null:
		old_capsule.queue_free()

	var capsule := HBoxContainer.new()
	capsule.name = "VisualUnlockCapsule"
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.alignment = BoxContainer.ALIGNMENT_CENTER
	capsule.add_theme_constant_override("separation", 4)
	capsule.position = Vector2((btn_skip.size.x - 132.0) * 0.5, 47.0)
	capsule.size = Vector2(132, 30)
	btn_skip.add_child(capsule)

	var bg := Panel.new()
	bg.name = "CapsuleBg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2.ZERO
	bg.size = capsule.size
	var sb_capsule := StyleBoxFlat.new()
	sb_capsule.bg_color = Color(0.04, 0.08, 0.15, 0.96)
	sb_capsule.set_corner_radius_all(12)
	sb_capsule.set_border_width_all(1)
	sb_capsule.border_color = Color(1.0, 0.80, 0.25, 0.95)
	bg.add_theme_stylebox_override("panel", sb_capsule)
	capsule.add_child(bg)
	capsule.move_child(bg, 0)

	var lbl := Label.new()
	lbl.text = _bm_matchsim_tr_fallback("matchsim.unlock", "Unlock")
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	capsule.add_child(lbl)

	var cost := Label.new()
	cost.text = "1"
	cost.add_theme_font_size_override("font_size", 24)
	cost.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30, 1.0))
	cost.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 0.95))
	cost.add_theme_constant_override("outline_size", 2)
	capsule.add_child(cost)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/images/token.png") as Texture2D
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.add_child(icon)

func _bm_apply_i18n_btn_retour() -> void:
	if btn_retour != null:
		btn_retour.set_meta("i18n_key", "matchsim.continue_to_season")
		btn_retour.text = "matchsim.continue_to_season"
		I18nSvc.apply_node(btn_retour)
		_bm_style_btn_retour()


func _bm_make_game_lineup_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
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


func _bm_style_current_lineup_button() -> void:
	if btn_current_lineup == null:
		return
	var normal := _bm_make_game_lineup_button_style(Color(0.95, 0.48, 0.12, 1.0), Color(0.72, 0.28, 0.04, 1.0), 4, 8)
	var hover := _bm_make_game_lineup_button_style(Color(1.0, 0.58, 0.18, 1.0), Color(0.88, 0.38, 0.06, 1.0), 6, 14)
	var pressed := _bm_make_game_lineup_button_style(Color(0.82, 0.36, 0.08, 1.0), Color(0.58, 0.22, 0.03, 1.0), 5, 6)
	btn_current_lineup.add_theme_stylebox_override("normal", normal)
	btn_current_lineup.add_theme_stylebox_override("hover", hover)
	btn_current_lineup.add_theme_stylebox_override("pressed", pressed)
	btn_current_lineup.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_current_lineup.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_current_lineup.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_current_lineup.add_theme_font_size_override("font_size", 22)


func _bm_apply_game_lineup_close_button_style(button: Button) -> void:
	if button == null:
		return
	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_font_size_override("font_size", 22)


func _bm_place_current_lineup_button() -> void:
	if btn_current_lineup == null:
		return
	var vp := get_viewport_rect().size
	var w := 202.0 if _bm_matchsim_is_mobile_layout() else 184.0
	var h := 58.0 if _bm_matchsim_is_mobile_layout() else 52.0
	btn_current_lineup.custom_minimum_size = Vector2(w, h)
	btn_current_lineup.size = Vector2(w, h)
	btn_current_lineup.position = Vector2(vp.x - w - 24.0, 24.0)
	btn_current_lineup.z_index = 80


func _bm_ensure_current_lineup_button() -> void:
	if btn_current_lineup != null and is_instance_valid(btn_current_lineup):
		_bm_place_current_lineup_button()
		return
	btn_current_lineup = Button.new()
	btn_current_lineup.name = "BtnCurrentLineup"
	btn_current_lineup.text = _bm_matchsim_tr_fallback("matchsim.game_lineup", "Game Lineup")
	btn_current_lineup.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_current_lineup.focus_mode = Control.FOCUS_NONE
	btn_current_lineup.pressed.connect(_bm_show_current_lineup_popup)
	add_child(btn_current_lineup)
	_bm_style_current_lineup_button()
	_bm_place_current_lineup_button()


func _bm_current_lineup_style_panel(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	return sb


func _bm_current_lineup_label(parent: Control, text_value: String, pos: Vector2, sz: Vector2, fs: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	parent.add_child(lbl)
	return lbl


func _bm_current_lineup_attr_color(metric: String) -> Color:
	match metric:
		"shooting", "accuracy", "attack":
			return Color(0.95, 0.50, 0.12, 1.0)
		"speed", "energy":
			return Color(0.88, 0.62, 0.18, 1.0)
		"defense":
			return Color(0.24, 0.47, 0.68, 1.0)
		"motivation":
			return Color(0.72, 0.52, 0.92, 1.0)
		_:
			return Color(0.92, 0.95, 1.0, 1.0)


func _bm_current_lineup_attr(parent: Control, label_text: String, value: Variant, pos: Vector2, metric: String) -> void:
	_bm_current_lineup_label(parent, label_text, pos, Vector2(84, 16), 11, Color(0.68, 0.76, 0.90, 0.95))
	var value_text := ("%.2f" % float(value)) if metric == "accuracy" else str(int(round(float(value))))
	_bm_current_lineup_label(parent, value_text, pos + Vector2(0, 15), Vector2(84, 22), 18, _bm_current_lineup_attr_color(metric), HORIZONTAL_ALIGNMENT_CENTER)


func _bm_current_lineup_player_metrics(pd: Dictionary) -> Dictionary:
	var tir := float(pd.get("tir", 0.0))
	var precision := float(pd.get("precision", pd.get("accuracy", 0.0)))
	if precision <= 1.5:
		precision *= 100.0
	var vitesse := float(pd.get("vitesse", pd.get("speed", 0.0)))
	var defense := float(pd.get("defense", 0.0))
	var motivation := float(pd.get("motivation", 0.0))
	return {
		"attack": int(round((tir + precision) * 0.5)),
		"defense": int(round(defense)),
		"energy": int(round((vitesse + motivation) * 0.5))
	}


func _bm_current_lineup_position_text(poste: String) -> String:
	match String(poste).strip_edges().to_lower():
		"meneur", "point guard", "p.g.", "pg":
			return _bm_matchsim_tr_fallback("player.position.point_guard", "Point Guard")
		"arrière", "arriere", "shooting guard", "s.g.", "sg":
			return _bm_matchsim_tr_fallback("player.position.shooting_guard", "Shooting Guard")
		"ailier", "small forward", "s.f.", "sf":
			return _bm_matchsim_tr_fallback("player.position.small_forward", "Small Forward")
		"ailier fort", "power forward", "p.f.", "pf":
			return _bm_matchsim_tr_fallback("player.position.point_forward", "Power Forward")
		"pivot", "center", "c.", "c":
			return _bm_matchsim_tr_fallback("player.position.center", "Center")
		_:
			return poste


func _bm_current_lineup_player_avatar(pd: Dictionary, parent: Control, pos: Vector2) -> void:
	var tex := TextureRect.new()
	tex.position = pos
	tex.size = Vector2(38, 38)
	tex.custom_minimum_size = tex.size
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(pd.get("avatar_path", "")).strip_edges()
	if path != "" and ResourceLoader.exists(path):
		tex.texture = load(path) as Texture2D
	parent.add_child(tex)


func _bm_current_lineup_player_row(parent: Control, pd: Dictionary, y: float, row_w: float) -> void:
	var row := Panel.new()
	row.position = Vector2(0, y)
	row.size = Vector2(row_w, 44)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _bm_current_lineup_style_panel(Color(0.02, 0.04, 0.08, 0.72), Color(1, 1, 1, 0.10)))
	parent.add_child(row)

	_bm_current_lineup_player_avatar(pd, row, Vector2(8, 3))
	_bm_current_lineup_label(row, _bm_player_display_name(pd), Vector2(54, 7), Vector2(row_w - 602.0, 30), 17, Color(1, 1, 1, 1))
	var pos_text := _bm_current_lineup_position_text(str(pd.get("poste", pd.get("pos", ""))))
	var metrics := _bm_current_lineup_player_metrics(pd)
	_bm_current_lineup_label(row, pos_text, Vector2(row_w - 545.0, 7), Vector2(130, 30), 16, Color(1, 1, 1, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(row, str(int(metrics.get("attack", 0))), Vector2(row_w - 350.0, 7), Vector2(70, 30), 16, Color(1, 1, 1, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(row, str(int(metrics.get("defense", 0))), Vector2(row_w - 235.0, 7), Vector2(76, 30), 16, Color(1, 1, 1, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(row, str(int(metrics.get("energy", 0))), Vector2(row_w - 112.0, 7), Vector2(68, 30), 16, Color(1, 1, 1, 0.94), HORIZONTAL_ALIGNMENT_CENTER)


func _bm_current_lineup_header(parent: Control, y: float, row_w: float) -> void:
	var header_color := Color(0.76, 0.84, 0.96, 0.82)
	_bm_current_lineup_label(parent, _bm_matchsim_tr_fallback("mercato.col.position", "Position"), Vector2(row_w - 545.0, y), Vector2(130, 20), 15, header_color, HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(parent, _bm_matchsim_tr_fallback("player.card.graph.attack", "Attack"), Vector2(row_w - 350.0, y), Vector2(70, 20), 15, header_color, HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(parent, _bm_matchsim_tr_fallback("player.card.graph.defense", "Defense"), Vector2(row_w - 235.0, y), Vector2(76, 20), 15, header_color, HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(parent, _bm_matchsim_tr_fallback("matchsim.energy", "Energy"), Vector2(row_w - 112.0, y), Vector2(68, 20), 15, header_color, HORIZONTAL_ALIGNMENT_CENTER)


func _bm_current_lineup_players() -> Array[Dictionary]:
	var save: Dictionary = PlayerLife.load_savegame()
	var lineup_ids: Array = []
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = save["roster"] as Dictionary
		if roster.has("match_selected_ids") and typeof(roster["match_selected_ids"]) == TYPE_ARRAY:
			var official_ids: Array = (roster["match_selected_ids"] as Array).duplicate()
			if official_ids.size() == 8:
				lineup_ids = official_ids
	if lineup_ids.is_empty():
		lineup_ids = _bm_get_effective_played_ids(save)
		if lineup_ids.size() > 8:
			lineup_ids = lineup_ids.slice(0, 8)
	var out: Array[Dictionary] = []
	if lineup_ids.is_empty():
		return out
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return out
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	for raw_id in lineup_ids:
		var sid := str(raw_id).strip_edges()
		if sid == "":
			continue
		var key := str(int(round(float(sid))))
		if not by_id.has(key) or typeof(by_id[key]) != TYPE_DICTIONARY:
			continue
		out.append((by_id[key] as Dictionary).duplicate(true))
	return out


func _bm_current_lineup_summary(players: Array[Dictionary]) -> Dictionary:
	var total_attack := 0.0
	var total_defense := 0.0
	var total_energy := 0.0
	for pd in players:
		var precision := float(pd.get("precision", pd.get("accuracy", 0.0)))
		if precision <= 1.5:
			precision *= 100.0
		total_attack += (float(pd.get("tir", 0.0)) + precision) / 2.0
		total_defense += float(pd.get("defense", 0.0))
		total_energy += (float(pd.get("vitesse", pd.get("speed", 0.0))) + float(pd.get("motivation", 0.0))) / 2.0
	var count := maxf(1.0, float(players.size()))
	return {
		"attack": int(round(total_attack / count)),
		"defense": int(round(total_defense / count)),
		"energy": int(round(total_energy / count))
	}


func _bm_current_lineup_summary_item(parent: Control, label_text: String, value: int, x: float, metric: String) -> void:
	_bm_current_lineup_label(parent, label_text, Vector2(x, 0), Vector2(150, 24), 15, Color(0.78, 0.85, 0.95, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(parent, str(value), Vector2(x, 24), Vector2(150, 34), 28, _bm_current_lineup_attr_color(metric), HORIZONTAL_ALIGNMENT_CENTER)


func _bm_show_current_lineup_popup() -> void:
	if current_lineup_popup != null and is_instance_valid(current_lineup_popup):
		return
	var players := _bm_current_lineup_players()
	var popup := Control.new()
	popup.name = "CurrentLineupPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 620
	add_child(popup)
	current_lineup_popup = popup

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.50)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var vp := get_viewport_rect().size
	var card_w := minf(820.0, vp.x - 64.0)
	var card_h := minf(710.0, vp.y - 56.0)
	var card := Panel.new()
	card.size = Vector2(card_w, card_h)
	card.position = Vector2((vp.x - card_w) * 0.5, (vp.y - card_h) * 0.5)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _bm_current_lineup_style_panel(Color(0.025, 0.035, 0.075, 0.98), Color(0.95, 0.58, 0.14, 0.72)))
	popup.add_child(card)

	_bm_current_lineup_label(card, _bm_matchsim_tr_fallback("matchsim.game_lineup", "Game Lineup"), Vector2(0, 18), Vector2(card_w, 38), 30, Color(1, 1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_bm_current_lineup_label(card, _bm_matchsim_tr_fallback("matchsim.match_in_progress", "Match in progress") + "  |  " + _bm_matchsim_tr_fallback("matchsim.read_only", "Read only"), Vector2(0, 54), Vector2(card_w, 26), 16, Color(0.76, 0.84, 0.96, 0.88), HORIZONTAL_ALIGNMENT_CENTER)

	var summary := _bm_current_lineup_summary(players)
	var summary_row := Control.new()
	summary_row.position = Vector2((card_w - 510.0) * 0.5, 84.0)
	summary_row.size = Vector2(510, 58)
	summary_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(summary_row)
	_bm_current_lineup_summary_item(summary_row, _bm_matchsim_tr_fallback("player.card.graph.attack", "Attack"), int(summary.get("attack", 0)), 0, "attack")
	_bm_current_lineup_summary_item(summary_row, _bm_matchsim_tr_fallback("player.card.graph.defense", "Defense"), int(summary.get("defense", 0)), 180, "defense")
	_bm_current_lineup_summary_item(summary_row, _bm_matchsim_tr_fallback("matchsim.energy", "Energy"), int(summary.get("energy", 0)), 360, "energy")

	var content := VBoxContainer.new()
	content.position = Vector2(34, 154)
	content.size = Vector2(card_w - 68.0, card_h - 246.0)
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var row_w := content.size.x
	var starting := players.slice(0, mini(5, players.size()))
	var bench := players.slice(mini(5, players.size()), players.size())

	var start_section := Control.new()
	start_section.custom_minimum_size = Vector2(row_w, 26.0 + float(starting.size()) * 46.0)
	content.add_child(start_section)
	_bm_current_lineup_label(start_section, _bm_matchsim_tr_fallback("matchsim.starting_five", "STARTING FIVE"), Vector2(0, 0), Vector2(row_w, 22), 17, Color(1.0, 0.72, 0.20, 1.0))
	_bm_current_lineup_header(start_section, 0.0, row_w)
	for i in range(starting.size()):
		_bm_current_lineup_player_row(start_section, starting[i], 26.0 + float(i) * 46.0, row_w)

	var bench_section := Control.new()
	bench_section.custom_minimum_size = Vector2(row_w, 26.0 + float(bench.size()) * 46.0)
	content.add_child(bench_section)
	_bm_current_lineup_label(bench_section, _bm_matchsim_tr_fallback("matchsim.bench", "BENCH"), Vector2(0, 0), Vector2(row_w, 22), 17, Color(1.0, 0.72, 0.20, 1.0))
	for i in range(bench.size()):
		_bm_current_lineup_player_row(bench_section, bench[i], 26.0 + float(i) * 46.0, row_w)

	var btn := Button.new()
	btn.text = _bm_matchsim_tr_fallback("common.close", "Close")
	btn.custom_minimum_size = Vector2(170, 56)
	btn.size = Vector2(170, 56)
	btn.position = Vector2(card_w - 198.0, card_h - 72.0)
	btn.focus_mode = Control.FOCUS_NONE
	_bm_apply_game_lineup_close_button_style(btn)
	btn.pressed.connect(func():
		if current_lineup_popup != null and is_instance_valid(current_lineup_popup):
			current_lineup_popup.queue_free()
		current_lineup_popup = null
	)
	card.add_child(btn)

@onready var btn_skip: Button = get_node_or_null("BtnSkip") as Button
@onready var lbl_team_dom: Label = get_node_or_null("ScoreBoardPanel/LabelTeamDom") as Label
@onready var lbl_team_ext: Label = get_node_or_null("ScoreBoardPanel/LabelTeamExt") as Label
@onready var scoreboard_panel: Control = $ScoreBoardPanel
@onready var info_panel: Control = $InfoPanel


func _bm_matchsim_is_mobile_layout() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(((navigator.maxTouchPoints || 0) > 0) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent))", true)
		if bool(js_mobile):
			return true
	if minf(vp.x, float(win.x)) < 900.0:
		return true
	return false


func _bm_matchsim_apply_mobile_layout() -> void:
	if not _bm_matchsim_is_mobile_layout():
		return

	var bg := get_node_or_null("BG") as TextureRect
	if bg != null:
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0.0
		bg.offset_top = 0.0
		bg.offset_right = 0.0
		bg.offset_bottom = 0.0
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for ctrl in [lbl_temps, lbl_score, lbl_info, lbl_team_dom, lbl_team_ext, btn_retour, btn_skip]:
		_bm_matchsim_mobile_font_plus2(ctrl as Control)

	# BM_MOBILE_MATCH_SCORE_TIME_TEXT_V1
	if lbl_score != null:
		lbl_score.add_theme_font_size_override("font_size", 82)
	if lbl_temps != null:
		lbl_temps.add_theme_font_size_override("font_size", 40)

	# BM_MOBILE_MATCH_TEAM_NAMES_TEXT_V1
	if lbl_team_dom != null:
		lbl_team_dom.add_theme_font_size_override("font_size", 32)
	if lbl_team_ext != null:
		lbl_team_ext.add_theme_font_size_override("font_size", 32)

	# BM_MOBILE_MATCH_END_INFO_TEXT_V1
	if lbl_info != null:
		lbl_info.add_theme_font_size_override("font_size", 34)
		lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl_info.add_theme_constant_override("outline_size", 8)
		if info_panel != null:
			var show_info_bg := bool(lbl_info.text.strip_edges() != "")
			info_panel.visible = show_info_bg
			if show_info_bg:
				lbl_info.z_index = 20
				info_panel.z_index = 19
				info_panel.self_modulate = Color(0, 0, 0, 0.78)
				info_panel.position = lbl_info.position - Vector2(24.0, 18.0)
				info_panel.size = lbl_info.size + Vector2(48.0, 70.0)
		if lbl_match_result != null and is_instance_valid(lbl_match_result):
			_bm_place_match_result_label(lbl_match_result.text, lbl_match_result.get_theme_color("font_color"))

	if btn_retour != null and not btn_retour.has_meta("bm_matchsim_mobile_btn_plus20_done"):
		btn_retour.set_meta("bm_matchsim_mobile_btn_plus20_done", true)
		btn_retour.scale *= 1.20

	if btn_skip != null and not btn_skip.has_meta("bm_matchsim_mobile_btn_plus20_done"):
		btn_skip.set_meta("bm_matchsim_mobile_btn_plus20_done", true)
		btn_skip.scale *= 1.20


func _bm_place_match_result_label(text_value: String, color_value: Color) -> void:
	if lbl_info == null:
		return
	if lbl_match_result == null or not is_instance_valid(lbl_match_result):
		lbl_match_result = Label.new()
		lbl_match_result.name = "LblMatchResultOnly"
		lbl_match_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl_match_result)
	lbl_match_result.text = text_value
	var result_height := 56.0 if _bm_matchsim_is_mobile_layout() else 44.0
	lbl_match_result.position = lbl_info.position - Vector2(0.0, result_height + 18.0)
	lbl_match_result.size = Vector2(lbl_info.size.x, result_height)
	lbl_match_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_match_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_match_result.z_index = 21
	lbl_match_result.add_theme_font_size_override("font_size", lbl_info.get_theme_font_size("font_size"))
	lbl_match_result.add_theme_color_override("font_color", color_value)
	lbl_match_result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_match_result.add_theme_constant_override("outline_size", 8)
	lbl_match_result.visible = text_value.strip_edges() != ""


func _bm_matchsim_mobile_font_plus2(ctrl: Control) -> void:
	if ctrl == null:
		return
	if ctrl.has_meta("bm_matchsim_mobile_font_plus2_done"):
		return
	ctrl.set_meta("bm_matchsim_mobile_font_plus2_done", true)
	var fs: int = int(ctrl.get_theme_font_size("font_size"))
	if fs > 0:
		ctrl.add_theme_font_size_override("font_size", fs + 2)


func _bm_matchsim_apply_mobile_texts_plus2() -> void:
	if not _bm_matchsim_is_mobile_layout():
		return
	for ctrl in [lbl_team_dom, lbl_team_ext, lbl_temps, lbl_score, lbl_info, btn_skip]:
		_bm_matchsim_mobile_font_plus2(ctrl as Control)

@onready var stats_end: Control = get_node_or_null("StatsEnd") as Control
@onready var lbl_dom_2p: Label = get_node_or_null("StatsEnd/Grid/LblDom2P") as Label
@onready var lbl_ext_2p: Label = get_node_or_null("StatsEnd/Grid/LblExt2P") as Label
@onready var lbl_dom_3p: Label = get_node_or_null("StatsEnd/Grid/LblDom3P") as Label
@onready var lbl_ext_3p: Label = get_node_or_null("StatsEnd/Grid/LblExt3P") as Label
@onready var lbl_dom_mvp: Label = get_node_or_null("StatsEnd/Grid/LblDomMVP") as Label
@onready var lbl_ext_mvp: Label = get_node_or_null("StatsEnd/Grid/LblExtMVP") as Label
@onready var lbl_title_2p: Label = get_node_or_null("StatsEnd/Grid/LblTitle2P") as Label
@onready var lbl_title_3p: Label = get_node_or_null("StatsEnd/Grid/LblTitle3P") as Label
@onready var lbl_title_mvp: Label = get_node_or_null("StatsEnd/Grid/LblTitleMVP") as Label

@onready var lbl_mvp_match: Label = get_node_or_null("StatsEnd/LblMvpMatch") as Label


const MATCH_DUREE_MINUTES: int = 40
const MAX_ADD_PER_MIN: int = 6        # max points ajoutés par équipe sur 1 minute
const NO_CATCHUP_LAST_MIN: int = 2    # pas de rattrapage brutal sur les 2 dernières minutes


const MATCHSIM_SUMMARY_KEYS := {
"matchsim.summary_comeback_win": true,
	"matchsim.summary_comeback_loss": true,
	"matchsim.summary_win_close": true,
	"matchsim.summary_win_big": true,
	"matchsim.summary_win_control": true,
	"matchsim.summary_loss_close": true,
	"matchsim.summary_loss_big": true,
	"matchsim.summary_loss_normal": true,
	"matchsim.summary_default": true,
}

const MATCHSIM_SUMMARY_ALIASES := {
	# Variantes / typos -> clés officielles
	"matchsim.summary_lose_control": "matchsim.summary_loss_normal",
	"matchsim.summary_lose_close": "matchsim.summary_loss_close",
	"matchsim.summary_lose_big": "matchsim.summary_loss_big",
	"matchsim.summary_win_normal": "matchsim.summary_win_control",

	# Identités (clé officielle -> elle-même)
	"matchsim.summary_win_control": "matchsim.summary_win_control",
	"matchsim.summary_win_close": "matchsim.summary_win_close",
	"matchsim.summary_win_big": "matchsim.summary_win_big",

	"matchsim.summary_loss_normal": "matchsim.summary_loss_normal",
	"matchsim.summary_loss_close": "matchsim.summary_loss_close",
	"matchsim.summary_loss_big": "matchsim.summary_loss_big",

	"matchsim.summary_comeback_win": "matchsim.summary_comeback_win",
	"matchsim.summary_comeback_loss": "matchsim.summary_comeback_loss",
	"matchsim.summary_draw": "matchsim.summary_draw",
	"matchsim.summary_default": "matchsim.summary_default",
}

# BM_SALARY_LEVEL_V1 ---------------------------------------------------------
# Salaires + niveau club (Web-safe, int-only, match-based), anti-double-compte
const K_SALARY: float = 0.12

const XP_WIN: int = 3
const XP_LOSS: int = 1
const XP_DRAW: int = 2

func _ensure_club_wallet_schema(save: Dictionary) -> void:
	# club.level / club.xp / club.titles_total
	if not save.has("club") or typeof(save["club"]) != TYPE_DICTIONARY:
		save["club"] = {}
	var club: Dictionary = save["club"]

	# Migration soft si tu avais des clés legacy
	if not club.has("level"):
		if save.has("club_level"):
			club["level"] = int(save.get("club_level", 1))
		else:
			club["level"] = 1
	if not club.has("xp"):
		if save.has("club_xp"):
			club["xp"] = int(save.get("club_xp", 0))
		else:
			club["xp"] = 0
	if not club.has("titles_total"):
		club["titles_total"] = int(club.get("titles_total", 0))

	# wallet.euros (Web schema) + compat finance.euros existant
	if not save.has("wallet") or typeof(save["wallet"]) != TYPE_DICTIONARY:
		save["wallet"] = {}
	var wallet: Dictionary = save["wallet"]

	# finance (compat) : garantit un dict avant toute lecture/écriture
	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}

	# Source actuelle probable: save["finance"]["euros"]
	var euros_fin: int = 0
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		euros_fin = int((save["finance"] as Dictionary).get("euros", 0))

	# wallet.euros devient la clé canonique Web, mais on garde sync
	if not wallet.has("euros"):
		wallet["euros"] = euros_fin
	# et si finance.euros absent, on le remplit depuis wallet
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		(save["finance"] as Dictionary)["euros"] = int(wallet.get("euros", euros_fin))

func _age_mult(age: int) -> float:
	if age < 23:
		return 0.85
	if age <= 29:
		return 1.15
	if age <= 33:
		return 1.00
	return 0.80

func _compute_player_salary(overall: int, age: int) -> int:
	var o: int = maxi(1, overall)
	var base: float = float(o * o) * K_SALARY * _age_mult(age)
	var s: int = int(round(base))
	return maxi(0, s)

func _get_player_overall_from_dict(pl: Dictionary) -> int:
	# Compat: overall/rating/pondération/ponderation
	if pl.has("overall"):
		return int(pl.get("overall", 70))
	if pl.has("rating"):
		return int(pl.get("rating", 70))
	if pl.has("pondération"):
		return int(round(float(pl.get("pondération", 70))))
	if pl.has("ponderation"):
		return int(round(float(pl.get("ponderation", 70))))
	return 70

func _get_player_age_from_dict(pl: Dictionary) -> int:
	if pl.has("age"):
		return int(pl.get("age", 25))
	return 25

func _ensure_roster_players_minimal(save: Dictionary) -> void:
	# Objectif: roster.players = Array[Dict{id,name,pos,age,overall,salary}]
	if not save.has("roster") or typeof(save["roster"]) != TYPE_DICTIONARY:
		save["roster"] = {}
	var roster: Dictionary = save["roster"]

	var out: Array = []

	# SOURCE PRIORITAIRE = save["players"] (salaires annuels corrects)
	# On resynchronise systématiquement roster.players depuis save["players"]
	# pour éviter les salaires stale après reconnexion / reload.
	if save.has("players") and typeof(save["players"]) == TYPE_ARRAY:
		for pl_raw in save["players"]:
			if typeof(pl_raw) != TYPE_DICTIONARY:
				continue
			var pl: Dictionary = pl_raw

			var pid := str(pl.get("id", ""))
			var overall := _get_player_overall_from_dict(pl)
			var age := _get_player_age_from_dict(pl)
			var pos := str(pl.get("pos", pl.get("poste", "PG"))).strip_edges()

			var name := ""
			for k in ["name", "display_name", "nom", "first_name", "prenom"]:
				if pl.has(k) and str(pl[k]).strip_edges() != "":
					name = str(pl[k]).strip_edges()
					break
			if name == "":
				name = "Player"

			out.append({
				"id": pid,
				"name": name,
				"pos": pos,
				"age": age,
				"overall": overall,
				"salary": int(pl.get("salaire", pl.get("salary", 0))),
			})

		roster["players"] = out
		return

	# SECOURS uniquement si save["players"] absent
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		var by_id: Dictionary = save["players_by_id"]
		for pid in by_id.keys():
			var pl_raw = by_id[pid]
			if typeof(pl_raw) != TYPE_DICTIONARY:
				continue
			var pl: Dictionary = pl_raw
			var overall := _get_player_overall_from_dict(pl)
			var age := _get_player_age_from_dict(pl)
			var pos := str(pl.get("pos", pl.get("poste", "PG"))).strip_edges()
			var name := ""
			for k in ["name","display_name","nom","first_name","prenom"]:
				if pl.has(k) and str(pl[k]).strip_edges() != "":
					name = str(pl[k]).strip_edges()
					break
			if name == "":
				name = "Player"

			out.append({
				"id": str(pid),
				"name": name,
				"pos": pos,
				"age": age,
				"overall": overall,
				"salary": int(pl.get("salaire", pl.get("salary", 0))),
			})

	roster["players"] = out

func _annual_salary_from_any(pd: Dictionary) -> int:
	var raw_salary: int = int(pd.get("salary", pd.get("salaire", 0)))
	if raw_salary > 0:
		return raw_salary

	return 0

func _compute_total_salary_per_match(save: Dictionary) -> int:
	var total_season: int = 0
	var season_number: int = int(save.get("season_number", 1))
	print("[SALARY MATCH][START] season_number=", season_number)
	var inflation_coef: float = 1.0
	if season_number >= 3:
		inflation_coef = pow(1.04, float(season_number - 2))

	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = save["roster"]

		if roster.has("players") and typeof(roster["players"]) == TYPE_ARRAY:
			print("[SALARY MATCH][ROSTER SIZE] ", (roster["players"] as Array).size())
			for row_raw in roster["players"]:
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_raw
				var annual_salary: int = _annual_salary_from_any(row)
				print("[SALARY MATCH][ROW] name=", str(row.get("name", row.get("nom", ""))), " salary=", annual_salary, " raw_salary=", row.get("salary", null), " raw_salaire=", row.get("salaire", null))
				total_season += int(round(float(annual_salary) * inflation_coef))

	print("[SALARY MATCH][TOTAL SEASON] ", total_season)
	var matches_total := 22
	var per_match := int(round(float(total_season) / float(matches_total)))
	print("[SALARY MATCH][PER MATCH] ", per_match)
	return maxi(0, per_match)

func _bm_format_int_spaces(value: int) -> String:
	var neg := value < 0
	var digits := str(abs(value))
	var parts: Array[String] = []
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	if digits.length() > 0:
		parts.insert(0, digits)
	var out := " ".join(parts)
	if neg:
		out = "-" + out
	return out

func _season_reward_fmt_amount(v: int) -> String:
	return "+" + _bm_format_int_spaces(int(v)) + " $"

func _season_reward_play_money_tick_once() -> void:
	var click_path := "res://audio/sfx/click.mp3"
	if not ResourceLoader.exists(click_path):
		return
	var sp := AudioStreamPlayer.new()
	sp.stream = load(click_path)
	sp.volume_db = -8.0
	add_child(sp)
	sp.finished.connect(func(): sp.queue_free())
	sp.play()

func _season_reward_animate_amount(lbl: Label, euros_gain: int) -> void:
	if lbl == null:
		return
	var displayed: int = 0
	var start_ms: int = Time.get_ticks_msec()
	var base_gain: int = max(euros_gain, 10)
	var duration_ms: int = int(round(float(base_gain) / 12000.0 * 1000.0))
	duration_ms = clampi(duration_ms, 2200, 4200)
	var last_tick_ms: int = -9999
	while displayed < euros_gain and is_instance_valid(lbl) and is_inside_tree():
		await get_tree().process_frame
		var elapsed: int = Time.get_ticks_msec() - start_ms
		var ratio: float = clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)
		var target: int = int(floor((float(euros_gain) * ratio) / 10.0)) * 10
		if target > euros_gain:
			target = euros_gain
		if target > displayed:
			displayed = target
			lbl.text = _season_reward_fmt_amount(displayed)
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - last_tick_ms >= 45:
				_season_reward_play_money_tick_once()
				last_tick_ms = now_ms
	lbl.text = _season_reward_fmt_amount(euros_gain)

func _season_reward_animate_tokens(lbl: Label, tokens_gain: int) -> void:
	if lbl == null:
		return
	if tokens_gain <= 0:
		lbl.text = "+0"
		return
	lbl.text = "+0"
	var displayed := 0
	while displayed < tokens_gain:
		displayed += 1
		lbl.text = "+" + str(displayed)
		var tree := get_tree()
		if tree == null:
			break
		await tree.create_timer(0.08).timeout
	lbl.text = "+" + str(tokens_gain)



func _show_season_reward_popup(final_rank: int, euros_gain: int, tokens_gain: int) -> void:
	var already := get_node_or_null("SeasonRewardPopup")
	if already != null:
		return
	if euros_gain <= 0 and tokens_gain <= 0:
		return

	var popup := Control.new()
	popup.name = "SeasonRewardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 235
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(620, 340)
	card.size = Vector2(620, 340)
	card.position = Vector2(
		(get_viewport_rect().size.x - 620.0) * 0.5,
		(get_viewport_rect().size.y - 340.0) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = "Season reward"
	title.position = Vector2(0, 24)
	title.size = Vector2(620, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	card.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Final rank: #" + str(final_rank)
	subtitle.position = Vector2(0, 66)
	subtitle.size = Vector2(620, 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(subtitle)

	var subtitle_money := Label.new()
	subtitle_money.text = "Prize money"
	subtitle_money.position = Vector2(45, 116)
	subtitle_money.size = Vector2(230, 32)
	subtitle_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_money.add_theme_font_size_override("font_size", 22)
	card.add_child(subtitle_money)

	var subtitle_tokens := Label.new()
	subtitle_tokens.text = "Prize tokens"
	subtitle_tokens.position = Vector2(345, 116)
	subtitle_tokens.size = Vector2(230, 32)
	subtitle_tokens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_tokens.add_theme_font_size_override("font_size", 22)
	subtitle_tokens.add_theme_color_override("font_color", Color(1.00, 0.82, 0.30, 1.0))
	card.add_child(subtitle_tokens)

	var amount_lbl := Label.new()
	amount_lbl.text = _season_reward_fmt_amount(0)
	amount_lbl.position = Vector2(45, 158)
	amount_lbl.size = Vector2(230, 54)
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 42)
	amount_lbl.add_theme_color_override("font_color", Color(0.18, 0.72, 0.25, 1.0))
	card.add_child(amount_lbl)

	var tokens_row := HBoxContainer.new()
	tokens_row.position = Vector2(345, 158)
	tokens_row.size = Vector2(230, 54)
	tokens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens_row.add_theme_constant_override("separation", 8)
	card.add_child(tokens_row)

	var tokens_amount_lbl := Label.new()
	tokens_amount_lbl.text = "+0"
	tokens_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tokens_amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tokens_amount_lbl.add_theme_font_size_override("font_size", 42)
	tokens_amount_lbl.add_theme_color_override("font_color", Color(1.00, 0.72, 0.18, 1.0))
	tokens_row.add_child(tokens_amount_lbl)

	var tokens_icon := TextureRect.new()
	tokens_icon.texture = load("res://assets/images/token.png") as Texture2D
	tokens_icon.custom_minimum_size = Vector2(36, 36)
	tokens_icon.size = Vector2(36, 36)
	tokens_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tokens_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tokens_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tokens_row.add_child(tokens_icon)

	var btn := Button.new()
	btn.text = "Close"
	btn.custom_minimum_size = Vector2(180, 52)
	btn.size = Vector2(180, 52)
	btn.position = Vector2(220, 254)
	btn.pressed.connect(func():
		popup.queue_free()
	)
	card.add_child(btn)

	_season_reward_animate_amount(amount_lbl, euros_gain)
	_season_reward_animate_tokens(tokens_amount_lbl, tokens_gain)


func _apply_salaries_and_level(save: Dictionary, did_win: bool, did_draw: bool) -> void:
	_ensure_club_wallet_schema(save)
	_ensure_roster_players_minimal(save)

	var wallet: Dictionary = save["wallet"]
	var club: Dictionary = save["club"]

	# 1) Paiement salaires (1x / match)

	var total_sal := _compute_total_salary_per_match(save)
	PlayerLife.ensure_finance_schema(save)
	# total_depenses est géré une seule fois dans _fin_match() après apply_post_match_to_save()
	wallet["euros"] = int(wallet.get("euros", 0)) - total_sal

	# Sync compat finance.euros
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		(save["finance"] as Dictionary)["euros"] = int(wallet["euros"])

	# 2) XP totale + niveau centralisé dans PlayerLife
	var xp_add := XP_LOSS
	if did_draw:
		xp_add = XP_DRAW
	elif did_win:
		xp_add = XP_WIN

	var PL = load("res://scripts/PlayerLife.gd")
	PL.add_club_xp(save, xp_add, "match_result")
# ---------------------------------------------------------------------------

var minute: int = 0
var score_dom: int = 0
var score_ext: int = 0
var match_fini: bool = false
var _live_comment_token: int = 0
var _live_comment_clear_minute: int = -1
var _live_comment_minute_10_shown: bool = false
var _live_comment_minute_25_shown: bool = false

var _score_final_dom: int = 0
var _score_final_ext: int = 0
var _timeline_dom: Array[int] = []
var _timeline_ext: Array[int] = []
var _team_dom_name: String = ""
var _team_ext_name: String = ""

var _user_is_home: bool = true
var _user_team_name: String = ""
var _opp_team_name: String = ""


func _is_home_arena_selected_for_match(save: Dictionary) -> bool:
	var arena_any: Variant = save.get("arena_identity", {})
	if typeof(arena_any) != TYPE_DICTIONARY:
		return false
	var arena := arena_any as Dictionary
	return bool(arena.get("home_arena_selected", false))


func _apply_home_arena_background_if_needed() -> void:
	if not _user_is_home:
		return

	var save := PlayerLife.load_savegame()
	if not _is_home_arena_selected_for_match(save):
		return

	var bg := get_node_or_null("BG") as TextureRect
	if bg == null:
		return
	if not ResourceLoader.exists(HOME_ARENA_MATCH_BACKGROUND_PATH):
		return

	bg.texture = load(HOME_ARENA_MATCH_BACKGROUND_PATH) as Texture2D


func _ensure_translations_loaded() -> void:
	var key_test := "matchsim.summary_loss_close"
	var paths := [
		"res://i18n/translations.fr.tres",
		"res://i18n/translations.en.tres",
		"res://i18n/translations.es.tres",
		"res://i18n/translations.it.tres",
		"res://i18n/translations.pt.tres",
	]
	for path in paths:
		var t: Translation = load(path) as Translation
		if t == null:
			print("[MATCHSIM][I18N] load FAIL ", path)
			continue
		# Preuve: ce que contient réellement l'objet Translation
		var msg := t.get_message(key_test)
		print("[MATCHSIM][I18N] loaded ", path, " locale=", t.locale, " has_key=", (msg != ""), " sample=", msg)
		TranslationServer.add_translation(t)


func _bm_funnel_profile_uuid() -> String:
	var profile_uuid: String = str(Session.profile_uuid).strip_edges()
	if profile_uuid == "":
		var active_profile_id: String = str(ProfileManager.get_active_profile_id()).strip_edges()
		if active_profile_id != "" and active_profile_id != "default":
			profile_uuid = active_profile_id
	return profile_uuid


func _bm_schedule_generic_funnel_retry(event_name: String, flag_name: String, meta: Dictionary, attempt: int) -> void:
	var retry_timer := get_tree().create_timer(1.0)
	retry_timer.timeout.connect(func() -> void:
		_bm_send_generic_funnel_event(event_name, flag_name, meta, attempt + 1)
	, CONNECT_ONE_SHOT)


func _bm_send_generic_funnel_event(event_name: String, flag_name: String, meta: Dictionary, attempt: int = 0) -> void:
	var save: Dictionary = PlayerLife.load_savegame()
	if bool(save.get(flag_name, false)):
		return

	var profile_uuid := _bm_funnel_profile_uuid()
	if profile_uuid == "":
		if attempt < BM_GENERIC_FUNNEL_MAX_RETRIES:
			_bm_schedule_generic_funnel_retry(event_name, flag_name, meta, attempt)
		return

	var request := HTTPRequest.new()
	request.timeout = 8.0
	get_tree().root.add_child(request)
	var request_url := BM_GENERIC_FUNNEL_URL
	var payload_data := {
		"profile_uuid": profile_uuid,
		"event_name": event_name,
		"team_name": str(save.get("team_name", save.get("club_name", ""))),
		"meta": meta,
	}
	if event_name == "first-match-started":
		request_url = "https://api.basketmanager-game.com/v1/funnel/first-match-started"
		payload_data = {"profile_uuid": profile_uuid}
	elif event_name == "first-match-finished":
		request_url = "https://api.basketmanager-game.com/v1/funnel/first-match-finished"
		payload_data = {"profile_uuid": profile_uuid}
	var payload := JSON.stringify(payload_data)

	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		var sent_ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		request.queue_free()
		if sent_ok:
			var fresh_save: Dictionary = PlayerLife.load_savegame()
			fresh_save[flag_name] = true
			PlayerLife.write_savegame(fresh_save)
		elif attempt < BM_GENERIC_FUNNEL_MAX_RETRIES:
			_bm_schedule_generic_funnel_retry(event_name, flag_name, meta, attempt)
	, CONNECT_ONE_SHOT)

	var request_error := request.request(
		request_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		payload
	)
	if request_error != OK:
		request.queue_free()
		if attempt < BM_GENERIC_FUNNEL_MAX_RETRIES:
			_bm_schedule_generic_funnel_retry(event_name, flag_name, meta, attempt)


func _bm_track_match_start_milestones() -> void:
	var save: Dictionary = PlayerLife.load_savegame()
	var season_number := int(save.get("season_number", 1))
	var completed_matches := int(save.get("season_round", 0))
	var match_number := completed_matches + 1
	var meta := {"season_number": season_number, "match_number": match_number}

	if season_number == 1 and completed_matches == 1:
		_bm_send_generic_funnel_event("second-match-started", "funnel_second_match_started_sent", meta)
	elif season_number == 1 and completed_matches == 10:
		_bm_send_generic_funnel_event("eleventh-match-started", "funnel_eleventh_match_started_sent", meta)

	if season_number == 2 and completed_matches == 0:
		_bm_send_generic_funnel_event("season2-started", "funnel_season2_started_sent", meta)
	elif season_number == 2 and completed_matches == 9:
		_bm_send_generic_funnel_event("season2-match10", "funnel_season2_match10_sent", meta)


func _bm_track_first_match_started() -> void:
	var save: Dictionary = PlayerLife.load_savegame()
	var season_number := int(save.get("season_number", 1))
	var match_number := int(save.get("season_round", 0)) + 1
	var meta := {"season_number": season_number, "match_number": match_number}

	if season_number == 1 and match_number == 1:
		_bm_send_generic_funnel_event("first-match-started", "funnel_first_match_started_sent", meta)


func _ready() -> void:
	if timer != null:
		timer.stop()
		timer.autostart = false

	_bm_apply_i18n_btn_retour()
	randomize()
	_ensure_translations_loaded()
	print("[MATCHSIM][I18N] test summary_loss_close=", tr("matchsim.summary_loss_close"))
	print("[MATCHSIM][I18N] locale=", TranslationServer.get_locale())
	print("[MATCHSIM][I18N] test end_prefix=", tr("matchsim.end_prefix"))
	print("[MATCHSIM][I18N] test loss_close=", tr("matchsim.summary_loss_close"))

	# UI init
	lbl_info.text = ""
	if info_panel != null:
		info_panel.visible = false
	if stats_end != null:
		stats_end.visible = false

	print("[DBG] before _apply_stats_titles")
	_apply_stats_titles()
	print("[DBG] after _apply_stats_titles")

	print("[DBG] before _apply_end_stats_transparency")
	_apply_end_stats_transparency()
	print("[DBG] after _apply_end_stats_transparency")

	print("[DBG] before _center_stats_end_horizontally")
	_center_stats_end_horizontally()
	print("[DBG] after _center_stats_end_horizontally")
	if lbl_info != null:
		_bm_lbl_info_base_position = lbl_info.position
		_bm_lbl_info_base_size = lbl_info.size
		_bm_lbl_info_base_font_size = int(lbl_info.get_theme_font_size("font_size"))

	btn_retour.disabled = true
	if not btn_retour.pressed.is_connected(_on_btn_retour_pressed):
		btn_retour.pressed.connect(_on_btn_retour_pressed)

	_bm_ensure_current_lineup_button()

	# BtnSkip (fast-forward fin de match)
	if btn_skip != null:
		btn_skip.visible = false
		btn_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_skip.text = tr("matchsim.btn_skip")
		if not btn_skip.pressed.is_connected(_on_btn_skip_gate_pressed):
			btn_skip.pressed.connect(_on_btn_skip_gate_pressed)
	_bm_matchsim_apply_mobile_texts_plus2()
	call_deferred("_bm_matchsim_apply_mobile_layout")
	call_deferred("_bm_place_current_lineup_button")


	# Timer (1 sec = 1 minute)
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.autostart = false
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

		print("[DBG READY] before _prepare_match_like_py")
	_prepare_match_like_py()
	print("[DBG READY] after _prepare_match_like_py")

	print("[DBG READY] before _init_team_names")
	_init_team_names()
	print("[DBG READY] after _init_team_names")
	_apply_home_arena_background_if_needed()

	print("[DBG READY] before _fade_in_scoreboard")
	_fade_in_scoreboard()
	print("[DBG READY] after _fade_in_scoreboard")

	print("[DBG READY] before _update_ui")
	_update_ui()
	print("[DBG READY] after _update_ui")
	_bm_track_match_start_milestones()

	print("[DBG READY] before match intro countdown")
	await _bm_play_match_intro_countdown()
	print("[DBG READY] before timer.start")
	timer.start()
	call_deferred("_bm_show_match_progress_info_after_start")
	_bm_track_first_match_started()
	if _bm_should_show_skip_final_result_button():
		_bm_style_btn_skip_final_result_active()
	print("[DBG READY] after timer.start")

func _bm_play_match_intro_countdown() -> void:
	_match_progress_info_after_countdown = ""
	var match_progress_save: Dictionary = PlayerLife.load_savegame()
	if typeof(match_progress_save) == TYPE_DICTIONARY and not bool(match_progress_save.get("match_progress_info_seen", false)) and int(match_progress_save.get("season_number", 1)) == 1 and int(match_progress_save.get("season_round", 0)) == 0:
		match_progress_save["match_progress_info_seen"] = true
		PlayerLife.write_savegame(match_progress_save)
		_match_progress_info_after_countdown = tr("matchsim.progress_info.line1") + "\n" + tr("matchsim.progress_info.line2")

	var overlay := Control.new()
	overlay.name = "MatchIntroCountdown"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 5000
	add_child(overlay)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.28)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dark)

	var ball := TextureRect.new()
	ball.texture = load("res://assets/images/ballon.png") as Texture2D
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.size = Vector2(86, 86)
	ball.position = Vector2((get_viewport_rect().size.x - ball.size.x) * 0.5, get_viewport_rect().size.y * 0.5 + 30.0)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ball)

	var count_lbl := Label.new()
	count_lbl.text = "3"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.size = Vector2(240, 160)
	count_lbl.position = Vector2((get_viewport_rect().size.x - count_lbl.size.x) * 0.5, get_viewport_rect().size.y * 0.5 - 150.0)
	count_lbl.add_theme_font_size_override("font_size", 92)
	count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 0.95))
	count_lbl.add_theme_constant_override("outline_size", 8)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(count_lbl)


	for n in ["3", "2", "1", "GO !"]:
		count_lbl.text = n
		count_lbl.add_theme_font_size_override("font_size", 78 if n == "GO !" else 92)
		count_lbl.scale = Vector2(0.82, 0.82)
		count_lbl.modulate.a = 0.0
		ball.position.y = get_viewport_rect().size.y * 0.5 + 30.0

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(count_lbl, "modulate:a", 1.0, 0.10)
		tw.tween_property(count_lbl, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ball, "position:y", get_viewport_rect().size.y * 0.5 - 16.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(ball, "position:y", get_viewport_rect().size.y * 0.5 + 30.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.54).timeout

	await get_tree().create_timer(0.16).timeout

	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.20).timeout

	overlay.queue_free()
	await get_tree().process_frame


func _bm_show_match_progress_info_after_start() -> void:
	var match_progress_info_text := _match_progress_info_after_countdown.strip_edges()
	_match_progress_info_after_countdown = ""
	if match_progress_info_text == "":
		return

	var overlay := Control.new()
	overlay.name = "MatchProgressInfoAfterStart"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 5001
	add_child(overlay)

	var progress_info_lbl := Label.new()
	progress_info_lbl.text = match_progress_info_text
	progress_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_info_lbl.size = Vector2(760, 82)
	progress_info_lbl.position = Vector2((get_viewport_rect().size.x - progress_info_lbl.size.x) * 0.5, get_viewport_rect().size.y * 0.5 - 111.0)
	progress_info_lbl.add_theme_font_size_override("font_size", 25)
	progress_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28, 1.0))
	progress_info_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.20, 1.0))
	progress_info_lbl.add_theme_constant_override("outline_size", 6)
	progress_info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(progress_info_lbl)

	await get_tree().create_timer(4.16).timeout
	if not is_instance_valid(overlay):
		return
	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.20).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()


func _bm_get_active_coach_match_bonus(save_override: Dictionary = {}) -> float:
	var save: Dictionary = save_override if not save_override.is_empty() else PlayerLife.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return 0.0
	if not save.has("coachs") or typeof(save["coachs"]) != TYPE_DICTIONARY:
		return 0.0

	var coachs: Dictionary = save["coachs"] as Dictionary
	var active_coach_id: String = str(coachs.get("active", "")).strip_edges()

	match active_coach_id:
		"coach_junior":
			return 0.8
		"coach_confirme":
			return 1.6
		"coach_elite":
			return 2.4
		_:
			return 0.0


func _bm_get_saved_match_crest_id(save: Dictionary) -> String:
	var cid: String = str(save.get("club_crest_id", save.get("selected_crest_id", ""))).strip_edges()
	if cid == "" and save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		cid = str((save["roster"] as Dictionary).get("selected_crest_id", "")).strip_edges()
	return cid


func _bm_get_match_crest_id_for_team(save: Dictionary, team_name: String) -> String:
	var tn: String = team_name.strip_edges()
	if tn != "" and save.has("team_crest_map") and typeof(save["team_crest_map"]) == TYPE_DICTIONARY:
		var m: Dictionary = save["team_crest_map"] as Dictionary
		if m.has(tn):
			var mapped: String = str(m.get(tn, "")).strip_edges()
			if mapped != "":
				return mapped
	return _bm_get_saved_match_crest_id(save)


func _bm_apply_scoreboard_crest_to_label(icon_name: String, team_name: String, target_lbl: Label, is_right_aligned: bool, save: Dictionary) -> void:
	if scoreboard_panel == null or target_lbl == null:
		return

	var icon := get_node_or_null("ScoreBoardPanel/" + icon_name) as TextureRect
	var crest_path: String = PlayerLife.get_display_crest_path(save, team_name)
	if crest_path == "":
		if icon != null:
			icon.queue_free()
		return
	if not ResourceLoader.exists(crest_path):
		return

	if icon == null:
		icon = TextureRect.new()
		icon.name = icon_name
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 20
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		scoreboard_panel.add_child(icon)

	icon.texture = load(crest_path)
	icon.visible = true
	icon.size = Vector2(42.6, 42.6)

	var x: float = target_lbl.position.x + 2.0
	var y: float = target_lbl.position.y + (target_lbl.size.y - icon.size.y) * 0.5
	icon.position = Vector2(x, y)


func _bm_update_scoreboard_club_crest(save_override: Dictionary = {}) -> void:
	if scoreboard_panel == null:
		return

	var save: Dictionary = save_override if not save_override.is_empty() else PlayerLife.load_savegame()
	_bm_apply_scoreboard_crest_to_label("ScoreboardDomCrestIcon", _team_dom_name, lbl_team_dom, false, save)
	_bm_apply_scoreboard_crest_to_label("ScoreboardExtCrestIcon", _team_ext_name, lbl_team_ext, true, save)



func _prepare_match_like_py() -> void:
	var base_score: int = randi_range(70, 90)
	var save: Dictionary = PlayerLife.load_savegame()

	var mean_dom: float = _estimate_strength_dom(save)
	var mean_ext: float = _estimate_strength_ext(save)

	var coach_bonus: float = _bm_get_active_coach_match_bonus(save)
	if coach_bonus > 0.0:
		if _user_is_home:
			mean_dom += coach_bonus
		else:
			mean_ext += coach_bonus
		print("[COACHS][MATCH_BONUS] coach_bonus=", snapped(coach_bonus, 0.1), " user_is_home=", _user_is_home)

	var strength_gap: float = clampf(mean_dom - mean_ext, -12.0, 12.0)
	var boost_points: int = int(round(strength_gap * 1.20))

	_score_final_dom = clampi(base_score + boost_points + randi_range(-5, 5), 50, 120)
	_score_final_ext = clampi(base_score - boost_points + randi_range(-5, 5), 50, 120)

	if _score_final_dom == _score_final_ext:
		if boost_points >= 0:
			_score_final_dom += 1
		else:
			_score_final_ext += 1

	print("[MATCHSIM][STRENGTH] dom=", snapped(mean_dom, 0.1), " ext=", snapped(mean_ext, 0.1), " gap=", snapped(strength_gap, 0.1), " boost=", boost_points)

	_generate_timeline_scores(_score_final_dom, _score_final_ext, MATCH_DUREE_MINUTES)

func _bm_get_effective_tir(pd: Dictionary) -> float:
	var tir: float = float(pd.get("tir", pd.get("precision", 70)))
	if tir <= 1.5:
		tir *= 100.0
	var motivation: float = float(pd.get("motivation", 75))
	var fatigue: float = float(pd.get("fatigue", 0))
	return tir * (0.75 + motivation / 200.0) * (1.0 - fatigue / 200.0)

func _bm_get_coach_auto_score(pd: Dictionary, active_coach_id: String = "") -> float:
	var rating: float = float(pd.get("overall", pd.get("rating", pd.get("pondération", pd.get("ponderation", 70)))))
	var motivation: float = float(pd.get("motivation", 75))
	var fatigue: float = float(pd.get("fatigue", 0))
	var attack_bonus: float = (_bm_get_effective_tir(pd) - 70.0) * 0.18

	match active_coach_id:
		"coach_junior":
			return rating + attack_bonus + motivation * 0.04 - fatigue * 0.06
		"coach_confirme":
			return rating + attack_bonus + motivation * 0.10 - fatigue * 0.18
		"coach_elite":
			return rating + attack_bonus + motivation * 0.14 - fatigue * 0.28
		_:
			return rating + attack_bonus + motivation * 0.08 - fatigue * 0.12

func _bm_get_effective_played_ids(save: Dictionary) -> Array:
	var out: Array = []
	if not save.has("roster") or typeof(save["roster"]) != TYPE_DICTIONARY:
		return out
	var roster: Dictionary = save["roster"] as Dictionary
	var match_ids: Array = []
	var selected_ids: Array = []
	if roster.has("match_selected_ids") and typeof(roster["match_selected_ids"]) == TYPE_ARRAY:
		match_ids = (roster["match_selected_ids"] as Array).duplicate()
	if roster.has("selected_ids") and typeof(roster["selected_ids"]) == TYPE_ARRAY:
		selected_ids = (roster["selected_ids"] as Array).duplicate()
	var season_round_now: int = int(save.get("season_round", 0))
	var season_number_now: int = int(save.get("season_number", 1))
	var match_selection_unlocked := season_round_now >= 5 if season_number_now <= 1 else season_round_now >= 0
	var active_coach_id: String = ""
	if save.has("coachs") and typeof(save["coachs"]) == TYPE_DICTIONARY:
		var coachs_pre: Dictionary = save["coachs"] as Dictionary
		active_coach_id = str(coachs_pre.get("active", "")).strip_edges()

	if match_ids.size() == 8:
		return match_ids
	if match_selection_unlocked:
		return []
	if active_coach_id == "":
		return selected_ids

	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return []
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var ranked: Array = []
	for pid in selected_ids:
		var key := str(pid)
		if not by_id.has(key) or typeof(by_id[key]) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = by_id[key] as Dictionary
		ranked.append({
			"id": pid,
			"score": _bm_get_coach_auto_score(pd, active_coach_id)
		})
	if ranked.is_empty():
		return []
	ranked.sort_custom(func(a, b): return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0)))
	for row in ranked:
		out.append((row as Dictionary).get("id"))
		if out.size() >= 8:
			break
	print("[COACHS][AUTO_COMPO] coach=", active_coach_id, " selected_pool=", selected_ids.size(), " played_ids=", out)
	return out

func _get_selected_team_rating_average(save_override: Dictionary = {}) -> float:
	var save: Dictionary = save_override if not save_override.is_empty() else PlayerLife.load_savegame()

	var players: Dictionary = {}
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		players = save["players_by_id"] as Dictionary

	var selected: Array = _bm_get_effective_played_ids(save)

	var total: float = 0.0
	var count: int = 0

	for pid in selected:
		var key := str(pid)
		if not players.has(key):
			continue
		var p = players[key]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = p as Dictionary
		var rating: float = float(pd.get("overall", pd.get("rating", pd.get("pondération", pd.get("ponderation", 70)))))
		var attack_bonus: float = (_bm_get_effective_tir(pd) - 70.0) * 0.18
		total += rating + attack_bonus
		count += 1

	return total / float(count) if count > 0 else 72.0

func _get_opponent_team_rating_estimate(save_override: Dictionary = {}) -> float:
	var save: Dictionary = save_override if not save_override.is_empty() else PlayerLife.load_savegame()
	var my_rating: float = _get_selected_team_rating_average(save)

	var ss := get_node_or_null("/root/SeasonState")
	var my_name := str(save.get("team_name", "")).strip_edges()
	var my_rank := 8

	if ss != null and ss.has_method("get_current_club_rank"):
		my_rank = int(ss.call("get_current_club_rank", my_name))

	var opp_rating := my_rating

	if my_rank <= 3:
		opp_rating = my_rating - 1.5
	elif my_rank <= 6:
		opp_rating = my_rating - 0.5
	elif my_rank <= 9:
		opp_rating = my_rating + 0.5
	else:
		opp_rating = my_rating + 1.5

	return clampf(opp_rating, 68.0, 82.0)

func _estimate_strength_dom(save_override: Dictionary = {}) -> float:
	return _get_selected_team_rating_average(save_override) if _user_is_home else _get_opponent_team_rating_estimate(save_override)

func _estimate_strength_ext(save_override: Dictionary = {}) -> float:
	return _get_opponent_team_rating_estimate(save_override) if _user_is_home else _get_selected_team_rating_average(save_override)

func _generate_timeline_scores(target_dom: int, target_ext: int, duree: int) -> void:
	_timeline_dom.clear()
	_timeline_ext.clear()

	var inc_dom: Array = _build_weighted_increments(target_dom, duree)
	var inc_ext: Array = _build_weighted_increments(target_ext, duree)

	var dom: int = 0
	var ext: int = 0

	for i in range(duree):
		dom += int(inc_dom[i])
		ext += int(inc_ext[i])
		_timeline_dom.append(dom)
		_timeline_ext.append(ext)


func _build_weighted_increments(target: int, duree: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var first_len: int = maxi(1, int(floor(float(duree) / 2.0)))
	var second_len: int = maxi(0, duree - first_len)

	# mi-temps crédible : ~46% à 54% du score final
	var first_target: int = clampi(int(round(float(target) * rng.randf_range(0.46, 0.54))), 0, target)
	var second_target: int = target - first_target

	var weights_first: Array = _bm_build_half_weights(first_len, rng)
	var weights_second: Array = _bm_build_half_weights(second_len, rng)

	var inc_first: Array = _bm_allocate_points_with_weights(first_target, weights_first, rng)
	var inc_second: Array = _bm_allocate_points_with_weights(second_target, weights_second, rng)

	var out: Array = []
	for v in inc_first:
		out.append(int(v))
	for v in inc_second:
		out.append(int(v))

	while out.size() < duree:
		out.append(0)

	return out


func _bm_build_half_weights(count: int, rng: RandomNumberGenerator) -> Array:
	var weights: Array = []
	if count <= 0:
		return weights

	var run_start: int = -1
	var run_len: int = 0
	if count >= 4 and rng.randf() < 0.75:
		run_start = rng.randi_range(0, maxi(0, count - 3))
		run_len = mini(rng.randi_range(2, 4), count - run_start)

	var lull_start: int = -1
	var lull_len: int = 0
	if count >= 4 and rng.randf() < 0.65:
		lull_start = rng.randi_range(0, maxi(0, count - 2))
		lull_len = mini(rng.randi_range(1, 2), count - lull_start)

	for i in range(count):
		var w: float = rng.randf_range(0.90, 1.10)

		if run_start >= 0 and i >= run_start and i < run_start + run_len:
			w *= 1.65

		if lull_start >= 0 and i >= lull_start and i < lull_start + lull_len:
			w *= 0.40

		# toute fin de période un peu plus active
		if i >= count - 2:
			w *= 1.10

		weights.append(maxf(0.05, w))

	return weights


func _bm_allocate_points_with_weights(target: int, weights: Array, rng: RandomNumberGenerator) -> Array:
	var incs: Array = []
	for _i in range(weights.size()):
		incs.append(0)

	var remaining: int = target
	while remaining > 0:
		var total_w: float = 0.0
		for i in range(weights.size()):
			if int(incs[i]) < MAX_ADD_PER_MIN:
				total_w += float(weights[i])

		if total_w <= 0.0:
			break

		var pick: float = rng.randf_range(0.0, total_w)
		var acc: float = 0.0
		var chosen: int = -1

		for i in range(weights.size()):
			if int(incs[i]) >= MAX_ADD_PER_MIN:
				continue
			acc += float(weights[i])
			if pick <= acc:
				chosen = i
				break

		if chosen < 0:
			chosen = maxi(0, weights.size() - 1)

		incs[chosen] = int(incs[chosen]) + 1
		remaining -= 1

	# sécurité ultra-fine si cap atteint partout (très rare)
	if remaining > 0:
		for i in range(incs.size()):
			if remaining <= 0:
				break
			var can_add: int = maxi(0, MAX_ADD_PER_MIN - int(incs[i]))
			if can_add <= 0:
				continue
			var add_here: int = mini(can_add, remaining)
			incs[i] = int(incs[i]) + add_here
			remaining -= add_here

	return incs


func _init_team_names() -> void:

	# Nom équipe depuis savegame (clé réelle = team_name)
	var user_name := tr("matchsim.team_default")
	var save := PlayerLife.load_savegame()

	if typeof(save) == TYPE_DICTIONARY:
		# ✅ priorité : team_name (création équipe)
		var n := str(save.get("team_name", "")).strip_edges()
		if n != "":
			user_name = n
		else:
			# fallback : club_name si présent (cas futur)
			n = str(save.get("club_name", "")).strip_edges()
			if n != "":
				user_name = n

	_user_team_name = user_name

	# Adversaire + home/away via SeasonState
	var opp_name := tr("matchsim.opponent_default")
	var user_home := true

	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss != null:
		var r := int(save.get("season_round", 0))

		# ✅ Calendrier round-robin si dispo
		if ss.has_method("get_user_fixture_for_round"):
			var fx: Dictionary = ss.call("get_user_fixture_for_round", user_name, r)
			if typeof(fx) == TYPE_DICTIONARY and fx.size() > 0:
				user_home = bool(fx.get("user_is_home", true))
				opp_name = str(fx.get("opponent", opp_name)).strip_edges()
			else:
				# fallback ancien
				user_home = (r % 2 == 0)
				if ss.has_method("compute_next_opponent_name"):
					var v := str(ss.call("compute_next_opponent_name", user_name)).strip_edges()
					if v != "":
						opp_name = v
		else:
			# fallback ancien si pas de fixture
			user_home = (r % 2 == 0)
			if ss.has_method("compute_next_opponent_name"):
				var v2 := str(ss.call("compute_next_opponent_name", user_name)).strip_edges()
				if v2 != "":
					opp_name = v2

	_user_is_home = user_home
	_opp_team_name = opp_name

	# Mapping visuel : RECEVEUR à gauche (DOM), VISITEUR à droite (EXT)
	var dom_name := ""
	var ext_name := ""

	if _user_is_home:
		dom_name = _user_team_name
		ext_name = _opp_team_name
	else:
		dom_name = _opp_team_name
		ext_name = _user_team_name

	_team_dom_name = dom_name
	_team_ext_name = ext_name

	print("[DBG NAMES] dom_name=", dom_name, " ext_name=", ext_name, " lbl_team_dom=", lbl_team_dom, " lbl_team_ext=", lbl_team_ext)
	if lbl_team_dom != null:
		lbl_team_dom.text = "       " + dom_name
		lbl_team_dom.add_theme_font_size_override("font_size", int(lbl_team_dom.get_theme_font_size("font_size")) + 8)
	if lbl_team_ext != null:
		lbl_team_ext.text = "       " + ext_name
		lbl_team_ext.add_theme_font_size_override("font_size", int(lbl_team_ext.get_theme_font_size("font_size")) + 8)
		if scoreboard_panel != null:
			var right_margin := 20.0
			var ext_text_w: float = lbl_team_ext.get_combined_minimum_size().x
			lbl_team_ext.position.x = scoreboard_panel.size.x - right_margin - ext_text_w
			lbl_team_ext.size.x = ext_text_w
	_bm_update_scoreboard_club_crest(save)
func _fade_in_scoreboard() -> void:
	# Fade-in doux (0.35s) du scoreboard + info panel
	if scoreboard_panel == null or info_panel == null:
		return

	scoreboard_panel.modulate.a = 0.0
	info_panel.visible = lbl_info != null and lbl_info.text.strip_edges() != ""
	info_panel.modulate.a = 0.0

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(scoreboard_panel, "modulate:a", 1.0, 1.30)
	tw.parallel().tween_property(info_panel, "modulate:a", 1.0, 1.30)

func _on_timer_timeout() -> void:
	if match_fini:
		return

	minute += 1

	if minute <= _timeline_dom.size():
		score_dom = int(_timeline_dom[minute - 1])
	if minute <= _timeline_ext.size():
		score_ext = int(_timeline_ext[minute - 1])

	_update_ui()
	_bm_clear_expired_live_match_comment()
	_bm_maybe_show_live_match_comment()

	if minute >= MATCH_DUREE_MINUTES:
		_fin_match()

func _update_ui() -> void:
	print("[DBG UI] lbl_temps=", lbl_temps, " lbl_score=", lbl_score, " minute=", minute, " dom=", score_dom, " ext=", score_ext)
	if lbl_temps != null:
		lbl_temps.text = str(minute) + "'"
	if lbl_score != null:
		lbl_score.text = str(score_dom) + " - " + str(score_ext)

func _bm_clear_live_match_comment() -> void:
	_live_comment_token += 1
	_live_comment_clear_minute = -1
	if lbl_info != null and not match_fini:
		lbl_info.text = ""
	if info_panel != null and not match_fini:
		info_panel.visible = false

func _bm_clear_expired_live_match_comment() -> void:
	if match_fini:
		return
	if _live_comment_clear_minute > 0 and minute >= _live_comment_clear_minute:
		_bm_clear_live_match_comment()

func _bm_pick_live_match_comment_variant(key_a: String, key_b: String) -> String:
	var keys := [key_a, key_b]
	return tr(str(keys[randi() % keys.size()]))

func _bm_pick_live_match_comment(trigger_minute: int) -> String:
	var save: Dictionary = PlayerLife.load_savegame()
	var gap: float = _estimate_strength_dom() - _estimate_strength_ext()
	if not _user_is_home:
		gap = -gap
	var user_score: int = int(score_dom if _user_is_home else score_ext)
	var opp_score: int = int(score_ext if _user_is_home else score_dom)
	var score_margin: int = abs(user_score - opp_score)
	var avg_motivation: float = 0.0
	var avg_fatigue: float = 0.0
	var count: int = 0
	var played_ids: Array = _bm_get_effective_played_ids(save)
	var by_id: Dictionary = {}
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		by_id = save["players_by_id"] as Dictionary
	for raw_id in played_ids:
		var sid := str(raw_id).strip_edges()
		if sid == "":
			continue
		var key := str(int(round(float(sid))))
		if not by_id.has(key) or typeof(by_id[key]) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = by_id[key] as Dictionary
		avg_motivation += float(pd.get("motivation", 50))
		avg_fatigue += float(pd.get("fatigue", 0))
		count += 1
	if count > 0:
		avg_motivation /= float(count)
		avg_fatigue /= float(count)

	if trigger_minute == 10:
		if gap >= 1.5:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute10.lineup_positive", "matchsim.live.minute10.lineup_positive_2")
		if gap <= -1.5:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute10.lineup_negative", "matchsim.live.minute10.lineup_negative_2")
		if avg_motivation >= 78.0:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute10.motivation_positive", "matchsim.live.minute10.motivation_positive_2")
		return _bm_pick_live_match_comment_variant("matchsim.live.minute10.neutral", "matchsim.live.minute10.neutral_2")

	if trigger_minute == 25:
		if score_margin <= 5 and abs(gap) < 1.5:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute25.close", "matchsim.live.minute25.close_2")
		if avg_fatigue >= 18.0:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute25.fatigue", "matchsim.live.minute25.fatigue_2")
		if avg_motivation <= 60.0:
			return _bm_pick_live_match_comment_variant("matchsim.live.minute25.motivation_low", "matchsim.live.minute25.motivation_low_2")
		return _bm_pick_live_match_comment_variant("matchsim.live.minute25.neutral", "matchsim.live.minute25.neutral_2")

	return ""

func _bm_show_live_match_comment(trigger_minute: int) -> void:
	if match_fini or lbl_info == null:
		return
	var text_value := _bm_pick_live_match_comment(trigger_minute).strip_edges()
	print("[LIVE_PROBE] show before_write trigger_minute=", trigger_minute, " minute=", minute, " text_value=", text_value, " text_empty=", text_value == "", " lbl_info_null=", lbl_info == null, " info_panel_null=", info_panel == null)
	if text_value == "":
		return
	_live_comment_token += 1
	_live_comment_clear_minute = minute + 4
	var display_text := "“" + text_value + "”"
	lbl_info.text = display_text
	print("[LIVE_PROBE] show after_write lbl_text=", lbl_info.text, " text_matches=", lbl_info.text == display_text, " lbl_visible=", lbl_info.visible, " lbl_visible_tree=", lbl_info.is_visible_in_tree(), " lbl_global_position=", lbl_info.global_position, " lbl_size=", lbl_info.size, " viewport_size=", get_viewport_rect().size)
	var live_info_pos := lbl_info.position
	lbl_info.visible = true
	lbl_info.modulate.a = 0.0
	lbl_info.position = live_info_pos + Vector2(0.0, 6.0)
	lbl_info.z_index = 20
	lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl_info.add_theme_constant_override("outline_size", 8)
	lbl_info.add_theme_font_size_override("font_size", 34)
	var live_panel_pos := Vector2.ZERO
	if info_panel != null:
		info_panel.visible = true
		info_panel.modulate.a = 0.0
		info_panel.z_index = 19
		lbl_info.z_index = 20
		info_panel.self_modulate = Color(0, 0, 0, 0.82)
		live_panel_pos = live_info_pos - Vector2(28.0, 18.0)
		info_panel.position = live_panel_pos + Vector2(0.0, 6.0)
		info_panel.size = lbl_info.size + Vector2(56.0, 78.0)
	var live_tw := create_tween()
	live_tw.set_parallel(true)
	live_tw.tween_property(lbl_info, "modulate:a", 1.0, 0.16)
	live_tw.tween_property(lbl_info, "position", live_info_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if info_panel != null:
		live_tw.tween_property(info_panel, "modulate:a", 1.0, 0.16)
		live_tw.tween_property(info_panel, "position", live_panel_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	call_deferred("_bm_live_probe_next_frame", display_text)

func _bm_live_probe_next_frame(expected_text: String) -> void:
	print("[LIVE_PROBE] next_frame lbl_text=", lbl_info.text if lbl_info != null else "<null>", " text_matches=", lbl_info != null and lbl_info.text == expected_text, " lbl_visible=", lbl_info.visible if lbl_info != null else false, " lbl_visible_tree=", lbl_info.is_visible_in_tree() if lbl_info != null else false, " info_visible=", info_panel.visible if info_panel != null else false, " info_visible_tree=", info_panel.is_visible_in_tree() if info_panel != null else false, " lbl_global_position=", lbl_info.global_position if lbl_info != null else Vector2.ZERO, " lbl_size=", lbl_info.size if lbl_info != null else Vector2.ZERO)

func _bm_maybe_show_live_match_comment() -> void:
	print("[LIVE_PROBE] maybe minute=", minute, " match_fini=", match_fini, " minute10_shown=", _live_comment_minute_10_shown, " minute25_shown=", _live_comment_minute_25_shown)
	if match_fini:
		return
	if minute >= 10 and not _live_comment_minute_10_shown:
		_live_comment_minute_10_shown = true
		_bm_show_live_match_comment(10)
	elif minute >= 25 and not _live_comment_minute_25_shown:
		_live_comment_minute_25_shown = true
		_bm_show_live_match_comment(25)

func _apply_stats_titles() -> void:
	# Titres au centre (KEYs -> tr via I18n.gd)
	if lbl_title_2p != null:
		lbl_title_2p.text = tr("matchsim.stats_2p")
	if lbl_title_3p != null:
		lbl_title_3p.text = tr("matchsim.stats_3p")
	if lbl_title_mvp != null:
		lbl_title_mvp.text = tr("matchsim.stats_mvp")

func _apply_end_stats_transparency() -> void:
	var a := 0.85

	if lbl_dom_2p != null: lbl_dom_2p.modulate.a = a
	if lbl_ext_2p != null: lbl_ext_2p.modulate.a = a
	if lbl_dom_3p != null: lbl_dom_3p.modulate.a = a
	if lbl_ext_3p != null: lbl_ext_3p.modulate.a = a
	if lbl_dom_mvp != null: lbl_dom_mvp.modulate.a = a
	if lbl_ext_mvp != null: lbl_ext_mvp.modulate.a = a

	if lbl_title_2p != null: lbl_title_2p.modulate.a = 0.95
	if lbl_title_3p != null: lbl_title_3p.modulate.a = 0.95
	if lbl_title_mvp != null: lbl_title_mvp.modulate.a = 0.95

func _center_stats_end_horizontally() -> void:
	if stats_end == null:
		return

	# Ancrer horizontalement au centre et recalculer les offsets selon la taille réelle
	stats_end.anchor_left = 0.5
	stats_end.anchor_right = 0.5

	# Assure que la taille est à jour (utile si layout)
	stats_end.queue_redraw()
	await get_tree().process_frame

	stats_end.offset_left = -stats_end.size.x * 0.5
	stats_end.offset_right = stats_end.size.x * 0.5



func _persist_ranking_history_to_save() -> void:
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss == null:
		return

	if ss.has_method("push_current_club_rank"):
		ss.call("push_current_club_rank", _user_team_name)

	var save: Dictionary = PlayerLife.load_savegame()
	save["ranking_history"] = ss.ranking_history.duplicate()
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster_reset: Dictionary = save["roster"] as Dictionary
		var auto_save_paid: bool = bool(roster_reset.get("auto_save_match_selection_paid", false))
		if not auto_save_paid:
			roster_reset["match_selected_ids"] = []
		save["roster"] = roster_reset

	PlayerLife.write_savegame(save)
	# DEBUG S+1 QUICK SKIP
	if false: # DEBUG FORCE S+1
		save["season_number"] = int(save.get("season_number", 1)) + 1
		save["matchs_joues"] = 0
		print("[DEBUG] FORCE S+1 → season=" + str(save["season_number"]))
		PlayerLife.write_savegame(save)
	print("[MATCHSIM][RANK] persisted ranking_history=", save["ranking_history"])



func _append_finance_history_to_save(save: Dictionary) -> void:
	if not save.has("finance_history_recettes") or typeof(save["finance_history_recettes"]) != TYPE_ARRAY:
		save["finance_history_recettes"] = []
	if not save.has("finance_history_depenses") or typeof(save["finance_history_depenses"]) != TYPE_ARRAY:
		save["finance_history_depenses"] = []
	if not save.has("finance_history_solde") or typeof(save["finance_history_solde"]) != TYPE_ARRAY:
		save["finance_history_solde"] = []

	var recettes_total: int = int(save.get("total_recettes", 0))
	var depenses_total: int = int(save.get("total_depenses", 0))
	var solde_total: int = recettes_total - depenses_total

	(save["finance_history_recettes"] as Array).append(recettes_total)
	(save["finance_history_depenses"] as Array).append(depenses_total)
	(save["finance_history_solde"] as Array).append(solde_total)


func _store_last_match_finance_popup(save: Dictionary, recettes_match: int, depenses_match: int, xp_match: int) -> void:
	save["last_match_finance_popup_pending"] = true
	save["last_match_finance_recettes"] = int(recettes_match)
	save["last_match_finance_depenses"] = int(depenses_match)
	save["last_match_finance_xp"] = int(xp_match)

func _pick_home_mvp_name_or_fallback() -> String:
	var save := PlayerLife.load_savegame()
	var played_ids: Array = []
	if typeof(save) == TYPE_DICTIONARY:
		played_ids = _bm_get_effective_played_ids(save)

	if typeof(save) == TYPE_DICTIONARY and save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY and played_ids.size() > 0:
		var by_id: Dictionary = save["players_by_id"]
		var any_id = played_ids[randi_range(0, played_ids.size() - 1)]
		if by_id.has(any_id) and typeof(by_id[any_id]) == TYPE_DICTIONARY:
			var pl: Dictionary = by_id[any_id]
			for k in ["first_name", "name", "prenom", "display_name"]:
				if pl.has(k) and str(pl[k]).strip_edges() != "":
					return str(pl[k]).strip_edges()

	return "Joueur"


func _compute_end_stats_and_show(dom_team: String, ext_team: String) -> void:
	# Stats cohérentes (simple) : dépend du rythme + diff
	var total := score_dom + score_ext
	var diff := score_dom - score_ext

	# Base en fonction du total points (rythme)
	var base_2p := clampi(46 + int((total - 150) * 0.05), 40, 60)
	var base_3p := clampi(33 + int((total - 150) * 0.03), 25, 45)

	# Petites variations + léger biais vers le gagnant
	var bias := clampi(int(diff * 0.15), -6, 6)

	var dom_2p := clampi(base_2p + randi_range(-4, 4) + (1 if diff > 0 else 0), 35, 65)
	var ext_2p := clampi(base_2p + randi_range(-4, 4) - (1 if diff > 0 else 0), 35, 65)

	var dom_3p := clampi(base_3p + randi_range(-5, 5) + (1 if diff > 0 else 0), 20, 50)
	var ext_3p := clampi(base_3p + randi_range(-5, 5) - (1 if diff > 0 else 0), 20, 50)

	# MVP : côté gagnant (sinon random)
	var mvp_side := 0 # 0=dom, 1=ext
	if diff == 0:
		mvp_side = randi() % 2
	elif diff < 0:
		mvp_side = 1

	var dom_mvp := "—"
	var ext_mvp := "—"

	if mvp_side == 0:
		dom_mvp = _pick_home_mvp_name_or_fallback()
		ext_mvp = ext_team + " #" + str(randi_range(1, 15))
	else:
		ext_mvp = ext_team + " #" + str(randi_range(1, 15))
		dom_mvp = tr("matchsim.mvp_home_short")  # ex: "—" ou "Capitaine"

	# Ecriture UI (grille 3 colonnes)
	if lbl_dom_2p != null: lbl_dom_2p.text = str(dom_2p) + "%"
	if lbl_ext_2p != null: lbl_ext_2p.text = str(ext_2p) + "%"

	if lbl_dom_3p != null: lbl_dom_3p.text = str(dom_3p) + "%"
	if lbl_ext_3p != null: lbl_ext_3p.text = str(ext_3p) + "%"

	if lbl_dom_mvp != null: lbl_dom_mvp.text = dom_mvp
	if lbl_ext_mvp != null: lbl_ext_mvp.text = ext_mvp

	# ✅ MVP du match (1 ligne sous la grille)
	if lbl_mvp_match != null:
		var mvp_name := (dom_mvp if mvp_side == 0 else ext_mvp)
		lbl_mvp_match.text = tr("matchsim.mvp_match") + " : " + str(mvp_name)
		lbl_mvp_match.modulate.a = 0.90

	# Centrage + affichage
	_center_stats_end_horizontally()

	if stats_end != null:
		stats_end.visible = true



func _build_match_summary(score_dom: int, score_ext: int) -> String:
	# Résumé en 10–15 mots (phrases pré-calibrées)
	var diff := score_dom - score_ext

	# Diff mi-temps (minute 20) si timeline dispo
	var half_diff := 0
	if _timeline_dom.size() >= 20 and _timeline_ext.size() >= 20:
		half_diff = int(_timeline_dom[19]) - int(_timeline_ext[19])

	# Cas match nul (11 mots)
	if diff == 0:
		return tr("matchsim.summary_draw")

	# Comeback / renversement (11 mots)
	if half_diff < 0 and diff > 0:
		return tr("matchsim.summary_comeback_win")
	if half_diff > 0 and diff < 0:
		return tr("matchsim.summary_comeback_loss")

	# Victoire
	if diff > 0:
		if diff <= 5:
			return tr("matchsim.summary_win_close")
		elif diff >= 16:
			return tr("matchsim.summary_win_big")
		else:
			return tr("matchsim.summary_win_control")

	# Défaite
	if diff < 0:
		if diff >= -5:
			return tr("matchsim.summary_loss_close")
		elif diff <= -16:
			return tr("matchsim.summary_loss_big")
		else:
			return tr("matchsim.summary_loss_normal")
	
	return tr("matchsim.summary_default")

func _tr_summary_key_or_text(s: String) -> String:
	var k := s.strip_edges()
	if k.begins_with("matchsim.summary_"):
		if MATCHSIM_SUMMARY_ALIASES.has(k):
			k = str(MATCHSIM_SUMMARY_ALIASES[k])
		return tr(k)
	# si ce n’est pas une clé, on renvoie tel quel
	return s


func _resolve_and_tr_summary(raw: String) -> String:
	var k := raw.strip_edges()

	# ✅ Si ce n'est pas une KEY i18n, c'est déjà une phrase -> on la garde
	if not k.begins_with("matchsim."):
		return k

	# Alias -> clé officielle (typos / variantes)
	if MATCHSIM_SUMMARY_ALIASES.has(k):
		k = str(MATCHSIM_SUMMARY_ALIASES[k])

	# Traduction directe : si la clé existe, tr() renvoie une phrase différente
	var t := tr(k)
	if t != k:
		return t

	# Fallback ultime
	return tr("matchsim.summary_default")


func _bm_build_match_impact_reason() -> String:
	var save: Dictionary = PlayerLife.load_savegame()
	var played_ids: Array = _bm_get_effective_played_ids(save)
	if BM_COACH_INSIGHTS_DEBUG:
		print("[COACH_INSIGHTS_DEBUG][PLAYED_IDS] ", played_ids)
	if played_ids.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][STOP] no played_ids")
		return ""

	var by_id: Dictionary = {}
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		by_id = save["players_by_id"] as Dictionary

	var played_profiles: Array[Dictionary] = []
	var total_motivation: float = 0.0
	var total_fatigue: float = 0.0
	var total_offense: float = 0.0
	var total_defense: float = 0.0
	var total_rating: float = 0.0

	for raw_id in played_ids:
		var sid := str(raw_id).strip_edges()
		if sid == "":
			continue
		var key := str(int(round(float(sid))))
		if not by_id.has(key) or typeof(by_id[key]) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = by_id[key] as Dictionary
		var profile := _bm_build_coach_insight_player_profile(pd)
		played_profiles.append(profile)
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][PLAYER] id=", key, " name=", str(profile.get("name", "")), " offense=", snapped(float(profile.get("offense", 0.0)), 0.1), " defense=", snapped(float(profile.get("defense", 0.0)), 0.1), " motivation=", snapped(float(profile.get("motivation", 0.0)), 0.1), " fatigue=", snapped(float(profile.get("fatigue", 0.0)), 0.1), " rating=", snapped(float(profile.get("rating", 0.0)), 0.1))
		total_motivation += float(profile.get("motivation", 50.0))
		total_fatigue += float(profile.get("fatigue", 0.0))
		total_offense += float(profile.get("offense", 0.0))
		total_defense += float(profile.get("defense", 0.0))
		total_rating += float(profile.get("rating", 0.0))

	if played_profiles.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][STOP] played_ids resolved, but no player profile found in players_by_id")
		return ""

	var count: float = float(played_profiles.size())
	var avg_motivation: float = total_motivation / count
	var avg_fatigue: float = total_fatigue / count
	var avg_offense: float = total_offense / count
	var avg_defense: float = total_defense / count
	var avg_rating: float = total_rating / count
	var gap: float = _estimate_strength_dom() - _estimate_strength_ext()
	if not _user_is_home:
		gap = -gap

	var user_score: int = int(score_dom if _user_is_home else score_ext)
	var opp_score: int = int(score_ext if _user_is_home else score_dom)
	var score_margin: int = abs(user_score - opp_score)
	var user_won: bool = user_score > opp_score
	var context_seed: int = user_score * 31 + opp_score * 17 + int(avg_motivation * 3.0) + int(avg_fatigue * 5.0) + int(abs(gap) * 11.0)

	var candidates: Array[Dictionary] = _bm_build_coach_insight_candidates(
		played_profiles,
		avg_motivation,
		avg_fatigue,
		avg_offense,
		avg_defense,
		avg_rating,
		gap,
		score_margin,
		user_won
	)
	if BM_COACH_INSIGHTS_DEBUG:
		var individual_candidates: Array[String] = []
		var collective_candidates: Array[String] = []
		for debug_candidate in candidates:
			var family := str(debug_candidate.get("family", ""))
			var player_name := str(debug_candidate.get("player_name", ""))
			if player_name != "":
				individual_candidates.append(family + ":" + player_name)
			else:
				collective_candidates.append(family)
		print("[COACH_INSIGHTS_DEBUG][CANDIDATES_INDIVIDUAL] ", individual_candidates)
		print("[COACH_INSIGHTS_DEBUG][CANDIDATES_COLLECTIVE] ", collective_candidates)
	var selected_candidate := _bm_select_coach_insight_candidate(
		candidates,
		played_profiles,
		avg_motivation,
		avg_fatigue,
		avg_offense,
		avg_defense,
		avg_rating,
		gap,
		score_margin
	)
	if selected_candidate.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][STOP] no selectable candidate variants")
		return ""

	var variants_raw: Variant = selected_candidate.get("variants", [])
	var variants: Array[String] = []
	if typeof(variants_raw) == TYPE_ARRAY:
		for variant_value in variants_raw:
			variants.append(str(variant_value))
	if variants.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][STOP] selected candidate has no variants family=", str(selected_candidate.get("family", "")))
		return ""

	var selected_family := str(selected_candidate.get("family", ""))
	var selected_player := str(selected_candidate.get("player_name", ""))
	var seed_text := selected_family + selected_player
	var selected_text := _bm_pick_match_reason(variants, context_seed + _bm_text_seed(seed_text))
	_bm_last_coach_insight_family = selected_family
	_bm_last_coach_insight_player = selected_player
	if BM_COACH_INSIGHTS_DEBUG:
		print("[COACH_INSIGHTS_DEBUG][SELECTED] family=", selected_family, " player=", selected_player, " text=", selected_text)
	return selected_text

func _bm_build_coach_insight_player_profile(pd: Dictionary) -> Dictionary:
	var precision: float = _bm_normalized_player_value(pd.get("precision", 50.0))
	var pct_2pts: float = _bm_normalized_player_value(pd.get("pct_2pts", precision))
	var pct_3pts: float = _bm_normalized_player_value(pd.get("pct_3pts", precision))
	var offense: float = (_bm_get_effective_tir(pd) + precision + pct_2pts + pct_3pts) / 4.0
	return {
		"name": _bm_player_display_name(pd),
		"offense": offense,
		"defense": float(pd.get("defense", 50.0)),
		"fatigue": float(pd.get("fatigue", 0.0)),
		"motivation": float(pd.get("motivation", 50.0)),
		"rating": float(pd.get("overall", pd.get("rating", pd.get("pondération", pd.get("ponderation", 50.0))))),
		"age": float(pd.get("age", 0.0)),
		"salary": float(pd.get("salaire", pd.get("salary", 0.0))),
		"position": str(pd.get("poste", pd.get("pos", "")))
	}

func _bm_build_coach_insight_candidates(played_profiles: Array[Dictionary], avg_motivation: float, avg_fatigue: float, avg_offense: float, avg_defense: float, avg_rating: float, gap: float, score_margin: int, user_won: bool) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	var fatigue_player := _bm_get_distinct_coach_insight_player(played_profiles, "fatigue", 24.0, 3.0, 8.0, true)
	if not fatigue_player.is_empty():
		var name := str(fatigue_player.get("name", ""))
		candidates.append({
			"family": "fatigue_player",
			"player_name": name,
			"variants": [
				"Your lineup had value, but its physical balance was stretched by %s." % name,
				"Your selection worked on paper, though %s made the fatigue risk clear." % name,
				"%s brought quality to the lineup, with a clear fatigue cost." % name,
				"Your group kept its shape, but %s showed the physical load in this selection." % name,
				"With %s involved, the lineup had quality and a visible freshness concern." % name
			]
		})

	var motivation_player := _bm_get_distinct_coach_insight_player(played_profiles, "motivation", 78.0, 3.0, 8.0, true)
	if not motivation_player.is_empty():
		var name := str(motivation_player.get("name", ""))
		candidates.append({
			"family": "motivation_player",
			"player_name": name,
			"variants": [
				"Your lineup had a stronger edge with %s involved." % name,
				"Your selection gained energy from %s." % name,
				"Your group looked more engaged with %s in the mix." % name,
				"Your selection had more spark with %s part of the group." % name,
				"%s gave the lineup a clearer mental edge." % name
			]
		})

	var offense_player := _bm_get_adaptive_coach_insight_player(played_profiles, "offense", 52.0, 6.0, 2.0, 8.0, 65.0, 2.5)
	if not offense_player.is_empty():
		var name := str(offense_player.get("name", ""))
		candidates.append({
			"family": "offense_player",
			"player_name": name,
			"variants": [
				"Your selection leaned toward offense, with %s giving it the clearest attacking profile." % name,
				"Your lineup gained a sharper attacking identity with %s." % name,
				"Your group had more offensive shape when %s was part of it." % name,
				"With %s involved, your lineup had a more defined attacking profile." % name,
				"Your selection found its strongest offensive identity through %s." % name
			]
		})

	var defense_player := _bm_get_adaptive_coach_insight_player(played_profiles, "defense", 76.0, 6.0, 0.75, 7.0, 86.0, 0.75)
	if not defense_player.is_empty():
		var name := str(defense_player.get("name", ""))
		candidates.append({
			"family": "defense_player",
			"player_name": name,
			"variants": [
				"Your selection had more defensive structure with %s involved." % name,
				"Your lineup gained a clearer defensive identity through %s." % name,
				"Your group looked more stable with %s in the selection." % name,
				"With %s in the group, your lineup had a firmer defensive base." % name,
				"Your selection carried more defensive balance through %s." % name
			]
		})

	var level_player := _bm_get_adaptive_coach_insight_player(played_profiles, "rating", 54.0, 5.5, 1.5, 8.0, 62.0, 2.0)
	if not level_player.is_empty():
		var name := str(level_player.get("name", ""))
		candidates.append({
			"family": "level_player",
			"player_name": name,
			"variants": [
				"Your selection had its clearest overall base with %s involved." % name,
				"Your lineup had a stronger current profile with %s in the group." % name,
				"Your group leaned on %s as its most complete profile." % name,
				"With %s included, the lineup had a more reliable overall shape." % name,
				"Your selection drew its strongest all-around profile from %s." % name
			]
		})

	for context_candidate in _bm_build_player_context_insight_candidates(played_profiles, avg_rating):
		candidates.append(context_candidate)

	if BM_COACH_INSIGHTS_DEBUG:
		if candidates.is_empty():
			print("[COACH_INSIGHTS_DEBUG][FLOW] no individual candidate retained; evaluating collective fallback")
		else:
			print("[COACH_INSIGHTS_DEBUG][FLOW] individual candidates retained; collective context still evaluated")

	if avg_fatigue >= 22.0:
		candidates.append({
			"family": "fatigue_group",
			"variants": [
				"Your lineup looked short on freshness.",
				"Your selection had quality, but the group lacked freshness.",
				"The group profile was solid, but fatigue limited its balance.",
				"Your team shape was there, but the group looked physically stretched.",
				"The selected group had enough structure, with freshness still the main concern."
			]
		})
	elif avg_motivation <= 58.0:
		candidates.append({
			"family": "motivation_group_low",
			"variants": [
				"Your selected group lacked a real motivation edge.",
				"The lineup did not show a strong mental profile.",
				"The group had structure, but not enough edge.",
				"Your selection looked organized, but it lacked a sharper mental tone.",
				"The group had a clear shape without much extra drive."
			]
		})
	elif avg_offense - avg_defense >= 10.0:
		candidates.append({
			"family": "offense_balance",
			"variants": [
				"Your lineup clearly leaned toward offense.",
				"Your selection gave the team a stronger attacking identity.",
				"The group offered more attacking profile than defensive cover.",
				"Your chosen group carried a clear attacking tilt.",
				"The lineup's identity was built more around creation than protection."
			]
		})
	elif avg_defense - avg_offense >= 10.0:
		candidates.append({
			"family": "defense_balance",
			"variants": [
				"Your lineup had a clear defensive base.",
				"Your selection gave the team more structure than creation.",
				"The group looked built to contain first.",
				"Your chosen group leaned into defensive stability.",
				"The lineup carried a more protective identity than an attacking one."
			]
		})
	elif gap >= 1.5 or avg_rating >= 72.0:
		candidates.append({
			"family": "group_level_positive",
			"variants": [
				"Your selection gave the team a strong enough base.",
				"The result reflected the quality of the group you chose.",
				"Your lineup had enough overall level to support this outcome.",
				"The group you selected had the overall profile to hold up.",
				"Your lineup showed a solid enough current level."
			]
		})
	elif gap <= -1.5 or avg_rating <= 58.0:
		candidates.append({
			"family": "group_level_negative",
			"variants": [
				"Your selection exposed the current limits of the group.",
				"The lineup lacked enough overall level to tilt this kind of matchup.",
				"The core group lacked enough quality to control the matchup.",
				"Your chosen group showed where the current level still feels thin.",
				"The lineup profile left the team short of control."
			]
		})
	elif score_margin <= 5:
		candidates.append({
			"family": "close_collective",
			"variants": [
				"In a close matchup, your lineup balance mattered.",
				"Small differences in the selected group shaped this result.",
				"Your selection left very little margin.",
				"The balance of your lineup carried real weight in a tight game.",
				"With so little between the teams, the selected group mattered."
			]
		})
	else:
		candidates.append({
			"family": "fallback_collective",
			"variants": [
				"The main takeaway was the balance of the group you selected.",
				"Your lineup gave a clear picture of the team's current identity.",
				"This result reflected the profile of the group you chose.",
				"Your selection offered a useful read on the team's current shape.",
				"The group you chose gave a fair view of where the team stands."
			]
		})

	return candidates

func _bm_build_player_context_insight_candidates(played_profiles: Array[Dictionary], avg_rating: float) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if played_profiles.is_empty():
		return candidates

	var total_age := 0.0
	var valid_age_count := 0
	var youngest: Dictionary = {}
	var oldest: Dictionary = {}
	var highest_salary: Dictionary = {}
	var youngest_age := INF
	var oldest_age := -INF
	var highest_salary_value := -INF
	var second_salary_value := -INF
	for profile in played_profiles:
		var age := float(profile.get("age", 0.0))
		var salary := float(profile.get("salary", 0.0))
		if age > 0.0:
			total_age += age
			valid_age_count += 1
			if age < youngest_age:
				youngest = profile
				youngest_age = age
			if age > oldest_age:
				oldest = profile
				oldest_age = age
		if salary > highest_salary_value:
			if not highest_salary.is_empty():
				second_salary_value = highest_salary_value
			highest_salary = profile
			highest_salary_value = salary
		elif salary > second_salary_value:
			second_salary_value = salary

	var avg_age := total_age / float(maxi(1, valid_age_count))
	if not youngest.is_empty():
		var young_rating := float(youngest.get("rating", 0.0))
		if youngest_age <= 22.0 and young_rating >= 68.0 and young_rating >= avg_rating + 2.0:
			var name := str(youngest.get("name", ""))
			candidates.append({
				"family": "context_young_anchor",
				"player_name": name,
				"context_score": 49.0 + maxf(0.0, 22.0 - youngest_age) * 2.0 + maxf(0.0, young_rating - 68.0) * 0.7 + maxf(0.0, young_rating - avg_rating) * 1.1,
				"variants": [
					"Your selection gave a young profile real weight, with %s already important to the group." % name,
					"One of your youngest players held a clear place in this lineup through %s." % name,
					"Your lineup had a younger identity without losing level, with %s involved." % name
				]
			})

	if not oldest.is_empty():
		var veteran_rating := float(oldest.get("rating", 0.0))
		if oldest_age >= 32.0 and veteran_rating >= 68.0 and veteran_rating >= avg_rating + 2.0:
			var name := str(oldest.get("name", ""))
			candidates.append({
				"family": "context_veteran_anchor",
				"player_name": name,
				"context_score": 48.0 + maxf(0.0, oldest_age - 32.0) * 1.4 + maxf(0.0, veteran_rating - 68.0) * 0.7 + maxf(0.0, veteran_rating - avg_rating) * 1.1,
				"variants": [
					"Your lineup kept an experienced base, with %s still carrying real weight in the selection." % name,
					"The group had a veteran reference point through %s." % name,
					"Your selection leaned on experience without losing current level, led by %s." % name
				]
			})

	if not highest_salary.is_empty() and highest_salary_value > 0.0:
		var salary_gap := highest_salary_value - second_salary_value if played_profiles.size() > 1 else highest_salary_value
		var responsibility_rating := float(highest_salary.get("rating", 0.0))
		if responsibility_rating >= 70.0 and salary_gap >= 18000.0 and responsibility_rating >= avg_rating + 2.0:
			var name := str(highest_salary.get("name", ""))
			candidates.append({
				"family": "context_responsibility_player",
				"player_name": name,
				"context_score": 46.0 + minf(8.0, salary_gap / 10000.0) + maxf(0.0, responsibility_rating - avg_rating) * 0.9,
				"variants": [
					"Your selection placed one of its major profiles at the heart of the group through %s." % name,
					"The lineup gave %s a role that matched his importance in the squad." % name,
					"Your group leaned on one of its key current profiles with %s involved." % name
				]
			})

	if valid_age_count >= 3:
		if avg_age <= 24.0 and avg_rating >= 60.0:
			candidates.append({
				"family": "context_young_group",
				"context_score": 37.0 + maxf(0.0, 24.0 - avg_age) * 1.3 + maxf(0.0, avg_rating - 60.0) * 0.3,
				"variants": [
					"Your lineup had a noticeably young profile.",
					"The selected group brought a younger identity to the floor.",
					"Your selection leaned into youth while keeping a coherent team shape."
				]
			})
		elif avg_age >= 31.0 and avg_rating >= 60.0:
			candidates.append({
				"family": "context_experienced_group",
				"context_score": 37.0 + maxf(0.0, avg_age - 31.0) * 1.2 + maxf(0.0, avg_rating - 60.0) * 0.3,
				"variants": [
					"Your lineup clearly leaned on experience.",
					"The selected group had an experienced core.",
					"Your selection gave the team a more mature profile."
				]
			})
		elif oldest_age - youngest_age >= 11.0 and avg_rating >= 60.0:
			candidates.append({
				"family": "context_generation_mix",
				"context_score": 38.0 + minf(8.0, (oldest_age - youngest_age - 10.0) * 0.8) + maxf(0.0, avg_rating - 60.0) * 0.25,
				"variants": [
					"Your lineup combined experience with younger profiles.",
					"The selected group showed a clear mix of ages.",
					"Your selection balanced younger legs with experienced profiles."
				]
			})

	return candidates

func _bm_select_coach_insight_candidate(candidates: Array[Dictionary], played_profiles: Array[Dictionary], avg_motivation: float, avg_fatigue: float, avg_offense: float, avg_defense: float, avg_rating: float, gap: float, score_margin: int) -> Dictionary:
	var best_candidate: Dictionary = {}
	var best_score: float = -INF
	var editorial_player_pick := false
	var scored_candidates: Array[Dictionary] = []
	for candidate in candidates:
		var variants_raw: Variant = candidate.get("variants", [])
		if typeof(variants_raw) != TYPE_ARRAY or (variants_raw as Array).is_empty():
			continue
		var score := _bm_score_coach_insight_candidate(candidate, played_profiles, avg_motivation, avg_fatigue, avg_offense, avg_defense, avg_rating, gap, score_margin)
		scored_candidates.append({"candidate": candidate, "score": score})
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][SCORE] family=", str(candidate.get("family", "")), " player=", str(candidate.get("player_name", "")), " score=", snapped(score, 0.1), " last_family=", _bm_last_coach_insight_family, " last_player=", _bm_last_coach_insight_player)
		if score > best_score:
			best_score = score
			best_candidate = candidate

	var best_player_scored := _bm_best_scored_coach_insight_candidate(scored_candidates, true)
	if not best_player_scored.is_empty():
		var best_player_candidate: Dictionary = best_player_scored.get("candidate", {})
		var best_player_score := float(best_player_scored.get("score", -INF))
		var player_margin := 8.0
		if not _bm_is_player_coach_insight_candidate(best_candidate):
			var player_is_exceptional := _bm_is_exceptional_coach_insight_candidate(best_player_candidate, played_profiles)
			if player_is_exceptional or best_score - best_player_score <= player_margin:
				best_candidate = best_player_candidate
				best_score = best_player_score
				editorial_player_pick = true
				if BM_COACH_INSIGHTS_DEBUG:
					print("[COACH_INSIGHTS_DEBUG][EDITORIAL_PLAYER_PICK] family=", str(best_candidate.get("family", "")), " player=", str(best_candidate.get("player_name", "")), " score=", snapped(best_score, 0.1))

	var close_margin := 6.0
	var best_novelty: float = _bm_coach_insight_novelty_score(best_candidate)
	for scored in scored_candidates:
		var candidate: Dictionary = scored.get("candidate", {})
		var score: float = float(scored.get("score", -INF))
		if candidate.is_empty() or best_score - score > close_margin:
			continue
		if editorial_player_pick and not _bm_is_player_coach_insight_candidate(candidate):
			continue
		if _bm_is_exceptional_coach_insight_candidate(best_candidate, played_profiles) and score < best_score:
			continue
		var novelty := _bm_coach_insight_novelty_score(candidate)
		if novelty > best_novelty:
			best_novelty = novelty
			best_candidate = candidate
			if BM_COACH_INSIGHTS_DEBUG:
				print("[COACH_INSIGHTS_DEBUG][NOVELTY_TIEBREAK] family=", str(candidate.get("family", "")), " player=", str(candidate.get("player_name", "")), " score=", snapped(score, 0.1), " novelty=", snapped(novelty, 0.1))
	best_candidate = _bm_restore_collective_story_if_close(best_candidate, scored_candidates, played_profiles, avg_fatigue)
	best_candidate = _bm_reduce_repeated_player_coach_insight(best_candidate, best_score, scored_candidates, played_profiles)
	return best_candidate

func _bm_restore_collective_story_if_close(best_candidate: Dictionary, scored_candidates: Array[Dictionary], played_profiles: Array[Dictionary], avg_fatigue: float) -> Dictionary:
	if best_candidate.is_empty() or not _bm_is_player_coach_insight_candidate(best_candidate):
		return best_candidate
	if _bm_is_exceptional_coach_insight_candidate(best_candidate, played_profiles):
		return best_candidate
	if avg_fatigue < 70.0:
		return best_candidate
	var best_score := -INF
	var fatigue_group_score := -INF
	var fatigue_group_candidate: Dictionary = {}
	for scored in scored_candidates:
		var candidate: Dictionary = scored.get("candidate", {})
		var score := float(scored.get("score", -INF))
		if candidate == best_candidate:
			best_score = score
		if str(candidate.get("family", "")) == "fatigue_group":
			fatigue_group_score = score
			fatigue_group_candidate = candidate
	if fatigue_group_candidate.is_empty():
		return best_candidate
	if best_score - fatigue_group_score <= 4.0:
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][COLLECTIVE_STORY_TIEBREAK] family=fatigue_group score=", snapped(fatigue_group_score, 0.1), " player_family=", str(best_candidate.get("family", "")), " player=", str(best_candidate.get("player_name", "")), " player_score=", snapped(best_score, 0.1))
		return fatigue_group_candidate
	return best_candidate

func _bm_best_scored_coach_insight_candidate(scored_candidates: Array[Dictionary], player_only: bool) -> Dictionary:
	var best_scored: Dictionary = {}
	var best_score: float = -INF
	for scored in scored_candidates:
		var candidate: Dictionary = scored.get("candidate", {})
		if candidate.is_empty():
			continue
		if player_only and not _bm_is_player_coach_insight_candidate(candidate):
			continue
		var score := float(scored.get("score", -INF))
		if score > best_score:
			best_score = score
			best_scored = scored
	return best_scored

func _bm_is_player_coach_insight_candidate(candidate: Dictionary) -> bool:
	return str(candidate.get("player_name", "")) != ""

func _bm_reduce_repeated_player_coach_insight(best_candidate: Dictionary, best_score: float, scored_candidates: Array[Dictionary], played_profiles: Array[Dictionary]) -> Dictionary:
	var player_name := str(best_candidate.get("player_name", ""))
	if player_name == "" or player_name != _bm_last_coach_insight_player:
		return best_candidate
	if _bm_is_exceptional_coach_insight_candidate(best_candidate, played_profiles):
		return best_candidate
	var alternate_margin := 8.0
	var best_alternate: Dictionary = best_candidate
	var best_alternate_changed := false
	var best_alternate_novelty := _bm_coach_insight_novelty_score(best_candidate)
	for scored in scored_candidates:
		var candidate: Dictionary = scored.get("candidate", {})
		if candidate.is_empty() or not _bm_is_player_coach_insight_candidate(candidate):
			continue
		if str(candidate.get("player_name", "")) == player_name:
			continue
		var score := float(scored.get("score", -INF))
		if best_score - score > alternate_margin:
			continue
		var novelty := _bm_coach_insight_novelty_score(candidate)
		if novelty > best_alternate_novelty:
			best_alternate_novelty = novelty
			best_alternate = candidate
			best_alternate_changed = true
	if BM_COACH_INSIGHTS_DEBUG and best_alternate_changed:
		print("[COACH_INSIGHTS_DEBUG][REPEAT_PLAYER_TIEBREAK] family=", str(best_alternate.get("family", "")), " player=", str(best_alternate.get("player_name", "")))
	return best_alternate

func _bm_coach_insight_novelty_score(candidate: Dictionary) -> float:
	var family := str(candidate.get("family", ""))
	var player_name := str(candidate.get("player_name", ""))
	var novelty := 0.0
	if family != "" and family != _bm_last_coach_insight_family:
		novelty += 2.0
	if player_name != "" and player_name != _bm_last_coach_insight_player:
		novelty += 3.0
	match family:
		"fatigue_player", "motivation_player":
			novelty += 1.5
		"offense_player", "defense_player":
			novelty += 1.0
		"context_young_anchor", "context_veteran_anchor", "context_responsibility_player", "context_young_group", "context_experienced_group", "context_generation_mix":
			novelty += 1.0
	return novelty


func _bm_score_coach_insight_candidate(candidate: Dictionary, played_profiles: Array[Dictionary], avg_motivation: float, avg_fatigue: float, avg_offense: float, avg_defense: float, avg_rating: float, gap: float, score_margin: int) -> float:
	var family := str(candidate.get("family", ""))
	var player_name := str(candidate.get("player_name", ""))
	var score: float = 34.0
	match family:
		"fatigue_player":
			score = 62.0 + _bm_coach_insight_metric_score(played_profiles, "fatigue", 24.0, true, avg_fatigue)
		"motivation_player":
			score = 58.0 + _bm_coach_insight_metric_score(played_profiles, "motivation", 78.0, true, avg_motivation)
		"offense_player":
			score = 56.0 + _bm_coach_insight_metric_score(played_profiles, "offense", 52.0, true, avg_offense)
		"defense_player":
			score = 56.0 + _bm_coach_insight_metric_score(played_profiles, "defense", 76.0, true, avg_defense)
		"level_player":
			score = 26.0 + _bm_coach_insight_metric_score(played_profiles, "rating", 54.0, true, avg_rating)
		"context_young_anchor", "context_veteran_anchor", "context_responsibility_player", "context_young_group", "context_experienced_group", "context_generation_mix":
			score = float(candidate.get("context_score", 36.0))
		"fatigue_group":
			score = 42.0 + minf(35.0, maxf(0.0, avg_fatigue - 22.0)) * 0.70
		"motivation_group_low":
			score = 42.0 + maxf(0.0, 58.0 - avg_motivation) * 1.4
		"offense_balance":
			score = 40.0 + maxf(0.0, avg_offense - avg_defense) * 1.1
		"defense_balance":
			score = 40.0 + maxf(0.0, avg_defense - avg_offense) * 1.1
		"group_level_positive":
			score = 38.0 + maxf(0.0, avg_rating - 72.0) * 0.7 + maxf(0.0, gap) * 2.0
		"group_level_negative":
			score = 38.0 + maxf(0.0, 58.0 - avg_rating) * 0.7 + maxf(0.0, -gap) * 2.0
		"close_collective":
			score = 38.0 + maxf(0.0, 6.0 - float(score_margin)) * 2.0
		"fallback_collective":
			score = 30.0
		_:
			score = 30.0

	var is_exceptional_candidate := _bm_is_exceptional_coach_insight_candidate(candidate, played_profiles)
	if family != "" and family == _bm_last_coach_insight_family and not is_exceptional_candidate:
		score -= 3.0
	if player_name != "" and player_name == _bm_last_coach_insight_player and not is_exceptional_candidate:
		score -= 5.0
	return score

func _bm_coach_insight_metric_score(played_profiles: Array[Dictionary], metric: String, min_value: float, higher_is_better: bool, group_average: float) -> float:
	var metric_signal := _bm_get_coach_insight_metric_signal(played_profiles, metric, higher_is_better)
	if metric_signal.is_empty():
		return 0.0
	var best_value := float(metric_signal.get("best_value", 0.0))
	var signal_gap := float(metric_signal.get("gap", 0.0))
	var threshold_strength := maxf(0.0, best_value - min_value) if higher_is_better else maxf(0.0, min_value - best_value)
	var group_strength := absf(best_value - group_average)
	return signal_gap * 1.7 + threshold_strength * 0.55 + group_strength * 0.35

func _bm_is_exceptional_coach_insight_candidate(candidate: Dictionary, played_profiles: Array[Dictionary]) -> bool:
	var family := str(candidate.get("family", ""))
	var metric := ""
	var min_value := 0.0
	match family:
		"fatigue_player":
			metric = "fatigue"
			min_value = 24.0
		"motivation_player":
			metric = "motivation"
			min_value = 78.0
		"offense_player":
			metric = "offense"
			min_value = 68.0
		"defense_player":
			metric = "defense"
			min_value = 76.0
		"level_player":
			metric = "rating"
			min_value = 68.0
		_:
			return false
	var metric_signal := _bm_get_coach_insight_metric_signal(played_profiles, metric, true)
	if metric_signal.is_empty():
		return false
	var best_value := float(metric_signal.get("best_value", 0.0))
	var signal_gap := float(metric_signal.get("gap", 0.0))
	return signal_gap >= 14.0 or best_value >= min_value + 14.0

func _bm_get_coach_insight_metric_signal(played_profiles: Array[Dictionary], metric: String, higher_is_better: bool) -> Dictionary:
	var best: Dictionary = {}
	var second_value: float = -INF if higher_is_better else INF
	var best_value: float = -INF if higher_is_better else INF
	for profile in played_profiles:
		var value: float = float(profile.get(metric, 0.0))
		var is_better: bool = value > best_value if higher_is_better else value < best_value
		if is_better:
			if not best.is_empty():
				second_value = best_value
			best = profile
			best_value = value
		else:
			var is_second: bool = value > second_value if higher_is_better else value < second_value
			if is_second:
				second_value = value
	if best.is_empty():
		return {}
	var signal_gap := 0.0
	if played_profiles.size() > 1:
		signal_gap = best_value - second_value if higher_is_better else second_value - best_value
	return {
		"best": best,
		"best_value": best_value,
		"second_value": second_value,
		"gap": signal_gap
	}


func _bm_get_coach_insight_metric_average(played_profiles: Array[Dictionary], metric: String) -> float:
	if played_profiles.is_empty():
		return 0.0
	var total := 0.0
	for profile in played_profiles:
		total += float(profile.get(metric, 0.0))
	return total / float(played_profiles.size())

func _bm_get_coach_insight_metric_median(played_profiles: Array[Dictionary], metric: String) -> float:
	var values: Array[float] = []
	for profile in played_profiles:
		values.append(float(profile.get(metric, 0.0)))
	if values.is_empty():
		return 0.0
	values.sort()
	var middle := int(values.size() / 2)
	if values.size() % 2 == 0:
		return (values[middle - 1] + values[middle]) * 0.5
	return values[middle]

func _bm_get_adaptive_coach_insight_player(played_profiles: Array[Dictionary], metric: String, absolute_floor: float, avg_gap: float, min_second_gap: float, strong_second_gap: float, high_value_floor: float, high_value_second_gap: float) -> Dictionary:
	var metric_signal := _bm_get_coach_insight_metric_signal(played_profiles, metric, true)
	if metric_signal.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][REJECT] metric=", metric, " reason=candidate_not_generated no_profiles")
		return {}
	var best: Dictionary = metric_signal.get("best", {})
	var best_value := float(metric_signal.get("best_value", 0.0))
	var second_value := float(metric_signal.get("second_value", 0.0))
	var signal_gap := float(metric_signal.get("gap", 0.0))
	var avg_value := _bm_get_coach_insight_metric_average(played_profiles, metric)
	var median_value := _bm_get_coach_insight_metric_median(played_profiles, metric)
	var floor_ok := best_value >= absolute_floor
	var avg_signal := best_value >= avg_value + avg_gap and signal_gap >= min_second_gap
	var median_signal := best_value >= median_value + avg_gap and signal_gap >= min_second_gap
	var clear_second_signal := signal_gap >= strong_second_gap
	var high_value_signal := best_value >= high_value_floor and best_value >= avg_value + avg_gap * 0.5 and signal_gap >= high_value_second_gap
	var accepted := floor_ok and (avg_signal or median_signal or clear_second_signal or high_value_signal)
	if BM_COACH_INSIGHTS_DEBUG:
		var reason := "adaptive_signal" if accepted else ("value_too_low" if not floor_ok else ("gap_insufficient" if signal_gap < min_second_gap else "group_gap_insufficient"))
		print("[COACH_INSIGHTS_DEBUG][ADAPTIVE_CHECK] metric=", metric, " best=", str(best.get("name", "")), " best_value=", snapped(best_value, 0.1), " second=", snapped(second_value, 0.1), " gap=", snapped(signal_gap, 0.1), " avg=", snapped(avg_value, 0.1), " median=", snapped(median_value, 0.1), " floor=", absolute_floor, " result=", "accepted" if accepted else "rejected", " reason=", reason)
	if not accepted:
		return {}
	return best

func _bm_get_distinct_coach_insight_player(played_profiles: Array[Dictionary], metric: String, min_value: float, min_gap: float, strong_gap: float, higher_is_better: bool) -> Dictionary:
	var best: Dictionary = {}
	var second_value: float = -INF if higher_is_better else INF
	var best_value: float = -INF if higher_is_better else INF
	for profile in played_profiles:
		var value: float = float(profile.get(metric, 0.0))
		var is_better: bool = value > best_value if higher_is_better else value < best_value
		if is_better:
			if not best.is_empty():
				second_value = best_value
			best = profile
			best_value = value
		else:
			var is_second: bool = value > second_value if higher_is_better else value < second_value
			if is_second:
				second_value = value
	if best.is_empty():
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][REJECT] metric=", metric, " reason=candidate_not_generated no_profiles")
		return {}
	if played_profiles.size() <= 1:
		var single_ok := (higher_is_better and best_value >= min_value) or ((not higher_is_better) and best_value <= min_value)
		if BM_COACH_INSIGHTS_DEBUG:
			print("[COACH_INSIGHTS_DEBUG][CHECK] metric=", metric, " best=", str(best.get("name", "")), " best_value=", snapped(best_value, 0.1), " min=", min_value, " result=", "accepted" if single_ok else "rejected", " reason=", "single_player_signal" if single_ok else "threshold_not_met")
		if single_ok:
			return best
		return {}

	var gap: float = best_value - second_value if higher_is_better else second_value - best_value
	var threshold_ok: bool = best_value >= min_value if higher_is_better else best_value <= min_value
	var absolute_signal: bool = threshold_ok and gap >= min_gap
	var relative_signal: bool = gap >= strong_gap
	if BM_COACH_INSIGHTS_DEBUG:
		var status := "accepted" if absolute_signal or relative_signal else "rejected"
		var reason := "absolute_signal" if absolute_signal else ("relative_signal" if relative_signal else ("gap_insufficient" if threshold_ok else "threshold_not_met"))
		print("[COACH_INSIGHTS_DEBUG][CHECK] metric=", metric, " best=", str(best.get("name", "")), " best_value=", snapped(best_value, 0.1), " second=", snapped(second_value, 0.1), " gap=", snapped(gap, 0.1), " min=", min_value, " min_gap=", min_gap, " strong_gap=", strong_gap, " result=", status, " reason=", reason)
	if not absolute_signal and not relative_signal:
		return {}
	return best

func _bm_player_display_name(pd: Dictionary) -> String:
	for key in ["name", "display_name", "nom", "first_name", "prenom"]:
		if pd.has(key):
			var value := str(pd.get(key, "")).strip_edges()
			if value != "":
				return value
	return "Player"

func _bm_normalized_player_value(raw_value) -> float:
	var value: float = float(raw_value)
	if value <= 1.5:
		value *= 100.0
	return value

func _bm_text_seed(value: String) -> int:
	var total: int = 0
	var bytes := value.to_utf8_buffer()
	for i in range(bytes.size()):
		total += int(bytes[i]) * (i + 1)
	return total


func _bm_pick_match_reason(options: Array[String], seed: int) -> String:
	if options.is_empty():
		return ""
	return options[posmod(seed, options.size())]

# BM_POP_FIN_V1 --------------------------------------------------------------
# Objectif: clone logique .py (popularité -> coef 0.30..1.00 -> recettes domicile cumulées)
# SÉCURITÉ: anti-double-compte via save["last_pop_fin_round"]

func _get_int_path(d: Dictionary, path: Array, default_val: int = 0) -> int:
	var cur = d
	for i in range(path.size()):
		var k = path[i]
		if typeof(cur) != TYPE_DICTIONARY:
			return default_val
		if not cur.has(k):
			return default_val
		cur = cur[k]
	return int(cur) if cur != null else default_val

func _compute_ticketing_prevision(save: Dictionary) -> int:
	# Forme attendue: prix A/B/C + places A/B/C
	var candidates = [
		[["stadium","ticketing","price_a"], ["stadium","ticketing","seats_a"]],
		[["stadium","ticketing","price_b"], ["stadium","ticketing","seats_b"]],
		[["stadium","ticketing","price_c"], ["stadium","ticketing","seats_c"]],
		[["ticketing","price_a"], ["ticketing","seats_a"]],
		[["ticketing","price_b"], ["ticketing","seats_b"]],
		[["ticketing","price_c"], ["ticketing","seats_c"]],
	]
	var total := 0
	for pair in candidates:
		var price_path = pair[0]
		var seats_path = pair[1]
		var price := _get_int_path(save, price_path, 0)
		var seats := _get_int_path(save, seats_path, 0)
		if price > 0 and seats > 0:
			total += price * seats
	return total

func _compute_shop_prevision(save: Dictionary) -> int:
	# 1) shop.items = [{price, qty}...] ou shop.items_by_id = {id:{price,qty}}
	var total := 0

	var items: Array = []
	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		var shop: Dictionary = save["shop"]
		if shop.has("items") and typeof(shop["items"]) == TYPE_ARRAY:
			items = shop["items"]
	if items.size() > 0:
		for it in items:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			var price := int(it.get("price", 0))
			var qty := int(it.get("qty", it.get("stock", 0)))
			if price > 0 and qty > 0:
				total += price * qty
		return total

	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		var shop2: Dictionary = save["shop"]
		if shop2.has("items_by_id") and typeof(shop2["items_by_id"]) == TYPE_DICTIONARY:
			var by: Dictionary = shop2["items_by_id"]
			for k in by.keys():
				var it2 = by[k]
				if typeof(it2) != TYPE_DICTIONARY:
					continue
				var price2 := int(it2.get("price", 0))
				var qty2 := int(it2.get("qty", it2.get("stock", 0)))
				if price2 > 0 and qty2 > 0:
					total += price2 * qty2
			return total

	total = int((save.get("shop", {}) as Dictionary).get("total_forecast", 0))
	return total

func _bm_collect_shop_price_values(v: Variant, out: Array) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		for k in d.keys():
			var key := str(k).to_lower()
			var val: Variant = d[k]
			if (key.find("price") != -1 or key.find("prix") != -1) and (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT):
				out.append(float(val))
			if typeof(val) == TYPE_DICTIONARY or typeof(val) == TYPE_ARRAY:
				_bm_collect_shop_price_values(val, out)
	elif typeof(v) == TYPE_ARRAY:
		for item in (v as Array):
			if typeof(item) == TYPE_DICTIONARY or typeof(item) == TYPE_ARRAY:
				_bm_collect_shop_price_values(item, out)


func _bm_shop_price_volume_coef_from_save(save: Dictionary) -> float:
	if not save.has("shop") or typeof(save["shop"]) != TYPE_DICTIONARY:
		return 1.0

	var prices: Array = []
	_bm_collect_shop_price_values(save["shop"], prices)
	if prices.is_empty():
		return 1.0

	var total := 0.0
	for raw_price in prices:
		total += float(raw_price)

	var avg_price := total / float(prices.size())

	if avg_price <= 10.0:
		return 1.0
	if avg_price >= 25.0:
		return 0.72

	return lerpf(1.0, 0.72, (avg_price - 10.0) / 15.0)


func _apply_popularity_after_match(save: Dictionary, did_win: bool, did_draw: bool) -> void:
	PlayerLife.ensure_finance_schema(save)

	# --- Resolve a stable round/match id from save (best-effort) ---
	var round_id: int = -1
	if save.has("journee"):
		print("[POP] BEFORE =", save.get("popularite", -1), " win=", did_win, " draw=", did_draw)
		round_id = int(save.get("journee", -1))
	elif save.has("round_id"):
		round_id = int(save.get("round_id", -1))
	elif save.has("round"):
		round_id = int(save.get("round", -1))
	elif save.has("match_index"):
		round_id = int(save.get("match_index", -1))
	elif save.has("season") and typeof(save["season"]) == TYPE_DICTIONARY:
		var s := save["season"] as Dictionary
		if s.has("journee"):
			round_id = int(s.get("journee", -1))
		elif s.has("round"):
			round_id = int(s.get("round", -1))
		elif s.has("match_index"):
			round_id = int(s.get("match_index", -1))


	# --- Source of truth: popularite (fallback 50), migrate legacy keys once ---
	var pop: int = int(save.get("popularite", 50))
	if not save.has("popularite"):
		if save.has("popularity"):
			pop = int(save.get("popularity", 50))
		elif save.has("notoriety"):
			pop = int(save.get("notoriety", 50))
		elif save.has("notoriete"):
			pop = int(save.get("notoriete", 50))
		save["popularite"] = pop
	print("[POP] AFTER =", pop)

	# --- Clamp canonical ---
	pop = clampi(pop, 30, 100)
	save["popularite"] = pop
	var coef: float = float(pop) / 100.0

	# --- Shop income computed from forecast * popularity coef (unchanged structure) ---
	var shop_forecast: int = 0
	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		shop_forecast = int((save["shop"] as Dictionary).get("total_forecast", 0))

	var shop_income: int = int(round(float(shop_forecast) * coef))
	if shop_income < 0:
		shop_income = 0
	# NOTE: si tu stockes shop_income quelque part, fais-le dans la clé existante attendue (non modifiée ici)

	# --- Update popularity after match result (win +8 / draw +1 / lose -7) ---
	if did_draw:
		pop += 1
	elif did_win:
		pop += 8
	else:
		pop -= 7

	print("[POP][FINAL BEFORE CLAMP] pop=", pop)
	pop = clampi(pop, 30, 100)
	save["popularite"] = pop
	print("[POP] UPDATED =", pop)
func _fin_match() -> void:
	match_fini = true
	_live_comment_token += 1
	_live_comment_clear_minute = -1
	if lbl_info != null:
		lbl_info.text = ""
	timer.stop()

	var resultat := ""
	var user_score := score_dom if _user_is_home else score_ext
	var opp_score := score_ext if _user_is_home else score_dom

	if user_score > opp_score:
		resultat = tr("matchsim.result_win")
	elif user_score < opp_score:
		resultat = tr("matchsim.result_loss")
	else:
		resultat = tr("matchsim.result_draw")
	var result_color := Color(1, 1, 1, 1)
	if user_score > opp_score:
		result_color = Color(0.20, 1.0, 0.38, 1.0)
	elif user_score < opp_score:
		result_color = Color(1.0, 0.16, 0.16, 1.0)

	if lbl_info != null:
		lbl_info.position = _bm_lbl_info_base_position
		lbl_info.size = _bm_lbl_info_base_size
		lbl_info.add_theme_font_size_override("font_size", _bm_lbl_info_base_font_size)

	var resume_raw := _build_match_summary(user_score, opp_score)
	var resume := tr(resume_raw) # ✅ si resume_raw est une clé => traduit, sinon inchangé
	print("[MATCHSIM][DBG] summary_raw_before_resolve=", str(resume))
	resume = _resolve_and_tr_summary(str(resume))
	var impact_reason := _bm_build_match_impact_reason()
	lbl_info.text = resume + ("\n\n" + impact_reason if impact_reason != "" else "")
	var end_summary_width: float = minf(lbl_info.size.x, 760.0)
	lbl_info.position += Vector2((lbl_info.size.x - end_summary_width) * 0.5, 30.0)
	lbl_info.size = Vector2(end_summary_width, lbl_info.size.y + 36.0)
	lbl_info.add_theme_constant_override("line_spacing", 8)
	lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if info_panel != null:
		info_panel.position = lbl_info.position - Vector2(28.0, 18.0)
		info_panel.size = lbl_info.size + Vector2(56.0, 86.0)

	# BM_MOBILE_MATCH_END_INFO_BG_FORCE_V2
	if _bm_matchsim_is_mobile_layout():
		lbl_info.add_theme_font_size_override("font_size", 34)
		lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl_info.add_theme_constant_override("outline_size", 8)
		if info_panel != null:
			info_panel.visible = true
			info_panel.z_index = 19
			lbl_info.z_index = 20
			info_panel.self_modulate = Color(0, 0, 0, 0.82)
			info_panel.position = lbl_info.position - Vector2(28.0, 18.0)
			info_panel.size = lbl_info.size + Vector2(56.0, 78.0)
	_bm_place_match_result_label(resultat, result_color)

	_bm_matchsim_apply_mobile_texts_plus2()
	call_deferred("_bm_matchsim_apply_mobile_layout")
	call_deferred("_bm_place_current_lineup_button")

	if stats_end != null:
		_compute_end_stats_and_show(_team_dom_name, _team_ext_name)

	# --- PATCH ULTRA-CIBLÉ: update joueurs "vivants" + rewrite savegame.json ---
	var save := PlayerLife.load_savegame()
	# BM_POP_FIN_APPLY_V2 ------------------------------------------------------
	PlayerLife.ensure_finance_schema(save)

	var _finance_euros_before_match: int = 0
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		_finance_euros_before_match = int((save["finance"] as Dictionary).get("euros", 0))
	elif save.has("wallet") and typeof(save["wallet"]) == TYPE_DICTIONARY:
		_finance_euros_before_match = int((save["wallet"] as Dictionary).get("euros", 0))

	var _total_recettes_before_match: int = int(save.get("total_recettes", 0))
	var _total_depenses_before_match: int = int(save.get("total_depenses", 0))

	# BM_ROUND_PERSIST_V2: source unique = save[season_round] (ne dépend pas de SeasonState)
	var round_index_local := int(save.get("season_round", 0))
	if save.has("progress") and typeof(save["progress"]) == TYPE_DICTIONARY:
		var progress_local: Dictionary = save["progress"] as Dictionary
		round_index_local = maxi(0, int(progress_local.get("journee", round_index_local + 1)) - 1)
	var last_round := int(save.get("last_pop_fin_round", -999))
	var already_applied := (last_round == round_index_local)

	var did_draw_local := (score_dom == score_ext)
	var did_win_local := false
	if _user_is_home:
		did_win_local = (score_dom > score_ext)
	else:
		did_win_local = (score_ext > score_dom)

	# BM_DBG_POP_V1
	print("[POP][DBG] already_applied=", already_applied, " round=", round_index_local, " last=", int(save.get('last_pop_fin_round', -999)), " season_round=", int(save.get('season_round', -1)), " pop=", int(save.get('popularite', 50)))
	if not already_applied:
		print("APPLY POP CALLED")
		_apply_popularity_after_match(save, did_win_local, did_draw_local)
		print("[DBG LAST WRITE] season_results=", save.get("season_results", {}))
		PlayerLife.write_savegame(save)

	if not already_applied and _user_is_home:
		var coef := PlayerLife.popularity_coef(save)
		var prev_ticket := _compute_ticketing_prevision(save)
		var prev_shop := _compute_shop_prevision(save)
		var rec_ticket := int(round(float(prev_ticket) * coef))
		var shop_price_volume_coef := _bm_shop_price_volume_coef_from_save(save)
		var rec_shop := int(round(float(prev_shop) * coef * shop_price_volume_coef))

		# BM_SHOP_STOCK_SALES_V1
		# Avant match 14 : on garde l'ancien système simple.
		# À partir du match 14 : les ventes consomment le stock réel ligne par ligne.
		if round_index_local >= 13 and save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
			var shop_d: Dictionary = save["shop"] as Dictionary
			if shop_d.has("items") and typeof(shop_d["items"]) == TYPE_DICTIONARY and shop_d.has("stock_state") and typeof(shop_d["stock_state"]) == TYPE_DICTIONARY:
				var items_d: Dictionary = shop_d["items"] as Dictionary
				var stock_state: Dictionary = shop_d["stock_state"] as Dictionary
				var real_shop_income: int = 0
				for pid_v in items_d.keys():
					var pid := str(pid_v)
					var item_any: Variant = items_d[pid_v]
					if typeof(item_any) != TYPE_DICTIONARY:
						continue
					var item: Dictionary = item_any as Dictionary
					if not bool(item.get("enabled", true)):
						continue
					var price: int = int(item.get("price", 0))
					if price <= 0:
						continue
					var st_any: Variant = stock_state.get(pid, {})
					if typeof(st_any) != TYPE_DICTIONARY:
						continue
					var st: Dictionary = st_any as Dictionary
					var current_stock: int = maxi(0, int(st.get("current", item.get("qty", 0))))
					var wanted_sold: int = int(round(float(current_stock) * coef * shop_price_volume_coef))
					var sold: int = clampi(wanted_sold, 0, current_stock)
					st["current"] = maxi(0, current_stock - sold)
					st["last_sold"] = sold
					stock_state[pid] = st
					real_shop_income += sold * price
				shop_d["stock_state"] = stock_state
				save["shop"] = shop_d
				rec_shop = real_shop_income

		save["total_billetterie"] = int(save.get("total_billetterie", 0)) + rec_ticket
		save["total_boutique"] = int(save.get("total_boutique", 0)) + rec_shop
		save["total_recettes"] = int(save.get("total_recettes", 0)) + rec_ticket + rec_shop

		if not save.has("shop") or typeof(save["shop"]) != TYPE_DICTIONARY:
			save["shop"] = {}
		(save["shop"] as Dictionary)["last_game_sales_coef"] = coef
		(save["shop"] as Dictionary)["last_price_volume_coef"] = shop_price_volume_coef

		# Pas de crédit direct de finance.euros ici :
		# wallet / finance sont recalculés plus bas à partir des cumuls.

	if not already_applied and round_index_local != -1:
		save["last_pop_fin_round"] = round_index_local
	var played_ids: Array = _bm_get_effective_played_ids(save)
	print("[MATCHSIM][PLAYED_IDS_BEFORE_POST] ", played_ids)
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		print("[MATCHSIM][ROSTER_SELECTED_IDS] ", (save["roster"] as Dictionary).get("selected_ids", []))
		print("[MATCHSIM][ROSTER_MATCH_SELECTED_IDS] ", (save["roster"] as Dictionary).get("match_selected_ids", []))

	var did_win := false
	if _user_is_home:
		did_win = (score_dom > score_ext)
	else:
		did_win = (score_ext > score_dom)
	
	# --- Shop income (local scope, no name collisions) ---
	var _shop_pop_raw := 50
	_shop_pop_raw = int(save.get("popularite", 50))
	var _shop_pop_val := clampi(_shop_pop_raw, 30, 100)
	var _shop_coef := float(_shop_pop_val) / 100.0

	var _shop_forecast := 0
	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		_shop_forecast = int((save["shop"] as Dictionary).get("total_forecast", 0))
		
	var shop_income := int(round(float(_shop_forecast) * _shop_coef))
	if shop_income < 0:
		shop_income = 0
	# -----------------------------------------------
	print("[POP BEFORE apply_post_match] =", save.get("popularite", -1))

	# --- KEEP STADIUM / FINANCE STADIUM FIELDS ------------------------------
	var _stadium_keep: Dictionary = {}
	if save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		_stadium_keep = (save["stadium"] as Dictionary).duplicate(true)

	var _finance_stadium_keep: Dictionary = {}
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		var _fin_keep: Dictionary = save["finance"] as Dictionary
		_finance_stadium_keep["total_cout_evolution_stade"] = int(_fin_keep.get("total_cout_evolution_stade", 0))
		_finance_stadium_keep["dernier_achat_stade_cout"] = int(_fin_keep.get("dernier_achat_stade_cout", 0))
		_finance_stadium_keep["dernier_achat_stade_label"] = str(_fin_keep.get("dernier_achat_stade_label", ""))
	# -----------------------------------------------------------------------

	# 🔒 Sauvegarde ticketing AVANT overwrite
	var _ticketing_keep := {}
	if save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		var _st := save["stadium"] as Dictionary
		if _st.has("ticketing") and typeof(_st["ticketing"]) == TYPE_DICTIONARY:
			_ticketing_keep = _st["ticketing"].duplicate(true)

	print("[MATCHSIM][PLAYED_IDS_BEFORE_APPLY] ", played_ids)
	for _pid in played_ids:
		print("[MATCHSIM][PLAYED_ID_ITEM] ", _pid, " type=", typeof(_pid))

	save = PlayerLife.apply_post_match_to_save(save, played_ids, did_win)

	# FATIGUE HOTFIX DIRECT: appliquer sur le save réellement écrit en fin de match
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		var by_id: Dictionary = save["players_by_id"] as Dictionary
		var played_keys := {}
		for raw_id in played_ids:
			var sid := str(raw_id).strip_edges()
			if sid == "":
				continue
			played_keys[str(int(round(float(sid))))] = true

		for pid in by_id.keys():
			var p = by_id[pid]
			if typeof(p) != TYPE_DICTIONARY:
				continue

			PlayerLife._ensure_player_schema(p)
			var key := str(pid).strip_edges()
			var is_played := played_keys.has(key)

			if is_played:
				p["fatigue"] = clampi(int(p.get("fatigue", 0)) + int(PlayerLife.FATIGUE_GAIN_PLAY), int(PlayerLife.FATIGUE_MIN), int(PlayerLife.FATIGUE_MAX))
				p["matchs_consecutifs"] = int(p.get("matchs_consecutifs", 0)) + 1
				p["repos_consecutifs"] = 0
				p["motivation"] = clampi(
					int(p.get("motivation", 50)) + (int(PlayerLife.MOTIV_WIN_GAIN) if did_win else -int(PlayerLife.MOTIV_LOSS_DROP)),
					int(PlayerLife.MOTIV_MIN),
					int(PlayerLife.MOTIV_MAX)
				)
			else:
				p["fatigue"] = clampi(int(p.get("fatigue", 0)) - int(PlayerLife.FATIGUE_RECOVER_REST), int(PlayerLife.FATIGUE_MIN), int(PlayerLife.FATIGUE_MAX))
				p["repos_consecutifs"] = int(p.get("repos_consecutifs", 0)) + 1
				p["matchs_consecutifs"] = 0
				p["motivation"] = clampi(
					int(p.get("motivation", 50)) + int(PlayerLife.MOTIV_REST_GAIN),
					int(PlayerLife.MOTIV_MIN),
					int(PlayerLife.MOTIV_MAX)
				)

			PlayerLife._recalc_derived(p)
			by_id[pid] = p

		save["players_by_id"] = by_id

	# --- MISSIONS V1 : compteurs match ---
	if not save.has("missions_state") or typeof(save["missions_state"]) != TYPE_DICTIONARY:
		save["missions_state"] = {}
	var _missions_state: Dictionary = save["missions_state"] as Dictionary

	if not _missions_state.has("counters") or typeof(_missions_state["counters"]) != TYPE_DICTIONARY:
		_missions_state["counters"] = {}
	var _missions_counters: Dictionary = _missions_state["counters"] as Dictionary

	_missions_counters["wins_total"] = int(_missions_counters.get("wins_total", 0))
	_missions_counters["win_streak"] = int(_missions_counters.get("win_streak", 0))
	_missions_counters["pts_75_plus"] = int(_missions_counters.get("pts_75_plus", 0))

	if did_win:
		_missions_counters["wins_total"] = int(_missions_counters["wins_total"]) + 1
		_missions_counters["win_streak"] = int(_missions_counters["win_streak"]) + 1
	else:
		_missions_counters["win_streak"] = 0

	if int(user_score) >= 75:
		_missions_counters["pts_75_plus"] = int(_missions_counters["pts_75_plus"]) + 1

	_missions_state["counters"] = _missions_counters
	save["missions_state"] = _missions_state
	print("[MISSIONS][MATCH] wins_total=", int(_missions_counters.get("wins_total", 0)), " win_streak=", int(_missions_counters.get("win_streak", 0)), " pts_75_plus=", int(_missions_counters.get("pts_75_plus", 0)))

	# 🔒 Restauration ticketing APRÈS overwrite
	if not _ticketing_keep.is_empty():
		if not save.has("stadium") or typeof(save["stadium"]) != TYPE_DICTIONARY:
			save["stadium"] = {}
		(save["stadium"] as Dictionary)["ticketing"] = _ticketing_keep

	if not _stadium_keep.is_empty():
		var _st_after := _stadium_keep

		if not _ticketing_keep.is_empty():
			_st_after["ticketing"] = _ticketing_keep

		if not save.has("stadium") or typeof(save["stadium"]) != TYPE_DICTIONARY:
			save["stadium"] = {}

		var _st_current := save["stadium"] as Dictionary

		for k in _st_after.keys():
			if k != "ticketing":
				_st_current[k] = _st_after[k]

		save["stadium"] = _st_current

	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}
	var _fin_after: Dictionary = save["finance"] as Dictionary
	for _k in _finance_stadium_keep.keys():
		_fin_after[_k] = _finance_stadium_keep[_k]

	print("[POP AFTER apply_post_match] =", save.get("popularite", -1))

	# ✅ Salaires + XP/level : 1 seule fois / match (anti double-compte)
	# On le fait APRÈS apply_post_match_to_save() car il réécrit 'save'.
	if not already_applied:
		_apply_salaries_and_level(save, did_win, did_draw_local)
		PlayerLife.ensure_finance_schema(save)
		var salary_match := _compute_total_salary_per_match(save)
		save["salary_total_per_match"] = salary_match
		save["total_depenses"] = int(save.get("total_depenses", 0)) + salary_match
		save["total_salaires"] = int(save.get("total_salaires", 0)) + salary_match
		var score_equipe: int = int(score_dom if _user_is_home else score_ext)
		if score_equipe >= 90:
			var ms90: Dictionary = save.get("missions_state", {}) as Dictionary
			var c90: Dictionary = ms90.get("counters", {}) as Dictionary
			c90["pts_90_plus"] = int(c90.get("pts_90_plus", 0)) + 1
			if score_equipe >= 100:
				c90["pts_100_plus"] = int(c90.get("pts_100_plus", 0)) + 1
			ms90["counters"] = c90
			save["missions_state"] = ms90
		SponsorDataRef.apply_per_match_revenue_to_save(save)

	# Revenus boutique déjà cumulés plus haut dans le bloc domicile.

	# Sync wallet -> finance après la dernière écriture de la frame
	# Sync wallet <-> finance après la dernière écriture de la frame
	_ensure_club_wallet_schema(save)
	if save.has("wallet") and typeof(save["wallet"]) == TYPE_DICTIONARY and save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		var _recettes_cumulees: int = int(save.get("total_recettes", 0))
		var _depenses_cumulees: int = int(save.get("total_depenses", 0))
		var _wallet_after_match: int = _recettes_cumulees - _depenses_cumulees
		if _wallet_after_match < 0:
			_wallet_after_match = 0

		print("[WALLET DBG] recettes=", _recettes_cumulees, " depenses=", _depenses_cumulees, " wallet_after=", _wallet_after_match)
		(save["finance"] as Dictionary)["euros"] = _wallet_after_match
		(save["wallet"] as Dictionary)["euros"] = _wallet_after_match
		print("[WALLET DBG] saved finance.euros=", (save["finance"] as Dictionary).get("euros", -1), " wallet.euros=", (save["wallet"] as Dictionary).get("euros", -1))
		_append_finance_history_to_save(save)

	if not save.has("season_results") or typeof(save["season_results"]) != TYPE_DICTIONARY:
		save["season_results"] = {}
	var season_results_final: Dictionary = save["season_results"] as Dictionary
	var round_key_final := str(round_index_local)
	if not season_results_final.has(round_key_final) or typeof(season_results_final[round_key_final]) != TYPE_DICTIONARY:
		season_results_final[round_key_final] = {}
	var result_key_final := str(_team_dom_name) + "||" + str(_team_ext_name)
	(season_results_final[round_key_final] as Dictionary)[result_key_final] = {
		"score_dom": int(score_dom),
		"score_ext": int(score_ext)
	}
	save["season_results"] = season_results_final

	var _total_recettes_after_match: int = int(save.get("total_recettes", 0))
	var _total_depenses_after_match: int = int(save.get("total_depenses", 0))

	var recettes_match: int = maxi(0, _total_recettes_after_match - _total_recettes_before_match)
	var depenses_match: int = maxi(0, _total_depenses_after_match - _total_depenses_before_match)
	var popup_expenses_splus1_coach_fee_pending: int = int(save.get("popup_expenses_splus1_coach_fee_pending", 0))
	print("[POPUP S+1][BEFORE STORE] dep_before=", int(_total_depenses_before_match), " dep_after=", int(_total_depenses_after_match), " dep_match_raw=", int(depenses_match), " coach_fee_pending=", int(popup_expenses_splus1_coach_fee_pending))
	if popup_expenses_splus1_coach_fee_pending > 0:
		depenses_match = maxi(0, depenses_match - popup_expenses_splus1_coach_fee_pending)
		print("[POPUP S+1][AFTER SUB] dep_match_fixed=", int(depenses_match))
		save.erase("popup_expenses_splus1_coach_fee_pending")

	var xp_match: int = XP_LOSS
	if did_draw_local:
		xp_match = XP_DRAW
	elif did_win:
		xp_match = XP_WIN

	_store_last_match_finance_popup(save, recettes_match, depenses_match, xp_match)


	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster_reset: Dictionary = save["roster"] as Dictionary
		var auto_save_paid: bool = bool(roster_reset.get("auto_save_match_selection_paid", false))
		if not auto_save_paid:
			roster_reset["match_selected_ids"] = []
		save["roster"] = roster_reset

	PlayerLife.write_savegame(save)

	# Mise à jour saison
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss != null:
		# ✅ round du match réellement joué = round_index_local
		var round_index: int = int(round_index_local)
		ss.matchs_joues = round_index
		print("[ROUND][SOURCE OF TRUTH] round_index=", round_index, " ss.matchs_joues=", int(ss.matchs_joues), " save.season_round=", int(save.get("season_round", -1)))

		# 1) enregistrer le match user pour la journée round_index
		if ss.has_method("register_match_result"):
			ss.call("register_match_result", _team_dom_name, _team_ext_name, score_dom, score_ext, _user_team_name)

			if not save.has("season_results") or typeof(save["season_results"]) != TYPE_DICTIONARY:
				save["season_results"] = {}
			var season_results_local: Dictionary = save["season_results"] as Dictionary
			var round_key_local := str(round_index)
			if not season_results_local.has(round_key_local) or typeof(season_results_local[round_key_local]) != TYPE_DICTIONARY:
				season_results_local[round_key_local] = {}
			var result_key_local := str(_team_dom_name) + "||" + str(_team_ext_name)
			(season_results_local[round_key_local] as Dictionary)[result_key_local] = {
				"score_dom": int(score_dom),
				"score_ext": int(score_ext)
			}
			save["season_results"] = season_results_local

		# 2) simuler les autres matchs de la même journée round_index
		if ss.has_method("simulate_other_games_for_round"):
			ss.call("simulate_other_games_for_round", _team_dom_name, _team_ext_name, round_index, _user_team_name)
			_persist_ranking_history_to_save()

			# --- Apply final rank-based popularity modifier AFTER real standings persist ---
			var save_rank := PlayerLife.load_savegame()
			if save_rank.has("ranking_history") and typeof(save_rank["ranking_history"]) == TYPE_ARRAY:
				var hist: Array = save_rank["ranking_history"]
				if hist.size() > 0:
					var current_rank := int(hist[hist.size() - 1])
					print("[POP][RANK FINAL] current_rank=", current_rank)

					var pop_final := int(save_rank.get("popularite", 50))
					if current_rank <= 3:
						pop_final += 2
					elif current_rank <= 6:
						pop_final += 1
					elif current_rank >= 10:
						pop_final -= 1

					pop_final = clampi(pop_final, 30, 100)
					save_rank["popularite"] = pop_final
					if save.has("season_results") and typeof(save["season_results"]) == TYPE_DICTIONARY:
						save_rank["season_results"] = (save["season_results"] as Dictionary).duplicate(true)
					PlayerLife.write_savegame(save_rank)
					print("[POP][RANK FINAL APPLIED] pop=", pop_final)

		# 3) incrémenter APRES la journée complète (une seule fois)
		ss.matchs_joues = mini(round_index_local + 1, int(SeasonState.total_matchs_saison))

		# --- FINAL FRESH SAVE SYNC (source de vérité disque) ---
		var save_sync := PlayerLife.load_savegame()
		if typeof(save_sync) != TYPE_DICTIONARY:
			save_sync = {}

		save_sync["season_round"] = int(ss.matchs_joues)

		print(
			"[FUNNEL RAW]",
			"round=", ss.matchs_joues,
			"flag=", save_sync.get("funnel_first_match_finished_sent", false)
		)

		if int(save_sync.get("season_round", 0)) >= 1:
			_bm_send_generic_funnel_event(
				"first-match-finished",
				"funnel_first_match_finished_sent",
				{
					"season_number": int(save_sync.get("season_number", 1)),
					"match_number": int(save_sync.get("season_round", 0))
				}
			)

		if not save_sync.has("progress") or typeof(save_sync["progress"]) != TYPE_DICTIONARY:
			save_sync["progress"] = {}
		var next_journee_sync: int = int(ss.matchs_joues) + 1
		if int(ss.matchs_joues) >= int(SeasonState.total_matchs_saison):
			next_journee_sync = int(SeasonState.total_matchs_saison)
		(save_sync["progress"] as Dictionary)["journee"] = next_journee_sync



		if not save_sync.has("season_results") or typeof(save_sync["season_results"]) != TYPE_DICTIONARY:
			save_sync["season_results"] = {}
		var season_results_sync: Dictionary = save_sync["season_results"] as Dictionary
		var round_key_sync := str(round_index)
		var round_results_sync: Dictionary = {}
		if season_results_sync.has(round_key_sync) and typeof(season_results_sync[round_key_sync]) == TYPE_DICTIONARY:
			round_results_sync = season_results_sync[round_key_sync] as Dictionary
		var result_key_sync := str(_team_dom_name) + "||" + str(_team_ext_name)
		round_results_sync[result_key_sync] = {
			"score_dom": int(score_dom),
			"score_ext": int(score_ext)
		}
		season_results_sync[round_key_sync] = round_results_sync
		save_sync["season_results"] = season_results_sync

		if save_sync.has("roster") and typeof(save_sync["roster"]) == TYPE_DICTIONARY:
			var roster_sync_reset: Dictionary = save_sync["roster"] as Dictionary
			var auto_save_sync_paid: bool = bool(roster_sync_reset.get("auto_save_match_selection_paid", false))
			if not auto_save_sync_paid:
				roster_sync_reset["match_selected_ids"] = []
			save_sync["roster"] = roster_sync_reset

		print("[DBG ROUND SYNC FRESH] season_results=", JSON.stringify(save_sync["season_results"]))
		PlayerLife.write_savegame(save_sync)
		if int(save_sync.get("season_number", 1)) == 1 and int(save_sync.get("season_round", 0)) >= int(SeasonState.total_matchs_saison):
			_bm_send_generic_funnel_event(
				"season-finished",
				"funnel_season_finished_sent",
				{"season_number": 1, "match_number": int(save_sync.get("season_round", 0))}
			)
		print("[ROUND][SYNC FULL] season_round=", int(save_sync.get("season_round", -1)), " progress.journee=", int((save_sync["progress"] as Dictionary).get("journee", -1)), " season_results=", JSON.stringify(save_sync.get("season_results", {})))

		# --- SEASON TOP 4 REWARD ------------------------------------------------
		if int(ss.matchs_joues) >= int(SeasonState.total_matchs_saison):
			var reward_season_key := str(save_sync.get("season_id", "season_1"))
			if not save_sync.has("season_top4_rewards_granted") or typeof(save_sync["season_top4_rewards_granted"]) != TYPE_DICTIONARY:
				save_sync["season_top4_rewards_granted"] = {}
			var granted_map: Dictionary = save_sync["season_top4_rewards_granted"] as Dictionary

			if not bool(granted_map.get(reward_season_key, false)):
				var final_rank := 99
				if save_sync.has("ranking_history") and typeof(save_sync["ranking_history"]) == TYPE_ARRAY:
					var rh: Array = save_sync["ranking_history"]
					if rh.size() > 0:
						final_rank = int(rh[rh.size() - 1])

				var euros_gain := 0
				var tokens_gain := 0
				if final_rank == 1:
					euros_gain = 120000
					tokens_gain = 15
				elif final_rank == 2:
					euros_gain = 80000
					tokens_gain = 8
				elif final_rank == 3:
					euros_gain = 50000
				elif final_rank == 4:
					euros_gain = 25000

				if euros_gain > 0 or tokens_gain > 0:
					if not save_sync.has("wallet") or typeof(save_sync["wallet"]) != TYPE_DICTIONARY:
						save_sync["wallet"] = {}
					var wallet_sync: Dictionary = save_sync["wallet"] as Dictionary
					wallet_sync["euros"] = int(wallet_sync.get("euros", 0)) + euros_gain
					wallet_sync["tokens"] = int(wallet_sync.get("tokens", 0)) + tokens_gain
					save_sync["wallet"] = wallet_sync

					if not save_sync.has("finance") or typeof(save_sync["finance"]) != TYPE_DICTIONARY:
						save_sync["finance"] = {}
					var finance_sync: Dictionary = save_sync["finance"] as Dictionary
					finance_sync["euros"] = int(wallet_sync.get("euros", 0))
					save_sync["finance"] = finance_sync

					save_sync["total_tournois"] = int(save_sync.get("total_tournois", 0)) + euros_gain
					granted_map[reward_season_key] = true
					save_sync["season_top4_rewards_granted"] = granted_map
					save_sync["pending_season_reward"] = {
						"rank": final_rank,
						"euros": euros_gain,
						"tokens": tokens_gain
					}
					save_sync["pending_season_reward_popup"] = {
						"rank": int(final_rank),
						"euros": int(euros_gain),
						"tokens": int(tokens_gain)
					}

					PlayerLife.write_savegame(save_sync)
					print("[SEASON REWARD STORED] rank=", final_rank, " euros=+", euros_gain, " tokens=+", tokens_gain)



		# --- STADIUM WORKS SYNC -------------------------------------------------
		var save_singleton := get_node_or_null("/root/SaveSingleton")
		if save_singleton != null and save_singleton.has_method("stadium_sync_travaux"):
			var current_matchs_saison: int = int(save.get("season_round", 0))
			var sync_any: Variant = save_singleton.call("stadium_sync_travaux", current_matchs_saison)
			if typeof(sync_any) == TYPE_DICTIONARY:
				var sync_result: Dictionary = sync_any as Dictionary
				if bool(sync_result.get("finished", false)):
					print("[STADIUM] travaux terminés -> niveau ", sync_result.get("new_ng"), ".", sync_result.get("new_ns"))
		# ----------------------------------------------------------------------

		# 4) préparer l'adversaire suivant (optionnel)
		if ss.has_method("get_user_fixture_for_round"):
			var fx: Dictionary = ss.call("get_user_fixture_for_round", _user_team_name, int(ss.matchs_joues))
			if typeof(fx) == TYPE_DICTIONARY and fx.size() > 0:
				ss.opponent_name = str(fx.get("opponent", "")).strip_edges()

	if btn_retour != null:
		_bm_style_btn_retour()
		btn_retour.disabled = false

func _bm_should_show_skip_final_result_button() -> bool:
	if not BM_SKIP_FINAL_RESULT_TOKEN_MODE:
		return true
	var save: Dictionary = PlayerLife.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return false
	return int(save.get("season_number", 1)) >= 2


func _bm_show_skip_final_result_not_enough_tokens() -> void:
	if btn_skip == null:
		return

	var old_msg := get_node_or_null("SkipFinalResultNoTokensMsg")
	if old_msg != null:
		old_msg.queue_free()

	var msg := Label.new()
	msg.name = "SkipFinalResultNoTokensMsg"
	msg.text = _bm_matchsim_tr_fallback("matchsim.not_enough_tokens_inline", "Not enough tokens")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", Color(1.0, 0.18, 0.16, 1.0))
	msg.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.95))
	msg.add_theme_constant_override("outline_size", 2)
	msg.size = Vector2(260, 28)
	msg.position = Vector2(btn_skip.position.x + (btn_skip.size.x - msg.size.x) * 0.5, btn_skip.position.y + btn_skip.size.y + 8.0)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)

	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(msg, "modulate:a", 0.0, 0.35)
	tw.finished.connect(func():
		if is_instance_valid(msg):
			msg.queue_free()
	)


func _on_btn_skip_gate_pressed() -> void:
	if not BM_SKIP_FINAL_RESULT_TOKEN_MODE:
		_on_btn_skip_pressed()
		return

	if not _bm_should_show_skip_final_result_button():
		return

	var save: Dictionary = PlayerLife.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return

	if not save.has("wallet") or typeof(save["wallet"]) != TYPE_DICTIONARY:
		save["wallet"] = {}

	var wallet: Dictionary = save["wallet"] as Dictionary
	var tokens_now: int = int(wallet.get("tokens", 0))
	if tokens_now < BM_SKIP_FINAL_RESULT_TOKEN_COST:
		_bm_show_skip_final_result_not_enough_tokens()
		return

	wallet["tokens"] = tokens_now - BM_SKIP_FINAL_RESULT_TOKEN_COST
	save["wallet"] = wallet
	PlayerLife.write_savegame(save)

	_on_btn_skip_pressed()


func _on_btn_skip_pressed() -> void:
	# Avance le match jusqu'à la fin sans changer la simulation : on saute l'attente.
	if match_fini:
		return

	# Stop timer et bascule l'affichage sur le score final (timeline dernière valeur)
	timer.stop()
	minute = MATCH_DUREE_MINUTES

	if _timeline_dom.size() > 0:
		score_dom = int(_timeline_dom[_timeline_dom.size() - 1])
	if _timeline_ext.size() > 0:
		score_ext = int(_timeline_ext[_timeline_ext.size() - 1])

	_update_ui()
	_fin_match()


func _on_btn_retour_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuSaison.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_bm_matchsim_apply_mobile_layout")
