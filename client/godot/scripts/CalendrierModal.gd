extends Control
const PlayerLife := preload("res://scripts/PlayerLife.gd")

# BM_CALENDAR_TEXT_PLUS2_MOBILE_V1
func _bm_calendar_apply_mobile_text_plus2(root: Node = null) -> void:
	if root == null:
		root = self
	if root == null:
		return
	if root is Control:
		var c := root as Control
		var fs := int(c.get_theme_font_size("font_size"))
		if fs > 0:
			c.add_theme_font_size_override("font_size", fs + 2)
	for child in root.get_children():
		_bm_calendar_apply_mobile_text_plus2(child)


signal closed

@onready var btn_close: Button = get_node("Panel/BtnClose") as Button
@onready var title: Label = get_node("Panel/Title") as Label
@onready var scroll: ScrollContainer = get_node("Panel/Scroll") as ScrollContainer
@onready var content: VBoxContainer = get_node("Panel/Scroll/Content") as VBoxContainer


func _bm_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	return OS.has_feature("android") or OS.has_feature("ios") or vp.x < 900.0



func _bm_calendar_is_mobile_layout() -> bool:
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

func _bm_calendar_apply_mobile_landscape_layout() -> void:
	if not _bm_calendar_is_mobile_layout():
		return

	var vp := get_viewport_rect().size
	if vp.x <= vp.y:
		return

	var panel := get_node_or_null("Panel") as Control
	var close_btn := get_node_or_null("Panel/BtnClose") as Button
	var title_lbl := get_node_or_null("Panel/Title") as Label
	var scroll_box := get_node_or_null("Panel/Scroll") as ScrollContainer
	var footer := get_node_or_null("Panel/Footer") as Label

	if panel == null or close_btn == null or title_lbl == null or scroll_box == null:
		return

	var margin_x := 18.0
	var margin_y := 14.0

	var current_panel_width := maxf(320.0, vp.x - margin_x * 2.0)
	var panel_size := Vector2(
		maxf(320.0, current_panel_width * 0.765),
		maxf(220.0, vp.y - margin_y * 2.0)
	)

	panel.position = Vector2(
		(vp.x - panel_size.x) * 0.5,
		margin_y
	)
	panel.size = panel_size
	panel.custom_minimum_size = panel_size

	# Header
	title_lbl.position = Vector2(14.0, 7.0)
	title_lbl.size = Vector2(
		maxf(120.0, panel_size.x - 86.0),
		44.0
	)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)

	# Croix
	close_btn.custom_minimum_size = Vector2(51.0, 51.0)
	close_btn.size = Vector2(51.0, 51.0)
	close_btn.position = Vector2(
		panel_size.x - close_btn.size.x - 8.0,
		4.0
	)
	close_btn.add_theme_font_size_override("font_size", 27)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.disabled = false
	close_btn.z_index = 50
	close_btn.move_to_front()

	# Scroll entièrement contenu dans le panel
	var scroll_margin := 12.0
	var scroll_top := 58.0

	scroll_box.position = Vector2(scroll_margin, scroll_top)
	scroll_box.size = Vector2(
		maxf(200.0, panel_size.x - scroll_margin * 2.0),
		maxf(120.0, panel_size.y - scroll_top - 12.0)
	)

	if footer != null:
		footer.visible = false


func _ready() -> void:
	if _bm_calendar_is_mobile_layout():
		_bm_calendar_apply_mobile_text_plus2()
		var close_btn := get_node_or_null("BtnClose") as Button
		if close_btn == null:
			close_btn = find_child("BtnClose", true, false) as Button
		if close_btn != null:
			close_btn.custom_minimum_size = Vector2(51, 51)
			close_btn.size = Vector2(51, 51)
			close_btn.add_theme_font_size_override("font_size", 27)
			close_btn.z_index = 20

			# Le TSCN place la croix à x=940 dans un panel de 1000 px.
			# Sur iPhone paysage elle sort du viewport : la ramener
			# explicitement dans le coin supérieur droit visible.
			var panel := get_node_or_null("Panel") as Control
			var vp := get_viewport_rect().size
			if panel != null and vp.x > vp.y:
				close_btn.position = Vector2(
					maxf(12.0, vp.x - panel.position.x - close_btn.size.x - 12.0),
					8.0
				)

	# Sécurité : si le node n'existe pas, on le voit tout de suite
	assert(btn_close != null)
	assert(title != null)
	assert(scroll != null)
	assert(content != null)
	title.text = tr("saison.tab.calendar")

	if _bm_is_mobile_layout():
		var title_font_size := int(title.get_theme_font_size("font_size"))
		title.add_theme_font_size_override("font_size", title_font_size + 4)

	_bm_calendar_apply_mobile_landscape_layout()

	btn_close.pressed.connect(_on_close_pressed)
	btn_close.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_close.focus_mode = Control.FOCUS_ALL
	btn_close.disabled = false
	btn_close.z_index = 50
	btn_close.move_to_front()


	_populate_placeholder_calendar()

	# Appliquer le scroll mémorisé
	await get_tree().process_frame
	scroll.scroll_vertical = max(0, SeasonState.decalage_scroll_calendrier)
	SeasonState.hauteur_contenu_calendrier = int(content.size.y)


func _process(_delta: float) -> void:
	SeasonState.decalage_scroll_calendrier = scroll.scroll_vertical



func _on_close_pressed() -> void:
	print("[CAL] close pressed -> close overlay")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	emit_signal("closed")
	queue_free()



func _bm_calendar_crest_for_team(save: Dictionary, team_name: String) -> TextureRect:
	if typeof(save) != TYPE_DICTIONARY:
		return null
	var path: String = PlayerLife.get_display_crest_path(save, team_name)
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _populate_placeholder_calendar() -> void:
	for c in content.get_children():
		c.queue_free()

	var save := PlayerLife.load_savegame()
	var my_name := "My Team"
	var start_round: int = 0
	var total_rounds: int = int(SeasonState.total_matchs_saison)

	if typeof(save) == TYPE_DICTIONARY:
		var n := str(save.get("team_name", "")).strip_edges()
		if n != "":
			my_name = n
		start_round = int(save.get("season_round", 0))

	var ss := get_node_or_null("/root/SeasonState")
	if ss == null:
		return

	for i in range(0, total_rounds):
		var opp_name := "Opponent"
		var fx: Dictionary = {}
		var opp_prefix := "vs"
		if ss.has_method("get_user_fixture_for_round"):
			fx = ss.call("get_user_fixture_for_round", my_name, i)
			if typeof(fx) == TYPE_DICTIONARY and fx.size() > 0:
				opp_name = str(fx.get("opponent", opp_name)).strip_edges()
				opp_prefix = "vs" if bool(fx.get("user_is_home", true)) else "@"

		var l := Label.new()
		for fp in [
			"res://assets/fonts/Inter-SemiBold.ttf",
			"res://assets/fonts/Inter-Regular.ttf",
			"res://assets/fonts/Poppins-SemiBold.ttf",
			"res://assets/fonts/Montserrat-SemiBold.ttf",
			"res://assets/fonts/Roboto-Medium.ttf"
		]:
			if ResourceLoader.exists(fp):
				l.add_theme_font_override("font", load(fp))
				break
		l.text = "Day %02d : %s" % [i + 1, opp_prefix]
		if typeof(fx) == TYPE_DICTIONARY and fx.has("home_score") and fx.has("away_score"):
			var home_score := int(fx.get("home_score", 0))
			var away_score := int(fx.get("away_score", 0))
			# score appended to opponent label below
			pass

			var user_is_home := bool(fx.get("user_is_home", true))
			var user_score := home_score if user_is_home else away_score
			var opp_score := away_score if user_is_home else home_score

			if user_score > opp_score:
				l.modulate = Color(0.45, 1.00, 0.45, 1.0)
			elif user_score < opp_score:
				l.modulate = Color(1.00, 0.45, 0.45, 1.0)
		var calendar_landscape := _bm_calendar_is_mobile_layout() and get_viewport_rect().size.x > get_viewport_rect().size.y
		l.add_theme_font_size_override("font_size", 20 if calendar_landscape else (32 if _bm_is_mobile_layout() else 28))
		if i == start_round:
			l.modulate = Color(0.25, 0.78, 1.00, 1.0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l.custom_minimum_size = Vector2(135, 0)

		var row := HBoxContainer.new()
		row.name = "CalendarMatchRow%02d" % (i + 1)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		row.add_child(l)

		var opp_icon := _bm_calendar_crest_for_team(save, opp_name)
		if opp_icon != null:
			row.add_child(opp_icon)

		var opp_label := Label.new()
		opp_label.text = opp_name
		if typeof(fx) == TYPE_DICTIONARY and fx.has("home_score") and fx.has("away_score"):
			opp_label.text += " (%d - %d)" % [int(fx.get("home_score", 0)), int(fx.get("away_score", 0))]
		opp_label.add_theme_font_size_override("font_size", 20 if calendar_landscape else (32 if _bm_is_mobile_layout() else 28))
		opp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		opp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opp_label.custom_minimum_size = Vector2(360, 0) if calendar_landscape else Vector2(760, 0)
		opp_label.modulate = l.modulate
		row.add_child(opp_label)

		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(row)
