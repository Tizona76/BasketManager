extends RefCounted
# Local opt-in operation. Main thread only, no await, no autoload/global manager.
var root: String
var _context: Dictionary = {}
var _busy := false

func _init(directory: String):
	root = directory

func _error(status: String, detail: String = "") -> Dictionary:
	return {"status":status,"detail":detail}

# JSON.new/parse/read/close pattern reused from ProfileManager._read_json.
func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var err := FileAccess.get_open_error()
		if err == ERR_FILE_NOT_FOUND: return _error("MISSING")
		if err == ERR_FILE_NO_PERMISSION: return _error("ACCESS_ERROR")
		return _error("IO_ERROR", str(err))
	var length := f.get_length()
	var bytes := f.get_buffer(length)
	var err := f.get_error()
	f.close()
	if bytes.size() != length or (err != OK and err != ERR_FILE_EOF): return _error("IO_ERROR")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return _error("INVALID_JSON")
	return {"status":"OK","data":parser.data,"hash":_hash(bytes)}

func _hash(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

func _id(value: Variant) -> bool:
	if not value is String or value == "": return false
	for c in value:
		if not (c >= "a" and c <= "z" or c >= "A" and c <= "Z" or c >= "0" and c <= "9" or c == "_" or c == "-"): return false
	return true

func _route() -> Dictionary:
	var p := _read(root.path_join("profiles.json"))
	if p.status != "OK" or not p.data is Dictionary: return _error("PATH_ERROR")
	var pid: Variant = p.data.get("active_profile_id")
	if not _id(pid): return _error("PATH_ERROR")
	var profiles: Variant = p.data.get("profiles")
	if not profiles is Array: return _error("PATH_ERROR")
	var found := 0
	for row in profiles:
		if row is Dictionary and row.get("id") == pid: found += 1
	if found != 1: return _error("PATH_ERROR")
	var i := _read(root.path_join("careers_" + pid + ".json"))
	if i.status != "OK" or not i.data is Dictionary: return _error("PATH_ERROR")
	var cid: Variant = i.data.get("active_career_id")
	if not _id(cid) or not i.data.get("careers") is Array: return _error("PATH_ERROR")
	found = 0
	for row in i.data.careers:
		if row is Dictionary and row.get("career_id") == cid: found += 1
	if found != 1: return _error("PATH_ERROR")
	return {"status":"OK","profile":pid,"career":cid,"path":root.path_join("save_"+pid+"_"+cid+".json"),"routing":p.hash+":"+i.hash}

func read_career(allow_unstamped_legacy: bool = false) -> Dictionary:
	_context.clear()
	var route := _route()
	if route.status != "OK": return route
	var value := _read(route.path)
	if value.status != "OK": return value
	if not value.data is Dictionary: return _error("INVALID_SCHEMA")
	if value.data.is_empty(): return _error("NOT_VALIDATED_CAREER")
	# This deliberately narrow future path requires explicit identity; no legacy guessing.
	if allow_unstamped_legacy and not value.data.has("l5_match"):
		# Explicit index + unique filename supply identity only when fields are absent.
		# Contradictions are never repaired; nothing is written by this read.
		if not value.data.has("profile_id"): value.data["profile_id"] = route.profile
		if not value.data.has("career_id"): value.data["career_id"] = route.career
	if value.data.get("profile_id") != route.profile or value.data.get("career_id") != route.career: return _error("PATH_ERROR")
	_context = route.duplicate(true)
	_context.hash = value.hash
	return {"status":"OK","data":value.data.duplicate(true)}

func _json_value(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int: return true
	if value is float: return is_finite(value)
	if value is Array:
		for item in value:
			if not _json_value(item): return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or not _json_value(value[key]): return false
		return true
	return false

func write_career(data: Dictionary) -> Dictionary:
	if _busy: return _error("BUSY")
	if _context.is_empty(): return _error("NO_CONTEXT")
	if not _json_value(data): return _error("INVALID_PAYLOAD")
	_busy = true
	var result := _publish(data)
	_busy = false
	return result

func _publish(data: Dictionary) -> Dictionary:
	var route := _route()
	if route.status != "OK" or route != {"status":"OK","profile":_context.profile,"career":_context.career,"path":_context.path,"routing":_context.routing}: return _error("CONTEXT_CHANGED")
	if data.get("profile_id") != _context.profile or data.get("career_id") != _context.career: return _error("IDENTITY_CHANGED")
	var old := _read(_context.path)
	if old.status != "OK": return _error("READ_FAILED")
	if old.hash != _context.hash: return _error("STALE")
	var bytes := JSON.stringify(data,"\t").to_utf8_buffer()
	var suffix := ".l0_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec())
	var tmp: String = _context.path + suffix + ".tmp"
	var backup: String = _context.path + suffix + ".bak"
	if FileAccess.file_exists(tmp) or FileAccess.file_exists(backup): return _error("COLLISION")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return _error("WRITE_FAILED", str(FileAccess.get_open_error()))
	f.store_buffer(bytes)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK: return _error("WRITE_FAILED",tmp)
	var check := _read(tmp)
	if check.status != "OK" or check.hash != _hash(bytes): return _error("TEMP_INVALID",tmp)
	if DirAccess.copy_absolute(_context.path,backup) != OK: return _error("BACKUP_FAILED")
	var previous := _read(backup)
	if previous.status != "OK" or previous.hash != _context.hash: return _error("BACKUP_FAILED")
	# Recheck under synchronous single-thread contract. Not an interprocess CAS.
	var current := _read(_context.path)
	if current.status != "OK" or current.hash != _context.hash: return _error("STALE")
	if _route() != route: return _error("CONTEXT_CHANGED")
	err = DirAccess.rename_absolute(tmp,_context.path)
	if err != OK: return _error("REPLACE_FAILED",str(err))
	_context.clear() # One-shot successful or uncertain operation, never global last-read state.
	var final := _read(route.path)
	if final.status != "OK" or final.hash != _hash(bytes): return {"status":"INDETERMINATE_AFTER_REPLACE","path":route.path,"backup":backup,"expected_hash":_hash(bytes)}
	return {"status":"COMMITTED","path":route.path,"backup":backup,"expected_hash":final.hash}

# An indeterminate rename is resolved only by an exact reread, never by retrying.
func write_verified(data: Dictionary) -> Dictionary:
	var result := write_career(data)
	if result.status != "INDETERMINATE_AFTER_REPLACE": return result
	var check := _read(result.path)
	if check.status == "OK" and check.hash == result.expected_hash and check.data is Dictionary and check.data.get("profile_id") == data.get("profile_id") and check.data.get("career_id") == data.get("career_id"):
		result.status = "COMMITTED"
		result["verified_after_indeterminate"] = true
	return result
