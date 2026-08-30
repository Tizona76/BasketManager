extends Node

# ⚠️ IMPORTANT : on ne lit PLUS user://session.json ici.
# La persistance est gérée uniquement par Bootstrap.

const DEFAULT_PROFILE_UUID := "TEST_UUID_EMPTY_001"

var access_token: String = ""
var refresh_token: String = ""
var token_type: String = "Bearer"

var profile_uuid: String = ""

# Meta cloud (prévu pour plus tard, checksum inclus)
var cloud_rev: int = 0
var cloud_checksum: String = ""
var cloud_meta_by_career: Dictionary = {}

const SESSION_MARK := "SESSION_vLOCK_001"


func set_tokens(at: Variant, rt: Variant, tt: Variant) -> void:
	access_token = str(at if at != null else "").strip_edges()
	refresh_token = str(rt if rt != null else "").strip_edges()
	token_type = str(tt if tt != null else "Bearer").strip_edges()

	if token_type.to_lower() == "bearer":
		token_type = "Bearer"


func set_access_token(v: Variant) -> void:
	# Empêche "true"/"false" de remplacer un vrai token
	var s := str(v if v != null else "").strip_edges()
	if s == "true" or s == "false":
		push_warning("[SESSION] refuse access_token bool-like: %s" % s)
		return
	access_token = s


func _cloud_career_key(career_id: Variant) -> String:
	return str(career_id if career_id != null else "").strip_edges()


func _coerce_cloud_rev(rev: Variant) -> int:
	var r_str := str(rev if rev != null else "").strip_edges()
	if r_str == "":
		return 0
	return int(r_str)


func set_cloud_meta(rev: Variant, checksum: Variant) -> void:
	# Compat globale conservée; le cloud multi-careers utilise set_cloud_meta_for_career().
	cloud_rev = _coerce_cloud_rev(rev)
	cloud_checksum = str(checksum if checksum != null else "").strip_edges()


func set_cloud_meta_for_career(career_id: Variant, rev: Variant, checksum: Variant) -> void:
	var key := _cloud_career_key(career_id)
	if key == "":
		return
	var r_int := _coerce_cloud_rev(rev)
	var chk := str(checksum if checksum != null else "").strip_edges()
	cloud_meta_by_career[key] = {"rev": r_int, "checksum": chk}
	set_cloud_meta(r_int, chk)


func get_cloud_rev_for_career(career_id: Variant) -> int:
	var key := _cloud_career_key(career_id)
	if key == "" or not cloud_meta_by_career.has(key):
		return 0
	var meta: Variant = cloud_meta_by_career.get(key)
	if typeof(meta) != TYPE_DICTIONARY:
		return 0
	return _coerce_cloud_rev((meta as Dictionary).get("rev", 0))


func get_cloud_checksum_for_career(career_id: Variant) -> String:
	var key := _cloud_career_key(career_id)
	if key == "" or not cloud_meta_by_career.has(key):
		return ""
	var meta: Variant = cloud_meta_by_career.get(key)
	if typeof(meta) != TYPE_DICTIONARY:
		return ""
	return str((meta as Dictionary).get("checksum", "")).strip_edges()


func is_profile_forced() -> bool:
	# Règle : si ce n'est pas vide et ≠ DEFAULT, on considère "forcé"
	var cur := str(profile_uuid).strip_edges()
	return (cur != "" and cur != DEFAULT_PROFILE_UUID)
