extends Node

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer

var _audio_unlocked := false
var _music_loop_enabled := false
var _music_path := ""
var _music_volume_db := -6.0
var _sfx_volume_db := -6.0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.name = "AudioMusic"
	music.volume_db = _music_volume_db
	add_child(music)

	sfx = AudioStreamPlayer.new()
	sfx.name = "AudioSfx"
	sfx.volume_db = _sfx_volume_db
	add_child(sfx)

	print("[AudioManager] ready (music+sfx created)")

func unlock_from_user_gesture(optional_click_sfx_path: String = "") -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true
	print("[AudioManager] unlocked by user gesture")

	if optional_click_sfx_path != "":
		play_sfx(optional_click_sfx_path)

func play_sfx(path: String) -> void:
	var st := load(path) as AudioStream
	if st == null:
		push_error("[AudioManager] cannot load sfx: " + path)
		return
	sfx.stream = st
	sfx.play()

func play_music(path: String, loop: bool = true, restart_if_same: bool = false) -> void:
	if music.playing and _music_path == path and not restart_if_same:
		return

	_music_path = path
	_music_loop_enabled = loop

	var st := load(path) as AudioStream
	if st == null:
		push_error("[AudioManager] cannot load music: " + path)
		return

	music.stream = st

	if music.finished.is_connected(_on_music_finished):
		music.finished.disconnect(_on_music_finished)
	if loop:
		music.finished.connect(_on_music_finished)

	music.play()

func stop_music() -> void:
	if music.finished.is_connected(_on_music_finished):
		music.finished.disconnect(_on_music_finished)
	music.stop()
	_music_path = ""
	_music_loop_enabled = false

func _on_music_finished() -> void:
	if _music_loop_enabled and _music_path != "":
		music.play()

func set_music_volume_db(db: float) -> void:
	_music_volume_db = db
	if music:
		music.volume_db = db

func set_sfx_volume_db(db: float) -> void:
	_sfx_volume_db = db
	if sfx:
		sfx.volume_db = db
