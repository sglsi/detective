extends Node

## KnowledgeBaseSystem — 推理知识库（按《04_推理知识库.md》v3.2 重新设计）
##
## 定位：维多利亚时代侦探百科全书（通用背景知识，不绑定具体案件）。
## 7 大主题域（严格对齐设计文档，含系统枚举名）+ 20 子主题 + 约 70 条知识点。
## MVP 必做：关键词检索(多关键词/模糊/相关度排序)、分类浏览(域→子主题→条目)、
##         随机翻阅、基础笔记(add_note)、条目收藏(favorite)、难度差异化检索。
## M2+ 数据结构：交叉引用(related)、标注高亮/自定义分类/条目关联/笔记导出/推理墙联动（数据结构预留）。
##
## 数据来源：优先 res://data/knowledge/knowledge_base.json（22 条结构化，随仓库）；
##          缺失时回退 FALLBACK_SEED（7 域各 1 条），保证系统始终可用。
## 难度：EASY=0 / NORMAL=1 / HARD=2（与 DifficultyManager 枚举一致）。
##   HARD：仅精确匹配标题+关键词，不扫正文；EASY/NORMAL：模糊匹配(标题×3>关键词×2>正文×1)。

# 7 大主题域（domain_id → {枚举名, 显示名, 子主题列表}），严格对应设计文档
const DOMAINS := {
	"KB-A": {"enum": "HUMAN_OBSERVATION", "name": "人体观察与社会身份", "subdomains": ["肤色与热带", "姿态与职业", "纹身文化"]},
	"KB-B": {"enum": "TRANSPORTATION", "name": "交通工具与工程测量", "subdomains": ["马车生态", "人体测量", "足迹分析"]},
	"KB-C": {"enum": "CHEMICAL_POISON", "name": "化学与毒物学", "subdomains": ["生物碱", "中毒症状", "检测技术", "剂量毒性"]},
	"KB-D": {"enum": "LANGUAGE_WRITING", "name": "语言与书写文化", "subdomains": ["德文字体", "印刷手写", "德语词汇"]},
	"KB-E": {"enum": "DETECTION_METHODS", "name": "侦查方法与证词分析", "subdomains": ["证词可靠性", "现场勘查", "行为动机"]},
	"KB-F": {"enum": "SOCIAL_BACKGROUND", "name": "维多利亚时代社会背景", "subdomains": ["警察制度", "社会阶层"]},
	"KB-G": {"enum": "CITY_TRANSPORT", "name": "伦敦城市交通与城市环境", "subdomains": ["交通工具类型", "速度效率", "天气环境", "时段特征"]},
}

# 回退种子：7 域各 1 条代表性条目，保证 JSON 缺失时系统仍可用
const FALLBACK_SEED := [
	{"id": "KB-A-fb", "domain": "KB-A", "subdomain": "肤色与热带", "title": "热带气候与肤色变化", "keywords": ["肤色", "热带", "殖民地"], "summary": "长期热带生活者暴露部位肤色加深，返回英国后需数月恢复。", "body": "长期热带暴露使皮肤产生更多黑色素，但主要在暴露部位；暴露与未暴露交界是判断长期热带生活的重要标志。返回英国后渐恢复，若面部仍深而手腕浅说明近期从热带返回。", "related": [], "tags": ["人体观察"]},
	{"id": "KB-B-fb", "domain": "KB-B", "subdomain": "马车生态", "title": "维多利亚时代伦敦的马车生态", "keywords": ["马车", "轮距", "汉索姆"], "summary": "汉索姆双轮宽约3-4英尺；四轮出租约4-4.5英尺；私人马车通常5英尺以上。", "body": "不同类型马车轮距范围不同，是识别马车类型的重要依据；车轮印宽度与车身设计直接相关。", "related": [], "tags": ["交通工具"]},
	{"id": "KB-C-fb", "domain": "KB-C", "subdomain": "生物碱", "title": "生物碱与植物毒素", "keywords": ["士的宁", "吗啡", "生物碱"], "summary": "士的宁白色结晶味苦，致死约30-100mg，引发痉挛苦笑面容；吗啡抑制呼吸针尖样瞳孔。", "body": "植物源生物碱微量即可致死；化学试剂盒可初步显色检测。", "related": [], "tags": ["毒物学"]},
	{"id": "KB-D-fb", "domain": "KB-D", "subdomain": "德文字体", "title": "德文字体的历史演变", "keywords": ["Fraktur", "拉丁体", "德文"], "summary": "Fraktur为哥特印刷体；真正德国人手写多用圆形拉丁体。", "body": "非母语者通过书籍学德语可能只见过Fraktur印刷体，模仿印刷体写字会暴露非母语身份。", "related": [], "tags": ["语言文化"]},
	{"id": "KB-E-fb", "domain": "KB-E", "subdomain": "证词可靠性", "title": "证人证词的可靠性评估", "keywords": ["证词", "可靠性", "夜间"], "summary": "证词可靠性受观察条件、证人状态、记忆偏差、动机影响。", "body": "独立一致证词更可靠，但独立性难保证；夜间煤气灯照明仅20-30码，颜色细节易失真。", "related": [], "tags": ["侦查方法"]},
	{"id": "KB-F-fb", "domain": "KB-F", "subdomain": "警察制度", "title": "苏格兰场与伦敦警察制度", "keywords": ["苏格兰场", "皮尔", "CID"], "summary": "1829年皮尔建大都市警察；CID 1878年成立；福尔摩斯为咨询侦探非官方。", "body": "19世纪中期侦探靠走访与经验推理，缺乏指纹DNA；福尔摩斯以科学知识补警方之不足。", "related": [], "tags": ["社会背景"]},
	{"id": "KB-G-fb", "domain": "KB-G", "subdomain": "交通工具类型", "title": "维多利亚时代伦敦交通工具类型与特点", "keywords": ["汉索姆", "四轮出租", "铁路"], "summary": "汉索姆双轮2人机动强；四轮出租封闭舒适；公共马车廉价；私人马车上层专属。", "body": "不同交通工具速度与适用场景不同，是估算行程时间、推断到达时刻的依据。", "related": [], "tags": ["城市交通"]},
]

var entries: Array = []
var notes: Array = []          # [{entry_id, text}]
var favorites: Array = []      # [entry_id, ...]

func _ready() -> void:
	_load_external()
	if entries.is_empty():
		entries = FALLBACK_SEED.duplicate()
	else:
		# 保底：确保 7 大域都有内容（开发者改 JSON 误删某域时回补）
		for fb in FALLBACK_SEED:
			var dom: String = fb.get("domain", "")
			var covered: bool = false
			for e in entries:
				if e.get("domain", "") == dom:
					covered = true
					break
			if not covered:
				entries.append(fb.duplicate())

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
		entries = parsed.duplicate()

## ---------- 检索 ----------

## query 支持多关键词（空格分隔）；返回 [{entry, score, summary}]，按 score 降序。
## difficulty: 0=EASY/1=NORMAL 模糊匹配(标题×3>关键词×2>正文×1)；2=HARD 仅精确匹配标题+关键词(不扫正文)。
func search(query: String, difficulty: int = 1) -> Array:
	var q: String = query.strip_edges().to_lower()
	if q == "":
		return []
	var hard: bool = (difficulty >= 2)
	var terms: PackedStringArray = q.split(" ", false)
	var results: Array = []
	for e in entries:
		var score: int = 0
		var title: String = e.get("title", "")
		var title_l: String = title.to_lower()
		var body: String = e.get("body", "")
		var body_l: String = body.to_lower()
		var kws: Array = e.get("keywords", [])
		for t in terms:
			var term: String = t
			if term in title_l:
				score += 3
			for k in kws:
				if term in str(k).to_lower():
					score += 2
			if not hard and term in body_l:
				score += 1
		if score > 0:
			results.append({"entry": e, "score": score, "summary": _summary(e)})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results

## 简单模式联想补全：返回以 prefix 开头的标题/关键词候选
func suggest(prefix: String, _difficulty: int = 0) -> Array:
	var p: String = prefix.strip_edges().to_lower()
	if p == "":
		return []
	var out: Array = []
	var seen: Dictionary = {}
	for e in entries:
		var title: String = e.get("title", "")
		if title.to_lower().begins_with(p) and not seen.has(title):
			seen[title] = true
			out.append(title)
		var kws: Array = e.get("keywords", [])
		for k in kws:
			var ks: String = str(k)
			if ks.to_lower().begins_with(p) and not seen.has(ks):
				seen[ks] = true
				out.append(ks)
	return out

## ---------- 浏览 ----------

func browse_domain(domain_id: String) -> Array:
	var out: Array = []
	for e in entries:
		if e.get("domain", "") == domain_id:
			out.append(e)
	return out

func browse_subdomain(domain_id: String, subdomain: String) -> Array:
	var out: Array = []
	for e in entries:
		if e.get("domain", "") == domain_id and e.get("subdomain", "") == subdomain:
			out.append(e)
	return out

func get_entry(id: String) -> Dictionary:
	for e in entries:
		if e.get("id", "") == id:
			return e
	return {}

func get_related(entry_id: String) -> Array:
	var e: Dictionary = get_entry(entry_id)
	if e.is_empty():
		return []
	var rel: Array = e.get("related", [])
	var out: Array = []
	for rid in rel:
		var re: Dictionary = get_entry(rid)
		if not re.is_empty():
			out.append(re)
	return out

func random_entry() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[randi() % entries.size()]

## ---------- 笔记（MVP 基础笔记）----------

func add_note(entry_id: String, text: String) -> void:
	notes.append({"entry_id": entry_id, "text": text})
	if SystemEventBus:
		SystemEventBus.emit_signal("knowledge_updated", entry_id, notes.size())

func get_notes() -> Array:
	return notes.duplicate()

func restore_notes(data: Array) -> void:
	if typeof(data) == TYPE_ARRAY:
		notes = data.duplicate()

## ---------- 收藏（MVP 必做，原实现缺失）----------

func add_favorite(entry_id: String) -> void:
	if not favorites.has(entry_id):
		favorites.append(entry_id)
		if SystemEventBus:
			SystemEventBus.emit_signal("knowledge_favorite_changed", entry_id, true)

func remove_favorite(entry_id: String) -> void:
	if favorites.has(entry_id):
		favorites.erase(entry_id)
		if SystemEventBus:
			SystemEventBus.emit_signal("knowledge_favorite_changed", entry_id, false)

func toggle_favorite(entry_id: String) -> bool:
	if favorites.has(entry_id):
		remove_favorite(entry_id)
		return false
	add_favorite(entry_id)
	return true

func is_favorite(entry_id: String) -> bool:
	return favorites.has(entry_id)

func get_favorites() -> Array:
	return favorites.duplicate()

func restore_favorites(data: Array) -> void:
	if typeof(data) == TYPE_ARRAY:
		favorites = data.duplicate()

## ---------- 工具 ----------

func _summary(e: Dictionary) -> String:
	var s: String = e.get("summary", "")
	if s != "":
		return s
	var b: String = e.get("body", "")
	if b.length() > 50:
		return b.substr(0, 50) + "…"
	return b

func domain_name(domain_id: String) -> String:
	if DOMAINS.has(domain_id):
		return DOMAINS[domain_id]["name"]
	return domain_id

func domain_enum(domain_id: String) -> String:
	if DOMAINS.has(domain_id):
		return DOMAINS[domain_id]["enum"]
	return ""
