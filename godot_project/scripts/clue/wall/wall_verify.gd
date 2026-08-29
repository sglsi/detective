extends RefCounted
class_name WallVerify

const WallCompare = preload("res://scripts/clue/wall/wall_compare.gd")

## 推理墙 · 验证窗口层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：实时判定标签、提交验证结果窗口（遮罩+拖拽标题栏+四档文案/边框色）、
## 确认结案（写盘+销毁墙+回调 on_verify）、验证报告（难度门控明细）。
## 公开 API get_last_report/get_difficulty 留在墙内。读取/回写 owner（ReasoningWall）状态。

var owner: ReasoningWall

func _update_verdict_label() -> void:
	if not owner._verdict_lbl: return
	var v := owner.get_verdict()
	if owner._difficulty == ReasoningWall.Diff.HARD:
		owner._verdict_lbl.text = "困难模式：以提交软比对为准（不判定对错）"
		owner._verdict_lbl.add_theme_color_override("font_color", Color(0.85, 0.65, 0.25))
		return
	var txt: String = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v]
	var col: Color = [owner.COL_RED, owner.COL_YELLOW, Color(0.4, 0.85, 0.4), owner.COL_GREEN][v]
	owner._verdict_lbl.text = "当前判定：" + txt
	owner._verdict_lbl.add_theme_color_override("font_color", col)


# === 验证 ===
func _on_verify_pressed() -> void:
	if owner._verifying: return
	if owner._verified: return   # 已提交过验证的墙不允许重复提交（顶栏/图谱入口共用）
	owner._verifying = true
	var v := owner.get_verdict()
	owner._last_report = _soft_compare_report()
	# 提交验证瞬间按玩家最终图谱重算三星并写入 StarRatingSystem，确保评价面板读到最终星级（问题4）
	owner._state_ctl._update_star_rating()

	# 半透明遮罩，吸收窗口外的点击，并压暗底层推理墙
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.z_index = 19
	backdrop.name = "VerifyBackdrop"
	owner.add_child(backdrop)

	# 居中结果窗口（手动计算 position 确保真正居中；PRESET_CENTER 在 add_child 前因 size=0 失效）
	# 加大尺寸 + 内容区可滚动，避免报告过长把底部「确定」按钮挤出可视区（问题2）。
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(760, 540)
	win.size = Vector2(760, 540)
	win.z_index = 20
	win.name = "VerifyResult"
	owner.add_child(win)
	win.position = (owner.get_viewport_rect().size - win.size) / 2

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	var _bc: Color = [owner.COL_RED, owner.COL_YELLOW, Color(0.4, 0.85, 0.4), owner.COL_GREEN][v] as Color
	if owner._difficulty == ReasoningWall.Diff.HARD:
		_bc = Color(0.85, 0.65, 0.25)
	pstyle.border_color = _bc
	pstyle.border_width_left = 3; pstyle.border_width_right = 3
	pstyle.border_width_top = 3; pstyle.border_width_bottom = 3
	pstyle.set_corner_radius_all(10)
	win.add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	win.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vb)

	# 标题栏（拖拽手柄）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 42)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.add_theme_constant_override("separation", 10)
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	tstyle.set_corner_radius_all(6)
	title_bar.add_theme_stylebox_override("panel", tstyle)
	title_bar.gui_input.connect(_on_verify_title_gui)
	vb.add_child(title_bar)

	var title_cap := Label.new()
	title_cap.text = "🔍 验证结果"
	title_cap.add_theme_font_size_override("font_size", 20)
	title_cap.add_theme_color_override("font_color", owner.COL_GOLD)
	title_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_cap)

	var vclose := Button.new()
	vclose.text = "✕"
	vclose.add_theme_font_size_override("font_size", 18)
	vclose.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	vclose.custom_minimum_size = Vector2(40, 32)
	var vcstyle := StyleBoxFlat.new()
	vcstyle.bg_color = Color(0.30, 0.18, 0.18, 0.95)
	vcstyle.border_color = Color(0.7, 0.4, 0.4)
	vcstyle.set_corner_radius_all(4)
	vclose.add_theme_stylebox_override("normal", vcstyle)
	vclose.pressed.connect(_close_verify_win)
	title_bar.add_child(vclose)

	var title := Label.new()
	title.text = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v] as String
	title.add_theme_font_size_override("font_size", 38)
	var _tc: Color = [owner.COL_RED, owner.COL_YELLOW, Color(0.4, 0.85, 0.4), owner.COL_GREEN][v] as Color
	if owner._difficulty == ReasoningWall.Diff.HARD:
		_tc = Color(0.85, 0.65, 0.25)
	title.add_theme_color_override("font_color", _tc)
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(title)

	# 滚动内容区：报告过长时滚动查看；确定按钮固定在底部始终可见（问题2）
	var scr := ScrollContainer.new()
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scr)

	var rep := Label.new()
	rep.text = owner._last_report
	rep.add_theme_font_size_override("font_size", 18)
	rep.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.add_child(rep)

	if v == ReasoningWall.Verdict.VERIFIED:
		for m in owner._milestones: m["lit"] = true
		owner._milestone_confirmed = owner._milestone_total
		owner._state_ctl._update_milestone_ui()

	var ok := Button.new()
	ok.text = "确定"
	ok.add_theme_font_size_override("font_size", 18)
	ok.add_theme_color_override("font_color", owner.COL_GOLD)
	ok.custom_minimum_size = Vector2(160, 46)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	ks.border_color = Color(0.85, 0.65, 0.25)
	ks.border_width_left = 2; ks.border_width_right = 2
	ks.border_width_top = 2; ks.border_width_bottom = 2
	ks.set_corner_radius_all(4)
	ok.add_theme_stylebox_override("normal", ks)
	ok.pressed.connect(_on_verify_confirm.bind(v))
	vb.add_child(ok)

	owner._verify_win = win
	owner._verify_v = v


func _on_verify_confirm(v: int) -> void:
	owner._verify_win = null
	owner._verified = true
	owner._verified_verdict = v
	owner._state_ctl._persist_state()
	# 立即隐藏并销毁墙，解除全屏 MOUSE_FILTER_STOP 拦截，确保过渡对话可点击/渲染；
	# 不再依赖「等一帧」的 await（Web 运行时偶发不可靠导致卡死）。
	owner.visible = false
	owner.queue_free()
	if owner._on_verify.is_valid(): owner._on_verify.call(v)


# 仅关闭验证结果窗口（不确认验证、不关闭推理墙），保留推理墙继续操作
func _close_verify_win() -> void:
	owner._verify_drag = false
	owner._verifying = false
	if owner._verify_win and is_instance_valid(owner._verify_win):
		owner._verify_win.queue_free()
		owner._verify_win = null


# 验证结果窗口标题栏拖拽
func _on_verify_title_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		owner._verify_drag = true
		if owner._verify_win and is_instance_valid(owner._verify_win):
			owner._verify_drag_offset = owner.get_viewport().get_mouse_position() - owner._verify_win.global_position


# ===================== 提交软比对（难度分支核心） =====================
## 抽取场景预设「正确推断」(true_items) 与玩家图谱主张(player_claims)，
## 经 WallCompare 逐项正确/方向/支撑比对，产出软评估文案（不硬判对错）。
func _soft_compare_report() -> String:
	var true_items := []
	var mislead_items := []
	if owner._battle_current is Dictionary and owner._battle_current.has("hypotheses"):
		if owner._battle_current.has("conclusions"):
			for c in owner._battle_current["conclusions"]:
				var cd2: Dictionary = c
				if str(cd2.get("kind", "true")) == "true":
					true_items.append({"id": str(cd2.get("id", "")), "text": str(cd2.get("text", "")),
						"dir": str(cd2.get("dir", "neutral")), "subject": cd2.get("subject", []),
						"object": cd2.get("object", []), "gate_clue_ids": cd2.get("gate_clue_ids", []),
						"adopt_desc": str(cd2.get("adopt_desc", ""))})
				else:
					mislead_items.append({"id": str(cd2.get("id", "")), "text": str(cd2.get("text", ""))})
		for h in owner._battle_current["hypotheses"]:
			var hd: Dictionary = h
			if str(hd.get("kind", "true")) == "true":
				true_items.append({"id": str(hd.get("id", "")), "text": str(hd.get("text", "")),
					"dir": str(hd.get("dir", "neutral")), "subject": hd.get("subject", []),
					"object": hd.get("object", []), "gate_clue_ids": hd.get("gate_clue_ids", []),
					"adopt_desc": str(hd.get("adopt_desc", ""))})
			else:
				mislead_items.append({"id": str(hd.get("id", "")), "text": str(hd.get("text", ""))})
	var player_claims := []
	if owner._graph_view != null and owner._graph_view.has_method("_player_claims"):
		player_claims = owner._graph_view._player_claims()
	var cmp := WallCompare.new()
	var res: Dictionary = cmp.run(true_items, player_claims, mislead_items)
	return res.get("report", "（暂无可评估内容）")



func _compute_report(v: int) -> String:
	var levels := {0: "矛盾冲突", 1: "证据不足", 2: "倾向成立", 3: "已获证实"}
	var hypo_name: String = owner._hypothesis.get("title", "")
	var support := owner._state_ctl._support_signals()
	var contra := owner._state_ctl._contradiction_signals()
	if owner._difficulty == ReasoningWall.Diff.HARD:
		return "假设：%s\n验证等级：%s" % [hypo_name, levels.get(v, "?")]
	var report := "假设：%s\n验证等级：%s\n" % [hypo_name, levels.get(v, "?")]
	match v:
		ReasoningWall.Verdict.VERIFIED:
			report += "支持依据：%d 条正确证据，证据链完整闭合\n行动建议：提交结论，推进结案" % support
		ReasoningWall.Verdict.SUPPORTED:
			report += "支持依据：%d 条证据倾向支持\n存疑点：%d 条矛盾/误导项待排除\n行动建议：深挖剩余疑点，寻找决定性证据完成闭环" % [support, contra]
		ReasoningWall.Verdict.INSUFFICIENT:
			report += "存疑点：证据不足（仅关联 %d 条）\n行动建议：补充更多相关证据，或转向其他假设调查" % owner._associated
		ReasoningWall.Verdict.CONTRADICTORY:
			report += "存疑点：存在 %d 条矛盾证据（含关系矛盾）\n行动建议：推翻该假设，或寻找证据解释矛盾" % contra
	return report
