extends Control
## 复现思傅报告（2026-09-16）：场景二「线索收集完毕 → 推理链设计 → 存档 → 读档 → 推理」
## 验证读档后推理墙是否正确恢复【已设计的推理链（relations/关联/战场）】，
## 而非读档后墙为空、玩家被迫重新设计。
##
## 覆盖范围：
##   (A) SaveManager 数据往返：种入设计的 case_wall_state + scene_state(phase=REASONING)
##       → save_to_slot → 清空 → load_slot → 断言 case_wall_state.relations 与 scene_state.phase 还原
##   (B) 场景读档接线：实例化真实 scene2.tscn（触发 _restore_saved_state → _apply_restored_phase(REASONING)
##       → _open_wall 读 ClueSystem.case_wall_state）→ 断言重开墙后 _relations 已恢复设计
##
## 运行：godot --headless --path . "res://scenes/test_scene2_reasoning_restore.tscn"
## 退出码 0=PASS，1=FAIL。

var _failures: Array = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _ready() -> void:
	await get_tree().process_frame

	if SaveManager == null or ClueSystem == null or GameManager == null:
		printerr("FATAL: 必要 autoload 未就绪"); get_tree().quit(2); return

	# 设计一份「推理链」：把两条已收集线索关联到两个预设推断节点，并点亮一个战场状态。
	# 字段命名对齐 WallState._restore_state / _persist_state。
	var designed := {
		"relations": [
			{"from": "c201", "to": "H1", "kind": "support", "color_key": "green", "dashed": false},
			{"from": "c202", "to": "H2", "kind": "support", "color_key": "green", "dashed": false},
		],
		"associated": ["c201", "c202"],
		"battlefield": {"H1": 2, "H2": 2},
		"milestones_lit": ["core"],
		"doubt_book": [],
		"verified": false,
		"verdict": -1,
		"owner_scene": "scene2",
		# 图谱视图布局键（graph_view_controller 读取），保证视觉节点也被还原
		"graph_placed_clues": ["c201", "c202"],
		"graph_node_positions": {"H1": {"x": 100.0, "y": 100.0}, "H2": {"x": 300.0, "y": 100.0}},
		"graph_manual_nodes": [],
		"graph_node_offsets": {},
		"graph_subtree_sides": {},
		"graph_balanced_layout": false,
		"graph_root_anchors": {},
		"graph_chosen_conclusion": "CL1",
		"graph_chosen_conclusion_text": "凶手为两人",
		"graph_derived_conclusions": ["CL1"],
		"graph_folded_nodes": {},
		"graph_edited_texts": {},
		"graph_deleted_target": {},
		"graph_deleted_nodes": [],
		"graph_tutorial_seen": true,
		"graph_seed": 1,
	}

	# ===== (A) SaveManager 数据往返 =====
	ClueSystem.case_wall_state = designed.duplicate(true)
	GameManager.current_scene_id = "scene2"
	GameManager.current_case_id = "case1"
	GameManager.scene_state = {
		"scene_id": "scene2",
		"phase": 3,                 # scene2 Phase.REASONING
		"clue_ids": ["c201", "c202"],
		"slot": 0
	}

	await SaveManager.save_to_slot(0)
	# 清空，模拟全新会话读档
	ClueSystem.case_wall_state = {}
	GameManager.scene_state = {}
	var ok := await SaveManager.load_slot(0)
	_assert(ok == true, "(A) load_slot 返回成功")

	var restored_case := ClueSystem.case_wall_state
	_assert(not restored_case.is_empty(), "(A) 读档后 ClueSystem.case_wall_state 非空（设计未丢失）")
	var rels_a: Array = restored_case.get("relations", [])
	_assert(rels_a.size() == 2, "(A) 读档后 case_wall_state.relations 还原为 2 条（实得 %d）" % rels_a.size())
	var ss_a: Dictionary = GameManager.scene_state
	_assert(int(ss_a.get("phase", -1)) == 3, "(A) 读档后 scene_state.phase == 3 (REASONING)（实得 %s）" % str(ss_a.get("phase", -1)))
	_assert(ss_a.get("scene_id", "") == "scene2", "(A) 读档后 scene_state.scene_id == scene2")

	# ===== (B) 场景读档接线：实例化真实 scene2 =====
	# 此时 ClueSystem.case_wall_state 已含设计；GameManager.scene_state 已含 phase=3。
	# 实例化 → super._ready → _restore_saved_state → _apply_restored_phase(3) → _open_wall 读回设计。
	var s2 = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var wall = s2.get("_wall_instance")
	_assert(wall != null, "(B) 读档后 REASONING 阶段自动打开推理墙")
	if wall != null:
		var rels_b: Array = wall.get("_relations")
		print("[B] 墙内 relations = %d" % rels_b.size())
		_assert(rels_b.size() == 2, "(B) 重开墙后 _relations 已恢复设计（实得 %d，应 2）" % rels_b.size())
		# 校验 relations 内容为设计值（from/to 正确）
		var froms := {}
		for r in rels_b:
			froms[r.get("from", "")] = true
		_assert(froms.has("c201") and froms.has("c202"), "(B) 恢复的 relations 节点来自设计（c201/c202）")
		var phase_b: int = s2.get("_phase")
		_assert(phase_b == 3, "(B) 场景 _phase 为 REASONING(3)（实得 %d）" % phase_b)

	if _failures.is_empty():
		print("RESULT: PASS 场景二「推理链设计→存档→读档→推理」推理墙状态正确恢复")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL 共 %d 项失败" % _failures.size())
		get_tree().quit(1)
