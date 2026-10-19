extends SceneTree
# Run only in a temporary minimal Godot project containing these two scripts.
# No file I/O, actual HTTP, Steam, personal saves or production imports.
const Adapter = preload("res://scripts/SteamWallet.gd")
class TestAdapter:
	extends "res://scripts/SteamWallet.gd"
	func _environment_allowed() -> bool: return true
class RefusedAdapter:
	extends "res://scripts/SteamWallet.gd"
	func _environment_allowed() -> bool: return false
class Transport:
	extends RefCounted
	var requests: Array = []
	func send(request: Dictionary) -> void: requests.append(request.duplicate(true))

var passed := 0
var failed := 0
func expect(name: String, condition: bool) -> void:
	if condition: passed += 1; print("PASS ",name)
	else: failed += 1; print("FAIL ",name)
func context() -> Dictionary:
	return {"user_id":"user1","profile_uuid":"profile1","career_id":"career1","revision":1,"checkpoint_hash":"a".repeat(64),"snapshot":{
		"career_id":"career1","wallet":{"tokens":10},"season_tokens_earned":7,
		"steam_wallet":{"binding":{"user_id":"user1","profile_uuid":"profile1","career_id":"career1"},"applied_receipts":{}}}}
func fixture() -> Dictionary:
	var t := Transport.new()
	var w := TestAdapter.new()
	var ctx := context()
	w.enable(t.send,ctx)
	return {"w":w,"t":t,"ctx":ctx}
func begin(f: Dictionary) -> Dictionary:
	return f.w.prepare("receipt1","key1")
func delivery(f: Dictionary) -> Dictionary:
	var candidate: Dictionary = f.ctx.snapshot.duplicate(true)
	candidate.wallet.tokens += 25 # Synthetic SERVER output only, never a real save.
	candidate.steam_wallet.applied_receipts.receipt1 = {"receipt_hash":"b".repeat(64),"quantity":25,"operation_id":"operation1"}
	return {"operation_id":"operation1","receipt_id":"receipt1","profile_uuid":"profile1","career_id":"career1",
		"state":"prepared","expected_revision":1,"parent_hash":"a".repeat(64),"candidate_hash":"c".repeat(64),
		"candidate":candidate,"receipt_state":"confirmed","manual_review":false}
func receive(f: Dictionary, body: Dictionary, code: int = 201) -> Dictionary:
	return f.w.receive(f.t.requests.back().request_id,code,body)
func proof(f: Dictionary) -> Dictionary:
	var d := delivery(f)
	return {"status":"COMMITTED","operation_id":d.operation_id,"candidate_hash":d.candidate_hash,"snapshot":d.candidate}
func ack_reply() -> Dictionary:
	return {"operation_id":"operation1","revision":2,"candidate_hash":"c".repeat(64)}
func _initialize() -> void:
	var t := Transport.new()
	var disabled := Adapter.new()
	expect("01_disabled_default",disabled.prepare("receipt1","key1").status=="DISABLED" and t.requests.is_empty())
	var refused := RefusedAdapter.new()
	expect("02_non_steam_refused",refused.enable(t.send,context()).status=="ENVIRONMENT_REFUSED")
	expect("03_real_mac_gate",OS.get_name()=="macOS" and disabled.enable(t.send,context()).status=="ENVIRONMENT_REFUSED")
	var f := fixture(); begin(f)
	expect("04_backend_confirmed",receive(f,delivery(f)).status=="PREPARED" and f.w.prepared_delivery().candidate.wallet.tokens==35)
	expect("05_inputs_unchanged",f.ctx.snapshot.wallet.tokens==10 and f.ctx.snapshot.season_tokens_earned==7 and f.ctx.snapshot.steam_wallet.applied_receipts.is_empty())
	var n: int = f.t.requests.size()
	expect("06_receipt_repeated_no_request",f.w.prepare("receipt1","key2").status=="OPERATION_EXISTS" and f.t.requests.size()==n)
	expect("07_identical_response",receive(f,delivery(f)).status=="DUPLICATE_RESPONSE")
	var changed := delivery(f);changed.candidate.wallet.tokens=999
	expect("08_altered_response",receive(f,changed).status=="ALTERED_RESPONSE" and f.w.prepared_delivery().is_empty())
	f=fixture();begin(f);changed=delivery(f);changed.candidate.steam_wallet.binding.user_id="other"
	expect("09_wrong_user",receive(f,changed).status=="CANDIDATE_CONFLICT")
	f=fixture();begin(f);changed=delivery(f);changed.profile_uuid="other"
	expect("10_wrong_profile",receive(f,changed).status=="DESTINATION_CONFLICT")
	f=fixture();begin(f);changed=delivery(f);changed.career_id="other"
	expect("11_wrong_career",receive(f,changed).status=="DESTINATION_CONFLICT")
	f=fixture();begin(f);changed=delivery(f);changed.expected_revision=0
	expect("12_old_revision",receive(f,changed).status=="REVISION_CONFLICT")
	f=fixture();begin(f);changed=delivery(f);changed.parent_hash="d".repeat(64)
	expect("13_wrong_parent",receive(f,changed).status=="REVISION_CONFLICT")
	f=fixture();begin(f);var newer: Dictionary = f.ctx.duplicate(true);newer.snapshot.wallet.tokens+=2;f.w.set_context(newer)
	expect("14_late_response_local_progress",receive(f,delivery(f)).status=="STALE_RESPONSE" and newer.snapshot.wallet.tokens==12)
	f=fixture();begin(f)
	expect("15_network_loss",receive(f,{},0).status=="OUTCOME_UNKNOWN" and f.w.local_play_allowed())
	var original: Dictionary = f.t.requests[0].duplicate(true);f.w.resume()
	expect("16_retry_same_key_body",f.t.requests.size()==2 and f.t.requests[1].headers==original.headers and f.t.requests[1].body==original.body and receive(f,delivery(f)).status=="PREPARED")
	f=fixture();begin(f);var old_id: String = f.t.requests.back().request_id;f.w.cancel()
	expect("17_cancel_late_ignored",f.w.receive(old_id,201,delivery(f)).status=="IGNORED_RESPONSE" and f.w.local_play_allowed())
	f.w.resume()
	expect("18_cancel_resume",receive(f,delivery(f)).status=="PREPARED" and f.t.requests[0].headers==f.t.requests[1].headers)
	f=fixture();begin(f);receive(f,delivery(f));f.w.acknowledge(proof(f))
	expect("19_ack_confirmed",receive(f,ack_reply(),200).status=="ACKNOWLEDGED" and f.w.prepared_delivery().is_empty())
	n=f.t.requests.size()
	expect("20_ack_idempotent",f.w.acknowledge(proof(f)).status=="ACKNOWLEDGED" and f.t.requests.size()==n)
	f=fixture();begin(f);receive(f,delivery(f));f.w.acknowledge(proof(f));receive(f,{},0);f.w.resume()
	expect("21_ack_lost_retry",f.t.requests.back().path.ends_with("/ack") and receive(f,ack_reply(),200).status=="ACKNOWLEDGED")
	f=fixture();begin(f);changed=delivery(f);changed.receipt_state="partial_refund";changed.manual_review=true;changed.erase("candidate")
	expect("22_refund_manual",receive(f,changed).status=="MANUAL_REVIEW" and f.w.prepared_delivery().is_empty() and f.ctx.snapshot.wallet.tokens==10)
	expect("23_local_game_after_conflict",f.w.local_play_allowed() and f.w.prepare("receipt2","key2").status=="SUSPENDED")
	f=fixture();begin(f);changed=delivery(f);changed.state="acknowledged";changed.erase("candidate")
	expect("24_no_restore_replay",receive(f,changed).status=="RECONCILIATION_REQUIRED")
	f=fixture();begin(f);receive(f,delivery(f));var bad_proof := proof(f);bad_proof.status="PREPARED"
	expect("25_no_ack_without_commit",f.w.acknowledge(bad_proof).status=="INVALID_COMMIT_PROOF" and f.t.requests.size()==1)
	f=fixture();begin(f);changed=delivery(f);changed.candidate.season_tokens_earned+=25
	expect("26_no_season_credit",receive(f,changed).status=="CANDIDATE_CONFLICT")
	f=fixture();begin(f);changed=delivery(f);changed.receipt_state="approved"
	expect("27_unconfirmed_refused",receive(f,changed).status=="MANUAL_REVIEW")
	f=fixture();var applied: Dictionary = f.ctx.duplicate(true);applied.snapshot.steam_wallet.applied_receipts.receipt1={"quantity":25};f.w.set_context(applied)
	expect("28_already_applied",f.w.prepare("receipt1","key1").status=="ALREADY_APPLIED" and f.t.requests.is_empty())
	f=fixture();begin(f);receive(f,delivery(f));var exposed: Dictionary = f.w.prepared_delivery();exposed.candidate.wallet.tokens=999
	expect("29_returned_copy",f.w.prepared_delivery().candidate.wallet.tokens==35 and f.ctx.snapshot.wallet.tokens==10)
	f=fixture();begin(f);receive(f,delivery(f));f.w.cancel();f.w.resume()
	expect("30_resume_get_only",f.t.requests.back().method=="GET" and f.t.requests.back().path.ends_with("/operation1") and receive(f,delivery(f),200).status=="PREPARED")
	f=fixture();begin(f);changed=JSON.parse_string(JSON.stringify(delivery(f)))
	expect("31_json_numeric_roundtrip",receive(f,changed).status=="PREPARED")
	f=fixture();begin(f);receive(f,delivery(f));f.w.acknowledge(proof(f));changed=ack_reply();changed.revision=7
	expect("32_wrong_ack_revision",receive(f,changed,200).status=="ACK_CONFLICT")
	f=fixture();begin(f);newer=f.ctx.duplicate(true);newer.user_id="user2";newer.snapshot.steam_wallet.binding.user_id="user2";f.w.set_context(newer)
	expect("33_account_changed_late",receive(f,delivery(f)).status=="STALE_RESPONSE" and f.w.resume().status=="CONTEXT_CHANGED")
	print("RESULT ",passed," PASS / ",failed," FAIL")
	quit(0 if failed==0 else 1)
