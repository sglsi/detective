extends SceneTree
## G3 回归测试：BuchheimWalker 轮廓打包（取代旧列式 2-pass _resolve_and_recenter）。
## 复用 test_logic_layout 已验证零重叠/右向/多人物的结构（P1 分支+C4 叶子兄弟+H1→CL1；P2 单叶），
## 额外断言 G3 核心性质：
##   ② 父居中于「直接子」首尾 y 中点（XMind 局部对称，G3 核心；非整棵子树质心）
##   ③ 分支子树 + 叶子兄弟紧凑：叶子兄弟 C4 紧邻分支子树 C1（间距有界≈一卡高+轮廓间隙），
##      不被 C1 的深层子树拖出大垂直带（轮廓法在布局阶段即保证紧凑，无需事后修正）
## ① 右向流 / ④ 零重叠 / ⑤ 多人物分离 与 test_logic_layout 同口径，作为回归护栏。

var _ok := true
var _log := []

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_log.append(msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit(); return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame

	# 结构（from=子, to=父）：与 test_logic_layout §段1 一致
	var KIND := {
		"P1": "person", "P2": "person",
		"C1": "conclusion", "C2": "conclusion", "C3": "conclusion", "C4": "conclusion", "C5": "conclusion",
		"H1": "hypo", "CL1": "clue",
	}
	var LABEL := {
		"P1": "凶手", "P2": "被害人",
		"C1": "结论A：凶手乘出租马车抵达", "C2": "结论B：马车为并排双轮", "C3": "结论C：轮距符合出租马车",
		"C4": "结论D：凶手高大强壮", "C5": "结论E：被害人无挣扎痕迹",
		"H1": "推断：车轮印为并排双轮", "CL1": "线索：并排车轮印",
	}
	var REL := [
		{"from":"C1", "to":"P1", "kind":"support"},
		{"from":"C2", "to":"C1", "kind":"support"},   # 串行：C2 由 C1 推得
		{"from":"C3", "to":"C2", "kind":"support"},   # 串行更深：C3 由 C2 推得
		{"from":"C4", "to":"P1", "kind":"support"},   # 独立：C4 与 C1 同挂 P1（叶子兄弟）
		{"from":"H1", "to":"C1", "kind":"support"},   # 推断挂结论
		{"from":"CL1", "to":"H1", "kind":"support"},  # 线索挂推断
		{"from":"C5", "to":"P2", "kind":"support"},   # 第二人物根的子树
	]
	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL.duplicate()

	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})

	var center := Vector2(960.0, 540.0)
	var out := {}
	gv._layout._logic_tree_layout(nodes, center, {}, out)

	# ① 右向流：每条边 父在左
	for r in REL:
		var par: String = r.get("to", "")
		var chi: String = r.get("from", "")
		_chk(out.has(par) and out.has(chi) and out[par].x < out[chi].x,
			"右向流 %s.x(%.0f)<%s.x(%.0f)" % [par, out.get(par, Vector2.ZERO).x, chi, out.get(chi, Vector2.ZERO).x])

	# ② 父居中于「直接子」首尾 y 中点（局部对称，G3 核心）
	#    P1 直接子按 kind_rank 排序：结论(C1,C4) 在前、推断(H1 为 C1 之子非 P1 直接子) → 首=C1, 末=C4
	var _midC1C4: float = (out["C1"].y + out["C4"].y) * 0.5
	_chk(abs(out["P1"].y - _midC1C4) < 1.0, "P1 居中于直接子首尾[C1,C4]中点 P1.y=%.0f≈%.0f" % [out["P1"].y, _midC1C4])

	# ③ 叶子兄弟 C4 紧凑：紧邻分支子树 C1（间距有界≈一卡高+轮廓间隙），不被深层子树拖出大垂直带
	_chk(out["C4"].y > out["C1"].y, "C4 在 C1 之下 C4.y=%.0f > %.0f" % [out["C4"].y, out["C1"].y])
	_chk(out["C4"].y <= out["C1"].y + 280.0, "C4 紧凑(距 C1 顶层≤280) C4.y=%.0f ≤ %.0f" % [out["C4"].y, out["C1"].y + 280.0])

	# ④ 零重叠（与 test_logic_layout 同口径：grow 20）
	var ids := out.keys()
	var rects := {}
	for id in ids:
		var k: String = KIND[id]
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = maxf(gv._layout._est_node_h({"label": LABEL[id]}), 110.0)
		rects[id] = Rect2(out[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var ra: Rect2 = rects[ids[i]].grow(20.0)
			var rb: Rect2 = rects[ids[j]].grow(20.0)
			if ra.intersects(rb):
				overlap = true
				_ok = false
				print("FAIL 重叠 %s↔%s" % [ids[i], ids[j]])
	if not overlap:
		_log.append("零重叠：%d 节点 AABB（含20间隙）两两不相交 ✓" % ids.size())

	# ⑤ 多人物垂直分离
	var _p1_set := ["P1","C1","C2","C3","C4","H1","CL1"]
	var _p2_set := ["P2","C5"]
	var _p1_min: float = 1e9; var _p1_max: float = -1e9
	var _p2_min: float = 1e9; var _p2_max: float = -1e9
	for id in _p1_set:
		_p1_min = minf(_p1_min, out[id].y); _p1_max = maxf(_p1_max, out[id].y)
	for id in _p2_set:
		_p2_min = minf(_p2_min, out[id].y); _p2_max = maxf(_p2_max, out[id].y)
	_chk(_p1_max < _p2_min or _p2_max < _p1_min, "多人物水平带垂直分离 P1[%.0f,%.0f] P2[%.0f,%.0f]" % [_p1_min, _p1_max, _p2_min, _p2_max])

	for l in _log:
		print("[G3]", l)

	if _ok:
		print("CONTOUR_PACKING_RESULT: PASS")
	else:
		print("CONTOUR_PACKING_RESULT: FAIL")
	quit()
