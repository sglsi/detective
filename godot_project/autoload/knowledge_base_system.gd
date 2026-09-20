extends Node

## KnowledgeBaseSystem — 推理知识库（按《04_推理知识库.md》v3.2 重新设计）
##
## 定位：维多利亚时代侦探百科全书（通用背景知识，不绑定具体案件）。
## 12 大主题域：KB-A~G（案件背景，见《04_推理知识库.md》）+ KB-H~L（侦探学方法论，见《05_侦探学方法论知识库.md》）。
## MVP 必做：关键词检索(多关键词/模糊/相关度排序)、分类浏览(域→子主题→条目)、
##         随机翻阅、基础笔记(add_note)、条目收藏(favorite)、难度差异化检索。
## M2+ 数据结构：交叉引用(related)、标注高亮/自定义分类/条目关联/笔记导出/推理墙联动（数据结构预留）。
##
## 数据来源（三层，逐级兜底）：
##   ① 内置基线 res://data/knowledge/knowledge_base.json（随 pck 打包，离线兜底）
##   ② 远端按域文件 /kb/KB-*.json + /kb/manifest.json（同源静态，**可随时更新而无需重导出 pck**）
##   ③ FALLBACK_SEED（7 域各 1 条），保证系统始终可用
## 远端内容按玩家查阅需求「按域」拉取，并缓存到 user://kb_cache，命中 hash 则直接复用。
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
	# ---- 侦探学方法论扩展域（05_侦探学方法论知识库.md，以 19 世纪真实著作为据）----
	"KB-H": {"enum": "INVESTIGATION_SYSTEM", "name": "侦查学总纲与现场勘查", "subdomains": ["侦查员素养", "现场勘查程序", "物证采集", "专家协作", "讯问与证词心理"]},
	"KB-I": {"enum": "IDENTIFICATION", "name": "身份识别技术", "subdomains": ["指纹学", "人体测量", "罪犯档案", "语言肖像"]},
	"KB-J": {"enum": "CRIMINOLOGY_THEORY", "name": "犯罪学理论与时代观念", "subdomains": ["天生犯罪人", "犯罪类型学", "面相与颅相", "实证犯罪学"]},
	"KB-K": {"enum": "DETECTIVE_PROFESSION", "name": "侦探职业与警务实务", "subdomains": ["机构沿革", "侦探培养", "罪犯图册与情报", "私家侦探", "审讯手段"]},
	"KB-L": {"enum": "FORENSIC_MEDICINE", "name": "法医学与尸体检验", "subdomains": ["死亡与尸检", "创伤与枪伤", "中毒与检测", "身份鉴定", "法医出庭"]},
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
	# 内置基线已就绪（离线兜底）；远端 manifest 与按域内容按需拉取（见「远程知识库」）。
	call_deferred("_bootstrap_remote")

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

## ---------- 远程知识库（外部化：按域按需拉取 + user:// 缓存）----------
## 知识库作为「独立可更新部分」：服务器托管 /kb/manifest.json + /kb/KB-*.json，
## 客户端在玩家查阅时按域拉取。改知识库只需刷新远端文件 + manifest 版本号，
## 无需重导出 pck、无需玩家重下整包；拉取失败一律回落内置基线，功能不受影响。

const KB_REMOTE_PATH := "/kb/"
## 桌面/编辑器环境下的远端基地址（Web 构建自动使用页面同源 origin）。
## 可用项目设置 knowledge/remote_base 覆盖；置为空字符串即可彻底关闭远端同步。
const KB_DEFAULT_REMOTE_BASE := "http://127.0.0.1:8081"
const KB_TIMEOUT := 12.0
const KB_CACHE_DIR := "user://kb_cache"

signal kb_manifest_updated(version: String, ok: bool)
signal kb_domain_loaded(domain_id: String, ok: bool)

## 远端 manifest（{version, domains:[{id,name,file,count,hash}]}）；空表示尚未取得
var manifest: Dictionary = {}
var _manifest_version: String = ""
var _fresh_domains: Dictionary = {}   # domain_id -> true（本次会话已并入最新数据）
var _remote_ready: bool = false       # manifest 已取得
var _remote_failed: bool = false      # 本会话已判定远端不可用（不再重试）

func _bootstrap_remote() -> void:
	# 启动仅探测 manifest（1 个小请求）；各域正文留待玩家查阅时按需拉取。
	await refresh_manifest()

## 拉取/刷新远端 manifest。成功返回 true；远端不可用返回 false（改用内置基线）。
func refresh_manifest(force: bool = false) -> bool:
	if _remote_ready and not force:
		return true
	if _remote_failed and not force:
		return false
	var res: Dictionary = await _kb_http_get("manifest.json")
	if res.get("ok", false) and typeof(res.get("data", null)) == TYPE_DICTIONARY:
		var m: Dictionary = res.get("data", {})
		if m.has("domains"):
			manifest = m
			_manifest_version = str(m.get("version", ""))
			_remote_ready = true
			_remote_failed = false
			_write_cache_file("manifest.json", JSON.stringify(m))
			kb_manifest_updated.emit(_manifest_version, true)
			return true
	_remote_failed = true
	kb_manifest_updated.emit("", false)
	# 控制台诊断（便于排查「百科显示的不是最新内容」）：远端不可用时一律回落内置基线快照。
	print("[KnowledgeBase] 远端知识库不可用：%s%s 拉取失败 → 使用内置基线快照。"
		% [_remote_base_desc(), KB_REMOTE_PATH]
		+ "请确认静态服务已提供 /kb/* 路由（旧版 serve_web.py 需重启为新版本）。")
	return false

## 当前实际使用的远端基地址（仅用于诊断输出）
func _remote_base_desc() -> String:
	if OS.has_feature("web"):
		var cfg: Node = get_node_or_null("/root/APIConfig")
		if cfg != null and cfg.has_method("get_base_url"):
			var o: String = str(cfg.get_base_url())
			return o if o != "" else "(页面同源)"
		return "(页面同源)"
	return str(ProjectSettings.get_setting("knowledge/remote_base", KB_DEFAULT_REMOTE_BASE))

## 确保某域为最新内容（玩家查阅该域时调用）。可 await；返回是否成功并入远端内容。
func ensure_domain(domain_id: String) -> bool:
	if domain_id == "":
		return false
	if _fresh_domains.has(domain_id):
		return true
	var ok: bool = await refresh_manifest()
	if not ok:
		return false
	var info: Dictionary = _manifest_domain_info(domain_id)
	if info.is_empty():
		_fresh_domains[domain_id] = true   # manifest 未收录该域 → 以内置基线为准
		return false
	var want_hash: String = str(info.get("hash", ""))
	# ① 缓存命中（hash 一致）→ 直接复用，零流量
	var cached: Array = _read_cached_domain(domain_id, want_hash)
	if not cached.is_empty():
		_merge_domain(domain_id, cached)
		_fresh_domains[domain_id] = true
		kb_domain_loaded.emit(domain_id, true)
		return true
	# ② 远端拉取
	var res: Dictionary = await _kb_http_get(str(info.get("file", domain_id + ".json")))
	if res.get("ok", false) and typeof(res.get("data", null)) == TYPE_ARRAY:
		var arr: Array = res.get("data", [])
		if _merge_domain(domain_id, arr):
			_write_cache_file(domain_id + ".json",
				JSON.stringify({"hash": want_hash, "version": _manifest_version, "entries": arr}))
			_fresh_domains[domain_id] = true
			kb_domain_loaded.emit(domain_id, true)
			return true
	kb_domain_loaded.emit(domain_id, false)
	return false

## 确保全部域为最新（玩家打开百科总览时调用）。逐域批式拉取。
func ensure_all_domains() -> bool:
	var any_ok: bool = false
	for dom_id in DOMAINS.keys():
		var ok: bool = await ensure_domain(str(dom_id))
		any_ok = any_ok or ok
	return any_ok

## 丢弃远端状态、回到内置基线（供「刷新知识库」入口使用）。
func reset_to_baseline() -> void:
	_fresh_domains.clear()
	manifest = {}
	_manifest_version = ""
	_remote_ready = false
	_remote_failed = false
	entries = []
	_load_external()
	if entries.is_empty():
		entries = FALLBACK_SEED.duplicate()

func is_remote_active() -> bool:
	return _remote_ready

func manifest_version() -> String:
	return _manifest_version

func _manifest_domain_info(domain_id: String) -> Dictionary:
	var arr: Array = manifest.get("domains", [])
	for d in arr:
		if d is Dictionary and str(d.get("id", "")) == domain_id:
			return d
	return {}

## 用 arr 替换 entries 中该域的全部条目（保持域序与域内稳定序）。
func _merge_domain(domain_id: String, arr: Array) -> bool:
	if arr.is_empty():
		return false
	var kept: Array = []
	for e in entries:
		if not (e is Dictionary) or str(e.get("domain", "")) != domain_id:
			kept.append(e)
	for e in arr:
		if e is Dictionary and str(e.get("domain", "")) == domain_id:
			kept.append(e)
	entries = kept
	_reorder_entries()
	return true

## 按 DOMAINS 键序重排 entries（域内保持既有相对顺序），使总览列表顺序稳定。
func _reorder_entries() -> void:
	var buckets: Dictionary = {}
	for e in entries:
		var d: String = str(e.get("domain", ""))
		if not buckets.has(d):
			buckets[d] = []
		buckets[d].append(e)
	var out: Array = []
	for k in DOMAINS.keys():
		if buckets.has(k):
			out.append_array(buckets[k])
			buckets.erase(k)
	for k in buckets.keys():
		out.append_array(buckets[k])
	entries = out

## ---------- 缓存 I/O ----------

func _cache_path(name: String) -> String:
	return KB_CACHE_DIR + "/" + name

func _write_cache_file(name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(KB_CACHE_DIR)
	var f := FileAccess.open(_cache_path(name), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

func _read_cached_domain(domain_id: String, want_hash: String) -> Array:
	if want_hash == "":
		return []
	var p: String = _cache_path(domain_id + ".json")
	if not FileAccess.file_exists(p):
		return []
	var f := FileAccess.open(p, FileAccess.READ)
	if not f:
		return []
	var txt: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	if str(parsed.get("hash", "")) != want_hash:
		return []
	var arr = parsed.get("entries", null)
	if typeof(arr) != TYPE_ARRAY:
		return []
	return arr

## ---------- 网络 ----------

## 取得 /kb/<rel>，返回 {ok, data}。Web 用浏览器 fetch（同源），桌面/编辑器用
## HTTPRequest（指向本地静态服务）。任何失败都只是回落内置基线。
func _kb_http_get(rel: String) -> Dictionary:
	if OS.has_feature("web"):
		# 动态解析（而非直接引用 autoload 全局名）：避免在 --script / --check-only
		# 等不加载 autoload 的运行模式下触发「Identifier not found」编译错误。
		var cfg: Node = get_node_or_null("/root/APIConfig")
		var origin: String = ""
		if cfg != null and cfg.has_method("get_base_url"):
			origin = str(cfg.get_base_url())
		if origin == "":
			origin = "."
		var url: String = origin + KB_REMOTE_PATH + rel
		var api: Node = get_node_or_null("/root/APIManager")
		if api != null and api.has_method("_web_request"):
			var r: Dictionary = await api._web_request(
				HTTPClient.METHOD_GET, url, PackedStringArray(["Accept: application/json"]), "")
			if not r.get("error", true):
				return {"ok": true, "data": r.get("data", null)}
		return {"ok": false, "data": null}
	var base: String = str(ProjectSettings.get_setting("knowledge/remote_base", KB_DEFAULT_REMOTE_BASE))
	if base == "":
		return {"ok": false, "data": null}
	var http := HTTPRequest.new()
	http.timeout = KB_TIMEOUT
	http.use_threads = true
	add_child(http)
	var err: int = http.request(base + KB_REMOTE_PATH + rel,
		PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET, "")
	if err != OK:
		http.queue_free()
		return {"ok": false, "data": null}
	var res: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	if res.size() < 4:
		return {"ok": false, "data": null}
	var code: int = int(res[1])
	var body: PackedByteArray = res[3]
	if code != 200:
		return {"ok": false, "data": null}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		return {"ok": false, "data": null}
	return {"ok": true, "data": parsed}

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
