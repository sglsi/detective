extends Control

## 回归测试：推理墙「提交验证 → 取消」后界面假死（用户 2026-09-10 反馈）
##
## 根因：_show_verify_confirm 把全屏 MOUSE_FILTER_STOP 遮罩 add_child 进墙，但只把确认小窗
## 存进 _verify_confirm_win；点「取消」只 queue_free 小窗，遮罩原样残留 → 透明全屏 STOP 层
## 吞掉所有点击 → 整个界面假死。同理结果窗口 VerifyBackdrop 也未被 _close_verify_win 清理。
##
## 本测试：实例化真实推理墙 → 走「提交验证→确认框弹出→取消」完整链路，
## 断言 a) 取消后 _verifying 复位 b) 遮罩与确认框均被销毁 c) 可再次提交（墙未假死）；
## 另走「确认提交→结果窗口→✕关闭」链路，断言结果窗口遮罩同样被清理。

var _pass := 0
var _fail := 0

func _ready() -> void:
	await get_tree().process_frame
	var ok := _run()
	print("=== 提交验证-取消-解冻 回归测试: PASS=%d FAIL=%d ===" % [_pass, _fail])
	get_tree().quit(0 if ok else 1)

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)

func _run() -> bool:
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

	# 点「提交验证」→ 弹出确认框（含全屏遮罩）
	rw._verify_ctl._on_verify_pressed()
	_chk(rw._verifying == true, "A：提交验证后进入验证流程(_verifying=true)")
	_chk(rw._verify_confirm_win != null and is_instance_valid(rw._verify_confirm_win), "B：确认框已弹出")
	_chk(rw._verify_confirm_backdrop != null and is_instance_valid(rw._verify_confirm_backdrop), "C：确认框遮罩已生成")

	# 遮罩是全屏 MOUSE_FILTER_STOP —— 修复前取消后残留即吞点击、界面假死
	var bd: ColorRect = rw._verify_confirm_backdrop
	_chk(bd.mouse_filter == Control.MOUSE_FILTER_STOP, "D：遮罩为全屏 STOP 层（取消若不清理即吞点击）")

	# 点「取消」
	rw._verify_ctl._cancel_verify_confirm()

	_chk(rw._verifying == false, "E：取消后 _verifying 复位")
	_chk(rw._verify_confirm_win == null or not is_instance_valid(rw._verify_confirm_win), "F：确认框已销毁")
	_chk(rw._verify_confirm_backdrop == null or not is_instance_valid(rw._verify_confirm_backdrop),
		"G：确认框遮罩已销毁（不再阻挡点击 → 不再假死）")

	# 取消后再次提交验证应可正常重新进入 → 证明墙未假死
	rw._verify_ctl._on_verify_pressed()
	_chk(rw._verifying == true and rw._verify_confirm_win != null, "H：取消后可再次提交验证（墙未假死）")
	rw._verify_ctl._cancel_verify_confirm()
	_chk(rw._verify_confirm_backdrop == null or not is_instance_valid(rw._verify_confirm_backdrop),
		"I：二次取消遮罩仍被清理")

	# 结果窗口路径：确认提交 → 结果窗口 → ✕ 关闭，遮罩同样须清理（同款泄漏修复）
	rw._verify_ctl._on_verify_pressed()
	rw._verify_ctl._open_verify_result()
	_chk(rw._verify_win != null and is_instance_valid(rw._verify_win), "J：结果窗口已弹出")
	_chk(rw._verify_result_backdrop != null and is_instance_valid(rw._verify_result_backdrop), "K：结果窗口遮罩已生成")
	_chk(rw._verified == true, "L：确认提交后墙已标记验证")
	rw._verify_ctl._close_verify_win()
	_chk(rw._verify_win == null or not is_instance_valid(rw._verify_win), "M：结果窗口已关闭")
	_chk(rw._verify_result_backdrop == null or not is_instance_valid(rw._verify_result_backdrop),
		"N：结果窗口遮罩已销毁（同款泄漏修复）")

	rw.queue_free()
	return _fail == 0
