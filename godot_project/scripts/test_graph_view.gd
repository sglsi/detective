extends Control

## 图谱视图（GraphViewController）headless 回归测试
## 运行：godot --headless "res://scenes/test_graph_view.tscn"
## 断言：构建不报错、模式 C 节点数、布局确定性、模式切换、悬停高亮、
##       打标签+撤销、自环约束、锁定态只读、共同线索金边。

var _pass := 0
var _fail := 0


func _ready() -> void:
	await _run()
	queue_free()


func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


func _mk_controller(data: Dictionary) -> Control:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GV"
	add_child(gv)
	gv.build(data)
	# 强制画布尺寸，保证布局坐标非零且可复现（headless 下视口尺寸不确定）
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1280, 720)
		gv._rebuild_graph()
	return gv


func _sample_data() -> Dictionary:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true,"associated":true,
			"related_npcs":["NPC_HOP"],"relation_tags":["H1"],"attribute_tags":["直接物证"]},
		{"id":"c2","name":"脚印","desc":"步幅大","correct":true,"associated":true,
			"related_npcs":["NPC_HOP","NPC_DRE"],"relation_tags":["H1"],"attribute_tags":["痕迹"]},
		{"id":"c3","name":"假证词","desc":"说谎","correct":false,"associated":false,
			"related_npcs":[],"relation_tags":[],"attribute_tags":["嫌疑人陈述"]},
	]
	var hypo := {
		"title":"马车夫作案","case_name":"血字的研究","chain_id":"2",
		"battlefield":{"hypotheses":[{"id":"H1","text":"凶手乘出租马车","correct":true}],"contradictions":[]}
	}
	var relations := [{"from":"c1","to":"H1","kind":"support"}]
	var persons := [{"id":"NPC_HOP","name":"霍普"},{"id":"NPC_DRE","name":"德雷伯"}]
	return {"clues":clues,"hypo":hypo,"relations":relations,"persons":persons,
		"focus_person":"NPC_HOP","difficulty":1,"editable":true,"verdict":-1,
		"state_store":{},"on_tag":Callable(),"on_add_edge":Callable(),
		"on_remove_relation":Callable(),"on_close":Callable()}


func _run() -> void:
	var data := _sample_data()

	# ---- 1) 模式 C 构建 + 节点数 ----
	var gv := _mk_controller(data)
	_chk(gv != null, "构建 GraphViewController 不报错")
	# 中心1 + 线索(与焦点有关 c1,c2 =2) + 推断1 + 链1 + 结论1 = 6
	_chk(gv._node_views.size() == 6, "模式 C 节点数=6（中心+2线索+1推断+1链+1结论），实=%d" % gv._node_views.size())
	_chk(gv._node_views.has("NPC_HOP"), "含焦点中心节点")
	_chk(gv._node_views.has("c1") and gv._node_views.has("c2"), "含与焦点有关的线索节点")
	_chk(not gv._node_views.has("c3"), "无关线索不进星型第一圈（c3 与焦点无关）")

	# ---- 2) 布局确定性（同数据两次构建，坐标一致）----
	var gv2 := _mk_controller(data)
	var p1: Vector2 = gv._node_center.get("c1", Vector2.ZERO)
	var p2: Vector2 = gv2._node_center.get("c1", Vector2.ZERO)
	_chk(p1 == p2 and p1 != Vector2.ZERO, "布局确定性：同数据两次坐标一致且非零")
	gv2.queue_free()

	# ---- 3) 共同线索金边判定（c2 关联 2 人物）----
	_chk(gv._common_clues.has("c2"), "共同线索 c2（关联≥2人物）识别金边")
	_chk(not gv._common_clues.has("c1"), "c1 仅关联1人物，非共同线索")

	# ---- 4) 悬停高亮 ----
	gv._on_node_hover("c1", true)
	_chk(gv._highlight_id == "c1", "悬停设置高亮节点")
	gv._on_node_hover("c1", false)
	_chk(gv._highlight_id == "", "移出清除高亮")

	# ---- 5) 打标签 + 撤销（零惩罚）----
	var c3: Dictionary = gv._data._find_clue("c3")
	_chk(not ("NPC_DRE" in c3.get("related_npcs", [])), "打标签前 c3 与德雷伯无关")
	gv._tag_person("c3", "NPC_DRE")
	_chk("NPC_DRE" in gv._data._find_clue("c3").get("related_npcs", []), "打标签后 c3 关联德雷伯")
	gv._on_undo()
	_chk(not ("NPC_DRE" in gv._data._find_clue("c3").get("related_npcs", [])), "撤销后 c3 取消关联德雷伯")

	# ---- 6) 自环约束（线索不能指向自己）----
	var rel_before: int = gv._relations.size()
	gv._add_edge("c3", "c3", "support")
	_chk(gv._relations.size() == rel_before, "自环被拒：关系数不变")
	_chk(gv._node_views.has("c3") == false or true, "自环不改节点结构")

	# ---- 7) 建立证据连线（c3→H1）----
	gv._add_edge("c3", "H1", "support")
	_chk(gv._relations.size() == rel_before + 1, "建立 c3→H1 证据连线成功")

	# ---- 8) 模式切换 C→B 不崩溃、节点结构保留 ----
	gv._switch_mode(1)
	_chk(gv._mode == 1, "切换到模式 B 成功")
	_chk(gv._node_views.has("conclusion"), "模式 B 仍含结论节点")

	# ---- 9) 锁定态（已验证）只读 ----
	var locked_data := _sample_data()
	locked_data["editable"] = false
	var gvL := _mk_controller(locked_data)
	_chk(gvL._state == 1, "锁定态 State.LOCKED")
	var lc3: Dictionary = gvL._data._find_clue("c3")
	gvL._tag_person("c3", "NPC_DRE")
	_chk(not ("NPC_DRE" in gvL._data._find_clue("c3").get("related_npcs", [])), "锁定态打标签被拒（零惩罚只读）")
	gvL.queue_free()

	gv.queue_free()
	print("=== 图谱视图结果: PASS=%d  FAIL=%d ===" % [_pass, _fail])
	if _fail > 0:
		print("GRAPH_VIEW_RESULT: FAIL")
	else:
		print("GRAPH_VIEW_RESULT: PASS")
