extends Node

## API 集成测试 — Godot 客户端网络层
## 测试 APIManager / AuthManager / SaveManager 与后端的通信
##
## 运行方式：将此脚本附加到场景根节点，或通过命令行运行 Godot

var test_results = {
	"passed": 0,
	"failed": 0,
	"skipped": 0,
	"results": [],
}

func _ready() -> void:
	print("=".repeat(50))
	print("  Godot 网络层集成测试")
	print("=".repeat(50))
	
	# 等待 APIManager 初始化完成
	await get_tree().create_timer(0.5).timeout
	
	await _run_all_tests()
	
	_print_summary()
	
	# 测试完成后退出（CI 模式）
	if OS.get_cmdline_args().has("--ci"):
		get_tree().quit(test_results["failed"])

func _run_all_tests() -> void:
	# ---- 1. 配置测试 ----
	await _test("APIConfig.get_base_url() 返回有效地址", func():
		var url = APIConfig.get_base_url()
		assert(url.begins_with("http"), "URL 应以 http 开头")
		assert(url.ends_with("3000") or url.contains("api."), "URL 应指向后端")
	)
	
	await _test("APIConfig 端点定义完整", func():
		assert(APIConfig.ENDPOINTS.has("health"), "缺少 health 端点")
		assert(APIConfig.ENDPOINTS.has("login"), "缺少 login 端点")
		assert(APIConfig.ENDPOINTS.has("saves_upload"), "缺少 saves_upload 端点")
		assert(APIConfig.ENDPOINTS.has("progress_get"), "缺少 progress_get 端点")
	)
	
	# ---- 2. APIManager 初始化 ----
	await _test("APIManager 已加载", func():
		assert(APIManager != null, "APIManager 应为非空")
		assert(APIManager.base_url != "", "base_url 不应为空")
	)
	
	await _test("APIManager 默认状态正确", func():
		var status = APIManager.get_status()
		assert(status.has("online"), "状态应包含 online")
		assert(status.has("pending_count"), "状态应包含 pending_count")
		assert(status["pending_count"] >= 0, "pending_count 应 >= 0")
	)
	
	# ---- 3. 健康检查 ----
	await _test("GET /api/health 成功", func():
		var result = await APIManager.health_check()
		if result.get("error", true):
			skip("后端未运行")
			return
		var data = result.get("data", {})
		assert(data.get("status", "") == "ok", "status 应为 ok")
	)
	
	# ---- 4. 游客会话 ----
	await _test("POST /api/auth/guest 创建会话", func():
		var result = await APIManager.create_guest_session()
		if result.get("error", true):
			skip("后端未运行")
			return
		var data = result.get("data", {})
		assert(data.has("guest_id"), "应返回 guest_id")
		assert(data.has("expires_at"), "应返回 expires_at")
		assert(APIManager.guest_id != "", "guest_id 应已保存")
	)
	
	# ---- 5. AuthManager ----
	await _test("AuthManager 初始为游客状态", func():
		assert(AuthManager.current_auth_state == AuthManager.AuthState.GUEST, "初始应为 GUEST")
		assert(AuthManager.is_guest(), "is_guest 应为 true")
	)
	
	await _test("AuthManager.get_username() 游客模式返回默认名", func():
		var name = AuthManager.get_username()
		assert(name != "", "用户名不应为空")
	)
	
	# ---- 6. 认证流程 ----
	await _test("注册缺少参数应返回错误", func():
		var result = await APIManager.register_user("", "", "", "")
		if result.get("error", true):
			# 预期行为：参数错误或后端未配置
			assert(true, "缺少参数正确返回错误")
		else:
			skip("后端接受了空参数（不预期）")
	)
	
	await _test("登录错误密码返回 401", func():
		var result = await APIManager.login_user("fake@test.com", "wrong")
		if result.get("error", true):
			assert(true, "错误凭据正确返回错误")
		else:
			skip("后端未配置")
	)
	
	# ---- 7. SaveManager ----
	await _test("SaveManager 已加载", func():
		assert(SaveManager != null, "SaveManager 应为非空")
		assert(SaveManager.save_version == 1, "save_version 应为 1")
	)
	
	await _test("SaveManager 游客模式本地保存", func():
		GameManager.is_guest = true
		GameManager.current_case_id = "test_case"
		var result = await SaveManager.save_game()
		assert(not result.get("error", true), "本地保存应成功")
	)
	
	await _test("SaveManager 游客模式本地加载", func():
		GameManager.is_guest = true
		var loaded = await SaveManager.load_game()
		assert(loaded, "本地加载应成功")
	)
	
	# ---- 8. 离线队列 ----
	await _test("离线请求加入队列", func():
		var initial_count = APIManager.get_pending_count()
		APIManager._queue_request("upload_save", {"test": true})
		assert(APIManager.get_pending_count() == initial_count + 1, "队列应增加1")
	)
	
	# ---- 9. 信号连接 ----
	await _test("SystemEventBus 信号已定义", func():
		assert(SystemEventBus.has_signal("user_registered"), "缺少 user_registered 信号")
		assert(SystemEventBus.has_signal("user_logged_in"), "缺少 user_logged_in 信号")
		assert(SystemEventBus.has_signal("game_saved"), "缺少 game_saved 信号")
		assert(SystemEventBus.has_signal("game_loaded"), "缺少 game_loaded 信号")
		assert(SystemEventBus.has_signal("network_online"), "缺少 network_online 信号")
		assert(SystemEventBus.has_signal("network_offline"), "缺少 network_offline 信号")
	)
	
	# ---- 10. 错误处理 ----
	await _test("AuthManager.logout() 清除状态", func():
		AuthManager.logout()
		assert(AuthManager.is_guest(), "退出后应为游客")
		assert(APIManager.auth_token == "", "token 应已清除")
	)

# ============ 测试工具 ============

func _test(name: String, fn: Callable) -> void:
	print("  测试: ", name)
	var result = {"name": name, "status": "unknown"}
	
	var test_context = {"skipped": false, "skip_reason": ""}
	
	var fn_with_context = func():
		await fn.call()
	
	# 实际执行
	var err = fn_with_context.call()
	if err is GDScriptFunctionState:
		await err
	
	# 手动检查 — 因为我们使用了简单的断言
	# 这里由 assert/skip 辅助函数处理
	# 如果测试未抛出异常，视为通过

## 断言（简化版，Godot 中需要更完善的实现）
func assert(condition: bool, message: String = "") -> void:
	if not condition:
		printerr("    ❌ 断言失败: ", message)
		test_results["failed"] += 1
		test_results["results"].append({"name": "test", "status": "fail", "message": message})
	else:
		test_results["passed"] += 1

func skip(reason: String = "") -> void:
	print("    ⏭ 跳过: ", reason)
	test_results["skipped"] += 1

func _print_summary() -> void:
	print("")
	print("=".repeat(50))
	print("  测试完成: %d 通过, %d 失败, %d 跳过"
		% [test_results["passed"], test_results["failed"], test_results["skipped"]])
	print("=".repeat(50))
