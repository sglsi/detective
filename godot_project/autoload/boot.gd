extends Node

## Boot — 游戏启动入口
## 注：本脚本由 project.godot 注册为 autoload 单例 "Boot"，
## 因此不声明 class_name（避免与 autoload 全局名冲突）。
## 负责五层架构的初始化顺序，严格遵循设计文档的依赖层级：
##
##   ┌─────────────────────────────────────────────────┐
##   │ 第 1 层: 引擎层 — 环境检查 / 渲染器 / 版本锁定    │
##   │ 第 2 层: 数据层 — 配置加载 / 设置 / 资源管理       │
##   │ 第 3 层: 事件层 — 7 个事件总线连接与信号注册       │
##   │ 第 4 层: 网络层 — APIManager / AuthManager 初始化  │
##   │ 第 5 层: 逻辑层 — GameManager / SaveManager 启动   │
##   │ 第 6 层: UI 层  — 主菜单 / 场景切换               │
##   └─────────────────────────────────────────────────┘
##
## 初始化顺序不可错乱 — 前层是后层的依赖。

# ============ 启动状态 ============

enum BootPhase {
	ENGINE_CHECK,      # 引擎层检查
	DATA_INIT,         # 数据层初始化
	EVENT_BINDING,     # 事件层绑定
	NETWORK_INIT,      # 网络层初始化
	AUTH_CHECK,        # 认证检查
	SAVE_CHECK,        # 存档检查
	UI_LAUNCH,         # UI 层启动
	COMPLETE,          # 启动完成
}

var current_phase: BootPhase = BootPhase.ENGINE_CHECK
var boot_errors: Array[String] = []
var boot_warnings: Array[String] = []
var boot_start_time: int = 0

# ============ 生命周期 ============

func _ready() -> void:
	boot_start_time = Time.get_ticks_msec()
	print("=".repeat(55))
	print("  维多利亚伦敦探案项目 启动中...")
	print("  Godot %s | %s" % [_engine_version(), ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	print("=".repeat(55))
	
	# 逐层初始化
	await _phase_1_engine_check()
	if not _can_proceed(): return
	
	await _phase_2_data_init()
	if not _can_proceed(): return
	
	await _phase_3_event_binding()
	
	await _phase_4_network_init()
	
	await _phase_5_auth_check()
	
	await _phase_6_save_check()
	
	await _phase_7_ui_launch()
	
	_phase_complete()

# ============ 第 1 层: 引擎层 ============

func _phase_1_engine_check() -> void:
	current_phase = BootPhase.ENGINE_CHECK
	print("\n[Boot/1] 引擎层 — 环境检查")
	
	# 1.1 版本锁定检查
	var version = Engine.get_version_info()
	var expected = {"major": 4, "minor": 4}  # Godot 4.4+ 兼容
	if version.major < expected.major or (version.major == expected.major and version.minor < expected.minor):
		boot_errors.append("Godot 版本过低: %d.%d，需要 >= %d.%d" % [version.major, version.minor, expected.major, expected.minor])
	else:
		print("  ✅ Godot %d.%d.%s — 版本合规" % [version.major, version.minor, version.status])
	
	# 1.2 渲染器检查
	var renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if renderer == "gl_compatibility":
		print("  ✅ 渲染器: Compatibility (GLES3)")
	else:
		boot_warnings.append("渲染器非 Compatibility: %s，Web 导出可能不兼容" % renderer)
	
	# 1.3 关键目录存在性
	var dirs = {
		"autoload": "res://autoload/",
		"scenes": "res://scenes/",
		"scripts": "res://scripts/",
		"config": "res://config/",
		"data": "res://data/",
	}
	for name in dirs:
		if DirAccess.dir_exists_absolute(dirs[name]):
			print("  ✅ 目录 %s/" % name)
		else:
			boot_warnings.append("目录缺失: %s" % dirs[name])
	
	# 1.4 配置文件存在性
	if ResourceLoader.exists("res://config/api_config.gd"):
		print("  ✅ API 配置文件")
	else:
		boot_errors.append("API 配置文件缺失: res://config/api_config.gd")
	
	await _frame()

# ============ 第 2 层: 数据层 ============

func _phase_2_data_init() -> void:
	current_phase = BootPhase.DATA_INIT
	print("\n[Boot/2] 数据层 — 配置与设置加载")
	
	# 2.1 加载用户设置（SettingsManager 已在 autoload 中初始化）
	if SettingsManager:
		SettingsManager._load_settings()
		print("  ✅ 用户设置已加载")
	else:
		boot_errors.append("SettingsManager 未加载")
	
	# 2.2 初始化音频总线
	_init_audio_buses()
	
	await _frame()

# ============ 第 3 层: 事件层 ============

func _phase_3_event_binding() -> void:
	current_phase = BootPhase.EVENT_BINDING
	print("\n[Boot/3] 事件层 — 7 总线信号连接")
	
	var event_buses = [
		{"name": "SystemEventBus", "instance": SystemEventBus},
		{"name": "CaseEventBus", "instance": CaseEventBus},
		{"name": "SceneEventBus", "instance": SceneEventBus},
		{"name": "DialogueEventBus", "instance": DialogueEventBus},
		{"name": "ClueEventBus", "instance": ClueEventBus},
		{"name": "UIEventBus", "instance": UIEventBus},
		{"name": "MapEventBus", "instance": MapEventBus},
	]
	
	for bus in event_buses:
		if bus["instance"]:
			print("  ✅ %s" % bus["name"])
		else:
			boot_errors.append("%s 未加载" % bus["name"])
	
	# 3.1 系统事件 — 全局状态监听
	_safe_connect(SystemEventBus.game_state_changed, _on_game_state_changed)
	_safe_connect(SystemEventBus.game_saved, _on_game_saved)
	_safe_connect(SystemEventBus.game_loaded, _on_game_loaded)
	_safe_connect(SystemEventBus.network_online, _on_network_online)
	_safe_connect(SystemEventBus.network_offline, _on_network_offline)
	_safe_connect(SystemEventBus.user_logged_in, _on_user_logged_in)
	_safe_connect(SystemEventBus.user_logged_out, _on_user_logged_out)
	
	# 3.2 案件事件
	_safe_connect(CaseEventBus.case_started, _on_case_started)
	_safe_connect(CaseEventBus.case_loaded, _on_case_loaded)
	
	print("  ✅ 跨层信号已绑定")
	await _frame()

# ============ 第 4 层: 网络层 ============

func _phase_4_network_init() -> void:
	current_phase = BootPhase.NETWORK_INIT
	print("\n[Boot/4] 网络层 — API 管理器初始化")
	
	# 4.1 配置 API 基地址
	if APIManager:
		APIManager.base_url = APIConfig.get_base_url()
		# Web 预览环境：把沙箱预览查询串（含后端端口 3000）作为后缀追加到每个请求路径之后
		APIManager.url_suffix = APIConfig.get_web_query_suffix()
		print("  ✅ API 基地址: %s" % APIManager.base_url)
		if APIManager.url_suffix != "":
			print("  ✅ Web 查询后缀: %s" % APIManager.url_suffix)
		
		# 4.2 配置超时与重试
		APIManager.request_timeout = APIConfig.REQUEST_TIMEOUT
		APIManager.max_retries = APIConfig.MAX_RETRIES
		
		# 4.3 连接网络状态变化信号
		_safe_connect(APIManager.connectivity_changed, _on_connectivity_changed)
		
		# 4.4 触发连通性检查（异步，不阻塞）
		print("  🔍 检测网络连通性...")
	else:
		boot_errors.append("APIManager 未加载")
	
	await _frame()

# ============ 第 5 层: 认证层 ============

func _phase_5_auth_check() -> void:
	current_phase = BootPhase.AUTH_CHECK
	print("\n[Boot/5] 认证层 — 用户身份初始化")
	
	if AuthManager:
		# 5.1 连接认证状态变化
		_safe_connect(AuthManager.auth_state_changed, _on_auth_state_changed)
		
		# 5.2 初始状态为游客
		print("  ✅ 初始身份: %s" % ("游客" if AuthManager.is_guest() else "注册用户"))
		
		# 5.3 如果在线，异步创建游客会话（不阻塞启动）
		if APIManager and APIManager.is_online:
			print("  🔍 自动创建游客会话...")
			# 注意: 游客会话在后台创建，不阻塞主菜单加载
	else:
		boot_warnings.append("AuthManager 未加载，认证功能不可用")
	
	await _frame()

# ============ 第 6 层: 存档层 ============

func _phase_6_save_check() -> void:
	current_phase = BootPhase.SAVE_CHECK
	print("\n[Boot/6] 存档层 — 存档状态检查")
	
	if SaveManager:
		_safe_connect(SaveManager.game_saved, _on_save_completed)
		_safe_connect(SaveManager.game_loaded, _on_load_completed)
		_safe_connect(SaveManager.no_save_found, _on_no_save)
		
		# 检查是否有存档
		var has_save = false
		if GameManager.is_guest:
			has_save = FileAccess.file_exists("user://save_game.json")
		else:
			# 云端存档检查（异步，不阻塞）
			has_save = false
		
		if has_save:
			print("  📁 发现存档")
			GameManager.has_existing_save = true
		else:
			print("  📄 无存档（新玩家或首次启动）")
			GameManager.has_existing_save = false
	else:
		boot_warnings.append("SaveManager 未加载")
	
	await _frame()

# ============ 第 7 层: UI 层 ============

func _phase_7_ui_launch() -> void:
	current_phase = BootPhase.UI_LAUNCH
	print("\n[Boot/7] UI 层 — 启动主菜单")
	
	# 7.1 设置游戏状态
	GameManager._change_state(GameManager.GameState.MAIN_MENU)
	
	# 7.2 短暂等待确保所有异步初始化完成
	await get_tree().create_timer(0.3).timeout
	
	# 7.3 切换到主菜单场景（使用新版维多利亚风格主界面）
	var err = get_tree().change_scene_to_file("res://scenes/main_menu_v2.tscn")
	if err != OK:
		boot_errors.append("无法加载主菜单场景: %d" % err)
	else:
		print("  ✅ 主菜单已加载")

# ============ 启动完成 ============

func _phase_complete() -> void:
	current_phase = BootPhase.COMPLETE
	var elapsed = Time.get_ticks_msec() - boot_start_time
	
	print("\n" + "=".repeat(55))
	if boot_errors.is_empty():
		print("  ✅ 启动完成 (%d ms)" % elapsed)
	else:
		print("  ⚠️  启动完成但有错误 (%d ms)" % elapsed)
		for err in boot_errors:
			print("    ❌ %s" % err)
	
	for warn in boot_warnings:
		print("    ⚠️  %s" % warn)
	
	print("=".repeat(55))
	SystemEventBus.emit_signal("boot_complete")

func _can_proceed() -> bool:
	# 致命错误才阻止启动
	return boot_errors.is_empty()

# ============ 辅助方法 ============

func _engine_version() -> String:
	var v = Engine.get_version_info()
	return "%d.%d.%s" % [v.major, v.minor, v.status]

func _init_audio_buses() -> void:
	var buses = ["Master", "Music", "SFX", "Voice"]
	for bus_name in buses:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus(AudioServer.get_bus_count())
			var bus_idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(bus_idx, bus_name)
	
	# 应用设置中的音量
	if SettingsManager:
		var master_vol = SettingsManager.get_setting("master_volume")
		if master_vol != null:
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Master"),
				linear_to_db(master_vol)
			)

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		return
	sig.connect(callable)

func _frame() -> void:
	await get_tree().process_frame

# ============ 事件回调 — 全局状态 ============

func _on_game_state_changed(state: int) -> void:
	var names = {0: "BOOT", 1: "MAIN_MENU", 2: "IN_GAME", 3: "PAUSED", 4: "GAME_OVER"}
	print("  [状态] → %s" % names.get(state, "UNKNOWN"))

func _on_game_saved(_save_id: String = "", _timestamp: int = 0) -> void:
	print("  [存档] 已保存")

func _on_game_loaded() -> void:
	print("  [存档] 已加载")

# ============ 事件回调 — 网络状态 ============

func _on_network_online() -> void:
	print("  [网络] 已连接 — 同步离线数据...")
	# 网络恢复后自动刷新离线队列
	if APIManager and APIManager.get_pending_count() > 0:
		APIManager.flush_pending()

func _on_network_offline() -> void:
	print("  [网络] 已断开 — 进入离线模式")

func _on_connectivity_changed(online: bool) -> void:
	if online:
		SystemEventBus.emit_signal("network_online")
	else:
		SystemEventBus.emit_signal("network_offline")

# ============ 事件回调 — 认证 ============

func _on_user_logged_in() -> void:
	print("  [认证] 用户已登录")
	# 登录后拉取云端存档
	if SaveManager:
		SaveManager.load_game()

func _on_user_logged_out() -> void:
	print("  [认证] 用户已登出")

func _on_auth_state_changed(_old: int, new_state: int) -> void:
	var names = {0: "GUEST", 1: "REGISTERING", 2: "REGISTERED", 3: "LOGGED_IN"}
	print("  [认证] 状态变更: %s" % names.get(new_state, "UNKNOWN"))

# ============ 事件回调 — 案件 ============

func _on_case_started(case_id: String) -> void:
	print("  [案件] 开始: %s" % case_id)

func _on_case_loaded(case_id: String) -> void:
	print("  [案件] 加载: %s" % case_id)

# ============ 事件回调 — 存档 ============

func _on_save_completed(_save_id: String, _timestamp: int) -> void:
	pass

func _on_load_completed(_save_id: String, _case_id: String) -> void:
	pass

func _on_no_save() -> void:
	print("  [存档] 无存档记录")
