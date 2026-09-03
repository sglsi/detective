extends SceneTree

# 存档复盘工具（配合侧栏「导出存档」按钮使用）
# 用法: GODOT --headless --path . -s res://tools/analyze_save_report.gd -- <save_export.json>
# 读取存档 JSON 中的 wall_state_watson / wall_state_messenger，
# 用 WallBranchEvaluator（与游戏内同一评分引擎）复算并输出逐项缺口明细。
# 注：存档未持久化 graph_nodes/derived_conclusions，节点维度按「relations 端点出现即产出」近似。

func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("USAGE: analyze_save_report.gd -- <save_export.json>")
		quit()
		return true
	var f := FileAccess.open(args[0], FileAccess.READ)
	if f == null:
		print("OPEN_FAIL: " + args[0])
		quit()
		return true
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		print("PARSE_FAIL: 存档 JSON 不是对象")
		quit()
		return true
	var data: Dictionary = parsed as Dictionary
	if str(data.get("kind", "")) == "wall_state_export":
		var w: Dictionary = data.get("wall", {}) as Dictionary
		var ws2: Dictionary = w.get("wall_state", {}) as Dictionary
		if ws2.is_empty():
			print("（该导出中 wall_state 为空——墙尚未产生连线？）")
		else:
			_report("chain=%s source=%s" % [str(w.get("chain_id", "?")), str(w.get("source", "?"))], ws2)
			var lb: Dictionary = w.get("last_branch", {}) as Dictionary
			if not lb.is_empty():
				print("\n[导出时游戏内评分] ratio=%s insight=%s" % [str(lb.get("ratio", "?")), str(lb.get("insight_ratio", "?"))])
		quit()
		return true
	var ss: Dictionary = data.get("scene_state", {})
	print("slot=%s timestamp=%s scene=%s phase=%s" % [
		str(data.get("slot", "?")), str(data.get("timestamp", "?")),
		str(data.get("scene_id", "?")), str(ss.get("phase", "?"))])
	print("clue_ids=%s" % [str(data.get("collected_clues", data.get("scene_state", {}).get("clue_ids", [])))])
	for key in ["wall_state_watson", "wall_state_messenger"]:
		var ws: Variant = ss.get(key, {})
		if not (ws is Dictionary) or (ws as Dictionary).is_empty():
			print("\n== %s: （存档中无此墙状态）==" % key)
			continue
		_report(key, ws as Dictionary)
	quit()
	return true

func _report(key: String, ws: Dictionary) -> void:
	print("\n========== %s ==========" % key)
	var rels: Array = ws.get("relations", [])
	var bf: Dictionary = ws.get("battlefield", {})
	var seen := {}
	for r in rels:
		if not (r is Dictionary):
			continue
		seen[norm(str((r as Dictionary).get("from", "")))] = true
		seen[norm(str((r as Dictionary).get("to", "")))] = true
	var nodes: Array = []
	for nid in seen.keys():
		nodes.append({"id": str(nid), "kind": "hypo", "data": {}})
	var ev: Variant = load("res://scripts/clue/wall_branch_evaluator.gd")
	var res: Variant = ev.call("evaluate", rels, nodes, [], "scene1", true)
	if not (res is Dictionary):
		print("EVAL_FAIL")
		return
	var r: Dictionary = res as Dictionary
	print("verdict=%s branch_ratio=%s insight_ratio=%s negated_misleads=%s" % [
		str(r.get("verdict", "?")), str(r.get("ratio", "?")), str(r.get("insight_ratio", "?")), str(r.get("negated_misleads", []))])
	for b in r.get("per_branch", []):
		if not (b is Dictionary) or not bool((b as Dictionary).get("active", false)):
			continue
		var bd: Dictionary = b as Dictionary
		print("【%s】命中 %s / 真相 %s 项（节点产出 %s）" % [
			str(bd.get("name", "?")), _g(bd.get("hit", 0.0)),
			str(bd.get("truth", 0)), _g(bd.get("built", 0.0))])
		var mn: Array = bd.get("missing_nodes", [])
		if not mn.is_empty():
			print("  缺节点: " + ", ".join(PackedStringArray(_str_arr(mn))))
		var me: Array = bd.get("missing_edges", [])
		if not me.is_empty():
			print("  缺连线: " + _edges_str(me))
		var rev: Array = bd.get("reversed_edges", [])
		if not rev.is_empty():
			print("  方向反: " + _edges_str(rev))
		var ee: Array = bd.get("extra_edges", [])
		if not ee.is_empty():
			print("  多余连线(拉低正确率): " + _edges_str(ee))
	print("  战场按钮(battlefield): " + str(bf))
	print("  存档 verified=%s verdict=%s" % [str(ws.get("verified", false)), str(ws.get("verdict", 0))])

func _g(v: Variant) -> String:
	return "%g" % float(v)

func _str_arr(a: Array) -> Array[String]:
	var out: Array[String] = []
	for e in a:
		out.append(str(e))
	return out

func _edges_str(a: Array) -> String:
	var out: Array[String] = []
	for e in a:
		if e is Dictionary:
			var d: Dictionary = e as Dictionary
			out.append("%s->%s(%s)" % [str(d.get("from", "")), str(d.get("to", "")), str(d.get("kind", ""))])
		else:
			out.append(str(e))
	return ", ".join(PackedStringArray(out))

func norm(pid: String) -> String:
	if pid.begins_with("conclusion_"):
		return pid.substr("conclusion_".length())
	if pid.begins_with("person:"):
		return pid.substr("person:".length())
	return pid
