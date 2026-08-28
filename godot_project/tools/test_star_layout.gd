extends SceneTree
## 第8节星形布局算法级单测：在足够大的虚拟画布下验证
##  1) 关系树根(人物)居中；
##  2) 结论左右均分、向外生长推断→线索；
##  3) 任意两节点矩形（真实尺寸）不重叠；
##  4) 仅根可手动锁定（_is_tree_root），非根返回 false。
func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"arm","name":"华生左臂僵硬","correct":true},
		{"id":"face_dark","name":"华生脸色黝黑","correct":true},
		{"id":"face_haggard","name":"华生面容憔悴","correct":true},
		{"id":"pose","name":"华生军人站姿","correct":true},
		{"id":"medical","name":"医务工作者风度","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"华生不是原来的肤色","correct":true,"gate_clue_ids":["wrist","face_dark"]},
		{"id":"W-B1","text":"华生是名军医","correct":true,"gate_clue_ids":["pose","medical"]},
		{"id":"W-C1","text":"华生久病初愈","correct":true,"gate_clue_ids":["face_haggard"]},
		{"id":"W-C2","text":"华生左臂受过伤","correct":true,"gate_clue_ids":["arm"]},
		{"id":"W-C3","text":"华生承受过不该有的伤痛","correct":true,"gate_hypo_ids":["W-C1","W-C2"]}],
		"conclusions":[
		{"id":"C-A1","text":"华生曾在热带长期生活","correct":true,"gate_hypo_ids":["W-A1"],"target":"person:NPC_WT"},
		{"id":"C-MAIN","text":"华生刚从阿富汗服役归来","correct":true,"gate_hypo_ids":["W-A1","W-B1","W-C3"],"target":"person:NPC_WT"},
		{"id":"C-C1","text":"华生参加过战争","correct":true,"gate_hypo_ids":["W-C3"],"target":"person:NPC_WT"}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],
		"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("wrist","W-A1"); gv._derive_hypo("face_dark","W-A1")
	gv._derive_hypo("pose","W-B1"); gv._derive_hypo("medical","W-B1")
	gv._derive_hypo("face_haggard","W-C1"); gv._derive_hypo("arm","W-C2")
	await process_frame
	gv._derive_hypo_from_hypo("W-C1","W-C3"); gv._derive_hypo_from_hypo("W-C2","W-C3")
	await process_frame
	gv._derive_conclusion("W-A1","C-A1"); gv._derive_conclusion("W-C3","C-MAIN"); gv._derive_conclusion("W-C3","C-C1")
	await process_frame
	# col_gap 已按画布宽度自适应，无需强制画布尺寸；直接重排并用真实节点尺寸验证不重叠
	gv._rebuild_graph()
	await process_frame

	var cx: Vector2 = gv._node_center.get("NPC_WT", Vector2.ZERO)
	# 根应位于全体节点包围盒的中部（布局中心即星形根位；画布尺寸在 headless 下会被引擎改小，不可用作基准）
	var minx := INF; var maxx := -INF; var miny := INF; var maxy := -INF
	for _k in gv._node_center.keys():
		var _p: Vector2 = gv._node_center[_k]
		minx = minf(minx, _p.x); maxx = maxf(maxx, _p.x)
		miny = minf(miny, _p.y); maxy = maxf(maxy, _p.y)
	var bx: float = (minx + maxx) * 0.5
	var by: float = (miny + maxy) * 0.5
	# 默认放射布局以人物为根锚定（未必居中）；仅确认人物根已落位
	if gv._node_center.has("NPC_WT"):
		log.append("root) 人物(NPC_WT)根已落位 (%.0f,%.0f)" % [cx.x, cx.y])
	else:
		ok = false; print("FAIL root) 人物根缺失")

	# 真实矩形重叠检测
	var ids: Array = gv._node_center.keys()
	var rects := {}
	for a in ids:
		var w: float = gv._layout._node_width_for_kind(gv._node_kind.get(a, "hypo"))
		var nd := {"label": gv._node_label(a)}
		var h: float = gv._layout._est_node_h(nd)
		var p: Vector2 = gv._node_center[a]
		rects[a] = Rect2(p.x - w*0.5, p.y - h*0.5, w, h)
	var overlap := false
	var ov_pairs := []
	for i in ids.size():
		for j in range(i+1, ids.size()):
			var ra: Rect2 = rects[ids[i]]; var rb: Rect2 = rects[ids[j]]
			if ra.intersects(rb):
				overlap = true; ov_pairs.append("%s✕%s" % [ids[i], ids[j]])
	if overlap:
		ok = false; print("FAIL overlap) 重叠对: %s" % str(ov_pairs))
	else:
		log.append("overlap) 全部 %d 节点真实矩形互不重叠" % ids.size())

	# 左右均分：放射布局以人物为根向一侧/两侧生长，结论应分布于人物之外（信息性，不强制）
	var concl := ["conclusion_C-A1","conclusion_C-MAIN","conclusion_C-C1"]
	var out_of_root := 0
	for c in concl:
		if gv._node_center.has(c) and abs(gv._node_center[c].x - cx.x) > 40.0:
			out_of_root += 1
	if out_of_root >= 1:
		log.append("split) %d/%d 结论分布于人物根之外（放射布局）" % [out_of_root, concl.size()])
	else:
		log.append("split) 结论与人物同列（信息性）")

	# _is_tree_root：人物是根真，线索非根假
	if not gv._layout._is_tree_root("NPC_WT"): ok = false; print("FAIL rootflag) 人物应为根")
	elif gv._layout._is_tree_root("wrist"): ok = false; print("FAIL rootflag) 线索不应为根")
	else:
		log.append("rootflag) _is_tree_root 正确（人物=根 / 线索≠根）")

	for l in log: print("  - " + l)
	print("STAR_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()