extends Control
class_name GameScene

## GameScene v2.0 — 游戏主场景（场景一教学关）
## 完整六步闭环驱动：
##   对话引擎 → 六步闭环信号 → 玩家交互 → 步骤切换 → 阶段推进
##
## 流程：对话开始 → Step 1 观察 → Step 2 工具 → Step 3 笔记
##       → Step 4 知识库(可选) → Step 5 推理墙(可选) → Step 6 验证
##       → 阶段2 信使 → 案件承接

# ============ 核心子系统 ============

@onready var scene_controller: SceneController = $SceneView/SceneController
@onready var dialogue_renderer: DialogueRenderer = $UI/DialoguePanel/DialogueRenderer
@onready var tool_bar: ToolBar = $UI/ToolBar
@onready var reasoning_wall: ReasoningWallUI = $UI/ReasoningWall
@onready var top_bar: Control = $UI/TopBar
@onready var side_panel: Control = $UI/SidePanel
@onready var notification_area: Control = $UI/NotificationArea

# ============ 游戏状态 ============

enum GamePhase {
	INTRO,             # 初次见面对话
	STEP_1_OBSERVE,    # Step 1: 观察华生
	STEP_2_TOOL,       # Step 2: 工具操作
	STEP_3_RECORD,     # Step 3: 数据记录
	STEP_4_KNOWLEDGE,  # Step 4: 知识检索(可选)
	STEP_5_HYPOTHESIS, # Step 5: 假设形成(可选)
	STEP_6_VERIFY,     # Step 6: 验证修正
	PHASE1_COMPLETE,   # 阶段1完成
	PHASE2_INTRO,      # 阶段2: 信使到访
	PHASE2_OBSERVE,    # 阶段2: 观察信使
	PHASE2_COMPLETE,   # 阶段2完成
	CASE_OFFER,        # 案件承接
	COMPLETE,          # 场景一完成
}

var current_phase: GamePhase = GamePhase.INTRO
var phase1_clue_count: int = 0         # 阶段1已记录线索数
var phase1_required: int = 4           # 阶段1需要4条线索
var phase2_clue_count: int = 0         # 阶段2已记录线索数
var phase2_correct: int = 0            # 阶段2正确线索数
var is_knowledge_used: bool = false    # 是否使用了知识库
var is_hypothesis_formed: bool = false # 是否形成了假设
var is_tutorial_complete: bool = false
var _phase1_observed: int = 0          # 阶段1已观察热点数（教程需满4个再推进，修复 Issue 4）
var _note_panel_open: bool = false     # 笔记选择面板是否打开（防止重复触发，修复 Issue 2）
var review_overlay: Control = null     # 放大镜放大视图（含立绘图像，修复 Issue 2）

# ============ 生命周期 ============

func _ready() -> void:
	print("=".repeat(50))
	print("  场景一：贝克街221B — 教学关")
	print("  难度: %s" % DifficultyManager.get_difficulty_name())
	print("=".repeat(50))
	
	_setup_ui()
	_connect_signals()
	_start_tutorial()

func _setup_ui() -> void:
	# 顶部栏
	var scene_title = top_bar.get_node_or_null("SceneTitle")
	if scene_title:
		scene_title.set("text", "贝克街221B — 福尔摩斯私人实验室")
	
	# 侧栏导航
	_setup_side_panel()
	
	# 难度标记
	var diff_badge = dialogue_renderer.get_node_or_null("DifficultyBadge")
	if diff_badge:
		diff_badge.text = DifficultyManager.get_difficulty_name()
		diff_badge.show()
	
	# 初始隐藏
	reasoning_wall.hide()
	tool_bar.hide()

func _setup_side_panel() -> void:
	var buttons = [
		{"name": "🔍 观察", "action": "observe"},
		{"name": "💬 对话", "action": "talk"},
		{"name": "🔧 工具", "action": "examine"},
		{"name": "📚 知识库", "action": "knowledge"},
		{"name": "🧱 推理墙", "action": "think"},
		{"name": "📝 笔记", "action": "journal"},
		{"name": "💾 保存", "action": "save"},
	]
	
	for i in buttons.size():
		var btn = Button.new()
		btn.text = buttons[i]["name"]
		btn.position = Vector2(10, 10 + i * 55)
		btn.size = Vector2(100, 48)
		btn.pressed.connect(_on_side_button_pressed.bind(buttons[i]["action"]))
		side_panel.add_child(btn)

func _connect_signals() -> void:
	# 场景事件
	SceneEventBus.connect("hotspot_clicked", _on_hotspot_clicked)
	SceneEventBus.connect("tool_used", _on_tool_used)
	SceneEventBus.connect("note_recorded", _on_note_recorded)
	
	# 线索事件
	ClueEventBus.connect("clue_discovered", _on_clue_discovered)
	ClueEventBus.connect("verification_complete", _on_verification_complete)
	
	# 对话事件（DialogueManager v2.0 信号）
	if dialogue_renderer and dialogue_renderer.dialogue_manager:
		var dm = dialogue_renderer.dialogue_manager
		dm.step_entered.connect(_on_step_entered)
		dm.note_updated.connect(_on_note_updated_from_dialogue)
		dm.milestone_triggered.connect(_on_milestone_triggered)
		dm.dialogue_ended.connect(_on_dialogue_finished)
		dm.score_awarded.connect(_on_score_awarded)
	else:
		# 兼容旧版连接
		DialogueEventBus.connect("dialogue_finished", _on_dialogue_finished)

# ============ 教学关启动 ============

func _start_tutorial() -> void:
	# 加载场景数据（阶段1：华生观察）
	scene_controller.load_scene("sc_01_lab")
	_phase1_observed = 0
	_note_panel_open = false
	
	# 短暂等待场景初始化
	await get_tree().create_timer(0.6).timeout
	
	# 启动对话（优先 .tres 资源）
	if dialogue_renderer.has_method("start_tutorial"):
		dialogue_renderer.start_tutorial()
	else:
		# 手动加载
		dialogue_renderer.load_dialogue_resource("res://resources/dialogues/scene_01_phase1_tutorial.tres")
		dialogue_renderer.start_dialogue()
	
	current_phase = GamePhase.INTRO

# ============ 六步闭环驱动 ============

func _on_step_entered(step: int, step_name: String) -> void:
	print("[GameScene] 六步闭环 Step %d: %s" % [step, step_name])
	
	match step:
		1:
			current_phase = GamePhase.STEP_1_OBSERVE
			_show_notification("Step 1: 观察华生身上的细节")
			# EASY 模式闪烁提示
			if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY:
				_highlight_hotspots(true)
		2:
			current_phase = GamePhase.STEP_2_TOOL
			tool_bar.show_toolbar()
			if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY:
				_show_notification("试试放大镜？")
		3:
			current_phase = GamePhase.STEP_3_RECORD
			_show_notification("侦探笔记已打开 — 记录你的观察")
		4:
			current_phase = GamePhase.STEP_4_KNOWLEDGE
			_show_notification("📚 知识库: 查阅「人体观察」主题域（可选，按 R 跳过）")
			# 打开知识库（简化：通知提示）
			if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY:
				is_knowledge_used = true
		5:
			current_phase = GamePhase.STEP_5_HYPOTHESIS
			_show_notification("🧱 推理墙: 点击左侧「推理墙」按钮打开假设板（可选，按 R 跳过）")
		6:
			current_phase = GamePhase.STEP_6_VERIFY
			_show_notification("🎯 验证修正: 打开推理墙，拖拽线索形成证据链后点「验证推理」")
			if not reasoning_wall.visible:
				reasoning_wall.open()

func _on_note_updated_from_dialogue(note_text: String) -> void:
	_show_notification("📝 " + note_text)

func _on_milestone_triggered(milestone_name: String) -> void:
	_show_notification("🏆 里程碑解锁: " + milestone_name)

func _on_score_awarded(observation: int, reasoning: int, insight: int) -> void:
	if observation > 0: StarRatingSystem.add_observation(observation)
	if reasoning > 0: StarRatingSystem.add_reasoning(reasoning)
	if insight > 0: StarRatingSystem.add_insight(insight)

# ============ 玩家交互 ============

func _on_hotspot_clicked(hotspot_id: String) -> void:
	if current_phase == GamePhase.STEP_1_OBSERVE:
		# 阶段1: 华生观察
		_handle_phase1_hotspot(hotspot_id)
	elif current_phase == GamePhase.PHASE2_OBSERVE:
		# 阶段2: 信使观察
		_handle_phase2_hotspot(hotspot_id)

func _handle_phase1_hotspot(hotspot_id: String) -> void:
	# 教程阶段1：逐个观察华生身上的 4 个部位（修复 Issue 4：首点不再锁死，4 个均可点击）
	if _note_panel_open:
		return
	_phase1_observed += 1

	# 展示该部位的放大镜放大视图（含真实立绘图像，持续显示直到玩家选择，修复 Issue 2）
	_show_magnifier_review(hotspot_id)
	# 弹「加入笔记 / 跳过」选择面板，由玩家决定是否记录（修复 Issue 2：去自动跳转）
	_present_note_choice(hotspot_id)

func _handle_phase2_hotspot(hotspot_id: String) -> void:
	tool_bar.show_toolbar()

func _on_tool_used(tool_name: String, target_id: String) -> void:
	if _note_panel_open:
		return
	tool_bar.hide_toolbar()

	# 阶段2：信使观察，按工具使用记录线索（保持原逻辑）
	if current_phase == GamePhase.PHASE2_OBSERVE or current_phase == GamePhase.PHASE2_COMPLETE:
		phase2_clue_count += 1
		if not target_id in ["ring", "shoes"]:
			phase2_correct += 1
		SceneEventBus.emit_signal("note_recorded", target_id)
		StarRatingSystem.add_observation(1)
		_show_notification("线索已记录到侦探笔记 (%d/6)" % phase2_clue_count)
		return

	# 阶段1 已改用「加入笔记」面板记录，不走工具流程；此处仅作状态兜底
	current_phase = GamePhase.STEP_3_RECORD
	_show_notification("侦探笔记已打开 — 记录你的观察")

func _on_note_recorded(clue_id: String) -> void:
	# 已在上方处理
	pass

func _on_clue_discovered(clue_id: String) -> void:
	_show_notification("🔍 发现线索: " + _get_clue_display_name(clue_id))

func _get_clue_display_name(clue_id: String) -> String:
	var names = {
		"wrist": "手腕肤色对比",
		"arm": "左臂旧伤",
		"face": "面容憔悴",
		"posture": "军人站姿",
		"tattoo": "手背锚文身",
		"beard": "军人式胡须",
		"messenger_posture": "信使站姿",
		"expression": "发号施令神态",
		"ring": "普通戒指(干扰)",
		"shoes": "普通皮鞋(干扰)",
	}
	return names.get(clue_id, clue_id)

# ============ 笔记选择 / 放大镜放大视图（Issue 2 / Issue 4）============

## 查询热点的观察描述文本（用于笔记面板展示）
func _get_clue_description(clue_id: String) -> String:
	if scene_controller:
		for h in scene_controller.hotspots:
			if h.id == clue_id:
				return h.description
	return _get_clue_display_name(clue_id)

## 弹出「加入笔记 / 跳过」选择面板（玩家主动选择，替代自动跳转）
func _present_note_choice(clue_id: String) -> void:
	_note_panel_open = true
	var panel = NoteChoicePanel.new()
	panel.setup(clue_id, _get_clue_description(clue_id))
	panel.choice_made.connect(_on_note_choice_made.bind(clue_id))
	get_tree().root.add_child(panel)

## 玩家在笔记面板做出选择后的回调
func _on_note_choice_made(confirmed: bool, clue_id: String) -> void:
	_note_panel_open = false
	_hide_magnifier_review()

	if confirmed:
		phase1_clue_count += 1
		SceneEventBus.emit_signal("note_recorded", clue_id)
		StarRatingSystem.add_observation(1)
		_show_notification("线索已记录到侦探笔记 (%d/%d)" % [phase1_clue_count, phase1_required])
	else:
		_show_notification("已跳过该线索（已观察 %d/%d）" % [_phase1_observed, phase1_required])

	# 4 个部位全部观察并选择完毕 → 进入验证环节
	if _phase1_observed >= phase1_required:
		current_phase = GamePhase.STEP_6_VERIFY
		if dialogue_renderer.dialogue_manager:
			dialogue_renderer.dialogue_manager.advance_to("s1_step6_normal")
	else:
		current_phase = GamePhase.STEP_1_OBSERVE

## 确保放大镜放大视图（含立绘图像）已创建
func _ensure_review_overlay() -> void:
	if review_overlay:
		return
	review_overlay = Control.new()
	review_overlay.name = "MagnifierReview"
	review_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	review_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 暗化背景，突出中间的放大视图
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.30)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_overlay.add_child(dim)

	# 圆形放大框（替代原仅有边框、无图像的放大镜）
	var frame = Panel.new()
	frame.size = Vector2(440, 440)
	frame.position = Vector2(1920 / 2 - 220, 1080 / 2 - 300)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.95)
	sb.border_color = Color(0.85, 0.72, 0.30, 1.0)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(220)
	frame.add_theme_stylebox_override("panel", sb)
	review_overlay.add_child(frame)

	# 立绘图像（华生），让放大镜真正"有图像"（修复 Issue 2）
	var tex_path = "res://assets/portraits/sherlock_凝思.png"
	var img = TextureRect.new()
	img.size = Vector2(400, 400)
	img.position = Vector2(20, 20)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(tex_path):
		img.texture = load(tex_path)
	frame.add_child(img)

	get_tree().root.add_child(review_overlay)
	review_overlay.hide()

## 显示放大镜放大视图（持续显示，直到玩家选择，修复"显示时间短"）
func _show_magnifier_review(_clue_id: String) -> void:
	_ensure_review_overlay()
	review_overlay.show()

## 隐藏放大镜放大视图
func _hide_magnifier_review() -> void:
	if review_overlay:
		review_overlay.hide()

# ============ 验证处理 ============

func _on_verification_complete(result: int) -> void:
	match result:
		ReasoningWallUI.VerifyResult.VERIFIED:
			_handle_verified()
		ReasoningWallUI.VerifyResult.SUPPORTED:
			_show_notification("证据基本支持 — 方向正确，但证据链还不够完整")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("SUPPORTED")
				dialogue_renderer.dialogue_manager.advance_to("s1_step6_supported")
		ReasoningWallUI.VerifyResult.INSUFFICIENT:
			_show_notification("证据不足 — 需要更多线索")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("INSUFFICIENT")
				dialogue_renderer.dialogue_manager.advance_to("s1_step6_insufficient")
		ReasoningWallUI.VerifyResult.CONTRADICTORY:
			_show_notification("证据矛盾 — 请重新审视")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.set_verify_result("CONTRADICTORY")
				dialogue_renderer.dialogue_manager.advance_to("s1_step6_contradictory")

func _handle_verified() -> void:
	if current_phase == GamePhase.STEP_6_VERIFY:
		# 阶段1完成
		current_phase = GamePhase.PHASE1_COMPLETE
		_show_notification("✅ 出色！第一次观察验证通过。")
		StarRatingSystem.add_reasoning(1)
		
		if dialogue_renderer.dialogue_manager:
			dialogue_renderer.dialogue_manager.set_verify_result("VERIFIED")
		
		# 短暂延迟后进入阶段2
		await get_tree().create_timer(2.0).timeout
		_advance_to_phase2()
	
	elif current_phase == GamePhase.PHASE2_OBSERVE or current_phase == GamePhase.PHASE2_COMPLETE:
		# 阶段2完成
		current_phase = GamePhase.PHASE2_COMPLETE
		_show_notification("✅ 第二次观察验证通过！")
		StarRatingSystem.add_reasoning(1)
		
		await get_tree().create_timer(2.0).timeout
		_present_case_choice()

func _advance_to_phase2() -> void:
	print("[GameScene] 进入阶段2: 信使到访")
	
	# 隐藏阶段1热点
	scene_controller._clear_hotspots()
	
	# 激活阶段2热点
	scene_controller.activate_phase2()
	current_phase = GamePhase.PHASE2_INTRO
	
	# 对话推进
	if dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.advance_to("s1_post_tutorial")

func _present_case_choice() -> void:
	current_phase = GamePhase.CASE_OFFER
	_show_notification("📜 葛莱森警长的委托信")
	
	if dialogue_renderer.dialogue_manager:
		dialogue_renderer.dialogue_manager.advance_to("case_offer")

func _on_dialogue_finished() -> void:
	if current_phase == GamePhase.CASE_OFFER or current_phase == GamePhase.COMPLETE:
		is_tutorial_complete = true
		current_phase = GamePhase.COMPLETE
		_show_notification("🎉 场景一完成！案件「血字的研究」承接完毕。")
		
		# 保存进度
		SaveManager.save_game()

# ============ 侧栏按钮 ============

func _on_side_button_pressed(action: String) -> void:
	match action:
		"observe":
			_show_notification("观察模式：点击场景中的可交互区域")
		"talk":
			_show_notification("对话模式：点击人物进行交谈")
		"examine":
			tool_bar.show_toolbar()
		"knowledge":
			if current_phase == GamePhase.STEP_4_KNOWLEDGE:
				is_knowledge_used = true
			_show_notification("📚 知识库已打开 — 浏览「人体观察」等相关条目")
		"think":
			if current_phase == GamePhase.STEP_5_HYPOTHESIS:
				is_hypothesis_formed = true
			if reasoning_wall.visible:
				reasoning_wall.close()
			else:
				reasoning_wall.open()
		"journal":
			_show_notification("📝 侦探笔记已打开 — 已记录 %d 条线索" % (phase1_clue_count + phase2_clue_count))
		"save":
			SaveManager.save_game()
			_show_notification("💾 游戏已保存")

# ============ 键盘输入 ============

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_reasoning"):
		if reasoning_wall.visible:
			reasoning_wall.close()
		else:
			reasoning_wall.open()
	
	if event.is_action_pressed("toggle_ui"):
		UIManager.toggle_ui()
		top_bar.visible = UIManager.is_ui_visible
		side_panel.visible = UIManager.is_ui_visible
		tool_bar.visible = UIManager.is_ui_visible
	
	# R 键跳过可选步骤
	if event.is_action_pressed("ui_cancel"):
		if current_phase == GamePhase.STEP_4_KNOWLEDGE:
			current_phase = GamePhase.STEP_5_HYPOTHESIS
			_show_notification("跳过知识检索")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.advance()
		elif current_phase == GamePhase.STEP_5_HYPOTHESIS:
			current_phase = GamePhase.STEP_6_VERIFY
			_show_notification("跳过假设形成")
			if dialogue_renderer.dialogue_manager:
				dialogue_renderer.dialogue_manager.advance()

# ============ 辅助 ============

func _show_notification(message: String) -> void:
	print("[GameScene] " + message)
	if UIManager:
		UIManager.show_notification(message)

func _highlight_hotspots(enable: bool) -> void:
	# EASY 模式闪烁效果
	if enable and scene_controller:
		for hotspot in scene_controller.hotspots:
			if hotspot.is_visible:
				var btn = scene_controller.hotspot_layer.get_node_or_null("Hotspot_%s" % hotspot.id)
				if btn:
					var tween = create_tween().set_loops()
					tween.tween_property(btn, "modulate:a", 0.3, 0.5)
					tween.tween_property(btn, "modulate:a", 0.7, 0.5)
