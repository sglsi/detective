extends SceneTree
## 人物关联后的左右平衡归位验证（2026-09-19 思傅报两 bug 的回归锁定）：
##   症状① 人物卡片被其它卡片覆盖（被拖结论与人物双刚性 → 全局去重叠永久跳过）
##   症状② 中间结论（干）留在人物右侧拖拽落点、其推断/线索（叶枝）被镜像派生到左侧 → 干叶异侧
##   根因：拖拽关联把被拖结论钉在落点（_root_anchor_pos + _manual_nodes），与平衡布局脱钩。
##   修复（controller _commit_move）：人物关联边创建时，非人物端清自身+后代钉位、清对端旧钉位，
##   置 _relayout_on_edge 全量重排；人物端保留钉位（玩家在移动人物）。
##   本测试锁定修复后的 _compute_layout 语义：
##   段E 人物钉位 + 3 条结论链（修复后状态：仅人物有锚点、relayout 标志开启）
##     E1 三链分侧 = 左 1 右 2（_last_layout_sides）
##     E2 每条链干-枝-叶与人物同侧且随深度单调远离（干叶同侧，禁止症状②）
##     E3 零 AABB 重叠（含人物，禁止症状①）
##     E4 人物保持玩家钉位锚点（拖人物的落点被尊重）
##   段F 无钉位纯布局（首次关联 / 未拖动过）同样满足分侧一致 + 零重叠

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("PASS " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


## 人物 P + n 条线性链（结论 Ci → 推断 Hi → 线索 Li，C→P 为 target 归属边）
func _build_person_scene(n_chain: int, prefix: String) -> Dictionary:
	var KIND := {prefix + "P": "person"}
	var LABEL := {prefix + "P": "嫌疑人：平衡归位验证人物"}
	var REL := []
	for i in n_chain:
		var c := "%sC%d" % [prefix, i]
		var h := "%sH%d" % [prefix, i]
		var l := "%sL%d" % [prefix, i]
		KIND[c] = "conclusion"
		LABEL[c] = "干结论%d：围绕人物的第一层结论文本" % i
		KIND[h] = "hypo"
		LABEL[h] = "枝推断%d：第二层推断文本" % i
		KIND[l] = "clue"
		LABEL[l] = "叶线索%d：支撑该推断的线索描述文本" % i
		REL.append({"from": c, "to": prefix + "P", "kind": "target"})
		REL.append({"from": h, "to": c, "kind": "support"})
		REL.append({"from": l, "to": h, "kind": "support"})
	return {"KIND": KIND, "LABEL": LABEL, "REL": REL}


func _setup_gv(gv, scene: Dictionary) -> Array:
	gv._graph_nodes = []
	for id in scene["KIND"]:
		gv._graph_nodes.append({"id": id, "kind": scene["KIND"][id], "label": scene["LABEL"][id], "sub": "", "data": {}})
	gv._relations = scene["REL"].duplicate()
	var nodes := []
	for id in scene["KIND"]:
		nodes.append({"id": id, "kind": scene["KIND"][id], "label": scene["LABEL"][id]})
	return nodes


func _overlap_check(gv, out: Dictionary, KIND: Dictionary, LABEL: Dictionary) -> void:
	var ids := out.keys()
	var rects := {}
	for id in ids:
		var k: String = KIND[id]
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(id, {"id": id, "kind": k, "label": LABEL[id]})
		rects[id] = Rect2(out[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].grow(2.0).intersects(rects[ids[j]].grow(2.0)):
				overlap = true
				print("FAIL 重叠 %s↔%s" % [ids[i], ids[j]])
	_chk(not overlap, "零 AABB 重叠（%d 节点两两不相交，含人物，禁止症状①）" % ids.size())


## 分侧一致性：每条链 干(C)-枝(H)-叶(L) 与人物同侧、随深度单调远离（禁止症状②干叶异侧）
func _side_consistency_check(gv, out: Dictionary, P: String, chains: Array, tag: String) -> void:
	var sides: Dictionary = gv._last_layout_sides
	var px: float = out[P].x
	var left_n := 0
	var right_n := 0
	var ok_all := true
	for c in chains:
		var s: String = str(sides.get(c, "R"))
		var h: String = c.replace("C", "H")
		var l: String = c.replace("C", "L")
		if s == "L":
			left_n += 1
			if not (out[c].x < px and out[h].x < out[c].x and out[l].x < out[h].x):
				ok_all = false
				print("FAIL %s 链 %s 左侧不单调/异侧（C=%.0f H=%.0f L=%.0f P=%.0f）" % [tag, c, out[c].x, out[h].x, out[l].x, px])
		else:
			right_n += 1
			if not (out[c].x > px and out[h].x > out[c].x and out[l].x > out[h].x):
				ok_all = false
				print("FAIL %s 链 %s 右侧不单调/异侧（C=%.0f H=%.0f L=%.0f P=%.0f）" % [tag, c, out[c].x, out[h].x, out[l].x, px])
	_chk(ok_all, "%s 全部链干-枝-叶与人物同侧且随深度单调远离（左=%d 右=%d）" % [tag, left_n, right_n])
	return


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit()
		return

	# ---- 段E：人物钉位 + 3 条结论链（模拟「拖结论关联人物」修复后状态）----
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var canvas := Control.new()
	canvas.size = Vector2(1920.0, 1080.0)
	gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	var scene := _build_person_scene(3, "E")
	var nodes := _setup_gv(gv, scene)
	# 人物被玩家拖动过 → 根锚点钉位；被拖结论 C1 的旧钉位已按修复清除
	var anchor := Vector2(1150.0, 520.0)
	gv._root_anchor_pos = {"EP": anchor}
	gv._manual_nodes = ["EP"]
	# 拖前旧位（脏数据，应被 relayout 标志忽略）
	var stale := {}
	for id in scene["KIND"]:
		stale[id] = Vector2(1400.0 + randf() * 100.0, 200.0 + randf() * 300.0)
	stale["EC1"] = Vector2(1500.0, 260.0)   # 旧落点（人物右侧）
	gv._node_center = stale
	gv._layout._relayout_on_edge = true
	var outE: Dictionary = gv._layout._compute_layout(nodes, {})
	# E1: 三链分侧 = 左 1 右 2
	var sidesE: Dictionary = gv._last_layout_sides
	var ln := 0
	for i in 3:
		if str(sidesE.get("EC%d" % i, "R")) == "L":
			ln += 1
	_chk(ln == 1, "E1 三条结论链左右分派 = 左 1 右 2（实际左 %d）" % ln)
	# E2: 干叶同侧 + 单调
	_side_consistency_check(gv, outE, "EP", ["EC0", "EC1", "EC2"], "E2")
	# E3: 零重叠
	_overlap_check(gv, outE, scene["KIND"], scene["LABEL"])
	# E4: 人物保持玩家钉位锚点
	_chk(outE["EP"].distance_to(anchor) < 0.5, "E4 人物保持玩家钉位锚点 (%.0f,%.0f)" % [anchor.x, anchor.y])

	# ---- 段F：无钉位纯布局（首次关联 / 未拖动过）----
	var gv2 = GV.new()
	var holder2 = Control.new()
	root.add_child(holder2)
	holder2.add_child(gv2)
	await process_frame
	gv2._canvas = canvas
	gv2._mode = GV.ViewMode.MODE_C
	var scene2 := _build_person_scene(3, "F")
	var nodes2 := _setup_gv(gv2, scene2)
	gv2._root_anchor_pos = {}
	gv2._manual_nodes = []
	gv2._node_center = {}
	var outF: Dictionary = gv2._layout._compute_layout(nodes2, {})
	var sidesF: Dictionary = gv2._last_layout_sides
	var ln2 := 0
	for i in 3:
		if str(sidesF.get("FC%d" % i, "R")) == "L":
			ln2 += 1
	_chk(ln2 == 1, "F1 三条结论链左右分派 = 左 1 右 2（实际左 %d）" % ln2)
	_side_consistency_check(gv2, outF, "FP", ["FC0", "FC1", "FC2"], "F2")
	_overlap_check(gv2, outF, scene2["KIND"], scene2["LABEL"])

	if _ok:
		print("ASSOC_RESULT: PASS — 人物关联平衡归位语义全部验证通过")
	else:
		print("ASSOC_RESULT: FAIL")
	quit()
