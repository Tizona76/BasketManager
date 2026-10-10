# res://scripts/PlayerLife.gd
extends RefCounted

const FATIGUE_MIN := 0
const FATIGUE_MAX := 100
const MOTIV_MIN := 0
const MOTIV_MAX := 100

# ---- Réglages “type .py” (à affiner ensuite) ----
const FATIGUE_GAIN_PLAY := 12        # +fatigue si joueur a joué
const FATIGUE_RECOVER_REST := 10     # -fatigue si joueur n'a pas joué
const MOTIV_WIN_GAIN := 4
const MOTIV_LOSS_DROP := 4
const MOTIV_REST_GAIN := 1
const BM_MERCATO_ID_DEBUG := true

# Blessure: probabilité augmente avec fatigue haute + endurance basse
const INJURY_BASE_PCT := 1.0         # % mini
const INJURY_FATIGUE_FACTOR := 0.10  # +0.10% par point de fatigue
const INJURY_ENDURANCE_FACTOR := 0.35 # -0.35% par point d'endurance (si endurance élevée)
const CONVAL_MIN := 1
const CONVAL_MAX := 4
const CLUB_IDENTITY_MAX_BADGE_LEVEL := 3
const CLUB_IDENTITY_BASE_BADGE_IDS := [
	"starter_crest_01",
	"starter_crest_02",
	"starter_crest_03",
	"starter_crest_04",
	"starter_crest_05",
	"starter_crest_06"
]
const CLUB_IDENTITY_SWITCH_COST := {
	1: 6,
	2: 18,
	3: 33
}
const CLUB_IDENTITY_UPGRADE_COST := {
	1: 8,
	2: 32
}
const CLUB_IDENTITY_SWITCH_UPGRADE_ADJUSTMENT := {
	1: 14,
	2: 15
}
const CLUB_BADGE_ACTION_SWITCH := "switch"
const CLUB_BADGE_ACTION_UPGRADE := "upgrade"
const CLUB_BADGE_ACTION_SWITCH_UPGRADE := "switch_upgrade"

static func _bm_sanitize_save_id(raw_id: String) -> String:
	var clean: String = str(raw_id).strip_edges()
	if clean == "":
		clean = "default"
	clean = clean.replace("/", "_").replace("\\", "_").replace("..", "_").replace(" ", "_")
	return clean

static func _bm_profile_save_path(profile_id: String) -> String:
	return "user://save_%s.json" % _bm_sanitize_save_id(profile_id)

static func _bm_career_index_path(profile_id: String) -> String:
	return "user://careers_%s.json" % _bm_sanitize_save_id(profile_id)

static func _bm_career_save_path(profile_id: String, career_id: String) -> String:
	return "user://save_%s_%s.json" % [_bm_sanitize_save_id(profile_id), _bm_sanitize_save_id(career_id)]

static func _bm_read_json_no_write(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		return null
	return json.data

static func _bm_resolve_from_career_index(profile_id: String) -> String:
	var parsed: Variant = _bm_read_json_no_write(_bm_career_index_path(profile_id))
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var index: Dictionary = parsed as Dictionary
	var active_id: String = str(index.get("active_career_id", "")).strip_edges()
	if active_id == "" or typeof(index.get("careers")) != TYPE_ARRAY:
		return ""
	for raw_entry in index["careers"]:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		if str((raw_entry as Dictionary).get("career_id", "")).strip_edges() != active_id:
			continue
		var career_path: String = _bm_career_save_path(profile_id, active_id)
		if FileAccess.file_exists(career_path):
			return career_path
	return ""

static func _resolve_save_path(path: String = "user://savegame.json") -> String:
	if path != "user://savegame.json":
		return path

	var tree := Engine.get_main_loop()
	if tree != null and tree is SceneTree:
		var root := (tree as SceneTree).root
		if root != null:
			var pm_node := root.get_node_or_null("/root/ProfileManager")
			if pm_node != null:
				if pm_node.has_method("get_active_career_save_path"):
					var career_path := str(pm_node.call("get_active_career_save_path")).strip_edges()
					if career_path != "":
						return career_path
				if pm_node.has_method("get_active_profile_id"):
					var pid := str(pm_node.call("get_active_profile_id")).strip_edges()
					var indexed_path := _bm_resolve_from_career_index(pid)
					if indexed_path != "":
						return indexed_path
					if pid != "":
						return _bm_profile_save_path(pid)
				if pm_node.has_method("get_current_profile_id"):
					var pid2 := str(pm_node.call("get_current_profile_id")).strip_edges()
					var indexed_path2 := _bm_resolve_from_career_index(pid2)
					if indexed_path2 != "":
						return indexed_path2
					if pid2 != "":
						return _bm_profile_save_path(pid2)

	var profiles_path := "user://profiles.json"
	var parsed_profiles: Variant = _bm_read_json_no_write(profiles_path)
	if typeof(parsed_profiles) == TYPE_DICTIONARY:
		var d: Dictionary = parsed_profiles as Dictionary
		var pid_file := str(d.get("active_profile_id", "")).strip_edges()
		if pid_file != "":
			var indexed_path_file := _bm_resolve_from_career_index(pid_file)
			if indexed_path_file != "":
				return indexed_path_file
			return _bm_profile_save_path(pid_file)

	return path

static func _bm_debug_dump_active_save_path() -> void:
	var resolved := _resolve_save_path("user://savegame.json")
	print("[DEBUG SAVE PATH] resolved=", resolved)

static func _bm_save_debug_active_profile_id() -> String:
	var tree := Engine.get_main_loop()
	if tree != null and tree is SceneTree:
		var root := (tree as SceneTree).root
		if root != null:
			var pm_node := root.get_node_or_null("/root/ProfileManager")
			if pm_node != null:
				if pm_node.has_method("get_active_profile_id"):
					var pid := str(pm_node.call("get_active_profile_id")).strip_edges()
					if pid != "":
						return pid
				if pm_node.has_method("get_current_profile_id"):
					var pid2 := str(pm_node.call("get_current_profile_id")).strip_edges()
					if pid2 != "":
						return pid2

	var profiles_path := "user://profiles.json"
	if FileAccess.file_exists(profiles_path):
		var f := FileAccess.open(profiles_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed as Dictionary
				return str(d.get("active_profile_id", "")).strip_edges()
	return ""

static func _bm_save_debug_caller() -> String:
	var stack := get_stack()
	for frame in stack:
		if typeof(frame) != TYPE_DICTIONARY:
			continue
		var fn := str((frame as Dictionary).get("function", ""))
		if fn == "" or fn.begins_with("_bm_save_debug") or fn == "load_savegame":
			continue
		var src := str((frame as Dictionary).get("source", ""))
		var line := int((frame as Dictionary).get("line", 0))
		return "%s:%d:%s" % [src, line, fn]
	return "unknown"

static func _bm_save_debug_player(save: Dictionary, wanted_id: int) -> void:
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var found: Dictionary = {}
	for raw_key in by_id.keys():
		var sid := str(raw_key).strip_edges()
		if sid == "":
			continue
		if int(round(float(sid))) != wanted_id:
			continue
		var candidate = by_id[raw_key]
		if typeof(candidate) == TYPE_DICTIONARY:
			found = candidate as Dictionary
		break
	if found.is_empty():
		return
	print(
		"[BM_SAVE_DEBUG] PLAYER_%d id=%s nom=%s name=%s avatar_key=%s avatar_path=%s mercato_generated=%s" %
		[
			wanted_id,
			str(found.get("id", "")),
			str(found.get("nom", "")),
			str(found.get("name", "")),
			str(found.get("avatar_key", "")),
			str(found.get("avatar_path", "")),
			str(found.get("mercato_generated", ""))
		]
	)

static func load_savegame(path: String = "user://savegame.json") -> Dictionary:
	path = _resolve_save_path(path)
	print(
		"[BM_SAVE_DEBUG] LOAD_SAVE path=%s global_path=%s profile=%s project=%s file=%s caller=%s" %
		[
			path,
			ProjectSettings.globalize_path(path),
			_bm_save_debug_active_profile_id(),
			str(ProjectSettings.get_setting("application/config/name", "")),
			path.get_file(),
			_bm_save_debug_caller()
		]
	)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	print("[BM_SAVE_DEBUG] FILE_HASH hash=", txt.sha256_text())
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var save: Dictionary = parsed as Dictionary
	if save.has("l5_match"):
		return save # L5 reads must not repair or publish implicitly.
	_bm_save_debug_player(save, 1006)
	_bm_save_debug_player(save, 1007)
	var had_legacy_wallet: bool = save.has("wallet") and typeof(save["wallet"]) != TYPE_DICTIONARY
	ensure_progression_wallet_schema(save)
	# Les réparations contractuelles restent explicites, jamais déclenchées par une lecture.
	var repaired_identity: bool = _repair_duplicate_player_identities_on_load(save)
	var repaired_incomplete_mercato_identity: bool = _repair_incomplete_mercato_identities_on_load(save)
	var repaired_lineup_duration := ensure_paid_lineup_duration(save)
	if had_legacy_wallet or repaired_identity or repaired_incomplete_mercato_identity or repaired_lineup_duration:
		write_savegame(save, path)
	return save

static func ensure_paid_lineup_duration(save: Dictionary) -> bool:
	if typeof(save.get("roster")) != TYPE_DICTIONARY:
		return false
	var roster: Dictionary = save["roster"]
	var paid := bool(roster.get("auto_save_match_selection_paid", false))
	# Legacy paid saves receive five matches once; load persists this migration.
	var remaining := maxi(0, int(roster.get("auto_save_match_selection_matches_left", 5))) if paid else 0
	var changed := not roster.has("auto_save_match_selection_matches_left") or int(roster["auto_save_match_selection_matches_left"]) != remaining
	roster["auto_save_match_selection_matches_left"] = remaining
	if paid and remaining == 0:
		roster["auto_save_match_selection_paid"] = false
		roster["match_selected_ids"] = []
		changed = true
	return changed

static func consume_paid_lineup_match(save: Dictionary) -> void:
	ensure_paid_lineup_duration(save)
	if typeof(save.get("roster")) != TYPE_DICTIONARY:
		return
	var roster: Dictionary = save["roster"]
	if not bool(roster.get("auto_save_match_selection_paid", false)):
		return
	var remaining := maxi(0, int(roster["auto_save_match_selection_matches_left"]) - 1)
	roster["auto_save_match_selection_matches_left"] = remaining
	if remaining == 0:
		roster["auto_save_match_selection_paid"] = false
		roster["match_selected_ids"] = []

static func write_savegame(data: Dictionary, path: String = "user://savegame.json") -> void:
	path = _resolve_save_path(path)
	ensure_progression_wallet_schema(data)
	if not _l5_legacy_write_allowed(path, data):
		push_error("L5: stale or pending career write refused")
		return
	if _l5_publish_existing(path, data): return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

static func _repair_corrupted_salaries_on_load(save: Dictionary) -> void:
	# Compatibilité : récupération explicite depuis un contrat annuel déjà enregistré.
	# Ne jamais remplacer un montant présent ni reconstruire depuis une note.
	if not save.get("players_by_id") is Dictionary:
		return
	var index := _l2_sport_index(save.players_by_id)
	var copies: Array = []
	if save.get("players") is Array: copies.append_array(save.players)
	if save.get("roster") is Dictionary and save.roster.get("players") is Array:
		copies.append_array(save.roster.players)
	for key in index:
		var player: Dictionary = save.players_by_id[index[key]]
		if player.has("salaire") or player.has("salary"):
			continue
		var amount: Variant = null
		var conflict := false
		for row in copies:
			if not row is Dictionary or _l3_license_id(row.get("id")) != key:
				continue
			var contract := _l4_annual_contract(row)
			if contract.status != "OK":
				conflict = true
			elif amount != null and amount != contract.annual:
				conflict = true
			else:
				amount = contract.annual
		if amount != null and not conflict:
			player["salaire"] = amount

static func clampi(v: int, a: int, b: int) -> int:
	return int(clamp(v, a, b))


static func _ensure_club_schema(save: Dictionary) -> void:
	if save == null:
		return
	if not save.has("club") or typeof(save["club"]) != TYPE_DICTIONARY:
		save["club"] = {}
	var club: Dictionary = save["club"] as Dictionary
	club["name"] = str(club.get("name", save.get("team_name", "BM Club"))).strip_edges()
	if club["name"] == "":
		club["name"] = "BM Club"
	club["level"] = maxi(1, int(club.get("level", save.get("club_level", 1))))
	club["xp"] = maxi(0, int(club.get("xp", save.get("club_xp", 0))))


static func _ensure_wallet_schema(save: Dictionary) -> void:
	if save == null:
		return
	if not save.has("wallet"):
		save["wallet"] = {}
	elif typeof(save["wallet"]) != TYPE_DICTIONARY:
		var legacy_wallet := int(save["wallet"])
		save["wallet"] = {
			"euros": legacy_wallet,
			"tokens": 0
		}
		print("[FIX WALLET] converted legacy wallet=", legacy_wallet)
	var wallet: Dictionary = save["wallet"] as Dictionary
	wallet["euros"] = int(wallet.get("euros", 0))
	wallet["tokens"] = maxi(0, int(wallet.get("tokens", 0)))


static func _append_token_history(save: Dictionary, amount: int, reason: String) -> void:
	var delta := int(amount)
	if delta == 0:
		return
	if not save.has("token_history") or typeof(save["token_history"]) != TYPE_ARRAY:
		save["token_history"] = []
	var history: Array = save["token_history"] as Array
	var clean_reason := str(reason).strip_edges()
	history.append({
		"amount": delta,
		"reason": clean_reason,
		"reason_key": clean_reason,
		"created_at_unix": Time.get_unix_time_from_system()
	})
	if history.size() > 40:
		history = history.slice(history.size() - 40, history.size())
	save["token_history"] = history


static func _normalize_club_badge_id(badge_id: Variant) -> String:
	var raw := str(badge_id).strip_edges()
	if raw == "":
		return ""
	var idx_txt := raw.replace("starter_crest_", "")
	if not idx_txt.is_valid_int():
		return ""
	var idx := int(idx_txt)
	if idx <= 0:
		return ""
	return "starter_crest_%02d" % idx


static func _legacy_club_badge_id(save: Dictionary) -> String:
	var cid := _normalize_club_badge_id(save.get("club_crest_id", save.get("selected_crest_id", "")))
	if cid == "" and save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		cid = _normalize_club_badge_id((save["roster"] as Dictionary).get("selected_crest_id", ""))
	return cid


static func _sync_legacy_club_crest_fields(save: Dictionary) -> void:
	if not save.has("club_identity") or typeof(save["club_identity"]) != TYPE_DICTIONARY:
		return
	var identity: Dictionary = save["club_identity"] as Dictionary
	var equipped := _normalize_club_badge_id(identity.get("equipped_badge_id", ""))
	if equipped == "":
		return
	var levels: Dictionary = {}
	if identity.has("badge_levels") and typeof(identity["badge_levels"]) == TYPE_DICTIONARY:
		levels = identity["badge_levels"] as Dictionary
	var level := clampi(int(levels.get(equipped, save.get("club_crest_level", 1))), 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	save["club_crest_id"] = equipped
	save["selected_crest_id"] = equipped
	save["club_crest_level"] = level
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		(save["roster"] as Dictionary)["selected_crest_id"] = equipped
	if save.has("team_crest_map") and typeof(save["team_crest_map"]) == TYPE_DICTIONARY:
		var team_crest_map := save["team_crest_map"] as Dictionary
		var team_name := str(save.get("team_name", "")).strip_edges()
		var club_name := str(save.get("club_name", "")).strip_edges()
		if team_name != "":
			team_crest_map[team_name] = equipped
		if club_name != "":
			team_crest_map[club_name] = equipped


static func _ensure_club_identity_schema(save: Dictionary) -> void:
	if save == null:
		return
	var equipped := _legacy_club_badge_id(save)

	var legacy_level := clampi(int(save.get("club_crest_level", 1)), 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	var identity: Dictionary = {}
	if save.has("club_identity") and typeof(save["club_identity"]) == TYPE_DICTIONARY:
		identity = save["club_identity"] as Dictionary

	var current_equipped := _normalize_club_badge_id(identity.get("equipped_badge_id", ""))
	if current_equipped != "":
		equipped = current_equipped

	var owned: Array = []
	if identity.has("owned_badges") and typeof(identity["owned_badges"]) == TYPE_ARRAY:
		for raw_badge in identity["owned_badges"] as Array:
			var bid := _normalize_club_badge_id(raw_badge)
			if bid != "" and not owned.has(bid):
				owned.append(bid)
	if equipped == "" and owned.is_empty():
		identity["equipped_badge_id"] = ""
		identity["owned_badges"] = []
		identity["badge_levels"] = {}
		save["club_identity"] = identity
		return
	if equipped == "" and not owned.is_empty():
		equipped = str(owned[0])
	if not owned.has(equipped):
		owned.append(equipped)

	var levels: Dictionary = {}
	if identity.has("badge_levels") and typeof(identity["badge_levels"]) == TYPE_DICTIONARY:
		for key in (identity["badge_levels"] as Dictionary).keys():
			var bid2 := _normalize_club_badge_id(key)
			if bid2 == "":
				continue
			levels[bid2] = clampi(int((identity["badge_levels"] as Dictionary).get(key, 1)), 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	for bid3 in owned:
		if not levels.has(bid3):
			levels[bid3] = legacy_level if bid3 == equipped else 1

	identity["equipped_badge_id"] = equipped
	identity["owned_badges"] = owned
	identity["badge_levels"] = levels
	save["club_identity"] = identity
	_sync_legacy_club_crest_fields(save)


static func ensure_progression_wallet_schema(save: Dictionary) -> void:
	_ensure_club_schema(save)
	_ensure_wallet_schema(save)
	_ensure_club_identity_schema(save)

	# --- COACHS SCHEMA ---
	if not save.has("coachs") or typeof(save["coachs"]) != TYPE_DICTIONARY:
		save["coachs"] = {
			"owned": [],
			"active": "",
			"last_hired_season": 0
		}


const CLUB_LEVEL_XP_FLOORS: Dictionary = {
	1: 0,
	2: 350,
	3: 800,
	4: 1350,
	5: 2000,
	6: 2750,
}
const CLUB_STAFF_INTRO_SEEN_KEY := "club_staff_intro_seen"
const CLUB_STAFF_INTRO_PENDING_KEY := "club_staff_intro_pending"


static func _get_level_floor_xp(level: int) -> int:
	var lv := maxi(1, int(level))
	if CLUB_LEVEL_XP_FLOORS.has(lv):
		return int(CLUB_LEVEL_XP_FLOORS[lv])
	return int(CLUB_LEVEL_XP_FLOORS[6])


static func _get_next_level_floor_xp(level: int) -> int:
	var lv := maxi(1, int(level))
	if CLUB_LEVEL_XP_FLOORS.has(lv + 1):
		return int(CLUB_LEVEL_XP_FLOORS[lv + 1])
	return int(CLUB_LEVEL_XP_FLOORS[6])


static func get_club_level_from_total_xp(total_xp: int) -> int:
	var xp := maxi(0, int(total_xp))
	if xp >= int(CLUB_LEVEL_XP_FLOORS[6]):
		return 6
	if xp >= int(CLUB_LEVEL_XP_FLOORS[5]):
		return 5
	if xp >= int(CLUB_LEVEL_XP_FLOORS[4]):
		return 4
	if xp >= int(CLUB_LEVEL_XP_FLOORS[3]):
		return 3
	if xp >= int(CLUB_LEVEL_XP_FLOORS[2]):
		return 2
	return 1


static func _migrate_club_xp_to_total_if_needed(save: Dictionary) -> void:
	ensure_progression_wallet_schema(save)
	if bool(save.get("club_xp_total_migrated", false)):
		return

	var club: Dictionary = save["club"] as Dictionary
	var current_level := maxi(1, int(club.get("level", 1)))
	var current_xp := maxi(0, int(club.get("xp", 0)))

	club["xp"] = _get_level_floor_xp(current_level) + current_xp
	club["level"] = get_club_level_from_total_xp(int(club["xp"]))
	save["club_xp_total_migrated"] = true


static func sync_club_level_from_xp(save: Dictionary) -> void:
	ensure_progression_wallet_schema(save)
	_migrate_club_xp_to_total_if_needed(save)
	var club: Dictionary = save["club"] as Dictionary
	club["xp"] = maxi(0, int(club.get("xp", 0)))
	club["level"] = get_club_level_from_total_xp(int(club["xp"]))


static func get_club_level(save: Dictionary) -> int:
	ensure_progression_wallet_schema(save)
	sync_club_level_from_xp(save)
	return maxi(1, int((save["club"] as Dictionary).get("level", 1)))


static func get_club_xp(save: Dictionary) -> int:
	ensure_progression_wallet_schema(save)
	_migrate_club_xp_to_total_if_needed(save)
	return maxi(0, int((save["club"] as Dictionary).get("xp", 0)))


static func get_club_identity_badge_ids() -> Array[String]:
	var out: Array[String] = []
	for bid in CLUB_IDENTITY_BASE_BADGE_IDS:
		out.append(str(bid))
	return out


static func get_club_identity(save: Dictionary) -> Dictionary:
	ensure_progression_wallet_schema(save)
	return (save["club_identity"] as Dictionary).duplicate(true)


static func get_equipped_club_badge_id(save: Dictionary) -> String:
	ensure_progression_wallet_schema(save)
	return _normalize_club_badge_id((save["club_identity"] as Dictionary).get("equipped_badge_id", ""))


static func is_club_badge_owned(save: Dictionary, badge_id: String) -> bool:
	ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return false
	var owned: Array = (save["club_identity"] as Dictionary).get("owned_badges", []) as Array
	return owned.has(bid)


static func get_club_badge_level(save: Dictionary, badge_id: String) -> int:
	ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return 1
	var levels: Dictionary = (save["club_identity"] as Dictionary).get("badge_levels", {}) as Dictionary
	return clampi(int(levels.get(bid, 1)), 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)


static func get_base_badge_unlock_cost(_badge_id: String = "") -> int:
	return get_badge_action_cost({}, _badge_id, CLUB_BADGE_ACTION_SWITCH)


static func get_club_badge_upgrade_cost(save: Dictionary, badge_id: String) -> int:
	return get_badge_action_cost(save, badge_id, CLUB_BADGE_ACTION_UPGRADE)


static func get_badge_action_cost(save: Dictionary, badge_id: String, action: String) -> int:
	if not save.is_empty():
		ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return 0
	var equipped := ""
	var current_level := 1
	if not save.is_empty():
		equipped = get_equipped_club_badge_id(save)
		current_level = get_club_badge_level(save, equipped if equipped != "" else bid)
	current_level = clampi(current_level, 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	match action:
		CLUB_BADGE_ACTION_SWITCH:
			if equipped != "" and bid == equipped:
				return 0
			return maxi(0, int(CLUB_IDENTITY_SWITCH_COST.get(current_level, 0)))
		CLUB_BADGE_ACTION_UPGRADE:
			if current_level >= CLUB_IDENTITY_MAX_BADGE_LEVEL:
				return 0
			return maxi(0, int(CLUB_IDENTITY_UPGRADE_COST.get(current_level, 0)))
		CLUB_BADGE_ACTION_SWITCH_UPGRADE:
			if current_level >= CLUB_IDENTITY_MAX_BADGE_LEVEL:
				return 0
			var switch_cost := 0 if (equipped != "" and bid == equipped) else maxi(0, int(CLUB_IDENTITY_SWITCH_COST.get(current_level, 0)))
			var upgrade_cost := maxi(0, int(CLUB_IDENTITY_UPGRADE_COST.get(current_level, 0)))
			var adjustment := 0 if switch_cost <= 0 else maxi(0, int(CLUB_IDENTITY_SWITCH_UPGRADE_ADJUSTMENT.get(current_level, 0)))
			return switch_cost + upgrade_cost + adjustment
	return 0


static func apply_club_badge_action(save: Dictionary, badge_id: String, action: String) -> bool:
	ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return false
	var equipped := get_equipped_club_badge_id(save)
	if equipped == "":
		equipped = bid
	var current_level := clampi(get_club_badge_level(save, equipped), 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	var target_level := current_level
	if action == CLUB_BADGE_ACTION_UPGRADE or action == CLUB_BADGE_ACTION_SWITCH_UPGRADE:
		if current_level >= CLUB_IDENTITY_MAX_BADGE_LEVEL:
			return false
		target_level = current_level + 1
	var cost := get_badge_action_cost(save, bid, action)
	if cost > 0 and not spend_tokens(save, cost, "club_badge_" + action):
		return false
	var identity: Dictionary = save["club_identity"] as Dictionary
	var owned: Array = identity.get("owned_badges", []) as Array
	if not owned.has(bid):
		owned.append(bid)
	identity["owned_badges"] = owned
	var levels: Dictionary = identity.get("badge_levels", {}) as Dictionary
	levels[bid] = clampi(target_level, 1, CLUB_IDENTITY_MAX_BADGE_LEVEL)
	identity["badge_levels"] = levels
	identity["equipped_badge_id"] = bid
	save["club_identity"] = identity
	_sync_legacy_club_crest_fields(save)
	return true


static func get_club_badge_texture_path(save: Dictionary, badge_id: String) -> String:
	ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return ""
	return get_club_badge_texture_path_for_level(bid, get_club_badge_level(save, bid))


static func get_club_badge_texture_path_for_level(badge_id: String, level: int) -> String:
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return ""
	var idx := int(bid.replace("starter_crest_", ""))
	if idx <= 0:
		return ""
	if level >= 3:
		var lv3_path := "res://assets/images/blasons/blason_%d_lv3.png" % idx
		if ResourceLoader.exists(lv3_path):
			return lv3_path
	if level >= 2:
		var lv2_path := "res://assets/images/blasons/blason_%d_lv2.png" % idx
		if ResourceLoader.exists(lv2_path):
			return lv2_path
	var base_path := "res://assets/images/blasons/blason_%d.png" % idx
	if ResourceLoader.exists(base_path):
		return base_path
	return ""


static func equip_club_badge(save: Dictionary, badge_id: String) -> bool:
	ensure_progression_wallet_schema(save)
	var bid := _normalize_club_badge_id(badge_id)
	if bid == "":
		return false
	if not is_club_badge_owned(save, bid):
		return false
	(save["club_identity"] as Dictionary)["equipped_badge_id"] = bid
	_sync_legacy_club_crest_fields(save)
	return true


static func unlock_club_badge(save: Dictionary, badge_id: String) -> bool:
	return apply_club_badge_action(save, badge_id, CLUB_BADGE_ACTION_SWITCH)


static func upgrade_club_badge(save: Dictionary, badge_id: String) -> bool:
	return apply_club_badge_action(save, badge_id, CLUB_BADGE_ACTION_UPGRADE)



static func get_display_crest_path(save: Dictionary, team_name: String) -> String:
	ensure_progression_wallet_schema(save)
	var tn: String = team_name.strip_edges()
	var my_team: String = str(save.get("team_name", save.get("club_name", ""))).strip_edges()
	var cid: String = ""

	if tn != "" and save.has("team_crest_map") and typeof(save["team_crest_map"]) == TYPE_DICTIONARY:
		var m: Dictionary = save["team_crest_map"] as Dictionary
		cid = str(m.get(tn, "")).strip_edges()

	if cid == "":
		cid = str(save.get("club_crest_id", save.get("selected_crest_id", ""))).strip_edges()
		if cid == "" and save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
			cid = str((save["roster"] as Dictionary).get("selected_crest_id", "")).strip_edges()

	var idx: int = int(cid.replace("starter_crest_", ""))
	if idx <= 0:
		return ""

	var is_my_team: bool = (tn == "" or tn == my_team)
	var current_season: int = maxi(1, int(save.get("season_number", 1)))
	var winner_until: int = int(save.get("club_season_winner_badge_until_season", 0))

	if is_my_team and idx <= 6 and winner_until == current_season:
		var winner_path: String = "res://assets/images/blasons/blason_%d_winner.png" % idx
		if ResourceLoader.exists(winner_path):
			return winner_path

	if is_my_team and idx <= 6 and bool(save.get("club_has_tournament_cup_crest", false)):
		var cup_path: String = "res://assets/images/blasons/blason_%d_cup.png" % idx
		if ResourceLoader.exists(cup_path):
			return cup_path

	var crest_level: int = get_club_badge_level(save, cid) if is_my_team else int(save.get("club_crest_level", 1))

	if is_my_team and crest_level >= 3:
		var lv3_path: String = "res://assets/images/blasons/blason_%d_lv3.png" % idx
		if ResourceLoader.exists(lv3_path):
			return lv3_path

	if is_my_team and crest_level >= 2:
		var lv2_path: String = "res://assets/images/blasons/blason_%d_lv2.png" % idx
		if ResourceLoader.exists(lv2_path):
			return lv2_path

	var base_path: String = "res://assets/images/blasons/blason_%d.png" % idx
	if ResourceLoader.exists(base_path):
		return base_path

	return ""



static func is_coachs_unlocked(save: Dictionary) -> bool:
	ensure_progression_wallet_schema(save)
	var club_level: int = get_club_level(save)
	var season_number: int = maxi(1, int(save.get("season_number", 1)))
	return club_level >= 2 or season_number >= 3


static func get_tokens(save: Dictionary) -> int:
	ensure_progression_wallet_schema(save)
	return maxi(0, int((save["wallet"] as Dictionary).get("tokens", 0)))


static func get_xp_to_next_level(level: int) -> int:
	var lv := maxi(1, int(level))
	var cur_floor := _get_level_floor_xp(lv)
	var next_floor := _get_next_level_floor_xp(lv)
	return maxi(0, next_floor - cur_floor)


static func add_club_xp(save: Dictionary, amount: int, reason: String = "") -> Dictionary:
	ensure_progression_wallet_schema(save)
	_migrate_club_xp_to_total_if_needed(save)

	var club: Dictionary = save["club"] as Dictionary
	var level_before := get_club_level_from_total_xp(maxi(0, int(club.get("xp", 0))))
	var xp_add := maxi(0, int(amount))
	club["xp"] = maxi(0, int(club.get("xp", 0))) + xp_add
	club["level"] = get_club_level_from_total_xp(int(club["xp"]))
	var level_after := int(club["level"])
	if level_before < 2 and level_after >= 2 and not bool(save.get(CLUB_STAFF_INTRO_SEEN_KEY, false)):
		save[CLUB_STAFF_INTRO_PENDING_KEY] = true
	save["season_xp_earned"] = maxi(0, int(save.get("season_xp_earned", 0))) + xp_add

	if reason != "":
		print("[ECON][XP] +", xp_add, " reason=", reason, " => level=", int(club["level"]), " xp_total=", int(club["xp"]))
	return save


static func can_spend_tokens(save: Dictionary, amount: int) -> bool:
	return get_tokens(save) >= maxi(0, int(amount))


static func spend_tokens(save: Dictionary, amount: int, reason: String = "") -> bool:
	ensure_progression_wallet_schema(save)
	var spend := maxi(0, int(amount))
	if spend <= 0:
		return true
	var wallet: Dictionary = save["wallet"] as Dictionary
	var cur := maxi(0, int(wallet.get("tokens", 0)))
	if cur < spend:
		return false
	wallet["tokens"] = cur - spend
	save["wallet"] = wallet
	_append_token_history(save, -spend, reason)
	if reason != "":
		print("[ECON][TOKENS] -", spend, " reason=", reason, " => tokens=", int(wallet["tokens"]))
	return true


static func add_tokens(save: Dictionary, amount: int, reason: String = "") -> Dictionary:
	ensure_progression_wallet_schema(save)
	var gain := maxi(0, int(amount))
	if gain <= 0:
		return save
	var wallet: Dictionary = save["wallet"] as Dictionary
	wallet["tokens"] = maxi(0, int(wallet.get("tokens", 0))) + gain
	save["season_tokens_earned"] = maxi(0, int(save.get("season_tokens_earned", 0))) + gain
	_append_token_history(save, gain, reason)
	if reason != "":
		print("[ECON][TOKENS] +", gain, " reason=", reason, " => tokens=", int(wallet["tokens"]), " season_tokens_earned=", int(save["season_tokens_earned"]))
	return save


static func spend_euros_or_tokens(save: Dictionary, euros_cost: int, tokens_cost: int, reason: String = "") -> bool:
	ensure_progression_wallet_schema(save)

	var euros_needed: int = maxi(0, int(euros_cost))
	var tokens_needed: int = maxi(0, int(tokens_cost))

	var wallet: Dictionary = save["wallet"] as Dictionary
	var euros_have: int = maxi(0, int(wallet.get("euros", 0)))
	var tokens_have: int = maxi(0, int(wallet.get("tokens", 0)))

	if euros_have >= euros_needed and (euros_needed > 0 or tokens_needed == 0):
		wallet["euros"] = euros_have - euros_needed
		if reason != "":
			print("[ECON][EUROS] -", euros_needed, " reason=", reason, " => euros=", int(wallet["euros"]))
		return true

	if euros_needed <= 0:
		if tokens_have < tokens_needed:
			return false
		wallet["tokens"] = tokens_have - tokens_needed
		_append_token_history(save, -tokens_needed, reason)
		if reason != "":
			print("[ECON][TOKENS] -", tokens_needed, " reason=", reason, " => tokens=", int(wallet["tokens"]))
		return true

	var euros_missing: int = euros_needed - euros_have
	var tokens_extra_for_missing: int = 0
	if euros_cost > 0 and tokens_cost > 0:
		tokens_extra_for_missing = int(ceil(float(euros_missing) * float(tokens_cost) / float(euros_cost)))
	else:
		return false

	var tokens_total_needed: int = tokens_needed + tokens_extra_for_missing
	if tokens_have < tokens_total_needed:
		return false

	wallet["euros"] = 0
	wallet["tokens"] = tokens_have - tokens_total_needed
	_append_token_history(save, -tokens_total_needed, reason)
	if reason != "":
		print("[ECON][MIX] euros=-", euros_have, " tokens=-", tokens_total_needed, " reason=", reason, " => tokens=", int(wallet["tokens"]))
	return true


static func can_afford_coach(save: Dictionary, euros_cost: int, tokens_cost: int) -> bool:
	ensure_progression_wallet_schema(save)

	var wallet: Dictionary = save["wallet"] as Dictionary
	var euros_have: int = maxi(0, int(wallet.get("euros", 0)))
	var tokens_have: int = maxi(0, int(wallet.get("tokens", 0)))

	var euros_needed: int = maxi(0, int(euros_cost))
	var tokens_needed: int = maxi(0, int(tokens_cost))

	if euros_have >= euros_needed and (euros_needed > 0 or tokens_needed == 0):
		return true

	if euros_needed <= 0:
		return tokens_have >= tokens_needed

	if euros_cost <= 0 or tokens_cost <= 0:
		return false

	var euros_missing: int = euros_needed - euros_have
	var tokens_extra_for_missing: int = int(ceil(float(euros_missing) * float(tokens_cost) / float(euros_cost)))
	var tokens_total_needed: int = tokens_needed + tokens_extra_for_missing
	return tokens_have >= tokens_total_needed


static func register_coach_purchase(save: Dictionary, coach_id: String) -> Dictionary:
	ensure_progression_wallet_schema(save)

	var cid: String = str(coach_id).strip_edges()
	if cid == "":
		return save

	var coachs: Dictionary = save["coachs"] as Dictionary
	var owned: Array = (coachs.get("owned", []) as Array).duplicate()
	if not owned.has(cid):
		owned.append(cid)
	coachs["owned"] = owned
	coachs["active"] = cid
	coachs["last_hired_season"] = maxi(1, int(save.get("season_number", 1)))
	save["coachs"] = coachs

	if save.has("missions_state") and typeof(save["missions_state"]) == TYPE_DICTIONARY:
		var ms: Dictionary = save["missions_state"] as Dictionary
		var counters: Dictionary = {}
		if ms.has("counters") and typeof(ms["counters"]) == TYPE_DICTIONARY:
			counters = ms["counters"] as Dictionary
		counters["coach_signed"] = maxi(0, int(counters.get("coach_signed", 0))) + 1
		ms["counters"] = counters
		save["missions_state"] = ms

	print("[COACHS] registered purchase coach_id=", cid, " active=", str(coachs["active"]))
	return save


static func buy_coach(save: Dictionary, coach_id: String, euros_cost: int = -1, tokens_cost: int = -1, reason: String = "") -> bool:
	ensure_progression_wallet_schema(save)

	var cid: String = str(coach_id).strip_edges()
	if cid == "":
		return false

	var coachs: Dictionary = save["coachs"] as Dictionary
	var owned: Array = (coachs.get("owned", []) as Array)
	if owned.has(cid):
		return false

	var price_data: Dictionary = get_coach_price_data(cid)
	if price_data.is_empty():
		return false

	var euros_final: int = int(price_data.get("euros_cost", 0))
	var tokens_final: int = int(price_data.get("tokens_cost", 0))

	if euros_cost >= 0:
		euros_final = int(euros_cost)
	if tokens_cost >= 0:
		tokens_final = int(tokens_cost)

	if not can_afford_coach(save, euros_final, tokens_final):
		return false

	if not spend_euros_or_tokens(save, euros_final, tokens_final, reason):
		return false

	register_coach_purchase(save, cid)
	return true


static func get_coach_price_data(coach_id: String) -> Dictionary:
	var cid: String = str(coach_id).strip_edges()
	if cid == "":
		return {}

	var TD = load("res://scripts/TuningData.gd")
	if TD == null:
		return {}

	var staff: Dictionary = TD.STAFF_TUNING
	if not staff.has(cid):
		return {}

	var data: Dictionary = staff[cid] as Dictionary
	return {
		"id": cid,
		"label": str(data.get("label", cid)),
		"euros_cost": maxi(0, int(data.get("euros_cost", 0))),
		"tokens_cost": maxi(0, int(data.get("tokens_cost", 0)))
	}



# --- Finance/Popularité schema (clone logique .py) ---
# popularite: 0..100 (init 50)
# totaux cumulés: int (init 0)
static func ensure_finance_schema(save: Dictionary) -> void:
	if save == null:
		return
	ensure_progression_wallet_schema(save)

	if not save.has("popularite"):
		save["popularite"] = 50
	save["popularite"] = clampi(int(save["popularite"]), 30, 100)

	if not save.has("total_billetterie"):
		save["total_billetterie"] = 0
	if not save.has("total_boutique"):
		save["total_boutique"] = 0
	if not save.has("total_sponsors"):
		save["total_sponsors"] = 0
	if not save.has("total_tournois"):
		save["total_tournois"] = 0
	if not save.has("total_depenses"):
		save["total_depenses"] = 0
	if not save.has("total_recettes"):
		save["total_recettes"] = 0
	
	save["total_billetterie"] = int(save["total_billetterie"])
	save["total_boutique"] = int(save["total_boutique"])
	save["total_sponsors"] = int(save["total_sponsors"])
	save["total_tournois"] = int(save["total_tournois"])
	save["total_depenses"] = int(save["total_depenses"])
	save["total_recettes"] = int(save["total_recettes"])

	# Prévision uniquement : ne jamais réécrire les cumuls déjà enregistrés.
	var payroll := _l4_payroll(save)
	if payroll.status == "OK":
		save["salary_total_per_match"] = payroll.per_match

static func popularity_coef(save: Dictionary) -> float:
	# clone .py: coef = clamp(pop/100, 0.30..1.00)
	var pop := 50
	if save != null and save.has("popularite"):
		pop = int(save["popularite"])
	pop = clampi(pop, 30, 100)
	var coef := float(pop) / 100.0
	coef = clamp(coef, 0.30, 1.00)
	return coef

static func _ensure_player_schema(p: Dictionary) -> void:
	# attributs
	if not p.has("precision"): p["precision"] = 50
	if not p.has("tir"): p["tir"] = 50
	if not p.has("vitesse"): p["vitesse"] = 50
	if not p.has("force"): p["force"] = 50
	if not p.has("defense"): p["defense"] = 50
	if not p.has("endurance"): p["endurance"] = 50

	# état
	if not p.has("fatigue"): p["fatigue"] = 0
	if not p.has("motivation"): p["motivation"] = 50
	if not p.has("blessure"): p["blessure"] = false
	if not p.has("matches_conval"): p["matches_conval"] = 0

	# progression
	if not p.has("matchs_consecutifs"): p["matchs_consecutifs"] = 0
	if not p.has("repos_consecutifs"): p["repos_consecutifs"] = 0

	# calculés
	if not p.has("pct_2pts"): p["pct_2pts"] = 0
	if not p.has("pct_3pts"): p["pct_3pts"] = 0

static func _recalc_derived(p: Dictionary) -> void:
	_l2_refresh_rating(p)
	var fatigue := int(p["fatigue"])

	# %2pts / %3pts: “type .py” simplifié basé sur precision + fatigue
	# (valeurs en %)
	var prec := int(p["precision"])
	var tir := int(p["tir"])
	var pct2 := prec * 0.60 + tir * 0.30 + 10 - float(fatigue) * 0.15
	var pct3 := prec * 0.30 + tir * 0.50 + float(p["vitesse"]) * 0.10 - float(fatigue) * 0.12

	p["pct_2pts"] = clampi(int(round(pct2)), 25, 85)
	p["pct_3pts"] = clampi(int(round(pct3)), 15, 65)

	# Salaire: index simple basé sur pondération (à aligner plus tard sur ton .py)
	# salaire annuel conservé : ne pas écraser ici

static func _injury_roll(p: Dictionary, rng: RandomNumberGenerator) -> bool:
	# Pas de nouvelle blessure si déjà blessé
	if bool(p["blessure"]):
		return false

	var fatigue := float(p["fatigue"])
	var endu := float(p["endurance"])

	var pct := INJURY_BASE_PCT
	pct += fatigue * INJURY_FATIGUE_FACTOR
	pct -= endu * INJURY_ENDURANCE_FACTOR
	pct = clamp(pct, 0.2, 25.0) # plafond sécurité

	return rng.randf() < (pct / 100.0)

static func _normalize_player_id(v) -> String:
	var s := str(v).strip_edges()
	if s == "":
		return ""
	if s.is_valid_int():
		return str(int(s))
	return str(int(float(s)))

static func apply_post_match_to_save(save: Dictionary, played_ids: Array, did_win: bool, injury_seed: Variant = null) -> Dictionary:
	if save.is_empty():
		return save
	if not save.has("players_by_id"):
		return save
	if typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return save

	var players_by_id: Dictionary = save["players_by_id"]

	# Résolution stricte : aucune conversion d'un ID fractionnaire ou ambigu.
	var index := _l2_sport_index(players_by_id)
	var played_keys: Array = []
	for id in played_ids:
		var key := _l1_id_key(id)
		if index.has(key) and not played_keys.has(index[key]):
			played_keys.append(index[key])
	print("[POST_MATCH][PLAYED_IDS_RAW] ", played_ids)
	print("[POST_MATCH][PLAYED_KEYS] ", played_keys)

	var rng := RandomNumberGenerator.new()
	if injury_seed == null:
		rng.randomize()
	else:
		rng.seed = int(str(injury_seed))

	var touched := {}



	# 1) Joueurs ayant joué
	for key in played_keys:
		if not players_by_id.has(key):
			continue
		var p = players_by_id[key]
		if typeof(p) != TYPE_DICTIONARY:
			continue

		_ensure_player_schema(p)

		# Blessure / convalescence
		if bool(p["blessure"]):
			p["matches_conval"] = maxi(0, int(p["matches_conval"]) - 1)
			if int(p["matches_conval"]) <= 0:
				p["blessure"] = false
				p["matches_conval"] = 0

		# Joué => fatigue +
		p["fatigue"] = clampi(int(p["fatigue"]) + FATIGUE_GAIN_PLAY, FATIGUE_MIN, FATIGUE_MAX)
		p["matchs_consecutifs"] = int(p["matchs_consecutifs"]) + 1
		p["repos_consecutifs"] = 0

		if _injury_roll(p, rng):
			p["blessure"] = true
			p["matches_conval"] = rng.randi_range(CONVAL_MIN, CONVAL_MAX)

		p["motivation"] = clampi(
			int(p["motivation"]) + (MOTIV_WIN_GAIN if did_win else -MOTIV_LOSS_DROP),
			MOTIV_MIN, MOTIV_MAX
		)

		_recalc_derived(p)
		players_by_id[key] = p
		touched[key] = true

	# 2) Joueurs au repos
	for pid in players_by_id.keys():
		if touched.has(pid):
			continue
		var p = players_by_id[pid]
		if typeof(p) != TYPE_DICTIONARY:
			continue

		_ensure_player_schema(p)

		# Blessure / convalescence
		if bool(p["blessure"]):
			p["matches_conval"] = maxi(0, int(p["matches_conval"]) - 1)
			if int(p["matches_conval"]) <= 0:
				p["blessure"] = false
				p["matches_conval"] = 0

		# Repos => fatigue -
		p["fatigue"] = clampi(int(p["fatigue"]) - FATIGUE_RECOVER_REST, FATIGUE_MIN, FATIGUE_MAX)
		p["repos_consecutifs"] = int(p["repos_consecutifs"]) + 1
		p["matchs_consecutifs"] = 0
		p["motivation"] = clampi(int(p["motivation"]) + MOTIV_REST_GAIN, MOTIV_MIN, MOTIV_MAX)

		_recalc_derived(p)
		players_by_id[pid] = p

	save["players_by_id"] = players_by_id

	_l2_sync_sport_copies(save)

	return save



static func _mercato_scan_avatar_portraits(path: String) -> Array[String]:
	var out: Array[String] = []
	if BM_MERCATO_ID_DEBUG:
		print("[BM_MERCATO_ID_DEBUG] SCAN_START path=", path, " platform_or_features=", OS.get_name(), "|web=", OS.has_feature("web"), "|ios=", OS.has_feature("ios"), "|android=", OS.has_feature("android"))
	var entries: PackedStringArray = ResourceLoader.list_directory(path)
	for fn in entries:
		if fn.ends_with("/"):
			continue
		var lf := fn.to_lower()
		if not lf.begins_with("avatar_"):
			continue
		if lf.ends_with(".png") or lf.ends_with(".webp") or lf.ends_with(".jpg") or lf.ends_with(".jpeg"):
			out.append(fn)
	out.sort()
	if BM_MERCATO_ID_DEBUG:
		var keys: Array[String] = []
		for fn in out:
			keys.append(String(fn).get_basename())
		print("[BM_MERCATO_ID_DEBUG] SCAN_RESULT count=", out.size(), " keys=", keys)
	return out


static func _mercato_meta_key_candidates(avatar_key: String) -> Array[String]:
	var keys: Array[String] = []
	keys.append(avatar_key)
	if not avatar_key.begins_with("avatar_"):
		return keys
	var rest: String = avatar_key.substr(7)
	var suffix := ""
	var digits := rest
	while digits.length() > 0 and not digits[digits.length() - 1].is_valid_int():
		suffix = digits[digits.length() - 1] + suffix
		digits = digits.substr(0, digits.length() - 1)
	if digits.is_valid_int():
		var num := int(digits)
		keys.append("avatar_%d%s" % [num, suffix])
		keys.append("avatar_%02d%s" % [num, suffix])
		keys.append("avatar_%03d%s" % [num, suffix])
	return keys


static func _mercato_load_avatar_meta() -> Dictionary:
	var out: Dictionary = {}
	var path := "res://data/avatars_meta_raw.txt"
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var lines := f.get_as_text().split("\n", false)
	for i in range(1, lines.size()):
		var line := String(lines[i]).strip_edges()
		if line == "":
			continue
		var parts := line.split(",", false)
		if parts.size() < 3:
			continue
		var key := String(parts[0]).strip_edges()
		var gender := String(parts[1]).strip_edges()
		var first_name := String(parts[2]).strip_edges()
		if key != "":
			out[key] = {"gender": gender, "first_name": first_name}
	return out


static func _identity_player_name(p: Dictionary) -> String:
	var n := str(p.get("nom", p.get("name", ""))).strip_edges()
	if n == "":
		n = str(p.get("name", p.get("nom", ""))).strip_edges()
	return n


static func _identity_extra_first_names() -> Array[String]:
	return [
		"Mason", "Isaac", "Aaron", "Adrian", "Blake", "Tyler", "Julian", "Dylan",
		"Owen", "Caleb", "Evan", "Miles", "Carter", "Logan", "Wyatt", "Cole",
		"Finn", "Axel", "Oscar", "Rayan", "Enzo", "Noe", "Robin", "Simon",
		"Quentin", "Mathis", "Yanis", "Nicolas", "Samuel", "Diego", "Milo", "Eliott",
		"Kylian", "Ilyes", "Nael", "Clement", "Paul", "Marceau", "Gabin",
		"Amelie", "Manon", "Ambre", "Lucie", "Agathe", "Romane", "Lena", "Anais"
	]


static func _identity_unique_name(base_name: String, used_names: Dictionary, pid: int) -> String:
	var clean := base_name.strip_edges()
	if clean != "" and not used_names.has(clean.to_lower()):
		return clean
	for candidate in _identity_extra_first_names():
		var c := str(candidate).strip_edges()
		if c != "" and not used_names.has(c.to_lower()):
			return c
	return "Prospect " + str(pid)


static func _identity_pair_key(name: String, avatar_key: String) -> String:
	var n := name.strip_edges().to_lower()
	var ak := avatar_key.strip_edges()
	if n == "" or ak == "":
		return ""
	return n + "|" + ak


static func _identity_unique_name_for_avatar(base_name: String, avatar_key: String, used_pairs: Dictionary, pid: int) -> String:
	var clean := base_name.strip_edges()
	if clean != "" and not used_pairs.has(_identity_pair_key(clean, avatar_key)):
		return clean
	for candidate in _identity_extra_first_names():
		var c := str(candidate).strip_edges()
		if c != "" and not used_pairs.has(_identity_pair_key(c, avatar_key)):
			return c
	return "Prospect " + str(pid)


static func _identity_normalized_id(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text == "":
		return ""
	if text.is_valid_int():
		return str(int(text))
	if text.is_valid_float():
		return str(int(round(float(text))))
	return text


static func _identity_mark_active_id(active_ids: Dictionary, value: Variant) -> void:
	var sid := _identity_normalized_id(value)
	if sid != "":
		active_ids[sid] = true


static func _identity_collect_active_player_ids(save: Dictionary) -> Dictionary:
	var active_ids := {}
	if save.has("mercato") and typeof(save["mercato"]) == TYPE_DICTIONARY:
		var md: Dictionary = save["mercato"] as Dictionary
		if md.has("current_ids") and typeof(md["current_ids"]) == TYPE_ARRAY:
			for id_value in (md["current_ids"] as Array):
				_identity_mark_active_id(active_ids, id_value)
		if md.has("purchased_ids") and typeof(md["purchased_ids"]) == TYPE_ARRAY:
			for id_value in (md["purchased_ids"] as Array):
				_identity_mark_active_id(active_ids, id_value)
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = save["roster"] as Dictionary
		if roster.has("selected_ids") and typeof(roster["selected_ids"]) == TYPE_ARRAY:
			for id_value in (roster["selected_ids"] as Array):
				_identity_mark_active_id(active_ids, id_value)
		if roster.has("match_selected_ids") and typeof(roster["match_selected_ids"]) == TYPE_ARRAY:
			for id_value in (roster["match_selected_ids"] as Array):
				_identity_mark_active_id(active_ids, id_value)
		if roster.has("players") and typeof(roster["players"]) == TYPE_ARRAY:
			for row_raw in (roster["players"] as Array):
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_raw as Dictionary
				_identity_mark_active_id(active_ids, row.get("id", ""))
	if save.has("players") and typeof(save["players"]) == TYPE_ARRAY:
		for row_raw in (save["players"] as Array):
			if typeof(row_raw) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_raw as Dictionary
			_identity_mark_active_id(active_ids, row.get("id", ""))
	return active_ids


static func _identity_is_abandoned_mercato_player(p: Dictionary, sid: String, active_ids: Dictionary) -> bool:
	if sid == "":
		return false
	if not bool(p.get("mercato_generated", false)):
		return false
	return not active_ids.has(sid)


static func _identity_has_active_reference_schema(save: Dictionary) -> bool:
	if not save.has("mercato") or typeof(save["mercato"]) != TYPE_DICTIONARY:
		return false
	var md: Dictionary = save["mercato"] as Dictionary
	if not md.has("current_ids") or typeof(md["current_ids"]) != TYPE_ARRAY:
		return false
	if not md.has("purchased_ids") or typeof(md["purchased_ids"]) != TYPE_ARRAY:
		return false
	if not save.has("roster") or typeof(save["roster"]) != TYPE_DICTIONARY:
		return false
	var roster: Dictionary = save["roster"] as Dictionary
	if not roster.has("selected_ids") or typeof(roster["selected_ids"]) != TYPE_ARRAY:
		return false
	if not save.has("players") or typeof(save["players"]) != TYPE_ARRAY:
		return false
	return true


static func _identity_collect_used(save: Dictionary, skip_id: String = "") -> Dictionary:
	var used := {"avatar_keys": {}, "names": {}, "identity_pairs": {}}
	var current_ids_count := 0
	var purchased_ids_count := 0
	var roster_selected_count := 0
	var roster_players_count := 0
	var save_players_count := 0
	if save.has("mercato") and typeof(save["mercato"]) == TYPE_DICTIONARY:
		var md_debug: Dictionary = save["mercato"] as Dictionary
		if md_debug.has("current_ids") and typeof(md_debug["current_ids"]) == TYPE_ARRAY:
			current_ids_count = (md_debug["current_ids"] as Array).size()
		if md_debug.has("purchased_ids") and typeof(md_debug["purchased_ids"]) == TYPE_ARRAY:
			purchased_ids_count = (md_debug["purchased_ids"] as Array).size()
	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster_debug: Dictionary = save["roster"] as Dictionary
		if roster_debug.has("selected_ids") and typeof(roster_debug["selected_ids"]) == TYPE_ARRAY:
			roster_selected_count = (roster_debug["selected_ids"] as Array).size()
		if roster_debug.has("players") and typeof(roster_debug["players"]) == TYPE_ARRAY:
			roster_players_count = (roster_debug["players"] as Array).size()
	if save.has("players") and typeof(save["players"]) == TYPE_ARRAY:
		save_players_count = (save["players"] as Array).size()
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] USED_IDENTITIES_RESULT used_pair_count=0 used_avatar_key_count=0 active_player_ids_count=0 players_by_id_missing=true selection_players_count=", save_players_count, " roster_selected_count=", roster_selected_count, " roster_players_count=", roster_players_count, " purchased_ids_count=", purchased_ids_count, " mercato_current_ids_count=", current_ids_count)
		return used
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var active_ids := _identity_collect_active_player_ids(save)
	var can_filter_abandoned_mercato := _identity_has_active_reference_schema(save)
	var normalized_skip_id := _identity_normalized_id(skip_id)
	var skipped_abandoned := 0
	var skipped_id := 0
	var scanned_players := 0
	for k in by_id.keys():
		var sid := _identity_normalized_id(k)
		if normalized_skip_id != "" and sid == normalized_skip_id:
			skipped_id += 1
			continue
		var raw = by_id[k]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw as Dictionary
		if can_filter_abandoned_mercato and _identity_is_abandoned_mercato_player(p, sid, active_ids):
			skipped_abandoned += 1
			continue
		scanned_players += 1
		var name := _identity_player_name(p)
		var ak := str(p.get("avatar_key", "")).strip_edges()
		if name != "":
			(used["names"] as Dictionary)[name.to_lower()] = true
		if ak != "":
			(used["avatar_keys"] as Dictionary)[ak] = true
		if name != "" and ak != "":
			var pair_key := _identity_pair_key(name, ak)
			if pair_key != "":
				(used["identity_pairs"] as Dictionary)[pair_key] = true
	if BM_MERCATO_ID_DEBUG:
		var used_pairs: Array = (used["identity_pairs"] as Dictionary).keys()
		var used_avatar_keys: Array = (used["avatar_keys"] as Dictionary).keys()
		print("[BM_MERCATO_ID_DEBUG] USED_IDENTITIES_RESULT used_pair_count=", used_pairs.size(), " used_avatar_key_count=", used_avatar_keys.size(), " active_player_ids_count=", active_ids.size(), " selection_players_count=", save_players_count, " roster_selected_count=", roster_selected_count, " roster_players_count=", roster_players_count, " purchased_ids_count=", purchased_ids_count, " mercato_current_ids_count=", current_ids_count, " abandoned_mercato_ignored_count=", skipped_abandoned, " skipped_id_count=", skipped_id, " scanned_players=", scanned_players, " players_by_id_count=", by_id.size(), " used_pairs=", used_pairs, " used_avatar_keys=", used_avatar_keys)
	return used


static func _mercato_collect_used(save: Dictionary, skip_id: String = "") -> Dictionary:
	var used := {"avatar_keys": {}, "names": {}, "identity_pairs": {}}
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return used
	if not save.has("mercato") or typeof(save["mercato"]) != TYPE_DICTIONARY:
		return used
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var md: Dictionary = save["mercato"] as Dictionary
	var active_mercato_ids := {}
	if md.has("current_ids") and typeof(md["current_ids"]) == TYPE_ARRAY:
		for id_value in (md["current_ids"] as Array):
			_identity_mark_active_id(active_mercato_ids, id_value)
	if md.has("purchased_ids") and typeof(md["purchased_ids"]) == TYPE_ARRAY:
		for id_value in (md["purchased_ids"] as Array):
			_identity_mark_active_id(active_mercato_ids, id_value)
	var normalized_skip_id := _identity_normalized_id(skip_id)
	for sid in active_mercato_ids.keys():
		var clean_id := _identity_normalized_id(sid)
		if clean_id == "" or clean_id == normalized_skip_id:
			continue
		if not by_id.has(clean_id) or typeof(by_id[clean_id]) != TYPE_DICTIONARY:
			continue
		_identity_mark_used(used, by_id[clean_id] as Dictionary)
	return used


static func _mercato_player_identity_complete(p: Dictionary) -> bool:
	var name := str(p.get("nom", p.get("name", ""))).strip_edges()
	var avatar_key := str(p.get("avatar_key", "")).strip_edges()
	var avatar_path := str(p.get("avatar_path", "")).strip_edges()
	if name == "" or name.begins_with("Prospect "):
		return false
	if avatar_key == "" or avatar_path == "":
		return false
	return ResourceLoader.exists(avatar_path)



static func _identity_pick_candidate(save: Dictionary, used: Dictionary, candidates: Array = []) -> Dictionary:
	if candidates.is_empty():
		candidates = _mercato_avatar_candidates()
	var used_pairs: Dictionary = used.get("identity_pairs", {}) as Dictionary
	var rejected_count := 0
	for c_raw in candidates:
		if typeof(c_raw) != TYPE_DICTIONARY:
			rejected_count += 1
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] CANDIDATE_REJECTED name= avatar_key= reason=not_dictionary")
			continue
		var c: Dictionary = c_raw as Dictionary
		var ak := str(c.get("avatar_key", "")).strip_edges()
		var name := str(c.get("name", "")).strip_edges()
		var avatar_path := str(c.get("avatar_path", "")).strip_edges()
		if ak == "":
			rejected_count += 1
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] CANDIDATE_REJECTED name=", name, " avatar_key=", ak, " reason=missing_avatar_key")
			continue
		if avatar_path == "" or not ResourceLoader.exists(avatar_path):
			rejected_count += 1
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] CANDIDATE_REJECTED name=", name, " avatar_key=", ak, " reason=missing_avatar_path")
			continue
		if used_pairs.has(_identity_pair_key(name, ak)):
			rejected_count += 1
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] CANDIDATE_REJECTED name=", name, " avatar_key=", ak, " reason=pair_already_used")
			continue
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] CANDIDATE_SELECTED name=", name, " avatar_key=", ak, " avatar_path=", avatar_path, " gender=", str(c.get("gender", "")))
		return c
	if BM_MERCATO_ID_DEBUG:
		print("[BM_MERCATO_ID_DEBUG] NO_CANDIDATE_SELECTED candidate_count=", candidates.size(), " rejected_count=", rejected_count)
	return {}


static func _identity_apply_candidate(p: Dictionary, candidate: Dictionary, used: Dictionary, pid: int) -> void:
	var base_name := str(candidate.get("name", p.get("name", p.get("nom", "")))).strip_edges()
	var avatar_key := str(candidate.get("avatar_key", ""))
	var used_pairs: Dictionary = used.get("identity_pairs", {}) as Dictionary
	var display_name := _identity_unique_name_for_avatar(base_name, avatar_key, used_pairs, pid)
	p["nom"] = display_name
	p["name"] = display_name
	p["avatar_key"] = avatar_key
	p["avatar_path"] = str(candidate.get("avatar_path", ""))
	p["gender"] = str(candidate.get("gender", p.get("gender", "U")))


static func _identity_mark_used(used: Dictionary, p: Dictionary) -> void:
	var name := _identity_player_name(p)
	var ak := str(p.get("avatar_key", "")).strip_edges()
	if name != "":
		(used["names"] as Dictionary)[name.to_lower()] = true
	if ak != "":
		(used["avatar_keys"] as Dictionary)[ak] = true
	if name != "" and ak != "":
		var pair_key := _identity_pair_key(name, ak)
		if pair_key != "":
			(used["identity_pairs"] as Dictionary)[pair_key] = true


static func _sync_player_identity_copies(save: Dictionary, by_id: Dictionary) -> void:
	if save.has("players") and typeof(save["players"]) == TYPE_ARRAY:
		var arr: Array = save["players"] as Array
		for i in range(arr.size()):
			var raw = arr[i]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw as Dictionary
			var row_id := str(int(round(float(str(row.get("id", -1)).strip_edges()))))
			if by_id.has(row_id) and typeof(by_id[row_id]) == TYPE_DICTIONARY:
				var src: Dictionary = by_id[row_id] as Dictionary
				row["nom"] = src.get("nom", row.get("nom", ""))
				row["name"] = src.get("name", row.get("name", row.get("nom", "")))
				row["avatar_key"] = src.get("avatar_key", row.get("avatar_key", ""))
				row["avatar_path"] = src.get("avatar_path", row.get("avatar_path", ""))
				row["gender"] = src.get("gender", row.get("gender", "U"))
				arr[i] = row
		save["players"] = arr



static func _repair_incomplete_mercato_identities_on_load(save: Dictionary) -> bool:
	if not save.has("players_by_id") or typeof(save.get("players_by_id")) != TYPE_DICTIONARY:
		return false
	if not save.has("mercato") or typeof(save.get("mercato")) != TYPE_DICTIONARY:
		return false
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var md: Dictionary = save["mercato"] as Dictionary
	var target_ids := {}
	if md.has("current_ids") and typeof(md["current_ids"]) == TYPE_ARRAY:
		for id_value in (md["current_ids"] as Array):
			_identity_mark_active_id(target_ids, id_value)
	if md.has("purchased_ids") and typeof(md["purchased_ids"]) == TYPE_ARRAY:
		for id_value in (md["purchased_ids"] as Array):
			_identity_mark_active_id(target_ids, id_value)
	var changed := false
	for k in target_ids.keys():
		var clean_id := _identity_normalized_id(k)
		if clean_id == "" or not by_id.has(clean_id):
			continue
		var player = by_id.get(clean_id)
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = player as Dictionary
		if not bool(p.get("mercato_generated", false)):
			continue
		if _mercato_player_identity_complete(p):
			continue
		var used := _mercato_collect_used(save, clean_id)
		var pick := _identity_pick_candidate(save, used, _mercato_male_avatar_candidates(true))
		if pick.is_empty():
			continue
		_identity_apply_candidate(p, pick, used, int(float(clean_id)))
		by_id[clean_id] = p
		changed = true
	if changed:
		save["players_by_id"] = by_id
		_sync_player_identity_copies(save, by_id)
	return changed

static func _repair_duplicate_player_identities_on_load(save: Dictionary) -> bool:
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return false
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var keys: Array = by_id.keys()
	keys.sort_custom(func(a, b): return int(float(str(a))) < int(float(str(b))))
	var used := {"avatar_keys": {}, "names": {}, "identity_pairs": {}}
	var reserved_mercato_avatar_owner := {}
	var reserved_mercato_pair_owner := {}
	var changed := false
	for k in keys:
		var raw = by_id[k]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw as Dictionary
		if not bool(p.get("mercato_generated", false)):
			_identity_mark_used(used, p)
			continue
		if _mercato_player_identity_complete(p):
			var ak := str(p.get("avatar_key", "")).strip_edges()
			if ak.begins_with("avatar_mercato_") and not reserved_mercato_avatar_owner.has(ak):
				var pair_key := _identity_pair_key(_identity_player_name(p), ak)
				reserved_mercato_avatar_owner[ak] = int(float(str(k)))
				if pair_key != "":
					reserved_mercato_pair_owner[pair_key] = int(float(str(k)))
				_identity_mark_used(used, p)
	for k in keys:
		var raw = by_id[k]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw as Dictionary
		var pid := int(float(str(k)))
		if not bool(p.get("mercato_generated", false)):
			_identity_mark_used(used, p)
			continue
		var name := _identity_player_name(p)
		var ak := str(p.get("avatar_key", "")).strip_edges()
		var pair_key := _identity_pair_key(name, ak)
		var avatar_collision := ak != "" and (used["avatar_keys"] as Dictionary).has(ak) and int(reserved_mercato_avatar_owner.get(ak, -1)) != pid
		var pair_collision := pair_key != "" and (used["identity_pairs"] as Dictionary).has(pair_key) and int(reserved_mercato_pair_owner.get(pair_key, -1)) != pid
		var invalid_mercato_identity := ak == "" or not ak.begins_with("avatar_mercato_") or not _mercato_player_identity_complete(p)
		if invalid_mercato_identity or avatar_collision or pair_collision:
			var candidate := _identity_pick_candidate(save, used, _mercato_male_avatar_candidates(true))
			if not candidate.is_empty():
				_identity_apply_candidate(p, candidate, used, pid)
			else:
				var used_pairs: Dictionary = used.get("identity_pairs", {}) as Dictionary
				var unique_name := _identity_unique_name_for_avatar(name, ak, used_pairs, pid)
				p["nom"] = unique_name
				p["name"] = unique_name
			by_id[k] = p
			changed = true
		_identity_mark_used(used, p)
	if changed:
		save["players_by_id"] = by_id
		_sync_player_identity_copies(save, by_id)
	return changed


static func _mercato_avatar_candidates() -> Array:
	var base_root := "res://assets/images/avatars"
	var base_used := base_root
	var files: Array[String] = _mercato_scan_avatar_portraits(base_root)
	if files.size() == 0:
		base_used = base_root + "/avatars_dessin"
		files = _mercato_scan_avatar_portraits(base_used)
	var meta: Dictionary = _mercato_load_avatar_meta()
	var out: Array = []
	var meta_hits := 0
	for i in range(files.size()):
		var fname := files[i]
		var avatar_key := fname.get_basename()
		var first_name := avatar_key.replace("_", " ")
		var gender := "U"
		for k in _mercato_meta_key_candidates(avatar_key):
			if meta.has(k):
				var m: Dictionary = meta[k] as Dictionary
				gender = str(m.get("gender", "U"))
				first_name = str(m.get("first_name", first_name))
				meta_hits += 1
				break
		out.append({
			"id": i,
			"avatar_key": avatar_key,
			"avatar_path": base_used + "/" + fname,
			"name": first_name,
			"gender": gender
		})
	if BM_MERCATO_ID_DEBUG:
		var candidate_keys: Array[String] = []
		for c_raw in out:
			if typeof(c_raw) == TYPE_DICTIONARY:
				var c: Dictionary = c_raw as Dictionary
				candidate_keys.append(str(c.get("name", "")) + "|" + str(c.get("avatar_key", "")) + "|" + str(c.get("avatar_path", "")) + "|" + str(c.get("gender", "")))
		print("[BM_MERCATO_ID_DEBUG] CANDIDATES_RESULT portraits_count=", files.size(), " metadata_count=", meta.size(), " metadata_hits=", meta_hits, " candidate_count=", out.size(), " candidate_keys=", candidate_keys)
	return out


static func _mercato_male_avatar_candidates(mercato_pool_only: bool = false) -> Array:
	var out: Array = []
	for c_raw in _mercato_avatar_candidates():
		if typeof(c_raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = c_raw as Dictionary
		var avatar_key := str(c.get("avatar_key", "")).strip_edges()
		if mercato_pool_only and not avatar_key.begins_with("avatar_mercato_"):
			continue
		var avatar_path := str(c.get("avatar_path", "")).strip_edges()
		if str(c.get("gender", "U")) != "M":
			continue
		if avatar_path == "" or not ResourceLoader.exists(avatar_path):
			continue
		out.append(c)
	return out


static func _mercato_pick_unused_avatar(save: Dictionary) -> Dictionary:
	var used := _mercato_collect_used(save)
	var picked := _identity_pick_candidate(save, used, _mercato_male_avatar_candidates(true))
	if BM_MERCATO_ID_DEBUG:
		print("[BM_MERCATO_ID_DEBUG] PICK_RESULT is_empty=", picked.is_empty(), " name=", str(picked.get("name", "")), " avatar_key=", str(picked.get("avatar_key", "")), " avatar_path=", str(picked.get("avatar_path", "")), " gender=", str(picked.get("gender", "")))
	return picked


static func _mercato_canonical_avatar_candidates() -> Array:
	var candidates := _mercato_male_avatar_candidates(true)
	candidates.sort_custom(func(a, b):
		var da: Dictionary = a as Dictionary
		var db: Dictionary = b as Dictionary
		return str(da.get("avatar_key", "")) < str(db.get("avatar_key", ""))
	)
	return candidates


static func _mercato_rotated_avatar_candidates(season_number: int) -> Array:
	var candidates := _mercato_canonical_avatar_candidates()
	if candidates.is_empty():
		return []
	var rotation_cycle: int = maxi(0, season_number - 2)
	var start_index: int = (rotation_cycle * 8) % candidates.size()
	var ordered: Array = []
	for i in range(candidates.size()):
		ordered.append(candidates[(start_index + i) % candidates.size()])
	return ordered


static func _mercato_rotated_unused_avatar_picks(save: Dictionary, pool_size: int, season_number: int) -> Array:
	var used := _identity_collect_used(save)
	var picks: Array = []
	for c_raw in _mercato_rotated_avatar_candidates(season_number):
		if typeof(c_raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = c_raw as Dictionary
		var avatar_key := str(c.get("avatar_key", "")).strip_edges()
		var used_avatar_keys: Dictionary = used.get("avatar_keys", {}) as Dictionary
		if avatar_key == "" or used_avatar_keys.has(avatar_key):
			continue
		var picked := _identity_pick_candidate(save, used, [c])
		if picked.is_empty():
			continue
		var preview := {
			"nom": str(picked.get("name", "")),
			"name": str(picked.get("name", "")),
			"avatar_key": str(picked.get("avatar_key", "")),
			"avatar_path": str(picked.get("avatar_path", "")),
			"gender": str(picked.get("gender", "U"))
		}
		_identity_mark_used(used, preview)
		picks.append(picked)
		if picks.size() >= pool_size:
			break
	return picks


static func _mercato_pool_tier_plan() -> Array:
	return ["elite", "bon", "bon", "standard", "standard", "standard", "bon", "standard"]


static func _mercato_target_tier_counts() -> Dictionary:
	return {"elite": 1, "bon": 3, "standard": 4}


static func _mercato_normalized_tier(value: Variant) -> String:
	var tier := str(value).strip_edges()
	if tier == "elite" or tier == "bon" or tier == "standard":
		return tier
	return "standard"


static func _mercato_used_avatar_keys_forever(save: Dictionary) -> Dictionary:
	var used := {}
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return used
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	for k in by_id.keys():
		var raw = by_id[k]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = raw as Dictionary
		var avatar_key := str(p.get("avatar_key", "")).strip_edges()
		if avatar_key.begins_with("avatar_mercato_"):
			used[avatar_key] = true
	return used


static func _mercato_unused_avatar_picks(save: Dictionary) -> Array:
	var used_avatar_keys := _mercato_used_avatar_keys_forever(save)
	var out: Array = []
	for c_raw in _mercato_canonical_avatar_candidates():
		if typeof(c_raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = c_raw as Dictionary
		var avatar_key := str(c.get("avatar_key", "")).strip_edges()
		if avatar_key == "" or used_avatar_keys.has(avatar_key):
			continue
		out.append(c)
	return out


static func _mercato_purchased_id_set(md: Dictionary) -> Dictionary:
	var purchased := {}
	if md.has("purchased_ids") and typeof(md["purchased_ids"]) == TYPE_ARRAY:
		for id_value in (md["purchased_ids"] as Array):
			_identity_mark_active_id(purchased, id_value)
	return purchased


static func _mercato_select_retained_pool_ids(save: Dictionary, current_ids: Array, keep_count: int, target_counts: Dictionary) -> Array:
	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		return []
	if not save.has("mercato") or typeof(save["mercato"]) != TYPE_DICTIONARY:
		return []
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	var md: Dictionary = save["mercato"] as Dictionary
	var purchased := _mercato_purchased_id_set(md)
	var candidates: Array = []
	var seen := {}
	for id_value in current_ids:
		var sid := _identity_normalized_id(id_value)
		if sid == "" or seen.has(sid) or purchased.has(sid):
			continue
		seen[sid] = true
		if not by_id.has(sid) or typeof(by_id[sid]) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = by_id[sid] as Dictionary
		if not _mercato_player_identity_complete(p):
			continue
		var tier := _mercato_normalized_tier(p.get("tier", "standard"))
		if not target_counts.has(tier):
			continue
		candidates.append({"id": int(sid), "tier": tier})
	return _mercato_select_retained_pool_ids_rec(candidates, keep_count, target_counts, 0, [], {"elite": 0, "bon": 0, "standard": 0})


static func _mercato_select_retained_pool_ids_rec(candidates: Array, keep_count: int, target_counts: Dictionary, start_index: int, selected: Array, counts: Dictionary) -> Array:
	if selected.size() == keep_count:
		return selected.duplicate()
	for i in range(start_index, candidates.size()):
		var c: Dictionary = candidates[i] as Dictionary
		var tier := str(c.get("tier", "standard"))
		var next_count := int(counts.get(tier, 0)) + 1
		if next_count > int(target_counts.get(tier, 0)):
			continue
		var remaining_candidates := candidates.size() - (i + 1)
		if selected.size() + 1 + remaining_candidates < keep_count:
			continue
		var next_selected := selected.duplicate()
		next_selected.append(int(c.get("id", -1)))
		var next_counts := counts.duplicate()
		next_counts[tier] = next_count
		var result := _mercato_select_retained_pool_ids_rec(candidates, keep_count, target_counts, i + 1, next_selected, next_counts)
		if not result.is_empty():
			return result
	return []


static func _mercato_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng

static func _mercato_random_poste(rng: RandomNumberGenerator) -> String:
	var postes: Array[String] = ["Meneur", "Ailier", "Pivot", "Arrière"]
	return postes[rng.randi_range(0, postes.size() - 1)]

static func _mercato_calc_ponderation(j: Dictionary) -> float:
	var poste: String = str(j.get("poste", ""))
	var precision: float = float(j.get("precision", 0.75)) * 100.0
	var tir: float = float(j.get("tir", precision))
	var vitesse: float = float(j.get("vitesse", 70))
	var force: float = float(j.get("force", 70))
	var defense: float = float(j.get("defense", 70))
	var endurance: float = float(j.get("endurance", 70))

	var ponderation: float = 0.0
	if poste == "Meneur":
		ponderation = precision * 0.20 + tir * 0.10 + vitesse * 0.30 + endurance * 0.20 + defense * 0.10 + force * 0.10
	elif poste == "Ailier":
		ponderation = precision * 0.18 + tir * 0.12 + vitesse * 0.22 + force * 0.20 + defense * 0.13 + endurance * 0.15
	elif poste == "Pivot":
		ponderation = force * 0.30 + defense * 0.25 + precision * 0.10 + tir * 0.05 + endurance * 0.15 + vitesse * 0.15
	elif poste == "Arrière":
		ponderation = precision * 0.18 + tir * 0.10 + vitesse * 0.28 + endurance * 0.20 + defense * 0.14 + force * 0.10
	else:
		ponderation = precision * 0.18 + tir * 0.10 + vitesse * 0.22 + force * 0.20 + defense * 0.15 + endurance * 0.15

	var age: int = int(j.get("age", 25))
	var coef_age: float = 1.0
	if age <= 22:
		coef_age = 0.9
	elif age <= 26:
		coef_age = 1.0
	elif age <= 30:
		coef_age = 1.05
	elif age <= 34:
		coef_age = 0.95
	else:
		coef_age = 0.85
	ponderation *= coef_age

	var matchs_consecutifs: int = int(j.get("matchs_consecutifs", 0))
	var coef_matchs_consecutifs: float = 1.0
	if matchs_consecutifs >= 8:
		coef_matchs_consecutifs = 0.92
	elif matchs_consecutifs >= 6:
		coef_matchs_consecutifs = 0.95
	elif matchs_consecutifs >= 6:
		coef_matchs_consecutifs = 0.98
	ponderation *= coef_matchs_consecutifs

	var repos: int = int(j.get("repos_consecutifs", 0))
	if repos > 0:
		var coef_repos := 1.0
		if repos == 1:
			coef_repos = 1.02
		elif repos == 2:
			coef_repos = 1.04
		elif repos == 3:
			coef_repos = 1.00
		elif repos == 4:
			coef_repos = 0.96
		else:
			coef_repos = 0.92
		ponderation *= coef_repos

	var est_blesse := bool(j.get("blessure", false)) or int(j.get("matches_conval", 0)) > 0
	if est_blesse:
		ponderation *= 0.70

	var motivation: float = float(j.get("motivation", 80))
	ponderation *= 1.0 + (motivation - 80.0) / 200.0

	return snapped(ponderation, 0.01)

static func _mercato_next_generated_id(save: Dictionary) -> int:
	var max_id: int = 999

	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		var by_id: Dictionary = save["players_by_id"] as Dictionary
		for k in by_id.keys():
			var sid := str(k).strip_edges()
			if sid.is_valid_int():
				max_id = maxi(max_id, int(sid))

	if save.has("mercato") and typeof(save["mercato"]) == TYPE_DICTIONARY:
		var md: Dictionary = save["mercato"] as Dictionary
		max_id = maxi(max_id, int(md.get("last_generated_id", max_id)))

	return max_id + 1

static func _mercato_make_new_player(save: Dictionary, forced_tier: String = "", forced_avatar_pick: Dictionary = {}) -> Dictionary:
	var rng := _mercato_rng()
	var pid: int = _mercato_next_generated_id(save)
	var poste: String = _mercato_random_poste(rng)

	# 🎯 Niveau joueur (standard / bon / elite)
	var roll: float = rng.randf()
	var tier: String = "standard"
	if forced_tier == "elite" or forced_tier == "bon" or forced_tier == "standard":
		tier = forced_tier
	elif roll > 0.95:
		tier = "elite"
	elif roll > 0.80:
		tier = "bon"

	var age: int = rng.randi_range(18, 35)
	var avatar_pick: Dictionary = {}
	if forced_avatar_pick.is_empty():
		avatar_pick = _mercato_pick_unused_avatar(save)
	else:
		var forced_used := _identity_collect_used(save)
		var forced_avatar_key := str(forced_avatar_pick.get("avatar_key", "")).strip_edges()
		var forced_used_avatar_keys: Dictionary = forced_used.get("avatar_keys", {}) as Dictionary
		if forced_avatar_key != "" and not forced_used_avatar_keys.has(forced_avatar_key):
			avatar_pick = _identity_pick_candidate(save, forced_used, [forced_avatar_pick])
	if avatar_pick.is_empty():
		return {}

	var nom_affiche := "Prospect " + str(pid)
	var avatar_key := ""
	var avatar_path := ""
	var gender := "U"
	if not avatar_pick.is_empty():
		var used_identity := _mercato_collect_used(save)
		avatar_key = str(avatar_pick.get("avatar_key", ""))
		nom_affiche = _identity_unique_name_for_avatar(str(avatar_pick.get("name", nom_affiche)), avatar_key, used_identity.get("identity_pairs", {}) as Dictionary, pid)
		avatar_path = str(avatar_pick.get("avatar_path", ""))
		gender = str(avatar_pick.get("gender", "U"))

	var j: Dictionary = {
		"id": pid,
		"nom": nom_affiche,
		"name": nom_affiche,
		"avatar_key": avatar_key,
		"avatar_path": avatar_path,
		"gender": gender,
		"poste": poste,
		"pos": poste,
		"age": age,
		"precision": (rng.randf_range(0.85, 0.98) if tier == "elite" else (rng.randf_range(0.75, 0.92) if tier == "bon" else rng.randf_range(0.60, 0.88))),
		"tir": (rng.randi_range(80, 98) if tier == "elite" else (rng.randi_range(70, 92) if tier == "bon" else rng.randi_range(55, 85))),
		"vitesse": (rng.randi_range(80, 98) if tier == "elite" else (rng.randi_range(70, 92) if tier == "bon" else rng.randi_range(55, 85))),
		"force": (rng.randi_range(80, 98) if tier == "elite" else (rng.randi_range(70, 92) if tier == "bon" else rng.randi_range(55, 85))),
		"defense": (rng.randi_range(80, 98) if tier == "elite" else (rng.randi_range(70, 92) if tier == "bon" else rng.randi_range(55, 85))),
		"endurance": (rng.randi_range(80, 98) if tier == "elite" else (rng.randi_range(70, 92) if tier == "bon" else rng.randi_range(55, 85))),
		"matchs_consecutifs": 0,
		"repos_consecutifs": 0,
		"fatigue": 0,
		"blessure": false,
		"matches_conval": 0,
		"mercato_generated": true,
		"tier": tier
	}

	j["pondération"] = _mercato_calc_ponderation(j)
	j["ponderation"] = j["pondération"]

	var base_motivation: int = 80
	if age < 23:
		base_motivation = rng.randi_range(75, 95)
	elif age > 30:
		base_motivation = rng.randi_range(60, 80)
	else:
		base_motivation = rng.randi_range(65, 90)

	if float(j["pondération"]) > 80.0:
		base_motivation += 5
	elif float(j["pondération"]) < 65.0:
		base_motivation -= 5

	j["motivation"] = clamp(base_motivation, 50, 100)

	# 💰 Salaire dépend du niveau (standard / bon / elite)
	var base := float(j["pondération"])
	var salaire_int: int = 0
	if tier == "elite":
		salaire_int = int(120000 + base * 1200.0)
	elif tier == "bon":
		salaire_int = int(90000 + base * 800.0)
	else:
		salaire_int = int(60000 + base * 400.0)
	salaire_int = clamp(salaire_int, 60000, 250000)
	j["salaire"] = salaire_int
	if not _mercato_player_identity_complete(j):
		return {}
	if BM_MERCATO_ID_DEBUG:
		var identity_complete := not str(j.get("nom", "")).begins_with("Prospect ") and str(j.get("avatar_key", "")).strip_edges() != "" and str(j.get("avatar_path", "")).strip_edges() != ""
		print("[BM_MERCATO_ID_DEBUG] PLAYER_CREATED id=", pid, " nom=", str(j.get("nom", "")), " name=", str(j.get("name", "")), " avatar_key=", str(j.get("avatar_key", "")), " avatar_path=", str(j.get("avatar_path", "")), " gender=", str(j.get("gender", "")), " mercato_generated=", bool(j.get("mercato_generated", false)))
		print("[BM_MERCATO_ID_DEBUG] PLAYER_IDENTITY_COMPLETE=", identity_complete)

	# New prospects only: keep the historical salary base and RNG above.
	# Resolve the sporting rating after motivation and contract are final.
	j["rating_provenance"] = {
		"kind": "canonical", "source": "PlayerLife._mercato_make_new_player",
		"accuracy_unit": "fraction"
	}
	var sports_rating := _l1_player_rating(j)
	if sports_rating.get("status") != "OK":
		push_error("[MERCATO] Invalid new player rating: " + str(sports_rating))
		return {}
	j["pondération"] = sports_rating.value
	j["ponderation"] = sports_rating.value

	return j

static func ensure_mercato_schema(save: Dictionary) -> void:
	if not save.has("mercato") or typeof(save["mercato"]) != TYPE_DICTIONARY:
		save["mercato"] = {}

	var md: Dictionary = save["mercato"] as Dictionary

	if not md.has("current_ids") or typeof(md["current_ids"]) != TYPE_ARRAY:
		md["current_ids"] = []
	if not md.has("seen_ids") or typeof(md["seen_ids"]) != TYPE_ARRAY:
		md["seen_ids"] = []
	if not md.has("pool_size"):
		md["pool_size"] = 8
	if not md.has("keep_ratio"):
		md["keep_ratio"] = 0.0
	if not md.has("cycle"):
		md["cycle"] = 0
	if not md.has("last_generated_id"):
		md["last_generated_id"] = 999
	if not md.has("last_refresh_season"):
		md["last_refresh_season"] = 0
	if not md.has("last_refresh_phase"):
		md["last_refresh_phase"] = ""

	save["mercato"] = md


static func _mercato_current_pool_identity_complete(save: Dictionary, current_ids: Array) -> bool:
	if not save.has("players_by_id") or typeof(save.get("players_by_id")) != TYPE_DICTIONARY:
		return false
	var by_id: Dictionary = save["players_by_id"] as Dictionary
	for pid in current_ids:
		var key := str(pid)
		if not by_id.has(key) or typeof(by_id.get(key)) != TYPE_DICTIONARY:
			return false
		var player: Dictionary = by_id[key] as Dictionary
		if not _mercato_player_identity_complete(player):
			return false
	return true


static func refresh_mercato_pool(save: Dictionary, phase: String = "manual") -> void:
	ensure_mercato_schema(save)

	if not save.has("players_by_id") or typeof(save["players_by_id"]) != TYPE_DICTIONARY:
		save["players_by_id"] = {}
	var by_id: Dictionary = save["players_by_id"] as Dictionary

	var md: Dictionary = save["mercato"] as Dictionary
	var current_ids: Array = (md.get("current_ids", []) as Array).duplicate()
	var seen_ids: Array = (md.get("seen_ids", []) as Array).duplicate()
	var original_seen_ids: Array = seen_ids.duplicate()
	var original_last_generated_id := int(md.get("last_generated_id", 999))
	var original_by_id: Dictionary = by_id.duplicate(true)

	var season_now: int = int(save.get("season_number", 1))
	var pool_size: int = 8
	var next_ids: Array = []
	if BM_MERCATO_ID_DEBUG:
		var purchased_ids_debug: Array = []
		if md.has("purchased_ids") and typeof(md["purchased_ids"]) == TYPE_ARRAY:
			purchased_ids_debug = (md["purchased_ids"] as Array).duplicate()
		print("[BM_MERCATO_ID_DEBUG] REFRESH_START season_round=", int(save.get("season_round", save.get("matchs_joues", 0))), " season_id=", season_now, " phase=", phase, " current_ids_before=", current_ids, " purchased_ids=", purchased_ids_debug, " players_by_id_count=", by_id.size())

	# Même saison + pool déjà complet et sain => on garde exactement les mêmes 8
	if int(md.get("last_refresh_season", 0)) == season_now and current_ids.size() == pool_size and _mercato_current_pool_identity_complete(save, current_ids):
		next_ids = current_ids.duplicate()
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] REFRESH_REUSE phase=", phase, " current_ids_after=", next_ids)
		return

	var current_pool_valid := current_ids.size() == pool_size and _mercato_current_pool_identity_complete(save, current_ids)
	var tier_plan := _mercato_pool_tier_plan()
	var target_counts := _mercato_target_tier_counts()
	var unused_avatar_picks := _mercato_unused_avatar_picks(save)
	var retained_ids: Array = []

	if current_pool_valid:
		if unused_avatar_picks.is_empty():
			md["last_refresh_season"] = season_now
			save["mercato"] = md
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] REFRESH_FREEZE_NO_UNUSED_IDENTITIES phase=", phase, " current_ids_after=", current_ids)
			return
		if unused_avatar_picks.size() == 5:
			retained_ids = _mercato_select_retained_pool_ids(save, current_ids, 3, target_counts)
			if retained_ids.size() != 3:
				md["last_refresh_season"] = season_now
				save["mercato"] = md
				if BM_MERCATO_ID_DEBUG:
					print("[BM_MERCATO_ID_DEBUG] REFRESH_KEEP_EXISTING_NO_RETAINED_COMBINATION phase=", phase, " unused_identity_count=", unused_avatar_picks.size())
				return
		elif unused_avatar_picks.size() != pool_size:
			md["last_refresh_season"] = season_now
			save["mercato"] = md
			if BM_MERCATO_ID_DEBUG:
				print("[BM_MERCATO_ID_DEBUG] REFRESH_KEEP_EXISTING_UNSUPPORTED_UNUSED_COUNT phase=", phase, " unused_identity_count=", unused_avatar_picks.size())
			return
	elif unused_avatar_picks.size() < pool_size:
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] REFRESH_KEEP_EXISTING_NOT_ENOUGH_IDENTITIES phase=", phase, " unused_identity_count=", unused_avatar_picks.size())
		return

	md["current_ids"] = []
	save["mercato"] = md
	var retained_remaining: Array = retained_ids.duplicate()
	var new_pick_index := 0
	for slot in range(pool_size):
		var slot_tier := str(tier_plan[slot])
		var retained_slot_index := -1
		for i in range(retained_remaining.size()):
			var retained_id := int(retained_remaining[i])
			var retained_key := str(retained_id)
			if by_id.has(retained_key) and typeof(by_id[retained_key]) == TYPE_DICTIONARY:
				var retained_player: Dictionary = by_id[retained_key] as Dictionary
				if _mercato_normalized_tier(retained_player.get("tier", "standard")) == slot_tier:
					retained_slot_index = i
					break
		if retained_slot_index >= 0:
			var placed_id := int(retained_remaining[retained_slot_index])
			next_ids.append(placed_id)
			retained_remaining.remove_at(retained_slot_index)
			continue

		if new_pick_index >= unused_avatar_picks.size():
			break
		md["current_ids"] = next_ids.duplicate()
		save["mercato"] = md
		var player: Dictionary = _mercato_make_new_player(save, slot_tier, unused_avatar_picks[new_pick_index])
		new_pick_index += 1
		var pid: int = int(player.get("id", -1))
		if pid < 0 or not _mercato_player_identity_complete(player):
			break

		var key := str(pid)
		by_id[key] = player
		next_ids.append(pid)

		if not seen_ids.has(pid):
			seen_ids.append(pid)

		md["last_generated_id"] = maxi(int(md.get("last_generated_id", 999)), pid)
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] REFRESH_APPEND phase=", phase, " id=", pid, " slot=", next_ids.size(), " tier=", str(player.get("tier", "")), " nom=", str(player.get("nom", "")), " avatar_key=", str(player.get("avatar_key", "")), " avatar_path=", str(player.get("avatar_path", "")))

	if next_ids.size() < pool_size or not retained_remaining.is_empty():
		var incomplete_generated_count := next_ids.size()
		by_id = original_by_id
		seen_ids = original_seen_ids
		md["last_generated_id"] = original_last_generated_id
		next_ids = current_ids.duplicate()
		md["current_ids"] = next_ids
		md["seen_ids"] = seen_ids
		save["players_by_id"] = by_id
		save["mercato"] = md
		if BM_MERCATO_ID_DEBUG:
			print("[BM_MERCATO_ID_DEBUG] REFRESH_KEEP_EXISTING_INCOMPLETE_GENERATION phase=", phase, " generated_count=", incomplete_generated_count, " required=", pool_size)
		return

	md["current_ids"] = next_ids
	md["seen_ids"] = seen_ids
	md["cycle"] = int(md.get("cycle", 0)) + 1
	md["last_refresh_phase"] = phase
	md["last_refresh_season"] = season_now

	save["players_by_id"] = by_id
	save["mercato"] = md
	if BM_MERCATO_ID_DEBUG:
		print("[BM_MERCATO_ID_DEBUG] REFRESH_END current_ids_after=", next_ids, " generated_ids=", next_ids, " players_by_id_count_after=", by_id.size(), " seen_ids_count=", seen_ids.size(), " phase=", phase)

# --- Reset Finance pour nouveau club (appelé depuis Main.gd) ---
static func reset_finance_for_new_club(save: Dictionary) -> void:
	if save == null:
		return

	ensure_progression_wallet_schema(save)
	ensure_finance_schema(save)

	# Totaux
	save["total_billetterie"] = 0
	save["total_boutique"] = 0
	save["total_sponsors"] = 0
	save["total_tournois"] = 0
	save["tournois_fees_total"] = 0
	save.erase("active_sponsor_contract")

	# Salaires (cumul + par match)
	if not save.has("total_salaires"):
		save["total_salaires"] = 0
	save["total_salaires"] = 0
	save["salary_total_per_match"] = 0

	# Round/persistance anti double-compte
	save["season_round"] = 0
	save["last_pop_fin_round"] = -1
	save["goal_climb_standings_seen"] = false
	save["intro_popup_first_match_seen"] = false
	save["goal_climb_standings_match17_seen"] = false
	save["shop_restock_notice_match14_seen"] = false
	save["stadium_intro_seen"] = false
	save[CLUB_STAFF_INTRO_SEEN_KEY] = false
	save[CLUB_STAFF_INTRO_PENDING_KEY] = false
	save["last_match_finance_popup_pending"] = false
	save.erase("season_unlock_glow_seen_s1_BtnTournois")
	save.erase("season_unlock_glow_seen_s1_BtnMissions")
	save.erase("season_unlock_glow_seen_BtnTournois")
	save.erase("season_unlock_glow_seen_BtnMissions")
	save.erase("last_match_finance_recettes")
	save.erase("last_match_finance_depenses")
	save.erase("last_match_finance_xp")

	# Progression saison remise à zéro pour une nouvelle équipe
	if not save.has("progress") or typeof(save["progress"]) != TYPE_DICTIONARY:
		save["progress"] = {}
	(save["progress"] as Dictionary)["journee"] = 1
	(save["progress"] as Dictionary)["wins"] = 0
	(save["progress"] as Dictionary)["losses"] = 0

	# Résultats / historique saison
	save["season_results"] = {}
	save["ranking_history"] = []
	save["season_xp_earned"] = 0

	# Cumuls finances / solde
	save["total_recettes"] = 0
	save["total_depenses"] = 0
	save["total_shop_restock_cost"] = 0

	# Historiques finances
	save["finance_history_recettes"] = []
	save["finance_history_depenses"] = []
	save["finance_history_solde"] = []

	# Wallet / finance réalignés à zéro pour un nouveau club
	if not save.has("wallet") or typeof(save["wallet"]) != TYPE_DICTIONARY:
		save["wallet"] = {}
	(save["wallet"] as Dictionary)["euros"] = 0
	(save["wallet"] as Dictionary)["tokens"] = 0

	# --- RESET COACHS ---
	save["coachs"] = {
		"owned": [],
		"active": "",
		"last_hired_season": 0
	}

	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}
	(save["finance"] as Dictionary)["euros"] = 0

	# Travaux stade / coûts reportés
	save["travaux_stade"] = 0
	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}
	(save["finance"] as Dictionary)["total_cout_evolution_stade"] = 0
	(save["finance"] as Dictionary)["dernier_achat_stade_cout"] = 0
	(save["finance"] as Dictionary)["dernier_achat_stade_label"] = ""

	if not save.has("stadium") or typeof(save["stadium"]) != TYPE_DICTIONARY:
		save["stadium"] = {}
	var stadium: Dictionary = save["stadium"] as Dictionary
	stadium["travaux_en_cours"] = false
	stadium["travaux_cible_ng"] = 0
	stadium["travaux_cible_ns"] = 0
	stadium["travaux_matches_restants"] = 0
	stadium["travaux_duree_totale"] = 0
	stadium["travaux_baseline_matchs_saison"] = 0

	# Ticketing
	# Nouvelle équipe : aucune ancienne configuration billetterie ne doit survivre.
	save["ticketing"] = {}
	if not save.has("stadium") or typeof(save["stadium"]) != TYPE_DICTIONARY:
		save["stadium"] = {}
	var stadium_ticketing_holder: Dictionary = save["stadium"] as Dictionary
	stadium_ticketing_holder["ticketing"] = {}

	# Shop
	save["shop"] = {}
	save["shop_total_forecast"] = 0

# L1 étape A : helpers purs, volontairement sans appelant dans le jeu.
# La provenance est une attestation explicite fournie par un futur appelant
# de confiance, jamais déduite d'un nom d'alias ou de l'amplitude d'une valeur.
# Aucun de ces helpers ne charge, répare ou modifie un dictionnaire/sauvegarde.
static func _l1_is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

static func _l1_accuracy_points(player: Dictionary, unit: String) -> Dictionary:
	if not player.has("precision"):
		return {"status": "MISSING", "field": "precision"}
	if unit != "fraction" and unit != "points":
		return {"status": "AMBIGUOUS", "field": "precision"}
	var value: Variant = player["precision"]
	var maximum := 1.0 if unit == "fraction" else 100.0
	if not _l1_is_number(value) or float(value) < 0.0 or float(value) > maximum:
		return {"status": "INVALID", "field": "precision"}
	return {"status": "OK", "value": float(value) * (100.0 if unit == "fraction" else 1.0)}

# Appel direct : entrées canoniques complètes, Accuracy fraction par défaut.
# "points" est réservé à une unité legacy explicitement attestée.
static func _l1_calc_c36(player: Dictionary, accuracy_unit: String = "fraction") -> Dictionary:
	var accuracy := _l1_accuracy_points(player, accuracy_unit)
	if accuracy.status != "OK":
		return accuracy
	for field in ["tir", "vitesse", "force", "defense", "endurance", "motivation", "age", "matchs_consecutifs", "repos_consecutifs", "matches_conval", "blessure", "poste"]:
		if not player.has(field):
			return {"status": "MISSING", "field": field}
	for field in ["tir", "vitesse", "force", "defense", "endurance", "motivation"]:
		if not _l1_is_number(player[field]) or float(player[field]) < 0.0 or float(player[field]) > 100.0:
			return {"status": "INVALID", "field": field}
	for field in ["age", "matchs_consecutifs", "repos_consecutifs", "matches_conval"]:
		if not _l1_is_number(player[field]) or float(player[field]) < 0.0 or floor(float(player[field])) != float(player[field]):
			return {"status": "INVALID", "field": field}
	if float(player.age) == 0.0 or typeof(player.blessure) != TYPE_BOOL or typeof(player.poste) != TYPE_STRING:
		return {"status": "INVALID", "field": "age/blessure/poste"}
	var a: float = accuracy.value
	var t: float = float(player.tir)
	var v: float = float(player.vitesse)
	var f: float = float(player.force)
	var d: float = float(player.defense)
	var e: float = float(player.endurance)
	var quality: float
	match player.poste:
		"Meneur": quality = a * 0.20 + t * 0.10 + v * 0.30 + e * 0.20 + d * 0.10 + f * 0.10
		"Ailier": quality = a * 0.18 + t * 0.12 + v * 0.22 + f * 0.20 + d * 0.13 + e * 0.15
		"Pivot": quality = f * 0.30 + d * 0.25 + a * 0.10 + t * 0.05 + e * 0.15 + v * 0.15
		"Arrière": quality = a * 0.18 + t * 0.10 + v * 0.28 + e * 0.20 + d * 0.14 + f * 0.10
		_: quality = a * 0.18 + t * 0.10 + v * 0.22 + f * 0.20 + d * 0.15 + e * 0.15
	var age: float = float(player.age)
	var age_coef: float = 0.85
	if age <= 20.0:
		age_coef = 0.90
	elif age <= 24.0:
		age_coef = lerpf(0.90, 1.00, (age - 20.0) / 4.0)
	elif age <= 28.0:
		age_coef = lerpf(1.00, 1.05, (age - 24.0) / 4.0)
	elif age <= 32.0:
		age_coef = lerpf(1.05, 0.95, (age - 28.0) / 4.0)
	elif age < 36.0:
		age_coef = lerpf(0.95, 0.85, (age - 32.0) / 4.0)
	var consecutive: float = float(player.matchs_consecutifs)
	var match_coef := 0.92 if consecutive >= 8.0 else (0.95 if consecutive >= 6.0 else 1.0)
	var rest: float = float(player.repos_consecutifs)
	var rest_coef := 1.04 if rest >= 2.0 else (1.02 if rest == 1.0 else 1.0)
	var injury_coef := 0.70 if player.blessure or float(player.matches_conval) > 0.0 else 1.0
	var motivation_coef := 1.0 + (float(player.motivation) - 80.0) / 200.0
	return {"status": "OK", "value": snapped(quality * age_coef * match_coef * rest_coef * injury_coef * motivation_coef, 0.01), "source": "C36_RP_M200"}

# Contrat d'attestation en mémoire (aucun nouveau champ de sauvegarde) :
# source non vide ; kind = canonical / derived_c36 / native / derived.
# canonical : nouvelles données, fraction obligatoire ; derived_c36 : formule
# C36 explicitement autorisée et accuracy_unit explicitement attestée.
# native/derived : field + min/max + version attestent l'alias et son domaine.
# invalid_zero_fields ne contient QUE des sentinelles prouvées ; un autre
# champ faisant autorité doit être fourni. Le brut n'est jamais supprimé.
static func _l1_resolve_rating(player: Dictionary, provenance: Dictionary = {}) -> Dictionary:
	if provenance.is_empty():
		for field in ["overall", "rating", "pondération", "ponderation", "note"]:
			if player.has(field):
				return {"status": "AMBIGUOUS", "field": field}
		return {"status": "MISSING", "field": "rating_provenance"}
	if typeof(provenance.get("source")) != TYPE_STRING or str(provenance.source).strip_edges() == "":
		return {"status": "INVALID", "field": "provenance.source"}
	var invalid_zeros: Variant = provenance.get("invalid_zero_fields", [])
	if not invalid_zeros is Array:
		return {"status": "INVALID", "field": "invalid_zero_fields"}
	for field in invalid_zeros:
		if typeof(field) != TYPE_STRING or field not in ["overall", "rating", "pondération", "ponderation", "note"]:
			return {"status": "INVALID", "field": "invalid_zero_fields"}
		if not player.has(field) or not _l1_is_number(player[field]) or float(player[field]) != 0.0:
			return {"status": "CONFLICT", "field": field}
	var kind: Variant = provenance.get("kind")
	if typeof(kind) != TYPE_STRING:
		return {"status": "INVALID", "field": "provenance.kind"}
	if kind == "canonical" or kind == "derived_c36":
		var unit: Variant = provenance.get("accuracy_unit")
		if typeof(unit) != TYPE_STRING or unit not in ["fraction", "points"]:
			return {"status": "AMBIGUOUS", "field": "precision"}
		if kind == "canonical" and unit != "fraction":
			return {"status": "CONFLICT", "field": "precision"}
		return _l1_calc_c36(player, unit)
	if kind != "native" and kind != "derived":
		return {"status": "AMBIGUOUS", "field": "provenance.kind"}
	var field: Variant = provenance.get("field")
	if typeof(field) != TYPE_STRING or field not in ["overall", "rating", "pondération", "ponderation", "note"]:
		return {"status": "INVALID", "field": "provenance.field"}
	if field in invalid_zeros:
		return {"status": "CONFLICT", "field": field}
	if typeof(provenance.get("version")) != TYPE_STRING or str(provenance.version).strip_edges() == "":
		return {"status": "INVALID", "field": "provenance.version"}
	if not _l1_is_number(provenance.get("min")) or not _l1_is_number(provenance.get("max")) or float(provenance.min) > float(provenance.max):
		return {"status": "INVALID", "field": "provenance.domain"}
	if not player.has(field):
		return {"status": "MISSING", "field": field}
	var value: Variant = player[field]
	if not _l1_is_number(value) or float(value) < float(provenance.min) or float(value) > float(provenance.max):
		return {"status": "INVALID", "field": field}
	return {"status": "OK", "value": float(value), "source": provenance.source, "field": field, "version": provenance.version}

# L1C : provenance par joueur, sans migration ni lecture de sauvegarde.
static func _l1_player_rating(player: Dictionary) -> Dictionary:
	var provenance: Variant = player.get("rating_provenance", {})
	if not provenance is Dictionary:
		return {"status": "INVALID", "field": "rating_provenance"}
	return _l1_resolve_rating(player, provenance)

static func _l1_player_force(player: Dictionary) -> Dictionary:
	var rating := _l1_player_rating(player)
	if rating.status != "OK":
		return rating
	for field in ["motivation", "fatigue"]:
		if not _l1_is_number(player.get(field)) or float(player[field]) < 0.0 or float(player[field]) > 100.0:
			return {"status": "INVALID", "field": field}
	var tir: float
	if player.has("tir"):
		if not _l1_is_number(player.tir) or float(player.tir) < 0.0 or float(player.tir) > 100.0:
			return {"status": "INVALID", "field": "tir"}
		tir = float(player.tir)
		# Conserver le canal de tir effectif existant, coefficients inchangés.
		if tir <= 1.5:
			tir *= 100.0
	else:
		var provenance: Dictionary = player.get("rating_provenance", {})
		var unit: Variant = provenance.get("accuracy_unit", "")
		if not unit is String:
			return {"status": "INVALID", "field": "precision"}
		var accuracy := _l1_accuracy_points(player, unit)
		if accuracy.status != "OK":
			return accuracy
		tir = accuracy.value
	var effective := tir * (0.75 + float(player.motivation) / 200.0) * (1.0 - float(player.fatigue) / 200.0)
	return {"status": "OK", "rating": rating.value, "value": float(rating.value) + (effective - 70.0) * 0.18}

static func _l1_coach_score(player: Dictionary, coach: String) -> Dictionary:
	var force := _l1_player_force(player)
	if force.status != "OK":
		return force
	var motivation := float(player.motivation)
	var fatigue := float(player.fatigue)
	var value: float = force.value
	match coach:
		"coach_junior": value = value + motivation * 0.04 - fatigue * 0.06
		"coach_confirme": value = value + motivation * 0.10 - fatigue * 0.18
		"coach_elite": value = value + motivation * 0.14 - fatigue * 0.28
		_: value = value + motivation * 0.08 - fatigue * 0.12
	return {"status": "OK", "value": value, "rating": force.rating}

static func _l1_id_key(value: Variant) -> String:
	if value is String:
		if not value.is_valid_int() or value != str(value.to_int()) or value.to_int() < 0:
			return ""
		return value
	if _l1_is_number(value) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and floor(float(value)) == float(value):
		return str(int(value))
	return ""

# Manuel explicite : exactement huit. Sinon conserver la priorité actuelle :
# huit IDs enregistrés, puis coach, puis selected_ids avant déblocage seulement.
static func _l1_validate_lineup(save: Dictionary, manual_ids: Variant = null) -> Dictionary:
	if not save.get("roster") is Dictionary or not save.get("players_by_id") is Dictionary:
		return {"status": "INVALID", "field": "roster/players_by_id"}
	var roster: Dictionary = save.roster
	var by_id: Dictionary = save.players_by_id
	var ids: Variant = roster.get("match_selected_ids", [])
	if not ids is Array:
		return {"status": "INVALID", "field": "match_selected_ids"}
	var coach := ""
	if save.get("coachs") is Dictionary:
		coach = str(save.coachs.get("active", "")).strip_edges()
	var automatic := false
	if manual_ids != null:
		if not manual_ids is Array or manual_ids.size() != 8:
			return {"status": "INVALID_COMPOSITION"}
		ids = manual_ids
	elif ids.size() != 8:
		var round_now := int(save.get("season_round", 0))
		var season := int(save.get("season_number", 1))
		var unlocked := round_now >= 5 if season <= 1 else round_now >= 0
		if coach == "" and unlocked:
			return {"status": "INVALID_COMPOSITION"}
		ids = roster.get("selected_ids", [])
		automatic = coach != ""
	if not ids is Array or ids.is_empty() or (automatic and ids.size() < 8):
		return {"status": "INVALID_COMPOSITION"}
	var seen: Dictionary = {}
	var rows: Array = []
	for id in ids:
		var key := _l1_id_key(id)
		if key == "" or seen.has(key) or not by_id.get(key) is Dictionary:
			return {"status": "INVALID_ID", "id": str(id)}
		seen[key] = true
		var player: Dictionary = by_id[key]
		if player.has("id") and _l1_id_key(player.id) != key:
			return {"status": "CONFLICT", "id": key}
		var force := _l1_player_force(player)
		if force.status != "OK":
			force["id"] = key
			return force
		var score := _l1_coach_score(player, coach) if automatic else force
		if score.status != "OK":
			score["id"] = key
			return score
		rows.append({"id": int(key), "player": player.duplicate(true), "force": force.value, "rating": force.rating, "score": score.value})
	if automatic:
		rows.sort_custom(func(a, b): return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0)))
		rows = rows.slice(0, 8)
	var played: Array = []
	var players: Array = []
	var total := 0.0
	for row in rows:
		played.append(row.id)
		players.append(row.player)
		total += float(row.force)
	return {"status": "OK", "ids": played, "players": players, "force": total / float(rows.size())}

static func _l1_lineup_error_text(result: Dictionary) -> String:
	if "SALARY" in str(result.get("status", "")):
		return "Match not started: %s (player %s). An annual contract must be verified before a new salary charge." % [str(result.status), str(result.get("id", "?"))]
	return "Match not started: %s (player %s). Choose a lineup with verified player ratings." % [str(result.get("status", "INVALID")), str(result.get("id", "?"))]

# L2 : seuls les caches C36 explicitement attestés peuvent être actualisés.
static func _l2_refresh_rating(p: Dictionary) -> void:
	var proof: Variant = p.get("rating_provenance", {})
	if not proof is Dictionary or proof.get("kind") not in ["canonical", "derived_c36"]:
		return
	var result := _l1_player_rating(p)
	if result.status != "OK":
		return
	for field in ["pondération", "ponderation"]:
		if field in proof.get("invalid_zero_fields", []):
			continue
		if field == "pondération" or p.has(field):
			p[field] = result.value

# Une collision de clés ou un conflit avec l'identité interdit la synchronisation.
static func _l2_sport_index(by_id: Dictionary) -> Dictionary:
	var index := {}
	var rejected := {}
	for raw in by_id:
		var key := _l1_id_key(raw)
		if key == "" or not by_id[raw] is Dictionary:
			continue
		var p: Dictionary = by_id[raw]
		if index.has(key) or (p.has("id") and _l1_id_key(p.id) != key):
			rejected[key] = true
		index[key] = raw
	for key in rejected:
		index.erase(key)
	return index

static func _l2_sync_sport_copies(save: Dictionary, new_season: bool = false) -> void:
	if not save.get("players") is Array or not save.get("players_by_id") is Dictionary:
		return
	var by_id: Dictionary = save.players_by_id
	var index := _l2_sport_index(by_id)
	var fields := ["fatigue", "motivation", "matchs_consecutifs", "repos_consecutifs"]
	if new_season:
		fields.append("age")
	else:
		fields.append_array(["blessure", "matches_conval", "pct_2pts", "pct_3pts"])
	for row in save.players:
		if not row is Dictionary:
			continue
		var key := _l1_id_key(row.get("id"))
		if not index.has(key):
			continue
		var source: Dictionary = by_id[index[key]]
		for field in fields:
			if source.has(field):
				row[field] = source[field]
		# Ne jamais écraser une note native/ambiguë ni importer une provenance.
		var proof: Variant = source.get("rating_provenance", {})
		if proof is Dictionary and proof.get("kind") in ["canonical", "derived_c36"] and row.get("rating_provenance", {}) == proof:
			var result := _l1_player_rating(source)
			if result.status == "OK":
				for field in ["pondération", "ponderation"]:
					if field not in proof.get("invalid_zero_fields", []) and (field == "pondération" or row.has(field)):
						row[field] = result.value

# L3 : les listes de licences sont des preuves de propriété, jamais le catalogue.
# Les chaînes entières et leur représentation historique exacte « n.0 » sont admises.
static func _l3_license_id(value: Variant) -> String:
	var key := _l1_id_key(value)
	if key == "" and value is String and value.ends_with(".0"):
		key = _l1_id_key(value.trim_suffix(".0"))
	return key

static func _l3_licensed_pool(save: Dictionary) -> Dictionary:
	var result := {"status":"OK", "ids":[], "players":[], "by_id":{}, "errors":[]}
	if not save.get("players_by_id") is Dictionary or not save.get("roster") is Dictionary:
		result.status = "INVALID_LICENSE"
		return result
	var index := {}
	var conflicts := {}
	for raw in save.players_by_id:
		var key := _l3_license_id(raw)
		if key == "":
			continue
		var player: Variant = save.players_by_id[raw]
		if index.has(key) or not player is Dictionary:
			conflicts[key] = true
		elif player.has("id") and _l3_license_id(player.id) != key:
			conflicts[key] = true
		index[key] = player
	var sources: Array = [save.roster.get("selected_ids", [])]
	if save.has("mercato"):
		if not save.mercato is Dictionary:
			result.status = "INVALID_LICENSE"
			return result
		sources.append(save.mercato.get("purchased_ids", []))
	for ids in sources:
		if not ids is Array:
			result.errors.append({"status":"INVALID_LICENSE"})
			continue
		for raw in ids:
			var key := _l3_license_id(raw)
			if key == "" or conflicts.has(key) or not index.has(key):
				result.errors.append({"status":"INVALID_LICENSE", "id":str(raw)})
				continue
			if result.by_id.has(key):
				continue
			var player: Dictionary = index[key].duplicate(true)
			player["id"] = int(key) # vue locale uniquement ; catalogue inchangé
			result.ids.append(int(key))
			result.players.append(player)
			result.by_id[key] = player
	if not result.errors.is_empty():
		result.status = "INVALID_LICENSE"
	return result

# Adapter uniquement une vue locale aux règles L1 ; ni formule ni sauvegarde modifiée.
static func _l3_validate_lineup(save: Dictionary, manual_ids: Variant = null) -> Dictionary:
	var payroll := _l4_payroll(save)
	if payroll.status != "OK":
		return payroll
	var pool := _l3_licensed_pool(save)
	if not save.get("roster") is Dictionary:
		return {"status":"INVALID_LICENSE"}
	var ids: Variant = manual_ids if manual_ids != null else save.roster.get("match_selected_ids", [])
	if not ids is Array:
		return {"status":"INVALID_COMPOSITION"}
	var explicit: bool = manual_ids != null or ids.size() == 8
	var normalized: Array = []
	if explicit:
		for raw in ids:
			var key := _l3_license_id(raw)
			if key == "" or not pool.by_id.has(key):
				return {"status":"INVALID_LICENSE", "id":str(raw)}
			normalized.append(int(key))
	elif pool.status != "OK":
		return pool.errors[0] if not pool.errors.is_empty() else {"status":"INVALID_LICENSE"}
	elif bool(save.roster.get("auto_save_match_selection_paid", false)) and int(save.roster.get("auto_save_match_selection_matches_left", 5)) > 0:
		# Un droit payé avec composition incomplète exige une reconfirmation gratuite.
		return {"status":"INVALID_COMPOSITION"}
	var view := save.duplicate(false)
	view["players_by_id"] = pool.by_id
	view["roster"] = save.roster.duplicate(true)
	view.roster["selected_ids"] = pool.ids
	view.roster["match_selected_ids"] = normalized if explicit else ids
	return _l1_validate_lineup(view, normalized if manual_ids != null else null)

# Contrat annuel enregistré : présence explicite, nombre fini non négatif,
# et absence de contradiction entre les deux alias historiques.
static func _l4_annual_contract(player: Dictionary) -> Dictionary:
	var amount: Variant = null
	for field in ["salaire", "salary"]:
		if not player.has(field):
			continue
		var raw: Variant = player[field]
		if not _l1_is_number(raw) or float(raw) < 0.0 or float(raw) > 9007199254740991.0:
			return {"status":"INVALID_SALARY", "field":field}
		if amount != null and float(raw) != float(amount):
			return {"status":"AMBIGUOUS_SALARY"}
		amount = raw
	if amount == null:
		return {"status":"MISSING_SALARY"}
	return {"status":"OK", "annual":int(amount)}

static func _l4_payroll(save: Dictionary) -> Dictionary:
	var pool := _l3_licensed_pool(save)
	if pool.status != "OK":
		return {"status":"INVALID_SALARY_LICENSE", "details":pool.errors}
	var contracts := {}
	var total_season := 0
	var annual_total := 0
	var season_number := int(save.get("season_number", 1))
	var inflation_coef := 1.0
	if season_number >= 3:
		inflation_coef = pow(1.04, float(season_number - 2))
	for player in pool.players:
		var contract := _l4_annual_contract(player)
		if contract.status != "OK":
			contract["id"] = str(player.id)
			return contract
		contracts[str(player.id)] = contract.annual
		annual_total += int(contract.annual)
		total_season += int(round(float(contract.annual) * inflation_coef))
	var leagues = preload("res://scripts/LeagueData.gd")
	var league_id := str(save.get("league_id", leagues.get_default_league_id())).strip_edges()
	if league_id == "": league_id = leagues.get_default_league_id()
	var salary_league_coef: float = leagues.get_coef(league_id, "salary")
	var per_match := int(round(float(total_season) * salary_league_coef / 22.0))
	return {"status":"OK", "contracts":contracts, "annual_total":annual_total, "per_match":maxi(0, per_match)}

# Protect only opted-in championship careers; keep historical callers/signatures.
static func _l5_legacy_write_allowed(path: String, data: Variant) -> bool:
	if not FileAccess.file_exists(path): return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return false
	var old: Dictionary = parser.data
	if not old.has("l5_match"): return true
	if not data is Dictionary: return false
	if old.get("profile_id") != data.get("profile_id") or old.get("career_id") != data.get("career_id"): return false
	if not old.l5_match is Dictionary or not data.get("l5_match") is Dictionary: return false
	if old.l5_match.has("pending"): return false
	return JSON.stringify(JSON.parse_string(JSON.stringify(old.l5_match))) == JSON.stringify(JSON.parse_string(JSON.stringify(data.l5_match)))

# Opted-in careers keep their receipt safe on subsequent historical writes too.
# Returns whether the protected path was handled (success or explicit refusal).
static func _l5_publish_existing(path: String, data: Variant) -> bool:
	if not data is Dictionary or not data.has("l5_match"): return false
	if not data.l5_match is Dictionary:
		push_error("L5: invalid protected metadata")
		return true
	var io = load("res://scripts/LocalIO.gd").new(ProjectSettings.globalize_path(path).get_base_dir())
	var current: Dictionary = io.read_career()
	if current.status != "OK" or ProjectSettings.globalize_path(io._context.get("path", "")) != ProjectSettings.globalize_path(path) or not _l5_legacy_write_allowed(path, data):
		push_error("L5: protected write refused; career or revision conflict")
		return true
	var next: Dictionary = data.duplicate(true)
	next.l5_match["revision"] = maxi(int(current.data.get("l5_match", {}).get("revision", 0)), int(data.l5_match.get("revision", 0))) + 1
	var result: Dictionary = io.write_verified(next)
	if result.status != "COMMITTED":
		push_error("L5: protected write failed: " + str(result.status))
	else:
		data["l5_match"] = next.l5_match.duplicate(true)
	return true
