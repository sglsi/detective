extends SceneTree

## 场景五改造冒烟：编译 scene5.gd + reasoning_hypothesis 自洽 + truth CH09A/CH09A2 完整性

func _initialize() -> void:
	await create_timer(0.1).timeout
	var ok := true
	var ids := {}
	var s5 = load("res://scripts/scene/scene5.gd")
	if s5 == null or not (s5 as Script).can_instantiate():
		print("SMOKE_FAIL scene5.gd load/can_instantiate")
		ok = false
	else:
		var inst = s5.new()
		var h = inst.reasoning_hypothesis()
		var bf: Dictionary = h.get("battlefield", {})
		for hp in bf.get("hypotheses", []):
			ids[str(hp.get("id", ""))] = true
		for c in bf.get("conclusions", []):
			for gid in c.get("gate_hypo_ids", []):
				if not ids.has(str(gid)):
					print("SMOKE_FAIL conclusion %s 引用缺失推断 %s" % [str(c.get("id", "")), str(gid)])
					ok = false
		print("SMOKE scene5 hypotheses=%d conclusions=%d contradictions=%d milestones=%d clues=%d" % [
			bf.get("hypotheses", []).size(), bf.get("conclusions", []).size(),
			bf.get("contradictions", []).size(), bf.get("milestones", []).size(), s5.CLUES.size()])
	# truth 完整性 + 场景五链的推断节点必须存在于 battlefield
	var T = load("res://data/case_branch_truth.gd")
	for bid in ["CH09A", "CH09A2"]:
		var b = T.branch(bid)
		if b.is_empty():
			print("SMOKE_FAIL truth missing " + bid)
			ok = false
			continue
		var nodes := {}
		for n in b.get("nodes", []):
			nodes[str(n.get("id", ""))] = true
			if str(n.get("layer", "")) == "hypo" and not ids.has(str(n.get("id", ""))):
				print("SMOKE_FAIL %s truth 推断 %s 不在 scene5 battlefield" % [bid, str(n.get("id", ""))])
				ok = false
		for e in b.get("edges", []):
			if not nodes.has(str(e.get("from", ""))) or not nodes.has(str(e.get("to", ""))):
				print("SMOKE_FAIL %s 边端点缺失 %s→%s" % [bid, str(e.get("from", "")), str(e.get("to", ""))])
				ok = false
		print("SMOKE truth %s nodes=%d edges=%d" % [bid, b.get("nodes", []).size(), b.get("edges", []).size()])
	print("SMOKE_ALL_OK" if ok else "SMOKE_ALL_FAIL")
	quit()
