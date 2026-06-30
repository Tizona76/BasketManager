extends Control

signal toggled(player_id: int)
signal photo_pressed(player_data: Dictionary)

var player_id: int = -1
var selected: bool = false
var player_data: Dictionary = {}

func _stat_color(v: int) -> Color:
	if v < 50:
		return Color(0.9, 0.3, 0.3) # rouge
	elif v < 70:
		return Color(0.95, 0.75, 0.2) # jaune
	else:
		return Color(0.3, 0.9, 0.4) # vert

@onready var btn: Button = get_node_or_null("BtnSelect") as Button
@onready var avatar: TextureRect = get_node_or_null("AvatarBox/Avatar") as TextureRect

func _ready() -> void:
	if btn == null:
		btn = find_child("BtnSelect", true, false) as Button
	if avatar == null:
		avatar = find_child("Avatar", true, false) as TextureRect

	_ensure_btn_connected()
	_update_text()
	_update_style()

func _stars_for_player(data: Dictionary) -> String:
	var stars := 0
	if data.has("stars"):
		stars = int(data.get("stars", 0))
	else:
		var tir := int(data.get("tir", 0))
		var vitesse := int(data.get("vitesse", 0))
		var defense := int(data.get("defense", 0))
		var motivation := int(data.get("motivation", 0))
		var avg := int(round(float(tir + vitesse + defense + motivation) / 4.0))
		stars = int(round(float(avg) / 20.0))
	stars = clampi(stars, 1, 5)
	return str(stars) + "/5"


func setup(data: Dictionary) -> void:
	player_id = int(data.get("id", -1))
	player_data = data.duplicate(true)

	var font_sz := 22
	# Modern selection screen: readable on dark/court backgrounds
	var font_color := Color(0.94, 0.96, 1.0, 1.0)

	var ln := get_node_or_null("AvatarBox/LabelName") as Label
	if ln == null:
		ln = find_child("LabelName", true, false) as Label
	if ln != null:
		ln.text = str(data.get("nom", data.get("name", "")))
		ln.add_theme_font_size_override("font_size", 20)
		ln.add_theme_color_override("font_color", font_color)
		ln.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))

	var lstars := get_node_or_null("LabelStars") as Label
	if lstars == null:
		lstars = find_child("LabelStars", true, false) as Label
	if lstars != null:
		lstars.text = _stars_for_player(data)
		lstars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lstars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lstars.add_theme_font_size_override("font_size", 20)
		lstars.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22, 1.0))
		lstars.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))

	var lpos := get_node_or_null("LabelPos") as Label
	if lpos == null:
		lpos = find_child("LabelPos", true, false) as Label
	if lpos != null:
		var poste_raw := str(data.get("poste", data.get("pos", "")))
		var poste_txt := poste_raw
		match poste_raw:
			"Meneur", "Point Guard":
				poste_txt = "P.G."
			"Ailier", "Small Forward":
				poste_txt = "S.F."
			"Pivot", "Center":
				poste_txt = "C"
			"Arrière", "Shooting Guard":
				poste_txt = "S.G."
		lpos.text = poste_txt
		lpos.add_theme_font_size_override("font_size", 21)
		lpos.add_theme_color_override("font_color", font_color)

	var la := get_node_or_null("LabelAge") as Label
	if la == null:
		la = find_child("LabelAge", true, false) as Label
	if la != null:
		la.text = str(int(data.get("age", 0)))
		la.add_theme_font_size_override("font_size", font_sz + 1)
		la.add_theme_color_override("font_color", font_color)

	var lg := get_node_or_null("LabelGender") as Label
	if lg == null:
		lg = find_child("LabelGender", true, false) as Label
	if lg != null:
		lg.text = str(int(data.get("tir", 0)))
		lg.add_theme_font_size_override("font_size", font_sz + 1)
		lg.add_theme_color_override("font_color", font_color)

	var lspeed := get_node_or_null("LabelSpeed") as Label
	if lspeed == null:
		lspeed = find_child("LabelSpeed", true, false) as Label
	if lspeed != null:
		lspeed.text = str(int(data.get("vitesse", 0)))
		lspeed.add_theme_font_size_override("font_size", font_sz + 1)
		lspeed.add_theme_color_override("font_color", _stat_color(int(data.get("vitesse",0))))

	var ldef := get_node_or_null("LabelDefense") as Label
	if ldef == null:
		ldef = find_child("LabelDefense", true, false) as Label
	if ldef != null:
		ldef.text = str(int(data.get("defense", 0)))
		ldef.add_theme_font_size_override("font_size", font_sz + 1)
		ldef.add_theme_color_override("font_color", _stat_color(int(data.get("defense",0))))

	var lprec := get_node_or_null("LabelPrecision") as Label
	if lprec == null:
		lprec = find_child("LabelPrecision", true, false) as Label
	if lprec != null:
		var precision_val: float = float(data.get("precision", 0.0))
		lprec.text = "%.2f" % precision_val
		lprec.add_theme_font_size_override("font_size", font_sz + 1)
		lprec.add_theme_color_override("font_color", _stat_color(int(data.get("precision",0))))

	var lmot := get_node_or_null("LabelMotivation") as Label
	if lmot == null:
		lmot = find_child("LabelMotivation", true, false) as Label
	if lmot != null:
		lmot.text = str(int(data.get("motivation", 0)))
		lmot.add_theme_font_size_override("font_size", font_sz + 1)
		lmot.add_theme_color_override("font_color", _stat_color(int(data.get("motivation",0))))

	var lsal := get_node_or_null("LabelSalary") as Label
	if lsal == null:
		lsal = find_child("LabelSalary", true, false) as Label
	if lsal != null:
		lsal.text = _fmt_salary(int(data.get("salaire", 0)))
		lsal.add_theme_font_size_override("font_size", font_sz + 1)
		lsal.add_theme_color_override("font_color", font_color)

	_bm_apply_selection_mobile_table_content_plus2(data)

	if avatar == null:
		avatar = get_node_or_null("AvatarBox/Avatar") as TextureRect
		if avatar == null:
			avatar = find_child("Avatar", true, false) as TextureRect

	if avatar != null:
		var p: String = str(data.get("avatar_path", ""))
		if p != "" and ResourceLoader.exists(p):
			avatar.texture = load(p) as Texture2D
		else:
			avatar.texture = null
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		avatar.pivot_offset = avatar.custom_minimum_size * 0.5
		if not avatar.gui_input.is_connected(_on_avatar_gui_input):
			avatar.gui_input.connect(_on_avatar_gui_input)
		if not avatar.mouse_entered.is_connected(_on_avatar_mouse_entered):
			avatar.mouse_entered.connect(_on_avatar_mouse_entered)
		if not avatar.mouse_exited.is_connected(_on_avatar_mouse_exited):
			avatar.mouse_exited.connect(_on_avatar_mouse_exited)

	_ensure_btn_connected()
	_update_text()
	_update_style()
	_bm_apply_selection_mobile_select_button_text_plus1(data)
	_bm_apply_selection_mobile_table_content_extra_plus2(data)

func _fmt_salary(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s.substr(i, 1) + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out + " €"

func _ensure_btn_connected() -> void:
	if btn == null:
		return
	var cb := Callable(self, "_on_btn")
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_text()
		_update_style()

func _update_text() -> void:
	if btn == null:
		return
	if selected:
		btn.set_meta("i18n_key", "BTN_REMOVE")
	else:
		btn.set_meta("i18n_key", "BTN_ADD")
	I18nSvc.apply_node(btn)

func _apply_row_panel_style() -> void:
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.92, 0.52, 0.12, 0.30) if selected else Color(0.03, 0.06, 0.12, 0.26)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(1.0, 0.62, 0.20, 0.42) if selected else Color(1, 1, 1, 0.10)
	row_style.corner_radius_top_left = 12
	row_style.corner_radius_top_right = 12
	row_style.corner_radius_bottom_left = 12
	row_style.corner_radius_bottom_right = 12
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", row_style)
	queue_redraw()


func set_selected_visual(is_selected: bool) -> void:
	selected = is_selected
	_update_text()
	_update_style()


func _update_style() -> void:
	_apply_row_panel_style()
	if btn == null:
		return

	var sb_normal := StyleBoxFlat.new()
	sb_normal.corner_radius_top_left = 12
	sb_normal.corner_radius_top_right = 12
	sb_normal.corner_radius_bottom_left = 12
	sb_normal.corner_radius_bottom_right = 12
	sb_normal.content_margin_left = 12
	sb_normal.content_margin_right = 12
	sb_normal.content_margin_top = 8
	sb_normal.content_margin_bottom = 8

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat

	if selected:
		btn.modulate = Color(1, 1, 1, 1)
		sb_normal.bg_color = Color(0.95, 0.48, 0.12, 1.0)
		sb_hover.bg_color = Color(1.00, 0.58, 0.18, 1.0)
		sb_pressed.bg_color = Color(0.82, 0.36, 0.08, 1.0)
	else:
		btn.modulate = Color(1, 1, 1, 1)
		sb_normal.bg_color = Color(0.10, 0.28, 0.62, 0.95)
		sb_hover.bg_color = Color(0.16, 0.38, 0.82, 1.0)
		sb_pressed.bg_color = Color(0.07, 0.20, 0.48, 1.0)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_font_size_override("font_size", 18)

func _on_btn() -> void:
	selected = !selected
	_update_text()
	_update_style()
	emit_signal("toggled", player_id)


func _on_avatar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("photo_pressed", player_data.duplicate(true))
			accept_event()


func _on_avatar_mouse_entered() -> void:
	if avatar != null:
		avatar.scale = Vector2(1.50, 1.50)


func _on_avatar_mouse_exited() -> void:
	if avatar != null:
		avatar.scale = Vector2.ONE


func _show_rating_tooltip() -> void:
	_hide_rating_tooltip()

	var panel := PanelContainer.new()
	panel.name = "RatingTooltip"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 999
	panel.set_as_top_level(true)

	var lbl := Label.new()
	lbl.text = "Rating based on shooting, speed, defense and motivation."
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.94)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	panel.add_child(lbl)
	add_child(panel)
	panel.global_position = get_global_mouse_position() + Vector2(14, 18)


func _hide_rating_tooltip() -> void:
	var old := get_node_or_null("RatingTooltip")
	if old != null:
		old.queue_free()


func _draw() -> void:
	var bg := Color(0.03, 0.06, 0.12, 0.26)
	if selected:
		bg = Color(0.92, 0.52, 0.12, 0.32)
	draw_rect(Rect2(Vector2.ZERO, size), bg, true)


func _bm_apply_selection_mobile_table_content_plus2(data: Dictionary) -> void:
	if not bool(data.get("bm_selection_mobile_rating_ratio", false)):
		return

	for node_name in [
		"LabelStars",
		"LabelPos",
		"LabelAge",
		"LabelGender",
		"LabelSpeed",
		"LabelDefense",
		"LabelPrecision",
		"LabelMotivation",
		"LabelSalary",
	]:
		var lbl := get_node_or_null(node_name) as Label
		if lbl == null:
			lbl = find_child(node_name, true, false) as Label
		if lbl == null:
			continue
		if lbl.has_meta("bm_selection_mobile_content_plus2_done"):
			continue

		lbl.set_meta("bm_selection_mobile_content_plus2_done", true)
		var fs: int = int(lbl.get_theme_font_size("font_size"))
		if fs > 0:
			lbl.add_theme_font_size_override("font_size", fs + 4)


func _bm_apply_selection_mobile_select_button_text_plus1(data: Dictionary) -> void:
	if not bool(data.get("bm_selection_mobile_rating_ratio", false)):
		return
	if btn == null:
		return
	if btn.has_meta("bm_selection_mobile_select_text_plus1_done"):
		return

	btn.set_meta("bm_selection_mobile_select_text_plus1_done", true)
	var fs: int = int(btn.get_theme_font_size("font_size"))
	if fs > 0:
		btn.add_theme_font_size_override("font_size", fs + 1)


func _bm_apply_selection_mobile_table_content_extra_plus2(data: Dictionary) -> void:
	if not bool(data.get("bm_selection_mobile_rating_ratio", false)):
		return

	for node_name in [
		"LabelStars",
		"LabelPos",
		"LabelAge",
		"LabelGender",
		"LabelSpeed",
		"LabelDefense",
		"LabelPrecision",
		"LabelMotivation",
		"LabelSalary",
	]:
		var lbl := get_node_or_null(node_name) as Label
		if lbl == null:
			lbl = find_child(node_name, true, false) as Label
		if lbl == null:
			continue
		if lbl.has_meta("bm_selection_mobile_content_extra_plus2_done"):
			continue

		lbl.set_meta("bm_selection_mobile_content_extra_plus2_done", true)
		var fs: int = int(lbl.get_theme_font_size("font_size"))
		if fs > 0:
			lbl.add_theme_font_size_override("font_size", fs + 2)
