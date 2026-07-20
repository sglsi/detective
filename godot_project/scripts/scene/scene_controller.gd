extends Node2D
class_name SceneController

## SceneController v2.0 — 场景控制器
## 管理场景多视角切换、热点交互、对话触发
## 支持六步闭环完整流转、阶段2信使热点激活

# 当前场景数据
var current_scene_id: String = "sc_01_lab"
var current_view: String = "front"

# 可交互热点列表
var hotspots: Array[HotspotData] = []

# 当前激活的六步闭环步骤
enum ExplorationStep {
	STEP_1_OBSERVE,
	STEP_2_TOOL,
	STEP_3_RECORD,
	STEP_4_KNOWLEDGE,
	STEP_5_HYPOTHESIS,
	STEP_6_VERIFY
}

var current_step: ExplorationStep = ExplorationStep.STEP_1_OBSERVE
var observed_hotspots: Array[String] = []
var recorded_clues: Array[String] = []

# 阶段管理
var current_phase: int = 1  # 1=华生观察, 2=信使观察
var phase2_hotspots_created: bool = false

# 难度相关
var show_highlight: bool = false
var show_glow: bool = false
var no_hints: bool = false

# 引导强度（复用教程状态机时递减，体现「教学递进」）
# 0 = 全引导（场景一教程） 1 = 半引导（场景二） 2 = 轻引导（场景三）
var guidance_level: int = 0

# 多热点观察模式：场景2-3 需收集满指定数量再推进；教程为单点即推进
var multi_observe: bool = false

# ============ 场景 2-3 热点数据表（数据驱动，替代硬编码）============
const HOTSPOT_TABLES := {
	# 场景二：劳瑞斯顿花园街三号（室外）—— 车辙/蹄印/脚印 三类观察点
	"sc_02_garden": [
		{"id": "wheel_track", "label": "车轮印", "pos": Vector2(600, 600), "size": Vector2(320, 48),
		 "desc": "两道平行车轮印，间距约 3.8 英尺、车轮宽 2 英寸、最深 1.2 英寸——出租马车特征", "correct": true},
		{"id": "hoof_print", "label": "马蹄印", "pos": Vector2(1000, 680), "size": Vector2(220, 48),
		 "desc": "马蹄印零乱，右前蹄刚换新蹄铁，旧蹄铁磨损严重", "correct": true},
		{"id": "footprint", "label": "行人脚印", "pos": Vector2(760, 790), "size": Vector2(260, 48),
		 "desc": "两道早期足迹：一人步伐 4 英尺+、一人 3.5 英尺——案发现场共两人", "correct": true},
		{"id": "grass_trample", "label": "碾轧花草", "pos": Vector2(470, 720), "size": Vector2(220, 48),
		 "desc": "路边花草凌乱、似被碾轧——马车曾在此停靠上下客", "correct": true},
	],
	# 场景三：劳瑞斯顿花园街三号（室内）—— 尸体/血字/物品/戒指 可自由勘查
	"sc_03_indoor": [
		{"id": "body", "label": "尸体", "pos": Vector2(820, 420), "size": Vector2(240, 360),
		 "desc": "死者约 43 岁，无伤痕，脸露忿恨恐怖——被迫服毒；右手指甲长", "correct": true},
		{"id": "blood_word", "label": "墙上血字", "pos": Vector2(1220, 240), "size": Vector2(240, 180),
		 "desc": "墙上用鲜血潦草写着 RACHE——德语「复仇」之意", "correct": true},
		{"id": "items", "label": "随身物品", "pos": Vector2(540, 560), "size": Vector2(240, 170),
		 "desc": "金表/阿尔伯特金链/共济会戒指/俄制皮名片夹(E.J.D.)/两封盖恩公司来信", "correct": true},
		{"id": "ring", "label": "女人戒指", "pos": Vector2(980, 660), "size": Vector2(130, 90),
		 "desc": "掉落的结婚金戒指，内径刻 L·F（露茜·费里尔）——凶手准备送情人的破绽", "correct": true},
	],
	# 场景四：劳瑞斯顿花园街（巡警兰斯问询）—— 空屋/尸体/血字/戒指落点
	"sc_04_police": [
		{"id": "empty_window", "label": "空屋窗口灯光", "pos": Vector2(420, 300), "size": Vector2(260, 200),
		 "desc": "案发夜两点，兰斯在布瑞克斯顿路看见空屋窗口有灯光——凶案第一现场", "correct": true},
		{"id": "corpse", "label": "尸体", "pos": Vector2(820, 460), "size": Vector2(240, 320),
		 "desc": "死者德雷伯，无伤痕、脸露忿恨恐怖——被迫服毒；现场有第二人足迹", "correct": true},
		{"id": "blood_word", "label": "墙上血字RACHE", "pos": Vector2(1220, 240), "size": Vector2(240, 180),
		 "desc": "墙上用鲜血潦草写着 RACHE——德语「复仇」之意", "correct": true},
		{"id": "ring_spot", "label": "戒指落点", "pos": Vector2(560, 700), "size": Vector2(220, 80),
		 "desc": "凶手俯身察看尸体时掉落的戒指落点——他之后返回正是为寻它", "correct": true},
	],
	# 场景五：会客厅（等待/伪装/识别）—— 老太婆步态/晚报/戒指/脱逃马车
	"sc_05_parlor": [
		{"id": "old_gait", "label": "老太婆步态", "pos": Vector2(480, 420), "size": Vector2(240, 360),
		 "desc": "「老太太」蹒跚进门，步态中透出不自然的肌肉记忆——伪装破绽", "correct": true},
		{"id": "ad_paper", "label": "晚报招领广告", "pos": Vector2(900, 360), "size": Vector2(220, 150),
		 "desc": "福尔摩斯刊登的失物招领启事——诱「失主」现身的诱饵", "correct": true},
		{"id": "ring_box", "label": "归还的戒指", "pos": Vector2(980, 620), "size": Vector2(160, 110),
		 "desc": "华生归还的结婚金戒指——来人自称索叶太太却住址矛盾", "correct": true},
		{"id": "escape_cab", "label": "脱逃马车", "pos": Vector2(1320, 700), "size": Vector2(280, 120),
		 "desc": "老太婆上车后踪影全无——车行进中跳车逃脱，反侦察意识极强", "correct": true},
	],
	# 场景六：卡彭蒂耶公寓（排除嫌疑）—— 礼帽/合影/爱莉丝证词/电报
	"sc_06_apartment": [
		{"id": "top_hat", "label": "死者礼帽", "pos": Vector2(500, 360), "size": Vector2(220, 160),
		 "desc": "死者德雷伯身旁的礼帽——坎伯韦尔路帽店售出，溯源锁定住址", "correct": true},
		{"id": "photo", "label": "合影照片", "pos": Vector2(880, 340), "size": Vector2(260, 200),
		 "desc": "墙上卡彭蒂耶中尉与妹妹合影——清秀消瘦，与现场强壮凶手体型不符", "correct": true},
		{"id": "alice", "label": "爱莉丝证词", "pos": Vector2(560, 640), "size": Vector2(240, 120),
		 "desc": "爱莉丝红着眼讲述德雷伯八点离开、赶九点一刻火车——不在场线索", "correct": true},
		{"id": "telegram", "label": "克利夫兰电报", "pos": Vector2(1180, 560), "size": Vector2(240, 150),
		 "desc": "克利夫兰回电：德雷伯曾控旧日情敌杰弗森·霍普，请求保护", "correct": true},
	],
	# 场景七：郝黎代旅馆（第二被害人）—— 门缝血迹/药丸木匣/钱袋/电报
	"sc_07_hotel": [
		{"id": "door_blood", "label": "门缝血迹", "pos": Vector2(420, 360), "size": Vector2(260, 220),
		 "desc": "曲曲弯弯的血由房门下流出——斯特兰森被刀刺死，墙上同样 RACHE", "correct": true},
		{"id": "pill_box", "label": "药丸木匣", "pos": Vector2(900, 400), "size": Vector2(220, 160),
		 "desc": "盛药膏的木匣，内有两粒珍珠灰透明药丸——一粒剧毒一粒无毒", "correct": true},
		{"id": "purse", "label": "钱袋", "pos": Vector2(560, 660), "size": Vector2(220, 110),
		 "desc": "斯特兰森钱袋八十多镑分文未少——再次证明非谋财害命", "correct": true},
		{"id": "wire", "label": "电报J.H.", "pos": Vector2(1200, 600), "size": Vector2(240, 140),
		 "desc": "一个月前从克利夫兰打来的电报：「J.H.现欧洲」——杰弗森·霍普", "correct": true},
	],
	# 场景八：起居室（最终对决）—— 旅行皮箱/手铐/马车/霍普
	"sc_08_finale": [
		{"id": "trunk", "label": "旅行皮箱", "pos": Vector2(460, 420), "size": Vector2(260, 200),
		 "desc": "福尔摩斯佯装系皮箱皮带，诱使马车夫上前帮忙——诱捕关键道具", "correct": true},
		{"id": "cuffs", "label": "钢手铐", "pos": Vector2(900, 400), "size": Vector2(200, 160),
		 "desc": "「咔嗒」一响，杰弗森·霍普手腕已被铐住——凶手落网", "correct": true},
		{"id": "cab", "label": "霍普的马车", "pos": Vector2(1280, 700), "size": Vector2(280, 120),
		 "desc": "凶手自己的马车——用他的马车把他送往苏格兰场", "correct": true},
		{"id": "hop", "label": "杰弗森·霍普", "pos": Vector2(720, 640), "size": Vector2(200, 160),
		 "desc": "红脸、高大、棕色外衣的马车夫——杀死德雷伯与斯特兰森的真凶", "correct": true},
	],
}

# 场景 -> 真实美术资源映射表（P5-3：TextureRect 替换占位 ColorRect，避免逐幕硬编码）
const SCENE_ART := {
	"sc_01_lab": "res://assets/scenes/sc_01_lab.png",
	"sc_02_garden": "res://assets/scenes/sc_02_garden.png",
	"sc_03_indoor": "res://assets/scenes/sc_03_indoor.png",
	"sc_04_police": "res://assets/scenes/sc_04_police.png",
	"sc_05_parlor": "res://assets/scenes/sc_05_parlor.png",
	"sc_06_apartment": "res://assets/scenes/sc_06_apartment.png",
	"sc_07_hotel": "res://assets/scenes/sc_07_hotel.png",
	"sc_08_finale": "res://assets/scenes/sc_08_finale.png",
}
const SCENE_TITLE := {
	"sc_01_lab": "贝克街221B — 福尔摩斯私人实验室",
	"sc_02_garden": "劳瑞斯顿花园街三号 — 室外花园",
	"sc_03_indoor": "劳瑞斯顿花园街三号 — 室内前室",
	"sc_04_police": "布瑞克斯顿路 — 巡警兰斯问询",
	"sc_05_parlor": "贝克街221B — 会客厅（伪装识破）",
	"sc_06_apartment": "陶尔魁里卡彭蒂耶公寓",
	"sc_07_hotel": "郝黎代旅馆 — 第二被害人",
	"sc_08_finale": "贝克街221B — 起居室（最终对决）",
}
const SCENE_TINT := {
	"sc_01_lab": Color(0.10, 0.08, 0.05, 0.30),
	"sc_02_garden": Color(0.08, 0.12, 0.10, 0.35),
	"sc_03_indoor": Color(0.14, 0.08, 0.10, 0.40),
	"sc_04_police": Color(0.08, 0.08, 0.14, 0.35),
	"sc_05_parlor": Color(0.12, 0.10, 0.08, 0.30),
	"sc_06_apartment": Color(0.08, 0.10, 0.08, 0.35),
	"sc_07_hotel": Color(0.12, 0.06, 0.08, 0.40),
	"sc_08_finale": Color(0.10, 0.08, 0.06, 0.35),
}

# 场景视图容器
@onready var scene_view_container: Control = $SceneViewContainer
@onready var hotspot_layer: Control = $SceneViewContainer/HotspotLayer
@onready var tool_overlay: Control = $ToolOverlay

func _ready() -> void:
	_setup_difficulty()
	SceneEventBus.connect("hotspot_clicked", _on_hotspot_clicked)
	SceneEventBus.connect("tool_used", _on_tool_used)
	SceneEventBus.connect("note_recorded", _on_note_recorded)

func _setup_difficulty() -> void:
	match DifficultyManager.current_difficulty:
		DifficultyManager.Difficulty.EASY:
			show_highlight = true
			show_glow = false
			no_hints = false
		DifficultyManager.Difficulty.NORMAL:
			show_highlight = false
			show_glow = true
			no_hints = false
		DifficultyManager.Difficulty.HARD:
			show_highlight = false
			show_glow = false
			no_hints = true

# ============ 场景加载 ============

func load_scene(scene_id: String) -> void:
	current_scene_id = scene_id
	hotspots.clear()
	observed_hotspots.clear()
	recorded_clues.clear()
	current_step = ExplorationStep.STEP_1_OBSERVE
	current_phase = 1
	phase2_hotspots_created = false
	
	# 清除旧热点
	_clear_hotspots()
	
	# 设置场景视图 + 热点（按场景分发，复用教程状态机）
	match scene_id:
		"sc_01_lab":
			guidance_level = 0
			multi_observe = false
			_setup_scene_view(scene_id)
			_create_phase1_hotspots()
		"sc_02_garden":
			guidance_level = 1   # 半引导
			multi_observe = true
			_setup_scene_view(scene_id)
			setup_scene_hotspots(scene_id)
		"sc_03_indoor":
			guidance_level = 2   # 轻引导
			multi_observe = true
			_setup_scene_view(scene_id)
			setup_scene_hotspots(scene_id)
		# 场景 4-8：自主探索（无引导）—— 复用同一架构，guidance_level=2
		"sc_04_police", "sc_05_parlor", "sc_06_apartment", "sc_07_hotel", "sc_08_finale":
			guidance_level = 2   # 无引导（自主探索）
			multi_observe = true
			_setup_scene_view(scene_id)
			setup_scene_hotspots(scene_id)
		_:
			_setup_scene_view(scene_id)
			_create_phase1_hotspots()
	
	SceneEventBus.emit_signal("scene_loaded", scene_id)

func _setup_scene_view(scene_id: String = "sc_01_lab") -> void:
	# 清除旧内容（保留热点层，它始终位于顶层交互）
	for child in scene_view_container.get_children():
		if child != hotspot_layer:
			child.queue_free()
	
	# 真实场景背景图：P5-3 从 .png 资源加载，替代原有 emoji ColorRect 占位
	var bg_path: String = SCENE_ART.get(scene_id, "")
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var bg := TextureRect.new()
		bg.name = "SceneBackground"
		bg.texture = load(bg_path)
		bg.size = Vector2(1920, 1080)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene_view_container.add_child(bg)
		scene_view_container.move_child(bg, 0)
	else:
		# 纹理缺失时的回退：保持原色块，避免崩溃
		var bg := ColorRect.new()
		bg.name = "SceneBackground"
		bg.size = Vector2(1920, 1080)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.color = Color(0.15, 0.12, 0.08, 1.0)
		scene_view_container.add_child(bg)
		scene_view_container.move_child(bg, 0)
	
	# 氛围着色叠层：统一维多利亚煤气灯调性，半透明覆盖在背景之上
	var tint := ColorRect.new()
	tint.name = "SceneTint"
	tint.size = Vector2(1920, 1080)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = SCENE_TINT.get(scene_id, Color(0.1, 0.08, 0.06, 0.30))
	scene_view_container.add_child(tint)
	scene_view_container.move_child(tint, 1)
	
	# 场景标题
	var label := Label.new()
	label.name = "SceneTitle"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	label.position = Vector2(50, 30)
	label.text = SCENE_TITLE.get(scene_id, "场景")
	scene_view_container.add_child(label)
	
	# 教程场景：华生立绘（用现有立绘资源替代灰色占位块）
	if scene_id == "sc_01_lab":
		var watson_tex_path = "res://assets/portraits/sherlock_凝思.png"
		var watson = TextureRect.new()
		watson.name = "WatsonSilhouette"
		if ResourceLoader.exists(watson_tex_path):
			watson.texture = load(watson_tex_path)
		watson.size = Vector2(280, 560)
		watson.position = Vector2(760, 260)
		watson.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		watson.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		watson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene_view_container.add_child(watson)
		var watson_label = Label.new()
		watson_label.name = "WatsonLabel"
		watson_label.text = "👤 华生医生"
		watson_label.position = Vector2(840, 830)
		watson_label.add_theme_font_size_override("font_size", 16)
		watson_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		scene_view_container.add_child(watson_label)

# ============ 阶段1：华生观察热点 ============

func _create_phase1_hotspots() -> void:
	_create_hotspot("wrist", "手腕", Vector2(870, 440), Vector2(100, 35), "手腕有明显肤色对比——手掌白净，手腕以上被晒黑")
	_create_hotspot("arm", "左臂", Vector2(780, 530), Vector2(90, 50), "左臂动作僵硬，似有肩部旧伤")
	_create_hotspot("face", "面色", Vector2(880, 330), Vector2(90, 70), "面容憔悴，眼下有黑眼圈——疾病初愈或长期疲劳")
	_create_hotspot("posture", "站姿", Vector2(850, 620), Vector2(140, 160), "站姿挺拔，带有明显的军人气质——正规军队服役的标志")

# ============ 阶段2：信使观察热点 ============

# ============ 数据驱动热点（场景 2-3）============

func setup_scene_hotspots(scene_id: String) -> void:
	if not HOTSPOT_TABLES.has(scene_id):
		return
	for h in HOTSPOT_TABLES[scene_id]:
		_create_table_hotspot(h)

func _create_table_hotspot(h: Dictionary) -> void:
	var hotspot = HotspotData.new()
	hotspot.id = h["id"]
	hotspot.label = h["label"]
	hotspot.position = h["pos"]
	hotspot.size = h["size"]
	hotspot.description = h["desc"]
	hotspot.is_visible = h.get("visible", true)
	hotspot.is_correct = h.get("correct", true)
	hotspots.append(hotspot)
	if hotspot.is_visible:
		_spawn_hotspot_button(hotspot)

func activate_phase2() -> void:
	current_phase = 2
	phase2_hotspots_created = true
	current_step = ExplorationStep.STEP_1_OBSERVE
	observed_hotspots.clear()
	recorded_clues.clear()
	
	# 隐藏华生剪影
	var watson = scene_view_container.get_node_or_null("WatsonSilhouette")
	if watson:
		watson.hide()
	
	# 信使立绘（用现有立绘资源替代灰色占位块）
	var messenger_tex_path = "res://assets/portraits/sherlock_神秘.png"
	var messenger = TextureRect.new()
	messenger.name = "MessengerSilhouette"
	if ResourceLoader.exists(messenger_tex_path):
		messenger.texture = load(messenger_tex_path)
	messenger.size = Vector2(260, 540)
	messenger.position = Vector2(580, 300)
	messenger.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	messenger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	messenger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_view_container.add_child(messenger)
	
	var messenger_label = Label.new()
	messenger_label.text = "👤 信使"
	messenger_label.position = Vector2(640, 800)
	messenger_label.add_theme_font_size_override("font_size", 16)
	messenger_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	scene_view_container.add_child(messenger_label)
	
	# 创建信使热点
	_create_hotspot("tattoo", "手背文身", Vector2(680, 520), Vector2(70, 40), "蓝色大锚文身——海员特征 ✓")
	_create_hotspot("beard", "络腮胡", Vector2(650, 350), Vector2(90, 50), "军人式修剪整齐的胡须 ✓")
	_create_hotspot("messenger_posture", "信使站姿", Vector2(640, 600), Vector2(120, 150), "昂首挺胸的军人站姿 ✓")
	_create_hotspot("expression", "神态", Vector2(680, 300), Vector2(70, 40), "自信发号施令的神态——军士气质 ✓")
	_create_hotspot("ring", "戒指", Vector2(740, 540), Vector2(35, 35), "普通戒指——无关线索 ✗")
	_create_hotspot("shoes", "鞋子", Vector2(660, 730), Vector2(70, 35), "普通皮鞋——无关线索 ✗")

# ============ 热点管理 ============

func _create_hotspot(id: String, label: String, pos: Vector2, size: Vector2, desc: String, visible_now: bool = true) -> void:
	var hotspot = HotspotData.new()
	hotspot.id = id
	hotspot.label = label
	hotspot.position = pos
	hotspot.size = size
	hotspot.description = desc
	hotspot.is_visible = visible_now
	hotspot.is_correct = not id in ["ring", "shoes"]
	
	hotspots.append(hotspot)
	
	if visible_now:
		_spawn_hotspot_button(hotspot)

func _spawn_hotspot_button(hotspot: HotspotData) -> void:
	var btn = Button.new()
	btn.name = "Hotspot_%s" % hotspot.id
	btn.position = hotspot.position - hotspot.size / 2
	btn.size = hotspot.size
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 设置提示文本
	btn.tooltip_text = hotspot.description
	
	if show_highlight:
		# 全引导（教程）：闪烁；半引导：稳定微亮（不闪烁）；轻引导：不可见
		match guidance_level:
			0:
				btn.modulate = Color(1, 1, 0, 0.45)
				var tween = btn.create_tween().set_loops()
				tween.tween_property(btn, "modulate:a", 0.2, 0.6)
				tween.tween_property(btn, "modulate:a", 0.5, 0.6)
			1:
				btn.modulate = Color(1, 1, 0, 0.28)
			_:
				btn.modulate = Color(1, 1, 1, 0.0)
	elif show_glow:
		# 微光：轻引导下也收起微光，要求玩家自行发现
		if guidance_level < 2:
			btn.modulate = Color(1, 1, 1, 0.12)
		else:
			btn.modulate = Color(1, 1, 1, 0.0)
	else:
		btn.modulate = Color(1, 1, 1, 0.0)
	
	# HARD 模式下热点仍可点击但不可见
	if no_hints:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	btn.pressed.connect(_on_hotspot_button_clicked.bind(hotspot.id))
	hotspot_layer.add_child(btn)

func _on_hotspot_button_clicked(hotspot_id: String) -> void:
	_on_hotspot_clicked(hotspot_id)

func _clear_hotspots() -> void:
	for child in hotspot_layer.get_children():
		child.queue_free()

# ============ 交互处理 ============

func _on_hotspot_clicked(hotspot_id: String) -> void:
	if current_step != ExplorationStep.STEP_1_OBSERVE:
		return
	
	if hotspot_id in observed_hotspots:
		return
	
	observed_hotspots.append(hotspot_id)
	print("[SceneController] 发现热点: %s (阶段%d)" % [hotspot_id, current_phase])
	
	# 隐藏已发现热点
	var btn = hotspot_layer.get_node_or_null("Hotspot_%s" % hotspot_id)
	if btn:
		btn.queue_free()
	
	# 通知外部
	ClueEventBus.emit_signal("clue_discovered", hotspot_id)
	# 通知游戏层（GameScene / ToolBar）热点被点击，用于观察流程与工具响应
	SceneEventBus.emit_signal("hotspot_clicked", hotspot_id)
	
	# 教程（sc_01）：需观察满全部热点再进入 Step 2；场景 2-3 由 GameScene 推进
	if not multi_observe:
		if observed_hotspots.size() >= 4:
			current_step = ExplorationStep.STEP_2_TOOL

func _on_tool_used(tool_name: String, target_id: String) -> void:
	if current_step != ExplorationStep.STEP_2_TOOL:
		return
	
	print("[SceneController] 使用 %s 观察: %s" % [tool_name, target_id])
	
	# Step 3: 数据记录
	current_step = ExplorationStep.STEP_3_RECORD

func _on_note_recorded(clue_id: String) -> void:
	recorded_clues.append(clue_id)
	print("[SceneController] 线索已记录: %s (共 %d 条)" % [clue_id, recorded_clues.size()])

# ============ 查询方法 ============

func switch_view(view_name: String) -> void:
	current_view = view_name
	SceneEventBus.emit_signal("view_changed", view_name)

func get_observed_count() -> int:
	return observed_hotspots.size()

func get_recorded_count() -> int:
	return recorded_clues.size()

func is_all_observed(target_count: int = 4) -> bool:
	return observed_hotspots.size() >= target_count

func get_current_phase() -> int:
	return current_phase
