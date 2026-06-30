extends SceneTree
func _init() -> void:
	print("[PROBE] start")
	print("[PROBE] exists PlayerLife.gd? ", FileAccess.file_exists("res://scripts/PlayerLife.gd"))
	print("[PROBE] loading PlayerLife.gd ...")
	var s := load("res://scripts/PlayerLife.gd")
	print("[PROBE] load result = ", s)
	quit()
