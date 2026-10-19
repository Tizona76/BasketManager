extends "res://tests/steam_wallet/test_steam_persistence.gd"

func cloud(f: Dictionary) -> RefCounted:
	var w := TestWallet.new()
	w.enable_cloud(f.t.send)
	return w
func response(f: Dictionary, revision: int = 2) -> Dictionary:
	return {"profile_uuid":"uuid1","career_id":"career1","revision":revision,"checkpoint_hash":"d".repeat(64),"snapshot":f.t.requests.back().body.snapshot.duplicate(true)}
func receive_cloud(w: RefCounted, f: Dictionary, code: int, reply: Dictionary, token: String = "jwt1") -> Dictionary:
	return w.cloud_receive(f.io,binding,token,f.t.requests.back().request_id,code,reply)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-root="):base=arg.trim_prefix("--fixture-root=")
	if not base.begins_with("/private/tmp/") or ".." in base or ProjectSettings.globalize_path("res://").begins_with("/Users/"):quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cloud-recover="):
			var directory:=arg.trim_prefix("--cloud-recover=")
			if not directory.begins_with(base+"/"):quit(2);return
			var child_fixture:={"io":SteamIO.new(directory),"root":directory,"path":directory.path_join("save_local1_career1.json"),"t":Transport.new()}
			var child_wallet:=cloud(child_fixture)
			var child_request:Dictionary=child_wallet.cloud_request(child_fixture.io,binding,"jwt1",false)
			var child_ok:bool=child_request.status=="REQUESTED" and child_fixture.t.requests.back().method=="PUT"
			if child_ok:child_ok=receive_cloud(child_wallet,child_fixture,200,response(child_fixture)).status=="COMMITTED"
			print("CHILD_CLOUD_PASS" if child_ok else "CHILD_CLOUD_FAIL");quit(0 if child_ok else 1);return
	var f:=fixture();var w:=TestWallet.new()
	expect("default_disabled",w.cloud_request(f.io,binding,"jwt1",true).status=="DISABLED" and f.t.requests.is_empty())
	expect("Mac_environment_refused",Wallet.new().enable_cloud(f.t.send).status=="ENVIRONMENT_REFUSED")
	expect("ordinary_routes_legacy",not Wallet.cloud_enrolled({"wallet":{"tokens":12}}))
	expect("damaged_enrollment_no_fallback",Wallet.cloud_enrolled({"_steam_local":null}))
	w=cloud(f)
	expect("missing_jwt",w.cloud_request(f.io,binding,"",true).status=="AUTH_REQUIRED" and f.t.requests.is_empty())
	expect("isolated_put",w.cloud_request(f.io,binding,"jwt1",true).status=="REQUESTED" and f.t.requests.back().path==Wallet.CHECKPOINT_API and f.t.requests.back().method=="PUT")
	expect("intent_before_network",read(f)._steam_local.cloud_pending!=null and not f.t.requests.back().body.snapshot.has("_steam_local"))
	var reply:=response(f);var result:=receive_cloud(w,f,200,reply)
	expect("put_persisted",result.status=="COMMITTED" and read(f)._steam_local.server_revision==2 and read(f)._steam_local.server_checkpoint_hash==reply.checkpoint_hash and read(f)._steam_local.cloud_pending==null)
	expect("balance_unchanged",read(f).wallet.tokens==10 and read(f).season_tokens_earned==7)
	w=cloud(f);w.cloud_request(f.io,binding,"jwt1",false)
	expect("get_checkpoint",f.t.requests.back().method=="GET" and f.t.requests.back().path.begins_with(Wallet.CHECKPOINT_API))
	expect("get_verified",receive_cloud(w,f,200,reply).status=="CHECKPOINT_VERIFIED")
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f);local_change(f,9);local_change(f,-6)
	expect("progress_during_put",receive_cloud(w,f,200,reply).status=="COMMITTED" and read(f).wallet.tokens==13 and read(f).season_tokens_earned==16)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f,8)
	expect("wrong_revision",receive_cloud(w,f,200,reply).status=="CHECKPOINT_CONFLICT" and read(f)._steam_local.server_revision==1)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true)
	expect("409_only_cloud",receive_cloud(w,f,409,{}).status=="CHECKPOINT_CONFLICT" and w.local_play_allowed() and local_change(f,2).status=="COMMITTED" and w.cloud_request(f.io,binding,"jwt1",true).status=="CHECKPOINT_CONFLICT")
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);var sent:Dictionary=f.t.requests.back().duplicate(true)
	expect("network_loss",receive_cloud(w,f,0,{}).status=="NETWORK_ERROR" and local_change(f,-2).status=="COMMITTED")
	w=cloud(f);w.cloud_request(f.io,binding,"jwt1",false)
	expect("restart_pending_same_request",f.t.requests.back().body==sent.body and f.t.requests.back().headers["Idempotency-Key"]==sent.headers["Idempotency-Key"])
	expect("restart_commit_preserves_spend",receive_cloud(w,f,200,response(f)).status=="COMMITTED" and read(f).wallet.tokens==8)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true)
	expect("expired_jwt",receive_cloud(w,f,401,{}).status=="AUTH_REQUIRED")
	w.cloud_request(f.io,binding,"jwt2",true)
	expect("refreshed_jwt",f.t.requests.back().headers.Authorization=="Bearer jwt2" and receive_cloud(w,f,200,response(f),"jwt2").status=="COMMITTED")
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f)
	expect("late_changed_account",receive_cloud(w,f,200,reply,"otherjwt").status=="CONTEXT_CHANGED" and read(f)._steam_local.server_revision==1)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f);var other:=binding.duplicate(true);other.career_id="career2"
	expect("late_changed_career",w.cloud_receive(f.io,other,"jwt1",f.t.requests.back().request_id,200,reply).status=="CONTEXT_CHANGED")
	f=fixture();var delivery:=prepare(f);commit(f,delivery)
	# Complete the old delivery before a checkpoint: immutable markers survive.
	var rec:Dictionary=f.io.read_steam_recovery(binding)
	f.io.write_steam_state(expected(f.io),{"action":"ack","ack":{"operation_id":"op1","candidate_hash":delivery.candidate_hash,"revision":2}})
	w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f,3)
	expect("receipts_preserved",receive_cloud(w,f,200,reply).status=="COMMITTED" and read(f).steam_wallet.applied_receipts.has("receipt1") and read(f).wallet.tokens==35)
	f=fixture(true,true);w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f);var doc:=read(f);doc.l5_match["pending"]={"match_id":"m1"};f.io.read_career();f.io.write_verified(doc)
	expect("L5_pending_defers_ack",receive_cloud(w,f,200,reply).status=="L5_PENDING" and read(f)._steam_local.cloud_pending!=null)
	doc=read(f);doc.l5_match.erase("pending");doc.l5_match.revision=2;f.io.read_career();f.io.write_verified(doc);w.cloud_request(f.io,binding,"jwt1",true)
	expect("postmatch_retry",receive_cloud(w,f,200,response(f)).status=="COMMITTED" and read(f).l5_match.revision==2)
	for fault_name in ["before","disk_full","after","indeterminate"]:
		f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f)
		var fault_io:=FaultIO.new(f.root);fault_io.fault=fault_name
		result=w.cloud_receive(fault_io,binding,"jwt1",f.t.requests.back().request_id,200,reply)
		var disk:=read(f)
		expect("atomic_ack_"+fault_name,(disk._steam_local.server_revision==1 and disk._steam_local.cloud_pending!=null or disk._steam_local.server_revision==2 and disk._steam_local.cloud_pending==null) and disk.wallet.tokens==10)
		w=cloud(f);w.cloud_request(f.io,binding,"jwt1",false)
		if disk._steam_local.server_revision==1:result=receive_cloud(w,f,200,response(f))
		else:result=receive_cloud(w,f,200,reply)
		expect("recovery_ack_"+fault_name,result.status in ["COMMITTED","CHECKPOINT_VERIFIED"])
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",false);local_change(f,2)
	expect("GET_late_local_progress",receive_cloud(w,f,200,{}).status=="STALE_RESPONSE" and read(f).wallet.tokens==12)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f);reply.snapshot.wallet.tokens=999
	expect("server_changed_snapshot_rejected",receive_cloud(w,f,200,reply).status=="CHECKPOINT_CONFLICT" and read(f).wallet.tokens==10)
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);reply=response(f)
	var reordered:Dictionary={}
	var keys:Array=reply.snapshot.keys();keys.sort()
	for key in keys:reordered[key]=reply.snapshot[key]
	reply.snapshot=reordered
	expect("server_canonical_key_order",receive_cloud(w,f,200,reply).status=="COMMITTED")
	f=fixture();var server_snapshot:Dictionary=Wallet.snapshot_for_server(read(f));local_change(f,4);w=cloud(f);w.cloud_request(f.io,binding,"jwt1",false)
	reply={"profile_uuid":"uuid1","career_id":"career1","revision":1,"checkpoint_hash":"a".repeat(64),"snapshot":server_snapshot}
	expect("GET_offline_progress_not_conflict",receive_cloud(w,f,200,reply).status=="CHECKPOINT_VERIFIED" and read(f).wallet.tokens==14 and w.cloud_request(f.io,binding,"jwt1",true).status=="REQUESTED")
	f=fixture();w=cloud(f);w.cloud_request(f.io,binding,"jwt1",true);local_change(f,-2)
	var child_output:Array=[]
	var child_code:=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/steam_wallet/test_steam_cloud.gd","--log-file",base.path_join("child.log"),"--","--fixture-root="+base,"--cloud-recover="+str(f.root)]),child_output,true)
	expect("separate_process_checkpoint_recovery",child_code==0 and str(child_output).contains("CHILD_CLOUD_PASS") and read(f)._steam_local.server_revision==2 and read(f)._steam_local.cloud_pending==null and read(f).wallet.tokens==8)
	print("RESULT ",passed," PASS / ",failed," FAIL");quit(0 if failed==0 else 1)
