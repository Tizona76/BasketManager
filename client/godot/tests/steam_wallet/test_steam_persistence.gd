extends SceneTree
# Run in an isolated temporary project only, with -- --fixture-root=/private/tmp/...
# The fixture argument is mandatory; this suite never uses user://.
const IO = preload("res://scripts/LocalIO.gd")
const Wallet = preload("res://scripts/SteamWallet.gd")
const PL = preload("res://scripts/PlayerLife.gd")
const PM = preload("res://scripts/ProfileManager.gd")
class SteamIO:
	extends "res://scripts/LocalIO.gd"
	func _steam_enabled() -> bool: return true
class TestWallet:
	extends "res://scripts/SteamWallet.gd"
	func _environment_allowed() -> bool: return true
class FaultIO:
	extends SteamIO
	var fault := ""
	var failed_reads := 0
	func _read(path: String) -> Dictionary:
		if failed_reads > 0:
			failed_reads -= 1
			return _error("IO_ERROR")
		return super._read(path)
	func _publish(data: Dictionary) -> Dictionary:
		if fault == "before": return _error("INTERRUPTED")
		if fault == "disk_full":
			var f := FileAccess.open(root.path_join("injected-partial.tmp"),FileAccess.WRITE)
			f.store_string("{partial"); f.close()
			return _error("WRITE_FAILED")
		var result := super._publish(data)
		if result.status == "COMMITTED" and fault in ["indeterminate","after"]:
			result.status = "INDETERMINATE_AFTER_REPLACE"
			if fault == "after": failed_reads = 1
		return result
class Transport:
	extends RefCounted
	var requests: Array = []
	func send(req: Dictionary) -> void: requests.append(req.duplicate(true))

var base := ""
var serial := 0
var passed := 0
var failed := 0
var binding := {"user_id":"user1","profile_uuid":"uuid1","career_id":"career1"}
func expect(name: String, condition: bool) -> void:
	if condition: passed += 1; print("PASS ",name)
	else: failed += 1; print("FAIL ",name)
func raw_write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"\t"));f.close()
func read(f: Dictionary) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(f.path))
func fixture(enroll: bool = true, l5: bool = false) -> Dictionary:
	serial += 1
	var directory := base.path_join("case_"+str(serial))
	DirAccess.make_dir_recursive_absolute(directory)
	raw_write(directory.path_join("profiles.json"),{"active_profile_id":"local1","profiles":[{"id":"local1"}]})
	raw_write(directory.path_join("careers_local1.json"),{"active_career_id":"career1","careers":[{"career_id":"career1"}]})
	var path := directory.path_join("save_local1_career1.json")
	var data := {"profile_id":"local1","career_id":"career1","wallet":{"tokens":10},"season_tokens_earned":7}
	if l5: data.l5_match={"revision":1,"receipts":{}}
	raw_write(path,data)
	var io := SteamIO.new(directory)
	io.read_career()
	if enroll:
		var result := io.write_steam_state(io.steam_expected(binding),{"action":"enroll","server_revision":1,"server_checkpoint_hash":"a".repeat(64)})
		if result.status != "COMMITTED": print("FIXTURE ENROLL ERROR ",result)
	var transport := Transport.new()
	var w := TestWallet.new()
	var f := {"io":io,"path":path,"root":directory,"w":w,"t":transport}
	if enroll: w.enable(transport.send,ctx(read(f)))
	return f
func ctx(data: Dictionary) -> Dictionary:
	var c: Dictionary = data.steam_wallet.binding.duplicate(true)
	c.revision=data._steam_local.server_revision;c.checkpoint_hash=data._steam_local.server_checkpoint_hash
	c.snapshot=Wallet.snapshot_for_server(data)
	return c
func expected(io: RefCounted) -> Dictionary:
	io.read_career();return io.steam_expected(binding)
func prepare(f: Dictionary) -> Dictionary:
	var r: Dictionary = f.w.prepare_persisted(f.io,expected(f.io),"receipt1","key1")
	if r.status != "REQUESTED": print("PREPARE ERROR ",r)
	var body: Dictionary = f.t.requests.back().body
	var candidate: Dictionary = body.snapshot.duplicate(true)
	candidate.wallet.tokens+=25
	candidate.steam_wallet.applied_receipts.receipt1={"receipt_hash":"b".repeat(64),"quantity":25,"operation_id":"op1"}
	var d := {"operation_id":"op1","receipt_id":"receipt1","profile_uuid":"uuid1","career_id":"career1","state":"prepared","expected_revision":1,"parent_hash":"a".repeat(64),"candidate_hash":"c".repeat(64),"candidate":candidate,"receipt_state":"confirmed","manual_review":false}
	f.w.receive(f.t.requests.back().request_id,201,d)
	return d
func commit(f: Dictionary, d: Dictionary) -> Dictionary:
	return f.io.commit_steam_delivery(d,expected(f.io))
func local_change(f: Dictionary, delta: int) -> Dictionary:
	var loaded: Dictionary = f.io.read_career()
	loaded.data.wallet.tokens+=delta
	if delta>0:loaded.data.season_tokens_earned+=delta
	return f.io.write_verified(loaded.data)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--fixture-root="):base=arg.trim_prefix("--fixture-root=")
	if not base.begins_with("/private/tmp/") or ".." in base or ProjectSettings.globalize_path("res://").begins_with("/Users/"):
		print("REFUSED: temporary project and explicit temporary fixtures required");quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	for arg in args:
		if arg.begins_with("--recover="):
			var directory := arg.trim_prefix("--recover=")
			if not directory.begins_with(base+"/"):quit(2);return
			var io := SteamIO.new(directory)
			var recovery := io.read_steam_recovery(binding)
			var transport := Transport.new();var w := TestWallet.new()
			w.enable(transport.send,recovery.get("context",{}))
			var result := w.restore_pending_state(recovery.get("pending",{}),recovery)
			var ok: bool = result.status=="RESTORED_COMMIT" and w.resume().status=="REQUESTED" and transport.requests.back().path.ends_with("/ack")
			print("RESTART_PASS" if ok else "RESTART_FAIL");quit(0 if ok else 1);return
	var f := fixture();var d := prepare(f);var out := commit(f,d)
	expect("01_atomic_credit_marker_journal",out.status=="COMMITTED" and read(f).wallet.tokens==35 and read(f).steam_wallet.applied_receipts.has("receipt1") and read(f)._steam_local.pending.phase=="committed")
	expect("02_season_unchanged",read(f).season_tokens_earned==7)
	expect("03_duplicate_no_write",commit(f,d).status=="COMMITTED" and read(f).wallet.tokens==35)
	var altered := d.duplicate(true);altered.candidate.wallet.tokens=99
	expect("04_altered_receipt",commit(f,altered).status=="RECEIPT_CONFLICT" and read(f).wallet.tokens==35)
	var old := read(f);local_change(f,9);local_change(f,-6)
	expect("05_local_gain_spend_preserved",read(f).wallet.tokens==38 and read(f).season_tokens_earned==16 and read(f)._steam_local.pending.phase=="committed")
	f.io.read_career()
	expect("06_stale_in_memory_write",f.io.write_verified(old).status=="STALE" and read(f).wallet.tokens==38)
	var recovery: Dictionary = f.io.read_steam_recovery(binding)
	var t := Transport.new();var restarted := TestWallet.new();restarted.enable(t.send,recovery.context)
	expect("07_restore_ack_only",restarted.restore_pending_state(recovery.pending,recovery).status=="RESTORED_COMMIT" and restarted.resume().status=="REQUESTED" and t.requests.back().path.ends_with("/ack"))
	restarted.receive(t.requests.back().request_id,200,{"operation_id":"op1","candidate_hash":"c".repeat(64),"revision":2})
	expect("08_ack_preserves_progress",restarted.persist_ack(f.io,expected(f.io)).status=="ACK_PERSISTED" and read(f).wallet.tokens==38 and read(f)._steam_local.pending==null and read(f)._steam_local.server_revision==2)
	f=fixture();d=prepare(f);local_change(f,2)
	expect("09_gain_during_network_refused",commit(f,d).status=="STALE" and read(f).wallet.tokens==12)
	f=fixture();d=prepare(f);var ex := expected(f.io)
	raw_write(f.root.path_join("careers_local1.json"),{"active_career_id":"other","careers":[{"career_id":"other"}]})
	expect("10_career_switch",f.io.commit_steam_delivery(d,ex).status!="COMMITTED" and read(f).wallet.tokens==10)
	f=fixture();d=prepare(f);ex=expected(f.io);ex.binding.user_id="wrong"
	expect("11_account_switch",f.io.commit_steam_delivery(d,ex).status=="DESTINATION_CONFLICT")
	f=fixture();d=prepare(f);var failure := FaultIO.new(f.root);failure.fault="before"
	expect("12_before_write",failure.commit_steam_delivery(d,expected(failure)).status=="INTERRUPTED" and read(f).wallet.tokens==10 and not read(f).steam_wallet.applied_receipts.has("receipt1"))
	failure.fault=""
	expect("13_before_write_resume",failure.commit_steam_delivery(d,expected(failure)).status=="COMMITTED" and read(f).wallet.tokens==35)
	f=fixture();d=prepare(f);failure=FaultIO.new(f.root);failure.fault="after"
	expect("14_after_write_unknown",failure.commit_steam_delivery(d,expected(failure)).status=="INDETERMINATE_AFTER_REPLACE" and read(f).wallet.tokens==35)
	failure.fault=""
	expect("15_after_write_recovery",failure.read_steam_recovery(binding).status=="COMMITTED" and failure.commit_steam_delivery(d,expected(failure)).status=="COMMITTED" and read(f).wallet.tokens==35)
	var child_output := [];var executable := OS.get_executable_path()
	var code := OS.execute(executable,["--headless","--path",ProjectSettings.globalize_path("res://"),"--script",get_script().resource_path,"--log-file",base.path_join("restart-engine.log"),"--","--fixture-root="+base,"--recover="+f.root],child_output,true)
	expect("16_actual_process_restart",code==0 and str(child_output).contains("RESTART_PASS"))
	f=fixture();d=prepare(f);failure=FaultIO.new(f.root);failure.fault="indeterminate"
	expect("17_indeterminate_readback",failure.commit_steam_delivery(d,expected(failure)).status=="COMMITTED" and read(f).wallet.tokens==35)
	f=fixture();d=prepare(f);failure=FaultIO.new(f.root);failure.fault="disk_full"
	expect("18_disk_full",failure.commit_steam_delivery(d,expected(failure)).status=="WRITE_FAILED" and read(f).wallet.tokens==10 and read(f).steam_wallet.applied_receipts.is_empty())
	f=fixture(true,true);d=prepare(f);var match_save := read(f);match_save.l5_match["pending"]={"key":"match1"};f.io.read_career();f.io.write_verified(match_save)
	expect("19_l5_pending_blocks_credit",commit(f,d).status=="L5_PENDING" and read(f).wallet.tokens==10)
	var pending_bytes := FileAccess.get_file_as_string(f.path);PL.write_savegame(read(f),f.path)
	expect("20_l5_legacy_guard",FileAccess.get_file_as_string(f.path)==pending_bytes)
	var final_match: Dictionary = f.io.read_career().data;final_match.l5_match.erase("pending");final_match.l5_match.revision+=1;final_match.l5_match.receipts["match1"]={"done":true};final_match.wallet.tokens-=1
	expect("21_l5_direct_finish_preserves_metadata",f.io.write_verified(final_match).status=="COMMITTED" and read(f).l5_match.receipts.has("match1") and read(f).wallet.tokens==9 and read(f)._steam_local.pending.phase=="intent")
	f=fixture(true,true);d=prepare(f);var old_l5: Dictionary=read(f).l5_match.duplicate(true);commit(f,d)
	expect("22_credit_no_l5_mutation",IO._steam_same(read(f).l5_match,old_l5))
	var st: Dictionary=read(f);st.wallet.tokens-=2;PL.write_savegame(st,f.path)
	expect("23_playerlife_protected_write",read(f).wallet.tokens==33 and read(f).steam_wallet.applied_receipts.has("receipt1") and read(f).l5_match.revision==2)
	var bare := read(f);bare.erase("_steam_local");var prior := FileAccess.get_file_as_string(f.path);PL.write_savegame(bare,f.path)
	expect("24_playerlife_marker_strip_refused",FileAccess.get_file_as_string(f.path)==prior)
	var dst: String=f.root.path_join("copy.json")
	expect("25_copy_refused",not PM._copy_file(f.path,dst) and not FileAccess.file_exists(dst))
	expect("26_new_career_clone_refused",PM.create_career(read(f))=="")
	f=fixture(false);var untouched:=read(f);var original_tokens:int=untouched.wallet.tokens
	f.io.read_career();untouched.wallet.tokens+=2
	expect("27_nonsteam_localio",f.io.write_verified(untouched).status=="COMMITTED" and read(f).wallet.tokens==original_tokens+2 and not read(f).has("_steam_local"))
	dst=f.root.path_join("copy.json")
	expect("28_nonsteam_copy",PM._copy_file(f.path,dst) and FileAccess.get_file_as_string(dst)==FileAccess.get_file_as_string(f.path))
	f=fixture();d=prepare(f);var first := SteamIO.new(f.root);var second := SteamIO.new(f.root);first.read_career();second.read_career();var a:Dictionary=first._read(f.path).data;var b:Dictionary=a.duplicate(true);a.wallet.tokens+=1;b.wallet.tokens+=2
	var one:=first.write_verified(a);var two:=second.write_verified(b)
	expect("29_stale_concurrent_instances",one.status=="COMMITTED" and two.status=="STALE" and read(f).wallet.tokens==11)
	f=fixture();d=prepare(f);f.w.commit_prepared(f.io,expected(f.io));local_change(f,3);f.w.set_context(ctx(read(f)))
	var ack:Dictionary=f.w.receive(f.t.requests.back().request_id,200,{"operation_id":"op1","candidate_hash":"c".repeat(64),"revision":2})
	expect("30_late_ack_local_progress",ack.status=="ACKNOWLEDGED" and f.w.persist_ack(f.io,expected(f.io)).status=="ACK_PERSISTED" and read(f).wallet.tokens==38)
	expect("31_local_metadata_excluded",not Wallet.snapshot_for_server(read(f)).has("_steam_local") and not f.t.requests[0].body.snapshot.has("_steam_local"))
	f=fixture();d=prepare(f);ex=expected(f.io);raw_write(f.root.path_join("profiles.json"),{"active_profile_id":"other","profiles":[{"id":"other"}]})
	expect("32_profile_switch",f.io.commit_steam_delivery(d,ex).status!="COMMITTED")
	f=fixture();d=prepare(f);var pristine:=read(f);commit(f,d);raw_write(f.path,pristine)
	# Old snapshot still has an intent: locally detect only what durable evidence remains.
	# Server reconciliation must refuse an old version if the entire file was rolled back.
	var recover_old:Dictionary=f.io.read_steam_recovery(binding)
	t=Transport.new();restarted=TestWallet.new();restarted.enable(t.send,recover_old.context)
	expect("33_restored_old_intent_no_replay",recover_old.status=="INTENT" and restarted.restore_pending_state(recover_old.pending,recover_old).status=="RECONCILIATION_REQUIRED" and restarted.resume().status=="RECONCILIATION_REQUIRED" and t.requests.is_empty() and read(f).wallet.tokens==10)
	f=fixture();first=SteamIO.new(f.root);second=SteamIO.new(f.root)
	a=first.read_career().data;b=second.read_career().data;a.wallet.tokens+=1;b.wallet.tokens+=2
	var thread1:=Thread.new();var thread2:=Thread.new()
	thread1.start(first.write_verified.bind(a));thread2.start(second.write_verified.bind(b))
	one=thread1.wait_to_finish();two=thread2.wait_to_finish()
	var winners:=int(one.status=="COMMITTED")+int(two.status=="COMMITTED")
	var loser:Dictionary=two if one.status=="COMMITTED" else one
	var retry_delta:=2 if one.status=="COMMITTED" else 1
	var retry:Dictionary=local_change(f,retry_delta)
	expect("34_threads_serialized_and_retry",winners==1 and loser.status in ["BUSY","STALE"] and retry.status=="COMMITTED" and read(f).wallet.tokens==13)
	f=fixture();d=prepare(f);commit(f,d);old=read(f);old.steam_wallet.applied_receipts.clear();f.io.read_career()
	expect("35_receipt_deletion_refused",f.io.write_verified(old).status=="STEAM_METADATA_CONFLICT" and read(f).steam_wallet.applied_receipts.has("receipt1"))
	f=fixture();d=prepare(f);commit(f,d);old=read(f);old._steam_local.pending=null;f.io.read_career()
	expect("36_journal_deletion_refused",f.io.write_verified(old).status=="STEAM_METADATA_CONFLICT" and read(f)._steam_local.pending!=null)
	f=fixture();d=prepare(f);commit(f,d);recovery=f.io.read_steam_recovery(binding)
	t=Transport.new();restarted=TestWallet.new();restarted.enable(t.send,recovery.context);restarted.restore_pending_state(recovery.pending,recovery);restarted.resume()
	restarted.receive(t.requests.back().request_id,0,{})
	expect("37_offline_after_commit_local_play",restarted.local_play_allowed() and local_change(f,-3).status=="COMMITTED" and read(f).wallet.tokens==32)
	f=fixture(false);var disabled_io:=IO.new(f.root);disabled_io.read_career()
	expect("38_mac_no_enrollment",disabled_io.write_steam_state(disabled_io.steam_expected(binding),{"action":"enroll","server_revision":1,"server_checkpoint_hash":"a".repeat(64)}).status=="STEAM_DISABLED" and not read(f).has("_steam_local"))
	f=fixture();d=prepare(f);commit(f,d);prior=FileAccess.get_file_as_string(f.path);old=read(f);old.wallet.tokens=0
	expect("39_legacy_publish_cannot_overwrite_steam",PL._l5_publish_existing(f.path,old) and FileAccess.get_file_as_string(f.path)==prior)
	f=fixture();d=prepare(f);commit(f,d);old=read(f);old.wallet.tokens-=1;PM._write_json(f.path,old)
	expect("40_profile_writer_preserves_markers",read(f).wallet.tokens==34 and read(f).steam_wallet.applied_receipts.has("receipt1"))
	# Optional baseline is a read-only copy supplied in the temporary test project.
	for arg in args:
		if arg.begins_with("--baseline-playerlife="):
			var baseline_path:=arg.trim_prefix("--baseline-playerlife=")
			if not baseline_path.begins_with(ProjectSettings.globalize_path("res://")):quit(2);return
			var baseline=load(baseline_path)
			f=fixture(false);var reference:String=f.root.path_join("reference.json")
			var original:Dictionary=read(f);raw_write(reference,original)
			baseline.write_savegame(original.duplicate(true),reference);PL.write_savegame(original.duplicate(true),f.path)
			expect("41_nonsteam_matches_prepatch",FileAccess.get_file_as_string(reference)==FileAccess.get_file_as_string(f.path))
			f=fixture(false,true);old=read(f);old.wallet.tokens+=3;PL.write_savegame(old,f.path)
			expect("42_nonsteam_l5_unchanged",read(f).wallet.tokens==13 and read(f).l5_match.revision==2 and not read(f).has("_steam_local"))
	for intent_fault in ["before","disk_full","after"]:
		f=fixture();var failed_io:=FaultIO.new(f.root);failed_io.fault=intent_fault
		var prepared:Dictionary=f.w.prepare_persisted(failed_io,expected(failed_io),"receipt1","key1")
		expect("failed_intent_no_network_"+intent_fault,prepared.status!="REQUESTED" and f.w.resume().status=="PERSISTENCE_REQUIRED" and f.t.requests.is_empty() and f.w.local_play_allowed())
	print("RESULT ",passed," PASS / ",failed," FAIL")
	quit(0 if failed==0 else 1)
