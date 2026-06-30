extends Control

@onready var title_label: Label = $UI/Title
@onready var hdr_nom: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrNom
@onready var hdr_stars: Label = get_node_or_null("UI/Panel/Margin/VBox/HeaderRow/HdrStars") as Label
@onready var hdr_poste: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrPoste
@onready var hdr_age: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrAge
@onready var hdr_fitness: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrFitness
@onready var hdr_tir: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrTir
@onready var hdr_motivation: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrMotivation
@onready var hdr_perf: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrPerf
@onready var hdr_salaire: Label = $UI/Panel/Margin/VBox/HeaderRow/HdrSalaire
@onready var hdr_accuracy: Label = get_node_or_null("UI/Panel/Margin/VBox/HeaderRow/HdrAccuracy") as Label
@onready var rows: VBoxContainer = $UI/Panel/Margin/VBox/Scroll/Rows
@onready var btn_retour: Button = $UI/BtnRetour
@onready var lbl_new_salaries_total: Label = $UI/LblNewSalariesTotal
@onready var lbl_team_full_warning: Label = $UI/LblTeamFullWarning
@onready var lbl_licensed_players: Label = $UI/LblLicensedPlayers
@onready var btn_confirmer_mercato: Button = $UI/BtnConfirmerMercato

var _mercato_sort_key: String = "name"
var _mercato_sort_ascending: bool = true
var _mercato_has_pending_buy_click: bool = false


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


func _bm_apply_back_button_style(btn: Button) -> void:
	if btn == null:
		return

	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	btn.add_theme_font_size_override("font_size", 22)

func _mercato_prepare_myteam_header() -> void:
	var header := get_node_or_null("UI/Panel/Margin/VBox/HeaderRow") as HBoxContainer
	if header == null:
		return
	header.custom_minimum_size = Vector2(0, 50)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 6)
	_mercato_style_header_label(hdr_nom, 88.0)
	if hdr_stars == null:
		hdr_stars = Label.new()
		hdr_stars.name = "HdrStars"
		header.add_child(hdr_stars)
	_mercato_style_header_label(hdr_stars, 72.0)
	_mercato_style_header_label(hdr_poste, 82.0)
	_mercato_style_header_label(hdr_age, 62.0)
	_mercato_style_header_label(hdr_tir, 72.0)
	_mercato_style_header_label(hdr_fitness, 72.0)
	_mercato_style_header_label(hdr_perf, 82.0)
	if hdr_accuracy == null:
		hdr_accuracy = Label.new()
		hdr_accuracy.name = "HdrAccuracy"
		header.add_child(hdr_accuracy)
	_mercato_style_header_label(hdr_accuracy, 88.0)
	_mercato_style_header_label(hdr_motivation, 82.0)
	_mercato_style_header_label(hdr_salaire, 92.0)
	var action := header.get_node_or_null("HdrAction") as Label
	_mercato_style_header_label(action, 170.0)
	if hdr_stars != null:
		header.move_child(hdr_stars, min(1, header.get_child_count() - 1))
	if hdr_tir != null:
		header.move_child(hdr_tir, min(4, header.get_child_count() - 1))
	if hdr_fitness != null:
		header.move_child(hdr_fitness, min(5, header.get_child_count() - 1))
	if hdr_perf != null:
		header.move_child(hdr_perf, min(6, header.get_child_count() - 1))
	if hdr_accuracy != null:
		header.move_child(hdr_accuracy, min(7, header.get_child_count() - 1))
	if hdr_motivation != null:
		header.move_child(hdr_motivation, min(8, header.get_child_count() - 1))
	if hdr_salaire != null:
		header.move_child(hdr_salaire, min(9, header.get_child_count() - 1))
	if action != null:
		header.move_child(action, header.get_child_count() - 1)


func _mercato_style_header_label(lbl: Label, min_w: float) -> void:
	if lbl == null:
		return
	lbl.custom_minimum_size = Vector2(min_w, 34)
	lbl.size = Vector2(min_w, 34)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)


func _ready() -> void:
	_mercato_prepare_myteam_header()
	_apply_i18n()
	_fill_rows()
	_update_new_salaries_ui()
	_connect_sort_header(hdr_nom, "name")
	_connect_sort_header(hdr_stars, "stars")
	_connect_sort_header(hdr_poste, "poste")
	_connect_sort_header(hdr_age, "age")
	_connect_sort_header(hdr_fitness, "vitesse")
	_connect_sort_header(hdr_tir, "tir")
	_connect_sort_header(hdr_perf, "defense")
	_connect_sort_header(hdr_accuracy, "precision")
	_connect_sort_header(hdr_motivation, "motivation")
	_connect_sort_header(hdr_salaire, "salary")
	if btn_retour != null and not btn_retour.pressed.is_connected(_on_btn_retour):
		btn_retour.pressed.connect(_on_btn_retour)
	if btn_confirmer_mercato != null and not btn_confirmer_mercato.pressed.is_connected(_on_btn_confirmer_mercato_pressed):
		btn_confirmer_mercato.pressed.connect(_on_btn_confirmer_mercato_pressed)
		var sb_confirm := StyleBoxFlat.new()
		sb_confirm.corner_radius_top_left = 12
		sb_confirm.corner_radius_top_right = 12
		sb_confirm.corner_radius_bottom_right = 12
		sb_confirm.corner_radius_bottom_left = 12
		sb_confirm.border_width_left = 2
		sb_confirm.border_width_top = 2
		sb_confirm.border_width_right = 2
		sb_confirm.border_width_bottom = 2
		sb_confirm.content_margin_left = 12
		sb_confirm.content_margin_top = 8
		sb_confirm.content_margin_right = 12
		sb_confirm.content_margin_bottom = 8
		sb_confirm.bg_color = Color(0.16, 0.66, 0.30, 1.0)
		sb_confirm.border_color = Color(0.10, 0.42, 0.18, 1.0)
		btn_confirmer_mercato.add_theme_stylebox_override("normal", sb_confirm)
		btn_confirmer_mercato.add_theme_stylebox_override("hover", sb_confirm)
		btn_confirmer_mercato.add_theme_stylebox_override("pressed", sb_confirm)
		btn_confirmer_mercato.add_theme_stylebox_override("focus", sb_confirm)
		btn_confirmer_mercato.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _apply_i18n() -> void:
	print("[MERCATO][I18N] locale=", TranslationServer.get_locale())
	print("[MERCATO][I18N] mercato.title=", tr("mercato.title"))
	print("[MERCATO][I18N] mercato.col.name=", tr("mercato.col.name"))
	print("[MERCATO][I18N] mercato.col.position=", tr("mercato.col.position"))
	print("[MERCATO][I18N] mercato.col.age=", tr("mercato.col.age"))
	print("[MERCATO][I18N] mercato.col.performance=", tr("mercato.col.performance"))
	print("[MERCATO][I18N] mercato.col.salary=", tr("mercato.col.salary"))
	if title_label != null:
		title_label.text = _tr_any(["mercato.title", "menu.mercato"], "Mercato")
	if hdr_nom != null:
		hdr_nom.text = _tr_any(["mercato.col.name"], "Nom")
	if hdr_stars != null:
		hdr_stars.text = "⭐"
	if hdr_poste != null:
		hdr_poste.text = "POS."
	if hdr_age != null:
		hdr_age.text = "AGE"
	if hdr_fitness != null:
		hdr_fitness.text = "SPEED"
	if hdr_tir != null:
		hdr_tir.text = tr("player.attr.tir")
	if hdr_perf != null:
		hdr_perf.text = "DEFENSE"
	if hdr_accuracy != null:
		hdr_accuracy.text = "ACCURACY"
	if hdr_motivation != null:
		hdr_motivation.text = _tr_any(["selection.header.motivation", "mercato.col.motivation"], "Motivation")
	if hdr_salaire != null:
		hdr_salaire.text = "SALARY"
	if btn_retour != null:
		btn_retour.text = _tr_any(["common.back", "btn.back"], "Retour")
		_bm_apply_back_button_style(btn_retour)
	if btn_confirmer_mercato != null:
		btn_confirmer_mercato.text = _tr_any(["mercato.btn.confirm_buy"], "Confirm buy")
	if lbl_new_salaries_total != null:
		lbl_new_salaries_total.text = _tr_any(["mercato.new_salaries_total"], "New salaries") + " : 0 €"
	if lbl_team_full_warning != null:
		lbl_team_full_warning.text = ""
		lbl_team_full_warning.visible = false

func _tr_any(keys: Array, fallback: String) -> String:
	for k in keys:
		var v := tr(str(k))
		if v != "" and v != str(k):
			return v
	return fallback

func _on_btn_retour() -> void:
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _fill_rows() -> void:
	for c in rows.get_children():
		c.queue_free()

	if lbl_team_full_warning != null:
		lbl_team_full_warning.text = ""
		lbl_team_full_warning.visible = false

	
	# Licensed players counter
	if lbl_licensed_players != null:
		var PL = load("res://scripts/PlayerLife.gd")
		var save = {}
		if PL != null and PL.has_method("load_savegame"):
			save = PL.load_savegame()
		if PL != null and PL.has_method("ensure_mercato_schema"):
			PL.ensure_mercato_schema(save)

		var selected_ids = []
		if save.has("roster") and save["roster"] is Dictionary:
			var r = save["roster"]
			if r.has("selected_ids"):
				selected_ids = r["selected_ids"]

		var purchased_ids = []
		if save.has("mercato") and save["mercato"] is Dictionary:
			var m = save["mercato"]
			if m.has("purchased_ids"):
				purchased_ids = m["purchased_ids"]

		var total = selected_ids.size() + purchased_ids.size()
		var display_total = mini(total, 12)
		lbl_licensed_players.text = tr("mercato.licensed_players") % display_total
		lbl_licensed_players.add_theme_font_size_override("font_size", 24)
		lbl_licensed_players.add_theme_color_override("font_color", Color(0.20, 0.55, 0.95, 1.0))
		lbl_licensed_players.add_theme_font_size_override("font_size", 24)
		lbl_licensed_players.add_theme_color_override("font_color", Color(0.20, 0.55, 0.95, 1.0))
		lbl_licensed_players.add_theme_font_size_override("font_size", 22)
		lbl_licensed_players.add_theme_color_override("font_color", Color(0.20, 0.55, 0.95, 1.0))

	var pool: Array = _get_mercato_pool()
	_sort_mercato_pool(pool)
	print("[MERCATO] pool size=", pool.size(), " sort=", _mercato_sort_key, " asc=", _mercato_sort_ascending)
	print("[MERCATO] purchased_ids=", _get_purchased_ids())

	for p in pool:
		if p is Dictionary:
			print("[MERCATO] row=", str((p as Dictionary).get("id", "?")), " name=", str((p as Dictionary).get("nom", (p as Dictionary).get("name", "?"))))
			rows.add_child(_make_row(p))

func _connect_sort_header(lbl: Label, sort_key: String) -> void:
	if lbl == null:
		return
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_sort_header_clicked(sort_key, event.double_click)
	)

func _on_sort_header_clicked(sort_key: String, _reverse_order: bool) -> void:
	if _mercato_sort_key == sort_key:
		_mercato_sort_ascending = not _mercato_sort_ascending
	else:
		_mercato_sort_key = sort_key
		_mercato_sort_ascending = true
	_fill_rows()

func _sort_mercato_pool(pool: Array) -> void:
	if pool.is_empty():
		return

	pool.sort_custom(func(a, b):
		var da: Dictionary = a as Dictionary
		var db: Dictionary = b as Dictionary

		match _mercato_sort_key:
			"name":
				var av := _player_name(da).to_lower()
				var bv := _player_name(db).to_lower()
				return av < bv if _mercato_sort_ascending else av > bv
			"poste":
				var av := _player_poste(da).to_lower()
				var bv := _player_poste(db).to_lower()
				return av < bv if _mercato_sort_ascending else av > bv
			"age":
				var av := int(da.get("age", 0))
				var bv := int(db.get("age", 0))
				return av < bv if _mercato_sort_ascending else av > bv
			"stars":
				var av := _mercato_star_count(da)
				var bv := _mercato_star_count(db)
				return av < bv if _mercato_sort_ascending else av > bv
			"vitesse":
				var av := int(da.get("vitesse", 0))
				var bv := int(db.get("vitesse", 0))
				return av < bv if _mercato_sort_ascending else av > bv
			"tir":
				var av := int(da.get("tir", 0))
				var bv := int(db.get("tir", 0))
				return av < bv if _mercato_sort_ascending else av > bv
			"motivation":
				var av := _player_motivation_value(da)
				var bv := _player_motivation_value(db)
				return av < bv if _mercato_sort_ascending else av > bv
			"defense":
				var av := int(da.get("defense", 0))
				var bv := int(db.get("defense", 0))
				return av < bv if _mercato_sort_ascending else av > bv
			"precision":
				var av := float(da.get("precision", 0.0))
				var bv := float(db.get("precision", 0.0))
				return av < bv if _mercato_sort_ascending else av > bv
			"salary":
				var av := _player_salary_value(da)
				var bv := _player_salary_value(db)
				return av < bv if _mercato_sort_ascending else av > bv
			_:
				var av := _player_name(da).to_lower()
				var bv := _player_name(db).to_lower()
				return av < bv if _mercato_sort_ascending else av > bv
	)

func _get_mercato_pool() -> Array:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		print("[MERCATO] PlayerLife introuvable")
		return []

	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()

	if PL.has_method("ensure_mercato_schema"):
		PL.ensure_mercato_schema(save)

	if not save.has("mercato") or not (save["mercato"] is Dictionary):
		save["mercato"] = {}

	var m: Dictionary = save["mercato"]
	var arr: Array = _resolve_pool_from_save(save, m)

	if arr.is_empty() and PL.has_method("refresh_mercato_pool"):
		print("[MERCATO] pool vide -> refresh_mercato_pool()")
		PL.refresh_mercato_pool(save, "mercato_screen")
		if save.has("mercato") and save["mercato"] is Dictionary:
			m = save["mercato"]
		if PL.has_method("write_savegame"):
			PL.write_savegame(save)
		arr = _resolve_pool_from_save(save, m)

	print("[MERCATO] resolved pool count=", arr.size())
	return arr

func _resolve_pool_from_save(save: Dictionary, m: Dictionary) -> Array:
	# source de vérité unique : current_ids -> players_by_id
	var current_ids: Array = []
	if m.has("current_ids") and m["current_ids"] is Array:
		current_ids = (m["current_ids"] as Array).duplicate()

	var purchased_ids: Array = []
	if m.has("purchased_ids") and m["purchased_ids"] is Array:
		purchased_ids = (m["purchased_ids"] as Array).duplicate()

	if not current_ids.is_empty() and save.has("players_by_id") and save["players_by_id"] is Dictionary:
		var arr: Array = []
		var by_id: Dictionary = save["players_by_id"]
		var purchased_set := {}
		for bought_pid in purchased_ids:
			purchased_set[str(bought_pid).strip_edges()] = true

		for pid in current_ids:
			var k := str(pid).strip_edges()
			if purchased_set.has(k):
				continue

			if by_id.has(k) and by_id[k] is Dictionary:
				arr.append((by_id[k] as Dictionary).duplicate(true))
				continue

			if k.is_valid_float():
				var k_int := str(int(float(k)))
				if purchased_set.has(k_int):
					continue
				if by_id.has(k_int) and by_id[k_int] is Dictionary:
					arr.append((by_id[k_int] as Dictionary).duplicate(true))

		print("[MERCATO] source=current_ids -> players_by_id count=", arr.size())
		return arr

	if save.has("mercato_pool") and save["mercato_pool"] is Array and not (save["mercato_pool"] as Array).is_empty():
		print("[MERCATO] source=mercato_pool")
		return save["mercato_pool"]

	print("[MERCATO] aucune source trouvée")
	return []

func _make_row(p: Dictionary) -> Control:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(0, 104)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.26)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 6
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)

	row.add_child(_make_avatar_name_cell(p))
	row.add_child(_make_cell(_mercato_stars_text(p), 72.0, Color(1.0, 0.78, 0.22, 1.0)))
	row.add_child(_make_cell(_tr_poste(_player_poste(p)), 82.0))
	row.add_child(_make_cell(str(int(p.get("age", 0))), 62.0))
	row.add_child(_make_cell(str(int(p.get("tir", 0))), 72.0))
	row.add_child(_make_cell(str(int(p.get("vitesse", 0))), 72.0, _mercato_stat_color(int(p.get("vitesse", 0)))))
	row.add_child(_make_cell(str(int(p.get("defense", 0))), 82.0, _mercato_stat_color(int(p.get("defense", 0)))))
	row.add_child(_make_cell("%.2f" % float(p.get("precision", 0.0)), 88.0, _mercato_stat_color(int(p.get("precision", 0)))))
	row.add_child(_make_cell(str(_player_motivation_value(p)), 82.0, _mercato_stat_color(_player_motivation_value(p))))
	row.add_child(_make_cell(_player_salary_text(p), 92.0))
	row.add_child(_make_buy_button_cell(p))

	return wrap

func _make_cell(txt: String, min_w: float, font_color: Color = Color(0.94, 0.96, 1.0, 1.0)) -> Control:
	var box := CenterContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(min_w, 0)

	var lbl := Label.new()
	lbl.text = txt
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(lbl)
	return box

func _make_buy_button_cell(p: Dictionary) -> Control:
	var holder := MarginContainer.new()
	holder.custom_minimum_size = Vector2(170, 40)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 40)
	holder.add_child(btn)

	var pid := _player_id_text(p)
	var bought := _is_player_bought(pid)
	_apply_buy_button_style(btn, bought)

	btn.pressed.connect(func():
		var now_bought := _toggle_player_bought(pid)
		if now_bought:
			_mercato_has_pending_buy_click = true
		elif _get_purchased_ids().is_empty():
			_mercato_has_pending_buy_click = false
		_apply_buy_button_style(btn, now_bought)
		_update_new_salaries_ui()
	)

	return holder

func _apply_buy_button_style(btn: Button, bought: bool) -> void:
	btn.text = (_tr_any(["mercato.bought"], "Acheté") if bought else _tr_any(["mercato.buy"], "Acheter"))
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.border_width_bottom = 4
	sb.content_margin_left = 14
	sb.content_margin_top = 9
	sb.content_margin_right = 14
	sb.content_margin_bottom = 9
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)

	if bought:
		sb.bg_color = Color(0.92, 0.52, 0.12, 1.0)
		sb.border_color = Color(0.64, 0.32, 0.06, 1.0)
	else:
		sb.bg_color = Color(0.16, 0.66, 0.30, 1.0)
		sb.border_color = Color(0.10, 0.42, 0.18, 1.0)

	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.60, 0.18, 1.0) if bought else Color(0.20, 0.74, 0.36, 1.0)
	hover.shadow_size = 12

	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.76, 0.40, 0.08, 1.0) if bought else Color(0.10, 0.54, 0.24, 1.0)
	pressed.border_width_bottom = 2
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 1)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.disabled = false

func _player_id_text(p: Dictionary) -> String:
	if p.has("id"):
		return str(p["id"])
	if p.has("player_id"):
		return str(p["player_id"])
	if p.has("uid"):
		return str(p["uid"])
	return _player_name(p) + "_" + str(int(p.get("age", 0))) + "_" + _player_poste(p)

func _is_player_bought(pid: String) -> bool:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return false

	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()

	if PL.has_method("ensure_mercato_schema"):
		PL.ensure_mercato_schema(save)

	if save.has("mercato") and save["mercato"] is Dictionary:
		var m: Dictionary = save["mercato"]
		if m.has("purchased_ids") and m["purchased_ids"] is Array:
			return pid in (m["purchased_ids"] as Array)

	return false

func _toggle_player_bought(pid: String) -> bool:
	print("[MERCATO][BUY_CLICK] pid=", pid)
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return false

	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()

	if PL.has_method("ensure_mercato_schema"):
		PL.ensure_mercato_schema(save)

	if not save.has("mercato") or not (save["mercato"] is Dictionary):
		save["mercato"] = {}

	var m: Dictionary = save["mercato"]
	var purchased: Array = []
	var is_now_bought := false

	if m.has("purchased_ids") and m["purchased_ids"] is Array:
		purchased = (m["purchased_ids"] as Array).duplicate()

	if pid in purchased:
		purchased.erase(pid)
		is_now_bought = false
	else:
		if purchased.size() >= 4:
			return false

		var selected_ids: Array = []
		if save.has("roster") and save["roster"] is Dictionary:
			var roster_cap: Dictionary = save["roster"]
			if roster_cap.has("selected_ids") and roster_cap["selected_ids"] is Array:
				selected_ids = (roster_cap["selected_ids"] as Array).duplicate()

		var effective_ids := {}
		if save.has("roster") and save["roster"] is Dictionary:
			var roster_players_cap: Variant = (save["roster"] as Dictionary).get("players", [])
			if roster_players_cap is Array:
				for raw_player in roster_players_cap:
					if raw_player is Dictionary:
						var player_id_txt := str((raw_player as Dictionary).get("id", "")).strip_edges()
						if player_id_txt != "":
							effective_ids[str(int(float(player_id_txt)))] = true
		for raw_sid in selected_ids:
			var sid_txt := str(raw_sid).strip_edges()
			if sid_txt == "":
				continue
			var key_sid := str(int(float(sid_txt)))
			effective_ids[key_sid] = true

		for raw_pid in purchased:
			var pid_txt := str(raw_pid).strip_edges()
			if pid_txt == "":
				continue
			var key_pid := str(int(float(pid_txt)))
			effective_ids[key_pid] = true

		var new_pid_txt := str(pid).strip_edges()
		if new_pid_txt != "":
			var new_key := str(int(float(new_pid_txt)))
			if not effective_ids.has(new_key) and effective_ids.size() >= 12:
				if lbl_team_full_warning != null:
					lbl_team_full_warning.text = _tr_any(["mercato.team_full_warning"], "Squad full: 12 players maximum") + "\n" + _tr_any(["mercato.team_full_sell_before"], "You must sell players first")
					lbl_team_full_warning.add_theme_font_size_override("font_size", 28)
					lbl_team_full_warning.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12, 1.0))
					lbl_team_full_warning.visible = true
				return false

		purchased.append(pid)
		is_now_bought = true

	print("[MERCATO][BUY_AFTER] purchased_ids=", purchased, " is_now_bought=", is_now_bought)
	m["purchased_ids"] = purchased
	save["mercato"] = m
	_sync_mercato_owned_players_into_roster(save)

	if PL.has_method("write_savegame"):
		PL.write_savegame(save)

	return is_now_bought

func _player_name(p: Dictionary) -> String:
	if p.has("nom"):
		var nom_txt := str(p["nom"]).strip_edges()
		if not nom_txt.begins_with("Prospect "):
			return nom_txt
	if p.has("name"):
		var name_txt := str(p["name"]).strip_edges()
		if not name_txt.begins_with("Prospect "):
			return name_txt
	if p.has("prenom") and p.has("nom_famille"):
		return str(p["prenom"]) + " " + str(p["nom_famille"])
	return _mercato_fallback_player_name(p)

func _mercato_fallback_player_name(p: Dictionary) -> String:
	var names := ["Liam", "Noah", "Lucas", "Ethan", "Alex", "Mason", "Nathan", "Ryan", "Nolan", "Isaac", "Eli", "Aaron", "Adrian", "Blake", "Tyler", "Julian"]
	var pid := int(str(p.get("id", p.get("player_id", 0))).to_int())
	if pid <= 0:
		return names[0]
	return names[pid % names.size()]

func _player_poste(p: Dictionary) -> String:
	if p.has("poste"):
		return str(p["poste"])
	if p.has("position"):
		return str(p["position"])
	if p.has("pos"):
		return str(p["pos"])
	return "-"

func _tr_poste(poste: String) -> String:
	match String(poste).strip_edges().to_lower():
		"meneur":
			return tr("player.position.point_guard")
		"arrière", "arriere":
			return tr("player.position.shooting_guard")
		"ailier":
			return tr("player.position.small_forward")
		"ailier fort", "power forward":
			return tr("player.position.point_forward")
		"pivot":
			return tr("player.position.center")
		_:
			return poste


func _player_fitness_value(p: Dictionary) -> int:
	var fatigue := int(p.get("fatigue", 0))
	return clampi(100 - fatigue, 0, 100)

func _player_motivation_value(p: Dictionary) -> int:
	return int(p.get("motivation", 0))

func _mercato_stat_color(v: int) -> Color:
	if v < 60:
		return Color(0.9, 0.3, 0.3)
	if v < 75:
		return Color(0.95, 0.75, 0.2)
	return Color(0.3, 0.9, 0.4)


func _mercato_star_count(p: Dictionary) -> int:
	var perf := float(p.get("pondération", p.get("ponderation", p.get("overall", p.get("rating", 0)))))
	if perf <= 0.0:
		var tir := int(p.get("tir", 0))
		var vitesse := int(p.get("vitesse", 0))
		var defense := int(p.get("defense", 0))
		var motivation := int(p.get("motivation", 0))
		perf = float(tir + vitesse + defense + motivation) / 4.0
	if perf >= 85.0:
		return 5
	if perf >= 75.0:
		return 4
	if perf >= 65.0:
		return 3
	if perf >= 55.0:
		return 2
	return 1


func _mercato_stars_text(p: Dictionary) -> String:
	var stars := _mercato_star_count(p)
	return str(stars) + "/5"


func _make_avatar_name_cell(p: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(88, 84)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(58, 58)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar.pivot_offset = avatar.custom_minimum_size * 0.5
	var avatar_path := str(p.get("avatar_path", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar.texture = load(avatar_path) as Texture2D
	avatar.mouse_entered.connect(func() -> void:
		avatar.scale = Vector2(1.50, 1.50)
	)
	avatar.mouse_exited.connect(func() -> void:
		avatar.scale = Vector2.ONE
	)
	avatar.gui_input.connect(func(event: InputEvent, player_data := p.duplicate(true)) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_bm_show_player_card_popup(player_data)
				accept_event()
	)

	var name := Label.new()
	name.text = _player_name(p)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))

	box.add_child(avatar)
	box.add_child(name)
	return box


func _bm_player_card_close() -> void:
	var existing := get_node_or_null("PlayerCardPopup")
	if existing != null and is_instance_valid(existing):
		existing.queue_free()


func _bm_player_card_percent(value: Variant) -> float:
	var f := float(value)
	if f <= 1.5:
		f *= 100.0
	return clampf(f, 0.0, 100.0)


func _bm_player_card_add_label(parent: Control, text_value: String, pos: Vector2, sz: Vector2, fs: int, color: Color, center: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	parent.add_child(lbl)
	return lbl


func _bm_player_card_add_stat(parent: VBoxContainer, label_text: String, value: Variant, keep_decimals: bool = false) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 26)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	row.add_child(lbl)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(180, 10)
	track.color = Color(1, 1, 1, 0.18)
	row.add_child(track)

	var bar := ColorRect.new()
	bar.color = Color(0.95, 0.50, 0.12, 1.0)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(180.0 * (_bm_player_card_percent(value) / 100.0), 10)
	track.add_child(bar)

	var val := Label.new()
	val.text = ("%.2f" % float(value)) if keep_decimals else str(int(round(float(value))))
	val.custom_minimum_size = Vector2(52, 26)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 17)
	val.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	row.add_child(val)



class PlayerProfileQuadrantGraph extends Control:
	var scores: Dictionary = {}

	func set_scores(v: Dictionary) -> void:
		scores = v
		queue_redraw()

	func _draw() -> void:
		_bm_draw_duel_graph(Vector2(50.0, 76.0), 50.8, "attaque", "defense", tr("player.card.graph.attack"), tr("player.card.graph.defense"), Color(0.88, 0.32, 0.12, 0.94), Color(0.24, 0.47, 0.68, 0.94))
		_bm_draw_duel_graph(Vector2(176.0, 76.0), 50.8, "physique", "mental", tr("player.card.graph.physical"), tr("player.card.graph.mental"), Color(0.88, 0.62, 0.18, 0.94), Color(0.48, 0.30, 0.62, 0.94))

	func _bm_draw_duel_graph(center: Vector2, radius: float, key_a: String, key_b: String, label_a: String, label_b: String, color_a: Color, color_b: Color) -> void:
		var value_a := clampf(float(scores.get(key_a, 0.0)), 0.0, 100.0)
		var value_b := clampf(float(scores.get(key_b, 0.0)), 0.0, 100.0)
		var total: float = max(1.0, value_a + value_b)
		var split_angle: float = -PI * 0.5 + TAU * (value_a / total)
		var font := get_theme_default_font()

		_bm_draw_sector(center, radius, -PI * 0.5, split_angle, color_a)
		_bm_draw_sector(center, radius, split_angle, -PI * 0.5 + TAU, color_b)
		draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.38), 2.0)
		draw_circle(center, radius * 0.16, Color(0.04, 0.07, 0.12, 0.88))

		var mid_a: float = (-PI * 0.5 + split_angle) * 0.5
		var mid_b: float = (split_angle + (-PI * 0.5 + TAU)) * 0.5
		var pos_a := center + Vector2(cos(mid_a), sin(mid_a)) * (radius * 0.52)
		var pos_b := center + Vector2(cos(mid_b), sin(mid_b)) * (radius * 0.52)
		draw_string(font, pos_a - Vector2(13, -6), str(int(round(value_a))), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 1))
		draw_string(font, pos_b - Vector2(13, -6), str(int(round(value_b))), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 1))
		draw_string(font, center + Vector2(-34, -60), label_a, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.94))
		draw_string(font, center + Vector2(-22, 66), label_b, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.94))
		draw_line(center + Vector2(-11, -39), center + Vector2(-20, -53), Color(1, 1, 1, 0.62), 1.0)
		draw_line(center + Vector2(14, 39), center + Vector2(32, 58), Color(1, 1, 1, 0.62), 1.0)

	func _bm_draw_sector(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
		var pts: PackedVector2Array = [center]
		for step in range(25):
			var a: float = start_angle + ((end_angle - start_angle) * float(step) / 24.0)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_polygon(pts, PackedColorArray([color]))


func _bm_player_profile_scores(data: Dictionary) -> Dictionary:
	var precision := float(data.get("precision", 0.0))
	if precision <= 1.5:
		precision *= 100.0
	var pct_2pts := float(data.get("pct_2pts", precision))
	if pct_2pts <= 1.5:
		pct_2pts *= 100.0
	var pct_3pts := float(data.get("pct_3pts", precision))
	if pct_3pts <= 1.5:
		pct_3pts *= 100.0
	var attaque := (float(data.get("tir", 0)) + precision + pct_2pts + pct_3pts) / 4.0
	var defense_score := float(data.get("defense", 0))
	var mental := float(data.get("motivation", 0))
	var fatigue_score := 100.0 - float(data.get("fatigue", 0))
	var physique := (float(data.get("vitesse", 0)) + float(data.get("endurance", 0)) + fatigue_score) / 3.0
	return {
		"attaque": clampf(attaque, 0.0, 100.0),
		"defense": clampf(defense_score, 0.0, 100.0),
		"mental": clampf(mental, 0.0, 100.0),
		"physique": clampf(physique, 0.0, 100.0),
	}



func _bm_show_player_graph_tooltip(card: Control, anchor: Control, text_value: String) -> void:
	var tooltip := card.get_node_or_null("PlayerProfileGraphCustomTooltip") as Panel
	if tooltip == null:
		tooltip = Panel.new()
		tooltip.name = "PlayerProfileGraphCustomTooltip"
		tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip.z_index = 80
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.03, 0.06, 0.96)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(1.0, 0.58, 0.14, 0.65)
		tooltip.add_theme_stylebox_override("panel", sb)
		card.add_child(tooltip)

		var lbl := Label.new()
		lbl.name = "LblGraphTooltip"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = Vector2(12, 10)
		lbl.size = Vector2(414, 102)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		tooltip.add_child(lbl)

	var tooltip_h := 118.0
	var label := tooltip.get_node_or_null("LblGraphTooltip") as Label
	if label != null:
		var display_text := text_value
		var line_count: int = max(1, display_text.split("\n").size())
		tooltip_h = max(118.0, float(line_count) * 24.0 + 38.0)
		label.text = display_text
		label.size = Vector2(414, tooltip_h - 12.0)

	tooltip.size = Vector2(442, tooltip_h)
	var desired := Vector2(anchor.position.x, -tooltip.size.y - 8.0)
	var max_x: float = max(0.0, card.size.x - tooltip.size.x - 12.0)
	tooltip.position = Vector2(clampf(desired.x, 12.0, max_x), desired.y)
	tooltip.visible = true
	card.move_child(tooltip, card.get_child_count() - 1)


func _bm_hide_player_graph_tooltip(card: Control) -> void:
	var tooltip := card.get_node_or_null("PlayerProfileGraphCustomTooltip") as Control
	if tooltip != null:
		tooltip.visible = false

func _bm_add_player_profile_graph(card: Control, data: Dictionary) -> void:
	var graph := PlayerProfileQuadrantGraph.new()
	graph.name = "PlayerProfileGraph"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.size = Vector2(249, 249)
	graph.position = Vector2(488, 24)
	graph.set_scores(_bm_player_profile_scores(data))
	card.add_child(graph)

	var graph_tip_left := Control.new()
	graph_tip_left.name = "PlayerProfileGraphAttackDefenseTooltipArea"
	graph_tip_left.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_tip_left.size = Vector2(118, graph.size.y)
	graph_tip_left.position = graph.position
	graph_tip_left.tooltip_text = ""
	graph_tip_left.mouse_entered.connect(func() -> void:
		_bm_show_player_graph_tooltip(card, graph_tip_left, tr("player.card.graph.tooltip.attack_defense"))
	)
	graph_tip_left.mouse_exited.connect(func() -> void:
		_bm_hide_player_graph_tooltip(card)
	)
	card.add_child(graph_tip_left)

	var graph_tip_right := Control.new()
	graph_tip_right.name = "PlayerProfileGraphPhysicalMentalTooltipArea"
	graph_tip_right.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_tip_right.size = Vector2(131, graph.size.y)
	graph_tip_right.position = graph.position + Vector2(118, 0)
	graph_tip_right.tooltip_text = ""
	graph_tip_right.mouse_entered.connect(func() -> void:
		_bm_show_player_graph_tooltip(card, graph_tip_right, tr("player.card.graph.tooltip.physical_mental"))
	)
	graph_tip_right.mouse_exited.connect(func() -> void:
		_bm_hide_player_graph_tooltip(card)
	)
	card.add_child(graph_tip_right)

func _bm_show_player_card_popup(data: Dictionary) -> void:
	if get_node_or_null("PlayerCardPopup") != null:
		return

	var popup := Control.new()
	popup.name = "PlayerCardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 320
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.62)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card_w := 792.0
	var card_h := 430.0
	var card := Panel.new()
	card.name = "PlayerCard"
	card.size = Vector2(card_w, card_h)
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.position = Vector2((get_viewport_rect().size.x - card_w) * 0.5, (get_viewport_rect().size.y - card_h) * 0.5)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.035, 0.075, 0.98)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.58, 0.14, 0.72)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	card.add_theme_stylebox_override("panel", sb)
	popup.add_child(card)

	var avatar_path := str(data.get("avatar_path", ""))
	var avatar_big := TextureRect.new()
	avatar_big.position = Vector2(34, 82)
	avatar_big.size = Vector2(190, 190)
	avatar_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar_big.texture = load(avatar_path) as Texture2D
	card.add_child(avatar_big)
	_bm_add_player_profile_graph(card, data)

	_bm_player_card_add_label(card, _player_name(data), Vector2(24, 278), Vector2(210, 44), 34, Color(1, 1, 1, 1), true)

	var badge := Panel.new()
	badge.position = Vector2(34, 326)
	badge.size = Vector2(210, 34)
	var sb_badge := StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.95, 0.48, 0.10, 1.0)
	sb_badge.corner_radius_top_left = 17
	sb_badge.corner_radius_top_right = 17
	sb_badge.corner_radius_bottom_left = 17
	sb_badge.corner_radius_bottom_right = 17
	badge.add_theme_stylebox_override("panel", sb_badge)
	card.add_child(badge)
	_bm_player_card_add_label(badge, _tr_poste(_player_poste(data)), Vector2(12, 2), Vector2(186, 30), 18, Color(1, 1, 1, 1), true)

	_bm_player_card_add_label(card, _tr_any(["player.card.age"], "Age") + " : " + str(int(data.get("age", 0))), Vector2(254, 130), Vector2(210, 28), 20, Color(0.92, 0.95, 1.0, 1.0))
	_bm_player_card_add_label(card, _tr_any(["player.card.salary"], "Salary") + " : " + _player_salary_text(data), Vector2(254, 160), Vector2(300, 28), 20, Color(0.92, 0.95, 1.0, 1.0))
	var rating := _player_perf(data)
	if rating > 0:
		_bm_player_card_add_label(card, _tr_any(["player.card.rating"], "Rating") + " : " + str(rating), Vector2(254, 100), Vector2(260, 30), 22, Color(1.0, 0.78, 0.22, 1.0))

	var stats := VBoxContainer.new()
	stats.position = Vector2(254, 230)
	stats.size = Vector2(420, 170)
	stats.add_theme_constant_override("separation", 3)
	card.add_child(stats)
	if data.has("tir"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.shooting"], "Shooting"), data.get("tir"))
	if data.has("vitesse"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.speed"], "Speed"), data.get("vitesse"))
	if data.has("defense"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.defense"], "Defense"), data.get("defense"))
	if data.has("precision"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.accuracy"], "Accuracy"), data.get("precision"), true)
	if data.has("motivation"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.motivation"], "Motivation"), data.get("motivation"))
	if data.has("endurance"):
		_bm_player_card_add_stat(stats, _tr_any(["player.card.endurance"], "Endurance"), data.get("endurance"))

	if bool(data.get("blessure", false)):
		_bm_player_card_add_label(card, _tr_any(["player.card.injured"], "Injured"), Vector2(34, 292), Vector2(190, 30), 20, Color(1.0, 0.35, 0.35, 1.0), true)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.position = Vector2(card_w - 52.0, 14.0)
	btn_close.size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(_bm_player_card_close)
	card.add_child(btn_close)


func _player_perf(p: Dictionary) -> int:
	if p.has("performance"):
		return int(p["performance"])
	if p.has("overall"):
		return int(p["overall"])
	if p.has("rating"):
		return int(p["rating"])
	if p.has("ponderation"):
		return int(round(float(p["ponderation"])))
	if p.has("pondération"):
		return int(round(float(p["pondération"])))
	return 0


func _fmt_int_spaces(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out

func _player_salary_value(p: Dictionary) -> int:
	var salaire := 0
	if p.has("salaire"):
		salaire = int(p["salaire"])
	elif p.has("salary"):
		salaire = int(p["salary"])
	elif p.has("wage"):
		salaire = int(p["wage"])

	# Mercato doit toujours afficher le salaire annuel saison.
	# Si la valeur stockée ressemble à un petit montant par match, on reconstruit l'annuel.
	if salaire > 0 and salaire < 5000:
		var perf := float(p.get("pondération", p.get("ponderation", p.get("overall", 70))))
		salaire = int(70000 + perf * 500.0)
		salaire = clamp(salaire, 70000, 130000)

	return salaire

func _player_salary_text(p: Dictionary) -> String:
	return _fmt_int_spaces(_player_salary_value(p)) + " €"

func _sync_mercato_owned_players_into_roster(save: Dictionary) -> void:
	if not save.has("roster") or not (save["roster"] is Dictionary):
		save["roster"] = {}
	var roster: Dictionary = save["roster"]

	var selected_ids: Array = []
	if roster.has("selected_ids") and roster["selected_ids"] is Array:
		selected_ids = (roster["selected_ids"] as Array).duplicate()

	var purchased_ids: Array = []
	if save.has("mercato") and save["mercato"] is Dictionary:
		var m: Dictionary = save["mercato"]
		if m.has("purchased_ids") and m["purchased_ids"] is Array:
			purchased_ids = (m["purchased_ids"] as Array).duplicate()

	if purchased_ids.size() > 4:
		purchased_ids = purchased_ids.slice(0, 4)

	var by_id: Dictionary = {}
	if save.has("players_by_id") and save["players_by_id"] is Dictionary:
		by_id = save["players_by_id"]

	var roster_players: Array = []
	var total_salary := 0

	for pid_v in selected_ids:
		var pid_txt := str(pid_v).strip_edges()
		if pid_txt == "":
			continue
		var key := str(int(float(pid_txt)))
		if not by_id.has(key) or not (by_id[key] is Dictionary):
			continue
		var p: Dictionary = by_id[key]
		var overall := int(round(float(p.get("overall", p.get("rating", p.get("pondération", p.get("ponderation", 70)))))))
		var age := int(p.get("age", 25))
		var pos := str(p.get("pos", p.get("poste", "")))
		var name := str(p.get("name", p.get("nom", "Player"))).strip_edges()
		var salary := int(p.get("salaire", p.get("salary", 0)))
		roster_players.append({
			"id": key,
			"name": name,
			"pos": pos,
			"age": age,
			"overall": overall,
			"salary": salary
		})
		total_salary += salary

	for pid_v in purchased_ids:
		var pid_txt := str(pid_v).strip_edges()
		if pid_txt == "":
			continue
		var key := str(int(float(pid_txt)))
		if not by_id.has(key) or not (by_id[key] is Dictionary):
			continue
		var p: Dictionary = by_id[key]
		var overall := int(round(float(p.get("overall", p.get("rating", p.get("pondération", p.get("ponderation", 70)))))))
		var age := int(p.get("age", 25))
		var pos := str(p.get("pos", p.get("poste", "")))
		var name := str(p.get("name", p.get("nom", "Player"))).strip_edges()
		var salary := int(p.get("salaire", p.get("salary", 0)))
		roster_players.append({
			"id": key,
			"name": name,
			"pos": pos,
			"age": age,
			"overall": overall,
			"salary": salary
		})
		total_salary += salary

	roster["players"] = roster_players
	save["roster"] = roster
	save["salary_total_per_match"] = int(round(float(total_salary) / 22.0))
	var ms_buy: Dictionary = save.get("missions_state", {}) as Dictionary
	var c_buy: Dictionary = ms_buy.get("counters", {}) as Dictionary
	c_buy["mercato_achats"] = int(_get_purchased_ids().size())
	ms_buy["counters"] = c_buy
	save["missions_state"] = ms_buy

func _on_btn_confirmer_mercato_pressed() -> void:
	print("[MERCATO] confirmer achats -> go Management")
	_update_new_salaries_ui()
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _get_purchased_ids() -> Array:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return []
	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()
	if save.has("mercato") and save["mercato"] is Dictionary:
		var m: Dictionary = save["mercato"]
		if m.has("purchased_ids") and m["purchased_ids"] is Array:
			return (m["purchased_ids"] as Array).duplicate()
	return []


func _get_new_salaries_total() -> int:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return 0
	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()
	var purchased_ids: Array = _get_purchased_ids()
	if purchased_ids.is_empty():
		return 0
	if not save.has("players_by_id") or not (save["players_by_id"] is Dictionary):
		return 0
	var by_id: Dictionary = save["players_by_id"]
	var total := 0
	for pid_v in purchased_ids:
		var key := str(pid_v)
		if by_id.has(key) and by_id[key] is Dictionary:
			var p: Dictionary = by_id[key]
			total += int(p.get("salaire", p.get("salary", 0)))
	return total


func _get_current_licensed_count() -> int:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return 0
	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()
	if not save.has("roster") or not (save["roster"] is Dictionary):
		return 0
	var roster: Dictionary = save["roster"]

	if roster.has("players") and (roster["players"] is Array):
		return (roster["players"] as Array).size()

	if not roster.has("selected_ids") or not (roster["selected_ids"] is Array):
		return 0
	var selected_ids: Array = (roster["selected_ids"] as Array).duplicate()
	var effective_ids := {}
	for raw_sid in selected_ids:
		var sid_txt := str(raw_sid).strip_edges()
		if sid_txt == "":
			continue
		var key_sid := str(int(float(sid_txt)))
		effective_ids[key_sid] = true
	return effective_ids.size()

func _update_new_salaries_ui() -> void:
	var total := _get_new_salaries_total()
	if lbl_new_salaries_total != null:
		lbl_new_salaries_total.text = _tr_any(["mercato.new_salaries_total"], "New salaries") + " : " + _fmt_int_spaces(total) + " €"
	if btn_confirmer_mercato != null:
		var purchased_count: int = _get_purchased_ids().size()
		var licensed_count: int = _get_current_licensed_count()
		var is_visible: bool = _mercato_has_pending_buy_click and purchased_count > 0 and licensed_count <= 12
		btn_confirmer_mercato.visible = is_visible
		btn_confirmer_mercato.disabled = false
		if is_visible:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.16, 0.66, 0.30, 1.0)
			sb.border_color = Color(0.10, 0.42, 0.18, 1.0)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.corner_radius_top_left = 12
			sb.corner_radius_top_right = 12
			sb.corner_radius_bottom_left = 12
			sb.corner_radius_bottom_right = 12
			btn_confirmer_mercato.add_theme_stylebox_override("normal", sb)
			btn_confirmer_mercato.add_theme_stylebox_override("hover", sb)
			btn_confirmer_mercato.add_theme_stylebox_override("pressed", sb)
			btn_confirmer_mercato.add_theme_stylebox_override("focus", sb)
			btn_confirmer_mercato.add_theme_color_override("font_color", Color(1, 1, 1, 1))
