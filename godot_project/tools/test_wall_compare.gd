extends SceneTree
## 难度分支 · 提交软比对引擎 WallCompare 单测（纯数据，无需 UI）
## 覆盖：方向正确+内容命中=3★ / 方向正确内容偏差=2★ / 方向相悖=0★ / 缺失=1★ / 误导命中检测

const WallCompare = preload("res://scripts/clue/wall/wall_compare.gd")

var res := {"p": 0, "f": 0}


func _chk(c: bool, m: String) -> void:
	if c:
		res.p += 1
	else:
		res.f += 1
	print("CHK", "PASS" if c else "FAIL", m)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var cmp = WallCompare.new()
	var true_items := [{
		"id": "H1", "text": "凶手乘出租马车", "dir": "affirm",
		"subject": ["凶手"], "object": ["出租马车", "马车"],
		"gate_clue_ids": ["c1", "c2"], "adopt_desc": "x"
	}]

	# 3★：方向正确 + 内容命中（关键词重叠高）+ 支撑线索共享
	var claims3 := [{"id": "n1", "kind": "hypo", "text": "凶手乘出租马车来",
		"support_clues": ["c1", "c2"], "player_made": true, "dir_derived": "affirm"}]
	var r3 = cmp.run(true_items, claims3, [])
	_chk(r3["overall"] == 3, "3★ 整体评定")
	_chk(r3["per_item"][0]["stars"] == 3, "3★ 单项")

	# 2★：方向正确 但 内容偏差（仅部分关键词命中）
	var claims2 := [{"id": "n1", "kind": "hypo", "text": "凶手乘车来的",
		"support_clues": ["c1"], "player_made": true, "dir_derived": "affirm"}]
	var r2 = cmp.run(true_items, claims2, [])
	_chk(r2["per_item"][0]["stars"] == 2, "2★ 方向正确内容偏差")

	# 0★：方向相悖（玩家得出相反结论）
	var claims0 := [{"id": "n1", "kind": "hypo", "text": "凶手不是乘马车来的",
		"support_clues": [], "player_made": true, "dir_derived": "negate"}]
	var r0 = cmp.run(true_items, claims0, [])
	_chk(r0["per_item"][0]["stars"] == 0, "0★ 方向相悖")

	# 1★：缺失（玩家未涉及该项）
	var r1 = cmp.run(true_items, [], [])
	_chk(r1["per_item"][0]["stars"] == 1, "1★ 缺失项")

	# 误导命中：玩家采纳了与误导项文字重叠的节点
	var mis := [{"id": "M1", "text": "凶手是身材矮小的报童"}]
	var claimsM := [{"id": "nM", "kind": "hypo", "text": "凶手是身材矮小的报童",
		"support_clues": [], "player_made": true, "dir_derived": "affirm"}]
	var rM = cmp.run([], claimsM, mis)
	_chk(rM["mislead_hits"].size() == 1, "误导项命中检测")

	print("WALL_COMPARE_RESULT PASS=%d FAIL=%d" % [res.p, res.f])
	quit()
