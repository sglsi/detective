extends SceneTree

## 单测：KnowledgeBaseSystem 推理知识库（检索排序 + 难度差异化 + 浏览）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	if not KnowledgeBaseSystem:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	# 普通模式：检索"马车"应命中 kb_transport（标题+关键词+正文均含）
	var r1 := KnowledgeBaseSystem.search("马车", 1)
	if r1.is_empty():
		ok = false; reason = "普通模式检索'马车'应非空"
	elif r1[0]["entry"].get("id", "") != "kb_transport":
		ok = false; reason = "首位应为 kb_transport，实得 %s" % r1[0]["entry"].get("id", "")

	# 困难模式：仍应命中（标题/关键词精确匹配）
	var r2 := KnowledgeBaseSystem.search("马车", 2)
	if r2.is_empty():
		ok = false; reason = "困难模式检索'马车'应仍命中（标题/关键词）"

	# 未知词返回空
	var r3 := KnowledgeBaseSystem.search("zzzqqq", 1)
	if not r3.is_empty():
		ok = false; reason = "未知词应返回空"

	# 分类浏览
	var dom := KnowledgeBaseSystem.browse_domain("KB-C")
	if dom.is_empty():
		ok = false; reason = "browse_domain KB-C 应非空"
	elif dom[0].get("id", "") != "kb_transport":
		ok = false; reason = "KB-C 首位应为 kb_transport"

	# 单条获取
	var e := KnowledgeBaseSystem.get_entry("kb_chem")
	if e.get("title", "") != "常见毒物与检测":
		ok = false; reason = "get_entry kb_chem 标题不符"

	# 笔记
	KnowledgeBaseSystem.add_note("kb_chem", "士的宁致死量极小")
	if KnowledgeBaseSystem.get_notes().size() != 1:
		ok = false; reason = "笔记数应=1"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()
