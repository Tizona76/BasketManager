extends Control

signal toggled(player_id: int)

var player_id: int = -1
var selected: bool = false

@onready var btn: Button = get_node_or_null("CardBody/BtnSelect") as Button
@onready var avatar: TextureRect = get_node_or_null("CardBody/Avatar") as TextureRect

func _ready() -> void:
	if btn == null:
		btn = find_child("BtnSelect", true, false) as Button
	if avatar == null:
		avatar = find_child("Avatar", true, false) as TextureRect
	_ensure_btn_connected()
	_update_text()
	_update_style()

func setup(data: Dictionary) -> void:
	player_id = int(data.get("id", -1))

	_apply_card_panel_style(selected)

	var ln := get_node_or_null("CardBody/LabelName") as Label
	if ln == null:
		ln = find_child("LabelName", true, false) as Label
	if ln != null:
		ln.text = str(data.get("nom", data.get("name", "")))
		ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ln.add_theme_font_size_override("font_size", 20)
		ln.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var la := get_node_or_null("CardBody/LabelAge") as Label
	if la == null:
		la = find_child("LabelAge", true, false) as Label
	if la != null:
		la.text = "%s %d" % [tr("myteam.header.age"), int(data.get("age", 0))]
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		la.add_theme_font_size_override("font_size", 18)
		la.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var lp := get_node_or_null("CardBody/LabelPerf") as Label
	if lp == null:
		lp = find_child("LabelPerf", true, false) as Label
	if lp != null:
		var perf_val: float = 0.0
		if data.has("pondération"):
			perf_val = float(data.get("pondération", 0.0))
		elif data.has("ponderation"):
			perf_val = float(data.get("ponderation", 0.0))
		else:
			perf_val = float(data.get("rating", 0.0))
		lp.text = "Perf %.1f" % perf_val
		lp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lp.add_theme_font_size_override("font_size", 18)
		lp.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	var ls := get_node_or_null("CardBody/LabelSalary") as Label
	if ls == null:
		ls = find_child("LabelSalary", true, false) as Label
	if ls != null:
		ls.text = _fmt_salary(int(data.get("salaire", 0)))
		ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ls.add_theme_font_size_override("font_size", 18)
		ls.add_theme_color_override("font_color", Color(0, 0, 0, 1))

	if avatar == null:
		avatar = get_node_or_null("CardBody/Avatar") as TextureRect
		if avatar == null:
			avatar = find_child("Avatar", true, false) as TextureRect

	if avatar != null:
		var p: String = str(data.get("avatar_path", ""))
		if p != "" and ResourceLoader.exists(p):
			avatar.texture = load(p) as Texture2D
		else:
			avatar.texture = null

	_ensure_btn_connected()
	_update_text()
	_update_style()

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

func _apply_card_panel_style(is_selected: bool) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.98, 1.0, 0.98)
	panel_style.border_width_left = 4 if is_selected else 1
	panel_style.border_width_top = 4 if is_selected else 1
	panel_style.border_width_right = 4 if is_selected else 1
	panel_style.border_width_bottom = 4 if is_selected else 1
	panel_style.border_color = Color(0.12, 0.78, 0.28, 1.0) if is_selected else Color(0.75, 0.80, 0.90, 1.0)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0, 0, 0, 0.18)
	panel_style.shadow_size = 5
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", panel_style)

func set_selected_visual(is_selected: bool) -> void:
	selected = is_selected
	_update_text()
	_update_style()

func _update_style() -> void:
	_apply_card_panel_style(selected)
	if btn == null:
		return
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	if selected:
		btn.modulate = Color(0.25, 0.75, 0.35, 1.0)
	else:
		btn.modulate = Color(0.20, 0.45, 0.95, 1.0)

func _on_btn() -> void:
	selected = !selected
	_update_text()
	_update_style()
	emit_signal("toggled", player_id)
