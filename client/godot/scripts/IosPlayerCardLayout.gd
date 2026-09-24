extends Node
# Presentation shared by the three existing player-detail popups. No player data.
var _card: Control
var _avatar: Control
var _badge: Control
var _stats: Control
var _close: Button
var _labels: Dictionary
var _original: Dictionary = {}

func configure(card: Control, avatar: Control, badge: Control, stats: Control, close: Button, labels: Dictionary) -> void:
	_card = card
	_avatar = avatar
	_badge = badge
	_stats = stats
	_close = close
	_labels = labels
	for node in [card, avatar, badge, stats, close] + labels.values():
		_original[node] = {"position": node.position, "size": node.size, "scale": node.scale, "custom_minimum_size": node.custom_minimum_size}
	var name_label: Label = labels["name"]
	_original[name_label]["autowrap_mode"] = name_label.autowrap_mode
	_original[name_label]["theme_override_font_sizes/font_size"] = name_label.get_theme_font_size("font_size")
	for path in ["PlayerProfileGraph", "PlayerProfileGraphAttackDefenseTooltipArea", "PlayerProfileGraphPhysicalMentalTooltipArea"]:
		var node := card.get_node(path) as Control
		_original[node] = {"size": node.size}

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	for node in _original:
		for property in _original[node]:
			node.set(property, _original[node][property])
	var vp := _card.get_viewport_rect().size
	if not OS.has_feature("ios") or vp.x <= vp.y:
		return
	# final_transform includes the project's canvas_items scale (currently 1.15).
	var transform := get_viewport().get_final_transform()
	var screen_scale := Vector2(transform.x.length(), transform.y.length())
	var design := Vector2(792, 360)
	var available := vp - Vector2(24.0 / screen_scale.x, 20.0 / screen_scale.y)
	var factor := minf(available.x / design.x, available.y / design.y)
	_card.custom_minimum_size = design
	_card.size = design
	_card.scale = Vector2.ONE * factor
	_card.position = (vp - design * factor) * 0.5
	_avatar.position.y = 24
	var name_label: Label = _labels["name"]
	name_label.position = Vector2(24, 218)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.size = Vector2(220, 60)
	_badge.position.y = 282
	for key in ["rating", "age", "salary"]:
		if _labels.has(key):
			_labels[key].position.y -= 60
	_stats.position.y = 168
	if _labels.has("injured"):
		_labels["injured"].position.y = 322
	for path in ["PlayerProfileGraph", "PlayerProfileGraphAttackDefenseTooltipArea", "PlayerProfileGraphPhysicalMentalTooltipArea"]:
		_card.get_node(path).size.y = 144
	# Keep a 44-screen-pixel hit target after both global and local scaling.
	_close.size = Vector2(44.0 / screen_scale.x, 44.0 / screen_scale.y) / factor
	_close.position = Vector2(design.x - _close.size.x - 8, 8)

static func contain_tooltip(card: Control, tooltip: Control) -> void:
	var vp := card.get_viewport_rect().size
	if OS.has_feature("ios") and vp.x > vp.y:
		# The existing graph explanation must stay below the close button.
		tooltip.position.y = clampf(60.0, 8.0, maxf(8.0, card.size.y - tooltip.size.y - 8.0))
