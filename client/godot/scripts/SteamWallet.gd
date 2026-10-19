extends RefCounted
## Isolated A5 protocol adapter. No autoload, native Steam, HTTPRequest, file I/O,
## gameplay calls or wallet writes. A trusted injected transport adds existing
## session authentication and calls receive() with decoded server responses.
## Candidate hashes are opaque SERVER hashes (Python canonical JSON), not local
## file hashes. Only a future verified persistence adapter may supply commit proof.
## Main-thread contract: no concurrent callers. All returned documents are copies.

const APP_ID := 5069970
const BUILD_FEATURE := "steam"
const API := "/v1/steam/wallet/deliveries"
var _active := false
var _transport: Callable
var _context: Dictionary = {}
var _origin: Dictionary = {}
var _epoch := 0
var _sequence := 0
var _inflight: Dictionary = {}
var _seen: Dictionary = {}
var _receipt := ""
var _key := ""
var _delivery: Dictionary = {}
var _proof: Dictionary = {}
var _suspended := false
var _acknowledged := false

func _environment_allowed() -> bool:
	# Tests override this method in a subclass; no runtime/platform override flag.
	return OS.get_name() == "Windows" and OS.has_feature(BUILD_FEATURE)

func _result(status: String) -> Dictionary:
	return {"status":status, "local_play_allowed":true}

func _suspend(reason: String) -> Dictionary:
	_suspended = true
	return _result(reason)

func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128: return false
	for c in value:
		if not (c >= "a" and c <= "z" or c >= "A" and c <= "Z" or c >= "0" and c <= "9" or c == "_" or c == "-"): return false
	return true

func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c in value:
		if not (c >= "0" and c <= "9" or c >= "a" and c <= "f"): return false
	return true

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= 9007199254740991

func _same(a: Variant, b: Variant) -> bool:
	# Normalize int/float representations from JSON; never used as server hashing.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

func _valid_context(ctx: Dictionary) -> bool:
	if not _id(ctx.get("user_id")) or not _id(ctx.get("profile_uuid")) or not _id(ctx.get("career_id")): return false
	if not _integer(ctx.get("revision")) or ctx.revision < 1 or not _hash(ctx.get("checkpoint_hash")): return false
	var save: Variant = ctx.get("snapshot")
	if not save is Dictionary or not save.get("wallet") is Dictionary or not _integer(save.wallet.get("tokens")): return false
	if save.has("career_id") and save.career_id != ctx.career_id: return false
	var meta: Variant = save.get("steam_wallet")
	if not meta is Dictionary or not meta.get("applied_receipts") is Dictionary: return false
	return _same(meta.get("binding"), {"user_id":ctx.user_id,"profile_uuid":ctx.profile_uuid,"career_id":ctx.career_id})

func enable(transport: Callable, context: Dictionary) -> Dictionary:
	if _active: return _result("ALREADY_ENABLED")
	if not _environment_allowed(): return _result("ENVIRONMENT_REFUSED")
	if not transport.is_valid() or not _valid_context(context): return _result("INVALID_CONTEXT")
	_transport = transport
	_context = context.duplicate(true)
	_context.snapshot = snapshot_for_server(_context.snapshot)
	_active = true
	return _result("READY")

func set_context(context: Dictionary) -> Dictionary:
	# Any identity/revision/local-snapshot change invalidates delayed responses.
	if not _active: return _result("DISABLED")
	if not _valid_context(context):
		_epoch += 1
		_context.clear()
		return _suspend("INVALID_CONTEXT")
	if _same(context, _context): return _result("UNCHANGED")
	_context = context.duplicate(true)
	_context.snapshot = snapshot_for_server(_context.snapshot)
	_epoch += 1
	if not _origin.is_empty():
		if _ack_context_valid(): return _result("LOCAL_PROGRESS_PRESERVED")
		return _suspend("CONTEXT_CHANGED")
	return _result("READY")

func prepare(receipt_id: String, idempotency_key: String) -> Dictionary:
	if not _active: return _result("DISABLED")
	if _suspended: return _result("SUSPENDED")
	if not _origin.is_empty(): return _result("OPERATION_EXISTS")
	if not _id(receipt_id) or not _id(idempotency_key): return _result("INVALID_REQUEST")
	if _context.snapshot.steam_wallet.applied_receipts.has(receipt_id): return _result("ALREADY_APPLIED")
	_receipt = receipt_id
	_key = idempotency_key
	_origin = _context.duplicate(true)
	return _send_prepare()

func _send_prepare() -> Dictionary:
	return _send("prepare", "POST", API, {
		"receipt_id":_receipt,"profile_uuid":_origin.profile_uuid,"career_id":_origin.career_id,
		"expected_revision":_origin.revision,"parent_hash":_origin.checkpoint_hash,
		"snapshot":_origin.snapshot.duplicate(true)}, {"Idempotency-Key":_key})

func _send(kind: String, method: String, path: String, body: Dictionary, headers: Dictionary = {}) -> Dictionary:
	_sequence += 1
	var request_id := str(_sequence)
	_inflight = {"id":request_id,"epoch":_epoch,"kind":kind}
	# No auth tokens retained here. Transport owns the authenticated session.
	_transport.call({"request_id":request_id,"method":method,"path":path,
		"body":body.duplicate(true),"headers":headers.duplicate(true)})
	return {"status":"REQUESTED","request_id":request_id,"local_play_allowed":true}

func receive(request_id: String, http_status: int, body: Dictionary) -> Dictionary:
	if not _active: return _result("DISABLED")
	if _seen.has(request_id):
		if not _same(_seen[request_id], {"code":http_status,"body":body}): return _suspend("ALTERED_RESPONSE")
		return _result("DUPLICATE_RESPONSE")
	if _inflight.get("id") != request_id: return _result("IGNORED_RESPONSE")
	var pending := _inflight.duplicate(true)
	_inflight.clear()
	if pending.kind == "ack" and _ack_context_valid():
		pass
	elif pending.epoch != _epoch or not _same(_origin, _context): return _suspend("STALE_RESPONSE")
	_seen[request_id] = {"code":http_status,"body":body.duplicate(true)}
	if http_status == 0 or http_status >= 500: return _suspend("OUTCOME_UNKNOWN")
	if http_status != 200 and http_status != 201: return _suspend("SERVER_REFUSED")
	if pending.kind == "ack": return _receive_ack(body)
	return _receive_delivery(body)

func _receive_delivery(body: Dictionary) -> Dictionary:
	if not _id(body.get("operation_id")) or body.get("receipt_id") != _receipt: return _suspend("RECEIPT_CONFLICT")
	if body.get("profile_uuid") != _origin.profile_uuid or body.get("career_id") != _origin.career_id: return _suspend("DESTINATION_CONFLICT")
	if not _integer(body.get("expected_revision")) or body.expected_revision != _origin.revision or body.get("parent_hash") != _origin.checkpoint_hash: return _suspend("REVISION_CONFLICT")
	if not _hash(body.get("candidate_hash")): return _suspend("INVALID_HASH")
	if not _delivery.is_empty() and (body.operation_id != _delivery.operation_id or body.candidate_hash != _delivery.candidate_hash): return _suspend("RECEIPT_CONFLICT")
	if body.get("receipt_state") != "confirmed" or body.get("manual_review") != false:
		return _suspend("MANUAL_REVIEW")
	# An already acknowledged operation must never be replayed into an old save.
	if body.get("state") == "acknowledged": return _suspend("RECONCILIATION_REQUIRED")
	if body.get("state") != "prepared" or not _candidate_valid(body): return _suspend("CANDIDATE_CONFLICT")
	if not _delivery.is_empty() and not _same(body.candidate, _delivery.candidate): return _suspend("RECEIPT_CONFLICT")
	_delivery = body.duplicate(true)
	_suspended = false
	return _result("PREPARED")

func _candidate_valid(body: Dictionary) -> bool:
	var candidate: Variant = body.get("candidate")
	if not candidate is Dictionary or not candidate.get("wallet") is Dictionary or not candidate.get("steam_wallet") is Dictionary: return false
	var meta: Dictionary = candidate.steam_wallet
	if not _same(meta.get("binding"), _origin.snapshot.steam_wallet.binding) or not meta.get("applied_receipts") is Dictionary: return false
	var markers: Dictionary = meta.applied_receipts
	var marker: Variant = markers.get(_receipt)
	if not marker is Dictionary or marker.size() != 3: return false
	if not _hash(marker.get("receipt_hash")) or marker.get("operation_id") != body.operation_id: return false
	if not _integer(marker.get("quantity")) or not int(marker.quantity) in [25, 75, 150]: return false
	if not _integer(candidate.wallet.get("tokens")) or candidate.wallet.tokens != _origin.snapshot.wallet.tokens + marker.quantity: return false
	# Validate the exact allowed change without ever editing the caller's wallet.
	var remaining: Dictionary = candidate.duplicate(true)
	remaining.wallet.erase("tokens")
	remaining.steam_wallet.applied_receipts.erase(_receipt)
	var previous: Dictionary = _origin.snapshot.duplicate(true)
	previous.wallet.erase("tokens")
	return _same(remaining, previous)

func prepared_delivery() -> Dictionary:
	# Suspension hides candidates; they are never persistence instructions.
	if _suspended or _acknowledged: return {}
	return _delivery.duplicate(true)

func acknowledge(commit_proof: Dictionary) -> Dictionary:
	if not _active: return _result("DISABLED")
	if _suspended: return _result("SUSPENDED")
	if _delivery.is_empty(): return _result("NOT_PREPARED")
	if commit_proof.get("status") != "COMMITTED" or commit_proof.get("operation_id") != _delivery.operation_id or commit_proof.get("candidate_hash") != _delivery.candidate_hash or not _same(commit_proof.get("snapshot"), _delivery.candidate): return _suspend("INVALID_COMMIT_PROOF")
	if not _proof.is_empty() and not _same(_proof, commit_proof): return _suspend("COMMIT_PROOF_CONFLICT")
	_proof = commit_proof.duplicate(true)
	if _acknowledged: return _result("ACKNOWLEDGED")
	if not _inflight.is_empty(): return _result("REQUEST_PENDING")
	return _send_ack()

func _send_ack() -> Dictionary:
	return _send("ack", "POST", API + "/" + _delivery.operation_id + "/ack", {"candidate_hash":_delivery.candidate_hash})

func _receive_ack(body: Dictionary) -> Dictionary:
	if _proof.is_empty() or body.get("operation_id") != _delivery.operation_id or body.get("candidate_hash") != _delivery.candidate_hash or not _integer(body.get("revision")) or body.revision != _origin.revision + 1: return _suspend("ACK_CONFLICT")
	_acknowledged = true
	_last_ack = body.duplicate(true)
	_suspended = false
	return _result("ACKNOWLEDGED")

func cancel() -> Dictionary:
	if not _active: return _result("DISABLED")
	if _origin.is_empty(): return _result("NOT_STARTED")
	# Local cancellation is NOT a server refund or proof that preparation failed.
	_inflight.clear()
	return _suspend("CANCELLED_LOCALLY")

func resume() -> Dictionary:
	if _durable_intent_required and not _durable_intent_confirmed: return _result("PERSISTENCE_REQUIRED")
	if _restore_uncertain: return _result("RECONCILIATION_REQUIRED")
	if not _active: return _result("DISABLED")
	if _origin.is_empty(): return _result("NOT_STARTED")
	if not _same(_origin, _context) and not _ack_context_valid(): return _suspend("CONTEXT_CHANGED")
	if not _inflight.is_empty(): return _result("REQUEST_PENDING")
	if _acknowledged: return _result("ACKNOWLEDGED")
	# Explicit recovery retains the original key/body; never starts another purchase.
	if not _proof.is_empty(): return _send_ack()
	if _delivery.is_empty(): return _send_prepare()
	return _send("resume", "GET", API + "/" + _delivery.operation_id, {})

func local_play_allowed() -> bool:
	return true

# Persistence integration is explicit/injected. No default file paths or autoload.
var _last_ack: Dictionary = {}
var _restore_uncertain := false
var _durable_intent_required := false
var _durable_intent_confirmed := false

static func snapshot_for_server(save: Dictionary) -> Dictionary:
	var snapshot := save.duplicate(true)
	snapshot.erase("_steam_local")
	return snapshot

static func verify_delivery(delivery: Dictionary, origin: Dictionary, receipt_id: String) -> bool:
	var verifier = load("res://scripts/SteamWallet.gd").new()
	if not verifier._valid_context(origin): return false
	verifier._origin = origin.duplicate(true)
	verifier._receipt = receipt_id
	return verifier._receive_delivery(delivery).status == "PREPARED"

func export_pending_state() -> Dictionary:
	if _origin.is_empty(): return {}
	return {"phase":"intent","receipt_id":_receipt,"idempotency_key":_key,"origin":_origin.duplicate(true)}

func prepare_persisted(io: RefCounted, expected: Dictionary, receipt_id: String, idempotency_key: String) -> Dictionary:
	if not _active: return _result("DISABLED")
	if _suspended or not _origin.is_empty(): return _result("OPERATION_EXISTS")
	if not _id(receipt_id) or not _id(idempotency_key): return _result("INVALID_REQUEST")
	if _context.snapshot.steam_wallet.applied_receipts.has(receipt_id): return _result("ALREADY_APPLIED")
	_receipt = receipt_id
	_key = idempotency_key
	_origin = _context.duplicate(true)
	_durable_intent_required = true
	var stored: Dictionary = io.write_steam_state(expected,{"action":"prepare","pending":export_pending_state()})
	if stored.status != "COMMITTED": return _suspend(str(stored.status))
	_durable_intent_confirmed = true
	return _send_prepare()

func commit_prepared(io: RefCounted, expected: Dictionary) -> Dictionary:
	if not _active or _suspended or _delivery.is_empty(): return _result("NOT_PREPARED")
	var committed: Dictionary = io.commit_steam_delivery(_delivery,expected)
	if committed.status != "COMMITTED": return _suspend(str(committed.status))
	_context = committed.context.duplicate(true)
	# LocalIO has already released its file lock. Only now may transport execute.
	return acknowledge(committed.proof)

func restore_pending_state(state: Dictionary, verified: Dictionary) -> Dictionary:
	if not _active or not _origin.is_empty(): return _result("NOT_READY")
	if not _same(state,verified.get("pending")) or not _valid_context(verified.get("context",{})): return _suspend("RESTORE_CONFLICT")
	if not _same(_context,verified.context): return _suspend("CONTEXT_CHANGED")
	if not state.get("origin") is Dictionary or not _valid_context(state.origin) or not _id(state.get("receipt_id")) or not _id(state.get("idempotency_key")): return _suspend("RESTORE_CONFLICT")
	if not _same(state.origin.snapshot.steam_wallet.binding,_context.snapshot.steam_wallet.binding): return _suspend("DESTINATION_CONFLICT")
	_origin = state.origin.duplicate(true)
	_receipt = state.receipt_id
	_key = state.idempotency_key
	if verified.status == "INTENT" and state.get("phase") == "intent" and _same(_context,_origin):
		# A file-only intent cannot distinguish a pre-write crash from restoration
		# of that intent AFTER a successful credit. Never replay it after restart.
		_restore_uncertain = true
		return _suspend("RECONCILIATION_REQUIRED")
	if verified.status != "COMMITTED" or state.get("phase") != "committed" or not state.get("delivery") is Dictionary: return _suspend("RESTORE_CONFLICT")
	if not verify_delivery(state.delivery,_origin,_receipt): return _suspend("RECEIPT_CONFLICT")
	_delivery = state.delivery.duplicate(true)
	var proof: Variant = verified.get("proof")
	if not proof is Dictionary or proof.get("status") != "COMMITTED" or proof.get("operation_id") != _delivery.operation_id or proof.get("candidate_hash") != _delivery.candidate_hash or not _same(proof.get("snapshot"),_delivery.candidate): return _suspend("INVALID_COMMIT_PROOF")
	_proof = proof.duplicate(true)
	if not _ack_context_valid(): return _suspend("RESTORE_CONFLICT")
	return _result("RESTORED_COMMIT")

func _ack_context_valid() -> bool:
	if _proof.is_empty() or _origin.is_empty(): return false
	if not _valid_context(_context): return false
	if not _same(_context.snapshot.steam_wallet.binding,_origin.snapshot.steam_wallet.binding): return false
	# Original synthetic protocol tests supply proof without a persistence adapter.
	# A real persisted commit additionally carries its immutable receipt markers.
	return _same(_context,_origin) or _same(_context.snapshot.steam_wallet,_proof.snapshot.steam_wallet)

func persist_ack(io: RefCounted, expected: Dictionary) -> Dictionary:
	if not _active or not _acknowledged or _last_ack.is_empty(): return _result("ACK_REQUIRED")
	var result: Dictionary = io.write_steam_state(expected,{"action":"ack","ack":_last_ack.duplicate(true)})
	if result.status != "COMMITTED": return _suspend(str(result.status))
	return _result("ACK_PERSISTED")

# Optional checkpoint transport; explicit opt-in, separate from purchase delivery.
const CHECKPOINT_API := "/v1/steam/wallet/checkpoint"
var _cloud_enabled := false
var _cloud_transport: Callable
var _cloud_attempt: Dictionary = {}
var _cloud_conflict := false

static func cloud_enrolled(document: Variant) -> bool:
	# Damaged enrollment remains isolated: never fall back to legacy cloud.
	return document is Dictionary and (document.has("_steam_local") or document.has("steam_wallet"))

func enable_cloud(transport: Callable) -> Dictionary:
	if not _environment_allowed(): return _result("ENVIRONMENT_REFUSED")
	if not transport.is_valid(): return _result("INVALID_TRANSPORT")
	_cloud_transport = transport
	_cloud_enabled = true
	return _result("READY")

func cloud_request(io: RefCounted, binding: Dictionary, jwt: String, upload: bool) -> Dictionary:
	if not _cloud_enabled: return _result("DISABLED")
	if _cloud_conflict: return _result("CHECKPOINT_CONFLICT")
	if not _cloud_attempt.is_empty(): return _result("REQUEST_PENDING")
	if jwt.is_empty(): return _result("AUTH_REQUIRED")
	var recovery: Dictionary = io.read_steam_recovery(binding)
	if recovery.status != "NO_INTENT": return _result("RECONCILIATION_REQUIRED")
	var loaded: Dictionary = io.read_career()
	if loaded.status != "OK": return _result("READ_FAILED")
	var data: Dictionary = loaded.data
	if data.get("l5_match",{}).has("pending"): return _result("L5_PENDING")
	var pending: Variant = data._steam_local.get("cloud_pending")
	if upload and pending == null:
		var body := {"profile_uuid":binding.profile_uuid,"career_id":binding.career_id,
			"expected_revision":data._steam_local.server_revision,"parent_hash":data._steam_local.server_checkpoint_hash,"snapshot":snapshot_for_server(data)}
		pending = {"key":Crypto.new().generate_random_bytes(16).hex_encode(),"body":body}
		var stored: Dictionary = io.write_steam_state(io.steam_expected(binding),{"action":"checkpoint_prepare","request":pending})
		if stored.status != "COMMITTED": return _result(str(stored.status))
		loaded = io.read_career()
		if loaded.status != "OK": return _result("READ_FAILED")
		data = loaded.data
	var put := pending is Dictionary
	_sequence += 1
	_cloud_attempt = {"id":str(_sequence),"binding":binding.duplicate(true),"expected":io.steam_expected(binding),
		"snapshot":snapshot_for_server(data),"revision":data._steam_local.server_revision,
		"hash":data._steam_local.server_checkpoint_hash,"pending":pending,"jwt":jwt,"put":put}
	var path := CHECKPOINT_API
	if not put: path += "?profile_uuid="+str(binding.profile_uuid).uri_encode()+"&career_id="+str(binding.career_id).uri_encode()
	_cloud_transport.call({"request_id":str(_sequence),"method":"PUT" if put else "GET","path":path,
		"headers":{"Authorization":"Bearer "+jwt,"Idempotency-Key":pending.key if put else ""},"body":pending.body.duplicate(true) if put else {}})
	return _result("REQUESTED")

func cloud_receive(io: RefCounted, binding: Dictionary, jwt: String, request_id: String, code: int, reply: Dictionary) -> Dictionary:
	if _cloud_attempt.is_empty() or request_id != _cloud_attempt.id: return _result("STALE_RESPONSE")
	var attempt := _cloud_attempt
	_cloud_attempt = {}
	if not _cloud_same(binding,attempt.binding) or jwt != attempt.jwt: return _result("CONTEXT_CHANGED")
	if code == 401: return _result("AUTH_REQUIRED")
	if code == 409:
		_cloud_conflict = true
		return _result("CHECKPOINT_CONFLICT")
	if code < 200 or code >= 300: return _result("NETWORK_ERROR")
	var loaded: Dictionary = io.read_career()
	if loaded.status != "OK": return _result("READ_FAILED")
	var expected: Dictionary = io.steam_expected(binding)
	if expected.get("binding") != attempt.binding or expected.get("local_profile_id") != attempt.expected.get("local_profile_id") or expected.get("career_id") != attempt.expected.get("career_id") or expected.get("generation",-1) < attempt.expected.get("generation",0): return _result("CONTEXT_CHANGED")
	if attempt.put:
		if not _cloud_same(loaded.data.get("_steam_local",{}).get("cloud_pending"),attempt.pending): return _result("CHECKPOINT_CONFLICT")
		var persisted: Dictionary = io.write_steam_state(expected,{"action":"checkpoint_ack","key":attempt.pending.key,"reply":reply})
		if persisted.status == "COMMITTED": persisted["local_matches_checkpoint"] = _cloud_same(snapshot_for_server(loaded.data),reply.get("snapshot"))
		return persisted
	# Downloads validate only. Never replace local progress with a remote snapshot.
	if expected != attempt.expected: return _result("STALE_RESPONSE")
	if reply.get("profile_uuid") != binding.get("profile_uuid") or reply.get("career_id") != binding.get("career_id") or reply.get("revision") != attempt.revision or reply.get("checkpoint_hash") != attempt.hash or not reply.get("snapshot") is Dictionary or not _cloud_same(reply.snapshot.get("steam_wallet"),attempt.snapshot.steam_wallet):
		_cloud_conflict = true
		return _result("CHECKPOINT_CONFLICT")
	var verified := _result("CHECKPOINT_VERIFIED")
	verified["local_matches_checkpoint"] = _cloud_same(attempt.snapshot,reply.snapshot)
	return verified

static func _cloud_same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

# A4 coordinator: explicit opt-in, injected persistence/transport, no default I/O.
const PAYMENTS_API := "/v1/steam/payments"
var _purchase_io: RefCounted
var _purchase_transport: Callable
var _purchase_binding: Dictionary = {}
var _purchase_jwt := ""
var _purchase_request: Dictionary = {}
var _purchase_serial := 0
var _purchase_delivery: RefCounted

var _purchase_enrollment_expected: Dictionary = {}
var _purchase_enrollment_snapshot: Dictionary = {}

# Prepare the existing A5 wallet before any order. No Valve call on this path.
func purchase_prepare(io: RefCounted, transport: Callable, binding: Dictionary, jwt: String) -> Dictionary:
	if not _environment_allowed(): return _result("DISABLED")
	if not transport.is_valid() or not purchase_session_valid(jwt,binding): return _result("AUTH_REQUIRED")
	var read: Dictionary = io.read_career()
	if read.status != "OK": return read
	_purchase_io=io; _purchase_transport=transport; _purchase_binding=binding.duplicate(true); _purchase_jwt=jwt
	if read.data.has("steam_wallet") or read.data.has("_steam_local"):
		var ready := purchase_enable(io,transport,binding,jwt,true)
		if ready.status != "READY": return ready
		# Durable payment/delivery recovery has priority over a new checkpoint read.
		if read.data._steam_local.get("purchase") != null: return _result("READY")
		return _purchase_send("ready_checkpoint","GET",CHECKPOINT_API+"?profile_uuid="+str(binding.profile_uuid).uri_encode()+"&career_id="+str(binding.career_id).uri_encode(),{})
	if read.data.get("l5_match",{}).has("pending"): return _result("L5_PENDING")
	_purchase_enrollment_expected=io.steam_expected(binding)
	_purchase_enrollment_snapshot=snapshot_for_server(read.data)
	var body := {"profile_uuid":binding.profile_uuid,"career_id":binding.career_id,
		"snapshot":_purchase_enrollment_snapshot.duplicate(true),"accept_initial_registration":true}
	return _purchase_send("enroll","POST","/v1/steam/wallet/enroll",body,{"Idempotency-Key":Crypto.new().generate_random_bytes(24).hex_encode()})

func _purchase_enrolled(reply: Dictionary) -> Dictionary:
	var confirmed := _purchase_binding.duplicate(true)
	if not _id(reply.get("profile_uuid")): return _result("CHECKPOINT_CONFLICT")
	confirmed.profile_uuid=reply.profile_uuid
	var wanted := _purchase_enrollment_snapshot.duplicate(true)
	wanted.steam_wallet={"binding":confirmed,"applied_receipts":{}}
	if reply.get("career_id") != confirmed.career_id or reply.get("revision") != 1 or not _hash(reply.get("checkpoint_hash")) or not _cloud_same(reply.get("snapshot"),wanted):
		return _result("CHECKPOINT_CONFLICT")
	var expected := _purchase_enrollment_expected.duplicate(true)
	expected.binding=confirmed
	var stored: Dictionary = _purchase_io.write_steam_state(expected,{"action":"enroll","server_revision":reply.revision,"server_checkpoint_hash":reply.checkpoint_hash})
	if stored.status != "COMMITTED": return stored
	_purchase_binding=confirmed
	_purchase_enrollment_expected.clear(); _purchase_enrollment_snapshot.clear()
	return _result("READY")

func purchase_enable(io: RefCounted, transport: Callable, binding: Dictionary, jwt: String, enabled: bool = false) -> Dictionary:
	if not enabled or not _environment_allowed(): return _result("DISABLED")
	if not transport.is_valid() or not purchase_session_valid(jwt,binding): return _result("AUTH_REQUIRED")
	var read: Dictionary = io.read_career()
	if read.status != "OK" or not read.data.get("steam_wallet") is Dictionary or not _same(read.data.steam_wallet.get("binding"),binding): return _result("ENROLLMENT_REQUIRED")
	_purchase_io=io; _purchase_transport=transport; _purchase_binding=binding.duplicate(true); _purchase_jwt=jwt
	return _result("READY")

static func purchase_session_valid(jwt: String, binding: Dictionary) -> bool:
	# Routing/expiry guard only. The backend authenticates the signature and A3 link.
	var parts := jwt.split(".")
	if parts.size()!=3: return false
	var payload := parts[1].replace("-","+").replace("_","/")
	while payload.length()%4: payload+="="
	var claims: Variant = JSON.parse_string(Marshalls.base64_to_utf8(payload))
	return claims is Dictionary and claims.get("sub") == binding.get("user_id") and (claims.get("exp") is int or claims.get("exp") is float) and float(claims.exp)>Time.get_unix_time_from_system()

func _purchase_read() -> Dictionary:
	if _purchase_io == null: return _result("DISABLED")
	if not purchase_session_valid(_purchase_jwt,_purchase_binding): return _result("AUTH_REQUIRED")
	var read: Dictionary = _purchase_io.read_career()
	if read.status != "OK": return read
	if not read.data.get("steam_wallet") is Dictionary or not _same(read.data.steam_wallet.get("binding"),_purchase_binding): return _result("DESTINATION_CONFLICT")
	return read

func purchase_start(pack: String, language: String = "en") -> Dictionary:
	if not _purchase_request.is_empty(): return _result("REQUEST_PENDING")
	var read := _purchase_read()
	if read.status != "OK": return read
	if read.data._steam_local.get("purchase") != null: return purchase_resume()
	if pack not in ["tokens25","tokens75","tokens150"]: return _result("INVALID_PACK")
	if language not in ["en","fr","es","de","it","pt"]: language="en"
	var intent := {"key":Crypto.new().generate_random_bytes(24).hex_encode(),"body":{"profile_uuid":_purchase_binding.profile_uuid,"career_id":_purchase_binding.career_id,"pack_id":pack,"language":language}}
	var saved: Dictionary = _purchase_io.write_steam_state(_purchase_io.steam_expected(_purchase_binding),{"action":"purchase_prepare","intent":intent})
	if saved.status != "COMMITTED": return saved
	# Catalogue access verifies the existing A3 association before InitTxn.
	return _purchase_send("catalog","GET",PAYMENTS_API+"/catalog",{})

func _purchase_send(kind: String, method: String, path: String, body: Dictionary, headers: Dictionary = {}) -> Dictionary:
	_purchase_serial+=1
	_purchase_request={"request_id":"purchase-"+str(_purchase_serial),"kind":kind,"method":method,"path":path,"body":body.duplicate(true),"headers":headers.duplicate(true)}
	_purchase_transport.call(_purchase_request.duplicate(true))
	return _result("REQUESTED")

func purchase_resume() -> Dictionary:
	if not _purchase_request.is_empty(): return _result("REQUEST_PENDING")
	var read := _purchase_read()
	if read.status != "OK": return read
	var intent: Variant = read.data._steam_local.get("purchase")
	if not intent is Dictionary: return _result("NOT_STARTED")
	if intent.order_id == "":
		return _purchase_send("order","POST",PAYMENTS_API+"/orders",intent.body,{"Idempotency-Key":intent.key})
	var reply: Variant = intent.get("reply")
	if reply is Dictionary and reply.get("state") == "PAID":
		var receipt: Variant = reply.get("receipt")
		if receipt is Dictionary and receipt.get("state") == "confirmed":
			return _purchase_send("order","GET",PAYMENTS_API+"/orders/"+intent.order_id,{})
	return _purchase_send("order","POST",PAYMENTS_API+"/orders/"+intent.order_id+"/resume",{})

func purchase_authorization(app_id: int, order_id: String, authorized: bool) -> Dictionary:
	if app_id != APP_ID: return _result("IGNORED_CALLBACK")
	var read := _purchase_read()
	if read.status != "OK": return read
	var intent: Variant = read.data._steam_local.get("purchase")
	if not intent is Dictionary or intent.order_id != order_id: return _result("IGNORED_CALLBACK")
	if not _purchase_request.is_empty(): return _result("REQUEST_PENDING")
	# Authorization is a hint, NEVER a receipt or a local credit.
	return _purchase_send("order","POST",PAYMENTS_API+"/orders/"+order_id+"/authorization",{"authorized":authorized})

func purchase_receive(request_id: String, code: int, reply: Dictionary, binding: Dictionary, jwt: String) -> Dictionary:
	if not _same(binding,_purchase_binding) or jwt != _purchase_jwt: return _result("STALE_CONTEXT")
	if _purchase_request.get("request_id") != request_id: return _result("STALE_RESPONSE")
	var request := _purchase_request.duplicate(true)
	_purchase_request.clear()
	if request.kind == "enroll":
		if not purchase_session_valid(jwt,binding) or code in [401,403]: return _result("AUTH_REQUIRED")
		if code == 0 or code >= 500: return _result("UNCERTAIN_RETRY")
		if code not in [200,201]: return _result("ENROLLMENT_REFUSED")
		return _purchase_enrolled(reply)
	var read := _purchase_read()
	if read.status != "OK": return read
	if code == 0 or code >= 500: return _result("UNCERTAIN_RETRY")
	if code == 401 or code == 403: return _result("AUTH_REQUIRED")
	if code == 409: return _result("CONFLICT")
	if code < 200 or code >= 300: return _result("SERVER_REFUSED")
	if request.kind == "ready_checkpoint":
		if reply.get("profile_uuid") != binding.profile_uuid or reply.get("career_id") != binding.career_id or reply.get("revision") != read.data._steam_local.server_revision or reply.get("checkpoint_hash") != read.data._steam_local.server_checkpoint_hash or not reply.get("snapshot") is Dictionary or not _cloud_same(reply.snapshot.get("steam_wallet"),read.data.steam_wallet): return _result("CHECKPOINT_CONFLICT")
		return _result("READY")
	if request.kind == "catalog": return purchase_resume()
	if request.kind == "cloud":
		var cloud: Dictionary = _purchase_delivery.cloud_receive(_purchase_io,_purchase_binding,_purchase_jwt,request.adapter_id,code,reply)
		if cloud.status != "COMMITTED": return cloud
		return _purchase_deliver()
	if request.kind == "delivery":
		var result: Dictionary = _purchase_delivery.receive(request.adapter_id,code,reply)
		if result.status == "PREPARED": return _purchase_delivery.commit_prepared(_purchase_io,_purchase_io.steam_expected(_purchase_binding))
		if result.status == "ACKNOWLEDGED":
			var stored: Dictionary = _purchase_delivery.persist_ack(_purchase_io,_purchase_io.steam_expected(_purchase_binding))
			if stored.status != "ACK_PERSISTED": return stored
			return _purchase_finish()
		return result
	var intent: Variant = read.data._steam_local.get("purchase")
	if not intent is Dictionary: return _result("ORDER_CONFLICT")
	var saved: Dictionary = _purchase_io.write_steam_state(_purchase_io.steam_expected(_purchase_binding),{"action":"purchase_response","key":intent.key,"reply":reply})
	if saved.status != "COMMITTED": return saved
	if reply.get("state") in ["FAILED","CANCELLED"]: return _purchase_finish()
	var receipt: Variant = reply.get("receipt")
	if reply.get("state") != "PAID" or not receipt is Dictionary or receipt.get("state") != "confirmed": return _result("ORDER_"+str(reply.get("state","UNKNOWN")))
	# A persisted A5 intention takes priority over a new checkpoint.
	read=_purchase_read()
	if read.data._steam_local.pending != null: return _purchase_deliver()
	if read.data.steam_wallet.applied_receipts.has(receipt.get("receipt_id","")): return _purchase_finish()
	_purchase_delivery=_new_purchase_wallet()
	_purchase_delivery.enable_cloud(_purchase_cloud_transport)
	return _purchase_delivery.cloud_request(_purchase_io,_purchase_binding,_purchase_jwt,true)

func _new_purchase_wallet() -> RefCounted:
	return load("res://scripts/SteamWallet.gd").new()

func _purchase_forward(message: Dictionary, kind: String) -> void:
	_purchase_serial+=1
	_purchase_request=message.duplicate(true)
	_purchase_request.adapter_id=message.request_id
	_purchase_request.request_id="purchase-"+str(_purchase_serial)
	_purchase_request.kind=kind
	_purchase_transport.call(_purchase_request.duplicate(true))
func _purchase_cloud_transport(message: Dictionary) -> void: _purchase_forward(message,"cloud")
func _purchase_delivery_transport(message: Dictionary) -> void: _purchase_forward(message,"delivery")

func _purchase_deliver() -> Dictionary:
	var read := _purchase_read()
	if read.status != "OK": return read
	var intent: Dictionary = read.data._steam_local.purchase
	var receipt: Dictionary = intent.reply.receipt
	_purchase_delivery=_new_purchase_wallet()
	var ctx: Dictionary = read.data.steam_wallet.binding.duplicate(true)
	ctx.revision=read.data._steam_local.server_revision; ctx.checkpoint_hash=read.data._steam_local.server_checkpoint_hash
	ctx.snapshot=snapshot_for_server(read.data)
	var enabled: Dictionary = _purchase_delivery.enable(_purchase_delivery_transport,ctx)
	if enabled.status != "READY": return enabled
	if read.data._steam_local.pending != null:
		var recovery: Dictionary = _purchase_io.read_steam_recovery(_purchase_binding)
		var restored: Dictionary = _purchase_delivery.restore_pending_state(read.data._steam_local.pending,recovery)
		if restored.status != "RESTORED_COMMIT": return restored
		return _purchase_delivery.resume()
	return _purchase_delivery.prepare_persisted(_purchase_io,_purchase_io.steam_expected(_purchase_binding),receipt.receipt_id,intent.key+"_delivery")

func _purchase_finish() -> Dictionary:
	var read := _purchase_read()
	if read.status != "OK": return read
	var intent: Dictionary = read.data._steam_local.purchase
	var result: Dictionary = _purchase_io.write_steam_state(_purchase_io.steam_expected(_purchase_binding),{"action":"purchase_complete","key":intent.key})
	if result.status != "COMMITTED": return result
	return _result("PURCHASE_COMPLETE" if intent.reply.get("state")=="PAID" else "PURCHASE_CANCELLED")
