extends Label

const PlayerLife := preload("res://scripts/PlayerLife.gd")

var _accum := 0.0
var _tooltip_panel: Panel = null
var _tooltip_label: Label = null

func _bm_is_stadium_popularity_badge() -> bool:
	var n: Node = self
	while n != null:
		var nm := str(n.name)
		if nm == "Stadium" or nm == "StadiumMinimal":
			return true
		n = n.get_parent()
	return false

func _ready() -> void:
	add_theme_font_size_override("font_size", 24)
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	add_theme_color_override("font_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	add_theme_constant_override("outline_size", 0)

	mouse_filter = Control.MOUSE_FILTER_STOP

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	_refresh()

func _process(delta: float) -> void:
	_accum += delta
	if _accum >= 0.25:
		_accum = 0.0
		_refresh()

	if _tooltip_panel != null and _tooltip_panel.visible:
		var mp := get_viewport().get_mouse_position()
		_tooltip_panel.position = mp + Vector2(-440, 14)

func _refresh() -> void:
	var label_txt := tr("club.popularity")
	if label_txt == "club.popularity":
		label_txt = "Popularity"

	var save: Dictionary = PlayerLife.load_savegame()
	if typeof(save) == TYPE_DICTIONARY:
		PlayerLife.ensure_finance_schema(save)
		var pop := int(save.get("popularite", 50))
		text = "%s : %d%%" % [label_txt, pop]
	else:
		text = "%s : 50%%" % label_txt

	if _tooltip_label != null:
		var tip := tr("club.popularity.tooltip")
		if tip == "club.popularity.tooltip":
			tip = "Indicator showing the stadium fill rate. It changes with your team's wins and losses and reflects your supporters' backing."
		_tooltip_label.text = tip

func _ensure_tooltip() -> void:
	if _tooltip_panel != null:
		return

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		return

	_tooltip_panel = Panel.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 50
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.custom_minimum_size = Vector2(420, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.border_color = Color(1.0, 0.72, 0.20, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_left = 10
	m.offset_top = 8
	m.offset_right = -10
	m.offset_bottom = -8

	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(400, 0)
	_tooltip_label.add_theme_font_size_override("font_size", 22)
	if _bm_is_stadium_popularity_badge():
		_tooltip_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	else:
		_tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	var tip := tr("club.popularity.tooltip")
	if tip == "club.popularity.tooltip":
		tip = "Indicator showing the stadium fill rate. It changes with your team's wins and losses and reflects your supporters' backing."
	_tooltip_label.text = tip

	m.add_child(_tooltip_label)
	_tooltip_panel.add_child(m)
	root.add_child(_tooltip_panel)

func _on_mouse_entered() -> void:
	_ensure_tooltip()
	if _tooltip_panel == null:
		return
	var mp := get_viewport().get_mouse_position()
	_tooltip_panel.position = mp + Vector2(-440, 14)
	_tooltip_panel.visible = true

func _on_mouse_exited() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false
