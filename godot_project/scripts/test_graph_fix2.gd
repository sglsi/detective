extends Control

## 四问题回归测试（2026-08-20 第二批）：
##  问题1：取消右键 → 打标签/标记状态/删除连线全部改由节点详情卡按钮提供
##  问题2：图谱内新增「提交验证」按钮 → 转发推理墙 _on_verify_pressed（可提交推进）
##  问题3：结论节点红/橙/黄/绿按图内关系实时推算（不再冻结 build 快照，无需退出重进）
##  问题4：MODE_C 下只有一个「结论」文本框（去掉重复追加）

var _pass := 0
var _fail := 0
var _verify_flag := false          # 闭包陷阱：lambda 按值捕获局部变量，改外层须用成员变量


func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


func _mk_controller(data: Dictionary) -> Control:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	gv.name = "GV"
	add_child(gv)
	gv.build(data)
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1280, 720)
		gv._rebuild_graph()
	return gv


func _sample_data() -> Dictionary:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true,"associated":true,
			"related_npcs":["NPC_HOP"],"relation_tags":["H1"],"attribute_tags":["直接物证"]},
		{"id":"c2","name":"脚印","desc":"步幅大","correct":true,"associated":true,
			"related_npcs":["NPC_HOP","NPC_DRE"],"relation_tags":["H1"],"attribute_tags":["痕迹"]},
		{"id":"c3","name":"假证词","desc":"说谎","correct":false,"associated":false,
			"related_npcs":[],"relation_tags":[],"attribute_tags":["嫌疑人陈述"]},
	]
	var hypo := {
		"title":"马车夫作案","case_name":"血字的研究","chain_id":"2",
		"battlefield":{"hypotheses":[{"id":"H1","text":"凶手乘出租马车","correct":true}],"contradictions":[]}
	}
	var relations := [{"from":"c1","to":"H1","kind":"support"}]
	var persons := [{"id":"NPC_HOP","name":"霍普"},{"id":"NPC_DRE","name":"德雷伯"}]
	var ss := {"graph_view_mode":0,"graph_focus":"NPC_HOP","graph_tutorial_seen":true}
	# 注意：verdict 故意传 0（红），用于验证「不被冻结、实时推算」（问题3）
	return {"clues":clues,"hypo":hypo,"relations":relations,"persons":persons,
		"focus_person":"NPC_HOP","difficulty":1,"editable":true,"verdict":0,
		"show_toolbar":true,"state_store":ss,"on_tag":Callable(),"on_add_edge":Callable(),
		"on_remove_relation":Callable(),"on_close":Callable()}


func _run() -> void:
	# ================= 问题4：只有一个结论框 =================
	var data := _sample_data()
	var gv := _mk_controller(data)
	var nodes: Array = gv._node_list()
	var concls: Array = nodes.filter(func(nd): return nd.kind == "conclusion")
	_chk(concls.size() == 1, "Fix4-A：MODE_C 节点列表只有一个 conclusion")
	_chk(gv._node_views.has("conclusion"), "Fix4-B：结论节点已渲染")
	var concl_ids: Array = nodes.filter(func(nd): return nd.kind == "conclusion" and nd.label == "有点道理")
	_chk(concl_ids.size() <= 1, "Fix4-C：结论标签文本不重复")

	# ================= 问题3：结论实时推算（不冻结 verdict） =================
	# 数据：c1/c2 正确关联(2) + c1→H1 support(1) = 3 → 「说得通」绿；data 传的 verdict:0 应被忽略
	_chk(gv._data._verdict_text() == "说得通", "Fix3-A：verdict 不被 build 快照冻结（传 verdict:0 仍实时算出说得通）")
	_chk(gv._data._verdict_color() == gv.COL_GREEN, "Fix3-B：结论色为绿（说得通）")
	var concl_label := ""
	for l in gv._node_views["conclusion"].find_children("*", "Label", true, false):
		if (l as Label).text == "说得通":
			concl_label = "found"
	_chk(concl_label == "found", "Fix3-C：结论节点卡片文本已按实时判定显示「说得通」")
	# 删掉唯一 support 关系 → support=2 → 「有点道理」黄（即时降级，无需退出重进）
	gv._remove_edge("c1", "H1", "support")
	_chk(gv._data._verdict_text() == "有点道理", "Fix3-D：删连线后结论即时降级为「有点道理」")
	_chk(gv._data._verdict_color() == gv.COL_YELLOW, "Fix3-E：结论色即时变黄")
	# 加一条虚线 support → 虚线不计入判定 → 仍是「有点道理」
	gv._add_edge("c1", "H1", "support", "green", true)
	_chk(gv._data._verdict_text() == "有点道理", "Fix3-F：虚线（存疑）支持连线不计入判定")
	# 删虚线、加实线 → 恢复「说得通」绿
	gv._remove_edge("c1", "H1", "support")
	gv._add_edge("c1", "H1", "support", "green", false)
	_chk(gv._data._verdict_text() == "说得通", "Fix3-G：实线支持连线计入后结论恢复「说得通」")

	# ================= 问题1：取消右键，功能移到详情卡 =================
	# 非线索节点调 _open_tag_menu 直接返回，不弹 PopupMenu
	gv._open_tag_menu("H1", "hypo")
	var popups: Array = gv.get_children().filter(func(c): return c is PopupMenu)
	_chk(popups.is_empty(), "Fix1-A：推断节点不再弹出右键菜单")
	# 线索节点详情卡：应含「和谁有关 ▾」「标记状态 ▾」「删除连线」按钮
	gv._show_detail("c1", "clue")
	_chk(gv._detail_card != null and is_instance_valid(gv._detail_card), "Fix1-B：点击线索打开详情卡")
	var has_tag := false
	var has_status := false
	var has_del := false
	for b in gv._detail_card.find_children("*", "Button", true, false):
		var t: String = (b as Button).text
		if t.begins_with("和谁有关"): has_tag = true
		if t.begins_with("标记状态"): has_status = true
		if t.begins_with("✕ 删除"): has_del = true
	_chk(has_tag, "Fix1-C：详情卡含「和谁有关 ▾」打标签入口")
	_chk(has_status, "Fix1-D：详情卡含「标记状态 ▾」入口")
	_chk(has_del, "Fix1-E：详情卡含「删除连线」按钮（替代右键）")
	# 连线删除按钮绑定回调不崩（直接驱动 _on_detail_delete）
	var card_ref: Control = gv._detail_card
	gv._on_detail_delete("c1", "H1", "support", card_ref)
	_chk(card_ref.is_queued_for_deletion(), "Fix1-F：删除连线后详情卡关闭（queue_free 已排队）")
	var still := false
	for r in gv._relations:
		if r.get("from", "") == "c1" and r.get("to", "") == "H1": still = true
	_chk(not still, "Fix1-G：c1→H1 连线已被删除")
	_chk(gv._data._verdict_text() == "有点道理", "Fix1-H：删除后结论即时降级（与 Fix3-D 一致）")

	# ================= 连线模式快捷 toggle（点两节点=有边删/无边建） =================
	gv._add_edge("c1", "H1", "support", "green", false)
	_chk(gv._relations_between("c1", "H1").size() == 1, "Fix1-I：c1↔H1 已有 1 条连线（准备测 toggle）")
	gv.set_connect_mode(true)
	gv._handle_connect_click("c1", "clue")
	gv._handle_connect_click("H1", "hypo")
	_chk(gv._relations_between("c1", "H1").is_empty(), "Fix1-J：连线模式点两已有连线节点=删除该连线")
	_chk(gv._data._verdict_text() == "有点道理", "Fix1-K：删除后结论即时降级")
	gv._handle_connect_click("c1", "clue")
	gv._handle_connect_click("H1", "hypo")
	_chk(gv._relations_between("c1", "H1").size() == 1, "Fix1-L：再点两次恢复建边")
	_chk(gv._data._verdict_text() == "说得通", "Fix1-M：恢复建边后结论回升")
	gv.set_connect_mode(false)
	gv.queue_free()

	# ================= 问题2：图谱内「提交验证」按钮 =================
	_verify_flag = false
	var data2 := _sample_data()
	data2["on_verify"] = func(): _verify_flag = true
	var gv2 := _mk_controller(data2)
	_chk(gv2._verify_btn != null and is_instance_valid(gv2._verify_btn), "Fix2-A：图谱工具栏存在「提交验证」按钮")
	_chk(gv2._verify_btn.text == "✓ 提交验证", "Fix2-B：按钮文案正确")
	_chk(not gv2._verify_btn.disabled, "Fix2-C：EDITABLE 态提交验证按钮可用")
	gv2._on_verify_pressed()
	_chk(_verify_flag, "Fix2-D：点击提交验证转发到推理墙 _on_verify_pressed")
	# LOCKED（已封存）态：按钮禁用 + 点击不触发
	_verify_flag = false
	var data3 := _sample_data()
	data3["editable"] = false
	data3["on_verify"] = func(): _verify_flag = true
	var gv3 := _mk_controller(data3)
	_chk(gv3._verify_btn != null and gv3._verify_btn.disabled, "Fix2-E：LOCKED 态提交验证按钮禁用")
	gv3._on_verify_pressed()
	_chk(not _verify_flag, "Fix2-F：LOCKED 态点击提交验证不触发回调")
	gv2.queue_free()
	gv3.queue_free()

	# ================= 问题2：模式切换 / 重进位置保持 =================
	var gv5 := _mk_controller(_sample_data())
	gv5._mode = 0  # ViewMode.MODE_C
	gv5._node_center["c1"] = Vector2(900, 300)          # 模拟玩家把 c1 拖到星型右上
	gv5._persist_node_positions()
	_chk(gv5._state_store["graph_node_positions"]["c1"] == Vector2(900, 300), "Fix5-A：MODE_C 拖动后位置写盘")
	gv5._switch_mode(1)  # ViewMode.MODE_B                    # 切推理链（垂直分层）
	_chk(gv5._all_positions.get("c1", Vector2.ZERO) == Vector2(900, 300),
		"Fix5-B：MODE_B 布局不污染 _all_positions（修复前会被覆盖成垂直分层坐标）")
	gv5._node_center["c1"] = Vector2(500, 900)
	gv5._persist_node_positions()
	_chk(gv5._state_store["graph_node_positions"]["c1"] == Vector2(900, 300),
		"Fix5-C：MODE_B 下拖动不覆盖星型存档位置")
	gv5._switch_mode(0)  # ViewMode.MODE_C                    # 切回星型
	var center5: Vector2 = gv5._canvas.size * 0.5
	var expect5: Vector2 = gv5._clamp_to_band(Vector2(900, 300), center5, "clue")
	_chk(gv5._node_center.get("c1", Vector2.ZERO) == expect5, "Fix5-D：切回星型后 c1 恢复存档位置（钳制带内）")
	gv5._persist_view()
	_chk(gv5._state_store["graph_node_positions"]["c1"] == expect5,
		"Fix5-E：关墙落盘位置为星型实际渲染位置（未被 MODE_B 污染）")
	gv5.queue_free()

	# ================= 问题3：字号放大一倍 =================
	var gv6 := _mk_controller(_sample_data())
	var c1_card: Control = gv6._node_views.get("c1")
	var max_fs := 0
	for l in c1_card.find_children("*", "Label", true, false):
		max_fs = maxi(max_fs, (l as Label).get_theme_font_size("font_size"))
	_chk(max_fs >= 26, "Fix6-A：节点卡片主文字字号 ≥26（原 15，放大近一倍）")
	_chk(gv6._verify_btn.custom_minimum_size.y >= 60, "Fix6-B：工具栏按钮高度随字号放大")
	_chk(gv6._node_views.get("c1").size.x >= 300, "Fix6-C：节点卡片宽度随字号放大")
	gv6.queue_free()

	# 推理墙链路：顶栏「✓ 提交验证」按钮（真实游戏图谱主视图时底部面板隐藏，靠它提交）
	await _run_rw_verify()

	print("=== 图谱第二批修复测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
	if _fail > 0:
		print("GRAPH_FIX2_RESULT: FAIL")
	else:
		print("GRAPH_FIX2_RESULT: PASS")


func _ready() -> void:
	await _run()
	queue_free()


# ================= 问题2 在推理墙真实链路上的验证 =================
func _run_rw_verify() -> void:
	var clues := [
		{"id":"c1","name":"车轮印","desc":"窄轮距马车","correct":true,"associated":true,
			"related_npcs":["NPC_HOP"],"relation_tags":["H1"],"attribute_tags":["直接物证"]},
		{"id":"c2","name":"脚印","desc":"步幅大","correct":true,"associated":true,
			"related_npcs":["NPC_HOP","NPC_DRE"],"relation_tags":["H1"],"attribute_tags":["痕迹"]},
	]
	var hypo := {"title":"马车夫作案","case_name":"血字的研究","chain_id":"2",
		"battlefield":{"hypotheses":[{"id":"H1","text":"凶手乘出租马车","correct":true}],"contradictions":[]}}
	var ss := {"graph_view_mode":0,"graph_focus":"NPC_HOP"}
	var rw = load("res://scripts/clue/reasoning_wall.gd").new()
	add_child(rw)
	rw.setup(clues, hypo, Callable(), Callable(), 1, Callable(), ss, Callable(), true, -1)
	_chk(rw._top_verify_btn != null and is_instance_valid(rw._top_verify_btn),
		"Fix2-G：推理墙顶栏存在「✓ 提交验证」按钮（图谱主视图时可见）")
	_chk(not rw._top_verify_btn.disabled, "Fix2-H：未验证态顶栏提交验证按钮可用")
	rw._on_verify_pressed()
	_chk(rw._verifying == true, "Fix2-I：点顶栏提交验证进入验证流程")
	_chk(rw._verify_win != null and is_instance_valid(rw._verify_win), "Fix2-J：验证结果窗口已弹出（图谱之上可见）")
	rw._close_verify_win()
	_chk(rw._verifying == false, "Fix2-K：关闭验证窗口后状态复位")
	rw.queue_free()
	print("=== 图谱提交验证链路测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
