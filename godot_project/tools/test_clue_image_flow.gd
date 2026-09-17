extends SceneTree
## 回归（Problem1，2026-09-17）：实时收集路径必须把热点表的 image/anchor 透传进 ClueSystem，
## 否则推理墙线索卡无图（场景二三玩家实时收集的线索全部丢失图片）。
## 旧根因：detective_scene._on_clue_recorded 把 image/anchor 写死传 ""。
## 运行：godot --headless --script res://tools/test_clue_image_flow.gd --path godot_project

var _pass := 0
var CS: Node = null
var _fail := 0

func _initialize() -> void:
	await create_timer(0.1).timeout
	CS = root.get_node("/root/ClueSystem")
	var container := Node.new()
	get_root().add_child(container)

	# —— 场景二：热点带 image+anchor ——
	var s2 = load("res://scripts/scene/scene2.gd").new()
	container.add_child(s2)
	await create_timer(0.05).timeout
	var src2: String = s2.clue_source()
	if CS: CS.clear_source(src2)
	var hs0: Dictionary = s2.hotspots()[0]
	# 模拟实时路径：_clue_data 不带 image/anchor（旧线上形态）
	s2._on_clue_recorded(str(hs0["id"]), {"id": hs0["id"], "name": hs0.get("label", ""),
		"desc": hs0.get("desc", ""), "correct": true})
	await create_timer(0.05).timeout
	var got2 := _find_collected(src2, str(hs0["id"]))
	_chk(not got2.is_empty(), "场景二 %s 已入 ClueSystem" % str(hs0["id"]))
	_chk(str(got2.get("image", "")) == str(hs0.get("image", "")) and str(got2.get("image", "")) != "",
		"场景二 image 已透传（=%s）" % str(got2.get("image", "")))
	_chk(str(got2.get("anchor", "")) == str(hs0.get("anchor", "")) and str(got2.get("anchor", "")) != "",
		"场景二 anchor 已透传（=%s）" % str(got2.get("anchor", "")))
	var anch2: Dictionary = load("res://data/clue_image_anchors.gd").get_anchor(
		str(got2.get("image", "")), str(got2.get("anchor", "")))
	_chk(not anch2.is_empty(), "场景二 锚点表可命中（裁剪图有据）")

	# —— 场景三：热点只带 image（无 anchor 字段 → 回退线索 id 命中锚点表）——
	var s3 = load("res://scripts/scene/scene3.gd").new()
	container.add_child(s3)
	await create_timer(0.05).timeout
	var src3: String = s3.clue_source()
	if CS: CS.clear_source(src3)
	var h30: Dictionary = s3.hotspots()[0]
	s3._on_clue_recorded(str(h30["id"]), {"id": h30["id"], "name": h30.get("label", ""),
		"desc": h30.get("desc", ""), "correct": true})
	await create_timer(0.05).timeout
	var got3 := _find_collected(src3, str(h30["id"]))
	_chk(not got3.is_empty(), "场景三 %s 已入 ClueSystem" % str(h30["id"]))
	_chk(str(got3.get("image", "")) == str(h30.get("image", "")) and str(got3.get("image", "")) != "",
		"场景三 image 已透传（=%s）" % str(got3.get("image", "")))
	# 锚点表按「anchor 优先，否则线索 id」可命中（墙内 _build_image_section 同口径）
	var anc_name3: String = str(got3.get("anchor", "")) if str(got3.get("anchor", "")) != "" else str(got3.get("id", ""))
	var anch3: Dictionary = load("res://data/clue_image_anchors.gd").get_anchor(
		str(got3.get("image", "")), anc_name3)
	_chk(not anch3.is_empty(), "场景三 锚点表按线索 id 可命中（%s）" % anc_name3)

	print("CLUE_IMAGE_RESULT: ", "PASS(%d)" % _pass if _fail == 0 else "FAIL(%d)" % _fail)
	quit()


func _find_collected(src: String, cid: String) -> Dictionary:
	if CS == null: return {}
	for c in CS.get_collected(src):
		if str(c.get("id", "")) == cid: return c
	return {}


func _chk(cond: bool, msg: String) -> void:
	if cond: _pass += 1; print("  [PASS] ", msg)
	else: _fail += 1; print("  [FAIL] ", msg)
