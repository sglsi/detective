extends GameScene
class_name Scene03Game

## 场景三：劳瑞斯顿花园街三号（室内）—— 轻引导
## 复用 GameScene 的 GamePhase 状态机与 SceneController；
## 引导强度 = 轻引导（guidance_level=2）：EASY 仅一句开场轻提示、NORMAL/HARD 近乎无提示。
## 主线由「叙事 + 关键推理选择题」驱动；热点为自由勘查，不阻断进度。

func _setup_ui() -> void:
	var scene_title = top_bar.get_node_or_null("SceneTitle")
	if scene_title:
		scene_title.set("text", "劳瑞斯顿花园街三号 — 室内前室")
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
	scene_controller.load_scene("sc_03_indoor")
	await get_tree().create_timer(0.6).timeout
	dialogue_renderer.load_dialogue_resource("res://resources/dialogues/scene_03_indoor.tres")
	dialogue_renderer.start_dialogue()
	current_phase = GamePhase.INTRO

# ============ 热点：自由勘查（轻引导，不阻断主线）============

func _on_hotspot_clicked(hotspot_id: String) -> void:
	_show_notification("🔍 勘查: " + _clue_name(hotspot_id))

func _clue_name(id: String) -> String:
	var names = {
		"body": "尸体（无伤痕 · 被迫服毒）",
		"blood_word": "墙上血字 RACHE",
		"items": "随身物品（E.J.D. 名片夹等）",
		"ring": "女人戒指 L·F（露茜·费里尔）",
	}
	return names.get(id, id)

# ============ 终点识别 ============

func _on_scene_node_entered(node_id: String) -> void:
	if node_id == "s3_end":
		current_phase = GamePhase.COMPLETE
		is_tutorial_complete = true
		_show_notification("🎉 场景三完成！室内勘查（服毒/复仇/红脸方头靴/戒指L·F/醉汉即凶手）已归档。")
		SaveManager.save_game()
