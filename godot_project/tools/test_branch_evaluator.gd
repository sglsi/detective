## 分枝（推理链）计分引擎 headless 单测
## 用法：godot --headless --script res://tools/test_branch_evaluator.gd
##
## 断言四件事（任何一条不过都说明评分被刷分或误伤）：
##   T1 完美解    —— 按真相建满 scene2 的两条 core 链 + 场景三~八全建 → 正确率 100%、3⭐
##   T2 只做短链  —— 只把最短的 CH02 做满、其余 core 链不动 → 远低于 80%，拿不到 3⭐
##   T3 乱连刷分  —— 真相边全建 + 额外乱连一堆错误边 → 正确率显著下降（分母变大）
##   T4 采纳误导  —— 完美解 + 对误导项建 support 边 → 三星硬条件失败（封顶 2⭐）
extends SceneTree

const Eval = preload("res://scripts/clue/wall_branch_evaluator.gd")
const Truth = preload("res://data/case_branch_truth.gd")

var _fail := 0


func _init() -> void:
	print("===== 分枝计分引擎单测 =====")
	var scene := "scene8"   # 终局：所有链都解锁

	# ── 造「完美解」：每条链的真相节点（hypo/concl）全部产出 + 真相边全建 ──
	var nodes: Array = []
	var edges: Array = []
	var cons: Array = []
	for b in Truth.branches():
		if str(b.get("scene", "")) == "scene1":
			continue          # 练习链不参与正式场景
		for n in b.get("nodes", []):
			var nid: String = str(n.get("id", ""))
			var layer: String = str(n.get("layer", ""))
			if layer == "hypo":
				nodes.append({"id": nid, "kind": "hypo", "data": {"correct": true}})
			elif layer == "concl":
				cons.append({"id": nid, "text": nid})
		for e in b.get("edges", []):
			edges.append({"from": str(e.get("from", "")), "to": str(e.get("to", "")),
				"kind": str(e.get("kind", "support")), "dashed": false})

	# T1 完美解
	var r1: Dictionary = Eval.evaluate(edges, nodes, cons, scene, false)
	_expect("T1 完美解 ratio=100%", absf(float(r1.get("ratio", 0.0)) - 1.0) < 0.001, str(r1.get("ratio")))
	_expect("T1 完美解 = 3⭐", int(r1.get("stars", 0)) == 3, str(r1.get("stars")))
	print("  ---- T1 逐链明细（truth=真相项 / built=玩家项 / hit=命中）----")
	for x in r1.get("per_branch", []):
		print("     %-6s %-14s core=%-5s active=%-5s T=%-3d B=%-3d H=%-5s R=%.2f" % [
			str(x.get("id")), str(x.get("name")), str(x.get("core")), str(x.get("active")),
			int(x.get("truth", 0)), int(x.get("built", 0)), str(x.get("hit")), float(x.get("ratio", 0.0))])

	# T2 只做最短的 CH02，其余 core 链不动
	var e2: Array = []
	var n2: Array = []
	var c2: Array = []
	for b in Truth.branches():
		if str(b.get("id", "")) != "CH02":
			continue
		for n in b.get("nodes", []):
			var layer: String = str(n.get("layer", ""))
			if layer == "hypo":
				n2.append({"id": str(n.get("id", "")), "kind": "hypo", "data": {"correct": true}})
			elif layer == "concl":
				c2.append({"id": str(n.get("id", "")), "text": str(n.get("id", ""))})
		for e in b.get("edges", []):
			e2.append({"from": str(e.get("from", "")), "to": str(e.get("to", "")),
				"kind": str(e.get("kind", "support")), "dashed": false})
	var r2: Dictionary = Eval.evaluate(e2, n2, c2, scene, false)
	_expect("T2 只做短链 < 80%（拿不到三星）", float(r2.get("ratio", 0.0)) < 0.80, str(r2.get("ratio")))

	# T3 乱连：完美解 + 一堆错误边（把每条链的节点两两乱连）
	var e3: Array = edges.duplicate()
	var all_ids: Array = []
	for b in Truth.branches():
		if str(b.get("scene", "")) == "scene1":
			continue
		for n in b.get("nodes", []):
			all_ids.append(str(n.get("id", "")))
	for i in range(mini(40, all_ids.size() - 1)):
		e3.append({"from": all_ids[i], "to": all_ids[all_ids.size() - 1 - i], "kind": "support", "dashed": false})
	var r3: Dictionary = Eval.evaluate(e3, nodes, cons, scene, false)
	_expect("T3 乱连后正确率显著下降", float(r3.get("ratio", 0.0)) < 0.80, str(r3.get("ratio")))
	_expect("T3 乱连拿不到三星", int(r3.get("stars", 0)) < 3, str(r3.get("stars")))

	# T4 采纳误导项：完美解 + 对 H2-M1 建 support 边
	var e4: Array = edges.duplicate()
	e4.append({"from": "c205", "to": "H2-M1", "kind": "support", "dashed": false})
	var n4: Array = nodes.duplicate()
	n4.append({"id": "H2-M1", "kind": "hypo", "data": {"correct": false}})
	var r4: Dictionary = Eval.evaluate(e4, n4, cons, scene, false)
	_expect("T4 采纳误导项 → hard_fail", bool(r4.get("hard_fail", false)), str(r4.get("adopted_misleads")))
	_expect("T4 采纳误导项 → 封顶 2⭐", int(r4.get("stars", 0)) == 2, str(r4.get("stars")))

	# T5 识破误导项：完美解 + 对 H2-M1 建 oppose 边（应加洞察、不 fail）
	var e5: Array = edges.duplicate()
	e5.append({"from": "c205", "to": "H2-M1", "kind": "oppose", "dashed": false})
	var r5: Dictionary = Eval.evaluate(e5, nodes, cons, scene, false)
	_expect("T5 识破误导项不 fail", not bool(r5.get("hard_fail", false)), str(r5.get("adopted_misleads")))

	# T6 场景二只评场景二的链（不该要求玩家完成场景八）
	var r6: Dictionary = Eval.evaluate(edges, nodes, cons, "scene2", false)
	var b6: Array = r6.get("per_branch", [])
	var ids6: Array = []
	for x in b6:
		ids6.append(str(x.get("id", "")))
	_expect("T6 场景二只含 scene2 链", ids6.has("CH02") and ids6.has("CH03") and not ids6.has("CH09F"), str(ids6))

	# T7 练习墙不计分（summary 明示）
	var r7: Dictionary = Eval.evaluate([], [], [], "scene1", true)
	_expect("T7 练习墙 summary 明示不计分", str(r7.get("summary", "")).find("不计分") >= 0, str(r7.get("summary")))

	# T8 空墙（什么都没做）→ 0 星、INSUFFICIENT
	var r8: Dictionary = Eval.evaluate([], [], [], scene, false)
	_expect("T8 空墙 = 0⭐", int(r8.get("stars", 3)) == 0, str(r8.get("stars")))

	print("===== %s =====" % ("全部通过 ✅" if _fail == 0 else "失败 %d 项 ❌" % _fail))
	quit(_fail)


func _expect(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("  ✅ %s  (%s)" % [name, detail])
	else:
		_fail += 1
		print("  ❌ %s  (%s)" % [name, detail])
