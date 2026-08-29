extends SceneTree
## 规模压测：验证「不折叠、场景2~8 全部内容并集平铺」在场景八规模下是否可行
## 指标：节点数 / 边数 / 重叠对数 / 布局包围盒 / 布局耗时 / 与视口 1920x1080 对比
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	# ---------- 构造场景八规模的全案数据（并集形态） ----------
	var clues: Array = []
	for i in range(1, 30):
		clues.append({"id": "c%02d" % i, "name": "线索%02d" % i, "correct": true})

	var hypos: Array = []
	var cons: Array = []
	# scene2: 7 推断 + 7 结论
	for i in range(1, 8):
		hypos.append({"id": "H2-%02d" % i, "text": "场景二推断%d" % i, "correct": true})
	for i in range(1, 8):
		cons.append({"id": "CL2-%02d" % i, "text": "场景二结论%d" % i, "correct": true,
			"target": "person:NPC_%d" % (1 + (i % 5))})
	# scene3~8: 27 推断（按实测分布 4/3/4/2/4/3）
	var per_scene := {3: 4, 4: 3, 5: 4, 6: 2, 7: 4, 8: 3}
	var hypo_ids: Array = []
	for sid in per_scene:
		for i in range(1, per_scene[sid] + 1):
			var hid := "H%d-%02d" % [sid, i]
			hypos.append({"id": hid, "text": "场景%d推断%d" % [sid, i], "correct": true})
			hypo_ids.append(hid)
	var h2_ids: Array = []
	for i in range(1, 8):
		h2_ids.append("H2-%02d" % i)

	var persons: Array = []
	for i in range(1, 6):
		persons.append({"id": "NPC_%d" % i, "name": "人物%d" % i})

	var hypo := {"battlefield": {"hypotheses": hypos, "conclusions": cons}}

	# ---------- 构造关系边（模拟玩家逐步建立的推理关系） ----------
	var relations: Array = []
	# 每个推断 → 2 条线索（均匀消费 29 条线索池）
	var ci := 0
	for h in hypo_ids:
		for _k in 2:
			relations.append({"from": h, "to": "c%02d" % (1 + (ci % 29)), "kind": "support"})
			ci += 1
	for h in h2_ids:
		for _k in 2:
			relations.append({"from": h, "to": "c%02d" % (1 + (ci % 29)), "kind": "support"})
			ci += 1
	# 结论 → 推断
	for i in range(1, 8):
		relations.append({"from": "conclusion_CL2-%02d" % i, "to": "H2-%02d" % i, "kind": "support"})
	# 结论 → 人物（target 金边）
	for i in range(1, 8):
		relations.append({"from": "conclusion_CL2-%02d" % i,
			"to": "NPC_%d" % (1 + (i % 5)), "kind": "target"})
	# 跨场景边：场景3~8 的推断挂到场景2 推断上（链式累积，模拟"依托上一场景绘制"）
	var prev := h2_ids
	for sid in [3, 4, 5, 6, 7, 8]:
		var cur: Array = []
		for i in range(1, per_scene[sid] + 1):
			cur.append("H%d-%02d" % [sid, i])
		for j in range(cur.size()):
			relations.append({"from": cur[j], "to": prev[j % prev.size()], "kind": "support"})
		prev = cur

	print("== 规模压测：全并集平铺（场景八形态） ==")
	print("  线索=%d 推断=%d 结论=%d 人物=%d 边=%d" % [
		clues.size(), hypos.size(), cons.size(), persons.size(), relations.size()])
	print("  预计节点总数=%d" % (clues.size() + hypos.size() + cons.size() + persons.size()))

	var t0 := Time.get_ticks_msec()
	gv.build({"clues": clues, "hypo": hypo, "persons": persons,
		"focus_person": "", "difficulty": gv.Diff.NORMAL, "editable": true,
		"state_store": {}, "relations": relations, "auto_fold": false, "case_wide": true})
	await process_frame
	var _nl: Array = gv._node_list()
	var _nlhist := {}
	for _n in _nl:
		var _k: String = _n.get("kind", "?")
		_nlhist[_k] = _nlhist.get(_k, 0) + 1
	print("  [debug] _node_list() 返回节点=%d 分布=%s" % [_nl.size(), str(_nlhist)])
	gv._rebuild_graph()
	await process_frame
	var t1 := Time.get_ticks_msec()

	var ids: Array = gv._node_center.keys()
	print("  实际落画布节点=%d  布局耗时=%d ms" % [ids.size(), t1 - t0])
	# debug: kind 直方图
	var khist := {}
	var unknown_ids: Array = []
	for nid in ids:
		var k: String = gv._node_kind.get(nid, "?")
		khist[k] = khist.get(k, 0) + 1
		if k == "?": unknown_ids.append(nid)
	print("  节点 kind 分布=%s" % str(khist))
	print("  ?节点示例=%s" % str(unknown_ids.slice(0, 12)))

	# ---- 关键：预期节点 vs 实际落画布，diff 出「丢失」的节点 ----
	var expect: Array = []
	for c in clues: expect.append(c["id"])
	for h in hypos: expect.append(h["id"])
	for cc in cons: expect.append("conclusion_" + cc["id"])
	for p in persons: expect.append(p["id"])
	var missing: Array = []
	for e in expect:
		if not gv._node_center.has(e): missing.append(e)
	print("  预期节点=%d 实际=%d 丢失=%d" % [expect.size(), ids.size(), missing.size()])
	if missing.size() > 0:
		print("  !! 丢失节点: %s" % str(missing))

	# 包围盒（尺寸从节点 Control 取）
	var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
	for nid in ids:
		var c: Vector2 = gv._node_center[nid]
		var v = gv._node_views.get(nid, null)
		var sz: Vector2 = (v as Control).size if (v is Control) else Vector2(200, 90)
		minx = minf(minx, c.x - sz.x * 0.5); maxx = maxf(maxx, c.x + sz.x * 0.5)
		miny = minf(miny, c.y - sz.y * 0.5); maxy = maxf(maxy, c.y + sz.y * 0.5)
	print("  布局包围盒：宽=%.0f px  高=%.0f px" % [maxx - minx, maxy - miny])
	print("  视口 1920x1080 → 需缩放比=%.2fx 才能一屏看全" % [
		maxf((maxx - minx) / 1800.0, (maxy - miny) / 900.0)])

	# 重叠检测
	var ov := 0
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Vector2 = gv._node_center[ids[i]]; var b: Vector2 = gv._node_center[ids[j]]
			var va = gv._node_views.get(ids[i], null); var vb = gv._node_views.get(ids[j], null)
			var sa: Vector2 = (va as Control).size if (va is Control) else Vector2(200, 90)
			var sb: Vector2 = (vb as Control).size if (vb is Control) else Vector2(200, 90)
			if absf(a.x - b.x) < (sa.x + sb.x) * 0.5 and absf(a.y - b.y) < (sa.y + sb.y) * 0.5:
				ov += 1
	print("  重叠对数=%d" % ov)
	print(("SCALE_RESULT: " + ("PASS(零重叠)" if ov == 0 else "OVERLAP(%d)" % ov)))

	# ================= 对照：折叠形态（_apply_fold_to_roots，现有跨场景折叠逻辑） =================
	print("")
	print("== 对照组：调用折叠（链根折叠，现有跨场景逻辑） ==")
	gv._apply_fold_to_roots()
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var vids: Array = []
	for nid in gv._node_center.keys():
		if not gv._folded_nodes.has(nid): vids.append(nid)
	print("  折叠根(含人物锚点)=%d  可见节点=%d / 总节点=%d" % [
		gv._folded_nodes.size(), vids.size(), gv._node_center.size()])
	var fminx := 1e9; var fmaxx := -1e9; var fminy := 1e9; var fmaxy := -1e9
	for nid in vids:
		var c: Vector2 = gv._node_center[nid]
		var v = gv._node_views.get(nid, null)
		var sz: Vector2 = (v as Control).size if (v is Control) else Vector2(200, 90)
		fminx = minf(fminx, c.x - sz.x * 0.5); fmaxx = maxf(fmaxx, c.x + sz.x * 0.5)
		fminy = minf(fminy, c.y - sz.y * 0.5); fmaxy = maxf(fmaxy, c.y + sz.y * 0.5)
	print("  折叠后包围盒：宽=%.0f px  高=%.0f px" % [fmaxx - fminx, fmaxy - fminy])
	print("  需缩放比=%.2fx" % maxf((fmaxx - fminx) / 1800.0, (fmaxy - fminy) / 900.0))
	var fov := 0
	for i in range(vids.size()):
		for j in range(i + 1, vids.size()):
			var a: Vector2 = gv._node_center[vids[i]]; var b: Vector2 = gv._node_center[vids[j]]
			var va = gv._node_views.get(vids[i], null); var vb = gv._node_views.get(vids[j], null)
			var sa: Vector2 = (va as Control).size if (va is Control) else Vector2(200, 90)
			var sb: Vector2 = (vb as Control).size if (vb is Control) else Vector2(200, 90)
			if absf(a.x - b.x) < (sa.x + sb.x) * 0.5 and absf(a.y - b.y) < (sa.y + sb.y) * 0.5:
				fov += 1
	print("  折叠后重叠对数=%d" % fov)
	print(("FOLD_RESULT: " + ("PASS(零重叠)" if fov == 0 else "OVERLAP(%d)" % fov)))
	quit()
