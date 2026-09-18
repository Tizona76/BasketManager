extends Node


const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.0

var _touches: Dictionary = {}
var _last_distance := 0.0
var _last_center := Vector2.ZERO

var _zoom := 1.0
var _pan := Vector2.ZERO
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_viewport_size = get_viewport().get_visible_rect().size
	_apply_transform()


func _ios_enabled() -> bool:
	return OS.has_feature("ios")


func _process(_delta: float) -> void:
	if not _ios_enabled():
		return

	var vp_size := get_viewport().get_visible_rect().size

	if vp_size != _last_viewport_size:
		_last_viewport_size = vp_size
		_reset_zoom()


func _input(event: InputEvent) -> void:
	if not _ios_enabled():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)

			if _touches.size() < 2:
				_last_distance = 0.0
				_last_center = Vector2.ZERO

		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag

		if _touches.has(drag.index):
			_touches[drag.index] = drag.position

		if _touches.size() == 2:
			_apply_two_finger_gesture()
			get_viewport().set_input_as_handled()
			return

		# Une fois zoomé : déplacement libre à un doigt.
		if _touches.size() == 1 and _zoom > MIN_ZOOM + 0.001:
			_pan += drag.relative
			_clamp_pan()
			_apply_transform()
			get_viewport().set_input_as_handled()


func _apply_two_finger_gesture() -> void:
	if _touches.size() != 2:
		return

	var keys := _touches.keys()

	var p0 := _touches[keys[0]] as Vector2
	var p1 := _touches[keys[1]] as Vector2

	var distance := p0.distance_to(p1)
	var center := (p0 + p1) * 0.5

	if _last_distance <= 0.0:
		_last_distance = distance
		_last_center = center
		return

	if distance <= 1.0:
		return

	var old_zoom := _zoom
	var ratio := distance / _last_distance
	var new_zoom := clampf(old_zoom * ratio, MIN_ZOOM, MAX_ZOOM)

	# Conserve sous les doigts le point actuellement pincé.
	if absf(new_zoom - old_zoom) > 0.0001:
		var scale_ratio := new_zoom / old_zoom
		_pan = center - ((center - _pan) * scale_ratio)
		_zoom = new_zoom

	# Les deux doigts peuvent également déplacer l'écran.
	_pan += center - _last_center

	if _zoom <= MIN_ZOOM + 0.001:
		_zoom = MIN_ZOOM
		_pan = Vector2.ZERO
	else:
		_clamp_pan()

	_apply_transform()

	_last_distance = distance
	_last_center = center


func _apply_transform() -> void:
	var vp := get_viewport()

	var xform := Transform2D(
		Vector2(_zoom, 0.0),
		Vector2(0.0, _zoom),
		_pan
	)

	vp.set_canvas_transform(xform)


func _clamp_pan() -> void:
	if _zoom <= MIN_ZOOM:
		_pan = Vector2.ZERO
		return

	var vp_size := get_viewport().get_visible_rect().size

	var scaled_size := vp_size * _zoom

	var min_x := vp_size.x - scaled_size.x
	var min_y := vp_size.y - scaled_size.y

	_pan.x = clampf(_pan.x, min_x, 0.0)
	_pan.y = clampf(_pan.y, min_y, 0.0)


func _reset_zoom() -> void:
	_touches.clear()

	_last_distance = 0.0
	_last_center = Vector2.ZERO

	_zoom = MIN_ZOOM
	_pan = Vector2.ZERO

	_apply_transform()
