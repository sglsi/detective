extends SceneTree
## 2026-09-18 思傅四问题回归（推理墙）：
##   ② 折叠态移动人物卡后展开：推理链子树必须以人物新位为基准重排（含折叠隐藏节点），
##      不再滞留画布中心默认列（旧根因：纯布局相对画布中心排布，仅根被钉回锚点）。
##   ②b 移动人物后新建关系的节点/链：同样以人物新位为基准（_relayout_on_edge 全量重排路径）。
##   ③④ 多兄弟推理链默认左右平衡：人物直接子（结论）≥2 → 左右分派；
##      左侧链呈镜像「叶→根」（线索.x < 推断.x < 结论.x < 人物.x），右侧「根→叶」。
##   锚点跟随不变式：任一 rebuild 后，子树每节点的 (x − 人物.x) 与初始布局的相对偏移一致
##   （列偏移确定性；去重叠只推 y 不动 x）。

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _initialize() -> void:
	await process_frame

	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit()
		return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame

	var clues := [
		{"id": "c201", "name": "车轮印与并行车轮印", "correct": true, "relation_tags": ["H2-01"]},
		{"id": "c206", "name": "大步幅脚印", "correct": true, "relation_tags": ["H2-02"]},
		{"id": "c207", "name": "现场遗留的雪茄烟灰", "correct": true, "relation_tags": ["H2-03"]},
	]
	var hypo := {"battlefield": {
		"hypotheses": [
			{"id": "H2-01", "text": "凶手乘出租马车来到花园街3号", "kind": "true", "correct": true, "dir": "affirm", "subject": ["凶手"], "object": ["出租马车"], "gate_clue_ids": ["c201"]},
			{"id": "H2-02", "text": "凶手身高六英尺以上", "kind": "true", "correct": true, "dir": "affirm", "subject": ["凶手"], "object": ["六英尺"], "gate_clue_ids": ["c206"]},
			{"id": "H2-03", "text": "凶手抽某种雪茄", "kind": "true", "correct": true, "dir": "affirm", "subject": ["凶手"], "object": ["雪茄"], "gate_clue_ids": ["c207"]},
		],
		"conclusions": []
	}}
	gv.build({"clues": clues, "hypo": hypo, "persons": [{"id": "KILLER", "name": "凶手"}],
		"difficulty": gv.Diff.NORMAL, "editable": true, "state_store": {}, "auto_fold": false})
	await process_frame
	# 三条链：c20x →(support) H2-0x →(support) conclusion_CL2-x →(target) KILLER
	for triple in [["c201", "H2-01", "CL2-1"], ["c206", "H2-02", "CL2-2"], ["c207", "H2-03", "CL2-3"]]:
		gv._derive.derive_hypo(triple[0], triple[1])
		gv._derive.derive_conclusion(triple[1], triple[2])
		gv._edge._add_edge("conclusion_" + triple[2], "KILLER", "target", "gold", false)
	await process_frame
	await process_frame

	var concl_ids := ["conclusion_CL2-1", "conclusion_CL2-2", "conclusion_CL2-3"]
	for cid in concl_ids:
		_chk(gv._node_center.has(cid), "结论节点已上墙: " + cid)
	var px0: float = gv._node_center["KILLER"].x

	# ---- ③④ 多兄弟链默认左右平衡 + 左侧镜像 ----
	var left_branch := []
	var right_branch := []
	for cid in concl_ids:
		if gv._node_center[cid].x < px0 - 1.0:
			left_branch.append(cid)
		else:
			right_branch.append(cid)
	_chk(not left_branch.is_empty() and not right_branch.is_empty(),
		"多链左右平衡：左 %d 条 / 右 %d 条（人物.x=%.0f）" % [left_branch.size(), right_branch.size(), px0])
	# 链结构：结论(父) ← 推断 ← 线索（from=子 to=父）。左侧镜像：线索.x < 推断.x < 结论.x < 人物.x
	for cid in left_branch:
		var hid := ""
		for r in gv._relations:
			if str(r.get("to", "")) == cid and str(r.get("kind", "")) == "support":
				hid = str(r.get("from", ""))
		var clid := ""
		if hid != "":
			for r in gv._relations:
				if str(r.get("to", "")) == hid and str(r.get("kind", "")) == "support":
					clid = str(r.get("from", ""))
		if hid == "" or clid == "":
			_chk(false, "%s 链结构不完整 hid=%s clid=%s" % [cid, hid, clid])
			continue
		var cx: float = gv._node_center[cid].x
		var hx: float = gv._node_center[hid].x
		var lx: float = gv._node_center[clid].x
		_chk(lx < hx and hx < cx and cx < px0,
			"左侧镜像 叶→根 %s：线索%.0f < 推断%.0f < 结论%.0f < 人物%.0f" % [cid, lx, hx, cx, px0])
	for cid in right_branch:
		var hid2 := ""
		for r in gv._relations:
			if str(r.get("to", "")) == cid and str(r.get("kind", "")) == "support":
				hid2 = str(r.get("from", ""))
		var clid2 := ""
		if hid2 != "":
			for r in gv._relations:
				if str(r.get("to", "")) == hid2 and str(r.get("kind", "")) == "support":
					clid2 = str(r.get("from", ""))
		if hid2 == "" or clid2 == "":
			_chk(false, "%s 链结构不完整 hid=%s clid=%s" % [cid, hid2, clid2])
			continue
		var cx2: float = gv._node_center[cid].x
		var hx2: float = gv._node_center[hid2].x
		var lx2: float = gv._node_center[clid2].x
		_chk(px0 < cx2 and cx2 < hx2 and hx2 < lx2,
			"右侧 根→叶 %s：人物%.0f < 结论%.0f < 推断%.0f < 线索%.0f" % [cid, px0, cx2, hx2, lx2])

	# 记录初始相对偏移（锚点跟随不变式的基准）
	var subtree: Array = gv._layout._descendants("KILLER")
	var init_rel := {}
	for nid in subtree:
		init_rel[str(nid)] = gv._node_center[str(nid)].x - px0

	# ---- ② 折叠态移动人物 → 展开：子树随人物新位 ----
	gv.toggle_fold("KILLER")
	await process_frame
	_chk(gv._folded_nodes.has("KILLER"), "人物已折叠（子树隐藏）")
	var newpos := Vector2(1500.0, 760.0)
	# 模拟折叠态拖动提交（_commit_move 折叠路径）：人物钉到新位 + rebuild
	gv._node_center["KILLER"] = newpos
	gv._root_anchor_pos["KILLER"] = newpos
	if not gv._manual_nodes.has("KILLER"):
		gv._manual_nodes.append("KILLER")
	gv._post_drag = true
	gv._rebuild_graph()
	await process_frame
	# 展开（full rebuild）
	gv.toggle_fold("KILLER")
	await process_frame
	await process_frame
	var px1: float = gv._node_center["KILLER"].x
	_chk(abs(px1 - newpos.x) < 1.0, "展开后人物仍在拖动落点 (%.0f≈%.0f)" % [px1, newpos.x])
	for nid in subtree:
		var ns := str(nid)
		if not gv._node_center.has(ns):
			_chk(false, "展开后子树节点缺失: " + ns)
			continue
		var rel_now: float = gv._node_center[ns].x - px1
		_chk(abs(rel_now - float(init_rel[ns])) < 2.0,
			"展开跟随 %s：相对人物偏移 %.0f ≈ 初始 %.0f" % [ns, rel_now, float(init_rel[ns])])

	# ---- ②b 移动后再全量重排（新建关系路径 _relayout_on_edge）：仍以人物新位为基准 ----
	var newpos2 := Vector2(700.0, 900.0)
	gv._node_center["KILLER"] = newpos2
	gv._root_anchor_pos["KILLER"] = newpos2
	gv._layout._relayout_on_edge = true
	gv._post_drag = true
	gv._rebuild_graph()
	await process_frame
	await process_frame
	var px2: float = gv._node_center["KILLER"].x
	for nid in subtree:
		var ns2 := str(nid)
		if not gv._node_center.has(ns2):
			_chk(false, "重排后子树节点缺失: " + ns2)
			continue
		var rel2: float = gv._node_center[ns2].x - px2
		_chk(abs(rel2 - float(init_rel[ns2])) < 2.0,
			"新建关系重排跟随 %s：相对偏移 %.0f ≈ 初始 %.0f" % [ns2, rel2, float(init_rel[ns2])])

	if _ok:
		print("ANCHOR_RESULT: PASS — 锚点跟随/折叠展开跟随/左右平衡/镜像 全部通过")
	else:
		print("ANCHOR_RESULT: FAIL")
	quit()
