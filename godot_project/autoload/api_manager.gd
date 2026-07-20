extends Node

## APIManager — 前端网络层
## 封装所有后端 RESTful API 调用，统一管理：
##   - HTTP 请求发送与响应解析
##   - 认证 token 自动附加
##   - 离线降级与请求队列
##   - 超时与重试策略
##   - 错误统一处理与事件通知
##
## 通信协议见 communication_protocol.md

# ============ 配置 ============

## 后端 API 基地址（生产环境从环境变量/配置文件读取）
var base_url: String = "http://localhost:3000"

## 请求超时时间（秒）
var request_timeout: float = 15.0

## 最大重试次数
var max_retries: int = 2

## 是否在线（自动检测）
var is_online: bool = false

## Web 预览环境：追加到每个请求路径之后的沙箱查询串（如 ?x-cs-sandbox-port=3000）
var url_suffix: String = ""

## 离线时缓存的请求队列
var pending_requests: Array[Dictionary] = []

## 当前认证 token（JWT）
var auth_token: String = ""

## 游客 ID（UUID v4）
var guest_id: String = ""

## 活跃的 HTTP 请求数（用于并发控制）
var active_requests: int = 0

# ============ 信号 ============

signal connectivity_changed(online: bool)
signal request_completed(endpoint: String, success: bool, data: Dictionary)
signal auth_expired
signal network_error(endpoint: String, error: String)
signal queue_flushed(count: int)

# ============ 生命周期 ============

func _ready() -> void:
	_check_connectivity()

func _check_connectivity() -> void:
	## 尝试连接后端 health 端点
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_health_check.bind(http))
	
	var error = http.request(base_url + "/api/health" + url_suffix)
	if error != OK:
		_set_online_status(false, http)
		return
	
	# 设置超时
	get_tree().create_timer(5.0).timeout.connect(
		func():
			# http 可能已被健康检查回调 queue_free，需先判活
			if not is_instance_valid(http):
				return
			if not http.get_meta("checked", false):
				_set_online_status(false, http)
	)

func _on_health_check(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.set_meta("checked", true)
	if code == 200:
		_set_online_status(true, http)
	else:
		_set_online_status(false, http)

func _set_online_status(online: bool, http: HTTPRequest) -> void:
	var was_online = is_online
	is_online = online
	
	http.queue_free()
	
	if online and not was_online:
		print("[APIManager] 网络已连接")
		connectivity_changed.emit(true)
		flush_pending()
	elif not online and was_online:
		print("[APIManager] 网络已断开，进入离线模式")
		connectivity_changed.emit(false)

# ============ HTTP 请求核心 ============

## 通用 GET 请求
func get_request(endpoint: String, auth: bool = true) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = _build_headers(auth)
	var url = base_url + endpoint + url_suffix
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return {"error": true, "message": "请求发送失败: " + str(error)}
	
	var response = await _wait_for_response(http)
	return response

## 通用 POST 请求
func post_request(endpoint: String, body: Dictionary, auth: bool = true) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = _build_headers(auth)
	headers.append("Content-Type: application/json")
	var url = base_url + endpoint + url_suffix
	var json_body = JSON.stringify(body)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		http.queue_free()
		return {"error": true, "message": "请求发送失败: " + str(error)}
	
	var response = await _wait_for_response(http)
	return response

## 通用 PUT 请求
func put_request(endpoint: String, body: Dictionary, auth: bool = true) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = _build_headers(auth)
	headers.append("Content-Type: application/json")
	var url = base_url + endpoint + url_suffix

	var error = http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(body))
	if error != OK:
		http.queue_free()
		return {"error": true, "message": "请求发送失败: " + str(error)}
	
	var response = await _wait_for_response(http)
	return response

## 等待 HTTP 响应（含超时处理）
func _wait_for_response(http: HTTPRequest) -> Dictionary:
	active_requests += 1
	
	var timer = get_tree().create_timer(request_timeout)
	var completed = false
	var response = {}
	
	http.request_completed.connect(
		func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
			if completed: return
			completed = true
			response = _parse_response(result, code, body)
	)
	
	timer.timeout.connect(
		func():
			if not completed:
				completed = true
				response = {"error": true, "message": "请求超时"}
				http.cancel_request()
	)
	
	# 等待完成（Godot 4 await 模式）
	while not completed:
		await get_tree().process_frame
	
	http.queue_free()
	active_requests -= 1
	return response

## 构建请求头
func _build_headers(auth: bool) -> PackedStringArray:
	var headers = PackedStringArray(["Accept: application/json"])
	
	if auth and auth_token:
		headers.append("Authorization: Bearer " + auth_token)
	
	if guest_id:
		headers.append("X-Guest-ID: " + guest_id)
	
	return headers

## 解析 HTTP 响应
func _parse_response(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": true, "message": "网络请求失败, code: " + str(result)}
	
	var body_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(body_str)
	
	if parse_error != OK:
		return {"error": true, "message": "响应解析失败", "raw": body_str}
	
	var data = json.get_data()
	if code >= 400:
		return {"error": true, "code": code, "message": data.get("error", "服务器错误")}
	
	return {"error": false, "code": code, "data": data}

# ============ 认证 API ============

## POST /api/auth/register — 用户注册
func register_user(email: String, password: String, username: String = "", phone: String = "") -> Dictionary:
	var body = {
		"email": email,
		"password": password,
		"username": username,
		"phone": phone,
	}
	
	var response = await post_request("/api/auth/register", body, false)
	request_completed.emit("register", not response.get("error", true), response)
	return response

## POST /api/auth/login — 用户登录
func login_user(email: String, password: String) -> Dictionary:
	var body = {
		"email": email,
		"password": password,
	}
	
	var response = await post_request("/api/auth/login", body, false)
	
	if not response.get("error", true) and response.has("data"):
		var data = response["data"]
		if data.has("token"):
			auth_token = data["token"]
			print("[APIManager] 登录成功, token已保存")
	
	request_completed.emit("login", not response.get("error", true), response)
	return response

## POST /api/auth/guest — 创建游客会话
func create_guest_session() -> Dictionary:
	var response = await post_request("/api/auth/guest", {}, false)
	
	if not response.get("error", true) and response.has("data"):
		var data = response["data"]
		if data.has("guest_id"):
			guest_id = data["guest_id"]
			print("[APIManager] 游客会话已创建: ", guest_id)
	
	request_completed.emit("guest", not response.get("error", true), response)
	return response

## 清除认证状态
func clear_auth() -> void:
	auth_token = ""
	guest_id = ""

# ============ 存档 API ============

## GET /api/saves — 获取存档列表
func get_save_list() -> Dictionary:
	var response = await get_request("/api/saves")
	return response

## GET /api/saves/latest — 获取最新存档
func get_latest_save(case_id: String = "") -> Dictionary:
	var endpoint = "/api/saves/latest"
	if case_id:
		endpoint += "?case_id=" + case_id.uri_encode()
	
	var response = await get_request(endpoint)
	return response

## POST /api/saves — 上传存档（M1 策略：覆盖同案件最新存档）
func upload_save(save_data: Dictionary) -> Dictionary:
	var response = await post_request("/api/saves", save_data)
	request_completed.emit("upload_save", not response.get("error", true), response)
	return response

# ============ 案件进度 API ============

## GET /api/progress/:caseId — 获取案件进度
func get_case_progress(case_id: String) -> Dictionary:
	var endpoint = "/api/progress/" + case_id.uri_encode()
	var response = await get_request(endpoint)
	return response

## PUT /api/progress/:caseId — 更新案件进度
func update_case_progress(case_id: String, progress_data: Dictionary) -> Dictionary:
	var endpoint = "/api/progress/" + case_id.uri_encode()
	var response = await put_request(endpoint, progress_data)
	request_completed.emit("update_progress", not response.get("error", true), response)
	return response

## GET /api/progress — 获取所有案件进度
func get_all_progress() -> Dictionary:
	var response = await get_request("/api/progress")
	return response

# ============ 健康检查 API ============

## GET /api/health — 服务器健康检查
func health_check() -> Dictionary:
	var response = await get_request("/api/health", false)
	return response

# ============ 离线队列 ============

## 将请求加入离线队列
func _queue_request(request_type: String, data: Dictionary) -> void:
	pending_requests.append({
		"type": request_type,
		"data": data,
		"timestamp": Time.get_unix_time_from_system(),
	})
	print("[APIManager] 请求已加入离线队列 (", request_type, "), 队列长度: ", pending_requests.size())

## 刷新离线队列（网络恢复后自动调用）
func flush_pending() -> void:
	if pending_requests.is_empty():
		return
	
	var flushed_count = 0
	var queue_copy = pending_requests.duplicate()
	pending_requests.clear()
	
	print("[APIManager] 开始刷新离线队列, 共 ", queue_copy.size(), " 条请求")
	
	for req in queue_copy:
		var success = false
		match req["type"]:
			"register":
				var r = await register_user(
					req["data"].get("email", ""),
					req["data"].get("password", ""),
					req["data"].get("username", ""),
					req["data"].get("phone", "")
				)
				success = not r.get("error", true)
			"upload_save":
				var r = await upload_save(req["data"])
				success = not r.get("error", true)
			"update_progress":
				var r = await update_case_progress(
					req["data"].get("case_id", ""),
					req["data"]
				)
				success = not r.get("error", true)
		
		if success:
			flushed_count += 1
		else:
			# 失败的请求重新入队
			pending_requests.append(req)
	
	print("[APIManager] 离线队列刷新完成: ", flushed_count, "/", queue_copy.size())
	queue_flushed.emit(flushed_count)

## 获取离线队列信息
func get_pending_count() -> int:
	return pending_requests.size()

## 获取网络状态摘要
func get_status() -> Dictionary:
	return {
		"online": is_online,
		"base_url": base_url,
		"authenticated": auth_token != "",
		"guest_id": guest_id,
		"active_requests": active_requests,
		"pending_count": pending_requests.size(),
	}
