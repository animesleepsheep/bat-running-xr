extends RefCounted
## Local visitor records are session-only and never uploaded. Signed-in queue is
## memory-only on shared headsets; users explicitly sync before signing out.
var guest_sessions := 0
var guest_selections := 0
var guest_best := 0
var queue: Array[Dictionary] = []
var account := ""
var profile: Dictionary = {}
const LIMIT := 100

func event_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20,12)]

func set_account(id: String) -> void:
	queue.clear()
	profile.clear()
	account = id

func platform_id() -> String:
	if OS.has_feature("quest3"):
		return "quest3"
	if OS.has_feature("focus3"):
		return "focus3"
	return "desktop"

func record(score: int) -> bool:
	if score < 1 or score > 10000:
		return false
	if account.is_empty():
		guest_sessions += 1
		guest_selections += score
		guest_best = maxi(guest_best, score)
		return true
	if queue.size() >= LIMIT:
		return false
	queue.append({"p_event_id":event_id(),"p_activity":"control_practice","p_score":score,"p_platform":platform_id()})
	return true

func clear_guest() -> void:
	guest_sessions = 0
	guest_selections = 0
	guest_best = 0

func ack(id: String) -> bool:
	if queue.is_empty() or queue[0].get("p_event_id") != id:
		return false
	queue.pop_front()
	return true

func summary() -> Dictionary:
	if account.is_empty():
		return {"sessions":guest_sessions,"selections":guest_selections,"best":guest_best,"recent":[]}
	return profile.duplicate(true)
