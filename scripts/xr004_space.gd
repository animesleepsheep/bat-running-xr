extends "res://scripts/xr003_space.gd"
var account_active := false
var account_note := ""
var cloud_available := false
var summary: Dictionary = {}
var pending_count := 0
var email_text := ""
var password_text := ""
var editing_password := false
var keyboard_page := 0
var email_label: Label3D
var password_label: Label3D
var keyboard_labels: Array[Label3D] = []
const KEY_ROWS := ["abcdefghijklmnopqrstuvwxyz0123456789@._-+","ABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&*()=?:/[]","0123456789!@#$%^&*()-_=+[]{}:;,.?/|~"]

func _ready() -> void:
	if route in ["account","profile","login"]:
		_architecture()
		match route:
			"account": _account()
			"profile": _profile()
			"login": _login()
	else:
		super._ready()

func _lobby() -> void:
	_make_panel(0.74,2.60,2.38,"BAT RUNNING","XR  /  ADVENTURE HUB")
	_button("preview","START ADVENTURE","Course preview",0.40)
	_button("practice","CONTROL PRACTICE","Save your practice results",0.04)
	_button("profile","MY ADVENTURE","Learning history",-0.32)
	_button("account","PLAYER / GUEST","Sign in or play offline",-0.68)
	_button("settings","SETTINGS","Model quality and controls",-1.04)
	_stage(-1.18,-2.2,0.30)
	label3(self,"WELCOME, RUNNER!",Vector3(-1.18,1.65,-2.2),0.095,MINT)
	status_label = label3(self,"PLAYER" if account_active else "GUEST / OFFLINE",Vector3(-1.18,0.62,-2.2),0.075,MINT)

func _practice() -> void:
	_make_panel(0,3.0,2.2,"CONTROL PRACTICE","Select a target, then save a learning record")
	_button("practice_hit","SELECT TARGET","Trigger or A-X",0.25)
	_button("practice_save","SAVE RESULT","Record selections from this round",-0.11)
	_button("practice_reset","RESET SCORE","Clear unsaved practice count",-0.47)
	_button("lobby","BACK TO HUB","Return to lobby",-0.83)
	status_label = label3(panel,"SCORE  0",Vector3(0,0.48,0.025),0.085,MINT)

func _account() -> void:
	_make_panel(0,3.15,2.18,"PLAYER ACCOUNT","Shared headset / no saved password")
	if account_active:
		_button("sync","SYNC RECORDS","Upload pending records + load profile",0.26)
		_button("profile","MY ADVENTURE","View learning record",-0.10)
		_button("logout","SIGN OUT","Sync required if pending",-0.46)
		_button("discard","DISCARD + SIGN OUT","Unsynced records will be lost",-0.82)
	else:
		_button("login","SIGN IN","Adult / authorized account only" if cloud_available else "Cloud not configured",0.24)
		_button("profile","GUEST RECORDS","Current session only",-0.12)
		_button("clear_guest","CLEAR GUEST","Reset this headset session",-0.48)
		_button("lobby","BACK TO HUB","Continue offline",-0.84)
	status_label = label3(panel,account_note,Vector3(0,0.48,0.025),0.063,MINT)

func _profile() -> void:
	_make_panel(0,3.2,2.2,"MY ADVENTURE","Cloud account" if account_active else "Guest / this session only")
	var total := int(summary.get("sessions",0))
	var selections := int(summary.get("selections",0))
	var best := int(summary.get("best",0))
	label3(panel,"ROUNDS  %d     SELECTS  %d     BEST  %d" % [total,selections,best],Vector3(0,0.35,0.025),0.10,MINT)
	var recent: Array = summary.get("recent",[])
	for i in range(mini(recent.size(),3)):
		var item: Dictionary = recent[i]
		label3(panel,"%s  /  %d selects  /  %s" % [str(item.get("recorded_at","")).left(10),int(item.get("score",0)),str(item.get("platform",""))],Vector3(0,0.14-i*0.13,0.025),0.07,Color.WHITE)
	_button("sync" if account_active else "clear_guest","SYNC  /  %d PENDING" % pending_count if account_active else "CLEAR GUEST RECORDS","Results are practice, not grades",-0.47)
	_button("lobby","BACK TO HUB","Continue adventure",-0.83)
	status_label = label3(panel,account_note,Vector3(0,-0.27,0.025),0.063,MINT)

func _key(id: String, text: String, x: float, y: float, width: float = 0.27) -> Label3D:
	var center := Vector2(x,y)
	panel.add_button(id,center,Vector2(width,0.22))
	choices.append(id)
	button_meshes[id] = box(panel,Vector3(width,0.22,0.05),Vector3(x,y,0),Color("34516f"))
	return label3(panel,text,Vector3(x,y,0.035),0.085,Color.WHITE)

func _login() -> void:
	_make_panel(0,3.7,2.65,"SIGN IN","Use an existing authorized account")
	email_label = _key("field_email","",0,0.65,3.3)
	password_label = _key("field_password","",0,0.37,3.3)
	for i in range(40):
		var x := -1.485 + float(i%10)*0.33
		var y := 0.04-floorf(float(i)/10.0)*0.26
		keyboard_labels.append(_key("char_"+str(i),"",x,y))
	_key("keyboard_page","ABC / 123",-1.15,-1.03,1.05)
	_key("backspace","DEL",0,-1.03,0.8)
	_key("submit_login","SIGN IN",1.14,-1.03,1.05)
	_key("account","BACK",-1.15,-1.28,1.05)
	status_label = label3(panel,account_note,Vector3(0.60,-1.23,0.025),0.064,MINT)
	_refresh_keyboard()

func _refresh_keyboard() -> void:
	email_label.text = ("EMAIL > " if not editing_password else "EMAIL: ") + email_text.right(38)
	password_label.text = ("PASSWORD > " if editing_password else "PASSWORD: ") + "*".repeat(mini(password_text.length(),32))
	var chars: String = KEY_ROWS[keyboard_page]
	for i in range(keyboard_labels.size()):
		keyboard_labels[i].text = chars.substr(i,1) if i < chars.length() else ""

func keyboard_action(id: String) -> bool:
	if route != "login":
		return false
	if id == "field_email":
		editing_password = false
	elif id == "field_password":
		editing_password = true
	elif id == "keyboard_page":
		keyboard_page = (keyboard_page + 1)%KEY_ROWS.size()
	elif id == "backspace":
		if editing_password:
			password_text = password_text.left(maxi(0,password_text.length()-1))
		else:
			email_text = email_text.left(maxi(0,email_text.length()-1))
	elif id.begins_with("char_"):
		var n := id.trim_prefix("char_").to_int()
		var chars: String = KEY_ROWS[keyboard_page]
		if n >= 0 and n < chars.length():
			append_character(chars.substr(n,1))
	else:
		return false
	_refresh_keyboard()
	return true

func append_character(ch: String) -> void:
	if editing_password and password_text.length()<128:
		password_text += ch
	elif not editing_password and email_text.length()<254:
		email_text += ch
