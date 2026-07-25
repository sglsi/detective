extends Node

## ClueSystem - 线索系统
## 管理线索的发现、记录、关联和15字段标准化数据结构

# 线索状态枚举
enum ClueState {
	UNDISCOVERED,
	DISCOVERED,
	RECORDED,
	ANALYZED,
	LINKED
}

# 线索数据结构见 data/clue_data.gd（class_name ClueData extends Resource，15 字段）
# 全局统一使用 ClueData 资源类；res://data/clues/<id>.tres 即其实例。

var discovered_clues: Dictionary = {}  # clue_id -> ClueData（已发现/已加载的线索实例）
var clue_catalog: Dictionary = {}      # clue_id -> ClueData（全部线索定义，启动预载，真实数据来源）
var clue_count: int = 0

func _ready() -> void:
	_load_catalog()

func load_clue(clue_id: String) -> ClueData:
	if discovered_clues.has(clue_id):
		return discovered_clues[clue_id]
	var path = "res://data/clues/%s.tres" % clue_id
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is ClueData:
		return res
	return null

func discover_clue(clue_id: String) -> void:
	if discovered_clues.has(clue_id):
		return
	var clue = load_clue(clue_id)
	if clue:
		clue.state = ClueState.DISCOVERED
		discovered_clues[clue_id] = clue
		clue_count += 1
		ClueEventBus.emit_signal("clue_discovered", clue_id)

func record_clue(clue_id: String) -> void:
	if not discovered_clues.has(clue_id):
		return
	discovered_clues[clue_id].state = ClueState.RECORDED
	ClueEventBus.emit_signal("clue_recorded", clue_id)

func link_clues(clue_a: String, clue_b: String) -> void:
	if discovered_clues.has(clue_a) and discovered_clues.has(clue_b):
		discovered_clues[clue_a].related_clues.append(clue_b)
		discovered_clues[clue_b].related_clues.append(clue_a)
		discovered_clues[clue_a].state = ClueState.LINKED
		discovered_clues[clue_b].state = ClueState.LINKED
		ClueEventBus.emit_signal("clues_linked", clue_a, clue_b)

func get_discovered_count() -> int:
	return clue_count

func get_total_clues() -> int:
	# 动态统计 data/clues/ 下真实 .tres 线索资源数量（不再硬编码）
	var dir = DirAccess.open("res://data/clues/")
	if dir == null:
		return clue_catalog.size()
	var count = 0
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("."):
			count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count

## 获取全部线索定义（真实数据来源，供推理墙/UI 消费）
func get_all_clue_definitions() -> Dictionary:
	return clue_catalog

## 按 ID 获取单条线索定义（未定义返回 null）
func get_clue_definition(clue_id: String) -> ClueData:
	if clue_catalog.has(clue_id):
		return clue_catalog[clue_id]
	return null

## 启动预载：扫描 data/clues/ 全部 .tres 构建线索目录
func _load_catalog() -> void:
	var dir = DirAccess.open("res://data/clues/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("."):
			var cd = load("res://data/clues/" + fname)
			if cd is ClueData:
				var key = cd.id if cd.id != "" else fname.get_basename()
				clue_catalog[key] = cd
		fname = dir.get_next()
	dir.list_dir_end()

## 存档：导出所有已发现线索的状态（clue_id -> ClueState 整数）
func get_clue_states() -> Dictionary:
	var states: Dictionary = {}
	for clue_id in discovered_clues.keys():
		states[clue_id] = discovered_clues[clue_id].state
	return states

## 存档：从字典恢复线索状态（不依赖 .tres 解析，直接重建内存态）
func restore_clue_states(states: Dictionary) -> void:
	discovered_clues.clear()
	for clue_id in states.keys():
		var cd = ClueData.new()
		cd.id = clue_id
		cd.state = int(states[clue_id])
		discovered_clues[clue_id] = cd
		clue_count = discovered_clues.size()

# ============ 通用「已收集线索」登记（场景无关 · 存/读档单一真相源）============
# 与上面的目录/发现态（Catalog / Discovered）解耦：这里登记的是「玩家在场景中
# 实际收集到的线索」，每条结构固定为：
#   {"id":String, "name":String, "desc":String, "correct":bool, "source":String}
# source 用于区分不同轮次/场景（如 "watson" / "messenger" / "garden"），
# 推理墙、笔记、物品栏等所有功能系统均从此处读取，确保与场景观察器永远一致。

var collected_clues: Array = []

## 登记一条已收集线索（按 id 去重；已存在则更新字段）
func collect_clue(id: String, name: String, desc: String, correct: bool, source: String = "") -> void:
	for c in collected_clues:
		if c.get("id", "") == id:
			c["name"] = name
			c["desc"] = desc
			c["correct"] = correct
			c["source"] = source
			return
	collected_clues.append({"id": id, "name": name, "desc": desc, "correct": correct, "source": source})

## 是否已收集（可按 source 过滤）
func has_collected(id: String, source: String = "") -> bool:
	for c in collected_clues:
		if c.get("id", "") == id and (source == "" or c.get("source", "") == source):
			return true
	return false

## 取出已收集线索（可按 source 过滤；返回副本避免外部篡改）
func get_collected(source: String = "") -> Array:
	if source == "":
		return collected_clues.duplicate()
	var out: Array = []
	for c in collected_clues:
		if c.get("source", "") == source:
			out.append(c.duplicate())
	return out

## 取出已收集线索 ID 列表（可按 source 过滤）
func get_collected_ids(source: String = "") -> Array:
	var out: Array = []
	for c in collected_clues:
		if source == "" or c.get("source", "") == source:
			out.append(c.get("id", ""))
	return out

## 已收集数量（可按 source 过滤）
func count_collected(source: String = "") -> int:
	return get_collected_ids(source).size()

## 清空（新游戏时调用）
func clear_collected() -> void:
	collected_clues.clear()

## 清空指定 source 的已收集线索（读档恢复前调用，避免全局累计导致「两层皮」）
## source 用于区分不同轮次/场景（"watson"/"messenger"/"garden"/"indoor"），
## 推理墙、笔记、物品栏等据此筛选——仅清本 source，不影响其它轮的线索。
func clear_source(source: String) -> void:
	var kept: Array = []
	for c in collected_clues:
		if c.get("source", "") != source:
			kept.append(c)
	collected_clues = kept

## 供 SaveManager 序列化的完整快照
func get_collected_clues_snapshot() -> Array:
	return collected_clues.duplicate()

## 从存档恢复（由 SaveManager 调用，元素结构同 collect_clue）
func restore_collected_clues(snapshot: Array) -> void:
	collected_clues.clear()
	if snapshot is not Array:
		return
	for c in snapshot:
		if c is Dictionary and c.has("id"):
			collected_clues.append(c.duplicate())
