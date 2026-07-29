extends Node

## AuthManager — 认证管理器
## 管理游客模式与注册用户的认证流程
## 对接后端 /api/auth/* 端点

enum AuthState {
	GUEST,
	REGISTERING,
	REGISTERED,
	LOGGED_IN
}

var current_auth_state: AuthState = AuthState.GUEST
var user_data: Dictionary = {}
var session_token: String = ""

# 离线本地账号存储（无后端时可用，密码以 SHA256 哈希保存，不存明文）
const ACCOUNTS_PATH: String = "user://accounts.json"
# 记住「上次登录的本地账号」的邮箱，便于下次启动自动恢复会话（避免重载后退化为游客而串档）
const SESSION_PATH: String = "user://session.json"

# ============ 信号 ============

signal auth_state_changed(old_state: int, new_state: int)
signal registration_success(user_id: String, username: String)
signal login_success(user_id: String, username: String)
signal login_failed(error: String)
signal registration_failed(error: String)
signal guest_session_created(guest_id: String)

# ============ 生命周期 ============

func _ready() -> void:
	# 连接网络状态变化
	if APIManager:
		APIManager.connectivity_changed.connect(_on_connectivity_changed)
	
	# 关键修复：自动恢复上次登录的本地账号会话。
	# 若不恢复，重载/重启后 AuthManager 会退化为游客(guest)，导致存档落入共享
	# user://saves/guest/ 命名空间，出现「不同用户互相看到彼此存档」的串档问题。
	_restore_session()
	
	# Web 端：请求浏览器将本站存储(IndexedDB，含账号/存档)标记为持久化，
	# 防止被浏览器自动清理而导致「账号/存档被删除」（用户数据绝不可丢失）。
	if OS.has_feature("web") and JavaScriptBridge:
		JavaScriptBridge.eval("if(navigator.storage && navigator.storage.persist){navigator.storage.persist();}", false)
	
	# 尝试自动创建游客会话
	_init_guest_session.call_deferred()

func _init_guest_session() -> void:
	## 自动初始化游客会话（不阻塞启动流程）
	if APIManager and APIManager.is_online:
		var result = await APIManager.create_guest_session()
		if not result.get("error", true):
			print("[AuthManager] 自动创建游客会话成功")

func _on_connectivity_changed(online: bool) -> void:
	if online and current_auth_state == AuthState.GUEST and APIManager.guest_id == "":
		_init_guest_session()

# ============ 状态查询 ============

func is_guest() -> bool:
	return current_auth_state == AuthState.GUEST

func is_authenticated() -> bool:
	return current_auth_state == AuthState.LOGGED_IN or current_auth_state == AuthState.REGISTERED

func get_user_id() -> String:
	if is_authenticated():
		return user_data.get("id", "")
	return APIManager.guest_id if APIManager else ""

func get_username() -> String:
	if is_authenticated():
		return user_data.get("username", "侦探")
	return "游客侦探"

# ============ 注册流程 ============

## 注册新用户
func register(username: String, email: String, password: String, phone: String = "") -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.REGISTERING
	auth_state_changed.emit(prev_state, current_auth_state)
	
	user_data = {
		"username": username,
		"email": email,
		"phone": phone,
	}
	
	if APIManager and APIManager.is_online:
		var result = await APIManager.register_user(email, password, username, phone)
		if not result.get("error", true):
			_on_registration_success(result.get("data", {}).get("user", {}))
		else:
			_on_auth_failed("register", result.get("message", "注册失败"))
	else:
		# 离线模式：写入本地账号（SHA256 哈希，无明文），无需后端
		var res = _register_local(username, email, password, phone)
		if res.get("error", true):
			_on_auth_failed("register", res.get("message", "注册失败"))
		else:
			_on_registration_success({"id": res.get("id"), "username": username, "email": email})

func _on_registration_success(user: Dictionary) -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.REGISTERED
	
	user_data.merge(user, true)  # 覆盖式合并：重新登录后切换到新账号，避免停留在旧账号 id（串档根因）
	# 防御：Web 构建中 GameManager 单例若尚未就绪，赋值时抛错会阻断下方信号发射，
	# 导致面板永久卡在“正在提交…”。先判空再访问。
	if GameManager:
		GameManager.is_guest = false
	_save_session()  # 记住本次登录，便于下次启动自动恢复（防串档/账号消失）

	auth_state_changed.emit(prev_state, current_auth_state)
	registration_success.emit(user.get("id", ""), user.get("username", ""))
	SystemEventBus.emit_signal("user_registered")
	
	print("[AuthManager] 注册成功: ", user.get("username", ""))

# ============ 登录流程 ============

## 登录已有账户
func login(email: String, password: String) -> void:
	if APIManager and APIManager.is_online:
		var result = await APIManager.login_user(email, password)
		if not result.get("error", true):
			_on_login_success(result.get("data", {}))
		else:
			_on_auth_failed("login", result.get("message", "登录失败"))
	else:
		# 离线模式：校验本地账号
		var res = _login_local(email, password)
		if res.get("error", true):
			_on_auth_failed("login", res.get("message", "登录失败"))
		else:
			_on_login_success({"user": res.get("user", {}), "token": "local"})

func _on_login_success(data: Dictionary) -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.LOGGED_IN
	
	var user = data.get("user", {})
	user_data.merge(user, true)  # 覆盖式合并：重新登录后切换到新账号（避免停留在旧账号 id → 串档）
	session_token = data.get("token", "")
	if GameManager:
		GameManager.is_guest = false
	_save_session()  # 记住本次登录，便于下次启动自动恢复（防串档/账号消失）

	auth_state_changed.emit(prev_state, current_auth_state)
	login_success.emit(user.get("id", ""), user.get("username", ""))
	SystemEventBus.emit_signal("user_logged_in")
	
	print("[AuthManager] 登录成功: ", user.get("username", ""))

func _on_auth_failed(operation: String, error: String) -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.GUEST
	
	auth_state_changed.emit(prev_state, current_auth_state)
	
	if operation == "login":
		login_failed.emit(error)
	elif operation == "register":
		registration_failed.emit(error)
	
	print("[AuthManager] ", operation, " 失败: ", error)

# ============ 离线本地账号（无后端可用） ============

func _hash_password(p: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(p.to_utf8_buffer())
	return ctx.finish().hex_encode()

func _load_accounts() -> Dictionary:
	if not FileAccess.file_exists(ACCOUNTS_PATH):
		return {}
	var f = FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
	if not f:
		return {}
	var text = f.get_as_text()
	f.close()
	var json = JSON.parse_string(text)
	return json if json is Dictionary else {}

func _save_accounts(d: Dictionary) -> void:
	var f = FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()

# ============ 登录会话持久化（防止重载后退化为游客 → 串档/账号「消失」） ============

## 记住当前登录账号的邮箱，便于下次启动自动恢复（无需重新输入密码）
func _save_session() -> void:
	var email = user_data.get("email", "")
	if email.is_empty():
		return
	var f = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"email": email}))
		f.close()

## 主动退出登录时清除记住的会话
func _clear_session() -> void:
	var d = DirAccess.open("user://")
	if d:
		d.remove("session.json")

## 启动时自动恢复上次登录的本地账号；账号不存在/无记录则保持游客
func _restore_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f = FileAccess.open(SESSION_PATH, FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return
	var email = data.get("email", "")
	if email.is_empty():
		return
	var accounts = _load_accounts()
	for k in accounts:
		if accounts[k].get("email", "") == email:
			user_data = accounts[k].duplicate()
			current_auth_state = AuthState.LOGGED_IN
			if GameManager:
				GameManager.is_guest = false
			print("[AuthManager] 已自动恢复登录会话: ", user_data.get("username", ""))
			return

## 注册本地账号：校验用户名/邮箱唯一性，密码哈希存储
func _register_local(username: String, email: String, password: String, phone: String) -> Dictionary:
	var accounts = _load_accounts()
	for k in accounts:
		var a = accounts[k]
		if a.get("username", "") == username:
			return {"error": true, "message": "用户名已被占用"}
		if a.get("email", "") == email:
			return {"error": true, "message": "邮箱已被注册"}
	var id = "local_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	accounts[id] = {
		"id": id,
		"username": username,
		"email": email,
		"phone": phone,
		"password_hash": _hash_password(password),
		"created_at": Time.get_datetime_string_from_system(),
	}
	_save_accounts(accounts)
	return {"error": false, "id": id}

## 本地登录：按邮箱 + 密码哈希校验
func _login_local(email: String, password: String) -> Dictionary:
	var accounts = _load_accounts()
	var want = _hash_password(password)
	for k in accounts:
		var a = accounts[k]
		if a.get("email", "") == email and a.get("password_hash", "") == want:
			return {"error": false, "user": {"id": a.get("id"), "username": a.get("username"), "email": a.get("email")}}
	return {"error": true, "message": "邮箱或密码错误"}

# ============ 退出登录 ============

func logout() -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.GUEST
	user_data.clear()
	session_token = ""
	_clear_session()  # 主动退出登录：清除记住的会话（但 accounts.json 中的账号本身绝不删除）
	if GameManager:
		GameManager.is_guest = true
	
	if APIManager:
		APIManager.clear_auth()
	
	auth_state_changed.emit(prev_state, current_auth_state)
	SystemEventBus.emit_signal("user_logged_out")
	
	print("[AuthManager] 已退出登录")

# ============ 游客会话 ============

## 手动创建游客会话
func create_guest() -> void:
	if APIManager and APIManager.is_online:
		var result = await APIManager.create_guest_session()
		if not result.get("error", true):
			var data = result.get("data", {})
			guest_session_created.emit(data.get("guest_id", ""))
			print("[AuthManager] 游客会话创建成功")
