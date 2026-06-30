extends Node

const PROFILES_FILE: String = "user://profiles.json"
const LEGACY_SAVE: String = "user://savegame.json"
const SAVE_PREFIX: String = "user://save_"
const SAVE_SUFFIX: String = ".json"

static func _profile_path(profile_id: String) -> String:
	var pid: String = str(profile_id).strip_edges()
	if pid == "":
		pid = "default"
	# sanitation simple
	pid = pid.replace("/", "_").replace("\\", "_").replace("..", "_").replace(" ", "_")
	return SAVE_PREFIX + pid + SAVE_SUFFIX

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt: String = f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	return JSON.parse_string(txt)

static func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

static func _copy_file(src: String, dst: String) -> bool:
	if not FileAccess.file_exists(src):
		return false

	var fr := FileAccess.open(src, FileAccess.READ)
	if fr == null:
		return false
	var b: PackedByteArray = fr.get_buffer(fr.get_length())
	fr.close()

	var fw := FileAccess.open(dst, FileAccess.WRITE)
	if fw == null:
		return false
	fw.store_buffer(b)
	fw.close()
	return true

static func ensure_exists() -> void:
	# profiles.json déjà là
	if FileAccess.file_exists(PROFILES_FILE):
		return

	# migration one-shot
	var profiles: Dictionary = {
		"version": 1,
		"active_profile_id": "default",
		"profiles": [
			{"id": "default", "label": "Default"}
		],
		"created_at_unix": Time.get_unix_time_from_system()
	}
	_write_json(PROFILES_FILE, profiles)

	# si legacy save existe, copie -> save_default.json
	var dst: String = _profile_path("default")
	if FileAccess.file_exists(LEGACY_SAVE):
		_copy_file(LEGACY_SAVE, dst)

static func get_active_profile_id() -> String:
	ensure_exists()
	var v: Variant = _read_json(PROFILES_FILE)
	if typeof(v) != TYPE_DICTIONARY:
		return "default"
	var d: Dictionary = v as Dictionary
	return str(d.get("active_profile_id", "default")).strip_edges()

static func _set_active_profile_id(profile_id: String) -> void:
	ensure_exists()
	var v: Variant = _read_json(PROFILES_FILE)
	var d: Dictionary = {} if typeof(v) != TYPE_DICTIONARY else (v as Dictionary)
	if d.is_empty():
		d = {"version": 1, "profiles": [], "created_at_unix": Time.get_unix_time_from_system()}
	d["active_profile_id"] = str(profile_id).strip_edges()
	_write_json(PROFILES_FILE, d)

static func flush_active_to_profile_file() -> void:
	var pid: String = get_active_profile_id()
	var ppath: String = _profile_path(pid)
	if FileAccess.file_exists(LEGACY_SAVE):
		_copy_file(LEGACY_SAVE, ppath)

static func activate_profile(profile_id: String) -> void:
	var new_id: String = str(profile_id).strip_edges()
	if new_id == "":
		new_id = "default"

	ensure_exists()

	var current_id: String = get_active_profile_id()
	if new_id == current_id:
		var same_src: String = _profile_path(new_id)
		if FileAccess.file_exists(same_src):
			_copy_file(same_src, LEGACY_SAVE)
		else:
			_write_json(same_src, _default_save_dict(new_id))
			_copy_file(same_src, LEGACY_SAVE)
		_set_active_profile_id(new_id)
		return

	# 1) flush actuel
	flush_active_to_profile_file()

	# 2) applique le nouveau
	var src: String = _profile_path(new_id)
	if FileAccess.file_exists(src):
		_copy_file(src, LEGACY_SAVE)
	else:
		# profil nouveau -> save neutre (ne pas cloner legacy d’un autre profil)
		_write_json(src, _default_save_dict(new_id))
		_copy_file(src, LEGACY_SAVE)

	# 3) active
	_set_active_profile_id(new_id)

static func reset_active_profile() -> void:
	ensure_exists()
	var pid: String = get_active_profile_id()
	var fresh: Dictionary = _default_save_dict(pid)
	_write_json(_profile_path(pid), fresh)
	_write_json(LEGACY_SAVE, fresh)


static func add_profile(profile_id: String, label: String = "") -> void:
	ensure_exists()
	var pid: String = str(profile_id).strip_edges()
	if pid == "":
		pid = "default"

	var v: Variant = _read_json(PROFILES_FILE)
	var d: Dictionary = {} if typeof(v) != TYPE_DICTIONARY else (v as Dictionary)
	if d.is_empty():
		d = {"version": 1, "active_profile_id": "default", "profiles": []}

	var arr: Array = []
	if typeof(d.get("profiles")) == TYPE_ARRAY:
		arr = d.get("profiles") as Array

	for p in arr:
		if typeof(p) == TYPE_DICTIONARY and str((p as Dictionary).get("id", "")) == pid:
			return

	arr.append({"id": pid, "label": (label if label != "" else pid)})
	d["profiles"] = arr
	_write_json(PROFILES_FILE, d)

static func _default_save_dict(profile_id: String) -> Dictionary:
	# Save neutre pour un nouveau profil (évite copier le legacy d’un autre profil)
	return {
		"version": 1,
		"profile_id": str(profile_id),
		"team_name": "",
		"intro_popup_first_match_seen": false,
		"early_flow_stadium_unlocked": false,
		"stadium_intro_seen": false,
		"season_number": 1,
		"season_round": 0,
		"club": {"name": "BM Club", "level": 1, "xp": 0},
		"wallet": {"euros": 1200, "tokens": 0},
		"total_billetterie": 0,
		"total_boutique": 0,
		"total_sponsors": 0,
		"total_tournois": 0,
		"total_depenses": 0,
		"total_recettes": 0,
		"finance_history_recettes": [],
		"finance_history_depenses": [],
		"finance_history_solde": [],
		"progress": {"journee": 1, "wins": 0, "losses": 0},
		"meta": {"created_at_unix": Time.get_unix_time_from_system()}
	}
