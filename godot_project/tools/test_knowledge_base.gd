extends SceneTree

## 单测：KnowledgeBaseSystem 推理知识库（对齐《04_推理知识库.md》重新设计）
## 覆盖：检索排序+难度差异化、域对齐(KB-C=化学毒物)、子主题浏览、交叉引用、收藏(MVP新增)、笔记兼容
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var kb = root.get_node_or_null("/root/KnowledgeBaseSystem")
	if not kb:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	# 1. 检索"马车"应命中，且首位 domain 为 KB-B 或 KB-G（验证域对齐核心修复：马车不再错归 KB-C）
	var r1 = kb.search("马车", 1)
	if r1.is_empty():
		ok = false; reason = "检索'马车'应非空"
	else:
		var d1: String = r1[0]["entry"].get("domain", "")
		if d1 != "KB-B" and d1 != "KB-G":
			ok = false; reason = "马车应归 KB-B/KB-G，实得 %s" % d1

	# 2. 难度 HARD(2) 仅精确匹配标题+关键词，仍应命中"马车"
	var r2 = kb.search("马车", 2)
	if r2.is_empty():
		ok = false; reason = "HARD 检索'马车'应仍命中（标题/关键词）"

	# 3. 未知词返回空
	if not kb.search("zzzqqq", 1).is_empty():
		ok = false; reason = "未知词应返回空"

	# 4. 域浏览 KB-C 必须是化学毒物（验证设计文档 KB-C=CHEMICAL_POISON 对齐）
	var dom = kb.browse_domain("KB-C")
	if dom.is_empty():
		ok = false; reason = "browse_domain KB-C 应非空"
	else:
		var t: String = dom[0].get("title", "")
		if not ("生物碱" in t or "毒物" in t or "剂量" in t or "检测" in t):
			ok = false; reason = "KB-C 应为化学毒物相关，实得 %s" % t

	# 5. 子主题浏览（fallback 与 JSON 均含 subdomain=生物碱）
	var sub = kb.browse_subdomain("KB-C", "生物碱")
	if sub.is_empty():
		ok = false; reason = "browse_subdomain KB-C/生物碱 应非空"

	# 6. 交叉引用（仅当 JSON 数据加载、KB-C-1 存在时校验）
	var e = kb.get_entry("KB-C-1")
	if not e.is_empty():
		var rel = kb.get_related("KB-C-1")
		if rel.is_empty():
			ok = false; reason = "KB-C-1 应有交叉引用 related"
	else:
		# 仅 fallback 种子时跳过（fallback 无 related），功能本身不报错即可
		pass

	# 7. 收藏（MVP 必做，原实现缺失）
	kb.add_favorite("KB-C-1")
	if not kb.is_favorite("KB-C-1"):
		ok = false; reason = "add_favorite 后 is_favorite 应 true"
	if kb.get_favorites().size() != 1:
		ok = false; reason = "get_favorites 应=1"
	var toggled = kb.toggle_favorite("KB-C-1")
	if toggled != false:
		ok = false; reason = "toggle_favorite 应取消收藏并返回 false"
	if kb.is_favorite("KB-C-1"):
		ok = false; reason = "toggle 后 is_favorite 应为 false"

	# 8. 基础笔记兼容
	kb.add_note("KB-C-1", "士的宁致死量极小")
	if kb.get_notes().size() < 1:
		ok = false; reason = "笔记数应>=1"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()
