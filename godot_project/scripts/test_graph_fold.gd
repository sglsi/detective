extends Control

## 图谱折叠（XMind 式连线折叠）headless 回归测试
## 运行：godot --headless "res://scenes/test_graph_fold.tscn"
## 覆盖：折叠推断隐藏外层线索 / 折叠控件点击不触发拖动 / 展开位置还原 /
##       持久化+重建恢复折叠 / 旧键 graph_folded_persons 迁移 / 顶部🪗折叠焦点人物。

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
		"state_store":{"graph_focus":"NPC_HOP"},"on_tag":Callable(),"on_add_edge":Callable(),
		"on_remove_relation":Callable(),"on_close":Callable()}


func _run() -> void:
	# ---- A) 折叠推断隐藏外层线索 + 控件存在性 ----
	var gv := _mk_controller(_sample_data())
	_chk(gv._node_views.has("H1"), "折叠前含推断 H1")
	_chk(gv._node_views.has("c1") and gv._node_views.has("c2"), "折叠前含线索 c1/c2")
	_chk(gv._fold_controls.has("H1"), "推断 H1 有折叠控件")
	_chk(gv._fold_count("H1") == 2, "H1 折叠控件计数=2（直接外层线索数）")
	_chk(not gv._fold_controls.has("c1"), "线索 c1 是叶子，无折叠控件")
	_chk(gv._fold_controls.has("conclusion"), "结论有折叠控件（外层为推断）")
	_chk(gv._fold_controls.has("NPC_HOP"), "焦点人物有折叠控件（外层为线索）")

	gv.toggle_fold("H1")
	_chk(gv._folded_nodes.has("H1"), "折叠 H1 后 _folded_nodes 含 H1")
	_chk(not gv._node_views.has("c1"), "折叠 H1 后线索 c1 被隐藏")
	_chk(not gv._node_views.has("c2"), "折叠 H1 后线索 c2 被隐藏")
	_chk(gv._node_views.has("H1"), "折叠根 H1 自身仍可见")
	_chk(gv._fold_controls.has("H1"), "折叠后根 H1 仍可见，折叠控件保留（呈 +N 折叠态）")
	_chk(gv._fold_glyph("H1") == "+2", "折叠后 H1 控件字形为 +2")

	gv.toggle_fold("H1")
	_chk(gv._node_views.has("c1") and gv._node_views.has("c2"), "展开 H1 后线索恢复可见")

	# ---- B) 折叠控件点击不触发节点拖动 ----
	var gv2 := _mk_controller(_sample_data())
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gv2._on_fold_control_gui(ev, "H1")
	_chk(gv2._folded_nodes.has("H1"), "点击折叠控件后 H1 被折叠")
	_chk(gv2._dragging == false, "点击折叠控件未触发节点拖动(_dragging=false)")
	gv2.queue_free()

	# ---- C) 展开后位置与折叠前一致（_all_positions 保持，避免错位）----
	var gv3 := _mk_controller(_sample_data())
	var before: Vector2 = gv3._node_center.get("c1", Vector2.ZERO)
	_chk(before != Vector2.ZERO, "折叠前 c1 位置非零")
	gv3.toggle_fold("H1")   # 隐藏 c1
	gv3.toggle_fold("H1")   # 展开
	var after: Vector2 = gv3._node_center.get("c1", Vector2.ZERO)
	_chk(after == before, "展开后 c1 位置与折叠前完全一致（无错位）")
	gv3.queue_free()

	# ---- D) 持久化 + 重建恢复折叠 ----
	var gv4 := _mk_controller(_sample_data())
	gv4.toggle_fold("H1")
	gv4._persist_view()
	_chk(gv4._state_store.get("graph_folded_nodes", {}).has("H1"), "persist 后 graph_folded_nodes 含 H1")
	var rebuild_data := _sample_data()
	rebuild_data["state_store"] = gv4._state_store
	var gv5 := _mk_controller(rebuild_data)
	_chk(gv5._folded_nodes.has("H1"), "重建后从 state_store 恢复折叠状态")
	_chk(not gv5._node_views.has("c1"), "重建后线索 c1 仍隐藏（折叠持久）")
	gv5.queue_free()
	gv4.queue_free()

	# ---- E) 旧键 graph_folded_persons 迁移为 graph_folded_nodes ----
	var mig_data := _sample_data()
	mig_data["state_store"] = {"graph_folded_persons": {"NPC_HOP": true}}
	var gv6 := _mk_controller(mig_data)
	_chk(gv6._folded_nodes.has("NPC_HOP"), "旧键 graph_folded_persons 迁移进 _folded_nodes")
	_chk(not gv6._node_views.has("c1"), "旧键迁移后焦点人物关联线索被隐藏")
	gv6._persist_view()
	_chk(gv6._state_store.get("graph_folded_nodes", {}).has("NPC_HOP"), "迁移后经 persist 写入新键 graph_folded_nodes")
	gv6.queue_free()

	# ---- F) 顶部 🪗 折叠焦点人物（保留旧行为）----
	var gv7 := _mk_controller(_sample_data())
	_chk(gv7._node_views.has("c1") and gv7._node_views.has("c2"), "🪗 前线索可见")
	var folded: bool = gv7.toggle_fold_focus()
	_chk(folded == true, "🪗 折叠焦点人物返回 true")
	_chk(not gv7._node_views.has("c1"), "🪗 折叠焦点人物后其线索被隐藏")
	_chk(not gv7._node_views.has("c2"), "🪗 折叠焦点人物后其另一线索也隐藏")
	gv7.queue_free()

	gv.queue_free()
	print("=== 图谱折叠结果: PASS=%d  FAIL=%d ===" % [_pass, _fail])
	if _fail > 0:
		print("GRAPH_FOLD_RESULT: FAIL")
	else:
		print("GRAPH_FOLD_RESULT: PASS")
