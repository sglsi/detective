extends SceneTree

## P16 — 复现「兰斯对话线索加入推理墙无线索提示」
## 模拟 dialogue_manager 在 scene4 内联对话里授予 4 条兰斯线索（source = scene_id() = "scene4"），
## 再走 ReasoningWall.setup 渲染卡片，打印每张卡片文本，确认是否空白。

func _initialize() -> void:
	# 等一帧让 autoload（ClueSystem 等）就绪
	await create_timer(0.1).timeout
	_repro()
	quit()

func _repro() -> void:
	print("===== P16 兰斯线索 → 推理墙 复现 =====")
	var cs = root.get_node("/root/ClueSystem")

	# 1) 模拟 dialogue_manager 授予 scene4 的 4 条兰斯线索
	#    dialogue_manager 实际调用：
	#    ClueSystem.collect_clue_from_catalog(id, name, desc, correct, dialogue_resource.scene_name, w)
	#    scene4 内联对话 _make_dialogue_resource 把 scene_name 设为 scene_id() = "scene4"
	var lance = [
		{"id":"C_SOTCB_401","name":"巡警看到'醉汉'","desc":"案发后有人离开现场","correct":true,"w":2},
		{"id":"C_SOTCB_402","name":"醉汉身高6英尺+","desc":"与高大足迹吻合","correct":true,"w":5},
		{"id":"C_SOTCB_403","name":"醉汉红脸","desc":"误导项","correct":false,"w":0},
		{"id":"C_SOTCB_404","name":"醉汉棕色外衣","desc":"马车夫装束","correct":true,"w":5},
	]
	for c in lance:
		cs.collect_clue_from_catalog(c["id"], c["name"], c["desc"], c["correct"], "scene4", c["w"])

	# 2) 模拟 _sync_clues + _open_wall(src="scene4")
	var clues = cs.get_collected("scene4")
	print("get_collected(\"scene4\") 数量 = %d" % clues.size())
	for c in clues:
		print("  collected: id=%s | name=%s | label=%s | desc=%s" % [
			c.get("id",""), c.get("name",""), c.get("label", "<无label键>"), str(c.get("desc","")).substr(0,20)])

	# 3) 渲染推理墙，检查每张卡片文本
	var rw = load("res://scripts/clue/reasoning_wall.gd").new()
	root.add_child(rw)
	var hypo = {"title":"凶手是马车夫", "description":"综合线索"}
	rw.setup(clues, hypo, Callable(), Callable())

	print("----- 推理墙卡片文本 -----")
	var empty_count := 0
	for cid in rw._card_btns:
		var b = rw._card_btns[cid]
		var txt = b.text
		if txt.strip_edges() == "":
			empty_count += 1
		print("  卡片 id=%s | text=\"%s\" | visible=%s" % [cid, txt, b.visible])
	print("空白卡片数 = %d" % empty_count)
	if empty_count > 0:
		print("结论：存在空白卡片（无线索提示）—— 复现成功，需排查 name 字段为何为空")
	else:
		print("结论：卡片均显示 name，无空白。『无线索提示』可能指：点击卡片不展开描述/无 hint 弹层")
	quit()
