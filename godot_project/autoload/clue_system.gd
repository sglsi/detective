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
	# 修复根因调试 2026-08-19 v7：catalog=0 的根因是「pck 打包后 *.tres 变 *.tres.remap，
	# _load_catalog/get_total_clues/load_clue 的 ends_with('.tres') 过滤全灭」——现已兼容 remap。
	print("[ClueSystem] AUTOLOAD_READY v7 20260819-2035 catalog_will_load")
	_load_catalog()
	print("[ClueSystem] catalog loaded, size=%d" % clue_catalog.size())

func load_clue(clue_id: String) -> ClueData:
	if discovered_clues.has(clue_id):
		return discovered_clues[clue_id]
	var path = "res://data/clues/%s.tres" % clue_id
	if not ResourceLoader.exists(path):
		path = path + ".remap"  # ⚠️ pck 打包后 *.tres 以 *.tres.remap 存在（Godot 导出重映射），native 源码树无 remap
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
		if _is_tres_name(fname):
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
		if _is_tres_name(fname):
			# ⚠️ pck 打包后目录里是 xxx.tres.remap（Godot 导出重映射），
			# load() 时用去掉 .remap 的原始名（资源系统会自动跟随重映射；native 无 remap 不受影响）
			var real_name := fname.trim_suffix(".remap")
			var cd = load("res://data/clues/" + real_name)
			if cd is ClueData:
				var key = cd.id if cd.id != "" else real_name.get_basename()
				clue_catalog[key] = cd
		fname = dir.get_next()
	dir.list_dir_end()

## pck 打包后 .tres 会以 .tres.remap 形式存在（Godot 4 导出重映射），两种后缀都识别
func _is_tres_name(fname: String) -> bool:
	if fname.begins_with("."):
		return false
	return fname.ends_with(".tres") or fname.ends_with(".tres.remap")

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

## 案件级推理墙持久化状态（跨场景共享单一真相源）。
## 场景二~八的「全案大墙」以它为 state_store（reasoning_wall 的 _state_store 引用），
## 墙内关系/节点位置/折叠/放置等图谱状态在此跨场景驻留：前一场景建立的推理内容
## 会原样带到下一场景，并在新墙打开时按 _auto_fold 折叠已确立的推理主干。
## 随 SaveManager snapshot 一并存/读档（见 save_manager.gd）。
var case_wall_state: Dictionary = {}

## 登记一条已收集线索（按 id 去重；已存在则更新字段）
## weight：线索分级权重（关键10/重要5/一般2/其他0，误导0）。tier 为其中文展示标签，
## 由 weight+correct 派生，仅供 UI/笔记展示，不参与计算。默认 0 兼容旧调用方（存/读档测试）。
## related_npcs：关联 NPC 列表（图谱视图人物聚焦依赖此字段；未传则空[]，兼容旧调用方）。
func collect_clue(id: String, name: String, desc: String, correct: bool, source: String = "", weight: int = 0, image: String = "", anchor: String = "", content_tags: Array = [], attribute_tags: Array = [], relation_tags: Array = [], related_npcs: Array = []) -> void:
	var tier := tier_label(weight, correct)
	for c in collected_clues:
		if c.get("id", "") == id:
			c["name"] = name
			c["desc"] = desc
			c["correct"] = correct
			c["source"] = source
			c["weight"] = weight
			c["tier"] = tier
			c["image"] = image
			c["anchor"] = anchor
			c["content_tags"] = content_tags
			c["attribute_tags"] = attribute_tags
			c["relation_tags"] = relation_tags
			c["related_npcs"] = related_npcs
			# 线索发现即重置停滞计数（设计 08 §3.5：停滞由「未发现线索的连续交互」驱动）
			if DifficultyManager != null:
				DifficultyManager.reset_stall_counter()
			return
	collected_clues.append({"id": id, "name": name, "desc": desc, "correct": correct, "source": source, "weight": weight, "tier": tier, "image": image, "anchor": anchor, "content_tags": content_tags, "attribute_tags": attribute_tags, "relation_tags": relation_tags, "related_npcs": related_npcs})
	if DifficultyManager != null:
		DifficultyManager.reset_stall_counter()

## 统一线索登记（数据源单一化）：优先采用 .tres 目录（clue_catalog）中该线索的
## 权威 name / description；目录缺失或字段为空时回退到场景内联文本，
## 从而消除「场景内联 desc」与「.tres ClueData.desc」两处重复维护、易漂移的问题。
## 注意：correct 始终取自场景内联——它是游戏性判定标志（驱动推理墙 CONTRADICTORY），
## 不在 ClueData 15 字段模型中，故不覆盖，避免误改判定结果。
func collect_clue_from_catalog(id: String, name: String, desc: String, correct: bool, source: String = "", inline_weight: int = -1, image: String = "", anchor: String = "", content_tags: Array = [], attribute_tags: Array = [], relation_tags: Array = [], related_npcs: Array = []) -> void:
	var def = get_clue_definition(id)
	var w := weight_of(id, correct, inline_weight)
	# 三级标签：场景内联优先（阶段1/2 由 HOTSPOTS 指定），.tres 目录（ClueData）作为权威兜底
	var ct: Array = content_tags if not content_tags.is_empty() else (def.content_tags if (def != null) else [])
	var at: Array = attribute_tags if not attribute_tags.is_empty() else (def.attribute_tags if (def != null) else [])
	var rt: Array = relation_tags if not relation_tags.is_empty() else (def.relation_tags if (def != null) else [])
	# related_npcs：图谱视图人物聚焦依赖此字段，目录为权威（场景内联很少传），未传则空数组
	var rn: Array = related_npcs if not related_npcs.is_empty() else (def.related_npcs if (def != null) else [])
	if def != null:
		var cn: String = def.name if def.name != "" else name
		var cd: String = def.description if def.description != "" else desc
		collect_clue(id, cn, cd, correct, source, w, image, anchor, ct, at, rt, rn)
	else:
		collect_clue(id, name, desc, correct, source, w, image, anchor, ct, at, rt, rn)

# ============ 线索分级权重（P3.1：把设计的「线索等级」在运行时落地）============
# 设计依据：00_核心设计思路.md §2.2 权重表（关键10/重要5/一般2/其他0/误导0-不扣分）。
# .tres 目录里的 importance 字段已按此口径写入（实测取值 10/5/4/3/2），故权重直取 importance；
# scene4-8 无 .tres，权重由场景内联表 "w" 字段提供（经 inline_weight 传入）。

## 计算一条线索的权重：
## - 误导项（correct==false）恒为 0（不计分、不扣分，符合设计）；
## - 有目录定义 → 取 importance（作者权威值）；
## - 无目录（内联线索）→ 用 inline_weight，缺省回退 2（一般）。
func weight_of(id: String, correct: bool, inline_weight: int = -1) -> int:
	if not correct:
		return 0
	var def = get_clue_definition(id)
	if def != null:
		return int(def.importance)
	return inline_weight if inline_weight >= 0 else 2

## 权重 → 等级中文标签（仅展示用，不参与计算）
func tier_label(weight: int, correct: bool) -> String:
	if not correct:
		return "误导"
	if weight >= 10:
		return "关键"
	if weight >= 4:
		return "重要"
	if weight >= 2:
		return "一般"
	return "其他"

## 已收集线索的权重合计（可按 source 过滤）——观察力加权评分的数据源
func total_weight(source: String = "") -> int:
	var sum := 0
	for c in collected_clues:
		if source == "" or c.get("source", "") == source:
			sum += int(c.get("weight", 0))
	return sum

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
	case_wall_state = {}

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
