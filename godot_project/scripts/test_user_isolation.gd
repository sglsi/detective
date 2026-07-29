extends Control
## 临时隔离测试（场景上下文，autoload 全局已注册）。跑完即删。

const EMAIL_A := "iso_test_a@detective.local"
const EMAIL_B := "iso_test_b@detective.local"
const USER_A  := "iso_user_A"
const USER_B  := "iso_user_B"
const GUEST_STATE := 0
const LOGGED_IN_STATE := 3

var _fails := 0
var _passes := 0

func _ready() -> void:
	await get_tree().create_timer(0.15).timeout
	await _run()
	print("=== 结果: PASS=%d  FAIL=%d ===" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] ", msg)
	else:
		_fails += 1
		print("[FAIL] ", msg)

func _force_offline() -> void:
	# 防止启动时异步连通性探测把 is_online 翻成 true，导致走后端路径（无后端时行为不确定）
	if APIManager != null:
		APIManager.is_online = false

func _run() -> void:
	_cleanup_test_accounts()
	_force_offline()

	await AuthManager.register(USER_A, EMAIL_A, "pwA_123", "")
	await get_tree().create_timer(0.05).timeout
	var idA: String = AuthManager.get_user_id()
	var nsA: String = SaveManager._user_namespace()
	_check(AuthManager.is_authenticated(), "A 注册后处于已认证态")
	_check(not idA.is_empty(), "A 的 user_id 非空 (id=%s)" % idA)
	GameManager.current_scene_id = "scene1"
	await GameManager.do_save(1, {"marker": "A_SAVE_11111", "clue_ids": ["cA1"]})
	await get_tree().create_timer(0.05).timeout
	var a_path: String = SaveManager.slot_path(0)
	_check(FileAccess.file_exists(a_path), "A 的存档文件已写入: %s" % a_path)
	_check(nsA != "guest", "A 的命名空间不是共享 guest (ns=%s)" % nsA)

	await AuthManager.register(USER_B, EMAIL_B, "pwB_456", "")
	await get_tree().create_timer(0.05).timeout
	var idB: String = AuthManager.get_user_id()
	var nsB: String = SaveManager._user_namespace()
	_check(idA != idB, "A 与 B 的 user_id 互不相同 (A=%s B=%s)" % [idA, idB])
	_check(nsA != nsB, "A 与 B 的命名空间互不相同 (A=%s B=%s)" % [nsA, nsB])
	GameManager.current_scene_id = "scene2"
	await GameManager.do_save(2, {"marker": "B_SAVE_222222", "clue_ids": ["cB1"]})
	await get_tree().create_timer(0.05).timeout
	_force_offline()

	var b_list = SaveManager.get_slot_list_sorted()
	var b_sees_a := false
	for m in b_list:
		var p = SaveManager.slot_path(m.get("slot", 0))
		if FileAccess.file_exists(p) and FileAccess.get_file_as_string(p).contains("A_SAVE_11111"):
			b_sees_a = true
	_check(not b_sees_a, "B 的存档列表中不包含 A 的存档内容（隔离）")
	_check(b_list.size() >= 1, "B 有自己的存档 (数量=%d)" % b_list.size())

	_force_offline()
	await AuthManager.login(EMAIL_A, "pwA_123")
	await get_tree().create_timer(0.05).timeout
	_check(AuthManager.get_user_id() == idA, "重新登录后 A 的 id 不变")
	var a_list = SaveManager.get_slot_list_sorted()
	var a_sees_b := false
	for m in a_list:
		var p = SaveManager.slot_path(m.get("slot", 0))
		if FileAccess.file_exists(p) and FileAccess.get_file_as_string(p).contains("B_SAVE_222222"):
			a_sees_b = true
	_check(not a_sees_b, "A 的存档列表中不包含 B 的存档内容（隔离）")

	AuthManager.user_data = {}
	AuthManager.current_auth_state = GUEST_STATE
	await get_tree().create_timer(0.05).timeout
	var ns_guest: String = SaveManager._user_namespace()
	_check(ns_guest == "guest", "未登录时为 guest 命名空间")
	var guest_path: String = SaveManager.slot_path(0)
	_check(guest_path != a_path, "guest 命名空间路径与用户 A 完全不同（不会串档）")
	_force_offline()
	await AuthManager.login(EMAIL_A, "pwA_123")
	await get_tree().create_timer(0.05).timeout
	_check(SaveManager.slot_path(0) == a_path, "A 重新登录后命名空间稳定一致")

	AuthManager.user_data = {}
	AuthManager.current_auth_state = GUEST_STATE
	await get_tree().create_timer(0.05).timeout
	AuthManager._restore_session()
	await get_tree().create_timer(0.05).timeout
	_check(AuthManager.is_authenticated(), "重载后自动恢复会话：仍处于已认证态")
	_check(AuthManager.get_user_id() == idA, "重载后恢复的是正确的用户 A (id=%s)" % AuthManager.get_user_id())

	_cleanup_test_accounts()
	print("[INFO] 测试账号与存档已清理（未触碰真实 guest/其他用户数据）")

func _cleanup_test_accounts() -> void:
	var accounts = AuthManager._load_accounts()
	var changed := false
	for k in accounts.keys():
		var e = accounts[k].get("email", "")
		if e == EMAIL_A or e == EMAIL_B:
			accounts.erase(k)
			changed = true
	if changed:
		AuthManager._save_accounts(accounts)
	var accts2 = AuthManager._load_accounts()
	for k in accts2.keys():
		var e = accts2[k].get("email", "")
		if e == EMAIL_A or e == EMAIL_B:
			_rm_dir(SaveManager._sanitize_dir_name(k))

func _rm_dir(ns: String) -> void:
	var base = "user://saves/" + ns
	for i in 3:
		var p = base + "/slot_" + str(i) + ".json"
		if FileAccess.file_exists(p):
			var d = DirAccess.open(base)
			if d: d.remove("slot_" + str(i) + ".json")
	var d2 = DirAccess.open("user://saves")
	if d2: d2.remove(ns)
