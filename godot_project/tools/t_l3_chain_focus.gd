extends SceneTree
## L3 链聚焦功能探针：验证 ReasoningChains.get_chain_node_ids 返回正确
const Truth := preload("res://data/case_branch_truth.gd")

func _init():
	call_deferred("_run")

func _run():
	var st := [0, 0]   # [ok, fail]，引用传递使汇总与退出码真实（原按值传参聚合恒 0）

	# Test 1: CH01W 链节点 id 完整性
	var w_ids: Array = ReasoningChains.get_chain_node_ids("CH01W")
	_p("CH01W 节点数>=10", w_ids.size() >= 10, "实际 %d" % w_ids.size(), st)
	_p("CH01W 含 W-A1", w_ids.has("W-A1"), "", st)
	_p("CH01W 含 conclusion_C-A1", w_ids.has("conclusion_C-A1"), "", st)
	_p("CH01W 含 NPC_WT", w_ids.has("NPC_WT"), "", st)

	# Test 2: CH01M 链节点 id
	var m_ids: Array = ReasoningChains.get_chain_node_ids("CH01M")
	_p("CH01M 节点数>=10", m_ids.size() >= 10, "实际 %d" % m_ids.size(), st)
	_p("CH01M 含 MT-1", m_ids.has("MT-1"), "", st)
	_p("CH01M 含 conclusion_CL1-01", m_ids.has("conclusion_CL1-01"), "", st)
	_p("CH01M 含 NPC_MSG", m_ids.has("NPC_MSG"), "", st)

	# Test 3: 不存在的链返回空
	var no_ids: Array = ReasoningChains.get_chain_node_ids("NO_SUCH_CHAIN")
	_p("不存在的链返回空", no_ids.is_empty(), "", st)

	# Test 4: evaluator display_ratio 字段存在 + 难度校正随 override 生效（EASY×1.0 / HARD×1.25）
	# 2026-11-18(a)：原 `ev.evaluate_branch("CH01W", t)` 调不存在方法 → SCRIPT ERROR 挂起；改真实静态签名。
	# 2026-11-18(b)：上一版空图调用 ratio=0 → display=0，断言恒真（假绿），完全没验证校正。
	#   现改为：从 scene2 取第一条正式核心链(CH02)构造非空图（hypo→graph_nodes / concl→derived_conclusions /
	#   support/weak→relations），完美构建唯一链 → 得确定性 ratio≈0.5（另一 core 链 CH03 贡献分母但不致 0）。
	#   断言对实际 ratio 求期望，EASY/HARD 可区分；ratio>0.1 防退化前置是本探针防止再次假绿的唯一保险。
	var orig: Dictionary = WallBranchEvaluator.evaluate([], [], [], "scene1")
	_p("evaluator 有 display_ratio", orig.has("display_ratio"), "", st)
	var chain := _first_scene2_core_chain()
	if chain.is_empty():
		_p("构造到 scene2 正式核心链", false, "Truth.branches() 无 scene2 非练习核心链", st)
	else:
		var gn: Array = []
		var dc: Array = []
		var rel: Array = []
		var mid := {}
		for m in chain.get("misleads", []):
			mid[WallBranchEvaluator.norm(str(m.get("id", "")))] = true
		for n in chain.get("nodes", []):
			var l: String = str(n.get("layer", ""))
			if l in ["hypo", "concl"] and not mid.has(WallBranchEvaluator.norm(str(n.get("id", "")))):
				var nd := {"id": str(n.get("id", "")), "text": str(n.get("text", ""))}
				if l == "hypo":
					nd["kind"] = "hypo"
					gn.append(nd)
				else:
					dc.append(nd)
		for e in chain.get("edges", []):
			var ek: String = str(e.get("kind", ""))
			if ek in ["support", "weak"]:
				var ef: String = WallBranchEvaluator.norm(str(e.get("from", "")))
				var et: String = WallBranchEvaluator.norm(str(e.get("to", "")))
				if mid.has(ef) or mid.has(et):
					continue
				rel.append({"from": str(e.get("from", "")), "to": str(e.get("to", "")), "kind": ek})
		var base: Dictionary = WallBranchEvaluator.evaluate(rel, gn, dc, "scene2")
		var ratio: float = float(base.get("ratio", -1.0))
		_p("防退化：ratio>0.1", ratio > 0.1, "ratio=%.3f（构造失败则无法验证校正）" % ratio, st)
		var e0: Dictionary = WallBranchEvaluator.evaluate(rel, gn, dc, "scene2", false, [], 0)   # EASY ×1.0
		var d0: float = float(e0.get("display_ratio", -1.0))
		_p("EASY override=0: display==ratio", abs(d0 - ratio) < 0.001,
			"ratio=%.3f display=%.3f 期望=%.3f" % [ratio, d0, ratio], st)
		var e2: Dictionary = WallBranchEvaluator.evaluate(rel, gn, dc, "scene2", false, [], 2)   # HARD ×1.25
		var d2: float = float(e2.get("display_ratio", -1.0))
		var exp2: float = minf(ratio * 1.25, 1.0)
		_p("HARD override=2: display==min(1.25r,1)", abs(d2 - exp2) < 0.001,
			"ratio=%.3f display=%.3f 期望=%.3f" % [ratio, d2, exp2], st)

	print("\n===== RESULT: %d passed, %d failed =====" % [st[0], st[1]])
	quit(0 if st[1] == 0 else 1)

func _p(name: String, cond: bool, detail: String, st: Array):
	if cond:
		print("✅ %s%s" % [name, " ("+detail+")" if detail else ""])
		st[0] += 1
	else:
		print("❌ %s — %s" % [name, detail])
		st[1] += 1

## 取 scene2 第一条正式（非练习）核心链，用于 Test4 构造真实图。
func _first_scene2_core_chain() -> Dictionary:
	for b in Truth.branches():
		if str(b.get("scene", "")) != "scene2":
			continue
		if bool(b.get("practice", false)):
			continue
		if not bool(b.get("core", false)):
			continue
		return b
	return {}
