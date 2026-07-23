extends Control

## Scene 2 — 劳瑞斯顿花园街3号 · 案发现场
## 设计依据：02_血字的研究_场景设计与流程 §10

enum Phase { ARRIVAL, OBSERVE, COLLECT, DEDUCE, COMPLETE }

var _phase := Phase.ARRIVAL
var _dm: DialogueManager
var _speaker_lbl: Label
var _text_lbl: Label

func _ready() -> void:
	_create_ui()
	_init_state()
	_show_arrival_dialogue()

func _init_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = "scene2"
		if AuthManager:
			GameManager.is_guest = AuthManager.is_guest()

func _create_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 场景标题
	var title = Label.new()
	title.text = "劳瑞斯顿花园街 3号 — 案发现场"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	title.position = Vector2(60, 20)
	title.size = Vector2(800, 40)
	add_child(title)

	# 场景说明
	var desc = Label.new()
	desc.text = "浓雾笼罩的清晨，一辆马车停在花园街3号门前。\n" + \
		"探长葛莱森神色凝重地迎上前来……\n\n" + \
		"（场景二内容开发中——更多案发现场探索即将上线）"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.80, 0.76, 0.66))
	desc.position = Vector2(300, 250)
	desc.size = Vector2(1300, 300)
	desc.horizontal_alignment = 1
	add_child(desc)

	# 对话底栏
	var bar = ColorRect.new()
	bar.color = Color(0.12, 0.10, 0.07, 0.95)
	bar.position = Vector2(0, 850)
	bar.size = Vector2(1920, 230)
	add_child(bar)

	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_size_override("font_size", 24)
	_speaker_lbl.position = Vector2(60, 865)
	_speaker_lbl.size = Vector2(400, 35)
	add_child(_speaker_lbl)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 20)
	_text_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	_text_lbl.position = Vector2(60, 905)
	_text_lbl.size = Vector2(1800, 155)
	add_child(_text_lbl)

func _show_arrival_dialogue() -> void:
	_dm = DialogueManager.new()
	add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_arrival_end)

	var nodes: Array[Resource] = []
	var _n = func(id, sp, txt, tri, nxt):
		var n = DialogueNodeResource.new()
		n.node_id = id; n.speaker = sp; n.text = txt
		n.trigger = tri; n.next_nodes = nxt; n.mood = "neutral"
		return n

	nodes.append(_n.call("a0", "葛莱森", "福尔摩斯先生！您总算来了——死者在里面，情况……不太寻常。", "click", ["a1"]))
	nodes.append(_n.call("a1", "福尔摩斯", "不寻常才是我们的专长，警长。带路吧。", "click", ["a2"]))
	nodes.append(_n.call("a2", "system", "（场景二开发中……更多凶案现场调查即将上线）\n恭喜！你已完成场景一的全部内容。", "click", ["end"]))

	var res = DialogueResource.new()
	res.scene_id = "s2"; res.scene_name = "花园街案发现场"
	res.nodes = nodes
	res.easy_start_node = "a0"
	res.normal_start_node = "a0"
	res.hard_start_node = "a0"

	_dm.dialogue_resource = res
	_dm.start_dialogue()

func _on_line(_id: String) -> void:
	var n = _dm.current_node
	if not n: return
	_speaker_lbl.text = n.speaker
	var c = Color(0.85, 0.75, 0.45)
	if n.speaker == "葛莱森": c = Color(0.7, 0.8, 0.9)
	elif n.speaker == "system": c = Color(0.5, 0.9, 0.5); _speaker_lbl.text = "提示"
	_speaker_lbl.add_theme_color_override("font_color", c)
	_text_lbl.text = n.text

func _on_arrival_end() -> void:
	# 自动存档（仅注册用户）
	if GameManager and not GameManager.is_guest and SaveManager:
		await SaveManager.save_game()

	_text_lbl.text = "感谢你游玩《维多利亚伦敦探案》场景一！\n点击或按 Enter 返回主菜单。"
	_speaker_lbl.text = ""

	# 等待点击后返回
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			break
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				await get_tree().process_frame
			break
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _dm and _dm.is_active():
			if not _dm.get_current_trigger() == "choice":
				_dm.advance()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E:
			if _dm and _dm.is_active():
				if not _dm.get_current_trigger() == "choice":
					_dm.advance()
