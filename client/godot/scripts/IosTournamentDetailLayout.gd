extends Node
## Presentation only: preserve the existing bracket and its tournament handlers.

var _scene: Control
var _bracket: Control
var _scroll: ScrollContainer
var _original: Dictionary = {}
var _original_index: int
var _active := false

static func bracket_font_size(control: Control) -> int:
	var viewport_size := control.get_viewport_rect().size
	if OS.has_feature("ios") and not OS.has_feature("web") and not OS.has_feature("android") and viewport_size.x > viewport_size.y:
		return roundi(18.0 * 0.90)
	return 18

func _ready() -> void:
	name = "IosTournamentDetailLayout"
	_scene = get_parent() as Control
	_bracket = _scene.get_node_or_null("UI/EliteBracketClean") as Control
	if _bracket == null:
		_bracket = _scene.get_node("UI/BracketWrap") as Control
	_original_index = _bracket.get_index()
	get_viewport().size_changed.connect(_apply)
	_apply()

func is_landscape_active() -> bool:
	return _active

func _set_layout(control: Control, properties: Dictionary) -> void:
	if not _original.has(control):
		_original[control] = {}
	for property in properties:
		if not _original[control].has(property):
			_original[control][property] = control.get(property)
		control.set(property, properties[property])

func _apply() -> void:
	var viewport_size := _scene.get_viewport_rect().size
	if viewport_size.x <= viewport_size.y:
		if not _active:
			return
		_active = false
		_move_lines(_scene.get_node("UI"))
		_bracket.reparent(_scene.get_node("UI"), false)
		_scene.get_node("UI").move_child(_bracket, _original_index)
		for control in _original:
			for property in _original[control]:
				control.set(property, _original[control][property])
		_original.clear()
		_scroll.hide()
		_refresh_vs_text()
		call_deferred("_refresh_lines")
		return

	_active = true
	_set_layout(_scene.get_node("BG"), {
		"anchor_left": 0.0, "anchor_top": 0.0, "anchor_right": 1.0, "anchor_bottom": 1.0,
		"offset_left": 0.0, "offset_top": 0.0, "offset_right": 0.0, "offset_bottom": 0.0,
		"expand_mode": TextureRect.EXPAND_IGNORE_SIZE,
		"stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
	})
	_set_layout(_scene.get_node("UI/LblTitle"), {
		"theme_override_font_sizes/font_size": 24,
		"offset_left": -viewport_size.x * 0.5 + 16.0, "offset_right": viewport_size.x * 0.5 - 16.0,
		"offset_top": 8.0, "offset_bottom": 44.0,
	})
	for button_name in ["BtnRetour", "BtnSimulerTour"]:
		var button := _scene.get_node("UI/" + button_name) as Button
		var is_back: bool = button_name == "BtnRetour"
		var width := 120.0 if is_back else 190.0
		_set_layout(button, {
			"theme_override_font_sizes/font_size": 18,
			"custom_minimum_size": Vector2(width, 44),
			"position": Vector2(16.0 if is_back else viewport_size.x - width - 16.0, viewport_size.y - 56.0),
			"size": Vector2(width, 44),
			"scale": Vector2.ONE * (0.90 if is_back else 0.85),
			"pivot_offset": Vector2(0.0 if is_back else width, 44),
		})
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var property: String = "theme_override_styles/" + state
			var source := button.get(property) as StyleBox
			if _original[button].has(property):
				source = _original[button][property] as StyleBox
			if source == null:
				continue
			var style := source.duplicate() as StyleBox
			style.content_margin_left = 12.0
			style.content_margin_right = 12.0
			style.content_margin_top = 6.0
			style.content_margin_bottom = 6.0
			_set_layout(button, {property: style})
		button.size = Vector2(width, 44)

	if _scroll == null:
		_scroll = ScrollContainer.new()
		_scroll.name = "TournamentBracketScroll"
		_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		_scroll.scroll_deadzone = 8
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.get_v_scroll_bar().custom_minimum_size.x = 14.0
		_scene.get_node("UI").add_child(_scroll)
	_scroll.position = Vector2(16, 54)
	_scroll.size = Vector2(viewport_size.x - 32.0, viewport_size.y - 122.0)
	_scroll.show()

	var margin := _bracket.get_node_or_null("BracketMargin") as MarginContainer
	var row := _bracket as HBoxContainer
	if margin != null:
		row = margin.get_node("RoundsRow") as HBoxContainer
		_set_layout(margin, {"position": Vector2.ZERO, "size": Vector2.ZERO,
			"theme_override_constants/margin_left": 8, "theme_override_constants/margin_right": 8,
			"theme_override_constants/margin_top": 8, "theme_override_constants/margin_bottom": 8})
		if not margin.minimum_size_changed.is_connected(_sync_extent):
			margin.minimum_size_changed.connect(_sync_extent, CONNECT_DEFERRED)
	_set_layout(row, {"theme_override_constants/separation": 16})
	var inset := 16.0 if margin != null else 0.0
	var column_width := floorf((_scroll.size.x - 14.0 - inset - 16.0 * (row.get_child_count() - 1)) / row.get_child_count())
	for column in row.get_children():
		_set_layout(column, {"custom_minimum_size": Vector2(column_width, 0),
			"theme_override_constants/separation": 10})
		for child in column.get_children():
			if child is Label:
				_set_layout(child, {"theme_override_font_sizes/font_size": bracket_font_size(_scene),
					"theme_override_constants/outline_size": 2})
			elif child is RichTextLabel:
				_set_layout(child, {"custom_minimum_size": Vector2(column_width, 540),
					"theme_override_font_sizes/normal_font_size": bracket_font_size(_scene), "fit_content": true,
					"mouse_filter": Control.MOUSE_FILTER_PASS})
	_set_layout(_bracket, {"position": Vector2.ZERO, "size": Vector2.ZERO,
		"custom_minimum_size": Vector2.ZERO, "mouse_filter": Control.MOUSE_FILTER_PASS})
	if _bracket.get_parent() != _scroll:
		_bracket.reparent(_scroll, false)
	# EliteColumns is an unused empty Desktop container in front of the actual bracket.
	var unused := _scene.get_node_or_null("UI/EliteColumns") as Control
	if unused != null:
		_set_layout(unused, {"visible": false})
	_move_lines(_bracket)
	_refresh_vs_text()
	call_deferred("_sync_extent")

func _refresh_vs_text() -> void:
	# Refresh only the existing presentation after changing the inline VS font.
	if _bracket.name == "BracketWrap":
		_scene.call("_refresh_ui")

func _move_lines(target: Node) -> void:
	for line_name in ["LineR2A", "LineR2B", "LineR2C", "LineR2D", "LineR3A", "LineR3B", "LineW"]:
		var line := _scene.find_child(line_name, true, false)
		if line != null and line.get_parent() != target:
			line.reparent(target, true)

func _sync_extent() -> void:
	if not _active:
		return
	var margin := _bracket.get_node_or_null("BracketMargin") as MarginContainer
	if margin != null:
		margin.size = margin.get_combined_minimum_size()
		_bracket.custom_minimum_size = margin.size
	call_deferred("_refresh_lines")

func _refresh_lines() -> void:
	# A and Intermediate use these connectors; Elite's visible table has none.
	if _bracket.name == "BracketWrap":
		_scene.call("_update_bracket_lines", "", "", "")

static func prepare_final_cinematic(scene: Control, layer: CanvasLayer, title: Label,
		left: Label, right: Label, left_crest: TextureRect, right_crest: TextureRect,
		vs_label: Label, score: Label, champion: Label, top_line: ColorRect,
		bottom_line: ColorRect, sparks: CPUParticles2D) -> float:
	var vp := scene.get_viewport_rect().size
	if not OS.has_feature("ios") or OS.has_feature("web") or OS.has_feature("android") or vp.x <= vp.y:
		return 0.0
	# Parent scale survives the score/champion reveal tweens. Play and the
	# full-screen dimmer remain outside this visual-only group.
	var content := Node2D.new()
	content.name = "IosFinalContent"
	layer.add_child(content)
	content.scale = Vector2.ONE * 0.90
	content.position.x = vp.x * 0.05
	for item in [title, left, right, left_crest, right_crest, vs_label, score, champion, top_line, bottom_line, sparks]:
		if item != null:
			item.reparent(content, false)
			if item is Control:
				item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position.y = 0.0
	title.size.y = title.get_combined_minimum_size().y
	# Reserve the winner's natural line height and a gap above Play (at 80%).
	champion.size.y = champion.get_combined_minimum_size().y
	champion.position.y = vp.y * 0.80 / 0.90 - champion.size.y - 4.0
	bottom_line.position.y = champion.position.y - 6.0
	top_line.position.y = title.size.y + 4.0
	var center_y := (top_line.position.y + top_line.size.y + bottom_line.position.y) * 0.5
	# Crests flank the names and score, leaving enough vertical room for
	# the winner above Play. Wrapped names retain their original font size.
	for label in [left, right]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.update_minimum_size()
		label.size = Vector2(vp.x * 0.27, 0.0)
		label.get_line_count()
		label.update_minimum_size()
	var name_height := maxf(left.get_combined_minimum_size().y, right.get_combined_minimum_size().y)
	score.size.y = score.get_combined_minimum_size().y
	vs_label.size.y = vs_label.get_combined_minimum_size().y
	var score_height := maxf(score.size.y * 1.13, vs_label.size.y)
	var group_height := name_height + 6.0 + score_height
	for label in [left, right]:
		label.size.y = name_height
		label.position.y = center_y - group_height * 0.5
	for crest in [left_crest, right_crest]:
		if crest != null:
			crest.position.y = center_y - crest.size.y * 0.5
	for label in [vs_label, score]:
		label.position.y = center_y + group_height * 0.5 - score_height * 0.5 - label.size.y * 0.5
		label.pivot_offset = label.size * 0.5
	champion.pivot_offset = champion.size * 0.5
	sparks.position.y = center_y
	# Leave a clear central lane for the score, including its reveal animation.
	return vp.x * 0.18
