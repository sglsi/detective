extends SceneTree

# 教学明细（missing/reversed/extra）逻辑断言：模拟玩家半成品推理链，核对 evaluator 逐项明细。

var done: bool = false

func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	var ev: Variant = load("res://scripts/clue/wall_branch_evaluator.gd")
	# 模拟玩家：只产出 W-A1/C-MAIN 两个节点，连 3 条真相边 + 1 条错误性质边
	var rels: Array = [
		{"from": "wrist", "to": "W-A1", "kind": "support", "dashed": false},
		{"from": "W-A1", "to": "C-MAIN", "kind": "support", "dashed": false},
		{"from": "person:NPC_WT", "to": "C-MAIN", "kind": "support", "dashed": false},  # 方向反
		{"from": "pose", "to": "W-B1", "kind": "relate", "dashed": false},              # 性质错
	]
	var nodes: Array = [
		{"id": "W-A1", "kind": "hypo", "data": {}},
	]
	var cons: Array = [{"id": "C-MAIN"}]
	var res: Variant = ev.call("evaluate", rels, nodes, cons, "scene1", true)
	if not (res is Dictionary):
		print("EVAL_FAIL")
		quit()
		return true
	var r: Dictionary = res as Dictionary
	var branch: Dictionary = {}
	for b in r.get("per_branch", []):
		if b is Dictionary and bool((b as Dictionary).get("active", false)):
			branch = b as Dictionary
	var fails: Array[String] = []
	# 期望值（真相 CH01W 2026-09-05 三层结论版：17 边 + 11 可产出节点（5 hypo+6 concl）= 28；
	# clue/person 不计入 T。missing_nodes 只列非线索非人物的未产出节点）
	# 玩家：W-A1/C-MAIN 两节点（2.0）+ wrist→W-A1 exact（1.0）+ person→C-MAIN reversed（0.5）= 3.5；
	# W-A1→C-MAIN 与 pose→W-B1(relate) 均不在真相 → extra×2
	var checks := [
		["truth=28", int(branch.get("truth", 0)) == 28],
		["hit=3.5", absf(float(branch.get("hit", 0.0)) - 3.5) < 0.01],
		["missing_nodes=9", (branch.get("missing_nodes", []) as Array).size() == 9],
		["missing_edges=15", (branch.get("missing_edges", []) as Array).size() == 15],
		["reversed_edges=1", (branch.get("reversed_edges", []) as Array).size() == 1],
		["extra_edges=2", (branch.get("extra_edges", []) as Array).size() == 2],
	]
	for c in checks:
		if not bool(c[1]):
			fails.append(str(c[0]))
	print("hit=%s built=%s truth=%s ratio=%s verdict=%s" % [
		_g(branch.get("hit", 0.0)), _g(branch.get("built", 0.0)), str(branch.get("truth", 0)),
		str(r.get("ratio", "?")), str(r.get("verdict", "?"))])
	print("missing_nodes: " + str(branch.get("missing_nodes", [])))
	print("missing_edges: " + _edges(branch.get("missing_edges", [])))
	print("reversed_edges: " + _edges(branch.get("reversed_edges", [])))
	print("extra_edges: " + _edges(branch.get("extra_edges", [])))
	if fails.is_empty():
		print("EVAL_DETAILS_OK")
	else:
		print("EVAL_DETAILS_FAIL: " + str(fails))
	quit()
	return true

func _g(v: Variant) -> String:
	return str(v)

func _edges(a: Array) -> String:
	var out: Array[String] = []
	for e in a:
		if e is Dictionary:
			var d: Dictionary = e as Dictionary
			out.append("%s->%s(%s)" % [str(d.get("from", "")), str(d.get("to", "")), str(d.get("kind", ""))])
		else:
			out.append(str(e))
	return ", ".join(PackedStringArray(out))
