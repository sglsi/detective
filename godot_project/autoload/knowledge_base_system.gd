extends Node

## KnowledgeBaseSystem — 推理知识库（P2-3）
## 7大主题域全量开放；关键词检索（标题×3>关键词×2>正文×1）、分类浏览、随机翻阅、基础笔记。
## 难度差异化：困难模式仅精确匹配（标题+关键词），不模糊匹配正文。
## MVP：内置 seed 数据集 + 可选 res://data/knowledge/knowledge_base.json 合并。
## 设计基准：04_推理知识库.md / 09审核报告 P1-2

const DOMAINS := {
	"KB-A": "维多利亚时代社会与阶层",
	"KB-B": "伦敦地理与城市环境",
	"KB-C": "交通工具与行程计算",
	"KB-D": "法医学与痕迹检验",
	"KB-E": "化学与毒理学",
	"KB-F": "科学与自然现象",
	"KB-G": "侦探方法论与推理技巧",
}

# seed 数据：每域一条，供立即可用与单测；后续由内容/美术扩充
const SEED_ENTRIES := [
	{"id": "kb_society", "domain": "KB-A", "title": "维多利亚时代社会阶层", "keywords": ["阶层", "贵族", "中产", "工人"], "body": "维多利亚时代社会分层明显，贵族、中产阶级与劳工阶层在生活、着装与言行上有显著差异，是判断嫌疑人身份的重要背景。"},
	{"id": "kb_london", "domain": "KB-B", "title": "伦敦城市环境与雾", "keywords": ["伦敦", "雾", "街道", "煤气灯"], "body": "19世纪伦敦常被煤烟浓雾笼罩，能见度低，街道以煤气灯照明，对夜间观察与痕迹保存有直接影响。"},
	{"id": "kb_transport", "domain": "KB-C", "title": "各类马车轮距与速度", "keywords": ["马车", "轮距", "速度", "行程"], "body": "不同用途马车轮距范围不同（如四轮轿式车约4.5英尺），结合城市平均速度可估算行程时间，是推断到达时刻的依据。"},
	{"id": "kb_forensic", "domain": "KB-D", "title": "血迹形态与血型", "keywords": ["血迹", "血型", "痕迹", "纤维"], "body": "血迹形态可推断受力方向与姿势；血型（ABO/Rh）能通过试剂初步判定，是锁定嫌疑人的关键物证。"},
	{"id": "kb_chem", "domain": "KB-E", "title": "常见毒物与检测", "keywords": ["毒物", "士的宁", "生物碱", "试剂"], "body": "植物源生物碱（如番木鳖碱/士的宁）微量即可致死，苦杏仁味提示氰化物，化学试剂盒可初步显色检测。"},
	{"id": "kb_science", "domain": "KB-F", "title": "足迹与身高的关系", "keywords": ["足迹", "身高", "步幅", "推算"], "body": "成年人身高约为步幅的一定倍数，结合足迹长度可估算嫌疑人身高范围，但不同文献比例略有差异。"},
	{"id": "kb_method", "domain": "KB-G", "title": "演绎法与溯因推理", "keywords": ["演绎", "归纳", "溯因", "福尔摩斯"], "body": "福尔摩斯式推理以观察为起点，通过排除不可能的假设（溯因）逼近真相，强调证据链而非直觉。"},
]

var entries: Array = []
var notes: Array = []   # {entry_id, text}

func _ready() -> void:
	entries = SEED_ENTRIES.duplicate()
	_load_external()

func _load_external() -> void:
	var path := "res://data/knowledge/knowledge_base.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_ARRAY:
		for e in parsed:
			if typeof(e) == TYPE_DICTIONARY:
				entries.append(e)

## 检索：返回排序后的条目（score 降序）
func search(query: String, difficulty: int = 1) -> Array:
	var q := query.strip_edges().to_lower()
	if q == "":
		return []
	var hard := (difficulty == 2)   # DifficultyManager.HARD = 2
	var results := []
	for e in entries:
		var score := 0
		var title: String = e.get("title", "")
		var body: String = e.get("body", "")
		var kws: Array = e.get("keywords", [])
		if q in title.to_lower():
			score += 3
		for k in kws:
			if q in str(k).to_lower():
				score += 2
		if not hard and q in body.to_lower():
			score += 1
		if score > 0:
			results.append({"entry": e, "score": score})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results

func browse_domain(domain_id: String) -> Array:
	var out := []
	for e in entries:
		if e.get("domain", "") == domain_id:
			out.append(e)
	return out

func get_entry(id: String) -> Dictionary:
	for e in entries:
		if e.get("id", "") == id:
			return e
	return {}

func random_entry() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[randi() % entries.size()]

func add_note(entry_id: String, text: String) -> void:
	notes.append({"entry_id": entry_id, "text": text})
	if SystemEventBus:
		SystemEventBus.emit_signal("knowledge_updated", entry_id, notes.size())

func get_notes() -> Array:
	return notes.duplicate()

func restore_notes(data: Array) -> void:
	if typeof(data) == TYPE_ARRAY:
		notes = data.duplicate()
