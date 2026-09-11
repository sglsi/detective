## 诊断单测：验证「玩家用『添文本框』新增的节点（id 形如 note_conclusion_0 / note_hypo_0）
## 是否被 HardModeEvaluator 的 `if gid.begins_with("note_"): continue` 整段跳过 → 四维全 0 → 0★。
## 用法：godot --headless --script res://tools/test_note_id_skip.gd
extends SceneTree

const Eval = preload("res://scripts/clue/hard_mode_evaluator.gd")

func _init() -> void:
	print("===== 诊断：note_ 前缀是否导致困难模式评分塌 0 =====")

	# 同一张玩家图，两种 id 命名：
	#  (A) 真实游戏：add_text_node 产出 id = "note_<kind>_<seq>"
	#  (B) 对照：去掉 note_ 前缀（id = "<kind>_<seq>"）
	var base_concl: Array = [
		{"text": "阿富汗服役", "kind": "conclusion"},
		{"text": "在热带生活过", "kind": "conclusion"},
		{"text": "受外伤", "kind": "conclusion"},
		{"text": "军医", "kind": "conclusion"},
	]
	var base_hypo: Array = [
		{"text": "被晒黑的", "kind": "hypo"},
		{"text": "大病初愈", "kind": "hypo"},
		{"text": "从事医务工作", "kind": "hypo"},
		{"text": "当过兵", "kind": "hypo"},
	]

	var nodes_note: Array = []
	var nodes_clean: Array = []
	var i := 0
	for c in base_concl:
		nodes_note.append({"id": "note_conclusion_%d" % i, "kind": c["kind"], "text": c["text"]})
		nodes_clean.append({"id": "conclusion_%d" % i, "kind": c["kind"], "text": c["text"]})
		i += 1
	i = 0
	for h in base_hypo:
		nodes_note.append({"id": "note_hypo_%d" % i, "kind": h["kind"], "text": h["text"]})
		nodes_clean.append({"id": "hypo_%d" % i, "kind": h["kind"], "text": h["text"]})
		i += 1

	# 边：推断→结论→人物（support + target），注意 from/to 须与 node id 一致
	var edges_note: Array = [
		{"from": "note_hypo_0", "to": "note_conclusion_1", "kind": "support", "dashed": false},
		{"from": "note_hypo_1", "to": "note_conclusion_2", "kind": "support", "dashed": false},
		{"from": "note_hypo_2", "to": "note_conclusion_3", "kind": "support", "dashed": false},
		{"from": "note_hypo_3", "to": "note_conclusion_3", "kind": "support", "dashed": false},
		{"from": "note_conclusion_1", "to": "note_conclusion_0", "kind": "support", "dashed": false},
		{"from": "note_conclusion_2", "to": "note_conclusion_0", "kind": "support", "dashed": false},
		{"from": "note_conclusion_3", "to": "note_conclusion_0", "kind": "support", "dashed": false},
		{"from": "note_conclusion_0", "to": "person:NPC_WT", "kind": "target", "dashed": false},
	]
	var edges_clean: Array = []
	for e in edges_note:
		edges_clean.append({
			"from": str(e["from"]).replace("note_", ""),
			"to": str(e["to"]).replace("note_", ""),
			"kind": e["kind"], "dashed": e["dashed"]
		})

	_run("【真实游戏】note_ 前缀节点", edges_note, nodes_note)
	_run("【对照】去掉 note_ 前缀", edges_clean, nodes_clean)

	quit(0)


func _run(label: String, edges: Array, nodes: Array) -> void:
	print("\n--- " + label + " ---")
	var res: Dictionary = Eval.evaluate(edges, nodes, [], "scene1", true)
	print("  ratio=%.3f  stars=%d  conclusion_correct=%s  grade=%s" % [
		float(res.get("ratio", 0.0)), int(res.get("stars", 0)),
		str(res.get("conclusion_correct", false)), str(res.get("grade", ""))
	])
	var f: Dictionary = res.get("four", {})
	print("  结论=%.2f 证据=%.2f 结构=%.2f 步骤=%.2f" % [
		float(f.get("conclusion", 0.0)), float(f.get("evidence", 0.0)),
		float(f.get("structure", 0.0)), float(f.get("step", 0.0))
	])
