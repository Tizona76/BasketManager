extends "res://tests/steam_wallet/test_steam_persistence.gd"
class ShopProbe:
	extends "res://shop_under_test.gd"
	var buys := 0
	var refreshes := 0
	func _steam_platform() -> bool: return true
	func _steam_buy() -> void: buys+=1
	func _set_status(_text: String) -> void: pass
	func _build_club_tokens_info_screen() -> void: refreshes+=1
class AsyncShopProbe:
	extends ShopProbe
	var binding_override := {"user_id":"user1","profile_uuid":"uuid1","career_id":"career1"}
	var renewals := 0
	func _steam_purchase_binding() -> Dictionary: return binding_override.duplicate(true)
	func _steam_request_session() -> void: renewals+=1
class PurchaseWallet:
	extends "res://scripts/SteamWallet.gd"
	func _environment_allowed() -> bool: return true
	func _new_purchase_wallet() -> RefCounted: return PurchaseWallet.new()
class Runtime:
	extends "res://scripts/SteamPurchases.gd"
	func environment_allowed() -> bool: return true
class FakeSteam:
	extends RefCounted
	signal microtransaction_auth_response(app_id: int, order_id: int, authorized: bool)
	signal get_ticket_for_web_api(handle: int, result: int, ticket_size: int, ticket_buffer: Array)
	func getAuthTicketForWebApi(_identity: String) -> void: pass
	func cancelAuthTicket(_handle: int) -> void: pass
	var calls := 0
	var app_id := 5069970
	func steamInitEx(app: int, embedded: bool) -> Dictionary:
		calls+=1
		return {"status":0 if app==5069970 and not embedded else 1}
	func getAppID() -> int: return app_id
	func run_callbacks() -> void: pass
	func steamShutdown() -> void: pass
func jwt() -> String:
	return "synthetic."+Marshalls.utf8_to_base64(JSON.stringify({"sub":"user1","exp":Time.get_unix_time_from_system()+3600}))+".signature"
func start(f: Dictionary) -> RefCounted:
	var w:=PurchaseWallet.new()
	w.purchase_enable(f.io,f.t.send,binding,jwt(),true)
	return w
var token := ""
func answer(f: Dictionary,w: RefCounted,body: Dictionary,code: int=200) -> Dictionary:
	return w.purchase_receive(f.t.requests.back().request_id,code,body,binding,token)
func order(state: String="AWAITING") -> Dictionary:
	return {"order_id":"123456789012345678","profile_uuid":"uuid1","career_id":"career1","pack_id":"tokens25","currency":"EUR","amount_minor":99,"state":state,"receipt":{"receipt_id":"receipt1","state":"confirmed"} if state=="PAID" else null}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-root="):base=arg.trim_prefix("--fixture-root=")
	if not base.begins_with("/private/tmp/") or ".." in base:quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	token=jwt()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--purchase-recover="):
			var directory := arg.trim_prefix("--purchase-recover=")
			if not directory.begins_with(base+"/"): quit(2);return
			var transport := Transport.new();var wallet := PurchaseWallet.new()
			wallet.purchase_enable(SteamIO.new(directory),transport.send,binding,token,true)
			var result := wallet.purchase_resume()
			var intent: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("save_local1_career1.json")))._steam_local.purchase
			var ok: bool=result.status=="REQUESTED" and transport.requests.back().headers.get("Idempotency-Key")==intent.key
			print("RECOVER_PASS" if ok else "RECOVER_FAIL");quit(0 if ok else 1);return
	var f:=fixture();var w:=PurchaseWallet.new()
	expect("disabled",w.purchase_enable(f.io,f.t.send,binding,token).status=="DISABLED")
	expect("jwt_missing",w.purchase_enable(f.io,f.t.send,binding,"",true).status=="AUTH_REQUIRED")
	expect("mac_refused",Wallet.new().purchase_enable(f.io,f.t.send,binding,token,true).status=="DISABLED")
	w.purchase_enable(f.io,f.t.send,binding,token,true)
	expect("persist_before_request",w.purchase_start("tokens25").status=="REQUESTED" and read(f)._steam_local.purchase.key!="" and f.t.requests.back().path.ends_with("catalog"))
	var key: String=read(f)._steam_local.purchase.key
	expect("double_click",w.purchase_start("tokens25").status=="REQUEST_PENDING" and f.t.requests.size()==1)
	answer(f,w,{})
	expect("create_key",f.t.requests.back().headers["Idempotency-Key"]==key)
	expect("timeout",answer(f,w,{},0).status=="UNCERTAIN_RETRY")
	var resumed:=PurchaseWallet.new();resumed.purchase_enable(SteamIO.new(f.root),f.t.send,binding,token,true)
	resumed.purchase_start("tokens75")
	expect("restart_same_intent",f.t.requests.back().body.pack_id=="tokens25" and f.t.requests.back().headers["Idempotency-Key"]==key)
	answer(f,resumed,order())
	expect("server_id_saved",read(f)._steam_local.purchase.order_id==order().order_id)
	var balance: int=read(f).wallet.tokens
	resumed.purchase_authorization(5069970,order().order_id,true)
	expect("callback_no_credit",read(f).wallet.tokens==balance and f.t.requests.back().path.ends_with("authorization"))
	expect("double_callback",resumed.purchase_authorization(5069970,order().order_id,true).status=="REQUEST_PENDING")
	answer(f,resumed,order("PAID"))
	expect("confirmed_checkpoint_first",f.t.requests.back().method=="PUT" and read(f).wallet.tokens==10)
	var request: Dictionary=f.t.requests.back()
	answer(f,resumed,{"profile_uuid":"uuid1","career_id":"career1","revision":2,"checkpoint_hash":"d".repeat(64),"snapshot":request.body.snapshot})
	expect("a5_delivery_requested",f.t.requests.back().path.ends_with("deliveries"))
	var candidate: Dictionary=f.t.requests.back().body.snapshot.duplicate(true)
	candidate.wallet.tokens+=25
	candidate.steam_wallet.applied_receipts.receipt1={"receipt_hash":"b".repeat(64),"quantity":25,"operation_id":"operation1"}
	var d: Dictionary={"operation_id":"operation1","receipt_id":"receipt1","profile_uuid":"uuid1","career_id":"career1","state":"prepared","expected_revision":2,"parent_hash":"d".repeat(64),"candidate_hash":"c".repeat(64),"candidate":candidate,"receipt_state":"confirmed","manual_review":false}
	answer(f,resumed,d)
	expect("atomic_credit_ack",read(f).wallet.tokens==35 and read(f)._steam_local.pending.phase=="committed" and f.t.requests.back().path.ends_with("ack"))
	answer(f,resumed,{},0)
	var paid_before: Dictionary = read(f).duplicate(true)
	resumed=PurchaseWallet.new();resumed.purchase_enable(SteamIO.new(f.root),f.t.send,binding,token,true);resumed.purchase_resume()
	expect("paid_resume_get_only",f.t.requests.back().method=="GET" and f.t.requests.back().path.ends_with("/orders/"+order().order_id))
	expect("paid_resume_preserves_receipt_and_career",read(f)._steam_local.purchase==paid_before._steam_local.purchase and read(f).career_id==paid_before.career_id)
	expect("paid_resume_no_save_or_balance_change",read(f)==paid_before)
	answer(f,resumed,order("PAID"))
	expect("restart_after_credit_retries_ack",f.t.requests.back().path.ends_with("/ack") and read(f).wallet.tokens==35)
	var ackid: String=f.t.requests.back().request_id
	var ack: Dictionary={"operation_id":"operation1","revision":3,"candidate_hash":"c".repeat(64)}
	expect("ack_completed",answer(f,resumed,ack).status=="PURCHASE_COMPLETE" and read(f)._steam_local.purchase==null)
	expect("duplicate_ack",resumed.purchase_receive(ackid,200,ack,binding,token).status=="STALE_RESPONSE" and read(f).wallet.tokens==35)
	expect("season_markers",read(f).season_tokens_earned==7 and read(f).steam_wallet.applied_receipts.has("receipt1"))
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25");answer(f,w,{});answer(f,w,order())
	w.purchase_authorization(5069970,order().order_id,false);answer(f,w,order("CANCELLED"))
	expect("cancel_no_credit",read(f).wallet.tokens==10 and read(f)._steam_local.purchase==null)
	f=fixture();var bad:=FaultIO.new(f.root);bad.fault="disk_full";w=PurchaseWallet.new();w.purchase_enable(bad,f.t.send,binding,token,true)
	expect("write_failure_no_network",w.purchase_start("tokens25").status=="WRITE_FAILED" and f.t.requests.is_empty())
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25")
	var other:=binding.duplicate();other.career_id="other"
	expect("late_context",w.purchase_receive(f.t.requests.back().request_id,200,{},other,token).status=="STALE_CONTEXT" and f.t.requests.size()==1)
	expect("wrong_app",w.purchase_authorization(480,"123",true).status=="IGNORED_CALLBACK")
	expect("offline_play",w.local_play_allowed())
	var native:=FakeSteam.new();var runtime:=Runtime.new()
	expect("native_init_simulated",runtime.initialize_api(native)=="READY")
	expect("one_native_init",runtime.initialize_api(native)=="READY" and native.calls==1)
	expect("callback_connected",native.microtransaction_auth_response.get_connections().size()==1)
	runtime._exit_tree();runtime.free()
	native=FakeSteam.new();native.app_id=480;runtime=Runtime.new()
	expect("wrong_native_app",runtime.initialize_api(native)=="STEAM_APPID_MISMATCH");runtime.free()
	var shop:=ShopProbe.new();shop._pending_tokens_amount=25;shop.PopupConfirm=Panel.new();shop.PopupConfirm.visible=true
	shop._steam_show_outcome({"status":"PURCHASE_COMPLETE"})
	expect("shop_complete_resets_confirmation",shop._pending_tokens_amount==0 and not shop.PopupConfirm.visible and shop.refreshes==1)
	shop._on_confirm_purchase()
	expect("windows_intercepts_stripe",shop.buys==1)
	var headers: PackedStringArray=shop._steam_headers({"headers":{"Authorization":"old","Content-Type":"ignored","Idempotency-Key":"key"}},"synthetic")
	var auth_count:=0
	for header in headers:
		if header.to_lower().begins_with("authorization:"):auth_count+=1
	expect("single_auth_header",auth_count==1 and headers.has("Authorization: Bearer synthetic") and headers.has("Idempotency-Key: key"))
	shop.PopupConfirm.free();shop.free()
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25");answer(f,w,{})
	var output: Array=[]
	var exit_code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script",get_script().resource_path,"--log-file",base.path_join("restart.log"),"--","--fixture-root="+base,"--purchase-recover="+f.root],output,true)
	expect("separate_process_restart_before_id",exit_code==0 and str(output).contains("RECOVER_PASS"))
	answer(f,w,order());w=PurchaseWallet.new();w.purchase_enable(SteamIO.new(f.root),f.t.send,binding,token,true);w.purchase_resume()
	expect("restart_after_id_same_order",f.t.requests.back().path.ends_with(order().order_id+"/resume"))
	var refunded:=order("REVERSED");refunded.receipt={"receipt_id":"receipt1","state":"revoked"}
	expect("refund_no_debit",answer(f,w,refunded).status=="ORDER_REVERSED" and read(f).wallet.tokens==10)
	w.purchase_resume();expect("server_conflict",answer(f,w,{},409).status=="CONFLICT" and read(f)._steam_local.purchase!=null)
	w.purchase_resume();expect("session_expired_response",answer(f,w,{},401).status=="AUTH_REQUIRED" and read(f)._steam_local.purchase!=null)
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25");answer(f,w,{})
	expect("callback_before_id_ignored",w.purchase_authorization(5069970,order().order_id,true).status=="IGNORED_CALLBACK")
	answer(f,w,order("FAILED"));expect("refusal_no_credit",read(f)._steam_local.purchase==null and read(f).wallet.tokens==10)
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25");answer(f,w,{});answer(f,w,order())
	local_change(f,9);local_change(f,-6)
	w.purchase_resume();answer(f,w,order("PAID"))
	expect("gain_spend_checkpoint_preserved",f.t.requests.back().body.snapshot.wallet.tokens==13 and read(f).wallet.tokens==13)
	var expired: String="synthetic."+Marshalls.utf8_to_base64(JSON.stringify({"sub":"user1","exp":1}))+".signature"
	expect("expired_session_no_start",PurchaseWallet.new().purchase_enable(f.io,f.t.send,binding,expired,true).status=="AUTH_REQUIRED")
	# Newly wired first registration uses the existing persistence transition.
	f=fixture(false);w=PurchaseWallet.new()
	expect("prepare_unregistered",w.purchase_prepare(f.io,f.t.send,binding,token).status=="REQUESTED" and f.t.requests.back().path.ends_with("/enroll"))
	var initial: Dictionary=f.t.requests.back().body.snapshot.duplicate(true)
	initial.steam_wallet={"binding":binding.duplicate(true),"applied_receipts":{}}
	var first: Dictionary={"profile_uuid":"uuid1","career_id":"career1","revision":1,"checkpoint_hash":"a".repeat(64),"snapshot":initial}
	expect("enroll_preserves_balance",answer(f,w,first,201).status=="READY" and read(f).wallet.tokens==10 and read(f)._steam_local.server_revision==1)
	w.purchase_start("tokens150");answer(f,w,{})
	expect("ready_to_pay_correct_pack",f.t.requests.back().body=={"profile_uuid":"uuid1","career_id":"career1","pack_id":"tokens150","language":"en"})
	f=fixture(false);w=PurchaseWallet.new();w.purchase_prepare(f.io,f.t.send,binding,token)
	var changed: Dictionary=read(f);changed.wallet.tokens=11;raw_write(f.path,changed)
	expect("enroll_stale_local_refused",answer(f,w,first,201).status=="STALE" and read(f).wallet.tokens==11 and not read(f).has("steam_wallet"))
	f=fixture();w=PurchaseWallet.new();w.purchase_prepare(f.io,f.t.send,binding,token)
	var cp: Dictionary={"profile_uuid":"uuid1","career_id":"career1","revision":2,"checkpoint_hash":"b".repeat(64),"snapshot":Wallet.snapshot_for_server(read(f))}
	expect("restored_old_revision_blocks_order",answer(f,w,cp).status=="CHECKPOINT_CONFLICT" and read(f)._steam_local.get("purchase")==null)
	f=fixture(false);w=PurchaseWallet.new();w.purchase_prepare(f.io,f.t.send,binding,token)
	expect("enrollment_network_uncertain_no_order",answer(f,w,{},0).status=="UNCERTAIN_RETRY" and not read(f).has("_steam_local"))
	f=fixture();w=PurchaseWallet.new();w.purchase_prepare(f.io,f.t.send,binding,token)
	cp={"profile_uuid":"uuid1","career_id":"career1","revision":1,"checkpoint_hash":"a".repeat(64),"snapshot":Wallet.snapshot_for_server(read(f))}
	expect("existing_checkpoint_verified",answer(f,w,cp).status=="READY")
	f=fixture();w=PurchaseWallet.new();w.purchase_enable(f.io,f.t.send,binding,token,true);w.purchase_start("tokens25");answer(f,w,{})
	var async_shop:=AsyncShopProbe.new();async_shop._steam_purchase=w;async_shop._steam_http_pending=true
	async_shop._steam_authorized(5069970,order().order_id,true)
	expect("early_callback_retained",async_shop._steam_deferred_authorizations.has(order().order_id))
	answer(f,w,order());async_shop._steam_http_pending=false;async_shop._steam_drain_authorizations()
	expect("early_callback_forwarded_after_order",f.t.requests.back().path.ends_with("/authorization") and async_shop._steam_deferred_authorizations.is_empty())
	async_shop._steam_runtime=Node.new()
	async_shop._steam_show_outcome({"status":"AUTH_REQUIRED"});async_shop._steam_show_outcome({"status":"AUTH_REQUIRED"})
	expect("one_controlled_renewal",async_shop.renewals==1)
	async_shop._steam_runtime.free();async_shop.free()
	var original:=FileAccess.get_file_as_string("res://scripts/ShopTokens_original.gd")
	var updated:=FileAccess.get_file_as_string("res://scripts/ShopTokens_updated.gd")
	var intercept: String="\tif _steam_platform() and not _payment_confirmation_shown:\n\t\t_steam_buy()\n\t\treturn\n"
	updated=updated.replace('\tif _steam_platform() and BtnCancel != null:\n\t\tleft = maxf(left, BtnCancel.offset_right + 16.0)\n',"")
	updated=updated.replace('func _add_buy_club_tokens_access(root: VBoxContainer) -> void:\n\tif not _steam_platform():\n\t\treturn\n','func _add_buy_club_tokens_access(root: VBoxContainer) -> void:\n\treturn\n')
	expect("legacy_shop_body_unchanged",updated.split("# Optional Steam path;")[0].strip_edges().replace(intercept,"").replace('\tif _steam_platform(): _steam_pack="" # Stop preparation before any new order.\n',"")==original.strip_edges())
	print("RESULT ",passed," PASS / ",failed," FAIL");quit(0 if failed==0 else 1)
