extends SceneTree

## 知识库面板 headless 验证：实例化 KnowledgeBasePanel，跑全部交互方法，
## 确认脚本编译通过、UI 方法无 SCRIPT ERROR、且数据正确接入 KnowledgeBaseSystem。
## 注意：--script 模式下 autoload 全局名在编译期不可见，须用 /root/ 节点获取（避免 Identifier not found）。
## 运行：godot --headless --script tools/test_kb_panel.gd

var _pass := 0
var _fail := 0
var _closed := false

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	await create_timer(0.1).timeout
	var kb = root.get_node_or_null("/root/KnowledgeBaseSystem")
	if kb == null:
		_ng("KnowledgeBaseSystem 未注册")
		_print_result()
		return
	if kb.entries.is_empty():
		_ng("知识库条目为空")
		_print_result()
		return
	_ok("知识库系统已加载 %d 条" % kb.entries.size())

	# 实例化面板（add_child 触发 _ready 构建 UI；面板内部自行取 KnowledgeBaseSystem 引用）
	var kbs = load("res://scripts/knowledge/knowledge_base_panel.gd")
	if kbs == null:
		_ng("面板脚本加载失败")
		_print_result()
		return
	var panel = kbs.new()
	root.add_child(panel)
	await create_timer(0.05).timeout

	if panel._right_content == null or panel._search_input == null:
		_ng("面板 UI 构建缺失")
		_print_result()
		return
	_ok("面板实例化 + UI 构建成功")

	# 默认浏览全部
	if panel._right_content.get_child_count() <= 0:
		_ng("默认浏览未渲染条目")
	else:
		_ok("默认浏览渲染 %d 张卡片" % panel._right_content.get_child_count())

	# 域浏览 KB-C
	panel._show_browse("KB-C")
	await create_timer(0.02).timeout
	if panel._right_content.get_child_count() <= 0:
		_ng("KB-C 域浏览未渲染")
	else:
		_ok("KB-C 域浏览渲染 %d 张" % panel._right_content.get_child_count())

	# 子主题浏览
	panel._show_browse("KB-C", "生物碱")
	await create_timer(0.02).timeout
	_ok("子主题浏览执行无异常")

	# 检索
	panel._search_input.text = "马车"
	panel._on_search()
	await create_timer(0.02).timeout
	if panel._right_content.get_child_count() <= 0:
		_ng("检索「马车」无结果渲染")
	else:
		_ok("检索「马车」渲染 %d 张" % panel._right_content.get_child_count())

	# 详情视图
	var first_id: String = ""
	for e in kb.entries:
		first_id = e.get("id", "")
		break
	panel._show_detail(first_id)
	await create_timer(0.02).timeout
	if panel._right_content.get_child_count() <= 0:
		_ng("详情视图未渲染")
	else:
		_ok("详情视图渲染（正文/收藏/笔记）")

	# 收藏切换
	var before: bool = kb.is_favorite(first_id)
	panel._on_toggle_fav(first_id)
	await create_timer(0.02).timeout
	var after: bool = kb.is_favorite(first_id)
	if before == after:
		_ng("收藏切换无效 (before=%s after=%s)" % [before, after])
	else:
		_ok("收藏切换生效 (%s → %s)" % [before, after])

	# 收藏夹视图
	panel._on_favorites()
	await create_timer(0.02).timeout
	_ok("收藏夹视图执行无异常")

	# 笔记增删
	var fake := LineEdit.new()
	fake.text = "测试笔记：马车印宽可推断车型"
	panel._on_add_note(first_id, fake)
	await create_timer(0.02).timeout
	var notes: Array = kb.get_notes()
	var found := false
	for n in notes:
		if n.get("entry_id", "") == first_id and "马车印宽" in str(n.get("text", "")):
			found = true
	if not found:
		_ng("笔记未写入知识库")
	else:
		_ok("笔记写入成功（%d 条）" % notes.size())

	# 交叉引用详情
	var rel_tested := false
	for e in kb.entries:
		var rel: Array = kb.get_related(e.get("id", ""))
		if not rel.is_empty():
			panel._show_detail(e.get("id", ""))
			await create_timer(0.02).timeout
			rel_tested = true
			break
	if rel_tested:
		_ok("交叉引用详情视图执行无异常")
	else:
		_ok("无交叉引用条目（跳过 related 测试）")

	# 随机翻阅
	panel._on_random()
	await create_timer(0.02).timeout
	_ok("随机翻阅执行无异常")

	# 关闭信号
	_closed = false
	panel.close_requested.connect(_mark_closed)
	panel.close_requested.emit()
	await create_timer(0.02).timeout
	if not _closed:
		_ng("close_requested 信号未触发")
	else:
		_ok("close_requested 信号正常")

	_print_result()

func _ok(msg: String) -> void:
	_pass += 1
	print("[PASS] " + msg)

func _mark_closed() -> void:
	_closed = true

func _ng(msg: String) -> void:
	_fail += 1
	print("[FAIL] " + msg)

func _print_result() -> void:
	print("=== 知识库面板 P1_RESULT: %s ===" % ("PASS" if _fail == 0 else "FAIL"))
	print("PASS=%d FAIL=%d" % [_pass, _fail])
	quit()
