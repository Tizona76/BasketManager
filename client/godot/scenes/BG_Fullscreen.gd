extends TextureRect

func _ready() -> void:
	_apply_fullscreen()
	get_viewport().size_changed.connect(_apply_fullscreen)

func _apply_fullscreen() -> void:
	# Force le BG à la taille exacte de la fenêtre
	position = Vector2.ZERO
	size = get_viewport_rect().size
