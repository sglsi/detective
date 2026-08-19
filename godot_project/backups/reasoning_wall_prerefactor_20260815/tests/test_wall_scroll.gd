extends SceneTree

## 验证推理墙左侧线索库已改为可滚轮滚动：
##  1) _clue_list 垂直不再 EXPAND_FILL（否则 ScrollContainer 永不出现滚动条，最底按钮被盖）
##  2) _clue_list 与「调查记录」按钮同处于一个 ScrollContainer 内（整列可滚）
##  3) 多线索时列表子节点数量正确

func _process(_d: float) -> bool:
	var ok := true
	var msg := ""
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	if rw == null:
		print("SCROLL_RESULT: FAIL — 无法加载 reasoning_wall")
		quit(); return true

	var wall = rw.new()
	var clues := []
	for i in range(20):
		clues.append({"id":"C%d"%i, "name":"线索%d"%i, "desc":"描述", "correct":true, "category":"normal"})
	var hypo := {
		"chain_id":"test", "expected_clues":20, "insight_bonus":0,
		"hypotheses":[], "battle_hypotheses":[], "battle_contradictions":[], "milestones":[]
	}
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), {}, Callable(), true)
	root.add_child(wall)
	await create_timer(0.05).timeout

	var cl = wall._clue_list
	if cl == null:
		ok = false; msg = "找不到 _clue_list"
	else:
		if cl.size_flags_vertical != 0:
			ok = false; msg = "修复失效：_clue_list.size_flags_vertical=%d（应为 0，否则滚动条不出现）" % cl.size_flags_vertical
		var inner = cl.get_parent()
		var scroll = inner.get_parent() if inner else null
		if not (scroll is ScrollContainer):
			ok = false; msg = "结构错误：clue_list 的祖父不是 ScrollContainer"
		else:
			var kids: Array = inner.get_children()
			var ci: int = kids.find(cl)
			if ci < 0 or ci + 1 >= kids.size():
				ok = false; msg = "结构错误：滚动区内 clue_list 之后无「调查记录」行"
			else:
				var rec_row = kids[ci + 1]
				if not (rec_row is HBoxContainer):
					ok = false; msg = "结构错误：clue_list 之后不是 HBoxContainer"
				else:
					var found_rec := false
					for b in rec_row.get_children():
						if b is Button and b.text == "调查记录":
							found_rec = true
					if not found_rec:
						ok = false; msg = "滚动区底部未找到「调查记录」按钮"
		if cl.get_child_count() != 20:
			ok = false; msg = "线索子节点数=%d，期望 20" % cl.get_child_count()

	if ok:
		print("SCROLL_RESULT: PASS")
	else:
		print("SCROLL_RESULT: FAIL — %s" % msg)
	quit()
	return true
