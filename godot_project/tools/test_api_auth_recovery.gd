extends Control

## 回归测试：Console 红字「401 Unauthorized / PUT /api/progress/ 404」的根因修复
##
## 覆盖两组根因：
##  A/B — 空 case_id 拼进 URL（`/api/progress/`）→ 请求必然失败
##  C   — 本地残留失效令牌 → 所有鉴权请求 401，且客户端永不自愈
##        （后端在带 Authorization 头时会跳过游客回退，见 middleware/auth.js）
##  D   — 启动时无校验地恢复 session.json 里的令牌（含哨兵值 "local"）
##
## 本测试**对真实后端**（127.0.0.1:3001）发请求，属端到端验证。
## 运行：godot --headless --path godot_project res://scenes/test_api_auth_recovery.tscn

const API_BASE := "http://127.0.0.1:3001"
const SESSION_PATH := "user://session.json"

var _pass := 0
var _fail := 0
var _expired_count := 0

## 基线（未修复）代码里不存在的成员：用 `in` 探测，保证测试在旧代码上也能跑完
## 而不是抛 "Invalid set index" 中断协程（那会让 headless 进程挂住不退出）。
func _has_prop(obj: Object, prop: String) -> bool:
	return prop in obj


func _set_pending(v: bool) -> void:
	if _has_prop(AuthManager, "_session_pending_verify"):
		AuthManager._session_pending_verify = v


func _is_pending() -> bool:
	if _has_prop(AuthManager, "_session_pending_verify"):
		return AuthManager._session_pending_verify
	return false


func _chk(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] ", label)
	else:
		_fail += 1
		print("[FAIL] ", label)


func _on_auth_expired() -> void:
	_expired_count += 1


func _ready() -> void:
	# 看门狗：若某条断言在异常路径上中断了协程，也保证进程退出（否则 headless 会一直挂住）
	get_tree().create_timer(90.0).timeout.connect(func():
		print("=== API_AUTH_RECOVERY: FAIL (看门狗超时：测试未正常结束) ===")
		get_tree().quit(1))
	_run.call_deferred()


func _write_session(d: Dictionary) -> void:
	var f = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


func _run() -> void:
	await get_tree().process_frame
	var api = APIManager
	api.base_url = API_BASE
	api.url_suffix = ""
	api.is_online = true

	# ---------- A. 空 case_id 守卫：不发请求 ----------
	print("=== A. 空 case_id 守卫 ===")
	var r1 = await api.update_case_progress("", {"status": "in_progress"})
	_chk(r1.get("error", false) and not r1.has("code"),
		"A1 update_case_progress(\"\") 直接短路（未走网络层，返回无 code；旧代码会发出 PUT /api/progress/）")
	var r2 = await api.get_case_progress("   ")
	_chk(r2.get("error", false) and not r2.has("code"),
		"A2 get_case_progress(\"   \") 直接短路（空白也算空）")

	# ---------- B. 离线队列：空 case_id 项应被丢弃 ----------
	print("=== B. 离线队列回放 ===")
	await api.create_guest_session()
	_chk(api.guest_id != "", "B0 已取得游客身份（后续以 X-Guest-ID 访问）")
	api.pending_requests.clear()
	api._queue_request("update_progress", {"case_id": "", "progress": {"status": "dirty"}})
	api._queue_request("update_progress",
		{"case_id": "case_blood_letter", "progress": {"status": "in_progress", "clues_found": 2}})
	await api.flush_pending()
	var leftover_empty := false
	var leftover_valid := false
	for req in api.pending_requests:
		if str(req.get("data", {}).get("case_id", "")).strip_edges().is_empty():
			leftover_empty = true
		else:
			leftover_valid = true
	_chk(not leftover_empty, "B1 空 case_id 的进度上报已从队列丢弃（不再每次重连都白跑一趟）")
	_chk(not leftover_valid, "B2 case_id 有效的进度上报已成功回放（队列不再残留）")

	# ---------- C. 失效令牌自愈 ----------
	print("=== C. 失效令牌自愈 ===")
	api.auth_token = "bogus.token.not.valid"
	if _has_prop(api, "_reported_bad_token"):
		api._reported_bad_token = ""
	_expired_count = 0
	api.auth_expired.connect(_on_auth_expired)
	var r3 = await api.get_save_list()
	_chk(int(r3.get("code", 0)) == 401, "C1 带失效令牌请求 → 服务端返回 401")
	_chk(api.auth_token == "", "C2 401 后本地失效令牌已被清除")
	_chk(_expired_count == 1, "C3 auth_expired 广播一次（实=%d）" % _expired_count)
	var r4 = await api.get_save_list()
	_chk(not r4.get("error", true), "C4 清令牌后重试 → 降级为游客并成功（自愈）")
	_chk(_expired_count == 1, "C5 后续请求不再重复广播（按令牌值幂等，实=%d）" % _expired_count)
	api.auth_expired.disconnect(_on_auth_expired)

	# ---------- D. session 恢复守卫 ----------
	print("=== D. 会话恢复守卫 ===")
	var backup_exists := FileAccess.file_exists(SESSION_PATH)
	var backup := ""
	if backup_exists:
		var bf = FileAccess.open(SESSION_PATH, FileAccess.READ)
		if bf:
			backup = bf.get_as_text()
			bf.close()

	# D1: 哨兵 token "local"（离线登录遗留）绝不能被当作在线令牌恢复
	_write_session({"email": "zz_sentinel@example.com", "username": "zz", "token": "local"})
	api.auth_token = ""
	AuthManager.session_token = ""
	_set_pending(false)
	AuthManager._restore_session()
	_chk(api.auth_token == "", "D1 session 中 token=\"local\" 不被当作在线令牌恢复（旧代码会照单全收 → 全站 401）")
	_chk(not _is_pending(), "D1b 哨兵令牌不触发「待校验」")

	# D2: 形态正常的令牌 → 恢复但标记待校验（联网后由 /api/auth/me 确认）
	_write_session({"email": "zz_pending@example.com", "username": "zz", "token": "header.payload.sig"})
	api.auth_token = ""
	_set_pending(false)
	AuthManager._restore_session()
	_chk(api.auth_token == "header.payload.sig", "D2 正常形态的令牌会被恢复")
	_chk(_is_pending(), "D3 恢复的令牌被标记为「待服务端校验」")

	# 还原真实 session.json（绝不污染用户既有登录态）
	if backup_exists:
		var f2 = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
		if f2:
			f2.store_string(backup)
			f2.close()
		var chk = FileAccess.open(SESSION_PATH, FileAccess.READ)
		var now_text := chk.get_as_text() if chk else ""
		if chk:
			chk.close()
		_chk(now_text == backup, "D4 测试已还原原 session.json（未破坏用户登录态）")
	else:
		var d = DirAccess.open("user://")
		if d and d.file_exists("session.json"):
			d.remove("session.json")
		_chk(not FileAccess.file_exists(SESSION_PATH), "D4 测试前无 session.json，已清理测试残留")

	# ---------- E. 会话校验用「静默探针」，不产生 401 红字 ----------
	# 注：用 has_method 探测，保证本测试在"未修复"的旧代码上也能跑完并如实报 FAIL，
	# 而不是因调用不存在的方法中断协程（那会让 headless 挂到看门狗超时）。
	print("=== E. 会话校验静默探针 ===")
	if not api.has_method("get_current_user"):
		_chk(false, "E1 缺少 get_current_user（基线未修复）")
	else:
		api.auth_token = "bogus.token.not.valid"
		var r5 = await api.get_current_user()
		_chk(not r5.get("error", true),
			"E1 /api/auth/me 对失效令牌仍返回 200（否则浏览器控制台会有红字 401）")
		_chk(not bool(r5.get("data", {}).get("valid", true)), "E2 响应体明确标注 valid=false")
		api.auth_token = ""
		var r6 = await api.get_current_user()
		_chk(not bool(r6.get("data", {}).get("valid", true)), "E3 无令牌时同样 valid=false（不报错）")

		api.auth_token = "bogus.token.not.valid"
		_set_pending(true)
		AuthManager.current_auth_state = AuthManager.AuthState.LOGGED_IN
		if AuthManager.has_method("_verify_restored_session"):
			await AuthManager._verify_restored_session()
			_chk(api.auth_token == "", "E4 valid=false → 启动校验后清除失效令牌")
			_chk(not _is_pending(), "E5 校验结束清掉「待校验」标记")
			_chk(AuthManager.current_auth_state == AuthManager.AuthState.GUEST,
				"E6 已降级为游客（可继续以游客身份游玩）")
		else:
			_chk(false, "E4 缺少 _verify_restored_session（基线未修复）")

	print("=== API_AUTH_RECOVERY: %s (pass=%d fail=%d) ===" % [
		"PASS" if _fail == 0 else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
