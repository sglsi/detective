extends Node

## GameManager — 游戏全局管理器
## 管理游戏状态机：BOOT → MAIN_MENU → IN_GAME ⇄ PAUSED → GAME_OVER
## 连接前后端架构的核心枢纽：
##   认证状态 ─→ 存档策略（本地/云端）
##   网络状态 ─→ 同步策略（在线同步/离线降级）
##   游戏状态 ─→ UI 切换 + 存档触发

# ============ 状态枚举 ============

enum GameState {
	BOOT,
	MAIN_MENU,
	IN_GAME,
	PAUSED,
	GAME_OVER
}

# ============ 变量 ============

var current_state: GameState = GameState.BOOT
var is_guest: bool = true
var has_existing_save: bool = false
var current_case_id: String = ""
var current_scene_id: String = ""
var game_start_time: int = 0
var is_online: bool = false
var completed_milestones: Array = []  # 已完成里程碑 ID 列表（P5-1 存档补全）

# ============ 生命周期 ============

func _ready() -> void:
	# 连接网络状态变化（从 APIManager）
	if APIManager:
		APIManager.connectivity_changed.connect(_on_connectivity_changed)
	
	# 连接认证状态变化（从 AuthManager）
	if AuthManager:
		AuthManager.auth_state_changed.connect(_on_auth_changed)
	
	# 连接系统事件
	_safe_connect(SystemEventBus.game_saved, _on_game_saved)
	
	# 初始状态
	_change_state(GameState.MAIN_MENU)

func _on_connectivity_changed(online: bool) -> void:
	is_online = online
	if online:
		SystemEventBus.emit_signal("network_online")
		# 网络恢复 → 刷新离线队列
		if APIManager.get_pending_count() > 0:
			APIManager.flush_pending()
		# 注册用户网络恢复 → 同步存档
		if not is_guest and SaveManager:
			_sync_cloud_save()
	else:
		SystemEventBus.emit_signal("network_offline")

func _on_auth_changed(_old: int, new_state: int) -> void:
	# 认证状态变化影响存档策略
	if new_state == AuthManager.AuthState.LOGGED_IN:
		is_guest = false
		# 登录成功后自动同步云端数据
		_sync_cloud_data()
	elif new_state == AuthManager.AuthState.GUEST:
		is_guest = true

func _on_game_saved(_save_id: String, _timestamp: int) -> void:
	# 存档后更新案件进度（注册用户）
	if not is_guest and APIManager and APIManager.is_online:
		var progress = {
			"status": "in_progress",
			"clues_found": ClueSystem.clue_count if ClueSystem else 0,
			"observation_stars": StarRatingSystem.observation_score if StarRatingSystem else 0,
			"reasoning_stars": StarRatingSystem.reasoning_score if StarRatingSystem else 0,
			"insight_stars": StarRatingSystem.insight_score if StarRatingSystem else 0,
		}
		APIManager.update_case_progress(current_case_id, progress)

# ============ 状态管理 ============

func _change_state(new_state: GameState) -> void:
	var old = current_state
	current_state = new_state
	
	if SystemEventBus:
		SystemEventBus.emit_signal("game_state_changed", new_state)
	
	# 状态变化时的额外逻辑
	match new_state:
		GameState.IN_GAME:
			game_start_time = Time.get_ticks_msec()
		GameState.PAUSED:
			SystemEventBus.emit_signal("game_paused")
		GameState.GAME_OVER:
			SystemEventBus.emit_signal("game_over", "normal")

# ============ 游戏操作 ============

## 开始新案件
func start_case(case_id: String) -> void:
	current_case_id = case_id
	_change_state(GameState.IN_GAME)
	
	if CaseEventBus:
		CaseEventBus.emit_signal("case_started", case_id)
	
	# 初始化案件进度（注册用户云端记录）
	if not is_guest and APIManager and APIManager.is_online:
		APIManager.update_case_progress(case_id, {
			"status": "in_progress",
			"started_at": Time.get_datetime_string_from_system(),
		})

## 继续案件（从存档加载后）
func continue_case(case_id: String, scene_id: String) -> void:
	current_case_id = case_id
	current_scene_id = scene_id
	_change_state(GameState.IN_GAME)
	
	if CaseEventBus:
		CaseEventBus.emit_signal("case_loaded", case_id)

## 暂停
func pause_game() -> void:
	if current_state == GameState.IN_GAME:
		_change_state(GameState.PAUSED)

## 继续
func resume_game() -> void:
	if current_state == GameState.PAUSED:
		_change_state(GameState.IN_GAME)

## 结束案件
func end_case(reason: String = "completed") -> void:
	_change_state(GameState.GAME_OVER)
	SystemEventBus.emit_signal("case_completed", current_case_id, {
		"observation": StarRatingSystem.observation_score if StarRatingSystem else 0,
		"reasoning": StarRatingSystem.reasoning_score if StarRatingSystem else 0,
		"insight": StarRatingSystem.insight_score if StarRatingSystem else 0,
	})

## 返回主菜单
func return_to_menu() -> void:
	_change_state(GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ============ 注册/登录 ============

## 注册用户（迁移游客数据）
func register_user(username: String, email: String, password: String, phone: String = "") -> void:
	if AuthManager:
		AuthManager.register(username, email, password, phone)

## 登录
func login_user(email: String, password: String) -> void:
	if AuthManager:
		AuthManager.login(email, password)

# ============ 云端同步 ============

## 登录后同步云端数据
func _sync_cloud_data() -> void:
	if not APIManager or not APIManager.is_online:
		return
	
	print("[GameManager] 同步云端数据...")
	
	# 拉取最新存档
	if SaveManager:
		SaveManager.load_game()
	
	# 拉取所有案件进度
	APIManager.get_all_progress()

## 同步云端存档
func _sync_cloud_save() -> void:
	if not is_guest and SaveManager:
		SaveManager.save_game()

# ============ 状态查询 ============

func get_game_duration_seconds() -> float:
	if game_start_time == 0:
		return 0
	return (Time.get_ticks_msec() - game_start_time) / 1000.0

func is_in_game() -> bool:
	return current_state == GameState.IN_GAME

func is_paused() -> bool:
	return current_state == GameState.PAUSED

# ============ 里程碑（P5-1 存档补全） ============

## 标记一个里程碑为已完成（去重）
func add_milestone(milestone_id: String) -> void:
	if not completed_milestones.has(milestone_id):
		completed_milestones.append(milestone_id)

## 查询已完成的里程碑列表（供存档收集）
func get_completed_milestones() -> Array:
	return completed_milestones.duplicate()

## 从存档字典恢复里程碑（供读档恢复）
func restore_milestones(milestones: Array) -> void:
	completed_milestones.clear()
	for m in milestones:
		if not completed_milestones.has(m):
			completed_milestones.append(m)

# ============ 辅助 ============

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
