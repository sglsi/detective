extends SceneTree

func _initialize() -> void:
	print("[test_registry] 构建注册表...")
	var reg_script = load("res://data/case_reasoning_registry.gd")
	var union: Dictionary = reg_script.get_hypo_union()
	var bf: Dictionary = union.get("battlefield", {})
	var hyps: Array = bf.get("hypotheses", [])
	var cons: Array = bf.get("conclusions", [])
	var all: Array = reg_script.get_all_nodes()
	print("[test_registry] 推断=%d 结论=%d 节点总数=%d" % [hyps.size(), cons.size(), all.size()])
	var ids := {}
	for n in all:
		ids[str(n.get("id",""))] = true
	var fails := 0
	for must in ["H2-01", "H3-01", "H2-03"]:   # 推断节点（C-06 属矛盾标记，非节点，不在此列）
		if not ids.has(must):
			print("[test_registry] FAIL 缺失节点: " + must)
			fails += 1
	var concl_ids := ""
	for c in cons:
		concl_ids += str(c.get("id","")) + " "
	print("[test_registry] 结论id: " + concl_ids)
	print("[test_registry] H2-01 来源=" + reg_script.scene_of("H2-01") + "  H3-01 来源=" + reg_script.scene_of("H3-01"))
	if reg_script.scene_of("H2-01") != "scene2" or reg_script.scene_of("H3-01") != "scene3":
		print("[test_registry] FAIL scene_of 错误")
		fails += 1
	# 校验深拷贝：改返回值不应污染缓存
	union["title"] = "MUT"
	if reg_script.get_hypo_union()["title"] != "":
		print("[test_registry] FAIL 深拷贝污染")
		fails += 1
	if fails > 0:
		print("[test_registry] RESULT: FAIL(%d)" % fails)
	else:
		print("[test_registry] RESULT: PASS")
	quit()
