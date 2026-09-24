extends Node

var _layer: CanvasLayer
var _button: Button
var _field: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(OS.has_feature("ios"))

func _process(_delta: float) -> void:
	var root_view := get_tree().root
	var landscape := root_view.get_visible_rect().size.x > root_view.get_visible_rect().size.y
	var focused := root_view.gui_get_focus_owner()
	# Embedded dialogs have their own viewport and focus owner.
	for window in root_view.find_children("*", "Window", true, false):
		if window.visible and window.gui_get_focus_owner() != null:
			focused = window.gui_get_focus_owner()
	var editable: bool = (focused is LineEdit or focused is TextEdit) and focused.editable and focused.virtual_keyboard_enabled
	if not landscape or not editable or not focused.is_visible_in_tree():
		if is_instance_valid(_button):
			_button.hide()
		_field = null
		return
	_field = focused
	var view := focused.get_viewport()
	if not is_instance_valid(_layer) or _layer.get_parent() != view:
		if is_instance_valid(_layer):
			_layer.queue_free()
		_layer = CanvasLayer.new()
		_layer.layer = 128
		view.add_child(_layer)
		_button = Button.new()
		_button.name = "MobileKeyboardDismiss"
		_button.text = "Close Keyboard"
		_button.custom_minimum_size = Vector2(150, 44)
		_button.add_theme_font_size_override("font_size", 16)
		_button.focus_mode = Control.FOCUS_NONE
		_button.pressed.connect(_hide_keyboard)
		_layer.add_child(_button)
	_button.show()
	_place_button(view)

func _hide_keyboard() -> void:
	if is_instance_valid(_field):
		_field.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_button.hide()
	_field = null

func _place_button(view: Viewport) -> void:
	var screen_size := Vector2(DisplayServer.window_get_size())
	var visible_screen := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(screen_size.x, maxf(0, screen_size.y - DisplayServer.virtual_keyboard_get_height())))
	var safe := view.get_visible_rect().intersection(view.get_screen_transform().affine_inverse() * visible_screen)
	if safe.size.x > 16 and safe.size.y > 16:
		safe = safe.grow(-8)
	var size := _button.size
	var field_rect := _field.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _field.size)
	var candidates: Array[Vector2] = [
		Vector2(field_rect.end.x + 8, field_rect.position.y),
		Vector2(field_rect.position.x - size.x - 8, field_rect.position.y),
		Vector2(field_rect.position.x, field_rect.position.y - size.y - 8),
		Vector2(field_rect.position.x, field_rect.end.y + 8)
	]
	# Find free space without moving or covering existing form controls.
	var occupied: Array[Rect2] = []
	for control in view.find_children("*", "Control", true, false):
		if control != _button and control.get_viewport() == view and control.is_visible_in_tree() and (control is BaseButton or control is LineEdit or control is TextEdit):
			occupied.append(control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size))
	for y in range(int(safe.position.y), int(safe.end.y - size.y) + 1, 8):
		for x in range(int(safe.position.x), int(safe.end.x - size.x) + 1, 16):
			candidates.append(Vector2(x, y))
	for position in candidates:
		var rect := Rect2(position, size)
		if not safe.encloses(rect):
			continue
		var clear := true
		for other in occupied:
			if rect.grow(4).intersects(other):
				clear = false
				break
		if clear:
			_button.position = position
			return
	# Keep dismissal reachable even when the keyboard leaves no empty space.
	_button.position = Vector2(maxf(safe.position.x, safe.end.x - size.x), maxf(safe.position.y, safe.end.y - size.y))
