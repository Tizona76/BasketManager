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


func set_cloud_meta(rev: Variant, checksum: Variant) -> void:
	# rev attendu int, checksum string (on stocke même si vide)
	var r_str := str(rev if rev != null else "").strip_edges()
	var r_int: int = 0
	if r_str != "":
		r_int = int(r_str)

	cloud_rev = r_int
	cloud_checksum = str(checksum if checksum != null else "").strip_edges()


func is_profile_forced() -> bool:
	# Règle : si ce n'est pas vide et ≠ DEFAULT, on considère "forcé"
	var cur := str(profile_uuid).strip_edges()
	return (cur != "" and cur != DEFAULT_PROFILE_UUID)
