extends Control

## 回归测试：华生教学链去除过渡结论 C-C1（用户 2026-09-10）
## 断言：① CH01W 不再含结论 C-C1；② C-C2 的 gate_hypo_ids == ["W-C1","W-C2"]（直接指向）；
## ③ C-MAIN 仍含 conclusion_C-C2；④ 所有 gate 引用都指向存在的节点（推断或结论）；
## ⑤ derive_truth(CH01W) 不含 C-C1 节点/边，且含 W-C1→C-C2、W-C2→C-C2、C-C2→C-MAIN。

var _pass := 0
var _fail := 0

func _ready() -> void:
	await get_tree().process_frame
	var ok := _run()
	print("=== 华生链重构 回归测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
	get_tree().quit(0 if ok else 1)

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)

func _run() -> bool:
	var rc := load("res://data/reasoning_chains.gd")
	var wd: Dictionary = rc.build_wall_dict("CH01W")
	_chk(not wd.is_empty(), "A：CH01W 墙数据可构建")

	var bf: Dictionary = wd.get("battlefield", {})
	var hypos: Array = bf.get("hypotheses", [])
	var concl: Array = bf.get("conclusions", [])
	var hypo_ids: Array = []
	for h in hypos:
		hypo_ids.append(str(h.get("id", "")))
	var concl_ids: Array = []
	for c in concl:
		concl_ids.append(str(c.get("id", "")))

	_chk("C-C1" not in concl_ids, "B：过渡结论 C-C1 已移除")
	_chk("W-C1" in hypo_ids and "W-C2" in hypo_ids, "C：推断 W-C1/W-C2 仍存在")

	# 找 C-C2
	var c2: Dictionary = {}
	for c in concl:
		if str(c.get("id","")) == "C-C2":
			c2 = c
	_chk(not c2.is_empty(), "D：结论 C-C2 存在")
	_chk(c2.get("gate_hypo_ids", []) == ["W-C1", "W-C2"], "E：C-C2 直接 gate 到 W-C1/W-C2（不再经 C-C1）")

	# C-MAIN 仍收敛 C-C2
	var cmain: Dictionary = {}
	for c in concl:
		if str(c.get("id","")) == "C-MAIN":
			cmain = c
	_chk("conclusion_C-C2" in cmain.get("gate_hypo_ids", []), "F：C-MAIN 仍含 conclusion_C-C2")

	# 所有 gate 引用指向存在节点
	var valid_ids := {}
	for h in hypos: valid_ids[str(h.get("id",""))] = true
	for c in concl: valid_ids[str(c.get("id",""))] = true
	var gate_ok := true
	for c in concl:
		for g in c.get("gate_hypo_ids", []):
			var gid: String = str(g)
			var bare: String = gid.replace("conclusion_", "")
			if not valid_ids.has(bare):
				gate_ok = false
				print("    [bad gate] %s -> %s" % [c.get("id"), gid])
	_chk(gate_ok, "G：所有结论 gate_hypo_ids 均指向存在的节点")

	# derive_truth 一致性
	var cbt := load("res://data/case_branch_truth.gd")
	var truth: Array = cbt.branches()
	var ch01w = null
	for b in truth:
		if str(b.get("id","")) == "CH01W":
			ch01w = b
	_chk(ch01w != null, "H：derive_truth 产出 CH01W 分支")
	if ch01w != null:
		var tnodes: Array = ch01w.get("nodes", [])
		var tedges: Array = ch01w.get("edges", [])
		var has_c1_node := tnodes.any(func(n): return str(n.get("id","")) == "C-C1")
		var has_c1_edge := tedges.any(func(e): return str(e.get("from","")) == "C-C1" or str(e.get("to","")) == "C-C1")
		_chk(not has_c1_node, "I：真相表不含 C-C1 节点")
		_chk(not has_c1_edge, "J：真相表不含 C-C1 边")
		var has_wc1_cc2 := tedges.any(func(e): return str(e.get("from",""))=="W-C1" and str(e.get("to",""))=="C-C2")
		var has_wc2_cc2 := tedges.any(func(e): return str(e.get("from",""))=="W-C2" and str(e.get("to",""))=="C-C2")
		var has_cc2_cmain := tedges.any(func(e): return str(e.get("from",""))=="C-C2" and str(e.get("to",""))=="C-MAIN")
		_chk(has_wc1_cc2, "K：真相表含 W-C1→C-C2")
		_chk(has_wc2_cc2, "L：真相表含 W-C2→C-C2")
		_chk(has_cc2_cmain, "M：真相表含 C-C2→C-MAIN")

	return _fail == 0
