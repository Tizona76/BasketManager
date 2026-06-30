extends Node3D

@onready var rig: Node3D = get_node_or_null("Rig") as Node3D
@onready var cam: Camera3D = get_node_or_null("Camera3D") as Camera3D

@export var index_centre: int = 0

@export var spacing_x: float = 1.15
@export var depth_step: float = 0.70
@export var side_drop_y: float = 0.08

@export var scale_center: float = 1.00
@export var scale_step: float = 0.12
@export var min_scale: float = 0.72

@export var rot_y_step_deg: float = 18.0
@export var max_visible_offset: int = 3
@export var tween_time: float = 0.20

var cartes: Array[Node3D] = []

func _ready() -> void:
	# Rig optionnel
	if rig == null:
		rig = self
		print("[CAROUSEL][WARN] Rig missing -> using self")

	# Camera obligatoire (créée si manquante)
	if cam == null:
		cam = Camera3D.new()
		cam.name = "Camera3D"
		add_child(cam)
		cam.current = true
		print("[CAROUSEL][WARN] Camera3D missing -> created")

	_setup_camera()
	_collect_cartes()
	_clamp_index()
	_apply_carousel_layout(false)

func _setup_camera() -> void:
	if cam == null:
		push_error("[CAROUSEL] cam is null in _setup_camera()")
		return

	cam.position = Vector3(0.0, 1.6, 6.0)
	cam.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	cam.fov = 55.0

func _collect_cartes() -> void:
	cartes.clear()

	if rig == null:
		return

	for child in rig.get_children():
		if child is Node3D:
			cartes.append(child as Node3D)

	print("[CAROUSEL] cartes found = ", cartes.size())

func _clamp_index() -> void:
	if cartes.is_empty():
		index_centre = 0
		return
	index_centre = clamp(index_centre, 0, cartes.size() - 1)

func _unhandled_input(event: InputEvent) -> void:
	if cartes.is_empty():
		return

	if event.is_action_pressed("ui_right"):
		_carousel_next()
		return

	if event.is_action_pressed("ui_left"):
		_carousel_prev()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_carousel_next()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_carousel_prev()

func _carousel_next() -> void:
	if cartes.is_empty():
		return
	index_centre = min(index_centre + 1, cartes.size() - 1)
	_apply_carousel_layout(true)

func _carousel_prev() -> void:
	if cartes.is_empty():
		return
	index_centre = max(index_centre - 1, 0)
	_apply_carousel_layout(true)

func center_on_card(card: Node3D) -> void:
	var idx: int = cartes.find(card)
	if idx == -1:
		return
	index_centre = idx
	_apply_carousel_layout(true)

func _apply_carousel_layout(use_tween: bool = true) -> void:
	if rig == null:
		return

	for i in range(cartes.size()):
		var carte: Node3D = cartes[i]
		if carte == null:
			continue

		var offset: int = i - index_centre
		var abs_offset: int = abs(offset)

		if abs_offset > max_visible_offset:
			carte.visible = false
			continue

		carte.visible = true

		var target_x: float = float(offset) * spacing_x
		var target_y: float = 0.0 - float(abs_offset) * side_drop_y
		var target_z: float = -float(abs_offset) * depth_step

		var target_scale_value: float = max(min_scale, scale_center - float(abs_offset) * scale_step)
		var target_scale: Vector3 = Vector3.ONE * target_scale_value

		var target_rot_y: float = deg_to_rad(float(offset) * rot_y_step_deg)
		var target_basis: Basis = Basis.from_euler(Vector3(0.0, target_rot_y, 0.0))

		if use_tween:
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(carte, "position", Vector3(target_x, target_y, target_z), tween_time)
			tw.tween_property(carte, "scale", target_scale, tween_time)
			tw.tween_property(carte, "basis", target_basis, tween_time)
		else:
			carte.position = Vector3(target_x, target_y, target_z)
			carte.scale = target_scale
			carte.basis = target_basis

func refresh_carousel() -> void:
	_collect_cartes()
	_clamp_index()
	_apply_carousel_layout(false)
