extends Control

## 聚焦回归：任务3（线索可折叠收起自身）+ 任务5（案件级大墙进入新场景不再自动折叠隐藏旧线索）
## 运行：godot --headless "res://scenes/test_fold_clue_and_scenewide.tscn" --path <proj>
## 本测试作为 Control 节点运行（autoload 已绑定，get_root 可用）。

var _pass := 0
var _fail := 0

func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)

func _ids(gv) -> Array:
	var out := []
	for n in gv._node_list():
		out.append(n.id)
	return out

func _build(gv, data: Dictionary) -> void:
	add_child(gv)
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1280, 720)
	gv._rebuild_graph()

func _ready() -> void:
	size = Vector2(1280, 720)

	# ---- 任务3：线索可折叠（收起自身），且可展开恢复 ----
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	var d1 := {
		"clues": [{"id":"c1","name":"车轮印","correct":true,"associated":true,
			"related_npcs":["p1"],"relation_tags":[]}],
		"hypo": {"battlefield": {"hypotheses": [{"id":"h1","text":"惯犯所为","correct":true}]}, "chain_id":""},
		"persons": [{"id":"p1","name":"德雷伯"}],
		"focus_person": "p1",
		"relations": [{"from":"c1","to":"h1","kind":"support"}],
		"state_store": {},
		"editable": true,
		"case_wide": false,
		"auto_fold": false
	}
	_build(gv, d1)
	print("[DBG] clues=", gv._clues.size(), " focus=", gv._focus_person, " ids=", _ids(gv))
	_chk("c1" in _ids(gv), "任务3·前置：线索 c1 初始可见")
	_chk(not gv._compute_hidden().has("c1"), "任务3·前置：c1 未折叠")
	var ok: bool = gv.toggle_fold("c1")
	_chk(ok, "任务3·toggle_fold(c1) 返回 true（线索现在可折叠）")
	_chk(gv._compute_hidden().has("c1"), "任务3·折叠后 c1 进入隐藏集")
	_chk(not ("c1" in _ids(gv)), "任务3·折叠后 c1 从画布节点列表移除（真折叠，非仅隐藏连线）")
	gv.toggle_fold("c1")
	_chk("c1" in _ids(gv), "任务3·再次展开后 c1 恢复可见")

	# ---- 任务5：案件级大墙（case_wide）进入新场景不再自动折叠隐藏旧线索 ----
	var gv2 = load("res://scripts/clue/graph_view_controller.gd").new()
	var d2 := {
		"clues": [
			{"id":"c_old","name":"旧场景线索","correct":true,"associated":true,"related_npcs":["p_old"],"relation_tags":[]},
			{"id":"c_new","name":"新场景线索","correct":true,"associated":false,"related_npcs":["p_new"],"relation_tags":[]}
		],
		"hypo": {"battlefield": {"hypotheses": [{"id":"h1","text":"推断","correct":true}]}, "chain_id":""},
		"persons": [{"id":"p_old","name":"旧人物"},{"id":"p_new","name":"新人物"}],
		"focus_person": "p_new",
		"relations": [{"from":"c_old","to":"h1","kind":"support"},{"from":"p_old","to":"h1","kind":"support"}],
		"state_store": {},
		"editable": true,
		"case_wide": true,
		"auto_fold": true
	}
	_build(gv2, d2)
	_chk(gv2._compute_hidden().is_empty(), "任务5·case_wide 进入新场景不自动折叠（隐藏集为空）")
	_chk("c_old" in _ids(gv2), "任务5·旧场景线索 c_old 完整可见（不被收起）")
	_chk("c_new" in _ids(gv2), "任务5·新场景线索 c_new 完整可见")
	_chk("p_old" in _ids(gv2), "任务5·旧人物节点 p_old 完整可见")

	print("FOLD_CLUE_SCENEWIDE_RESULT: PASS=%d FAIL=%d" % [_pass, _fail])
	queue_free()
