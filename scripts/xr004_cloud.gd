extends Node
## Supabase Auth + Data API. Only public publishable key in exported config.
## No credentials or tokens on disk; no raw tracking/PII in game event tables.
signal changed
const Records = preload("res://scripts/xr004_records.gd")
var records := Records.new()
var endpoint := ""
var public_key := ""
var access := ""
var refresh := ""
var expires := 0
var generation := 0
var busy := false
var note := "Guest / offline"
var test_mode := false
var http: HTTPRequest

func configure(smoke: bool) -> void:
	test_mode = smoke
	if smoke:
		return
	var file := FileAccess.open("res://cloud/config.json", FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	var url := str(data.get("url", "")).trim_suffix("/")
	var key := str(data.get("publishable_key", ""))
	var regex := RegEx.new()
	regex.compile("^https://[a-z0-9]{20}\\.supabase\\.co$")
	if regex.search(url) != null and key.begins_with("sb_publishable_"):
		endpoint = url
		public_key = key

func available() -> bool:
	return not endpoint.is_empty() and not public_key.is_empty()

func _notify(message: String) -> void:
	note = message
	changed.emit()

func _request(path: String, body: Dictionary, token: String, epoch: int) -> Dictionary:
	if test_mode or not available() or generation != epoch:
		return {"ok":false}
	var req := HTTPRequest.new()
	req.timeout = 15.0
	req.max_redirects = 0
	req.body_size_limit = 262144
	req.use_threads = true
	add_child(req)
	http = req
	var headers := PackedStringArray(["apikey: " + public_key,"Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var err := req.request(endpoint + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http = null
		req.queue_free()
		return {"ok":false}
	var response: Array = await req.request_completed
	if http == req:
		http = null
	req.queue_free()
	if epoch != generation:
		return {"ok":false}
	var status := int(response[1])
	var raw: PackedByteArray = response[3]
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return {"ok":response[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300 and decoded is Dictionary,"data":decoded,"status":status}

func login(email: String, password: String) -> void:
	if busy or not available() or not records.account.is_empty():
		return
	if email.length() > 254 or not email.contains("@") or password.length() < 6 or password.length() > 128:
		_notify("Check email / password")
		return
	busy = true
	generation += 1
	var epoch := generation
	_notify("Signing in...")
	var answer: Dictionary = await _request("/auth/v1/token?grant_type=password",{"email":email,"password":password},"",epoch)
	if epoch != generation:
		return
	busy = false
	if not answer.get("ok", false) or not _accept_session(answer.get("data", {})):
		_notify("Sign-in failed. Check account or connection.")
		return
	_notify("Signed in / sync to load records")
	sync()

func _accept_session(data: Dictionary) -> bool:
	var user: Variant = data.get("user", {})
	if not user is Dictionary or user.get("is_anonymous",false):
		return false
	var uid := str(user.get("id",""))
	var a := str(data.get("access_token",""))
	var r := str(data.get("refresh_token",""))
	if uid.is_empty() or a.is_empty() or r.is_empty():
		return false
	if not records.account.is_empty() and records.account != uid:
		return false
	if records.account.is_empty():
		records.clear_guest()
		records.set_account(uid)
	access = a
	refresh = r
	expires = int(Time.get_unix_time_from_system()) + int(data.get("expires_in",3600))
	return true

func sync() -> void:
	if busy or not available() or records.account.is_empty():
		return
	busy = true
	var epoch := generation
	_notify("Syncing...")
	if expires <= int(Time.get_unix_time_from_system()) + 45:
		var renewed: Dictionary = await _request("/auth/v1/token?grant_type=refresh_token",{"refresh_token":refresh},"",epoch)
		if epoch != generation:
			return
		if not renewed.get("ok",false) or not _accept_session(renewed.get("data",{})):
			busy = false
			_notify("Session unavailable. Retry or sign out.")
			return
	while not records.queue.is_empty():
		var event: Dictionary = records.queue[0].duplicate()
		var sent: Dictionary = await _request("/rest/v1/rpc/br_xr_submit",event,access,epoch)
		if epoch != generation:
			return
		var data: Variant = sent.get("data",{})
		if not sent.get("ok",false) or not data is Dictionary or data.get("accepted") != true or data.get("event_id") != event["p_event_id"]:
			busy = false
			_notify("Sync failed. Pending records retained.")
			return
		if not records.ack(event["p_event_id"]):
			busy = false
			_notify("Queue changed. Retry.")
			return
	var result: Dictionary = await _request("/rest/v1/rpc/br_xr_profile",{},access,epoch)
	if epoch != generation:
		return
	busy = false
	if result.get("ok",false):
		records.profile = result["data"]
		_notify("Cloud records synced")
	else:
		_notify("Profile unavailable. Retry sync.")

func cancel_login() -> void:
	if busy and records.account.is_empty():
		generation += 1
		busy = false
		_notify("Sign-in cancelled")

func sign_out(discard: bool = false) -> bool:
	if busy:
		_notify("Sync in progress. Try again after completion.")
		return false
	if not records.queue.is_empty() and not discard:
		_notify("Sync first or choose discard + sign out")
		return false
	generation += 1
	busy = false
	var old_access := access
	access = ""
	refresh = ""
	expires = 0
	records.set_account("")
	_notify("Guest / offline")
	# Best-effort revoke the current session, without retaining any local tokens.
	if available() and not old_access.is_empty() and not test_mode:
		var req := HTTPRequest.new()
		req.timeout = 8.0
		req.max_redirects = 0
		add_child(req)
		req.request_completed.connect(func(_r,_c,_h,_b): req.queue_free(), CONNECT_ONE_SHOT)
		if req.request(endpoint + "/auth/v1/logout?scope=local",PackedStringArray(["apikey: " + public_key,"Authorization: Bearer " + old_access]),HTTPClient.METHOD_POST) != OK:
			req.queue_free()
	return true
