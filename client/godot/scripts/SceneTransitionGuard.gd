extends CanvasLayer
## Covers native scene replacements only; never owns or changes a scene.

const SETTLE_FRAMES := 2
var _cover: ColorRect
var _snapshot: TextureRect
var _cover_started_frame: int = 0
var _cover_started_usec: int = 0
var _scene_id: int = 0
var _generation: int = 0


func _is_mobile() -> bool:
	return OS.has_feature("ios") or OS.has_feature("android")


func _ready() -> void:
	if not _is_mobile():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	follow_viewport_enabled = false
	_cover = ColorRect.new()
	_cover.name = "TransitionCover"
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.hide()
	add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_snapshot = TextureRect.new()
	_snapshot.name = "LastVisibleFrame"
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(_snapshot)
	_snapshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_resize_cover)
	_resize_cover()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	get_tree().scene_changed.connect(_on_scene_changed)
	if get_tree().current_scene != null:
		_scene_id = get_tree().current_scene.get_instance_id()


func _resize_cover() -> void:
	_cover.position = Vector2.ZERO
	_cover.size = get_viewport().get_visible_rect().size


func _on_node_added(node: Node) -> void:
	# Also tracks the initial scene, before its _ready can request a change.
	if node == get_tree().current_scene:
		_scene_id = node.get_instance_id()


func _on_node_removed(node: Node) -> void:
	if node.get_instance_id() != _scene_id:
		return
	# Read the last rendered frame synchronously, before the next draw.
	# A chained replacement keeps the already visible snapshot.
	if not _cover.visible:
		_cover_started_frame = Engine.get_frames_drawn()
		_cover_started_usec = Time.get_ticks_usec()
		_capture_last_frame()
	_scene_id = 0
	_generation += 1
	_resize_cover()
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.show()


func _capture_last_frame() -> void:
	# Never read back every frame or await frame_post_draw here: that would
	# capture the replacement scene instead of the last visible screen.
	if Engine.get_frames_drawn() == 0:
		return
	var started := Time.get_ticks_usec()
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		# Keep the original opaque protection if no rendered image is available.
		if OS.is_debug_build():
			push_warning("[SceneTransitionGuard] No snapshot; using opaque fallback.")
		return
	_snapshot.texture = ImageTexture.create_from_image(image)
	if OS.is_debug_build():
		print("[SceneTransitionGuard] snapshot_ms=%.2f size=%s bytes=%d" % [
			(Time.get_ticks_usec() - started) / 1000.0,
			image.get_size(), image.get_data_size()])


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not _cover.visible:
		return
	_scene_id = scene.get_instance_id()
	var generation := _generation
	for frame in range(SETTLE_FRAMES):
		await get_tree().process_frame
		if generation != _generation:
			return
	# Flush frame callbacks/deferred layout before exposing the new scene.
	call_deferred("_finish_transition", generation, _scene_id)


func _finish_transition(generation: int, scene_id: int) -> void:
	var scene := get_tree().current_scene
	if generation != _generation or scene == null:
		return
	if scene.get_instance_id() != scene_id:
		return
	_cover.hide()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snapshot.texture = null
	if OS.is_debug_build():
		print("[SceneTransitionGuard] elapsed_draw_frames=%d cover_ms=%.2f" % [
			Engine.get_frames_drawn() - _cover_started_frame,
			(Time.get_ticks_usec() - _cover_started_usec) / 1000.0])
