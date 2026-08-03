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
		# —— 场景二 花园（garden）——
		"tape+c202": "卷尺测量：轴距约3.8英尺、轮宽约2英寸——典型伦敦出租马车（为钻小巷做得窄）",
		"tape+c205": "卷尺测量：大步子步幅4.5英尺、小步子3.5英尺——两人身高约6英尺与5英尺4英寸",
		"tape+c206": "卷尺测量：步幅约4.5英尺→身高约6英尺（183cm）的大个子",
		"magnifier+c203": "放大镜下：右前蹄铁崭新锐利、其余三蹄磨损——右前蹄最近刚换过",
		"magnifier+c204": "放大镜下：蹄印走向散乱有迂回——马曾无人看管，车夫很可能进了屋",
		# —— 场景三 室内（indoor）——
		"magnifier+c301": "放大镜下：面部肌肉扭曲、瞳孔收缩——那种表情不是一般的死亡",
		"magnifier+c304": "放大镜下：名片「伊诺克·J·德雷伯」与金表刻字、衬衣缩写三重印证",
		"magnifier+c306": "放大镜下：共济会金戒指内侧磨损——佩戴者多为中产及以上",
		"magnifier+c307": "放大镜下：《十日谈》扉页手写「约瑟夫·斯特兰森」——与信件收件人对上",
		"magnifier+c309": "放大镜下：RACHE 笔画边缘有墙粉刮痕——写字人指甲未修剪",
		"magnifier+c310": "放大镜下：烟灰深黑薄片状——印度雪茄特征，非普通纸烟",
		"magnifier+d1_top": "放大镜下：墙角旧木陀螺刻花、漆皮剥落——空屋曾住过一家人",
		"tape+c309": "卷尺测量：RACHE 离地约6英尺——书写者身高约6英尺",
		"tape+c311": "卷尺测量：步幅约4.5英尺——与花园发现一致：六英尺高个子、方头靴",
		"chemistry+c302": "化学检验：无外伤+嘴唇暗紫+痛苦死亡→生物碱中毒可能性很大",
		"plaster+c311": "石膏翻模完成：尘土中漆皮靴+方头靴两枚脚印，可比对鞋底花纹",
		"directory+c304": "黄页查址：名片「克利夫兰」→ 德雷伯旅英下落可追溯",
		"directory+c308": "黄页溯源：礼帽内衬商标指向伦敦帽店，锁定死者落脚点",
		"newspaper+c307": "据《十日谈》题字登报协查：斯特兰森身份可经报社确认",
		# —— 场景七 旅馆（scene7）——
		"chemistry+C_SOTCB_704": "化学检验：木匣灰色半透明药丸味苦，含生物碱剧毒",
		"chemistry+C_SOTCB_705": "化学实验：两粒药丸一毒一无毒——凶手的「上帝裁决」式选择",
		"plaster+C_SOTCB_703": "石膏翻模：窗台湿脚印，确认凶手翻窗进出、不走正门",
		"magnifier+C_SOTCB_702": "放大镜下：脸上 RACHE 字迹与第一案墙上相似——两案共同铁证",
		"directory+C_SOTCB_706": "黄页/电报核查：J.H.现欧洲——J.H.=杰弗森·霍普？",
		"rope+C_SOTCB_703": "绳索痕迹：窗沿摩擦痕显示凶手以绳类固定身体翻窗而下",
		# —— 通用兜底（命中即给通用发现）——
		"handcuffs+suspect": "嫌疑人已被制服",
		"plaster+footprint": "石膏翻模完成，可比对鞋底花纹",
		"directory+name": "查得住址与职业信息",
		"newspaper+article": "发现同期悬赏启事，暗合案情",
	}

## 工具 id → 中文名（用于匹配热点数据里的 "tool" 中文标签，如 "放大镜"/"卷尺"）
func tool_cn_name(tool_id: String) -> String:
	match tool_id:
		"magnifier": return "放大镜"
		"tape": return "卷尺"
		"chemistry": return "化学试剂盒"
		"directory": return "黄页"
		"handcuffs": return "手铐"
		"rope": return "绳索"
		"newspaper": return "报纸"
		"plaster": return "石膏粉"
	return ""

## 仅查询是否存在 tool+clue 组合（不触发信号，供工具栏高亮判定用）
func has_combination(tool_id: String, clue_id: String) -> bool:
	return combinations.has("%s+%s" % [tool_id, clue_id])

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
