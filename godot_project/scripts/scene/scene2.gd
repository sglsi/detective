extends DetectiveScene
## Scene 2 — 劳瑞斯顿花园街3号 · 案发现场（室外）
## 架构：继承统一框架 DetectiveScene（与场景三完全一致，所有机制在基类中）。
## 本文件只提供「内容」：热点、对话、推理假设、面板文案、流程分支。
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.3

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

const HOTSPOTS = [
	# ── 勘查对象A：车轮印迹（08稿 六步闭环 Step1-3+6）──
	# 2026-08-12 修复：场景可视区 y 范围为 50~850（dialogue_bar 从 850 开始），
	# 因此热点 bottom 必须 < 850，否则圆圈被 clip_contents 裁掉、点击也被 bar 吞掉。
	# 当前分布：c201/c205/c206 放在前景底部（仍处可视区内），其余按车道位置保留。
	# 每个热点都带 image+anchor，点击后像场景1一样弹出背景放大框+底部线索说明。
	{"id":"c201","label":"碾轧的花草","x":180,"y":800,"w":150,"h":42,
	 "desc":"路边草地被压过了——两道平行的印子，草地上有两道平行的凹痕，像是车轮碾轧留下的。有马车在此停靠过。","tool":"none",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c201"},
	{"id":"c202","label":"平行车轮印","x":880,"y":660,"w":150,"h":42,
	 "desc":"用卷尺测量：轴距约3.8英尺，轮宽约2英寸，压痕最深处约1.2英寸。查知识库·伦敦马车类型：出租四轮马车轴距约3.8~4.0英尺，车身较窄以适应伦敦小巷——这是一辆出租马车。伦敦的出租马车为了钻小巷，轴距都做窄了，私家马车不会这么窄。","tool":"卷尺",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c202"},
	# ── 勘查对象B：马蹄印迹（08稿 六步闭环）──
	{"id":"c203","label":"右前蹄新蹄铁","x":1200,"y":700,"w":150,"h":42,
	 "desc":"放大镜下：四个蹄铁磨损程度不同——右前蹄铁特别新，边缘锐利，亮得像刚从铁匠铺出来的；其余三个有不同程度磨损。这匹马的右前蹄铁是最近换的。","tool":"none",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c203"},
	{"id":"c204","label":"马蹄印迹零乱","x":760,"y":790,"w":150,"h":42,
	 "desc":"蹄印方向散乱，有迂回和停顿痕迹，非正常行进路线——如果有人驾驭，马不会走得这么乱。赶车的不在车上，马曾无人看管：马车夫很可能进了那栋房子。","tool":"none",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c204"},
	# ── 勘查对象C：步伐距离（08稿 六步闭环）──
	{"id":"c205","label":"两组不同脚印","x":1000,"y":800,"w":150,"h":42,
	 "desc":"泥地里有两组明显不同的脚印，部分叠在另一部分上面（有先后顺序），且都在警察脚印之下——案发当晚有两个人来过。放大镜下：大步子的脚印是方头靴，小步子是漆皮靴。方头靴多为干体力活的人穿，漆皮靴多为体面人士。","tool":"卷尺",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c205"},
	{"id":"c206","label":"步伐距离差异","x":1280,"y":790,"w":150,"h":42,
	 "desc":"卷尺测量：大步子步幅约4.5英尺，小步子约3.5英尺。查知识库·步态与身高（步幅约为身高的0.45倍）：步幅4.5英尺→身高约6英尺（183cm）的大个子；步幅3.5英尺→身高约5英尺4英寸（163cm）。步幅骗不了人。","tool":"卷尺",
	 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c206"},
]

# ===== 框架配置 =====
func scene_id() -> String: return "scene2"
func clue_source() -> String: return "garden"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "劳瑞斯顿花园街 3号"
func scene_time_text() -> String: return "DAY 1 上午11:15"
@export var procedural_bg: bool = false

func use_procedural_background() -> bool: return procedural_bg
func wants_atmosphere() -> bool: return false

func scene_background() -> Texture2D: return load("res://assets/scenes/sc_02_garden.png")

# ===== 阶段 / 进度判断 =====
func _is_terminal_phase(p: int) -> bool:
	return p == Phase.TRANSITION

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "抵达案发现场"
		Phase.DETECTIVE_DIALOGUE: return "警长对话"
		Phase.OBSERVE: return "花园勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool:
	return _phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION

# ===== 观察 / 动作文案 =====
func _observe_locked_msg() -> String: return "请先听取警长们的现场说明"
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

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查花园。"
func _journal_empty_hint() -> String: return "去花园勘查现场痕迹"

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，花园里的痕迹全都记录好了——轴距3.8英尺的车轮印、右前蹄的新蹄铁、两组不同步幅的足迹……证据很充足。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "案发当晚的交通与人员（推理战场 M1）",
		"description": "一辆伦敦出租马车停在花园街3号门口，驾车者高大男性，另一人同行进入花园。\n\n活跃假设：\n· H2-01 凶手乘出租马车来（强）\n· H2-02 凶手身高6英尺以上（中·范围估计）\n· H2-03 凶手穿方头靴（中）\n· H2-04 凶手体格强壮（弱-中·可选）\n· H2-05 凶手中年人（弱·可选）\n\n矛盾标记：\n· C2-01 两组不同脚印（方头靴 vs 小步皮靴）\n· C2-02 乘马车来 vs 泥地大步走\n· C2-03 新蹄铁三只旧蹄铁 vs 统一蹄铁\n\n苏格兰场假设池：葛莱森=政治阴谋灭口（弱）/ 雷斯垂德=情杀（弱）。",
		"battlefield": {
			"hypotheses": [
				{"id":"H2-01","text":"凶手乘出租马车来到花园街3号","correct":true},
				{"id":"H2-02","text":"凶手身高六英尺以上","correct":true},
				{"id":"H2-03","text":"凶手穿方头靴","correct":true},
				{"id":"H2-04","text":"凶手体格强壮","correct":true},
				{"id":"H2-05","text":"凶手中年人","correct":true}
			],
		"contradictions": [
			{"id":"C2-01","text":"现场出现两组不同脚印（方头靴 vs 小步皮靴）","correct":true},
			{"id":"C2-02","text":"乘马车来 vs 泥地大步走进入花园","correct":true},
			{"id":"C2-03","text":"一只马蹄铁是新的、其余三只是旧的","correct":true}
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
	"expected_clues": HOTSPOTS.size(),
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
	return ["抵达案发现场", "听取警长汇报", "勘查花园痕迹", "推理墙验证"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= HOTSPOTS.size(), _phase >= Phase.REASONING]

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
		["a3","福尔摩斯","先别急着进去。在进入现场之前，外围的痕迹往往比室内更有价值。雨后的泥地是最好的记录者。","","指导"],
		["a4","系统","【场景目标】勘查花园外围，对凶手特征做出范围估计\n可探索区域：花园小径、路边草地、人行道\n可使用工具：卷尺、放大镜","","guide"]]), "a0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	# 对齐 02 稿 §10.8 苏格兰场竞争暗线：警长仅提供背景与各自立场，
	# 血字的现场分析（左手/伪装等）属场景三内容，此处不提前泄露。
	# ⚠️ 不同难度不同引导：b5 之后分流（b5_e→b5_n→b5_h→end），难度过滤节点链式为 next，
	#    引擎 skip-walk 走到当前难度第一个可见变体（简单逐条点出部位 / 普通标准 / 困难无引导）。
	_start_dialogue([
		_mk_node("b0","葛莱森","福尔摩斯先生，您总算来了。昨晚巡警在这座空屋里发现一具男尸——没有外伤，屋里的东西我们都没动。","click",["b1"]),
		_mk_node("b1","雷斯垂德","（拍了拍身上的灰）我也刚到。附近居民昨晚听到过马车声和马蹄声，天亮前还有人看见一个醉汉在街上踉跄。","click",["b2"]),
		_mk_node("b2","葛莱森","（压低声音）我看这是桩政治阴谋——某个秘密团体的灭口行动。雷斯垂德那套情杀论？太俗套。","click",["b3"]),
		_mk_node("b3","雷斯垂德","（哼了一声）我倒觉得是私人恩怨。死者衣着体面，因爱生恨才是最常见的杀人动机。某人总喜欢把事情想复杂。","click",["b4"]),
		_mk_node("b4","福尔摩斯","（并不接话，蹲下身看向泥地）两位的推论，都会进推理战场当'待验证假设'——但真相得靠证据说话。","click",["b5"]),
		_mk_node("b5","福尔摩斯","华生，先别进屋。雨后的泥地是最好的记录者。","click",["b5_e","b5_n","b5_h"]),
		_mk_node("b5_e","福尔摩斯","（低声）注意车轮印的间距、四个蹄印的磨损差异、还有脚印的多少和大小——每一条都可能是线索，逐一查清楚。","click",["b5_n"],[],"指导",1),
		_mk_node("b5_n","福尔摩斯","用你的眼睛找证据：车轮印、蹄印、脚印。别被警长的推论带偏。","click",["b5_h"],[],"指导",2),
		_mk_node("b5_h","福尔摩斯","（望着泥地）……证据就在这片泥里。你自己看，别等我喂。","click",["end"],[],"从容",3)], "b0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_begin_observe("花园")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_prompt_think("福尔摩斯", "华生，证据齐全了。把这些线索摆上推理墙——什么车、什么人、几号人，在案发那晚进过这座花园。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	# 对齐 08 稿 v3.16.0 场景二"阶段末：场景小结与进入室内"（L1173-1198）+ 02 稿 §10.11 双钩子
	_start_dialogue(_make_nodes([
		["c0","福尔摩斯","（直起身，拍掉手上的泥）好了，外面能看的差不多了。","","从容"],
		["c1","福尔摩斯","他们乘出租马车来的；马车的右前蹄铁是新换的；赶车的不在车上——他进了那栋房子。两个人，一个高个子，一个矮一些。","","自信"],
		["c2","华生","那我们……进去吗？","","思考"],
		["c3","福尔摩斯","（看向空屋的门）当然。真正的好戏在里面。","","从容"],
		["c4","华生","（皱眉，低声）等等——马车夫进了屋……但他是一个人吗？死者为什么会跟他进去？","","疑惑"],
		["c5","福尔摩斯","（嘴角微微上扬）好问题。进去看看就知道了。","","狡黠"],
		["c6","葛莱森","福尔摩斯，你看出什么了？"],
		["c7","福尔摩斯","（头也不回，低声自语）有意思……这位凶手比我想象的更懂章法。进去看看就知道了。","","从容"],
		["c8","system","（谜题钩子）马蹄印显示：一个新蹄铁，三个旧蹄铁——全城那么多出租马车，怎么找到这一匹？此问题已记入推理战场待验证。","guide"]]), "c0", _go_to_next_scene)

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
			if _clues.size() >= HOTSPOTS.size():
				# 死局防御：线索已集齐但阶段还停在勘查——all_recorded 不会再触发
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ids, _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 花园勘查阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size()) + " 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			_enter_transition(); return true
	return false
