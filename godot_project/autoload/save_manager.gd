extends Node

## SaveManager — 存档管理器
## M1 策略：服务端覆盖（同一用户+同一案件，最新时间戳为准）
## M2+ 策略：案件级合并（预留）
##
## 双模式支持：
##   - 游客模式：本地 JSON 文件存储
##   - 注册用户：云端 Supabase 同步 + 本地缓存

# ============ 信号 ============

signal game_saved(save_id: String, timestamp: int)
signal game_loaded(save_id: String, case_id: String)
signal save_sync_failed(error: String)
signal no_save_found

# ============ 数据 ============

var save_data: Dictionary = {}
var save_version: int = 1
var last_save_timestamp: int = 0
var last_save_id: String = ""

# ============ 生命周期 ============

func _ready() -> void:
	# 连接认证状态变化
	if AuthManager:
		AuthManager.auth_state_changed.connect(_on_auth_changed)
	
	# 连接网络状态变化
	if APIManager:
		APIManager.connectivity_changed.connect(_on_connectivity_changed)

func _on_auth_changed(_old: int, new_state: int) -> void:
	## 认证状态变化时，考虑迁移本地存档到云端
	if new_state == AuthManager.AuthState.LOGGED_IN and _has_local_save():
		print("[SaveManager] 检测到本地存档，提示用户是否迁移到云端")
		# TODO: 弹出对话框询问用户是否迁移

func _on_connectivity_changed(online: bool) -> void:
	if online and APIManager.get_pending_count() > 0:
		print("[SaveManager] 网络恢复，尝试同步待处理存档")
		APIManager.flush_pending()

# ============ 存档操作 ============

## 保存游戏
func save_game() -> Dictionary:
	_build_save_data()
	
	if GameManager.is_guest:
		return await _save_local()
	else:
		return await _save_to_server()

func _build_save_data() -> void:
	## 从各子系统收集存档数据
	save_data = {
		"save_version": save_version,
		"timestamp": Time.get_unix_time_from_system(),
		"case_id": GameManager.current_case_id,
		"scene_id": GameManager.current_scene_id,
		"difficulty": DifficultyManager.current_difficulty,
		"clue_count": ClueSystem.clue_count,
		"observation_score": StarRatingSystem.observation_score,
		"reasoning_score": StarRatingSystem.reasoning_score,
		"insight_score": StarRatingSystem.insight_score,
		"is_guest": GameManager.is_guest,
		"game_time": 0,  # TODO: 游戏内计时器
		"dialogue_progress": _get_dialogue_progress(),
		"clue_states": _get_clue_states(),
		"unlocked_locations": _get_unlocked_locations(),
		"completed_milestones": _get_completed_milestones(),
		"settings_snapshot": _get_settings_snapshot(),
		"metadata": {
			"version": "0.1.0",
			"platform": OS.get_name(),
			"device_id": OS.get_unique_id() if OS.has_feature("mobile") else "desktop",
		},
	}
	last_save_timestamp = save_data["timestamp"]

# ============ 本地存档 ============

func _save_local() -> Dictionary:
	var file = FileAccess.open("user://save_game.json", FileAccess.WRITE)
	if not file:
		return {"error": true, "message": "无法写入本地存档文件"}
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	print("[SaveManager] 本地存档已保存")
	SystemEventBus.emit_signal("game_saved", "local", last_save_timestamp)
	game_saved.emit("local", last_save_timestamp)
	return {"error": false, "save_id": "local", "timestamp": last_save_timestamp}

func _has_local_save() -> bool:
	return FileAccess.file_exists("user://save_game.json")

# ============ 云端存档 ============

func _save_to_server() -> Dictionary:
	if not APIManager or not APIManager.is_online:
		# 离线时先存本地，加入上传队列
		_save_local()
		APIManager._queue_request("upload_save", save_data)
		print("[SaveManager] 离线模式，存档已缓存本地，待网络恢复后同步")
		return {"error": false, "save_id": "local_queued", "timestamp": last_save_timestamp}
	
	var result = await APIManager.upload_save(save_data)
	
	if result.get("error", true):
		save_sync_failed.emit(result.get("message", "存档同步失败"))
		# 失败时仍保存本地
		_save_local()
		return result
	
	var data = result.get("data", {})
	last_save_id = data.get("save_id", "")
	
	print("[SaveManager] 云端存档已同步: ", last_save_id)
	SystemEventBus.emit_signal("game_saved", last_save_id, last_save_timestamp)
	game_saved.emit(last_save_id, last_save_timestamp)
	return result

# ============ 读档操作 ============

## 加载游戏
func load_game() -> bool:
	if GameManager.is_guest:
		return await _load_local()
	else:
		return await _load_from_server()

func _load_local() -> bool:
	if not FileAccess.file_exists("user://save_game.json"):
		no_save_found.emit()
		return false
	
	var file = FileAccess.open("user://save_game.json", FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(text)
	if json:
		_restore_from_dict(json)
		SystemEventBus.emit_signal("game_loaded")
		game_loaded.emit("local", json.get("case_id", ""))
		return true
	
	return false

func _load_from_server() -> bool:
	if not APIManager or not APIManager.is_online:
		# 离线时尝试加载本地缓存
		if _has_local_save():
			print("[SaveManager] 离线模式，加载本地缓存存档")
			return await _load_local()
		no_save_found.emit()
		return false
	
	var case_id = GameManager.current_case_id
	var result = await APIManager.get_latest_save(case_id)
	
	if result.get("error", true):
		no_save_found.emit()
		# 检查是否有本地缓存
		if _has_local_save():
			print("[SaveManager] 云端无存档，尝试加载本地缓存")
			return await _load_local()
		return false
	
	var data = result.get("data", {})
	var save = data.get("save", {})
	
	if save:
		_restore_from_dict(save)
		last_save_id = save.get("id", "")
		SystemEventBus.emit_signal("game_loaded")
		game_loaded.emit(last_save_id, save.get("case_id", ""))
		return true
	
	no_save_found.emit()
	return false

# ============ 数据恢复 ============

func _restore_from_dict(data: Dictionary) -> void:
	GameManager.current_case_id = data.get("case_id", "")
	GameManager.current_scene_id = data.get("scene_id", "")
	DifficultyManager.set_difficulty(data.get("difficulty", 0))
	StarRatingSystem.observation_score = data.get("observation_score", 0)
	StarRatingSystem.reasoning_score = data.get("reasoning_score", 0)
	StarRatingSystem.insight_score = data.get("insight_score", 0)
	last_save_timestamp = data.get("timestamp", 0)
	
	# 恢复其他状态
	if data.has("dialogue_progress"):
		_restore_dialogue_progress(data["dialogue_progress"])
	if data.has("clue_states"):
		_restore_clue_states(data["clue_states"])
	if data.has("unlocked_locations"):
		_restore_unlocked_locations(data["unlocked_locations"])
	if data.has("completed_milestones"):
		_restore_completed_milestones(data["completed_milestones"])

# ============ 存档查询 ============

## 获取云端存档列表
func get_cloud_saves() -> Dictionary:
	if not APIManager or not APIManager.is_online:
		return {"error": true, "message": "网络不可用"}
	
	return await APIManager.get_save_list()

## 获取案件进度
func get_case_progress(case_id: String) -> Dictionary:
	if not APIManager or not APIManager.is_online:
		return {"error": true, "message": "网络不可用"}
	
	return await APIManager.get_case_progress(case_id)

## 更新案件进度
func update_case_progress(case_id: String, progress: Dictionary) -> void:
	if not APIManager or not APIManager.is_online:
		APIManager._queue_request("update_progress", {"case_id": case_id, "progress": progress})
		return
	
	await APIManager.update_case_progress(case_id, progress)

# ============ 辅助方法（预留接口） ============

func _get_dialogue_progress() -> Dictionary:
	if DialogueProgress:
		return DialogueProgress.get_dialogue_progress()
	return {}

func _get_clue_states() -> Dictionary:
	if ClueSystem:
		return ClueSystem.get_clue_states()
	return {}

func _get_unlocked_locations() -> Array:
	if MapManager:
		return MapManager.get_unlocked_locations()
	return []

func _get_completed_milestones() -> Array:
	if GameManager:
		return GameManager.get_completed_milestones()
	return []

func _get_settings_snapshot() -> Dictionary:
	if SettingsManager:
		return SettingsManager.get_all_settings()
	return {}

func _restore_dialogue_progress(data: Dictionary) -> void:
	if DialogueProgress:
		DialogueProgress.restore_dialogue_progress(data)

func _restore_clue_states(data: Dictionary) -> void:
	if ClueSystem:
		ClueSystem.restore_clue_states(data)

func _restore_unlocked_locations(data: Array) -> void:
	if MapManager:
		MapManager.restore_unlocked_locations(data)

func _restore_completed_milestones(data: Array) -> void:
	if GameManager:
		GameManager.restore_milestones(data)
