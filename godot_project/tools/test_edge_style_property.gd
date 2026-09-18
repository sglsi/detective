extends SceneTree
## 2026-09-18 连线线形/性质交互回归：
##   · 弹窗显式设线形(实/虚)、性质(支持/反对/矛盾/弱关联) 正确改写 _relations（含 Undo 恢复）
##   · 顶栏路由 _edit_selected_edge_dashed/_kind 改的是「当前选中线」
##   · _select_edge 触发 on_edge_selected(idx)、_deselect_edge 触发 -1
##   · _edge_hit_test 命中容差放大(24)不过度偏移（加粗后仍能点中）

var _ok := true
var _sel_log := []

func _chk(c: bool, m: String) -> void:
	if c:
		print("[PASS] " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _on_sel(ei: int) -> void:
	_sel_log.append(ei)

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [{"id":"c1","name":"车轮印","correct":true},{"id":"c2","name":"脚印","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[{"id":"H1","text":"马车夫作案","correct":true}],"conclusions":[]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"KILLER","name":"凶手"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	# 派生 H1 推断节点（并建立 c1→H1 的 support 用户连线），确保两端都在 _node_center
	gv._derive_hypo("c1","H1")
	await process_frame
	gv._rebuild_graph()
	await process_frame

	var idx := -1
	for i in gv._edge_list.size():
		var e = gv._edge_list[i]
		if e.from == "c1" and e.to == "H1" and e.kind == "support":
			idx = i
	_chk(idx >= 0, "找到 c1→H1 support 边 idx=%d" % idx)
	if idx < 0:
		print("EDGE_STYLE_TEST_DONE ok=false"); quit(1)

	_chk(gv._relations[0].get("dashed",false) == false, "初始实线")
	_chk(gv._relations[0].get("kind") == "support", "初始 kind=support")

	# 选中该边
	gv._selected_edge = idx

	# 1) 显式设虚线
	gv._edge._set_edge_dashed(gv._edge_list[idx], true)
	await process_frame
	_chk(gv._relations[0].get("dashed",false) == true, "设虚线后 dashed=true")

	# 2) 设反对
	gv._edge._set_edge_kind(gv._edge_list[idx], "oppose")
	await process_frame
	var r0 = gv._relations[0]
	_chk(r0.get("kind") == "oppose", "设反对后 kind=oppose")
	_chk(r0.get("color_key") == "red", "反对→color_key=red")

	# 3) Undo 逐步恢复
	gv._undo.undo(); gv._rebuild_graph(); await process_frame
	_chk(gv._relations[0].get("kind") == "support", "undo kind 恢复 support")
	gv._undo.undo(); gv._rebuild_graph(); await process_frame
	_chk(gv._relations[0].get("dashed",false) == false, "undo dashed 恢复实线")

	# 4) 顶栏路由：改的是「当前选中线」
	gv._selected_edge = idx
	gv._edit_selected_edge_dashed(false)
	await process_frame
	_chk(gv._relations[0].get("dashed",false) == false, "_edit_selected_edge_dashed 改选中线")
	gv._edit_selected_edge_kind("contradict")
	await process_frame
	_chk(gv._relations[0].get("kind") == "contradict", "_edit_selected_edge_kind 改选中线")
	_chk(gv._relations[0].get("color_key") == "orange", "矛盾→color_key=orange")

	# 5) 选中/取消选中回调
	gv._cb_edge_selected = Callable(self, "_on_sel")
	_sel_log.clear()
	gv._edge._select_edge(idx, Vector2.ZERO)
	await process_frame
	_chk(_sel_log.size()==1 and _sel_log[0]==idx, "_select_edge 回调带 idx=%d" % idx)
	gv._deselect_edge()
	await process_frame
	_chk(_sel_log.size()==2 and _sel_log[1]==-1, "_deselect_edge 回调带 -1")
	_chk(gv._selected_edge == -1, "deselect 后 _selected_edge=-1")

	# 6) 命中容差：取曲线上一点必命中
	var pa = gv._node_center.get("H1", Vector2.ZERO)
	var cb = gv._node_center.get("c1", Vector2.ZERO)
	var ep = gv._edge._flow_endpoints("c1","H1",pa,cb)
	var pts = gv._edge._flow_curve_points(ep[0], ep[1])
	var p = pts[pts.size() / 2]
	var hit = gv._edge._edge_hit_test(p)
	_chk(hit == idx, "曲线上点命中 idx (hit=%d)" % hit)

	print("EDGE_STYLE_TEST_DONE ok=%s" % _ok)
	quit(0 if _ok else 1)
