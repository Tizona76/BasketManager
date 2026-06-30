extends Control

signal back_requested

const PlayerLife := preload("res://scripts/PlayerLife.gd")
const TuningData := preload("res://scripts/TuningData.gd")

const TOURNOIS_INFOS := {
	"tournoi_a": {
		"nom_key": "tournois.tournament_a",
		"nb_equipes": 8
	},
	"intermediaire": {
		"nom_key": "tournois.intermediate",
		"nb_equipes": 8
	},
	"elite": {
		"nom_key": "tournois.elite",
		"nb_equipes": 16
	}
}

var tournoi_survole_id: String = ""
var tournoi_selectionne_popup: String = ""

var lbl_result_tournoi_a: RichTextLabel = null
var lbl_result_intermediaire: RichTextLabel = null
var lbl_result_elite: RichTextLabel = null

@onready var btn_tournoi_a: Button = get_node("UI/Center/VBox/ButtonsRow/BtnTournoiA") as Button
@onready var btn_intermediaire: Button = get_node("UI/Center/VBox/ButtonsRow/BtnIntermediaire") as Button
@onready var btn_elite: Button = get_node("UI/Center/VBox/ButtonsRow/BtnElite") as Button
@onready var btn_retour: Button = get_node("UI/BtnRetour") as Button
@onready var lbl_info: Label = get_node("UI/Center/VBox/LblInfo") as Label

@onready var panel_tournoi_info: Panel = get_node("UI/PanelTournoiInfo") as Panel
@onready var lbl_tournoi_info_titre: Label = get_node("UI/PanelTournoiInfo/Margin/VBox/LblTournoiInfoTitre") as Label
@onready var lbl_tournoi_info_nb_equipes: Label = get_node("UI/PanelTournoiInfo/Margin/VBox/LblTournoiInfoNbEquipes") as Label
@onready var lbl_tournoi_info_prix: Label = get_node("UI/PanelTournoiInfo/Margin/VBox/LblTournoiInfoPrix") as Label
@onready var lbl_tournoi_info_finaliste: RichTextLabel = get_node("UI/PanelTournoiInfo/Margin/VBox/LblTournoiInfoFinaliste") as RichTextLabel
@onready var lbl_tournoi_info_champion: RichTextLabel = get_node("UI/PanelTournoiInfo/Margin/VBox/LblTournoiInfoChampion") as RichTextLabel
var btn_tournoi_info_confirm: Button = null

@onready var popup_confirm: Panel = get_node("UI/PopupConfirmTournoi") as Panel
@onready var lbl_popup_text: Label = get_node("UI/PopupConfirmTournoi/VBox/LblPopupText") as Label
@onready var btn_popup_ok: Button = get_node("UI/PopupConfirmTournoi/VBox/BtnOK") as Button
@onready var btn_popup_close: Button = get_node("UI/PopupConfirmTournoi/BtnClose") as Button

func _play_tournois_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("play_music"):
		am.call("play_music", "res://assets/audio_mp3/tournois.mp3", true, false)

func _stop_tournois_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("stop_music"):
		am.call("stop_music")

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if panel_tournoi_info != null and not is_instance_valid(panel_tournoi_info):
		return
	_bm_update_tournoi_hover()

func _bm_apply_pale_orange_tournament_button_style(btn: Button) -> void:
	if btn == null:
		return
	var normal := load("res://ui/styleboxes/btn_match.tres") as StyleBox
	var hover := load("res://ui/styleboxes_nba/btn_match_hover.tres") as StyleBox
	var pressed := load("res://ui/styleboxes_nba/btn_match_pressed.tres") as StyleBox
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

func _bm_make_tournois_back_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
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


func _ready() -> void:
	_play_tournois_music()

	if btn_retour != null:
		btn_retour.text = tr("tournois.back_to_season")
		var back_normal := _bm_make_tournois_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
		var back_hover := _bm_make_tournois_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
		var back_pressed := _bm_make_tournois_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
		var back_disabled := _bm_make_tournois_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)
		btn_retour.add_theme_stylebox_override("normal", back_normal)
		btn_retour.add_theme_stylebox_override("hover", back_hover)
		btn_retour.add_theme_stylebox_override("focus", back_hover)
		btn_retour.add_theme_stylebox_override("pressed", back_pressed)
		btn_retour.add_theme_stylebox_override("disabled", back_disabled)
		btn_retour.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_retour.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn_retour.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		btn_retour.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn_retour.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))

	if lbl_info != null:
		lbl_info.text = tr("tournois.select_tournament")
		lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	if btn_tournoi_a != null:
		btn_tournoi_a.text = tr("tournois.tournament_a")
		if not btn_tournoi_a.pressed.is_connected(_on_tournoi_a_pressed):
			btn_tournoi_a.pressed.connect(_on_tournoi_a_pressed)

	if btn_intermediaire != null:
		btn_intermediaire.text = tr("tournois.intermediate")
		if not btn_intermediaire.pressed.is_connected(_on_intermediaire_pressed):
			btn_intermediaire.pressed.connect(_on_intermediaire_pressed)

	if btn_elite != null:
		btn_elite.text = tr("tournois.elite")
		if not btn_elite.pressed.is_connected(_on_elite_pressed):
			btn_elite.pressed.connect(_on_elite_pressed)

	for btn_tournament in [btn_tournoi_a, btn_intermediaire, btn_elite]:
		_bm_apply_pale_orange_tournament_button_style(btn_tournament)

	call_deferred("_bm_ensure_result_labels")
	call_deferred("_bm_refresh_tournament_buttons_state")

	if btn_retour != null:
		if not btn_retour.pressed.is_connected(_on_retour_pressed):
			btn_retour.pressed.connect(_on_retour_pressed)

	if panel_tournoi_info != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.16, 0.94)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(1.00, 0.38, 0.72, 0.78)
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		sb.corner_radius_bottom_left = 18
		sb.corner_radius_bottom_right = 18
		sb.shadow_color = Color(1.00, 0.84, 0.18, 0.34)
		sb.shadow_size = 26
		sb.shadow_offset = Vector2(0, 0)
		panel_tournoi_info.add_theme_stylebox_override("panel", sb)
		panel_tournoi_info.custom_minimum_size = Vector2(430, 310)
		panel_tournoi_info.size = Vector2(430, 310)
		panel_tournoi_info.mouse_filter = Control.MOUSE_FILTER_STOP
		panel_tournoi_info.visible = false
		var info_vbox := panel_tournoi_info.get_node_or_null("Margin/VBox") as VBoxContainer
		if info_vbox != null:
			var top_row := info_vbox.get_node_or_null("TournoiInfoTopRow") as HBoxContainer
			if top_row == null:
				top_row = HBoxContainer.new()
				top_row.name = "TournoiInfoTopRow"
				top_row.add_theme_constant_override("separation", 18)
				info_vbox.add_child(top_row)
				info_vbox.move_child(top_row, 1)
			if lbl_tournoi_info_nb_equipes != null and lbl_tournoi_info_nb_equipes.get_parent() != top_row:
				lbl_tournoi_info_nb_equipes.get_parent().remove_child(lbl_tournoi_info_nb_equipes)
				top_row.add_child(lbl_tournoi_info_nb_equipes)
			if lbl_tournoi_info_prix != null and lbl_tournoi_info_prix.get_parent() != top_row:
				lbl_tournoi_info_prix.get_parent().remove_child(lbl_tournoi_info_prix)
				top_row.add_child(lbl_tournoi_info_prix)
			if lbl_tournoi_info_titre != null:
				lbl_tournoi_info_titre.add_theme_font_size_override("font_size", 30)
			if lbl_tournoi_info_nb_equipes != null:
				lbl_tournoi_info_nb_equipes.add_theme_font_size_override("font_size", 24)
				lbl_tournoi_info_nb_equipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if lbl_tournoi_info_prix != null:
				lbl_tournoi_info_prix.add_theme_font_size_override("font_size", 24)
				lbl_tournoi_info_prix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lbl_tournoi_info_prix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if lbl_tournoi_info_finaliste != null:
				lbl_tournoi_info_finaliste.add_theme_font_size_override("normal_font_size", 24)
			if lbl_tournoi_info_champion != null:
				lbl_tournoi_info_champion.add_theme_font_size_override("normal_font_size", 24)
			btn_tournoi_info_confirm = info_vbox.get_node_or_null("BtnTournoiInfoConfirm") as Button
			if btn_tournoi_info_confirm == null:
				btn_tournoi_info_confirm = Button.new()
				btn_tournoi_info_confirm.name = "BtnTournoiInfoConfirm"
				info_vbox.add_child(btn_tournoi_info_confirm)
			var confirm_spacer := info_vbox.get_node_or_null("TournoiInfoConfirmSpacer") as Control
			if confirm_spacer == null:
				confirm_spacer = Control.new()
				confirm_spacer.name = "TournoiInfoConfirmSpacer"
				info_vbox.add_child(confirm_spacer)
			confirm_spacer.custom_minimum_size = Vector2(0, 14)
			confirm_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info_vbox.move_child(confirm_spacer, info_vbox.get_child_count() - 1)
			info_vbox.move_child(btn_tournoi_info_confirm, info_vbox.get_child_count() - 1)
			btn_tournoi_info_confirm.custom_minimum_size = Vector2(260, 46)
			btn_tournoi_info_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn_tournoi_info_confirm.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirm"
			btn_tournoi_info_confirm.add_theme_font_size_override("font_size", 24)
			_bm_apply_pale_orange_tournament_button_style(btn_tournoi_info_confirm)
			if not btn_tournoi_info_confirm.pressed.is_connected(_on_tournoi_info_confirm_pressed):
				btn_tournoi_info_confirm.pressed.connect(_on_tournoi_info_confirm_pressed)

	if popup_confirm != null:
		popup_confirm.visible = false

	if btn_popup_ok != null:
		if not btn_popup_ok.pressed.is_connected(_on_popup_ok):
			btn_popup_ok.pressed.connect(_on_popup_ok)

	if btn_popup_close != null:
		if not btn_popup_close.pressed.is_connected(_on_popup_close):
			btn_popup_close.pressed.connect(_on_popup_close)

	print("[TOURNOIS] TournoisAccueil ready")


func _bm_load_tournois_save_dict() -> Dictionary:
	return PlayerLife.load_savegame()

func _bm_get_current_season_key_for_tournois() -> String:
	var d := _bm_load_tournois_save_dict()
	var season_number := int(d.get("season_number", 1))
	if season_number < 1:
		season_number = 1
	return "season_" + str(season_number)

func _bm_get_tournament_result_for_current_season(tournoi_id: String) -> String:
	var d := _bm_load_tournois_save_dict()
	var all_results = d.get("tournament_results_by_season", {})
	if not (all_results is Dictionary):
		return ""
	var season_key := _bm_get_current_season_key_for_tournois()
	var season_results = all_results.get(season_key, {})
	if not (season_results is Dictionary):
		return ""
	return str(season_results.get(tournoi_id, "")).strip_edges()

func _bm_make_result_label(node_name: String) -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.name = node_name
	lbl.visible = false
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", 32)
	lbl.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	return lbl

func _bm_ensure_result_labels() -> void:
	var ui_root := get_node_or_null("UI") as Control
	if ui_root == null:
		return

	if lbl_result_tournoi_a == null:
		lbl_result_tournoi_a = _bm_make_result_label("LblResultTournoiA")
		ui_root.add_child(lbl_result_tournoi_a)
	if lbl_result_intermediaire == null:
		lbl_result_intermediaire = _bm_make_result_label("LblResultIntermediaire")
		ui_root.add_child(lbl_result_intermediaire)
	if lbl_result_elite == null:
		lbl_result_elite = _bm_make_result_label("LblResultElite")
		ui_root.add_child(lbl_result_elite)

	call_deferred("_bm_place_result_labels")

func _bm_place_one_result_label(btn: Button, lbl: RichTextLabel) -> void:
	if btn == null or lbl == null:
		return
	var parent_ctrl := lbl.get_parent() as Control
	if parent_ctrl == null:
		return
	var btn_global := btn.get_global_rect()
	var parent_global := parent_ctrl.global_position
	lbl.position = btn_global.position - parent_global + Vector2(0, btn.size.y + 8)
	lbl.size = Vector2(btn.size.x, 24)
	
func _bm_place_result_labels() -> void:
	_bm_place_one_result_label(btn_tournoi_a, lbl_result_tournoi_a)
	_bm_place_one_result_label(btn_intermediaire, lbl_result_intermediaire)
	_bm_place_one_result_label(btn_elite, lbl_result_elite)

func _bm_apply_tournament_button_state(btn: Button, lbl: RichTextLabel, tournoi_id: String) -> void:
	if btn == null or lbl == null:
		return
	if not is_instance_valid(btn) or not is_instance_valid(lbl):
		return

	var result := _bm_get_tournament_result_for_current_season(tournoi_id)
	var played := (result != "")

	btn.disabled = played
	btn.modulate = Color(1, 1, 1, 1)

	if played:
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		if result == "winner":
			lbl.text = "[center][img=81x81]res://assets/images/coupe.png[/img] 1er[/center]"
		elif result == "finalist":
			lbl.text = "[center][img=63x63]res://assets/images/medaille_argent.png[/img] 2e[/center]"
		elif result == "played":
			lbl.text = ""
		else:
			lbl.text = ""
		lbl.visible = (lbl.text != "")
	else:
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		lbl.text = ""
		lbl.visible = false

func _bm_refresh_tournament_buttons_state() -> void:
	_bm_ensure_result_labels()
	_bm_apply_tournament_button_state(btn_tournoi_a, lbl_result_tournoi_a, "tournoi_a")
	_bm_apply_tournament_button_state(btn_intermediaire, lbl_result_intermediaire, "intermediaire")
	_bm_apply_tournament_button_state(btn_elite, lbl_result_elite, "elite")

func _on_tournoi_a_pressed() -> void:
	_bm_open_popup("tournoi_a")

func _on_intermediaire_pressed() -> void:
	_bm_open_popup("intermediaire")

func _on_elite_pressed() -> void:
	_bm_open_popup("elite")

func _on_retour_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_stop_tournois_music()
	tree.change_scene_to_file("res://scenes/MenuSaison.tscn")
	print("[TOURNOIS] -> change_scene_to_file(MenuSaison)")

func _bm_get_reward_from_source(tournoi_id: String, outcome: String) -> Dictionary:
	if not TuningData.TOURNAMENT_TUNING.has(tournoi_id):
		return {"euros": 0, "tokens": 0, "xp": 0}
	var tournoi_data: Dictionary = TuningData.TOURNAMENT_TUNING[tournoi_id] as Dictionary
	if not tournoi_data.has(outcome):
		return {"euros": 0, "tokens": 0, "xp": 0}
	var reward: Variant = tournoi_data.get(outcome, {})
	if reward is Dictionary:
		return (reward as Dictionary).duplicate(true)
	return {"euros": 0, "tokens": 0, "xp": 0}

func _bm_get_entry_fee_from_tuning(tournoi_id: String) -> int:
	if not TuningData.TOURNAMENT_TUNING.has(tournoi_id):
		return 0
	var tournoi_data: Dictionary = TuningData.TOURNAMENT_TUNING[tournoi_id] as Dictionary
	return int(tournoi_data.get("entry_fee_euros", 0))

func _bm_update_tournoi_hover() -> void:
	var nouveau_survol := ""

	if btn_tournoi_a != null and btn_tournoi_a.get_global_rect().has_point(get_global_mouse_position()):
		nouveau_survol = "tournoi_a"
	elif btn_intermediaire != null and btn_intermediaire.get_global_rect().has_point(get_global_mouse_position()):
		nouveau_survol = "intermediaire"
	elif btn_elite != null and btn_elite.get_global_rect().has_point(get_global_mouse_position()):
		nouveau_survol = "elite"
	elif panel_tournoi_info != null and panel_tournoi_info.visible and panel_tournoi_info.get_global_rect().has_point(get_global_mouse_position()):
		nouveau_survol = tournoi_survole_id
	elif tournoi_selectionne_popup != "" and TOURNOIS_INFOS.has(tournoi_selectionne_popup):
		nouveau_survol = tournoi_selectionne_popup

	if nouveau_survol != tournoi_survole_id:
		tournoi_survole_id = nouveau_survol
		_bm_refresh_tournoi_info_panel()

func _bm_refresh_tournoi_info_panel() -> void:
	if panel_tournoi_info != null and not is_instance_valid(panel_tournoi_info):
		panel_tournoi_info = null
	if lbl_tournoi_info_titre != null and not is_instance_valid(lbl_tournoi_info_titre):
		lbl_tournoi_info_titre = null
	if lbl_tournoi_info_nb_equipes != null and not is_instance_valid(lbl_tournoi_info_nb_equipes):
		lbl_tournoi_info_nb_equipes = null
	if lbl_tournoi_info_prix != null and not is_instance_valid(lbl_tournoi_info_prix):
		lbl_tournoi_info_prix = null
	if lbl_tournoi_info_finaliste != null and not is_instance_valid(lbl_tournoi_info_finaliste):
		lbl_tournoi_info_finaliste = null
	if lbl_tournoi_info_champion != null and not is_instance_valid(lbl_tournoi_info_champion):
		lbl_tournoi_info_champion = null

	if panel_tournoi_info == null:
		return

	if tournoi_survole_id == "" or not TOURNOIS_INFOS.has(tournoi_survole_id):
		panel_tournoi_info.visible = false
		return

	var data: Dictionary = TOURNOIS_INFOS[tournoi_survole_id]
	panel_tournoi_info.visible = true
	panel_tournoi_info.move_to_front()

	if tournoi_survole_id == "tournoi_a":
		_bm_position_panel_above_button(btn_tournoi_a)
	elif tournoi_survole_id == "intermediaire":
		_bm_position_panel_above_button(btn_intermediaire)
	elif tournoi_survole_id == "elite":
		_bm_position_panel_above_button(btn_elite)

	if lbl_tournoi_info_titre != null:
		lbl_tournoi_info_titre.text = tr(str(data.get("nom_key", "tournois.tournament_a")))

	if lbl_tournoi_info_nb_equipes != null:
		lbl_tournoi_info_nb_equipes.text = "# " + tr("tournois.info.teams") + " : " + str(data.get("nb_equipes", 0))

	if lbl_tournoi_info_prix != null:
		lbl_tournoi_info_prix.text = tr("tournois.info.entry_fee") + " : " + _bm_format_int_spaces(_bm_get_entry_fee_from_tuning(tournoi_survole_id)) + " €"

	if lbl_tournoi_info_finaliste != null:
		var reward_f: Dictionary = _bm_get_reward_from_source(tournoi_survole_id, "finalist")
		var euros_f := int(reward_f.get("euros", 0))
		var tokens_f := int(reward_f.get("tokens", 0))
		var txt_f := tr("tournois.info.runner_up") + " : " + _bm_format_int_spaces(euros_f) + " €"
		if tokens_f > 0:
			txt_f += " + " + _bm_format_int_spaces(tokens_f) + " [img=26x26]res://assets/images/token.png[/img]"
		lbl_tournoi_info_finaliste.text = txt_f

	if lbl_tournoi_info_champion != null:
		var reward_c: Dictionary = _bm_get_reward_from_source(tournoi_survole_id, "victory")
		var euros_c := int(reward_c.get("euros", 0))
		var tokens_c := int(reward_c.get("tokens", 0))
		var txt_c := tr("tournois.info.champion") + " : " + _bm_format_int_spaces(euros_c) + " €"
		if tokens_c > 0:
			txt_c += " + " + _bm_format_int_spaces(tokens_c) + " [img=26x26]res://assets/images/token.png[/img]"
		lbl_tournoi_info_champion.text = txt_c

	if btn_tournoi_info_confirm != null:
		var played := (_bm_get_tournament_result_for_current_season(tournoi_survole_id) != "")
		btn_tournoi_info_confirm.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirm"
		btn_tournoi_info_confirm.visible = not played
		btn_tournoi_info_confirm.disabled = played

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

func _bm_position_panel_above_button(btn: Control) -> void:
	if panel_tournoi_info == null or btn == null:
		return

	var r: Rect2 = btn.get_global_rect()

	var panel_size: Vector2 = panel_tournoi_info.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = panel_tournoi_info.custom_minimum_size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = Vector2(380, 220)

	panel_tournoi_info.size = panel_size

	var x := r.position.x + (r.size.x - panel_size.x) * 0.5
	var y := r.position.y - panel_size.y - 32.0

	x = max(12.0, x)
	y = max(12.0, y)

	panel_tournoi_info.global_position = Vector2(x, y)

func _bm_open_popup(tournoi_id: String) -> void:
	if popup_confirm != null and not is_instance_valid(popup_confirm):
		popup_confirm = null
	if lbl_popup_text != null and not is_instance_valid(lbl_popup_text):
		lbl_popup_text = null
	if btn_popup_ok != null and not is_instance_valid(btn_popup_ok):
		btn_popup_ok = null
	if btn_popup_close != null and not is_instance_valid(btn_popup_close):
		btn_popup_close = null

	if popup_confirm == null:
		return

	tournoi_selectionne_popup = tournoi_id
	tournoi_survole_id = tournoi_id

	var prix := _bm_get_entry_fee_from_tuning(tournoi_id)
	if lbl_popup_text != null:
		lbl_popup_text.text = "Pay " + tr("tournois.info.entry_fee") + " : " + _bm_format_int_spaces(prix) + " ?"

	popup_confirm.visible = false
	popup_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tournoi_id == "tournoi_a":
		_bm_position_panel_above_button(btn_tournoi_a)
	elif tournoi_id == "intermediaire":
		_bm_position_panel_above_button(btn_intermediaire)
	elif tournoi_id == "elite":
		_bm_position_panel_above_button(btn_elite)

	_bm_refresh_tournoi_info_panel()

func _on_tournoi_info_confirm_pressed() -> void:
	if tournoi_survole_id != "" and TOURNOIS_INFOS.has(tournoi_survole_id):
		tournoi_selectionne_popup = tournoi_survole_id
	if tournoi_selectionne_popup == "":
		return
	if _bm_get_tournament_result_for_current_season(tournoi_selectionne_popup) != "":
		return
	_on_popup_ok()

func _on_popup_ok() -> void:
	if popup_confirm != null:
		popup_confirm.visible = false
	if panel_tournoi_info != null:
		panel_tournoi_info.visible = false

	var data: Dictionary = TOURNOIS_INFOS.get(tournoi_selectionne_popup, {})
	var prix := _bm_get_entry_fee_from_tuning(tournoi_selectionne_popup)
	_bm_apply_tournament_fee_to_save(prix)

	if tournoi_selectionne_popup == "tournoi_a":
		SeasonState.bm_init_tournoi_a()
		get_tree().change_scene_to_file("res://scenes/TournoiA.tscn")
	elif tournoi_selectionne_popup == "intermediaire":
		get_tree().change_scene_to_file("res://scenes/TournoiIntermediaire.tscn")
	elif tournoi_selectionne_popup == "elite":
		get_tree().change_scene_to_file("res://scenes/TournoiElite.tscn")

func _on_popup_close() -> void:
	if popup_confirm != null:
		popup_confirm.visible = false


func _bm_position_popup_below_button(btn: Control) -> void:
	if popup_confirm == null or btn == null:
		return

	var r: Rect2 = btn.get_global_rect()

	var popup_size: Vector2 = popup_confirm.size
	if popup_size.x <= 1.0 or popup_size.y <= 1.0:
		popup_size = popup_confirm.custom_minimum_size
	if popup_size.x <= 1.0 or popup_size.y <= 1.0:
		popup_size = Vector2(360, 180)

	popup_confirm.size = popup_size

	var x := r.position.x + (r.size.x - popup_size.x) * 0.5
	var y := r.position.y + r.size.y + 18.0

	x = max(12.0, x)
	y = max(12.0, y)

	popup_confirm.global_position = Vector2(x, y)


func _bm_apply_tournament_fee_to_save(amount: int) -> void:
	if amount <= 0:
		return

	var save: Dictionary = PlayerLife.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		save = {}

	var wallet: Dictionary = {}
	if save.has("wallet") and typeof(save["wallet"]) == TYPE_DICTIONARY:
		wallet = save["wallet"]

	wallet["euros"] = int(wallet.get("euros", 0)) - amount
	save["wallet"] = wallet

	save["total_depenses"] = int(save.get("total_depenses", 0)) + amount
	save["tournois_fees_total"] = int(save.get("tournois_fees_total", 0)) + amount

	# sync compat éventuelle avec finance.euros
	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}
	(save["finance"] as Dictionary)["euros"] = int(wallet.get("euros", 0))

	PlayerLife.write_savegame(save)
