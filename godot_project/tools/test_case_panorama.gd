extends SceneTree
## 全案平铺（case_wide）回归（2026-08，2026-xx 修订）：
##  1) 全部人物作为 person 根节点分组平铺（保留上轮「按人物分组平铺」设计）
##  2) 线索【默认放左侧已收集线索栏，不放画布】：case_wide 下未放置线索不进画布，
##     仅已放置（拖入/建边，见 _placed_clues）的线索作为图谱节点（本轮新需求）
##  3) 已建立联系可折叠
## 运行：godot --headless --path . --script res://tools/test_case_panorama.gd

var _pass := 0
var _fail := 0

func _initialize() -> void:
	await _run()
	print("--- CASE_PANORAMA done pass=%d fail=%d ---" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)

func _run() -> void:
	var clues := [
		{"id": "c1", "name": "车轮印", "desc": "窄轮距马车", "correct": true, "related_npcs": ["P_A"]},
		{"id": "c2", "name": "身高特征", "desc": "凶手高大", "correct": true, "related_npcs": ["P_B"]},
		{"id": "c3", "name": "烟蒂", "desc": "三级烟", "correct": true, "related_npcs": ["P_A"]},
		{"id": "c4", "name": "怀表", "desc": "刻字", "correct": true, "related_npcs": []},
	]
	var hypo := {"title": "测试假设", "battlefield": {"hypotheses": [{"id": "H1", "text": "马车夫作案"}]}}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW"
	root.add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), {}, Callable(), true, -1, Callable(), true)
	await process_frame
	await process_frame
	var gv = wall._graph_view
	_chk(gv != null and is_instance_valid(gv), "图谱视图已构建")
	_chk(gv._case_wide, "case_wide 标记已开启 (实得 %s)" % gv._case_wide)

	# 1) 人物分组平铺保留；线索【默认放左栏不进画布】：
	#    case_wide 下未放置线索不作为图谱节点（本轮新需求：线索默认放左侧已收集线索栏）
	_chk(not gv._node_views.has("c1"), "线索 c1 默认放左栏，不进画布")
	_chk(not gv._node_views.has("c2"), "线索 c2 默认放左栏，不进画布")
	_chk(not gv._node_views.has("c3"), "线索 c3 默认放左栏，不进画布")
	_chk(gv._placed_clues.is_empty(), "首次开墙 _placed_clues 为空（线索全在左栏）")

	# 2) 全部人物作为 person 根节点分组
	var person_ids := [] as Array
	for id in gv._node_kind:
		if gv._node_kind[id] == "person":
			person_ids.append(id)
	_chk(person_ids.size() >= 2, "多人物分组平铺（含 %d 个人物节点: %s）" % [person_ids.size(), str(person_ids)])

	# 3) 孤立线索 c4 同样默认放左栏不在画布（供玩家后续拖入布设）
	_chk(not gv._node_views.has("c4"), "孤立线索 c4 默认放左栏，不进画布")

	# 4) 问题3: 自定义推断+线索建立联系后，折叠推断应能同时隐藏其线索（不只藏线）
	gv.add_text_node("hypo")
	var fol = null
	for id in gv._node_views:
		if id.begins_with("note_hypo"):
			fol = id
			break
	_chk(fol != null, "已新增自定义推断 %s" % (str(fol) if fol != null else ""))
	gv.add_text_node("clue")
	var targ = ""
	for id in gv._node_views:
		if id.begins_with("note_clue"):
			targ = id
			break
	_chk(targ != "", "已新增自定义线索 %s" % targ)
	if fol != null and targ != "":
		gv._edge._add_edge(fol, targ, "support", "green", false)
	await process_frame
	await process_frame
	_chk(gv._node_views.has(targ), "线索 %s 已出现在画布（建边前）" % targ)
	var ok_fold: bool = gv.toggle_fold(fol)
	await process_frame
	await process_frame
	var hidden: Dictionary = gv._fold._compute_hidden()
	_chk(ok_fold and (hidden.has(targ) or not gv._node_views.has(targ)),
		"折叠推断后线索 %s 被隐藏 okfold=%s cnt=%d" % [targ, ok_fold, hidden.size()])