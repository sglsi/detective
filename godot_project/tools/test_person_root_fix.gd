extends SceneTree
## 验证「人物恒为关系树根」修复：
##  A) 兜底——任何把人物写成子(from)的 _relations 边，_build_parent_of 仍让人物无父(=根)；
##  B) 入口——_add_edge(person, infer) 自动反转为 infer→person，推断父=人物，重排后 person 在手动位、下游跟随。
func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"pose","name":"华生军人站姿","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"华生不是原来的肤色","correct":true,"gate_clue_ids":["wrist"]},
		{"id":"W-B1","text":"华生是名军医","correct":true,"gate_clue_ids":["pose"]}],
		"conclusions":[
		{"id":"C-A1","text":"华生曾在热带长期生活","correct":true,"gate_hypo_ids":["W-A1"],"target":"person:NPC_WT"}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],
		"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("wrist","W-A1"); gv._derive_hypo("pose","W-B1")
	await process_frame
	gv._derive_conclusion("W-A1","C-A1")
	await process_frame
	gv._rebuild_graph()
	await process_frame

	# ── 基准：默认 person 是根 ──
	var pf0: Dictionary = gv._layout._build_parent_of()
	if pf0.has("NPC_WT"):
		ok = false; print("FAIL base) 默认 person 不应有父")
	else:
		log.append("base) 默认 person(NPC_WT) 为根 ✓")

	# ── A) 兜底：直接写一条 person→infer 反向边（模拟旧存档 / 异常预设）──
	gv._relations.append({"from":"NPC_WT","to":"W-A1","kind":"support","color_key":"green","dashed":false})
	var pfA: Dictionary = gv._layout._build_parent_of()
	if pfA.has("NPC_WT"):
		ok = false; print("FAIL A) 兜底失败：person 仍被写成子(from)，失根！")
	else:
		log.append("A) 兜底生效：person→infer 反向边下 person 仍是根 ✓")

	# 移除该异常边，回到正常态
	gv._relations = gv._relations.filter(func(r): return not (r.get("from","")=="NPC_WT" and r.get("to","")=="W-A1" and r.get("kind","")=="support"))

	# ── B) 真实入口：玩家手动连「人物→推断」(把人物拖到推断上会生成此调用) ──
	gv._edge._add_edge("NPC_WT", "W-A1", "support", "green", false)
	await process_frame
	var last: Dictionary = gv._relations.back() if not gv._relations.is_empty() else {}
	if last.get("from","") != "W-A1" or last.get("to","") != "NPC_WT":
		ok = false; print("FAIL B1) _add_edge 未反转 person→infer：得到 %s→%s" % [last.get("from",""), last.get("to","")])
	else:
		log.append("B1) _add_edge(person,infer) 自动反转为 infer→person ✓")
	var pfB: Dictionary = gv._layout._build_parent_of()
	if pfB.has("NPC_WT"):
		ok = false; print("FAIL B2) 反向后 person 仍有父(失根)")
	elif not gv._layout._descendants("NPC_WT").has("W-A1"):
		ok = false; print("FAIL B3) 反向后 W-A1 不在 person 子树内：%s" % str(gv._layout._descendants("NPC_WT")))
	else:
		log.append("B2/B3) 反向后 person 为根、W-A1 在其子树内(放射树 person→conclusion→W-A1) ✓")

	# ── B4) 重排：person 落在手动位，下游随 person 衍生（拖拽跟随） ──
	gv._root_anchor_pos["NPC_WT"] = Vector2(640, 920)
	if not ("NPC_WT" in gv._manual_nodes):
		gv._manual_nodes.append("NPC_WT")
	# person 子树含 W-A1(→C-A1) 与其下游；整墙应围绕手动位 (640,920) 生长，不再锚定旧根中心
	gv._rebuild_graph()
	await process_frame
	if not gv._node_center.has("NPC_WT"):
		ok = false; print("FAIL B4a) person 未落位")
	elif abs(gv._node_center["NPC_WT"].x - 640.0) > 1.0 or abs(gv._node_center["NPC_WT"].y - 920.0) > 1.0:
		ok = false; print("FAIL B4b) person 未在手动位(640,920)：%s" % str(gv._node_center["NPC_WT"]))
	else:
		log.append("B4) 重排后 person 钉在手动位(640,920) ✓")
	if not gv._node_center.has("W-A1"):
		ok = false; print("FAIL B4c) W-A1 未落位")
	elif abs(gv._node_center["W-A1"].x - 640.0) > 700.0 or abs(gv._node_center["W-A1"].y - 920.0) > 500.0:
		ok = false; print("FAIL B4d) W-A1 脱离 person 子树(偏离过远)：%s" % str(gv._node_center["W-A1"]))
	else:
		log.append("B4) 下游 W-A1 围绕 person 手动位衍生 ✓")

	for l in log: print("  - " + l)
	print("PERSON_ROOT_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
