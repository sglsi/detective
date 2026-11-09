extends SceneTree
## L02 收尾验证：反转墙规模不退化（0cbfeda 后，不改代码）
## 构造真实场景二完整反转墙：9 线索 H2-01~09 / CL2-1~CL2-9 / persons 由 related_npcs 派生（KILLER）。

var _gvclass = null
func _clue(id, name, tags, rel=null):
	if rel == null: rel = []
	return {"id":id,"name":name,"correct":true,"relation_tags":tags,"related_npcs":rel}

func _make_gv():
	if _gvclass == null:
		_gvclass = load("res://scripts/clue/graph_view_controller.gd")
	var gv = _gvclass.new()
	var holder := Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv._canvas = Control.new()
	return gv

func _proc():
	# 真实场景二线索（scene2.gd STREET/PATH_HOTSPOTS 实读）
	var clues := [
		_clue("c201","碾轧的花草",["H2-01"],["KILLER"]),
		_clue("c202","平行车轮印",["H2-01"]),
		_clue("c203","右前蹄新蹄铁",["H2-02"]),
		_clue("c204","马蹄印迹零乱",["H2-03"]),
		_clue("c205","两组不同脚印",["H2-04","H2-06","H2-08"]),
		_clue("c206","步伐距离差异",["H2-04","H2-05"]),
		_clue("c209","方头靴印",["H2-06","H2-07"]),
		_clue("c210","尖头漆皮靴印",["H2-09"]),
		_clue("c211","两串脚印的往返",["H2-10"]),
	]
	# 真实推断 gate_clue_ids（scene2.gd battlefield.hypotheses 实读）
	var hyps := [
		{"id":"H2-01","gate_clue_ids":["c201","c202"]},
		{"id":"H2-02","gate_clue_ids":["c203"]},
		{"id":"H2-03","gate_clue_ids":["c204"]},
		{"id":"H2-04","gate_clue_ids":["c205","c206"]},
		{"id":"H2-05","gate_clue_ids":["c206"]},
		{"id":"H2-06","gate_clue_ids":["c205"]},
		{"id":"H2-07","gate_clue_ids":["c206"]},
		{"id":"H2-08","gate_clue_ids":["c205"]},
		{"id":"H2-09","gate_clue_ids":["c210","c206"]},
		{"id":"H2-10","gate_clue_ids":["c211"]},
	]
	# 真实结论 gate_hypo_ids（scene2.gd battlefield.conclusions 实读）
	var cons := [
		{"id":"CL2-1","gate_hypo_ids":["H2-01"]},
		{"id":"CL2-2","gate_hypo_ids":["H2-02"]},
		{"id":"CL2-3","gate_hypo_ids":["H2-03"]},
		{"id":"CL2-4","gate_hypo_ids":["H2-01","H2-02","H2-03"],"target":"person:KILLER"},
		{"id":"CL2-5","gate_hypo_ids":["H2-04"]},
		{"id":"CL2-6","gate_hypo_ids":["H2-05","H2-06"],"target":"person:KILLER"},
		{"id":"CL2-7","gate_hypo_ids":["H2-04","H2-08"]},
		{"id":"CL2-8","gate_hypo_ids":["H2-09"]},
		{"id":"CL2-9","gate_hypo_ids":["H2-10"]},
	]
	# persons 由 related_npcs 派生（含 KILLER）——同 _derive_persons 语义
	var persons := []
	var seen := {}
	for c in clues:
		for p in c.get("related_npcs", []):
			if not seen.has(p): seen[p]=true; persons.append({"id":p,"name":p})

	var gv = await _make_gv()
	var hypo := {"battlefield":{
		"hypotheses": hyps,
		"conclusions": cons,
		"persons": [],
	}}
	gv.build({"clues":clues,"hypo":hypo,"persons":persons,"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await gv.get_tree().process_frame
	# 玩家真实操作：线索→推断→结论支撑边（含多线索共享推断）
	for h in hyps:
		for cid in h.get("gate_clue_ids", []):
			gv._derive.derive_hypo(cid, h.get("id",""))
			await gv.get_tree().process_frame
	for cn in cons:
		for hid in cn.get("gate_hypo_ids", []):
			gv._derive.derive_conclusion(hid, cn.get("id",""))
			await gv.get_tree().process_frame
	# CL2-4/CL2-6 以 KILLER 为目标
	for cn in cons:
		var tg = cn.get("target","")
		if "person:" in str(tg):
			gv._derive.derive_conclusion(cn.get("id",""), "person:"+str(tg).replace("person:",""))
			await gv.get_tree().process_frame
	gv._rebuild_graph(); await gv.get_tree().process_frame
	await gv.get_tree().process_frame

	# 1) 判定 reverse
	var hanchor := false
	for r in gv._relations:
		var fk:String = gv._fold._kind_of(str(r.get("from","")))
		var tk:String = gv._fold._kind_of(str(r.get("to","")))
		if fk=="person" or fk=="event" or tk=="person" or tk=="event":
			hanchor = true
	print("== reverse=%s persons=%d focus=%s ==" % [not hanchor, gv._persons.size(), gv._focus_person])

	# 2) 节点/范围
	var xmin:=1e9; var xmax:=-1e9; var ymin:=1e9; var ymax:=-1e9
	var n=0
	for id in gv._node_center:
		var c:Vector2 = gv._node_center[id]
		n+=1
		xmin=min(xmin,c.x); xmax=max(xmax,c.x); ymin=min(ymin,c.y); ymax=max(ymax,c.y)
	print("nodes=%d x[%.0f,%.0f] y[%.0f,%.0f]" % [n,xmin,xmax,ymin,ymax])

	# 3) 画布/缩放：调用 fit_view 得到提交前玩家看全的初始缩放
	var vp := Vector2(1280, 760)
	if gv._clip != null and gv._clip.size.x > 0:
		vp = gv._clip.size
	gv.fit_view()
	var fz: float = gv._zoom
	var bbox := Vector2(xmax-xmin, ymax-ymin)
	var margin := 90.0
	var ideal: float = min((vp.x-margin*2.0)/max(bbox.x,1.0), (vp.y-margin*2.0)/max(bbox.y,1.0))
	print("vp=%s" % str(vp))
	print("bbox_size=%.0f x %.0f  ideal_fit_scale=%.3f  fit_view_zoom=%.3f (clamp 0.25~1.6)" % [bbox.x, bbox.y, ideal, fz])

	# 4) 重叠检测（复用 L03 思路：矩形中心 ±half）
	var rects := {}
	for id in gv._node_center:
		var c:Vector2 = gv._node_center[id]
		var s = 60.0  # 半宽半高近似
		rects[id] = Rect2(c.x-s, c.y-s, 2*s, 2*s)
	var overlap_count := 0
	var idxs := rects.keys()
	for i in range(idxs.size()):
		for j in range(i+1, idxs.size()):
			if rects[idxs[i]].intersects(rects[idxs[j]]):
				overlap_count += 1
	print("overlap_pairs=%d (approx 120px box, 仅抽样语义)" % overlap_count)

	# 5) 多线索同列抽查
	var ok := true
	if gv._node_center.has("c201") and gv._node_center.has("c202"):
		var e1 := absf(gv._node_center["c201"].x-gv._node_center["c202"].x) < 0.5
		print("c201.x=%.2f c202.x=%.2f (equal=%s)" % [gv._node_center["c201"].x, gv._node_center["c202"].x, e1])
		ok = ok and e1
	if gv._node_center.has("c205") and gv._node_center.has("c206"):
		var e2 := absf(gv._node_center["c205"].x-gv._node_center["c206"].x) < 0.5
		print("c205.x=%.2f c206.x=%.2f (equal=%s)" % [gv._node_center["c205"].x, gv._node_center["c206"].x, e2])
		ok = ok and e2
	# 6) 规模不退化判定：fit_view 后内容在 (0.25 clamp) 下覆盖视口（不窄长条）、无重叠
	var no_overlap: bool = overlap_count == 0
	var covers_w: bool = bbox.x * maxf(fz, 0.25) <= vp.x
	var covers_h: bool = bbox.y * maxf(fz, 0.25) <= vp.y
	# 装箱大墙后内容应横向铺开呈近方形；跳过装箱的窄长条（高远大于宽）判为退化
	var fits := covers_w and covers_h
	ok = ok and no_overlap and fits
	print("no_overlap=%s covers_viewport(w=%s,h=%s)" % [no_overlap, covers_w, covers_h])
	print("L02_SCALE_RETEST: %s" % ("PASS" if ok else "FAIL"))

	# 6) 完整节点坐标 dump（按 x 分组看列结构）
	var by_x := {}
	for id in gv._node_center:
		var cx: float = gv._node_center[id].x
		var key: String = "%05d" % int(cx)
		if not by_x.has(key): by_x[key] = []
		by_x[key].append("%s(y%.0f)" % [id, gv._node_center[id].y])
	for k in by_x.keys():
		print("col x=%s : %s" % [k, " ".join(by_x[k])])

	# 7) parent_of dump（反转下线索为根，父应为空；推断父=线索）
	var po: Dictionary = gv._layout._build_parent_of() if gv._layout != null and gv._layout.has_method("_build_parent_of") else {}
	if not po.is_empty():
		print("--- parent_of (key child -> parent) ---")
		for k in po.keys():
			if str(k) in ["c201","c202","c203","c204","c205","c206","c209","c210","c211","H2-01","H2-03","H2-04","H2-06","H2-08"]:
				print("  %s -> %s" % [k, po[k]])
	
	quit()

func _initialize() -> void:
	await process_frame
	await _proc()
