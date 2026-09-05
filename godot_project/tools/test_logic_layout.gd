extends SceneTree
## MODE_LOGIC 逻辑图（偏右侧整洁树）布局验证：
##   段1（隔离单元测试）：直接构造多层级关系树（串行结论链 + 独立结论 + 双人物根），
##        调用 _logic_tree_layout，断言 XMind「结构服从关系」的核心性质：
##         A) 右向流：每条 support 边 父.x < 子.x（深度=右向轴）
##         B) 串行结论成链：A→B→C 的 x 严格递增（不并排）
##         C) 独立结论并排：同 root 的并列结论 同 x（同列）、异 y（垂直堆叠）、父居中于子
##         D) 零重叠：所有节点 AABB（含间隙）两两不相交
##         E) 多人物：两棵独立水平带树互不重叠（段D 已覆盖全局，此段再验垂直分离）
##   段2（集成冒烟）：用 scene2 风格数据走真实 build+推导管道，断言默认布局即逻辑图
##         （人物.x < 其结论.x，右向推导生效），确认替换 _star_tree_layout 接入正确。

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

	# 段1：隔离逻辑布局
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
		{"from":"C4", "to":"P1", "kind":"support"},   # 独立：C4 与 C1 同挂 P1
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

	# A) 右向流：每条边的父在左
	for r in REL:
		var par: String = r.get("to", ""); var chi: String = r.get("from", "")
		_chk(out.has(par) and out.has(chi) and out[par].x < out[chi].x,
			"右向流 %s.x(%.0f) < %s.x(%.0f)" % [par, out.get(par, Vector2.ZERO).x, chi, out.get(chi, Vector2.ZERO).x])

	# B) 串行结论成链：x 严格递增
	_chk(out["C1"].x < out["C2"].x and out["C2"].x < out["C3"].x,
		"串行链 C1.x(%.0f)<C2.x(%.0f)<C3.x(%.0f) 沿右向轴连续更深（非并排）" % [out["C1"].x, out["C2"].x, out["C3"].x])

	# C) 独立结论并排：C1 与 C4 同挂 P1 → 同列(x 相同)、异 y(垂直)、父 P1 居中于二者
	_chk(abs(out["C1"].x - out["C4"].x) < 1.0,
		"独立结论 C1/C4 同列 x(%.0f≈%.0f)" % [out["C1"].x, out["C4"].x])
	_chk(abs(out["C1"].y - out["C4"].y) > 20.0,
		"独立结论 C1/C4 垂直堆叠 y差=%.0f" % abs(out["C1"].y - out["C4"].y))
	var _ymin: float = minf(out["C1"].y, out["C4"].y)
	var _ymax: float = maxf(out["C1"].y, out["C4"].y)
	_chk(out["P1"].y > _ymin and out["P1"].y < _ymax,
		"父 P1.y(%.0f) 居中于子群[%.0f,%.0f]" % [out["P1"].y, _ymin, _ymax])

	# D) 零重叠：两两 AABB（碰撞模型：宽按 kind、高=max(估算高,110)、间隙20）不相交
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

	# E) 多人物垂直分离：P1 子树带与 P2 子树带不垂直重叠
	var _p1_set := ["P1","C1","C2","C3","C4","H1","CL1"]
	var _p2_set := ["P2","C5"]
	var _p1_min: float = 1e9; var _p1_max: float = -1e9
	var _p2_min: float = 1e9; var _p2_max: float = -1e9
	for id in _p1_set:
		_p1_min = minf(_p1_min, out[id].y); _p1_max = maxf(_p1_max, out[id].y)
	for id in _p2_set:
		_p2_min = minf(_p2_min, out[id].y); _p2_max = maxf(_p2_max, out[id].y)
	_chk(_p1_max < _p2_min or _p2_max < _p1_min,
		"多人物水平带垂直分离：P1带[%.0f,%.0f] 与 P2带[%.0f,%.0f] 不重叠" % [_p1_min, _p1_max, _p2_min, _p2_max])

	for l in _log:
		print("[LOGIC]", l)

	# 段2：集成冒烟（真实管道走默认逻辑布局）
	var clues := [
		{"id":"c201","name":"车轮印与并行车轮印","correct":true,"relation_tags":["H2-01"]},
		{"id":"c206","name":"大步幅脚印","correct":true,"relation_tags":["H2-02"]},
	]
	var hypo := {
		"battlefield": {
			"hypotheses": [
				{"id":"H2-01","text":"凶手乘出租马车来到花园街3号","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["出租马车"],"gate_clue_ids":["c201"]},
				{"id":"H2-02","text":"凶手身高六英尺以上","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["六英尺"],"gate_clue_ids":["c206"]},
			],
			"conclusions": [
				{"id":"CL2-1","text":"凶手乘出租马车抵达现场","kind":"true","dir":"affirm","subject":["凶手"],"object":["出租马车"],"gate_hypo_ids":["H2-01"]},
				{"id":"CL2-2","text":"凶手是高大强壮的成年男性","kind":"true","dir":"affirm","subject":["凶手"],"object":["高大"],"gate_hypo_ids":["H2-02"]},
			]
		}
	}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"KILLER","name":"凶手"}],"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	gv._derive_hypo("c201", "H2-01")
	gv._derive_conclusion("H2-01", "CL2-1")
	await process_frame
	var _pc := "conclusion_CL2-1"
	var _ph := "H2-01"
	var _right := false
	if gv._node_center.has(_pc) and gv._node_center.has(_ph):
		_right = gv._node_center[_pc].x < gv._node_center[_ph].x
	_chk(_right, "集成：默认布局 结论.x(%.0f) < 推断.x(%.0f) 右向推导生效（结论为父、推断为子，子在其右侧）" % [gv._node_center.get(_pc, Vector2.ZERO).x, gv._node_center.get(_ph, Vector2.ZERO).x])

	if _ok:
		print("LOGIC_RESULT: PASS — MODE_LOGIC 逻辑图布局全部性质验证通过")
	else:
		print("LOGIC_RESULT: FAIL")
	quit()
