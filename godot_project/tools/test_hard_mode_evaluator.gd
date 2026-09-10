## 困难模式四维定性反馈引擎 headless 单测
## 用法：godot --headless --script res://tools/test_hard_mode_evaluator.gd
##
## 验证「比对真相而非作者链」的四维口径在 HARD 自由推理下给出合理定性反馈。
## 测试图谱由 CaseBranchTruth.branches() 的「当前场景正式链」动态构造（结构真相源，含全场景），
## 避免硬编码案件文本，并验证：正式/HARD 墙排除练习链（与引擎 _truth_branches 口径一致）。
##   T1 完美解     —— scene2 正式链构造满节点+真相边 → 四维满分、优秀、3★、结论正确
##   T2 空墙       —— 无产出 → ratio=0、0★、conclusion_correct=false
##   T3 结论对无证据 —— 命中真相结论但全孤立 → 结论维>0、证据维=0、ratio 被拉低
##   T4 结论全错   —— 瞎 id 不命中任何真相 → conclusion_correct=false、0★
##   T5 缺核心结论 —— 仅命中非核心结论、跳过终局(core) → conclusion_correct=false、stars<=2
##   T6 derived 路径 —— 结论经 derived_conclusions 传入也能被标注命中（id 别名匹配）
##   T7 场景范围   —— scene3 累积真相结论集 ⊇ scene2
extends SceneTree

const Eval = preload("res://scripts/clue/hard_mode_evaluator.gd")
const Truth = preload("res://data/case_branch_truth.gd")

var _fail := 0


# 取某场景「非 practice」链（与引擎 _truth_branches 单场景口径一致）
func _scene_branches(scene_id: String) -> Array:
	var out: Array = []
	for b in Truth.branches():
		if str(b.get("scene", "")) != scene_id:
			continue
		if bool(b.get("practice", false)):
			continue
		out.append(b)
	return out


func _is_concl(id: String, b: Dictionary) -> bool:
	for n in b.get("nodes", []):
		if str(n.get("id", "")) == id and str(n.get("layer", "")) == "concl":
			return true
	return false


# 由场景正式链构造「完美解」玩家图谱（结论节点用 conclusion_ 前缀模拟真实画布 id）
func _perfect_graph(scene_id: String) -> Dictionary:
	var gn: Array = []
	var ed: Array = []
	for b in _scene_branches(scene_id):
		for n in b.get("nodes", []):
			var layer: String = str(n.get("layer", ""))
			if layer == "person" or layer == "clue":
				continue
			var nid: String = str(n.get("id", ""))
			var kind: String = "conclusion" if layer == "concl" else "hypo"
			var pid: String = ("conclusion_" + nid) if layer == "concl" else nid
			gn.append({"id": pid, "kind": kind, "text": ""})
		for e in b.get("edges", []):
			var ek: String = str(e.get("kind", ""))
			if ek != "support" and ek != "weak":
				continue
			var f: String = str(e.get("from", ""))
			var t: String = str(e.get("to", ""))
			var fid: String = ("conclusion_" + f) if _is_concl(f, b) else f
			var tid: String = ("conclusion_" + t) if _is_concl(t, b) else t
			ed.append({"from": fid, "to": tid, "kind": ek, "dashed": false})
	return {"nodes": gn, "edges": ed}


# 累积真相结论数（与引擎 _allowed_scenes 口径一致：到当前场景为止）
func _cumulative_concl_count(scene_id: String) -> int:
	var order: Array = ["scene1", "scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]
	var allowed: Dictionary = {}
	for sid in order:
		allowed[sid] = true
		if sid == scene_id:
			break
	if not allowed.has(scene_id):
		allowed[scene_id] = true
	var cnt: int = 0
	for b in Truth.branches():
		if bool(b.get("practice", false)):
			continue
		if not allowed.has(str(b.get("scene", ""))):
			continue
		for n in b.get("nodes", []):
			if str(n.get("layer", "")) == "concl":
				cnt += 1
	return cnt


func _init() -> void:
	print("===== 困难模式四维定性反馈引擎单测 =====")
	var scene: String = "scene2"

	# ── T1 完美解（scene2 正式链）──
	var pg: Dictionary = _perfect_graph(scene)
	var r1: Dictionary = Eval.evaluate(pg["edges"], pg["nodes"], [], scene, false)
	_expect("T1 four_dim=true", bool(r1.get("four_dim", false)), str(r1.get("four_dim")))
	_expect("T1 ratio≈1.0", absf(float(r1.get("ratio", 0.0)) - 1.0) < 0.02, "%.3f" % r1.get("ratio"))
	_expect("T1 三星", int(r1.get("stars", 0)) == 3, str(r1.get("stars")))
	_expect("T1 结论正确", bool(r1.get("conclusion_correct", false)), str(r1.get("conclusion_correct")))
	_expect("T1 等级=优秀", str(r1.get("grade", "")) == "优秀", str(r1.get("grade")))
	var f1: Dictionary = r1.get("four", {})
	print("  T1 四维: 结论=%.2f 证据=%.2f 结构=%.2f 步骤=%.2f" % [
		float(f1.get("conclusion", 0.0)), float(f1.get("evidence", 0.0)),
		float(f1.get("structure", 0.0)), float(f1.get("step", 0.0))])
	_expect("T1 结论维=1.0", absf(float(f1.get("conclusion", 0.0)) - 1.0) < 0.001, "%.2f" % f1.get("conclusion"))
	_expect("T1 证据维=1.0", absf(float(f1.get("evidence", 0.0)) - 1.0) < 0.001, "%.2f" % f1.get("evidence"))
	_expect("T1 结构维=1.0", absf(float(f1.get("structure", 0.0)) - 1.0) < 0.001, "%.2f" % f1.get("structure"))
	_expect("T1 步骤维=1.0", absf(float(f1.get("step", 0.0)) - 1.0) < 0.001, "%.2f" % f1.get("step"))

	# ── T2 空墙 ──
	var r2: Dictionary = Eval.evaluate([], [], [], scene, false)
	_expect("T2 ratio=0", absf(float(r2.get("ratio", -1.0))) < 0.001, "%.3f" % r2.get("ratio"))
	_expect("T2 0★", int(r2.get("stars", 3)) == 0, str(r2.get("stars")))
	_expect("T2 结论不正确", not bool(r2.get("conclusion_correct", true)), str(r2.get("conclusion_correct")))

	# ── T3 结论对但无证据（孤立）──
	# 取一个非核心真相结论 id（CL2-1）以 conclusion_ 前缀构造孤立玩家结论
	var gn3: Array = [{"id": "conclusion_CL2-1", "kind": "conclusion", "text": ""}]
	var r3: Dictionary = Eval.evaluate([], gn3, [], scene, false)
	_expect("T3 结论维>0(命中真相)", float(r3.get("four", {}).get("conclusion", 0.0)) > 0.0, "%.2f" % r3.get("four", {}).get("conclusion"))
	_expect("T3 证据维=0", absf(float(r3.get("four", {}).get("evidence", -1.0))) < 0.001, "%.2f" % r3.get("four", {}).get("evidence"))
	_expect("T3 ratio<0.25(被证据/结构拉低)", float(r3.get("ratio", 1.0)) < 0.25, "%.3f" % r3.get("ratio"))

	# ── T4 结论全错（瞎 id 不命中任何真相）──
	var gn4: Array = [
		{"id": "x1", "kind": "conclusion", "text": "华生是个木匠"},
		{"id": "x2", "kind": "conclusion", "text": "今天天气真好"},
	]
	var r4: Dictionary = Eval.evaluate([], gn4, [], scene, false)
	_expect("T4 结论不正确", not bool(r4.get("conclusion_correct", true)), str(r4.get("conclusion_correct")))
	_expect("T4 0★", int(r4.get("stars", 3)) == 0, str(r4.get("stars")))
	_expect("T4 ratio<0.25", float(r4.get("ratio", 1.0)) < 0.25, "%.3f" % r4.get("ratio"))

	# ── T5 缺核心结论（仅命中非核心 CL2-1，跳过 core CL2-4/CL2-6）──
	var gn5: Array = [
		{"id": "conclusion_CL2-1", "kind": "conclusion", "text": ""},
	]
	var ed5: Array = [
		{"from": "c201", "to": "conclusion_CL2-1", "kind": "support", "dashed": false},
	]
	var r5: Dictionary = Eval.evaluate(ed5, gn5, [], scene, false)
	_expect("T5 结论不正确(缺核心)", not bool(r5.get("conclusion_correct", true)), str(r5.get("conclusion_correct")))
	_expect("T5 stars<=2(结论错封顶)", int(r5.get("stars", 3)) <= 2, str(r5.get("stars")))

	# ── T6 derived_conclusions 路径也能被标注命中（id 别名匹配）──
	var dc6: Array = [{"id": "conclusion_CL2-1", "text": ""}]
	var r6: Dictionary = Eval.evaluate([], [], dc6, scene, false)
	_expect("T6 derived 命中真相", float(r6.get("four", {}).get("conclusion", 0.0)) > 0.0, "%.2f" % r6.get("four", {}).get("conclusion"))

	# ── T7 场景范围：scene3 累积真相结论集 ⊇ scene2 ──
	var c2: int = _cumulative_concl_count("scene2")
	var c3: int = _cumulative_concl_count("scene3")
	_expect("T7 scene2 含正式结论", c2 > 0, "scene2=%d" % c2)
	_expect("T7 scene3 ⊇ scene2", c3 >= c2, "scene2=%d scene3=%d" % [c2, c3])

	print("===== %s =====" % ("全部通过 ✅" if _fail == 0 else "失败 %d 项 ❌" % _fail))
	quit(_fail)


func _expect(name: String, cond: bool, detail: String) -> void:
	if cond:
		print("  [PASS] %s  (%s)" % [name, detail])
	else:
		_fail += 1
		print("  [FAIL] %s  (%s)" % [name, detail])
