extends SceneTree
## 单元测试：推理墙「线索关系接入验证 + 拖拽相互关系」逻辑（无渲染依赖，纯逻辑断言）
## 验证点：
##  1) 无关系时 get_verdict 仅由关联计数决定（向后兼容）
##  2) 线索↔线索矛盾关系 → 判定变为 CONTRADICTORY（原 _detect_contradiction 结果此前未进验证，即用户反馈的「无渠道」）
##  3) 线索→假设 支持关系 → 计入支持信号（≥3 即 VERIFIED）
##  4) 线索→假设 反对关系 → 计入矛盾信号
##  5) 关系持久化进 _state_store["relations"]
##  6) 重复/自连被拒

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	var RW = load("res://scripts/clue/reasoning_wall.gd")
	var rw = RW.new()

	# 构造线索：c1/c2 共享矛盾标签 C-01；c3 无标签；c4 为误导项(correct=false)
	var clues := [
		{"id": "c1", "name": "车轮印", "correct": true, "relation_tags": ["C-01"]},
		{"id": "c2", "name": "矛盾证词", "correct": true, "relation_tags": ["C-01"]},
		{"id": "c3", "name": "身高特征", "correct": true, "relation_tags": []},
		{"id": "c4", "name": "误导传言", "correct": false, "relation_tags": []},
	]
	var hypo := {
		"title": "凶手是谁", "description": "",
		"battle": {"hypotheses": [{"id": "H1", "text": "马车夫作案", "correct": true}], "contradictions": []},
	}
	var state := {}
	rw.setup(clues, hypo, Callable(), Callable(), 1, Callable(), state, Callable(), true, 4)
	# 注：枚举 Verdict 值 CONTRADICTORY=0 / INSUFFICIENT=1 / SUPPORTED=2 / VERIFIED=3

	# 1) 关联 3 条正确线索 → VERIFIED(3)
	rw._clue_ctl._toggle_association("c1")
	rw._clue_ctl._toggle_association("c2")
	rw._clue_ctl._toggle_association("c3")
	var v1: int = rw.get_verdict()
	log.append("关联3条正确线索 verdict=%d (期望3)" % v1)
	if v1 != 3: ok = false; print("REL_FAIL 基础关联未得 VERIFIED, v=", v1)

	# 2) 线索↔线索矛盾关系 → CONTRADICTORY(0)
	var r2: bool = rw._rel_ctl.connect_nodes("c1", "c2", "auto")
	var rel_kind_after: String = rw._rel_ctl.get_relations()[-1]["kind"] if not rw._rel_ctl.get_relations().is_empty() else "?"
	log.append("connect c1↔c2(auto) 返回=%s 解析kind=%s" % [r2, rel_kind_after])
	var v2: int = rw.get_verdict()
	log.append("建立矛盾关系后 verdict=%d (期望0)" % v2)
	if v2 != 0: ok = false; print("REL_FAIL 矛盾关系未触发 CONTRADICTORY, v=", v2)

	# 3) 清除关系 → 复位为 VERIFIED(3)
	rw._rel_ctl.clear_relations()
	var v3: int = rw.get_verdict()
	log.append("clear_relations 后 verdict=%d (期望3)" % v3)
	if v3 != 3: ok = false; print("REL_FAIL clear_relations 未复位, v=", v3)

	# 4) 仅关联 2 条 + 1 条 支持关系 → VERIFIED(3)
	rw._clue_ctl._toggle_association("c3")   # 取消 c3，剩余 c1,c2 关联(2条)
	var r4: bool = rw._rel_ctl.connect_nodes("c1", "H1", "support")
	var v4: int = rw.get_verdict()
	log.append("关联2+支持关系1 verdict=%d (期望3) support关系返回=%s" % [v4, r4])
	if v4 != 3: ok = false; print("REL_FAIL 支持关系未计入支持信号, v=", v4)

	# 5) 反对关系 → CONTRADICTORY(0)
	var r5: bool = rw._rel_ctl.connect_nodes("c4", "H1", "oppose")
	var v5: int = rw.get_verdict()
	log.append("反对关系 verdict=%d (期望0) oppose返回=%s" % [v5, r5])
	if v5 != 0: ok = false; print("REL_FAIL 反对关系未触发 CONTRADICTORY, v=", v5)

	# 6) 持久化
	var persisted: Array = state.get("relations", [])
	log.append("持久化 relations 条数=%d" % persisted.size())
	if persisted.size() < 1: ok = false; print("REL_FAIL 关系未持久化进 state_store")

	# 7) 重复/自连被拒
	var dup: bool = rw._rel_ctl.connect_nodes("c1", "H1", "support")   # 已存在
	var selfc: bool = rw._rel_ctl.connect_nodes("c1", "c1", "support")  # 自连
	log.append("重复连接返回=%s (期望false) 自连返回=%s (期望false)" % [dup, selfc])
	if dup != false or selfc != false: ok = false; print("REL_FAIL 重复/自连未被拒绝 dup=", dup, " self=", selfc)

	# 8) 非矛盾线索↔线索 → relate（不影响判定，且不引入矛盾）
	rw._rel_ctl.clear_relations()
	rw._clue_ctl._toggle_association("c3")   # 重新关联 c3 → 此时 _associated=3 应 VERIFIED(3)
	var v8_pre: int = rw.get_verdict()
	rw._rel_ctl.connect_nodes("c3", "c4", "auto")
	var kinds: Array = rw._rel_ctl.get_relations()
	var rel_kind2: String = kinds[0]["kind"] if not kinds.is_empty() else "?"
	var v8: int = rw.get_verdict()
	log.append("relate 前 verdict=%d (期望3)；c3↔c4(auto) kind=%s (期望relate) 后 verdict=%d (期望3)" % [v8_pre, rel_kind2, v8])
	if v8_pre != 3: ok = false; print("REL_FAIL 前置关联异常 v8_pre=", v8_pre)
	if rel_kind2 != "relate": ok = false; print("REL_FAIL 非矛盾线索对未解析为 relate, kind=", rel_kind2)
	if v8 != 3: ok = false; print("REL_FAIL relate 不应改变判定, v=", v8)

	for l in log: print("[REL]", l)
	if ok:
		print("REL_RESULT: PASS — 线索关系接入验证 + 拖拽相互关系逻辑全部通过")
	else:
		print("REL_RESULT: FAIL")
	quit()
