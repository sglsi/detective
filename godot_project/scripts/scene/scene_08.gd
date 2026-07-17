extends GameScene
class_name Scene08Game

## 场景08：贝克街221B — 起居室（最终对决） —— 自主探索（无引导）
## 复用 GameScene 的 GamePhase 状态机与 SceneController；
## 引导强度 = 自主（guidance_level=2）：EASY 仅一句开场轻提示、NORMAL/HARD 近乎无提示。
## 主线由「叙事 + 关键推理选择题」驱动；热点为自由勘查，不阻断进度。

func _setup_ui() -> void:
	var scene_title = top_bar.get_node_or_null("SceneTitle")
	if scene_title:
		scene_title.set("text", "贝克街221B — 起居室（最终对决）")
	_setup_side_panel()
	var diff_badge = dialogue_renderer.get_node_or_null("DifficultyBadge")
	if diff_badge:
		diff_badge.text = DifficultyManager.get_difficulty_name()
		diff_badge.show()
	reasoning_wall.hide()
	tool_bar.hide()

func _connect_signals() -> void:
	super._connect_signals()
	if dialogue_renderer and dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.dialogue_node_entered.connect(_on_scene_node_entered)

func _start_tutorial() -> void:
	scene_controller.load_scene("sc_08_finale")
	await get_tree().create_timer(0.6).timeout
	dialogue_renderer.load_dialogue_resource("res://resources/dialogues/scene_08_finale.tres")
	dialogue_renderer.start_dialogue()
	current_phase = GamePhase.INTRO

# ============ 热点：自由勘查（自主，不阻断主线）============

func _on_hotspot_clicked(hotspot_id: String) -> void:
	_show_notification("🔍 勘查: " + _clue_name(hotspot_id))

func _clue_name(id: String) -> String:
	var names = "trunk": "旅行皮箱（诱捕道具）", "cuffs": "钢手铐（凶手落网）", "cab": "霍普的马车", "hop": "杰弗森·霍普（真凶）"
	return names.get(id, id)

# ============ 验证处理（四级验证 → 对话分支）============

func _on_verification_complete(result: int) -> void:
	match result:
		ReasoningWallUI.VerifyResult.VERIFIED:
			_handle_verified()
		ReasoningWallUI.VerifyResult.SUPPORTED:
			_show_notification("证据基本支持 — 方向正确，但证据链还不够完整")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("SUPPORTED")
				dialogue_renderer.dialogue_manager.advance_to("s08_step6_supported")
		ReasoningWallUI.VerifyResult.INSUFFICIENT:
			_show_notification("证据不足 — 需要更多观察")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("INSUFFICIENT")
				dialogue_renderer.dialogue_manager.advance_to("s08_step6_insufficient")
		ReasoningWallUI.VerifyResult.CONTRADICTORY:
			_show_notification("证据矛盾 — 请重新审视")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("CONTRADICTORY")
				dialogue_renderer.dialogue_manager.advance_to("s08_step6_contradictory")

func _handle_verified() -> void:
	current_phase = GamePhase.PHASE1_COMPLETE
	_show_notification("✅ 场景08勘查验证通过！")
	StarRatingSystem.add_reasoning(1)
	if dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.set_verify_result("VERIFIED")
		dialogue_renderer.dialogue_manager.advance_to("s08_step6_verified")

# ============ 终点识别 ============

func _on_scene_node_entered(node_id: String) -> void:
	if node_id == "s8_end":
		current_phase = GamePhase.COMPLETE
		is_tutorial_complete = true
		_show_notification("🎉 场景八完成！凶手杰弗森·霍普落网，血字的研究真相大白。")
		SaveManager.save_game()
