extends Node

## ToolSystem — 侦破工具系统（P2-5）
## 管理工具栏与「工具×物品」组合发现；复用 SceneEventBus.tool_used 驱动发现，避免平行实现。
## 设计基准：08_系统框架设计.md §3.7（D-22.1.11）

const TOOLS := {
	"magnifier":  {"name": "放大镜",     "icon": "🔍"},
	"tape":       {"name": "卷尺",       "icon": "📏"},
	"directory":  {"name": "黄页",       "icon": "📖"},
	"newspaper":  {"name": "报纸",       "icon": "📰"},
	"handcuffs":  {"name": "手铐",       "icon": "🔗"},
	"rope":       {"name": "绳索",       "icon": "🪢"},
	"chemistry":  {"name": "化学试剂盒", "icon": "🧪"},
	"plaster":    {"name": "石膏粉",     "icon": "🏗️"},
}

# 初始解锁（与 08 文档一致：放大镜/卷尺/黄页 + 手铐/绳索）
var unlocked_tools: Array = ["magnifier", "tape", "directory", "handcuffs", "rope"]
var selected_tool: String = ""
# 组合规则：键 "tool+target" -> 发现结果文本（seed，可由案件数据 register_case_combinations 扩充）
var combinations: Dictionary = {}

func _ready() -> void:
	_seed_combinations()
	if SceneEventBus:
		SceneEventBus.tool_used.connect(_on_tool_used)

func _seed_combinations() -> void:
	combinations = {
		"magnifier+blood":   "发现血型信息：AB型，Rh阴性",
		"magnifier+fiber":   "发现衣物纤维：与嫌疑人外套吻合",
		"tape+footprint":    "推断身高范围：约1.75–1.80米",
		"chemistry+pill":    "检出生物碱：疑似番木鳖碱（士的宁）",
		"plaster+footprint": "石膏翻模完成，可比对鞋底花纹",
		"handcuffs+suspect": "嫌疑人已被制服",
		"directory+name":    "查得住址与职业信息",
		"newspaper+article": "发现同期悬赏启事，暗合案情",
	}

## 案件级组合规则合并（未来由案件 .tres 提供）
func register_case_combinations(rules: Dictionary) -> void:
	for k in rules.keys():
		combinations[k] = rules[k]

func select_tool(tool_id: String) -> void:
	if tool_id in unlocked_tools:
		selected_tool = tool_id
		if UIEventBus:
			UIEventBus.emit_signal("tool_selected", tool_id)

func unlock_tool(tool_id: String) -> void:
	if not (tool_id in unlocked_tools):
		unlocked_tools.append(tool_id)

func is_unlocked(tool_id: String) -> bool:
	return tool_id in unlocked_tools

## 使用工具于目标，返回组合发现结果（空串表示无新发现）
func use_tool_on(tool_id: String, target_id: String) -> String:
	var key := "%s+%s" % [tool_id, target_id]
	var result: String = combinations.get(key, "")
	if UIEventBus:
		UIEventBus.emit_signal("tool_used", tool_id, target_id)
	if result != "" and UIEventBus:
		UIEventBus.emit_signal("tool_discovery_triggered", tool_id, target_id, result)
	return result

## 返回某线索对某道具的「关联 reveal」（图片/测量/黄页登记等富数据）。
## 当前没有结构化的 reveal 数据，统一返回空字典，由调用方（ToolBar）
## 回退到 use_tool_on 组合表或通用兜底，避免 Invalid call 运行时崩溃。
## 后续若案件数据提供 reveal（如 {"kind":"image","image":...,"anchor":...}），
## 在此按 clue_id+tool_id 查表返回即可，ToolBar 的 image/measure 分支会自动生效。
func get_clue_tool_reveal(clue_id: String, tool_id: String) -> Dictionary:
	return {}

func _on_tool_used(tool_name: String, target_id: String = "") -> void:
	# 来自 UI（tool_bar）的触发，用当前选中工具或传入工具名驱动发现
	var tid := selected_tool if selected_tool != "" else tool_name
	use_tool_on(tid, target_id)

func get_persistent_state() -> Dictionary:
	return {"unlocked": unlocked_tools.duplicate(), "selected": selected_tool}

func restore_state(data: Dictionary) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("unlocked") and typeof(data["unlocked"]) == TYPE_ARRAY:
			unlocked_tools = data["unlocked"].duplicate()
		if data.has("selected"):
			selected_tool = data["selected"]
