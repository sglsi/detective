extends SceneTree
## 校验：scene2.gd 的 reasoning_hypothesis() 与 case_branch_truth.gd 场景二真相链（CH02/CH03）
## 在本场景范围内（排除跨场景线索 c309/c311/C_SOTCB_*）的推导门控一致，且引用的线索均为 scene2 真实热点。
## 裸 --script 下 autoload 不自动注册，故先解析 project.godot 的 [autoload] 段按引擎既定顺序全部注册。

func _register_autoloads() -> void:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	var lines := text.split("\n")
	var in_auto := false
	for line in lines:
		var s := line.strip_edges()
		if s == "[autoload]":
			in_auto = true
			continue
		if s.begins_with("[") and s != "[autoload]":
			in_auto = false
			continue
		if in_auto and s.contains("="):
			var eq := s.find("=")
			var name := s.substr(0, eq).strip_edges()
			var val := s.substr(eq + 1).strip_edges().trim_prefix("*").strip_edges().trim_prefix("\"").trim_prefix("'").strip_edges().trim_suffix("\"").trim_suffix("'")
			if val.begins_with("res://") and not Engine.has_singleton(name):
				var sc := load(val)
				if sc != null:
					Engine.register_singleton(name, sc.new())

func _init() -> void:
	_register_autoloads()
	var ok := true
	var sc := load("res://scripts/scene/scene2.gd")
	if sc == null:
		print("FAIL load scene2.gd")
		quit()
		return
	var inst = sc.new()
	var rh: Dictionary = inst.reasoning_hypothesis()
	var bf: Dictionary = rh.get("battlefield", {})

	var hotspot_ids: Array = []
	for h in inst.STREET_HOTSPOTS:
		hotspot_ids.append(str(h.get("id", "")))
	for h in inst.PATH_HOTSPOTS:
		hotspot_ids.append(str(h.get("id", "")))

	var hypo: Dictionary = {}
	for h in bf.get("hypotheses", []):
		hypo[str(h.get("id", ""))] = h

	# 期望（本场景）gate —— 对齐 case_branch_truth.gd CH02/CH03
	var expect := {
		"H2-01": ["c201", "c202", "c203", "c204"],
		"H2-04": ["c206"],
		"H2-05": ["c206"],
	}
	for hid in expect.keys():
		if not hypo.has(hid):
			print("FAIL missing hypo node %s" % hid)
			ok = false
			continue
		var got: Array = Array(hypo[hid].get("gate_clue_ids", []))
		for c in expect[hid]:
			if not (c in got):
				print("FAIL %s missing expected gate %s" % [hid, c])
				ok = false
			if not (c in hotspot_ids):
				print("FAIL %s gate %s not a scene2 hotspot" % [hid, c])
				ok = false
		for c in got:
			if not (c in hotspot_ids):
				print("FAIL %s gate %s not a scene2 hotspot" % [hid, c])
				ok = false
			if c.begins_with("c3") or c.begins_with("C_SOTCB"):
				print("FAIL %s references cross-scene clue %s (should NOT be in scene2 local preset)" % [hid, c])
				ok = false

	# H2-02/H2-03 不应引入跨场景线索
	for hid in ["H2-02", "H2-03"]:
		if hypo.has(hid):
			for c in Array(hypo[hid].get("gate_clue_ids", [])):
				if c.begins_with("c3") or c.begins_with("C_SOTCB"):
					print("FAIL %s references cross-scene clue %s" % [hid, c])
					ok = false

	# 结论 gate_hypo_ids 完整性
	var concl_exp := {
		"CL2-1": ["H2-01"], "CL2-2": ["H2-02", "H2-04"], "CL2-3": ["H2-03"],
	}
	var concl := {}
	for c in bf.get("conclusions", []):
		concl[str(c.get("id", ""))] = c
	for cid in concl_exp.keys():
		var got2: Array = Array(concl[cid].get("gate_hypo_ids", []))
		for h in concl_exp[cid]:
			if not (h in got2):
				print("FAIL %s missing gate_hypo %s" % [cid, h])
				ok = false

	print("SCENE2_CHAIN_ALIGN: " + ("PASS" if ok else "FAIL"))
	quit()
