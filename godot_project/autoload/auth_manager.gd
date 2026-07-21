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
		# 离线模式：缓存注册请求
		if APIManager:
			APIManager._queue_request("register", {
				"email": email,
				"password": password,
				"username": username,
				"phone": phone,
			})
		registration_failed.emit("离线模式：注册请求已加入队列，联网后自动重试")

func _on_registration_success(user: Dictionary) -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.REGISTERED
	
	user_data.merge(user)
	# 防御：Web 构建中 GameManager 单例若尚未就绪，赋值时抛错会阻断下方信号发射，
	# 导致面板永久卡在“正在提交…”。先判空再访问。
	if GameManager:
		GameManager.is_guest = false

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
		_on_auth_failed("login", "网络不可用，无法登录")

func _on_login_success(data: Dictionary) -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.LOGGED_IN
	
	var user = data.get("user", {})
	user_data.merge(user)
	session_token = data.get("token", "")
	if GameManager:
		GameManager.is_guest = false
	
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

# ============ 退出登录 ============

func logout() -> void:
	var prev_state = current_auth_state
	current_auth_state = AuthState.GUEST
	user_data.clear()
	session_token = ""
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
