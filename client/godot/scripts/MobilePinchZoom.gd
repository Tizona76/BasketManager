extends Node

const MIN_ZOOM := 1.0
const MAX_ZOOM := 1.45
const ZOOM_SPEED := 0.002

var _touch_points := {}
var _pressed_touches := {}
var _last_distance: float = 0.0
var _current_target: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _bm_is_mobile_layout() -> bool:
	var vp := get_viewport().get_visible_rect().size
	var win := DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _input(event: InputEvent) -> void:
	if not _bm_is_mobile_layout():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pressed_touches[touch.index] = true
			_touch_points[touch.index] = touch.position
		else:
			_pressed_touches.erase(touch.index)
			_touch_points.erase(touch.index)
			_last_distance = 0.0
		return

	if event is InputEventScreenDrag:
		if _pressed_touches.size() != 2:
			_last_distance = 0.0
			return
		var drag := event as InputEventScreenDrag
		if not _pressed_touches.has(drag.index):
			return
		_touch_points[drag.index] = drag.position
		_apply_pinch_zoom()


func _apply_pinch_zoom() -> void:
	if _pressed_touches.size() != 2 or _touch_points.size() != 2:
		_last_distance = 0.0
		return

	var target := get_tree().current_scene as Control
	if target == null:
		return

	if _current_target != target:
		_reset_target()
		_current_target = target

	var points := _touch_points.values()
	var p0 := points[0] as Vector2
	var p1 := points[1] as Vector2
	var distance := p0.distance_to(p1)

	if _last_distance <= 0.0:
		_last_distance = distance
		return

	var delta := distance - _last_distance
	_last_distance = distance
	if absf(delta) < 2.0:
		return

	var next_zoom := clampf(target.scale.x + (delta * ZOOM_SPEED), MIN_ZOOM, MAX_ZOOM)
	var center := (p0 + p1) * 0.5
	target.pivot_offset = target.get_global_transform().affine_inverse() * center
	target.scale = Vector2(next_zoom, next_zoom)


func _reset_target() -> void:
	if _current_target != null and is_instance_valid(_current_target):
		_current_target.scale = Vector2.ONE
		_current_target.pivot_offset = Vector2.ZERO
	_current_target = null
