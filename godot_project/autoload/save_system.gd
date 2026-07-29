extends Node

## SaveSystem — 通用存/读档服务（项目级，与具体场景无关）
## 注意：不要在此声明 `class_name SaveSystem`，否则会与同名 autoload 单例冲突（Godot 4 报 "hides an autoload singleton"）。
##
## 设计原则：存档 / 读档是整个项目的通用功能，不依赖任何场景。
## 场景只做两件事：
##   1) 提供自身可序列化状态：  get_save_data() -> Dictionary
##   2) 消费恢复的状态：        restore_from_save(data: Dictionary) -> void
## 其余（持久化、场景切换、快照存取、线索登记）全部由本服务
## 与 SaveManager / GameManager / ClueSystem 通用处理。
##
## 线索登记、推理墙亦为通用服务，统一以 ClueSystem.collected_clues 为单一真相源。

# ============ 读取：判断 / 取回属于本场景的存档状态 ============

## 是否存在属于该场景的有效存档
func has_save_for(scene_id: String) -> bool:
	var ss = _current_state()
	return not ss.is_empty() and ss.get("scene_id", "") == scene_id

## 取出属于该场景的存档状态（默认消费掉，避免重复恢复），无匹配返回 {}
func take_save_state(scene_id: String, consume: bool = true) -> Dictionary:
	var ss = _current_state()
	if ss.is_empty() or ss.get("scene_id", "") != scene_id:
		return {}
	if consume and GameManager:
		GameManager.scene_state = {}
	return ss.duplicate()

## 预览（不消费）属于该场景的存档状态
func peek_save_state(scene_id: String) -> Dictionary:
	var ss = _current_state()
	if ss.is_empty() or ss.get("scene_id", "") != scene_id:
		return {}
	return ss.duplicate()

# ============ 写入：场景请求保存 ============

## 场景把自身状态交给通用存档流程
##   scene_id : 场景标识（如 "scene1"），用于读档归属判定
##   phase    : 场景自定义的当前阶段值（int）
##   data     : 场景自定义的附加状态字典（如 {"clue_ids":[...]}）
##   slot     : 指定存档槽位（0..2）；缺省 -1 表示自动分配（空槽位优先，满则覆盖最旧）。
func request_save(scene_id: String, phase: int, data: Dictionary, slot: int = -1) -> void:
	if GameManager:
		GameManager.current_scene_id = scene_id
	await GameManager.do_save(phase, data, slot)

## 真正读档：刷新 GameManager.scene_state 与 ClueSystem，返回是否成功。
## 场景/UI 一律经此门面读档，不要直接调 SaveManager.load_game()。
##   slot     : 指定读取槽位；缺省 -1 表示沿用当前 current_slot。
func load_game(slot: int = -1) -> bool:
	if not SaveManager:
		return false
	var target := slot if slot >= 0 else (GameManager.current_slot if GameManager else 0)
	return await SaveManager.load_slot(target)

## 是否存在任意本地存档（用于「继续游戏」按钮可用性）
func has_save() -> bool:
	return SaveManager.has_any_save() if SaveManager else false

## 读取全部槽位的摘要列表（按槽位号顺序）
func list_slots() -> Array:
	return SaveManager.get_slot_list() if SaveManager else []

## 读取「已有存档」槽位列表，按时间倒序（最新在上）——读档面板专用
func list_slots_sorted() -> Array:
	return SaveManager.get_slot_list_sorted() if SaveManager else []

# ============ 新游戏：清空一切运行时进度 ============

## 真正的新游戏：清空内存态与本地/云端存档进度，并清空线索登记
func new_game() -> void:
	if GameManager:
		GameManager.clear_save()
	if ClueSystem:
		ClueSystem.clear_collected()

# ============ 内部 ============

func _current_state() -> Dictionary:
	if GameManager:
		return GameManager.scene_state
	return {}
