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
	var mutex: Mutex
	var old := _read(_context.path)
	if steam_document(data) or (old.status == "OK" and steam_document(old.data)):
		mutex = _steam_mutex(ProjectSettings.globalize_path(_context.path))
		if not mutex.try_lock():
			_busy = false
			return _error("BUSY")
	var result := _publish(data)
	if mutex != null: mutex.unlock()
	if result.status == "COMMITTED" and result.has("steam_local"): data["_steam_local"] = result.steam_local.duplicate(true)
	_busy = false
	return result

func _publish(data: Dictionary) -> Dictionary:
	var route := _route()
	if route.status != "OK" or route != {"status":"OK","profile":_context.profile,"career":_context.career,"path":_context.path,"routing":_context.routing}: return _error("CONTEXT_CHANGED")
	if data.get("profile_id") != _context.profile or data.get("career_id") != _context.career: return _error("IDENTITY_CHANGED")
	var old := _read(_context.path)
	if old.status != "OK": return _error("READ_FAILED")
	if old.hash != _context.hash: return _error("STALE")
	if steam_document(old.data) or steam_document(data):
		var transition: bool = _steam_transition != "" and _steam_transition == JSON.stringify(data)
		if not _steam_valid(data): return _error("INVALID_STEAM_STATE")
		if steam_document(old.data):
			if not _steam_valid(old.data): return _error("INVALID_STEAM_STATE")
			if data._steam_local.generation != old.data._steam_local.generation: return _error("STALE")
			if not _steam_same(data.steam_wallet.binding,old.data.steam_wallet.binding): return _error("DESTINATION_CONFLICT")
			if not transition and (not _steam_same(data._steam_local,old.data._steam_local) or not _steam_same(data.steam_wallet,old.data.steam_wallet)): return _error("STEAM_METADATA_CONFLICT")
		elif not transition: return _error("ENROLLMENT_REQUIRED")
		data = data.duplicate(true)
		data._steam_local.generation = int(data._steam_local.generation) + 1
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
	if final.status != "OK" or final.hash != _hash(bytes): return {"status":"INDETERMINATE_AFTER_REPLACE","path":route.path,"backup":backup,"expected_hash":_hash(bytes),"steam_local":data.get("_steam_local",{})}
	var result := {"status":"COMMITTED","path":route.path,"backup":backup,"expected_hash":final.hash}
	if steam_document(data): result["steam_local"] = data._steam_local.duplicate(true)
	return result

# An indeterminate rename is resolved only by an exact reread, never by retrying.
func write_verified(data: Dictionary) -> Dictionary:
	var result := write_career(data)
	if result.status != "INDETERMINATE_AFTER_REPLACE": return result
	var check := _read(result.path)
	if check.status == "OK" and check.hash == result.expected_hash and check.data is Dictionary and check.data.get("profile_id") == data.get("profile_id") and check.data.get("career_id") == data.get("career_id"):
		result.status = "COMMITTED"
		result["verified_after_indeterminate"] = true
		if steam_document(check.data): data["_steam_local"] = check.data._steam_local.duplicate(true)
	return result

# A5 only: explicit enrollment/credit requires Windows Steam. Existing enrolled
# documents retain their protection even when payments/features are disabled.
static var _steam_locks: Dictionary = {}
static var _steam_locks_guard := Mutex.new()
var _steam_transition := ""

func _steam_enabled() -> bool:
	return OS.get_name() == "Windows" and OS.has_feature("steam")

static func _steam_same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

static func steam_document(data: Variant) -> bool:
	return data is Dictionary and data.has("_steam_local")

static func _steam_mutex(path: String) -> Mutex:
	_steam_locks_guard.lock()
	if not _steam_locks.has(path): _steam_locks[path] = Mutex.new()
	var mutex: Mutex = _steam_locks[path]
	_steam_locks_guard.unlock()
	return mutex

func _steam_valid(data: Dictionary) -> bool:
	var s: Variant = data.get("_steam_local")
	var w: Variant = data.get("steam_wallet")
	if not s is Dictionary or s.get("version") != 1 or not s.get("generation") is float and not s.get("generation") is int: return false
	if s.generation < 0 or s.generation != floor(s.generation) or s.generation >= 9007199254740991: return false
	if s.get("local_profile_id") != data.get("profile_id") or not w is Dictionary or not w.get("binding") is Dictionary or not w.get("applied_receipts") is Dictionary: return false
	if w.binding.get("career_id") != data.get("career_id") or not _id(w.binding.get("user_id")) or not _id(w.binding.get("profile_uuid")): return false
	if not s.has("pending") or (s.pending != null and not s.pending is Dictionary): return false
	var rev: Variant = s.get("server_revision")
	return (rev is int or rev is float) and is_finite(float(rev)) and rev == floor(float(rev)) and rev >= 1 and rev < 9007199254740991 and _steam_hex(s.get("server_checkpoint_hash"))

static func _steam_hex(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c in value:
		if not (c >= "0" and c <= "9" or c >= "a" and c <= "f"): return false
	return true

static func steam_snapshot(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	copy.erase("_steam_local")
	return copy

func steam_expected(session_binding: Dictionary) -> Dictionary:
	# Call after read_career; the session binding is supplied by authenticated code.
	if _context.is_empty(): return {}
	var current := _read(_context.path)
	if current.status != "OK" or current.hash != _context.hash: return {}
	return {"file_hash":current.hash,"generation":current.data.get("_steam_local",{}).get("generation",0),
		"local_profile_id":_context.profile,"career_id":_context.career,"binding":session_binding.duplicate(true)}

func _steam_current(expected: Dictionary) -> Dictionary:
	var current := read_career()
	if current.status != "OK": return current
	if expected.get("file_hash") != _context.hash or expected.get("local_profile_id") != _context.profile or expected.get("career_id") != _context.career: return _error("STALE")
	if expected.get("generation") != current.data.get("_steam_local",{}).get("generation",0): return _error("STALE")
	if steam_document(current.data) and (not _steam_valid(current.data) or not _steam_same(expected.get("binding"),current.data.steam_wallet.binding)): return _error("DESTINATION_CONFLICT")
	return current

func _steam_write(next: Dictionary) -> Dictionary:
	next = _steam_string_keys(next)
	# One-shot internal permission, checked against the exact candidate in _publish.
	_steam_transition = JSON.stringify(next)
	var result := write_verified(next)
	_steam_transition = ""
	return result

func write_steam_state(expected: Dictionary, state: Dictionary) -> Dictionary:
	if not _steam_enabled(): return _error("STEAM_DISABLED")
	var current := _steam_current(expected)
	if current.status != "OK": return current
	var data: Dictionary = current.data
	if data.get("l5_match",{}).has("pending"): return _error("L5_PENDING")
	var next := data.duplicate(true)
	match state.get("action"):
		"enroll":
			if steam_document(data) or data.has("steam_wallet"): return _error("ALREADY_ENROLLED")
			var binding: Variant = expected.get("binding")
			if not binding is Dictionary or not _id(binding.get("user_id")) or not _id(binding.get("profile_uuid")) or binding.get("career_id") != data.career_id: return _error("DESTINATION_CONFLICT")
			var rev: Variant = state.get("server_revision")
			if not (rev is int or rev is float) or not is_finite(float(rev)) or rev != floor(float(rev)) or rev < 1 or rev >= 9007199254740991 or not _steam_hex(state.get("server_checkpoint_hash")): return _error("INVALID_STATE")
			next.steam_wallet = {"binding":binding.duplicate(true),"applied_receipts":{}}
			next._steam_local = {"version":1,"local_profile_id":data.profile_id,"generation":0,
				"server_revision":state.server_revision,"server_checkpoint_hash":state.server_checkpoint_hash,"pending":null}
		"purchase_prepare":
			if not _steam_valid(data): return _error("INVALID_STATE")
			if data._steam_local.get("purchase") != null: return _error("ORDER_PENDING")
			if data._steam_local.pending != null or data._steam_local.get("cloud_pending") != null: return _error("DELIVERY_PENDING")
			var intent: Variant = state.get("intent")
			if not intent is Dictionary or not _id(intent.get("key")) or not intent.get("body") is Dictionary: return _error("INVALID_INTENT")
			var body: Dictionary = intent.body
			if body.keys().size() != 4 or body.get("pack_id") not in ["tokens25","tokens75","tokens150"] or body.get("language") not in ["en","fr","es","de","it","pt"]: return _error("INVALID_INTENT")
			if body.get("profile_uuid") != data.steam_wallet.binding.profile_uuid or body.get("career_id") != data.career_id: return _error("DESTINATION_CONFLICT")
			next._steam_local["purchase"] = {"key":intent.key,"body":body.duplicate(true),"order_id":"","reply":{}}
		"purchase_response":
			if not _steam_valid(data): return _error("INVALID_STATE")
			var intent: Variant = data._steam_local.get("purchase")
			var reply: Variant = state.get("reply")
			if not intent is Dictionary or state.get("key") != intent.key or not reply is Dictionary: return _error("ORDER_CONFLICT")
			var oid: Variant = reply.get("order_id")
			if not oid is String or not oid.is_valid_int() or oid.to_int() <= 0 or str(oid.to_int()) != oid: return _error("ORDER_CONFLICT")
			if intent.order_id != "" and intent.order_id != oid: return _error("ORDER_CONFLICT")
			if reply.get("profile_uuid") != intent.body.profile_uuid or reply.get("career_id") != intent.body.career_id or reply.get("pack_id") != intent.body.pack_id: return _error("DESTINATION_CONFLICT")
			next._steam_local.purchase.order_id = oid
			next._steam_local.purchase.reply = reply.duplicate(true)
		"purchase_complete":
			if not _steam_valid(data): return _error("INVALID_STATE")
			var intent: Variant = data._steam_local.get("purchase")
			if not intent is Dictionary or state.get("key") != intent.key: return _error("ORDER_CONFLICT")
			var reply: Dictionary = intent.reply
			var receipt: Variant = reply.get("receipt")
			var applied: bool = receipt is Dictionary and data.steam_wallet.applied_receipts.has(receipt.get("receipt_id", "")) and data._steam_local.pending == null
			if not applied and reply.get("state") not in ["FAILED","CANCELLED"]: return _error("ORDER_UNRESOLVED")
			# Retain completed intentions for diagnosis; never erase receipt markers.
			if not next._steam_local.has("purchase_history"): next._steam_local.purchase_history = {}
			next._steam_local.purchase_history[intent.key] = intent.duplicate(true)
			next._steam_local.purchase = null
		"checkpoint_prepare":
			if not _steam_valid(data) or data._steam_local.pending != null: return _error("DELIVERY_PENDING")
			if data._steam_local.get("cloud_pending") != null: return _error("CHECKPOINT_PENDING")
			var request: Variant = state.get("request")
			if not request is Dictionary or not _id(request.get("key")) or not request.get("body") is Dictionary: return _error("INVALID_STATE")
			var body: Dictionary = request.body
			if body.get("profile_uuid") != data.steam_wallet.binding.profile_uuid or body.get("career_id") != data.career_id or body.get("expected_revision") != data._steam_local.server_revision or body.get("parent_hash") != data._steam_local.server_checkpoint_hash or not _steam_checkpoint_same(body.get("snapshot"),steam_snapshot(data)): return _error("CHECKPOINT_CONFLICT")
			next._steam_local["cloud_pending"] = request.duplicate(true)
		"checkpoint_ack":
			if not _steam_valid(data) or data._steam_local.pending != null: return _error("DELIVERY_PENDING")
			var pending: Variant = data._steam_local.get("cloud_pending")
			var reply: Variant = state.get("reply")
			if not pending is Dictionary or not reply is Dictionary: return _error("CHECKPOINT_CONFLICT")
			var body: Dictionary = pending.body
			if state.get("key") != pending.key or body.expected_revision != data._steam_local.server_revision or body.parent_hash != data._steam_local.server_checkpoint_hash: return _error("CHECKPOINT_CONFLICT")
			if reply.get("profile_uuid") != body.profile_uuid or reply.get("career_id") != body.career_id or reply.get("revision") != body.expected_revision + 1 or not _steam_hex(reply.get("checkpoint_hash")) or not _steam_checkpoint_same(reply.get("snapshot"),body.snapshot): return _error("CHECKPOINT_CONFLICT")
			if not _steam_checkpoint_same(data.steam_wallet,body.snapshot.steam_wallet): return _error("RECEIPT_CONFLICT")
			# Only protocol metadata changes: preserve current local gains, spends and L5.
			next._steam_local.server_revision = reply.revision
			next._steam_local.server_checkpoint_hash = reply.checkpoint_hash
			next._steam_local["cloud_pending"] = null
		"prepare":
			if not _steam_valid(data) or data._steam_local.pending != null: return _error("DELIVERY_PENDING")
			var pending: Variant = state.get("pending")
			if data._steam_local.get("cloud_pending") != null: return _error("CHECKPOINT_PENDING")
			if not _steam_intent(pending,data): return _error("INVALID_INTENT")
			next._steam_local.pending = pending.duplicate(true)
		"ack":
			if not _steam_valid(data): return _error("INVALID_STATE")
			var proof := _steam_recovery(data)
			if proof.status != "COMMITTED": return proof
			var ack: Variant = state.get("ack")
			var pending: Dictionary = data._steam_local.pending
			if not ack is Dictionary or ack.get("operation_id") != pending.delivery.operation_id or ack.get("candidate_hash") != pending.delivery.candidate_hash or ack.get("revision") != pending.origin.revision + 1: return _error("ACK_CONFLICT")
			next._steam_local.server_revision = ack.revision
			next._steam_local.server_checkpoint_hash = ack.candidate_hash
			next._steam_local.pending = null
		_:
			return _error("INVALID_STATE")
	return _steam_write(next)

func _steam_intent(pending: Variant, data: Dictionary) -> bool:
	if not pending is Dictionary or pending.get("phase") != "intent" or not _id(pending.get("receipt_id")) or not _id(pending.get("idempotency_key")): return false
	var origin: Variant = pending.get("origin")
	if not origin is Dictionary: return false
	if not _steam_same(origin.get("snapshot"),steam_snapshot(data)): return false
	if not _steam_same({"user_id":origin.get("user_id"),"profile_uuid":origin.get("profile_uuid"),"career_id":origin.get("career_id")},data.steam_wallet.binding): return false
	if origin.get("revision") != data._steam_local.server_revision or origin.get("checkpoint_hash") != data._steam_local.server_checkpoint_hash: return false
	return not data.steam_wallet.applied_receipts.has(pending.receipt_id)

func commit_steam_delivery(delivery: Dictionary, expected: Dictionary) -> Dictionary:
	if not _steam_enabled(): return _error("STEAM_DISABLED")
	var current := _steam_current(expected)
	if current.status != "OK": return current
	var data: Dictionary = current.data
	if not _steam_valid(data) or not data._steam_local.pending is Dictionary: return _error("NO_INTENT")
	var pending: Dictionary = data._steam_local.pending
	if pending.get("phase") == "committed":
		if not _steam_same(delivery,pending.get("delivery")): return _error("RECEIPT_CONFLICT")
		return _steam_recovery(data) # already applied; never add again
	if data.get("l5_match",{}).has("pending"): return _error("L5_PENDING")
	if not _steam_intent(pending,data): return _error("STALE")
	if not load("res://scripts/SteamWallet.gd").verify_delivery(delivery,pending.origin,pending.receipt_id): return _error("RECEIPT_CONFLICT")
	var next: Dictionary = delivery.candidate.duplicate(true)
	# Record History atomically with the first local credit, never during receipt recovery.
	# Keep the server candidate/proof unchanged; History is local progress like gains/spends.
	load("res://scripts/PlayerLife.gd")._append_token_history(next, int(next.steam_wallet.applied_receipts[pending.receipt_id].quantity), "club_tokens.history.reason.token_pack")
	next._steam_local = data._steam_local.duplicate(true)
	next._steam_local.pending.phase = "committed"
	next._steam_local.pending.delivery = delivery.duplicate(true)
	next._steam_local.pending.commit_generation = int(data._steam_local.generation) + 1
	var result := _steam_write(next)
	if result.status != "COMMITTED": return result
	# Re-read through the active routing; proof is never fabricated from write intent.
	var verified := read_career()
	if verified.status != "OK": return _error("INDETERMINATE_AFTER_REPLACE")
	return _steam_recovery(verified.data)

func _steam_recovery(data: Dictionary) -> Dictionary:
	if not _steam_valid(data) or not data._steam_local.pending is Dictionary: return _error("NO_INTENT")
	var pending: Dictionary = data._steam_local.pending
	if pending.get("phase") == "intent":
		if not _steam_intent(pending,data): return _error("RESTORE_CONFLICT")
		return {"status":"INTENT","pending":pending.duplicate(true),"context":_steam_context(data)}
	if pending.get("phase") != "committed" or not pending.get("delivery") is Dictionary or not pending.get("origin") is Dictionary: return _error("INVALID_STATE")
	var d: Dictionary = pending.delivery
	if data._steam_local.generation < pending.get("commit_generation",INF): return _error("RESTORE_CONFLICT")
	if not load("res://scripts/SteamWallet.gd").verify_delivery(d,pending.origin,pending.get("receipt_id","")): return _error("RECEIPT_CONFLICT")
	if not _steam_same(data.steam_wallet,d.candidate.steam_wallet): return _error("RECEIPT_CONFLICT")
	return {"status":"COMMITTED","pending":pending.duplicate(true),"context":_steam_context(data),
		"proof":{"status":"COMMITTED","operation_id":d.operation_id,"candidate_hash":d.candidate_hash,"snapshot":d.candidate.duplicate(true)}}

func _steam_context(data: Dictionary) -> Dictionary:
	var ctx: Dictionary = data.steam_wallet.binding.duplicate(true)
	ctx.revision = data._steam_local.server_revision
	ctx.checkpoint_hash = data._steam_local.server_checkpoint_hash
	ctx.snapshot = steam_snapshot(data)
	return ctx

func read_steam_recovery(session_binding: Dictionary) -> Dictionary:
	var current := read_career()
	if current.status != "OK": return current
	if not _steam_valid(current.data) or not _steam_same(current.data.steam_wallet.binding,session_binding): return _error("DESTINATION_CONFLICT")
	return _steam_recovery(current.data)


static func _steam_string_keys(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value: out[str(key) if key is StringName else key] = _steam_string_keys(value[key])
		return out
	if value is Array:
		var out := []
		for item in value: out.append(_steam_string_keys(item))
		return out
	return value

static func _steam_checkpoint_same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
