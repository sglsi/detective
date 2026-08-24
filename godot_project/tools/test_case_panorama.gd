extends SceneTree
## 全案平铺（case_wide）回归（2026-08）：
##  1) case_wide 下把全部已收集线索作为节点平铺（非焦点人物线索也显示）
##  2) 全部人物作为 person 根节点分组
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

	# 1) 全部线索作为节点平铺
	for c in clues:
		var cid = c["id"]
		_chk(gv._node_views.has(cid),
			"线索 %s 已平铺为节点 (实得 %d)" % [cid, gv._node_views.size()])

	# 2) 全部人物作为 person 根节点分组
	var person_ids := [] as Array
	for id in gv._node_kind:
		if gv._node_kind[id] == "person":
			person_ids.append(id)
	_chk(person_ids.size() >= 2, "多人物分组平铺（含 %d 个人物节点: %s）" % [person_ids.size(), str(person_ids)])

	# 3) 关联未来线索也显示（无关联线索 c4 也应平铺展示，作为可后续布设的孤立节点）
	_chk(gv._node_views.has("c4"), "孤立线索 c4 也平铺展示（供后续布设）")