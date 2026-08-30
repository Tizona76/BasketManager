extends Node

const PROFILES_FILE: String = "user://profiles.json"
const LEGACY_SAVE: String = "user://savegame.json"
const SAVE_PREFIX: String = "user://save_"
const SAVE_SUFFIX: String = ".json"
const CAREERS_PREFIX: String = "user://careers_"
const FALLBACK_LEAGUE_ID: String = "classic"

static func _sanitize_path_id(raw_id: String) -> String:
	var clean: String = str(raw_id).strip_edges()
	if clean == "":
		clean = "default"
	clean = clean.replace("/", "_").replace("\\", "_").replace("..", "_").replace(" ", "_")
	return clean

static func _profile_path(profile_id: String) -> String:
	return SAVE_PREFIX + _sanitize_path_id(profile_id) + SAVE_SUFFIX

static func _careers_index_path(profile_id: String) -> String:
	return CAREERS_PREFIX + _sanitize_path_id(profile_id) + SAVE_SUFFIX

static func _career_save_path(profile_id: String, career_id: String) -> String:
	return SAVE_PREFIX + _sanitize_path_id(profile_id) + "_" + _sanitize_path_id(career_id) + SAVE_SUFFIX

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
	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		return null
	return json.data

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

static func _empty_careers_index() -> Dictionary:
	return {
		"version": 1,
		"active_career_id": "",
		"careers": []
	}

static func _read_careers_index(profile_id: String) -> Variant:
	var parsed: Variant = _read_json(_careers_index_path(profile_id))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = parsed as Dictionary
	if typeof(d.get("careers")) != TYPE_ARRAY:
		return null
	return d

static func _career_exists_in_index(index: Dictionary, career_id: String) -> bool:
	if typeof(index.get("careers")) != TYPE_ARRAY:
		return false
	for raw_entry in index["careers"]:
		if typeof(raw_entry) == TYPE_DICTIONARY and str((raw_entry as Dictionary).get("career_id", "")).strip_edges() == career_id:
			return true
	return false

static func _find_first_existing_career_id(profile_id: String, index: Dictionary) -> String:
	if typeof(index.get("careers")) != TYPE_ARRAY:
		return ""
	for raw_entry in index["careers"]:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var cid: String = str((raw_entry as Dictionary).get("career_id", "")).strip_edges()
		if cid != "" and FileAccess.file_exists(_career_save_path(profile_id, cid)):
			return cid
	return ""

static func _scan_existing_career_ids(profile_id: String) -> Array[String]:
	var found: Array[String] = []
	var pid: String = _sanitize_path_id(profile_id)
	var prefix: String = "save_%s_" % pid
	var dir := DirAccess.open("user://")
	if dir == null:
		return found
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with(prefix) and file_name.ends_with(SAVE_SUFFIX):
			var cid: String = file_name.substr(prefix.length(), file_name.length() - prefix.length() - SAVE_SUFFIX.length())
			if cid != "":
				found.append(cid)
		file_name = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found

static func _generate_career_id(_profile_id: String) -> String:
	randomize()
	var unix_part: int = int(Time.get_unix_time_from_system())
	var random_part: int = randi() % 1000000
	return _sanitize_path_id("career_%d_%06d" % [unix_part, random_part])

static func _career_entry_from_save(save: Dictionary, career_id: String) -> Dictionary:
	var team_name: String = str(save.get("team_name", save.get("club_name", ""))).strip_edges()
	if team_name == "" and save.has("club") and typeof(save["club"]) == TYPE_DICTIONARY:
		team_name = str((save["club"] as Dictionary).get("name", "")).strip_edges()
	var league_id: String = str(save.get("league_id", FALLBACK_LEAGUE_ID)).strip_edges()
	if league_id == "":
		league_id = FALLBACK_LEAGUE_ID
	var club_level: int = maxi(1, int(save.get("club_level", 1)))
	if save.has("club") and typeof(save["club"]) == TYPE_DICTIONARY:
		club_level = maxi(1, int((save["club"] as Dictionary).get("level", club_level)))
	return {
		"career_id": career_id,
		"team_name": team_name,
		"league_id": league_id,
		"season": maxi(1, int(save.get("season_number", 1))),
		"club_level": club_level,
		"last_played": int(Time.get_unix_time_from_system())
	}

static func _write_career_save(profile_id: String, career_id: String, save: Dictionary) -> void:
	var career_save: Dictionary = save.duplicate(true)
	career_save["profile_id"] = _sanitize_path_id(profile_id)
	career_save["career_id"] = career_id
	if not career_save.has("league_id") or str(career_save.get("league_id", "")).strip_edges() == "":
		career_save["league_id"] = FALLBACK_LEAGUE_ID
	_write_json(_career_save_path(profile_id, career_id), career_save)

static func _legacy_source_path(profile_id: String) -> String:
	var profile_path: String = _profile_path(profile_id)
	if FileAccess.file_exists(profile_path):
		return profile_path
	if FileAccess.file_exists(LEGACY_SAVE):
		return LEGACY_SAVE
	return ""

static func _ensure_careers_for_profile(profile_id: String) -> void:
	var pid: String = _sanitize_path_id(profile_id)
	var index_path: String = _careers_index_path(pid)
	var existing_index: Variant = _read_careers_index(pid)
	if typeof(existing_index) == TYPE_DICTIONARY:
		var index: Dictionary = existing_index as Dictionary
		var active_id: String = str(index.get("active_career_id", "")).strip_edges()
		if active_id != "" and _career_exists_in_index(index, active_id) and FileAccess.file_exists(_career_save_path(pid, active_id)):
			return
		var first_existing: String = _find_first_existing_career_id(pid, index)
		if first_existing != "":
			index["active_career_id"] = first_existing
			_write_json(index_path, index)
			return
	elif FileAccess.file_exists(index_path):
		return

	var scanned_ids: Array[String] = _scan_existing_career_ids(pid)
	if scanned_ids.size() == 1:
		var scanned_save: Variant = _read_json(_career_save_path(pid, scanned_ids[0]))
		if typeof(scanned_save) == TYPE_DICTIONARY:
			var rebuilt: Dictionary = _empty_careers_index()
			rebuilt["active_career_id"] = scanned_ids[0]
			rebuilt["careers"] = [_career_entry_from_save(scanned_save as Dictionary, scanned_ids[0])]
			_write_json(index_path, rebuilt)
			return
	elif scanned_ids.size() > 1:
		return

	var source_path: String = _legacy_source_path(pid)
	var source_save: Dictionary = {}
	if source_path != "":
		var source_any: Variant = _read_json(source_path)
		if typeof(source_any) == TYPE_DICTIONARY:
			source_save = (source_any as Dictionary).duplicate(true)
	if source_save.is_empty():
		source_save = _default_save_dict(pid)

	var career_id: String = _generate_career_id(pid)
	_write_career_save(pid, career_id, source_save)

	var new_index: Dictionary = _empty_careers_index()
	new_index["active_career_id"] = career_id
	new_index["careers"] = [_career_entry_from_save(source_save, career_id)]
	_write_json(_careers_index_path(pid), new_index)

static func get_active_career_id() -> String:
	var pid: String = get_active_profile_id()
	_ensure_careers_for_profile(pid)
	var index_any: Variant = _read_careers_index(pid)
	if typeof(index_any) != TYPE_DICTIONARY:
		return ""
	var active_id: String = str((index_any as Dictionary).get("active_career_id", "")).strip_edges()
	if active_id != "" and FileAccess.file_exists(_career_save_path(pid, active_id)):
		return active_id
	return ""

static func get_active_career_save_path() -> String:
	var pid: String = get_active_profile_id()
	_ensure_careers_for_profile(pid)
	var index_any: Variant = _read_careers_index(pid)
	if typeof(index_any) != TYPE_DICTIONARY:
		var scanned_ids: Array[String] = _scan_existing_career_ids(pid)
		if scanned_ids.size() == 1:
			return _career_save_path(pid, scanned_ids[0])
		return _profile_path(pid)
	var index: Dictionary = index_any as Dictionary
	var active_id: String = str(index.get("active_career_id", "")).strip_edges()
	if active_id != "" and _career_exists_in_index(index, active_id) and FileAccess.file_exists(_career_save_path(pid, active_id)):
		return _career_save_path(pid, active_id)
	var first_existing: String = _find_first_existing_career_id(pid, index)
	if first_existing != "":
		index["active_career_id"] = first_existing
		_write_json(_careers_index_path(pid), index)
		return _career_save_path(pid, first_existing)
	return _profile_path(pid)

static func _hydrate_season_state_from_active_save() -> void:
	var tree := Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return
	var root := (tree as SceneTree).root
	if root == null:
		return
	var ss := root.get_node_or_null("/root/SeasonState")
	if ss == null or not ss.has_method("hydrate_from_save"):
		return
	var active_save: Variant = _read_json(get_active_career_save_path())
	if typeof(active_save) == TYPE_DICTIONARY:
		ss.call("hydrate_from_save", active_save as Dictionary)

static func ensure_exists() -> void:
	if not FileAccess.file_exists(PROFILES_FILE):
		var profiles: Dictionary = {
			"version": 1,
			"active_profile_id": "default",
			"profiles": [
				{"id": "default", "label": "Default"}
			],
			"created_at_unix": Time.get_unix_time_from_system()
		}
		_write_json(PROFILES_FILE, profiles)

		var dst: String = _profile_path("default")
		if FileAccess.file_exists(LEGACY_SAVE):
			_copy_file(LEGACY_SAVE, dst)
	_ensure_careers_for_profile(get_active_profile_id_no_ensure())

static func get_active_profile_id_no_ensure() -> String:
	var v: Variant = _read_json(PROFILES_FILE)
	if typeof(v) != TYPE_DICTIONARY:
		return "default"
	var d: Dictionary = v as Dictionary
	var pid: String = str(d.get("active_profile_id", "default")).strip_edges()
	if pid == "":
		pid = "default"
	return pid

static func get_active_profile_id() -> String:
	ensure_exists()
	return get_active_profile_id_no_ensure()

static func get_current_profile_id() -> String:
	return get_active_profile_id()

static func _set_active_profile_id(profile_id: String) -> void:
	ensure_exists()
	var v: Variant = _read_json(PROFILES_FILE)
	var d: Dictionary = {} if typeof(v) != TYPE_DICTIONARY else (v as Dictionary)
	if d.is_empty():
		d = {"version": 1, "profiles": [], "created_at_unix": Time.get_unix_time_from_system()}
	d["active_profile_id"] = _sanitize_path_id(profile_id)
	_write_json(PROFILES_FILE, d)

static func flush_active_to_profile_file() -> void:
	_ensure_careers_for_profile(get_active_profile_id())

static func activate_profile(profile_id: String) -> void:
	var new_id: String = _sanitize_path_id(profile_id)

	ensure_exists()

	var current_id: String = get_active_profile_id()
	if new_id == current_id:
		_ensure_careers_for_profile(new_id)
		_set_active_profile_id(new_id)
		_hydrate_season_state_from_active_save()
		return

	flush_active_to_profile_file()
	_ensure_careers_for_profile(new_id)
	_set_active_profile_id(new_id)
	_hydrate_season_state_from_active_save()

static func reset_active_profile() -> void:
	ensure_exists()
	var pid: String = get_active_profile_id()
	var fresh: Dictionary = _default_save_dict(pid)
	var career_id: String = get_active_career_id()
	if career_id == "":
		_ensure_careers_for_profile(pid)
		career_id = get_active_career_id()
	if career_id != "":
		fresh["career_id"] = career_id
		_write_json(_career_save_path(pid, career_id), fresh)
	_hydrate_season_state_from_active_save()


static func add_profile(profile_id: String, label: String = "") -> void:
	ensure_exists()
	var pid: String = _sanitize_path_id(profile_id)

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
	return {
		"version": 1,
		"profile_id": _sanitize_path_id(profile_id),
		"team_name": "",
		"league_id": FALLBACK_LEAGUE_ID,
		"intro_popup_first_match_seen": false,
		"early_flow_stadium_unlocked": false,
		"stadium_intro_seen": false,
		"season_number": 1,
		"season_round": 0,
		"club": {"name": "BM Club", "level": 1, "xp": 0},
		"club_xp_total_migrated": true,
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
