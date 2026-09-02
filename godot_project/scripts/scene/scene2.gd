extends DetectiveScene
## Scene 2 — 劳瑞斯顿花园街3号 · 案发现场（室外）
## 架构：继承统一框架 DetectiveScene（与场景三完全一致，所有机制在基类中）。
## 本文件只提供「内容」：热点、对话、推理假设、面板文案、流程分支。
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.3

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

# ── 2026-09 场景二重构：三张新实拍图取代原合成图 sc_02_garden.png ──
# 流程：街道勘查(车辙/马蹄印 c201-204, sc02_street) → 房屋外墙转场(福尔摩斯由远及近推镜演出, sc02_facade)
#      → 花园通道勘查(脚印 c205-206, sc02_path) → 推理。
# street/path 已裁为 16:9(1024×576)，STRETCH_KEEP_ASPECT_COVERED 铺满 1920×1080 无裁切，
# 故热点 svg 坐标 ×1920/1080 即 1920×1080 场景坐标，且锚点归一化 = 场景归一化一一对应。
# 可视区 y 50~850（dialogue_bar 从 850 开始），热点 bottom 必须 < 850。

const STREET_HOTSPOTS = [
	# ── 勘查对象A：车轮印迹（街道图 · 车行道中部地带）──
	{"id":"c201","attribute_tags":["直接物证"],"label":"碾轧的花草","x":1307,"y":735,"w":150,"h":42,
	 "desc":"路边草地被压过了——两道平行的印子，草地上有两道平行的凹痕，像是车轮碾轧留下的。有马车在此停靠过。","tool":"none",
	 "image":"res://assets/scenes/sc02_street.png","anchor":"c201","relation_tags":["H2-01"],"related_npcs":["KILLER"]},
	{"id":"c202","attribute_tags":["直接物证"],"label":"平行车轮印","x":885,"y":649,"w":150,"h":42,
	 "desc":"用卷尺测量：轴距约3.8英尺，轮宽约2英寸，压痕最深处约1.2英寸。查知识库·伦敦马车类型：出租四轮马车轴距约3.8~4.0英尺，车身较窄以适应伦敦小巷——这是一辆出租马车。伦敦的出租马车为了钻小巷，轴距都做窄了，私家马车不会这么窄。","tool":"卷尺",
	 "image":"res://assets/scenes/sc02_street.png","anchor":"c202","relation_tags":["H2-01"]},
	{"id":"c203","attribute_tags":["直接物证"],"label":"右前蹄新蹄铁","x":1000,"y":821,"w":150,"h":42,
	 "desc":"放大镜下：四个蹄铁磨损程度不同——右前蹄铁特别新，边缘锐利，亮得像刚从铁匠铺出来的；其余三个有不同程度磨损。这匹马的右前蹄铁是最近换的。","tool":"none",
	 "image":"res://assets/scenes/sc02_street.png","anchor":"c203","relation_tags":["C2-03"]},
	{"id":"c204","attribute_tags":["直接物证"],"label":"马蹄印迹零乱","x":770,"y":789,"w":150,"h":42,
	 "desc":"蹄印方向散乱，有迂回和停顿痕迹，非正常行进路线——如果有人驾驭，马不会走得这么乱。赶车的不在车上，马曾无人看管：马车夫很可能进了那栋房子。","tool":"none",
	 "image":"res://assets/scenes/sc02_street.png","anchor":"c204","relation_tags":["H2-01","C2-02"]},
	# ── Q3 困难观察级干扰（巡逻警马蹄印）：correct=false，简单模式过滤剔除、普通30%、困难70%概率出现 ──
	{"id":"c207","attribute_tags":["直接物证"],"label":"另一组蹄印","x":560,"y":470,"w":150,"h":42,
	 "desc":"泥地里另有一组蹄印——蹄铁磨损均匀，大小也与那匹马不同。这是巡逻警马的蹄印：警方昨夜到场后留下的，并非凶手来时的痕迹。别把它和凶手的马蹄印混为一谈。","tool":"none",
	 "image":"res://assets/scenes/sc02_street.png","anchor":"c207","relation_tags":[],"correct":false,"silent":true},
]

# ── 勘查对象C：步伐距离（花园通道图 · 中央通道）──
const PATH_HOTSPOTS = [
	{"id":"c205","attribute_tags":["直接物证"],"label":"两组不同脚印","x":731,"y":584,"w":150,"h":42,
	 "desc":"泥地里有两组明显不同的脚印，部分叠在另一部分上面（有先后顺序），且都在警察脚印之下——案发当晚有两个人来过。放大镜下：大步子的脚印是方头靴，小步子是漆皮靴。方头靴多为干体力活的人穿，漆皮靴多为体面人士。","tool":"卷尺",
	 "image":"res://assets/scenes/sc02_path.png","anchor":"c205","relation_tags":["H2-03","C2-01"]},
	{"id":"c206","attribute_tags":["直接物证"],"label":"步伐距离差异","x":923,"y":735,"w":150,"h":42,
	 "desc":"卷尺测量：大步子步幅约4.5英尺，小步子约3.5英尺。查知识库·步态与身高（步幅约为身高的0.45倍）：步幅4.5英尺→身高约6英尺（183cm）的大个子；步幅3.5英尺→身高约5英尺4英寸（163cm）。步幅骗不了人。","tool":"卷尺",
	 "image":"res://assets/scenes/sc02_path.png","anchor":"c206","relation_tags":["H2-02"]},
	# ── Q3 困难观察级干扰（巡警脚印）：correct=false，简单剔除、普通30%、困难70%概率出现 ──
	{"id":"c208","attribute_tags":["直接物证"],"label":"规整的靴印","x":540,"y":470,"w":150,"h":42,
	 "desc":"通道上还有一组规整的靴印，鞋头圆钝、步幅均匀——这是巡警来回勘查时留下的，案发之后才踩上去的。它与凶手的大步方头靴、小步漆皮靴都不是一回事。","tool":"none",
	 "image":"res://assets/scenes/sc02_path.png","anchor":"c208","relation_tags":[],"correct":false,"silent":true},
]

const STAGE_STREET := "street"
const STAGE_PATH := "path"

var _street_obs: ClueObserver
var _path_obs: ClueObserver
var _stage: String = STAGE_STREET

# ===== 框架配置 =====
func scene_id() -> String: return "scene2"
func clue_source() -> String: return "garden"
func hotspots() -> Array: return STREET_HOTSPOTS + PATH_HOTSPOTS
func scene_title() -> String: return "劳瑞斯顿花园街 3号"
func scene_time_text() -> String: return "DAY 1 上午11:15"
@export var procedural_bg: bool = false

func use_procedural_background() -> bool: return procedural_bg
func wants_atmosphere() -> bool: return false

func scene_background() -> Texture2D: return load("res://assets/scenes/sc02_street.png")

# ===== 阶段 / 进度判断 =====
func _is_terminal_phase(p: int) -> bool:
	return p == Phase.TRANSITION

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "抵达案发现场"
		Phase.DETECTIVE_DIALOGUE: return "现场引导"
		Phase.OBSERVE: return "花园勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool:
	return _phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION

# ===== 观察 / 动作文案 =====
func _observe_locked_msg() -> String: return "请先完成现场引导"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击花园中的标记点进行勘查"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 仔细检查现场痕迹"

func _hotspot_tip(tool: String) -> String:
	if tool == "卷尺": return "\n\n[📏 使用卷尺精确测量 — 场景二解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "福尔摩斯指向路边：\"看那里——草地被压过了。两道平行的印子，你觉得是什么？\""
		2,3: return "福尔摩斯：\"用卷尺量量两道车辙之间的距离——那叫轴距。想知道是什么马车？去知识库查查伦敦马车的类型。\""
		4: return "福尔摩斯：\"看看地上——马的蹄印。用放大镜仔细看每个蹄印，蹄铁的磨损程度一样吗？再看蹄印的走向，是直直的还是乱的？\""
		5: return "福尔摩斯：\"看看这些脚印——仔细数，有几种不同的？用卷尺量量大步子的前后距离，一个人的步幅和他的身高有关系。\""
		_: return "福尔摩斯：\"外面能看的差不多了。把线索摆上推理墙，串起来。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查街道与花园。"
func _journal_empty_hint() -> String: return "去勘查现场痕迹"

# ===== 双阶段观察器：街道勘查(c201-204) → 花园通道勘查(c205-206) =====
func _create_observers() -> void:
	_stage = STAGE_STREET
	_street_obs = _make_place_observer("street_observer", STREET_HOTSPOTS)
	_path_obs = _make_place_observer("path_observer", PATH_HOTSPOTS)
	if DifficultyManager and DifficultyManager.auto_reveal_clues and STREET_HOTSPOTS.size() > 0:
		_street_obs.show()

func _make_place_observer(oname: String, list: Array) -> ClueObserver:
	var o := ClueObserver.new()
	o.name = oname
	add_child(o)
	var filtered: Array = list
	if DifficultyManager:
		filtered = DifficultyManager.filter_hotspots_by_difficulty(filtered)
	o.setup(self, _obs_text_lbl, _obs_speaker_lbl, filtered, null, null, "",
		_ui.get_world_layer() if _ui else null, _ui.get_world_offset() if _ui else Vector2.ZERO)
	o.hotspot_clicked.connect(_on_hotspot_seen)
	o.clue_recorded.connect(_on_clue_recorded)
	o.all_recorded.connect(_on_all_done)
	return o

func _current_observer() -> ClueObserver:
	return _street_obs if _stage == STAGE_STREET else _path_obs

func _begin_observe(target_noun: String) -> void:
	_stage = STAGE_STREET
	_ui.set_scene_background(load("res://assets/scenes/sc02_street.png"))
	_current_observer().show()
	_ui.set_dialogue("提示", _observe_hint(target_noun) + _observe_warn_suffix() + "\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙整理。")

func _advance_blocked(is_mouse: bool) -> bool:
	if _wall_instance and is_instance_valid(_wall_instance): return true
	if _modal_panel and is_instance_valid(_modal_panel): return true
	if _toolbar and _toolbar.has_method("_is_overlay_active") and _toolbar._is_overlay_active(): return true
	var cur := _current_observer()
	if cur and cur.has_method("is_active") and cur.is_active() and _in_observe_phase(): return true
	return false

func _observe_hint(_noun: String, _person: bool = false) -> String:
	if _stage == STAGE_STREET:
		return "🔍 街道勘查 — " + ("所有可观察点已高亮，点击街道草地与路面上的车辙、马蹄印圆圈" if (DifficultyManager and DifficultyManager.auto_reveal_clues) else "点击街道草地与路面上的车辙、马蹄印标记点")
	return "🔍 花园通道勘查 — " + ("所有可观察点已高亮，点击通道上的两组脚印圆圈" if (DifficultyManager and DifficultyManager.auto_reveal_clues) else "点击通道上的两组脚印标记点")

func _street_owned_ids() -> Array:
	var r: Array = []
	for h in STREET_HOTSPOTS: r.append(h["id"])
	return r

func _path_owned_ids() -> Array:
	var r: Array = []
	for h in PATH_HOTSPOTS: r.append(h["id"])
	return r

func _on_all_done(_clues_arr: Array) -> void:
	var cur := _current_observer()
	if cur and cur.has_method("hide"): cur.hide()
	if _stage == STAGE_STREET:
		await _street_to_path_transition()
	else:
		_on_observe_complete()

## 街道勘查完成 → 房屋外墙转场（图2）：福尔摩斯「由远及近」推镜演出（方案A）──
## 远全景(reset_camera, zoom=1.0) → 推近房屋(focus_world_point 1.7) → 门廊特写(2.6)，
## 三段旁白对应「街对面看 → 走近几步 → 到门廊下」；演出期间锁相机输入避免与推镜打架；
## 结束 reset_camera 回统览再切图3，保证花园通道热点坐标对齐。
func _street_to_path_transition() -> void:
	_ui.set_scene_background(load("res://assets/scenes/sc02_facade.png"))
	_ui.set_camera_enabled(false)            # 演出期间锁住玩家拖拽/滚轮，避免与推镜打架
	_ui.reset_camera()                        # 远：全景 zoom=1.0
	_ui.set_dialogue("福尔摩斯", "（站在街对面）劳瑞斯顿花园街三号……先从远处看个全貌。", "从容")
	await get_tree().create_timer(0.45).timeout   # 让镜头先稳到全景（远）
	_ui.focus_world_point(Vector2(960, 540), 1.7)   # 中：走近几步，推近房屋
	_ui.set_dialogue("福尔摩斯", "（走近几步）外墙很干净——没有撬锁、没有破窗。凶手是被人请进来的，或者自己有钥匙。", "思考")
	await get_tree().create_timer(1.7).timeout
	_ui.focus_world_point(Vector2(960, 640), 2.6)   # 近：到门廊下，推近细节
	_ui.set_dialogue("福尔摩斯", "（到门廊下）但门廊下的泥地……留下了我们感兴趣的东西。先记着，屋里才是重头戏。", "从容")
	await get_tree().create_timer(1.7).timeout
	_ui.reset_camera()                        # 回统览，避免镜头偏移导致图3热点错位
	_ui.set_camera_enabled(true)
	_stage = STAGE_PATH
	_ui.set_scene_background(load("res://assets/scenes/sc02_path.png"))
	_current_observer().show()
	_ui.set_dialogue("提示", "街道痕迹已记录。雨后的花园通道还藏着脚步的秘密——注意这两组脚印的大小差异与步幅差距。")

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，花园里的痕迹全都记录好了——轴距3.8英尺的车轮印、右前蹄的新蹄铁、两组不同步幅的足迹……证据很充足。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "案发当晚的交通与人员（推理战场 M1）",
		"description": "一辆伦敦出租马车停在花园街3号门口，驾车者高大男性，另一人同行进入花园。\n\n活跃假设：\n· H2-01 凶手乘出租马车来（强）\n· H2-02 凶手身高6英尺以上（中·范围估计）\n· H2-03 凶手穿方头靴（中）\n· H2-04 凶手体格强壮（弱-中·可选）\n· H2-05 凶手中年人（弱·可选）\n\n矛盾标记：\n· C2-01 两组不同脚印（方头靴 vs 小步皮靴）\n· C2-02 乘马车来 vs 泥地大步走\n· C2-03 新蹄铁三只旧蹄铁 vs 统一蹄铁",
		"battlefield": {
			"hypotheses": [
				{"id":"H2-01","text":"凶手乘出租马车来到花园街3号","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["出租马车","马车"],
				 "gate_clue_ids":["c201","c202"],
				 "adopt_desc":"邻居目击+雨后泥地车轮印迹：既有马车的碾轧花草，又有并行车轮印，说明凶手极可能是乘出租马车来的。下一步盘问看门老头确认马车夫身形。",
				 "new_clue_hint":"盘问马厩街车夫，可问出凶手外貌、去向与付钱细节。"},
				{"id":"H2-02","text":"凶手身高六英尺以上","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["六英尺","高个","身高"],
				 "gate_clue_ids":["c206"],
				 "adopt_desc":"现场步伐距离较大，据此推算身高范围：属高个子。可与马车夫身高描述互相印证。",
				 "new_clue_hint":"找马车夫确认凶手是否高个，形成体貌闭环。"},
				{"id":"H2-03","text":"凶手穿方头靴","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["方头靴","靴"],
				 "gate_clue_ids":["c205"],
				 "adopt_desc":"地面两组脚印中主组为方头靴，是本案最关键体貌证据。",
				 "new_clue_hint":"比对屋内皮靴脚印，确认是否同一人伪装成小步。"},
				{"id":"H2-04","text":"凶手体格强壮","kind":"true","correct":true,"pool":"manual","dir":"affirm","subject":["凶手"],"object":["体格强壮","强壮"],
				 "gate_clue_ids":[],
				 "adopt_desc":"翻越、搬运等动作显示体力，属可选强化推断。",
				 "new_clue_hint":""},
				{"id":"H2-05","text":"凶手中年人","kind":"true","correct":true,"pool":"manual","dir":"affirm","subject":["凶手"],"object":["中年人","中年"],
				 "gate_clue_ids":[],
				 "adopt_desc":"综合体貌推断年龄层，属弱支撑的可选结论。",
				 "new_clue_hint":""},
				{"id":"H2-M1","text":"凶手是身材矮小的报童","kind":"mislead","correct":false,
				 "gate_clue_ids":["c205"],
				 "reject_desc":"报童小步与方头靴大码脚印矛盾：现场主要脚印是方头靴，尺寸与报童不合。",
				 "adopt_desc":""},
				{"id":"H2-M2","text":"凶手徒步踏泥大步进入花园","kind":"mislead","correct":false,
				 "gate_clue_ids":["c202"],
				 "reject_desc":"若徒步进入，泥地应留有连续大步足迹；已见并行车轮印与碾轧花草，与乘马车抵达矛盾。",
				 "adopt_desc":""}
			],
		"contradictions": [
			{"id":"C2-01","text":"现场出现两组不同脚印（方头靴 vs 小步皮靴）","correct":true},
			{"id":"C2-02","text":"乘马车来 vs 泥地大步走进入花园","correct":true},
			{"id":"C2-03","text":"一只马蹄铁是新的、其余三只是旧的","correct":true}
		],
		"conclusions": [
			{"id":"CL2-1","text":"凶手乘出租马车抵达现场","kind":"true","dir":"affirm","subject":["凶手"],"object":["出租马车","马车"],"gate_hypo_ids":["H2-01"],"target":"person:KILLER",
			 "adopt_desc":"马车碾轧花草+并行车轮印推导：凶手乘出租马车抵达花园街3号。"},
			{"id":"CL2-2","text":"凶手是高大强壮的成年男性","kind":"true","dir":"affirm","subject":["凶手"],"object":["高大","强壮","成年"],"gate_hypo_ids":["H2-02","H2-04"],"target":"person:KILLER",
			 "adopt_desc":"步幅推算身高、动作推断体格：凶手为高大强壮的成年男性。"},
			{"id":"CL2-3","text":"凶手穿方头靴（关键体貌）","kind":"true","dir":"affirm","subject":["凶手"],"object":["方头靴","靴"],"gate_hypo_ids":["H2-03"],"target":"person:KILLER",
			 "adopt_desc":"两组脚印主组为方头靴：锁定凶手身份的关键体貌结论。"},
			{"id":"CL2-M1","text":"凶手是身材矮小的少年","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["矮小","少年"],"gate_hypo_ids":["H2-M1"],"target":"person:KILLER",
			 "reject_desc":"小步漆皮靴与方头靴主组矛盾：凶手并非矮小少年。"},
			{"id":"CL2-1M","text":"凶手徒步踏泥大步进入花园","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["徒步","泥地","大步"],"gate_hypo_ids":["H2-01"],"target":"person:KILLER",
			 "reject_desc":"并行车轮印与碾轧花草说明是乘马车抵达，非徒步大步进入。"},
			{"id":"CL2-2M","text":"凶手身材矮小、体格瘦弱","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["矮小","瘦弱"],"gate_hypo_ids":["H2-02"],"target":"person:KILLER",
			 "reject_desc":"现场大步幅与翻越/搬运动作均指向高大强壮者，与矮小瘦弱矛盾。"},
			{"id":"CL2-3M","text":"凶手穿小步漆皮靴","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["漆皮靴","小步"],"gate_hypo_ids":["H2-03"],"target":"person:KILLER",
			 "reject_desc":"主组脚印为方头靴大码，漆皮小步靴属同行者/伪装，非凶手本人。"}
		],
		"milestones": [
			{"id":"S2-1","text":"死亡地点：劳瑞斯顿花园街3号"},
			{"id":"S2-2","text":"凶手乘出租马车抵达现场"},
			{"id":"S2-3","text":"凶手身高六英尺以上、体格强壮、中年"},
			{"id":"S2-4","text":"凶手穿方头靴（关键体貌）"},
			{"id":"S2-5","text":"现场两组脚印暗示伪装或同伙"},
		{"id":"S2-6","text":"初步死亡时间：案发当夜"},
		],
	},
	"chain_id": scene_id(),
	"expected_clues": STREET_HOTSPOTS.size() + PATH_HOTSPOTS.size(),
	"insight_bonus": 0
}

# ===== 面板内容 =====
func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号·室外", "d":"案发现场 — 当前场景"},
		{"t":"花园街3号·室内", "d":"尸体现场 — 待进入场景三"},
	]

func casebook_steps() -> Array:
	return ["抵达案发现场", "听取现场引导", "勘查花园痕迹", "推理墙验证"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= STREET_HOTSPOTS.size() + PATH_HOTSPOTS.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单", "普通", "困难"][_difficulty] + " — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"📏 卷尺：场景二起可用，测量轴距/步幅等物理证据",
		"💡 本案马车轴距≈3.8英尺（伦敦出租四轮马车 3.8~4.0 英尺）",
		"音效：MVP 阶段暂无（M3 补全）",
	]

# ===== 对话阶段（节点由基类 _make_nodes / _start_dialogue 驱动） =====
func _enter_arrival() -> void:
	# 对齐 08 稿 v3.16.0 §场景二阶段0到达现场（L615-631）
	_start_dialogue(_make_nodes([
		["a0","系统","（演出）马车缓缓停在劳瑞斯顿花园街三号门口。雨景，灰蒙蒙的天空，街道两旁是破旧的联排房屋。","","guide"],
		["a1","福尔摩斯","（推开车门，看向街道）我们到了。劳瑞斯顿花园街三号——案发现场。","","从容"],
		["a2","华生","（皱眉）这地方……可不怎么体面。","","思考"],
		["a3","福尔摩斯","先别急着进去。在进入现场之前，先看看门外——室内的东西会被人挪动，室外的痕迹不会撒谎，尤其是一夜的雨之后。","","指导"],
		["a4","系统","【场景目标】勘查花园外围，对凶手特征做出范围估计\n可探索区域：花园小径、路边草地、人行道\n可使用工具：卷尺、放大镜","","guide"]]), "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	# 对齐 08 稿 v3.16.0 场景二：本阶段改为 福尔摩斯+华生 现场引导
	#（移除原 b0-b5 葛莱森/雷斯垂德对话——按"场景二只留福尔摩斯+华生"对齐要求）。
	_start_dialogue(_make_nodes([
		["b0","福尔摩斯","华生，站住。别急着进屋——苏格兰场的人已经在里面了，他们只会把现场越弄越乱。","","从容"],
		["b1","华生","（环顾四周）那我们……就在外面看？","","思考"],
		["b2","福尔摩斯","对。雨后的泥地是最好的记录者：车轮印、马蹄印、还有脚印。室外的痕迹，比屋里任何东西都诚实。","","指导"],
		["b3","华生","（点头）我明白了——从痕迹反推：什么车、什么人、几个人。","","思考"],
		["b4","福尔摩斯","（拍了拍你的肩）聪明。去吧，把每一条都看仔细。证据不会自己跳出来。","","自信"],
	]), "b0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_begin_observe("花园")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_prompt_think("福尔摩斯", "华生，证据齐全了。把这些线索摆上推理墙——什么车、什么人、几号人，在案发那晚进过这座花园。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	# 对齐 08 稿 v3.16.0 场景二「阶段末：场景小结与进入室内」（L1173-1198）+ Q4 条件化教学时刻：
	#   简单 = 完整教学（逐条讲解第一/二/三线索 + 「三条线指向同一个人」哲理）
	#   普通 = 标准总结（原 c0-c8）
	#   困难 = 精简（仅总结 + 谜题钩子，去掉教学长段与过渡闲笔）
	var diff := DifficultyManager.Difficulty.NORMAL
	if DifficultyManager: diff = DifficultyManager.current_difficulty
	var nodes: Array[Resource] = []
	if diff == DifficultyManager.Difficulty.EASY:
		nodes = _make_nodes([
			["c0","福尔摩斯","（直起身，拍掉手上的泥）好了，外面能看的差不多了。","ct","从容"],
			["ct","福尔摩斯","他们乘出租马车来的；马车的右前蹄铁是新换的；赶车的不在车上——他进了那栋房子。两个人，一个高个子，一个矮一些。","ca","自信"],
			["ca","福尔摩斯","（突然转向玩家，教学时刻的口吻）等一下。在我们进去之前——我希望你把刚才收集的三条证据，亲手连成一条链。","cb","指导"],
			["cb","福尔摩斯","第一——车轮印的轴距3.8英尺，符合伦敦出租四轮马车。私家马车不会这么窄，因为它们不钻小巷。→ 来的是一辆出租马车。","cc","指导"],
			["cc","福尔摩斯","第二——右前蹄铁是新的，其他三个磨损。正常使用的马，四个蹄铁磨损应大致均匀。→ 这匹马最近被特别关照过——很可能就是来过案发现场。","cd","指导"],
			["cd","福尔摩斯","第三——马蹄印零乱无章，不是直线行进。一匹正常工作的马不会这样。→ 赶车的人不在车上。他下了车。","ce","指导"],
			["ce","福尔摩斯","把这三条串起来——一辆出租马车、一匹刚换过蹄铁的马、一个不在车上的车夫。他进了那栋空房子。","cf","自信"],
			["cf","福尔摩斯","以后遇到案子，先问自己：'有几条线在指向同一个方向？'一条线可能是巧合，两条线可能是偶然，三条线指向同一个人——就是答案。","c2","哲理"],
			["c2","华生","那我们……进去吗？","c3","思考"],
			["c3","福尔摩斯","（看向空屋的门）当然。真正的好戏在里面。","c4","从容"],
			["c4","华生","（皱眉，低声）等等——马车夫进了屋……但他是一个人吗？死者为什么会跟他进去？","c5","疑惑"],
		["c5","福尔摩斯","（嘴角微微上扬）好问题。警察在屋里了，葛莱森警长和雷斯垂德警长——两位正在为我们争取时间。我们进去看看就知道了。","c8","狡黠"],
		["c8","system","（谜题钩子）马蹄印显示：一个新蹄铁，三个旧蹄铁——全城那么多出租马车，怎么找到这一匹？此问题已记入推理战场待验证。","","guide"],
		])
	elif diff == DifficultyManager.Difficulty.HARD:
		nodes = _make_nodes([
			["c0","福尔摩斯","（直起身）外面收完了。","c1","从容"],
			["c1","福尔摩斯","出租马车、新蹄铁、不在车上的车夫——两人进过花园。剩下的，屋里见。","c4","自信"],
			["c4","华生","等等——马车夫进了屋……但他是一个人吗？","c5","疑惑"],
			["c5","福尔摩斯","（嘴角微扬）好问题。警察在屋里了，葛莱森警长和雷斯垂德警长——两位正在为我们争取时间。进去。","c8","狡黠"],
			["c8","system","（谜题钩子）一个新蹄铁，三个旧蹄铁——全城那么多出租马车，怎么找到这一匹？此问题已记入推理战场待验证。","","guide"],
		])
	else:
		nodes = _make_nodes([
			["c0","福尔摩斯","（直起身，拍掉手上的泥）好了，外面能看的差不多了。","c1","从容"],
			["c1","福尔摩斯","他们乘出租马车来的；马车的右前蹄铁是新换的；赶车的不在车上——他进了那栋房子。两个人，一个高个子，一个矮一些。","c2","自信"],
			["c2","华生","那我们……进去吗？","c3","思考"],
			["c3","福尔摩斯","（看向空屋的门）当然。真正的好戏在里面。","c4","从容"],
			["c4","华生","（皱眉，低声）等等——马车夫进了屋……但他是一个人吗？死者为什么会跟他进去？","c5","疑惑"],
		["c5","福尔摩斯","（嘴角微微上扬）好问题。警察在屋里了，葛莱森警长和雷斯垂德警长——两位正在为我们争取时间。我们进去看看就知道了。","c8","狡黠"],
		["c8","system","（谜题钩子）马蹄印显示：一个新蹄铁，三个旧蹄铁——全城那么多出租马车，怎么找到这一匹？此问题已记入推理战场待验证。","","guide"],
		])
	_start_dialogue(nodes, "c0", _go_to_next_scene)

func _go_to_next_scene() -> void:
	# 过渡对话结束后弹出「侦破过程」评价面板（风格对齐场景一），点继续再存档进入下一场景
	_show_scene_rating("场景二 完成 · 侦破过程", "res://scenes/scene3.tscn", Callable(self, "_save_and_transition").bind("scene2", "res://scenes/scene3.tscn"))

# ===== 读档分支（ClueSystem 同步与通知已由基类 _restore_saved_state 完成） =====
func _apply_restored_phase(p: int, ids: Array, _clues_arr: Array) -> bool:
	_phase = p
	match p:
		Phase.ARRIVAL:
			_enter_arrival(); return true
		Phase.DETECTIVE_DIALOGUE:
			_show_detective_dialogue(); return true
		Phase.OBSERVE:
			_phase = Phase.OBSERVE
			var total := STREET_HOTSPOTS.size() + PATH_HOTSPOTS.size()
			if _clues.size() >= total:
				# 死局防御：线索已集齐但阶段还停在勘查——all_recorded 不会再触发
				_enter_reasoning(); return true
			# 按已收集数决定恢复在哪一子阶段：<4 → 街道勘查；≥4（街道已集齐）→ 花园通道勘查
			if _clues.size() >= STREET_HOTSPOTS.size():
				_stage = STAGE_PATH
				_ui.set_scene_background(load("res://assets/scenes/sc02_path.png"))
				_ui.restore_observer(_path_obs, ids, _path_owned_ids())
				_ui.set_dialogue("提示", "已恢复进度 — 花园通道勘查阶段（已收集 " + str(_clues.size()) + "/" + str(total) + " 条）")
			else:
				_stage = STAGE_STREET
				_ui.set_scene_background(load("res://assets/scenes/sc02_street.png"))
				_ui.restore_observer(_street_obs, ids, _street_owned_ids())
				_ui.set_dialogue("提示", "已恢复进度 — 街道勘查阶段（已收集 " + str(_clues.size()) + "/" + str(total) + " 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			# 终局（已过场）读档：直接展示「侦破过程」结束面板（对齐场景一读档直接 _show_rating），
			# 而不是重放过场对话。_suppress_terminal_save 已由基类置 true，点「继续推进」时
			# _save_and_transition 会跳过重复存档、直接切入下一场景。
			_show_scene_rating("场景二 完成 · 侦破过程", "res://scenes/scene3.tscn", Callable(self, "_save_and_transition").bind("scene2", "res://scenes/scene3.tscn"))
			return true
	return false

# ===== Q2 推理墙四档回应（覆盖基类 _default_wall_verify）=====
# 验证后按整体 verdict 播放场景二专属四档回应（对齐 08 稿场景二 Step6 + 阶段末教学），
# 播完再按 advance 推进过渡（REASONING 阶段 / 线索收满）或回观察（预览墙）。
# 机制与场景一 _show_*_verdict_dialogue 一致：墙只调 on_verify(verdict)，推进由本回调内部负责。
func _default_wall_verify(verdict: int) -> void:
	var fb = {
		0: ["错误 ❌", Color(0.95, 0.3, 0.3)],
		1: ["存疑 ❓", Color(0.95, 0.8, 0.2)],
		2: ["正确 ✅", Color(0.4, 0.85, 0.4)],
		3: ["正确 🌟", Color(0.3, 0.95, 0.3)],
	}
	var entry = fb.get(verdict, ["等待", Color.WHITE])
	_ui.show_notification("推理验证结果：" + entry[0])
	# 推进判定与基类一致：仅 REASONING 阶段或线索已收满才推进；OBSERVE 阶段提前开墙属预览，不推进。
	var advance := _in_reasoning_phase() or (_clues.size() >= hotspots().size())
	_show_scene2_verdict_dialogue(verdict, advance)

func _show_scene2_verdict_dialogue(v: int, advance: bool) -> void:
	if _ui: _ui.set_camera_enabled(false)   # 验证回应：禁用摄像机
	var diff := DifficultyManager.Difficulty.NORMAL
	if DifficultyManager: diff = DifficultyManager.current_difficulty
	var nodes: Array[Resource] = []
	match v:
		3:  # VERIFIED —— 总结式四档，对齐「三条线指向同一个人」
			nodes.append(_mk_node("v1","福尔摩斯","（点头）不错。三条不同方向的线索，同时指向同一个人——这就是回溯推理。","click",["v2"],[],"认可"))
			if diff == DifficultyManager.Difficulty.EASY:
				nodes.append(_mk_node("v2","福尔摩斯","第一——车轮印轴距3.8英尺，符合伦敦出租四轮马车，私家马车不会这么窄；第二——右前蹄铁是新的，这匹马最近被特别关照过；第三——马蹄印零乱，赶车的人不在车上，他下了车。","click",["v3"],[],"指导"))
				nodes.append(_mk_node("v3","福尔摩斯","把这三条串起来：一辆出租马车、一匹刚换过蹄铁的马、一个不在车上的车夫——他进了那栋空房子。记住：一条线可能是巧合，两条线可能是偶然，三条线指向同一个人，就是答案。","click",["v4"],[],"哲理"))
				nodes.append(_mk_node("v4","华生","（在小本子上记）三条线——同一个方向——就是答案……","click",["end"],[],"思考"))
			else:
				nodes.append(_mk_node("v2","华生","（在小本子上记）三条线指向同一个人……","click",["end"],[],"思考"))
		2:  # SUPPORTED
			nodes.append(_mk_node("v1","福尔摩斯","方向对了，但你的链子有一环只是'可能'。进去之后，室内的证据会替你补上。","click",["end"],[],"从容"))
		1:  # INSUFFICIENT
			nodes.append(_mk_node("v1","福尔摩斯","你下的结论，跑得比证据快了。先回去把轴距、蹄铁、脚印重新看一遍。","click",["end"],[],"从容"))
		_:  # CONTRADICTORY(0)
			nodes.append(_mk_node("v1","福尔摩斯","你的链子自己打架了。马车、蹄铁、脚印指向的不是一个人。推翻重来。","click",["end"],[],"从容"))
	if nodes.is_empty():
		nodes.append(_mk_node("v1","福尔摩斯","（看着推理墙）再想想。","click",["end"],[],"从容"))
	_start_dialogue(nodes, "v1", _on_scene2_verdict_end.bind(advance))

func _on_scene2_verdict_end(advance: bool) -> void:
	if _ui: _ui.set_camera_enabled(true)
	if advance:
		_advance_now()
	else:
		# 预览墙（OBSERVE 阶段提前开墙提交）：不推进，回到观察继续收集线索
		_ui.reset_camera()
		_current_observer().show()
		_ui.set_dialogue("提示", "推理墙预览结束，继续收集线索。")
