extends SceneTree

func _init() -> void:
	# Force la compilation/chargement du script PlayerLife
	var s := load("res://scripts/PlayerLife.gd")
	print("[CHECK] load PlayerLife.gd -> ", s)
	quit()
