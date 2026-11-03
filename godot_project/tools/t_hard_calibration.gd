extends SceneTree
const Eval = preload("res://scripts/clue/hard_mode_evaluator.gd")
const Truth = preload("res://data/case_branch_truth.gd")

func _init():
	call_deferred("_run")

func _run():
	var scene := "scene2"
	var pg: Dictionary = _perfect(scene)
	var total_concl: int = 0
	var total_hypo: int = 0
	for n in pg.nodes:
		if str(n.get("kind","")) == "conclusion": total_concl += 1
		else: total_hypo += 1
	print("scene2 玩家侧：%d结论 / %d推断 / %d边" % [total_concl, total_hypo, pg.edges.size()])
	print("")
	print("%-12s %6s %6s  %3s  %s" % ["水平", "ratio", "disp_r", "★", "结论/证据/结构/步骤"])
	print("------------------------------------------------------------")
	_p("100%完美", _eval(pg, scene))
	_p("75%水平", _eval(_subset(pg, 0.75, 0.75), scene))
	_p("50%水平", _eval(_subset(pg, 0.5, 0.5), scene))
	_p("30%水平", _eval(_subset(pg, 0.3, 0.4), scene))
	_p("仅核心结论", _eval(_core_only(pg), scene))
	_p("方向全错自洽", _eval(_wrong(total_concl, total_hypo, pg.edges.size()), scene))
	_p("空墙", _eval({"nodes": [], "edges": []}, scene))
	
	print("")
	print("=== EASY/NORMAL 参考 ===")
	print("100%真相边 → ratio=1.00  ★3")
	print(" 75%真相边 → ratio=0.75  ★2")
	print(" 50%真相边 → ratio=0.50  ★1~2")
	print(" 25%真相边 → ratio=0.25  ★1")
	print("  0%        → ratio=0.00  ★0")
	quit(0)

func _eval(g: Dictionary, scene: String) -> Dictionary:
	return Eval.evaluate(g.edges, g.nodes, [], scene, false)

func _p(name: String, r: Dictionary):
	var f: Dictionary = r.get("four", {})
	var dr: float = float(r.get("display_ratio", r.get("ratio", 0)))
	print("%-12s %6.3f %6.3f  ★%d  %.2f/%.2f/%.2f/%.2f" % [
		name, float(r.get("ratio",0)), dr, int(r.get("stars",0)),
		float(f.get("conclusion",0)), float(f.get("evidence",0)),
		float(f.get("structure",0)), float(f.get("step",0))])

func _perfect(scene_id: String) -> Dictionary:
	var gn: Array = []
	var ed: Array = []
	var concl_ids: Dictionary = {}
	var hypo_ids: Dictionary = {}
	for b in Truth.branches():
		if str(b.get("scene","")) != scene_id: continue
		if bool(b.get("practice", false)): continue
		for n in b.get("nodes", []):
			var l: String = str(n.get("layer",""))
			if l == "person" or l == "clue": continue
			var nid: String = str(n.get("id",""))
			var kind: String = "conclusion" if l == "concl" else "hypo"
			var pid: String = ("conclusion_"+nid) if l == "concl" else nid
			gn.append({"id": pid, "kind": kind, "text": ""})
			if l == "concl": concl_ids[pid] = true
			else: hypo_ids[pid] = true
		for e in b.get("edges", []):
			var ek: String = str(e.get("kind",""))
			if ek != "support" and ek != "weak": continue
			var f: String = str(e.get("from",""))
			var t: String = str(e.get("to",""))
			var fid: String = "conclusion_"+f if concl_ids.has("conclusion_"+f) else f
			var tid: String = "conclusion_"+t if concl_ids.has("conclusion_"+t) else t
			ed.append({"from": fid, "to": tid, "kind": ek, "dashed": false})
	return {"nodes": gn, "edges": ed}

func _subset(g: Dictionary, concl_ratio: float, hypo_ratio: float) -> Dictionary:
	var concls: Array = []
	var hypos: Array = []
	for n in g.nodes:
		if str(n.get("kind","")) == "conclusion": concls.append(n)
		else: hypos.append(n)
	var keep_concl: int = max(1, int(float(concls.size()) * concl_ratio))
	var keep_hypo: int = max(0, int(float(hypos.size()) * hypo_ratio))
	var kept_concl: Array = concls.slice(0, keep_concl)
	var kept_hypo: Array = hypos.slice(0, keep_hypo)
	var kept_ids: Dictionary = {}
	for n in kept_concl: kept_ids[n.id] = true
	for n in kept_hypo: kept_ids[n.id] = true
	var kept_edges: Array = []
	for e in g.edges:
		if kept_ids.has(str(e.from)) and kept_ids.has(str(e.to)):
			kept_edges.append(e)
	return {"nodes": kept_concl + kept_hypo, "edges": kept_edges}

func _core_only(g: Dictionary) -> Dictionary:
	var concls: Array = []
	var hypos: Array = []
	for n in g.nodes:
		if str(n.get("kind","")) == "conclusion": concls.append(n)
		else: hypos.append(n)
	var core_concl: Dictionary = concls[0]
	var some_hypos: Array = hypos.slice(0, 2)
	var kept_ids: Dictionary = {core_concl.id: true}
	for h in some_hypos: kept_ids[h.id] = true
	var kept_edges: Array = []
	for e in g.edges:
		if kept_ids.has(str(e.from)) and kept_ids.has(str(e.to)):
			kept_edges.append(e)
	return {"nodes": [core_concl] + some_hypos, "edges": kept_edges}

func _wrong(nc: int, nh: int, ne: int) -> Dictionary:
	var gn: Array = []
	for i in range(nc): gn.append({"id":"wc_%d"%i, "kind":"conclusion", "text":""})
	for i in range(nh): gn.append({"id":"wh_%d"%i, "kind":"hypo", "text":""})
	var ed: Array = []
	var max_e: int = min(ne, nc*nh)
	for i in range(max_e):
		var hi: int = i % nh
		var ci: int = int(i / nh) % nc
		ed.append({"from":"wh_%d"%hi, "to":"wc_%d"%ci, "kind":"support", "dashed":false})
	return {"nodes": gn, "edges": ed}
