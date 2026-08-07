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
var last_save_slot: int = 0

# ============ 多槽位存档 ============
# 3 个本地槽位，按登录用户隔离，存于 user://saves/<用户>/slot_0.json .. slot_2.json。
# 各用户的存档相互独立：用户 A 登录看不到用户 B 的存档。
# 保存不需要玩家选槽位：自动分配（先用空槽位，满了覆盖最旧的），
# 形成「最近 3 次存档」滚动历史；读档列表按时间倒序（最新在上）。
const SLOT_COUNT: int = 3
const SLOT_DIR: String = "user://saves/"
const SLOT_FILE_PREFIX: String = "slot_"

## 文件名安全化：仅保留字母/数字/下划线/连字符，其余替换为下划线
func _sanitize_dir_name(raw: String) -> String:
	var out := ""
	for ch in raw:
		var c: String = ch
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			out += c
		else:
			out += "_"
	return out if not out.is_empty() else "unknown"

## 当前用户的存档命名空间（登录用户 = user_id；游客 = guest）
func _user_namespace() -> String:
	if AuthManager and AuthManager.is_authenticated():
		var raw: String = str(AuthManager.get_user_id())
		if raw.is_empty():
			raw = str(AuthManager.get_username())
		return _sanitize_dir_name(raw)
	return "guest"

## 当前用户的存档目录（user:// 相对路径形式，供 make_dir_recursive 用）
func _user_save_subdir() -> String:
	return "saves/" + _user_namespace()

## 槽位 N 的文件路径（按当前登录用户隔离）
func slot_path(slot: int) -> String:
	return SLOT_DIR + _user_namespace() + "/" + SLOT_FILE_PREFIX + str(slot) + ".json"

## 是否存在任意槽位存档（用于「继续游戏」可用性）
func has_any_save() -> bool:
	for i in SLOT_COUNT:
		if FileAccess.file_exists(slot_path(i)):
			return true
	return false

## 读取单个槽位的摘要信息（不加载完整进度，仅用于列表展示）
func get_slot_meta(slot: int) -> Dictionary:
	var path = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"slot": slot, "exists": false, "timestamp": 0, "scene_id": "", "case_id": "", "difficulty": 0, "label": ""}
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var json = JSON.parse_string(text)
	if not json:
		return {"slot": slot, "exists": false, "timestamp": 0, "scene_id": "", "case_id": "", "difficulty": 0, "label": ""}
	return {
		"slot": slot,
		"exists": true,
		"timestamp": json.get("timestamp", 0),
		"scene_id": json.get("scene_id", ""),
		"case_id": json.get("case_id", ""),
		"difficulty": json.get("difficulty", 0),
		"label": json.get("label", ""),
	}

## 读取全部槽位的摘要列表（按槽位号顺序）
func get_slot_list() -> Array:
	var list: Array = []
	for i in SLOT_COUNT:
		list.append(get_slot_meta(i))
	return list

## 读取「已有存档」的槽位摘要，按时间倒序（最新在最上面）——读档面板专用
func get_slot_list_sorted() -> Array:
	var list: Array = []
	for i in SLOT_COUNT:
		var meta = get_slot_meta(i)
		if meta.get("exists", false):
			list.append(meta)
	list.sort_custom(func(a, b): return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0)))
	return list

## 自动分配存档槽位：优先空槽位；全满时覆盖时间戳最旧的槽位。
## 保存永远不需要玩家手选槽位（滚动保留最近 SLOT_COUNT 次存档）。
func pick_auto_slot() -> int:
	var oldest_slot := 0
	var oldest_ts := 9223372036854775807
	for i in SLOT_COUNT:
		var meta = get_slot_meta(i)
		if not meta.get("exists", false):
			return i
		var ts := int(meta.get("timestamp", 0))
		if ts < oldest_ts:
			oldest_ts = ts
			oldest_slot = i
	return oldest_slot

## 删除指定槽位存档
func clear_slot(slot: int) -> void:
	var path = slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

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
	if new_state == AuthManager.AuthState.LOGGED_IN and has_local_save():
		print("[SaveManager] 检测到本地存档，提示用户是否迁移到云端")
		# TODO: 弹出对话框询问用户是否迁移

func _on_connectivity_changed(online: bool) -> void:
	if online and APIManager.get_pending_count() > 0:
		print("[SaveManager] 网络恢复，尝试同步待处理存档")
		APIManager.flush_pending()

# ============ 存档操作 ============

## 保存游戏
## 设计：本地缓存文件（user://save_game.json）是会话内读档的权威来源，
## 每次存档都先写本地；注册用户在线时再同步到云端（云端异常不影响本地已存）。
## 这样无论网络/后端如何波动，存档→读档一定闭环（符合「存/读档是通用功能」原则）。
## 默认存档（无槽位参数）写入槽位 0，保持旧调用方兼容
func save_game() -> Dictionary:
	return await save_to_slot(0)

## 保存到指定槽位（0..SLOT_COUNT-1）。本地槽位文件为权威；注册用户在线时再镜像云端。
func save_to_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {"error": true, "message": "无效存档槽位: " + str(slot)}
	_build_save_data()
	save_data["slot"] = slot
	last_save_slot = slot

	# 1) 始终写入本地槽位
	var local_res = _write_slot_file(slot, save_data)
	var result = local_res

	# 2) 注册用户在线时同步到云端（仅作镜像，失败不影响本地）
	if not GameManager.is_guest and APIManager and APIManager.is_online:
		var server_res = await _save_to_server()
		if not server_res.get("error", true):
			result = server_res

	return result

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
		"star_chains": StarRatingSystem.chains.duplicate(),   # v4.0 逐链三维星级（读档恢复用）
		"scene_state": GameManager.scene_state.duplicate(),   # 场景内运行状态（phase, clue_ids）
		"collected_clues": _get_collected_clues(),             # 通用已收集线索（场景无关单一真相源）
		"is_guest": GameManager.is_guest,
		"game_time": 0,  # TODO: 游戏内计时器
		"dialogue_progress": _get_dialogue_progress(),
		"clue_states": _get_clue_states(),
		"unlocked_locations": _get_unlocked_locations(),
		"completed_milestones": _get_completed_milestones(),
		"settings_snapshot": _get_settings_snapshot(),
		"badges": BadgeSystem.get_unlocked_badges() if BadgeSystem else {},
		"endings": EndingSystem.get_all_endings() if EndingSystem else {},
		"progress": ProgressSystem.get_all_progress() if ProgressSystem else {},
		"timeline": TimelineSystem.get_all_entries() if TimelineSystem else {},
		"kb_notes": KnowledgeBaseSystem.get_notes() if KnowledgeBaseSystem else [],
		"kb_favorites": KnowledgeBaseSystem.get_favorites() if KnowledgeBaseSystem else [],
		"tools": ToolSystem.get_persistent_state() if ToolSystem else {},
		"metadata": {
			"version": "0.1.0",
			"platform": OS.get_name(),
			"device_id": OS.get_unique_id() if OS.has_feature("mobile") else "desktop",
		},
	}
	last_save_timestamp = save_data["timestamp"]

# ============ 本地存档 ============

func _write_slot_file(slot: int, data: Dictionary) -> Dictionary:
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(_user_save_subdir())
	var path = slot_path(slot)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"error": true, "message": "无法写入本地存档文件: " + path}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("[SaveManager] 本地存档已保存 (槽位 ", slot, "): ", path)
	SystemEventBus.emit_signal("game_saved", "slot_" + str(slot), last_save_timestamp)
	game_saved.emit("slot_" + str(slot), last_save_timestamp)
	last_save_id = "slot_" + str(slot)
	return {"error": false, "save_id": "slot_" + str(slot), "slot": slot, "timestamp": last_save_timestamp}

## 兼容别名：是否存在任意本地存档
func has_local_save() -> bool:
	return has_any_save()

# ============ 云端存档 ============

func _save_to_server() -> Dictionary:
	if not APIManager or not APIManager.is_online:
		# 离线：本地缓存已由 save_game 写入，这里仅入队等待同步
		APIManager._queue_request("upload_save", save_data)
		print("[SaveManager] 离线模式，存档已入队等待同步（本地缓存已写入）")
		return {"error": false, "save_id": "local_queued", "timestamp": last_save_timestamp}
	
	var result = await APIManager.upload_save(save_data)
	
	if result.get("error", true):
		save_sync_failed.emit(result.get("message", "存档同步失败"))
		return result
	
	var data = result.get("data", {})
	last_save_id = data.get("save_id", "")
	
	print("[SaveManager] 云端存档已同步: ", last_save_id)
	SystemEventBus.emit_signal("game_saved", last_save_id, last_save_timestamp)
	game_saved.emit(last_save_id, last_save_timestamp)
	return result

# ============ 读档操作 ============

## 默认读档（无槽位参数）读取槽位 0，保持旧调用方兼容
func load_game(slot: int = 0) -> bool:
	return await load_slot(slot)

## 从指定槽位读取本地存档。离线优先；无后端时本地槽位即权威来源。
func load_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		no_save_found.emit()
		return false
	if not FileAccess.file_exists(slot_path(slot)):
		no_save_found.emit()
		return false
	return await _load_slot_file(slot)

func _load_slot_file(slot: int) -> bool:
	var path = slot_path(slot)
	if not FileAccess.file_exists(path):
		no_save_found.emit()
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var json = JSON.parse_string(text)
	if json:
		_restore_from_dict(json)
		SystemEventBus.emit_signal("game_loaded")
		game_loaded.emit("slot_" + str(slot), json.get("case_id", ""))
		return true

	return false

func _load_from_server() -> bool:
	if not APIManager or not APIManager.is_online:
		return false
	
	var case_id = GameManager.current_case_id
	var result = await APIManager.get_latest_save(case_id)
	
	if result.get("error", true):
		return false
	
	var data = result.get("data", {})
	var save = data.get("save", {})
	if save.is_empty():
		return false
	
	# 云端较新才覆盖本地（按时间戳），避免把进度往回退
	var local_ts = last_save_timestamp
	var server_ts = save.get("timestamp", 0)
	if local_ts > 0 and server_ts > 0 and server_ts < local_ts:
		print("[SaveManager] 云端存档较旧，保留本地缓存")
		return false
	
	_restore_from_dict(save)
	last_save_id = save.get("id", "")
	SystemEventBus.emit_signal("game_loaded")
	game_loaded.emit(last_save_id, save.get("case_id", ""))
	return true

# ============ 数据恢复 ============

func _restore_from_dict(data: Dictionary) -> void:
	GameManager.current_case_id = data.get("case_id", "")
	GameManager.current_scene_id = data.get("scene_id", "")
	if GameManager and "current_slot" in GameManager:
		GameManager.current_slot = data.get("slot", 0)
	DifficultyManager.set_difficulty(data.get("difficulty", 0))
	StarRatingSystem.observation_score = data.get("observation_score", 0)
	StarRatingSystem.reasoning_score = data.get("reasoning_score", 0)
	StarRatingSystem.insight_score = data.get("insight_score", 0)
	# v4.0 逐链三维星级：优先从存档恢复（保证读档后评分不丢）；否则由聚合分重建单链
	if data.has("star_chains") and not data["star_chains"].is_empty():
		StarRatingSystem.chains = data["star_chains"].duplicate()
	else:
		StarRatingSystem.chains = {}
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
	if data.has("scene_state"):
		GameManager.scene_state = data["scene_state"].duplicate()
		print("[SaveManager] scene_state 已恢复: ", GameManager.scene_state)
	if data.has("collected_clues") and ClueSystem:
		ClueSystem.restore_collected_clues(data["collected_clues"])
		print("[SaveManager] collected_clues 已恢复: ", ClueSystem.count_collected())
	if data.has("badges") and BadgeSystem:
		BadgeSystem.restore_badges(data["badges"])
	if data.has("endings") and EndingSystem:
		EndingSystem.restore_endings(data["endings"])
	if data.has("progress") and ProgressSystem:
		ProgressSystem.restore_progress(data["progress"])
	if data.has("timeline") and TimelineSystem:
		TimelineSystem.restore_timeline(data["timeline"])
	if data.has("kb_notes") and KnowledgeBaseSystem:
		KnowledgeBaseSystem.restore_notes(data["kb_notes"])
	if data.has("kb_favorites") and KnowledgeBaseSystem:
		KnowledgeBaseSystem.restore_favorites(data["kb_favorites"])
	if data.has("tools") and ToolSystem:
		ToolSystem.restore_state(data["tools"])

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

func _get_collected_clues() -> Array:
	if ClueSystem:
		return ClueSystem.get_collected_clues_snapshot()
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
