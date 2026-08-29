extends SceneTree
## 跨场景累积集成测试（设计文档 09）：验证「场景三开墙带入场景二全部内容」关键主张：
##   ① 上一场景预设推断/结论节点确实进入画布（信息缺失根因修复）
##   ② 关系边端点全部解析（无孤儿边被丢弃）
##   ③ 跨场景共用人物只出现一次（同一人物不重复）
##   ④ 零重叠（自适应画布生效）
## 用真实 CaseReasoningRegistry 并集作为 hypo，模拟场景三开墙（case_wide=true）。
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	var reg_script = load("res://data/case_reasoning_registry.gd")
	var union: Dictionary = reg_script.get_hypo_union()

	# 线索：模拟场景三开墙时全案池已含场景二线索（c2xx）+ 本场景新线索（c3xx）
	var clues: Array = []
	for cid in ["c201", "c202", "c203", "c301", "c302", "c303"]:
		clues.append({"id": cid, "name": cid, "correct": true})

	# 人物：场景二与场景三共用 NPC_WT（看门老头）→ 只传一次，验证不重复
	var persons: Array = [
		{"id": "NPC_WT", "name": "看门老头"},
		{"id": "NPC_1", "name": "马车夫"},
	]

	# 关系：模拟真实玩法下 case_wall_state 已累积的边（连通树，避免 34 孤立根星爆）。
	# 结论 → 共用人物（target）；推断 → 结论（support，轮流分配）；线索 → 推断（support，每推断挂 1 线索）。
	# 末 3 个推断故意不连线 → 作孤立根，验证螺旋碰撞放置零重叠。
	var relations: Array = []
	var _concls: Array = []
	for _c in union.get("battlefield", {}).get("conclusions", []):
		_concls.append("conclusion_" + str(_c.get("id", "")))
	for _cc in _concls:
		relations.append({"from": _cc, "to": "NPC_WT", "kind": "target"})   # 结论→共用人物
	var _hyps: Array = union.get("battlefield", {}).get("hypotheses", [])
	var _clue_ids: Array = ["c201", "c202", "c203", "c301", "c302", "c303"]
	for _i in _hyps.size():
		var _h: String = str(_hyps[_i].get("id", ""))
		if _i >= _hyps.size() - 3:
			continue   # 末 3 个推断保持孤立（验证孤立根螺旋放置）
		var _tgt: String = _concls[_i % _concls.size()]
		relations.append({"from": _h, "to": _tgt, "kind": "support"})       # 推断→结论
		var _cl: String = _clue_ids[_i % _clue_ids.size()]
		relations.append({"from": _cl, "to": _h, "kind": "support"})        # 线索→推断

	print("== 跨场景累积集成测试（场景三开墙，case_wide） ==")
	var t0 := Time.get_ticks_msec()
	gv.build({"clues": clues, "hypo": union, "persons": persons,
		"focus_person": "", "difficulty": gv.Diff.NORMAL, "editable": true,
		"state_store": {}, "relations": relations, "auto_fold": false, "case_wide": true})
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var _nl: Array = gv._node_list()
	print("[debug] union.hypotheses.size=%d union.conclusions.size=%d" % [
		union.get("battlefield", {}).get("hypotheses", []).size(),
		union.get("battlefield", {}).get("conclusions", []).size()])
	print("[debug] _node_list 返回=%d" % _nl.size())
	var _kh := {}
	for _n in _nl:
		var _k: String = _n.get("kind", "?")
		_kh[_k] = _kh.get(_k, 0) + 1
	print("[debug] _node_list kind 分布=%s" % str(_kh))
	print("[debug] _node_kind 是否含 H2-01? %s  H3-01? %s" % [
		gv._node_kind.has("H2-01"), gv._node_kind.has("H3-01")])
	var t1 := Time.get_ticks_msec()

	var ids: Array = gv._node_center.keys()
	var fails := 0

	# ① 上一场景节点必须存在
	for must in ["H2-01", "H2-03", "H3-01", "conclusion_CL2-1"]:
		if not gv._node_center.has(must):
			print("CROSS FAIL 缺失上一场景节点: " + must); fails += 1

	# ② 关系端点全部解析（无孤儿边）
	for r in relations:
		if not gv._node_center.has(r["from"]):
			print("CROSS FAIL 边起点缺失: " + r["from"]); fails += 1
		if not gv._node_center.has(r["to"]):
			print("CROSS FAIL 边终点缺失: " + r["to"]); fails += 1

	# ③ 人物不重复（NPC_WT 仅一个节点）
	var wt_count := 0
	for nid in ids:
		if nid == "NPC_WT":
			wt_count += 1
	if wt_count != 1:
		print("CROSS FAIL 人物 NPC_WT 重复: count=%d" % wt_count); fails += 1

	# ④ 零重叠（复用布局自身的碰撞模型：宽按 kind、高=max(view_h,110)、clearance=24，
	# 与 _find_non_overlapping_position 真实放置逻辑完全一致，避免测试/布局尺寸口径不一致导致的误判）
	var ov := 0
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var ai: String = ids[i]
			var bi: String = ids[j]
			var rect_a: Rect2 = gv._layout._node_rect(ai)
			if gv._layout._intersects_any(rect_a, {bi: gv._node_center[bi]}, ai, 24.0):
				ov += 1
				if ov <= 12:
					var a: Vector2 = gv._node_center[ai]
					var b: Vector2 = gv._node_center[bi]
					print("  OVERLAP: %s(%s)@%.0f,%.0f <-> %s(%s)@%.0f,%.0f" % [
						ai, gv._node_kind.get(ai, ""), a.x, a.y, bi, gv._node_kind.get(bi, ""), b.x, b.y])
	if ov > 0:
		print("CROSS FAIL 重叠对数=%d" % ov); fails += 1

	# 包围盒（验证自适应画布：不钳制到固定框，节点按布局自由展开）
	var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
	for nid in ids:
		var c: Vector2 = gv._node_center[nid]
		var v = gv._node_views.get(nid, null)
		var sz: Vector2 = (v as Control).size if (v is Control) else Vector2(200, 90)
		minx = minf(minx, c.x - sz.x * 0.5); maxx = maxf(maxx, c.x + sz.x * 0.5)
		miny = minf(miny, c.y - sz.y * 0.5); maxy = maxf(maxy, c.y + sz.y * 0.5)
	print("  节点=%d 边=%d 布局耗时=%dms 重叠=%d" % [ids.size(), relations.size(), t1 - t0, ov])
	print("  包围盒 宽=%.0f 高=%.0f (视口1920x1080，自适应应>=较小值)" % [maxx - minx, maxy - miny])

	if fails == 0:
		print("CROSS_RESULT: PASS")
	else:
		print("CROSS_RESULT: FAIL(%d)" % fails)
	quit()
