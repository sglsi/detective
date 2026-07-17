extends GameScene
class_name Scene02Game

## 场景二：劳瑞斯顿花园街三号（室外）—— 半引导
## 复用 GameScene 的 GamePhase 状态机与 SceneController；
## 引导强度 = 半引导（guidance_level=1）：EASY 稳定微亮、NORMAL 微光、HARD 无提示。
## 观察点 = 4（车轮印 / 马蹄印 / 脚印 / 碾轧花草），多热点收集满后推进六步闭环。

var s2_observed: int = 0
const S2_REQUIRED: int = 4

func _setup_ui() -> void:
	var scene_title = top_bar.get_node_or_null("SceneTitle")
	if scene_title:
		scene_title.set("text", "劳瑞斯顿花园街三号 — 室外花园")
	_setup_side_panel()
	var diff_badge = dialogue_renderer.get_node_or_null("DifficultyBadge")
	if diff_badge:
		diff_badge.text = DifficultyManager.get_difficulty_name()
		diff_badge.show()
	reasoning_wall.hide()
	tool_bar.hide()

func _connect_signals() -> void:
	super._connect_signals()
	# 监听进入节点，用于识别终点（对话结束时 current_node 已置空，需提前捕获）
	if dialogue_renderer and dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.dialogue_node_entered.connect(_on_scene_node_entered)

func _start_tutorial() -> void:
	scene_controller.load_scene("sc_02_garden")
	await get_tree().create_timer(0.6).timeout
	dialogue_renderer.load_dialogue_resource("res://resources/dialogues/scene_02_garden.tres")
	dialogue_renderer.start_dialogue()
	current_phase = GamePhase.INTRO

# ============ 多热点观察（半引导）============

func _on_hotspot_clicked(hotspot_id: String) -> void:
	if current_phase == GamePhase.STEP_1_OBSERVE:
		_handle_scene2_observe(hotspot_id)

func _handle_scene2_observe(hotspot_id: String) -> void:
	s2_observed += 1
	# 记录到侦探笔记 + 推理墙（供四级验证判定）
	SceneEventBus.emit_signal("note_recorded", hotspot_id)
	ClueEventBus.emit_signal("clue_recorded", hotspot_id)
	_show_notification("🔍 发现痕迹 (%d/%d)" % [s2_observed, S2_REQUIRED])
	if s2_observed >= S2_REQUIRED:
		current_phase = GamePhase.STEP_2_TOOL
		_show_notification("痕迹收集完毕，进入工具测量阶段")
		if dialogue_renderer.dialogue_manager:
			dialogue_renderer.dialogue_manager.advance_to("s2_step2_start")

# ============ 验证处理（四级验证 → 对话分支）============

func _on_verification_complete(result: int) -> void:
	match result:
		ReasoningWallUI.VerifyResult.VERIFIED:
			_handle_verified()
		ReasoningWallUI.VerifyResult.SUPPORTED:
			_show_notification("证据基本支持 — 方向正确，但证据链还不够完整")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("SUPPORTED")
				dialogue_renderer.dialogue_manager.advance_to("s2_step6_supported")
		ReasoningWallUI.VerifyResult.INSUFFICIENT:
			_show_notification("证据不足 — 需要更多观察")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("INSUFFICIENT")
				dialogue_renderer.dialogue_manager.advance_to("s2_step6_insufficient")
		ReasoningWallUI.VerifyResult.CONTRADICTORY:
			_show_notification("证据矛盾 — 请重新审视")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("CONTRADICTORY")
				dialogue_renderer.dialogue_manager.advance_to("s2_step6_contradictory")

func _handle_verified() -> void:
	current_phase = GamePhase.PHASE1_COMPLETE
	_show_notification("✅ 室外勘查验证通过！")
	StarRatingSystem.add_reasoning(1)
	if dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.set_verify_result("VERIFIED")
		dialogue_renderer.dialogue_manager.advance_to("s2_step6_verified")

# ============ 终点识别 ============

func _on_scene_node_entered(node_id: String) -> void:
	if node_id == "s2_end":
		current_phase = GamePhase.COMPLETE
		is_tutorial_complete = true
		_show_notification("🎉 场景二完成！室外勘查（车辙/蹄印/脚印/碾轧）已归档。")
		SaveManager.save_game()
