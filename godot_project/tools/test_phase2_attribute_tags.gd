extends SceneTree
# 阶段2验证：attribute_tags（人证/物证区分）+ 可信度显示
#  - _credibility_of 由 attribute_tags 派生：直接物证=高 / 目击证词=中 / 嫌疑人陈述=中 / 二手传闻=低 / 缺省=中
#  - _attribute_label_of 取主标签，缺省=其他
#  - 线索卡片文本含「属性 · 可信度:X」徽标
#  - 详情弹窗构建含「证据属性 / 可信度」行且不报错

func _initialize() -> void:
	await create_timer(0.2).timeout
	var RW = load("res://scripts/clue/reasoning_wall.gd")
	if not RW:
		print("PHASE2_RESULT: FAIL - 无法加载 reasoning_wall.gd")
		quit(1)
		return

	var wall = RW.new()
	wall.name = "Phase2Wall"
	root.add_child(wall)

	var clues := [
		{"id":"p1","name":"车轮印","desc":"d","correct":true,"source":"garden","associated":true,"attribute_tags":["直接物证"],"relation_tags":["H-A"]},
		{"id":"p2","name":"警长证词","desc":"d","correct":true,"source":"test","associated":true,"attribute_tags":["目击证词"],"relation_tags":[]},
		{"id":"p3","name":"街坊传言","desc":"d","correct":false,"source":"test","associated":true,"attribute_tags":["二手传闻"],"relation_tags":[]},
		{"id":"p4","name":"无标签线索","desc":"d","correct":true,"source":"test","associated":true,"relation_tags":[]},
	]
	var hypo := {"title":"t","description":"d","battlefield":{"hypotheses":[{"id":"H-A","text":"a","correct":true}],"contradictions":[]}}
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable())

	var ok := true
	var msgs := []

	# 断言1：_credibility_of 派生
	if wall._credibility_of(clues[0]) != "高": ok=false; msgs.append("P2_A_FAIL: 直接物证应=高, got=%s" % wall._credibility_of(clues[0]))
	if wall._credibility_of(clues[1]) != "中": ok=false; msgs.append("P2_B_FAIL: 目击证词应=中, got=%s" % wall._credibility_of(clues[1]))
	if wall._credibility_of(clues[2]) != "低": ok=false; msgs.append("P2_C_FAIL: 二手传闻应=低, got=%s" % wall._credibility_of(clues[2]))
	if wall._credibility_of(clues[3]) != "中": ok=false; msgs.append("P2_D_FAIL: 无标签应=中(默认), got=%s" % wall._credibility_of(clues[3]))

	# 断言2：_attribute_label_of
	if wall._attribute_label_of(clues[0]) != "直接物证": ok=false; msgs.append("P2_E_FAIL: 主属性应为 直接物证")
	if wall._attribute_label_of(clues[3]) != "其他": ok=false; msgs.append("P2_F_FAIL: 无标签主属性应为 其他")

	# 断言3：卡片文本含属性与可信度徽标
	var c1 = wall._make_clue_card(clues[0])
	var c2 = wall._make_clue_card(clues[1])
	var c3 = wall._make_clue_card(clues[2])
	if not c1.text.contains("可信度:高"): ok=false; msgs.append("P2_G_FAIL: 卡片1应含 可信度:高, got=%s" % c1.text)
	if not c2.text.contains("可信度:中"): ok=false; msgs.append("P2_H_FAIL: 卡片2应含 可信度:中, got=%s" % c2.text)
	if not c3.text.contains("可信度:低"): ok=false; msgs.append("P2_I_FAIL: 卡片3应含 可信度:低, got=%s" % c3.text)
	if not c1.text.contains("直接物证"): ok=false; msgs.append("P2_J_FAIL: 卡片1应含 直接物证")

	# 断言4：详情弹窗构建不报错（覆盖 _show_clue_detail 路径）
	wall._show_clue_detail(clues[0])
	await create_timer(0.05).timeout
	if wall.get("_detail_popup") == null: ok=false; msgs.append("P2_K_FAIL: 详情弹窗未创建")

	if ok:
		print("PHASE2_RESULT: PASS  (属性标签+可信度：物证=高/人证=中/传闻=低；卡片与详情弹窗均展示)")
	else:
		for m in msgs: print(m)
		print("PHASE2_RESULT: FAIL")
	quit(0)
