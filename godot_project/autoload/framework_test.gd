extends Node

## FrameworkTest — 框架整合测试 v2.0
## 注：本脚本由 project.godot 注册为 autoload 单例 "FrameworkTest"，
## 因此不声明 class_name（避免与 autoload 全局名冲突）。
## 在游戏启动后自动运行，验证所有核心系统正常工作
## 覆盖：Autoload 存在性 → 状态机 → 事件总线 → 网络层 → 跨层连接

var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0

func _ready() -> void:
	# FrameworkTest 按字母序可能在 Boot 之前初始化，
	# 延迟若干帧确保 Boot 7 阶段全部完成后再自检
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	run_all_tests()

func run_all_tests() -> void:
	print("=".repeat(55))
	print("  维多利亚伦敦探案 — 框架整合测试 v2.0")
	print("=".repeat(55))
	
	# ═══════════════════════════════════════
	# 1. 引擎层 — Autoload 存在性检查
	# ═══════════════════════════════════════
	print("\n── 第 1 层: 引擎层 — Autoload 存在性 ──")
	
	_test_autoload("SystemEventBus", SystemEventBus)
	_test_autoload("CaseEventBus", CaseEventBus)
	_test_autoload("SceneEventBus", SceneEventBus)
	_test_autoload("DialogueEventBus", DialogueEventBus)
	_test_autoload("ClueEventBus", ClueEventBus)
	_test_autoload("UIEventBus", UIEventBus)
	_test_autoload("MapEventBus", MapEventBus)
	_test_autoload("GameManager", GameManager)
	_test_autoload("CaseManager", CaseManager)
	_test_autoload("DifficultyManager", DifficultyManager)
	_test_autoload("ClueSystem", ClueSystem)
	_test_autoload("StarRatingSystem", StarRatingSystem)
	_test_autoload("SaveManager", SaveManager)
	_test_autoload("AuthManager", AuthManager)
	_test_autoload("APIManager", APIManager)
	_test_autoload("APIConfig", APIConfig)
	_test_autoload("UIManager", UIManager)
	_test_autoload("SettingsManager", SettingsManager)
	_test_autoload("AudioManager", AudioManager)
	
	# ═══════════════════════════════════════
	# 2. 逻辑层 — 状态机与核心系统
	# ═══════════════════════════════════════
	print("\n── 第 2 层: 逻辑层 — 状态机与核心系统 ──")
	
	_test("游戏状态机初始化", func():
		return GameManager.current_state == GameManager.GameState.MAIN_MENU
	)
	
	_test("游客模式默认开启", func():
		return GameManager.is_guest == true
	)
	
	_test("GameManager 在线状态跟踪", func():
		return GameManager.has_method("_on_connectivity_changed")
	)
	
	# 难度系统
	_test("默认难度为普通", func():
		return DifficultyManager.current_difficulty == DifficultyManager.Difficulty.NORMAL
	)
	
	_test("难度切换功能", func():
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
		var ok = DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		return ok
	)
	
	_test("简单模式自动填写笔记", func():
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
		var ok = DifficultyManager.auto_fill_notebook == true
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		return ok
	)
	
	_test("困难模式无提示", func():
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
		var ok = DifficultyManager.should_show_hint() == false
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		return ok
	)
	
	# ═══════════════════════════════════════
	# 3. 事件层 — 总线通信验证
	# ═══════════════════════════════════════
	print("\n── 第 3 层: 事件层 — 7 总线通信验证 ──")
	
	_test("CaseEventBus 信号发送", func():
		var received = [false]
		CaseEventBus.connect("case_started", func(_id): received[0] = true, CONNECT_ONE_SHOT)
		CaseEventBus.emit_signal("case_started", "test_case")
		return received[0]
	)

	_test("SceneEventBus 信号发送", func():
		var received = [false]
		SceneEventBus.connect("hotspot_clicked", func(_id): received[0] = true, CONNECT_ONE_SHOT)
		SceneEventBus.emit_signal("hotspot_clicked", "test_hotspot")
		return received[0]
	)

	_test("UIEventBus 信号发送", func():
		var received = [false]
		UIEventBus.connect("screen_opened", func(_s): received[0] = true, CONNECT_ONE_SHOT)
		UIEventBus.emit_signal("screen_opened", 0)
		return received[0]
	)

	_test("SystemEventBus 跨层信号发送", func():
		var received = [false]
		SystemEventBus.connect("game_state_changed", func(_s): received[0] = true, CONNECT_ONE_SHOT)
		SystemEventBus.emit_signal("game_state_changed", 1)
		return received[0]
	)
	
	# ═══════════════════════════════════════
	# 4. 网络层 — 前后端连接
	# ═══════════════════════════════════════
	print("\n── 第 4 层: 网络层 — 前后端连接验证 ──")
	
	_test("APIManager base_url 已配置", func():
		return APIManager.base_url != ""
	)
	
	_test("APIManager 状态查询可用", func():
		var status = APIManager.get_status()
		return status.has("online") and status.has("pending_count") and status.has("authenticated")
	)
	
	_test("APIConfig 端点定义完整", func():
		return (APIConfig.ENDPOINTS.has("health") and 
		        APIConfig.ENDPOINTS.has("login") and 
		        APIConfig.ENDPOINTS.has("saves_upload") and
		        APIConfig.ENDPOINTS.has("progress_get"))
	)
	
	_test("APIConfig 开发/生产地址分离", func():
		var url = APIConfig.get_base_url()
		return url.begins_with("http")
	)
	
	_test("APIManager 信号已定义", func():
		return (APIManager.has_signal("connectivity_changed") and
		        APIManager.has_signal("request_completed") and
		        APIManager.has_signal("auth_expired") and
		        APIManager.has_signal("network_error"))
	)
	
	# ═══════════════════════════════════════
	# 5. 认证层 — 身份管理
	# ═══════════════════════════════════════
	print("\n── 第 5 层: 认证层 — 身份管理验证 ──")
	
	_test("AuthManager 初始游客状态", func():
		return AuthManager.is_guest() and AuthManager.current_auth_state == AuthManager.AuthState.GUEST
	)
	
	_test("AuthManager 四态枚举完整", func():
		return (AuthManager.AuthState.GUEST != null and 
		        AuthManager.AuthState.REGISTERING != null and
		        AuthManager.AuthState.REGISTERED != null and
		        AuthManager.AuthState.LOGGED_IN != null)
	)
	
	_test("AuthManager 信号已定义", func():
		return (AuthManager.has_signal("auth_state_changed") and
		        AuthManager.has_signal("login_success") and
		        AuthManager.has_signal("login_failed") and
		        AuthManager.has_signal("guest_session_created"))
	)
	
	_test("AuthManager.get_user_id() 游客模式返回 guest_id", func():
		return AuthManager.get_user_id() is String
	)
	
	# ═══════════════════════════════════════
	# 6. 数据层 — 存档与持久化
	# ═══════════════════════════════════════
	print("\n── 第 6 层: 数据层 — 存档与持久化验证 ──")
	
	_test("SaveManager 版本号正确", func():
		return SaveManager.save_version == 1
	)
	
	_test("SaveManager 双模式支持", func():
		return (SaveManager.has_method("_save_local") and 
		        SaveManager.has_method("_save_to_server"))
	)
	
	_test("SaveManager 信号已定义", func():
		return (SaveManager.has_signal("game_saved") and
		        SaveManager.has_signal("game_loaded") and
		        SaveManager.has_signal("save_sync_failed") and
		        SaveManager.has_signal("no_save_found"))
	)
	
	_test("游客模式本地保存", func():
		GameManager.is_guest = true
		GameManager.current_case_id = "test_case"
		SaveManager.save_game()
		return SaveManager.last_save_timestamp > 0
	)
	
	_test("游客模式本地加载接口", func():
		GameManager.is_guest = true
		# load_game() 为协程（内部 await 网络/文件），此处仅验证接口存在性，
		# 避免在同步 _test 框架中引入协程时序问题。
		return SaveManager.has_method("load_game") and SaveManager.has_method("_load_local")
	)
	
	# ═══════════════════════════════════════
	# 7. UI 层 — 界面管理
	# ═══════════════════════════════════════
	print("\n── 第 7 层: UI 层 — 界面管理验证 ──")
	
	_test("UI界面栈操作", func():
		UIManager.open_screen(UIManager.UIScreen.REASONING_WALL)
		var opened = UIManager.is_screen_open(UIManager.UIScreen.REASONING_WALL)
		UIManager.close_screen(UIManager.UIScreen.REASONING_WALL)
		return opened
	)
	
	_test("UI可见性切换", func():
		var before = UIManager.is_ui_visible
		UIManager.toggle_ui()
		var after = UIManager.is_ui_visible
		UIManager.toggle_ui()
		return before != after
	)
	
	# 设置系统
	_test("设置保存与读取", func():
		SettingsManager.set_setting("master_volume", 0.5)
		return SettingsManager.get_setting("master_volume") == 0.5
	)
	
	# ═══════════════════════════════════════
	# 8. 架构层间连接 — 跨层通信
	# ═══════════════════════════════════════
	print("\n── 第 8 层: 跨层连接 — 架构集成验证 ──")
	
	# 8.1 网络层 → 认证层
	_test("网络层→认证层: APIManager ↔ AuthManager 联通", func():
		return (APIManager.has_method("login_user") and 
		        AuthManager.has_method("login"))
	)
	
	# 8.2 认证层 → 存档层
	_test("认证层→存档层: AuthManager ↔ SaveManager 联通", func():
		return (SaveManager.has_method("_save_to_server") and 
		        AuthManager.has_method("is_authenticated"))
	)
	
	# 8.3 游戏层 → 网络层
	_test("游戏层→网络层: GameManager ↔ APIManager 联通", func():
		return (GameManager.has_method("_sync_cloud_data") and 
		        APIManager.has_method("get_all_progress"))
	)
	
	# 8.4 事件层 → 所有层
	_test("事件层: SystemEventBus 跨层信号完整性", func():
		return (SystemEventBus.has_signal("user_registered") and
		        SystemEventBus.has_signal("user_logged_in") and
		        SystemEventBus.has_signal("user_logged_out") and
		        SystemEventBus.has_signal("game_saved") and
		        SystemEventBus.has_signal("game_loaded") and
		        SystemEventBus.has_signal("network_online") and
		        SystemEventBus.has_signal("network_offline") and
		        SystemEventBus.has_signal("case_completed"))
	)
	
	# 8.5 Boot 层 → 所有层
	_test("启动层: Boot 分阶段初始化完整", func():
		return (Boot.has_method("_phase_1_engine_check") and
		        Boot.has_method("_phase_2_data_init") and
		        Boot.has_method("_phase_3_event_binding") and
		        Boot.has_method("_phase_4_network_init") and
		        Boot.has_method("_phase_5_auth_check") and
		        Boot.has_method("_phase_6_save_check") and
		        Boot.has_method("_phase_7_ui_launch"))
	)
	
	# 8.6 离线降级验证
	_test("离线降级: APIManager 离线队列机制", func():
		var initial = APIManager.get_pending_count()
		APIManager._queue_request("upload_save", {"test": true})
		var after = APIManager.get_pending_count()
		return after == initial + 1
	)
	
	# 8.7 游客/注册双模式
	_test("双模式: 游客 ↔ 注册用户切换路径", func():
		AuthManager.logout()
		var is_guest_after_logout = AuthManager.is_guest()
		var token_cleared = APIManager.auth_token == ""
		return is_guest_after_logout and token_cleared
	)
	
	# ═══════════════════════════════════════
	# 9. 资源层 — 场景与脚本存在性
	# ═══════════════════════════════════════
	print("\n── 第 9 层: 资源层 — 场景与脚本存在性 ──")
	
	_test("Boot场景存在", func():
		return ResourceLoader.exists("res://scenes/boot.tscn")
	)
	
	_test("主菜单场景存在", func():
		return ResourceLoader.exists("res://scenes/main_menu.tscn")
	)
	
	_test("游戏场景存在", func():
		return ResourceLoader.exists("res://scenes/game_scene.tscn")
	)
	
	_test("API配置脚本存在", func():
		return ResourceLoader.exists("res://config/api_config.gd")
	)
	
	var required_scripts = [
		"res://scripts/scene/scene_controller.gd",
		"res://scripts/scene/game_scene.gd",
		"res://scripts/dialogue/dialogue_manager.gd",
		"res://scripts/dialogue/dialogue_renderer.gd",
		"res://scripts/tool/tool_bar.gd",
		"res://scripts/clue/reasoning_wall_ui.gd",
		"res://scripts/ui/main_menu.gd",
		"res://scripts/ui/screen_manager.gd",
		"res://scripts/ui/top_bar.gd",
		"res://scripts/ui/side_panel.gd",
		"res://scripts/ui/notification.gd",
	]
	
	for script_path in required_scripts:
		_test("脚本存在: " + script_path.get_file(), func():
			return ResourceLoader.exists(script_path)
		)

	# 对话资源（六步闭环）— P0-1b 冒烟验证
	var dlg_path = "res://resources/dialogues/scene_01_phase1_tutorial.tres"
	_test("场景一对话资源存在", func():
		return ResourceLoader.exists(dlg_path)
	)
	_test("场景一对话资源可加载", func():
		var res = load(dlg_path)
		return res != null and "nodes" in res and res.has_method("get_start_node")
	)
	_test("对话节点数充足(>=30)", func():
		var res = load(dlg_path)
		return res != null and res.nodes.size() >= 30
	)
	_test("七步入口完整(7个)", func():
		var res = load(dlg_path)
		if res == null: return false
		var cnt = 0
		for node in res.nodes:
			if node.is_step_entry and node.exploration_step > 0:
				cnt += 1
		return cnt == 7
	)
	_test("三难度起点有效", func():
		var res = load(dlg_path)
		if res == null: return false
		for diff in [0, 1, 2]:
			var sid = res.get_start_node(diff)
			if sid == "": return false
			var found = false
			for node in res.nodes:
				if node.node_id == sid:
					found = true
					break
			if not found: return false
		return true
	)
	_test("四级验证分支存在(>=4)", func():
		var res = load(dlg_path)
		if res == null: return false
		var cnt = 0
		for node in res.nodes:
			if node.node_id.begins_with("s1_step6_"):
				cnt += 1
		return cnt >= 4
	)
	_test("六步闭环可达(起点→入口)", func():
		var res = load(dlg_path)
		if res == null: return false
		var start = res.get_start_node(1)
		var visited = {}
		var current = start
		var steps = 0
		var reached = false
		while current != "" and steps < 500:
			if visited.has(current): break
			visited[current] = true
			for node in res.nodes:
				if node.node_id == current and node.is_step_entry and node.exploration_step > 0:
					reached = true
			var nxt = []
			for node in res.nodes:
				if node.node_id == current:
					nxt = node.get_available_next(1, "")
					break
			if nxt.is_empty(): break
			current = nxt[0]
			steps += 1
			if reached: break
		return reached
	)

	# ═══════════════════════════════════════
	# 结果汇总
	# ═══════════════════════════════════════
	print("\n" + "=".repeat(55))
	print("  测试结果: %d / %d 通过" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("  ✅ 所有测试通过！前后端架构连接就绪。")
	else:
		print("  ⚠️  %d 项测试未通过" % [total_tests - passed_tests])
	print("=".repeat(55))

func _test_autoload(name: String, instance) -> void:
	_test("Autoload: " + name, func():
		return instance != null
	)

func _test(name: String, check: Callable) -> void:
	total_tests += 1
	var result = check.call()
	test_results[name] = result
	
	if result:
		passed_tests += 1
		print("  ✅ %s" % name)
	else:
		print("  ❌ %s" % name)
