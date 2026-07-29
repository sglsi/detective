extends DetectiveScene
## Scene 3 — 劳瑞斯顿花园街3号 · 室内（尸体现场）
## 架构：与场景二继承同一个统一框架 DetectiveScene，二者结构完全一致，
## 仅「内容」不同（clue_source=indoor、9 处热点、对话与推理假设）。
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.4

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

const HOTSPOTS = [
	# ── 死者与尸体 ──
	{"id":"c301","label":"德雷伯名片","x":320,"y":150,"w":200,"h":46,
	 "desc":"死者衣袋里掉落的名片：伊诺克·J·德雷伯，美国克利夫兰人。这是辨认死者身份的第一条线索。","tool":"none"},
	{"id":"c302","label":"死尸无外伤","x":560,"y":150,"w":220,"h":46,
	 "desc":"尸体表面没有任何殴打、刀伤或勒痕，面色青紫——典型的非暴力中毒死亡。用化学试剂盒检验，确认血液里有生物碱残留。","tool":"化学试剂盒"},
	{"id":"c303","label":"面部痉挛痕迹","x":810,"y":150,"w":220,"h":46,
	 "desc":"死者面部保留着极度痛苦的痉挛扭曲，是死前剧烈绞痛的表现，符合生物碱类毒物（如苦杏仁酸/番木鳖碱）中毒特征。用放大镜细看更明显。","tool":"放大镜"},
	# ── 血字 ──
	{"id":"c304","label":"\"RACHE\"血字","x":1060,"y":150,"w":240,"h":46,
	 "desc":"墙上用血写下的「R-A-C-H-E」——德语「复仇」之意。但福尔摩斯判断：真正的德国人不会在作案现场用母语留字，这是刻意伪装。用放大镜细看笔迹。","tool":"放大镜"},
	{"id":"c305","label":"血字笔顺异常","x":1330,"y":150,"w":240,"h":46,
	 "desc":"血字笔画歪斜、起笔拖沓、收尾草率，像是凶手用左手蘸血、随手涂抹而成，而非从容书写。这进一步证明血字是伪装。","tool":"放大镜"},
	# ── 戒指与随身物 ──
	{"id":"c306","label":"戒指内刻\"L·F\"","x":320,"y":560,"w":240,"h":46,
	 "desc":"死者右手紧攥一枚女式结婚戒指，内圈刻着「L·F」——属于一位女性，并非德雷伯的原配妻子。这是本案的核心线索。","tool":"none"},
	{"id":"c307","label":"共济会图案","x":600,"y":560,"w":220,"h":46,
	 "desc":"戒指侧面刻有共济会式样的图案——或许购买渠道与共济会成员有关。但福尔摩斯认为这多半是干扰项，别被带偏。用放大镜看。","tool":"放大镜"},
	{"id":"c308","label":"礼帽（坎伯韦尔路）","x":860,"y":560,"w":200,"h":46,
	 "desc":"角落里一顶高档礼帽，内衬标着坎伯韦尔路的帽商标记——指向物品购买地点。困难模式下才是关键细节奖励。","tool":"none"},
	{"id":"c309","label":"死者随身财物","x":1100,"y":560,"w":220,"h":46,
	 "desc":"金表、金链、书信等随身财物原封未动——死者并未遭抢劫，作案动机不在钱财。","tool":"none"},
	# ── 沉默线索 D1（自由发现，无对话无任务指引，给洞察之星奖励；详见 02 §11）──
	{"id":"d1_top","label":"墙角杂物堆（木陀螺）","x":320,"y":760,"w":240,"h":46,
	 "desc":"墙角杂物堆深处，一个手工木陀螺静静躺着——漆皮剥落，缠线还在。没有任务指引，也没有对话，只是个被人遗忘的玩具。（沉默线索 D1：自由探索发现，额外给洞察之星奖励）","tool":"放大镜","silent":true},
]

# ===== 框架配置 =====
func scene_id() -> String: return "scene3"
func clue_source() -> String: return "indoor"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "劳瑞斯顿花园街 3号 · 室内"
func scene_time_text() -> String: return "DAY 1 正午12:05"
@export var procedural_bg: bool = false

func use_procedural_background() -> bool: return procedural_bg

func scene_background() -> Texture2D: return load("res://assets/scenes/sc_03_indoor.png")

# ===== 阶段 / 进度判断 =====
func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "进入尸体现场"
		Phase.DETECTIVE_DIALOGUE: return "警长说明"
		Phase.OBSERVE: return "室内勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool:
	return _phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION

# ===== 观察 / 动作文案 =====
func _observe_locked_msg() -> String: return "请先听完警长对现场的说明"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击屋内的标记点进行勘查"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 仔细检查血字与尸体细节"

func _hotspot_tip(tool: String) -> String:
	match tool:
		"放大镜": return "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": return "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "雷斯垂德指着墙角：\"尸体就在这儿，表面一点伤都没有——葛莱森说他从没见过这种死法。墙上那几个血字，你看见了吧？\""
		2,3: return "葛莱森压低声音：\"血字写的是 R-A-C-H-E，德语'复仇'。我们猜凶手是个德国人。你看这人脸，死前像疼得抽搐过。\""
		4,5: return "福尔摩斯俯身：\"血字笔画歪斜，是用左手蘸血随手抹的——真德国人不会在案发现场留母语字。这是伪装。\""
		6,7: return "福尔摩斯拾起那枚戒指：\"看内圈的'L·F'。这是女人的结婚戒指，不是德雷伯的原配。真正的线索在这枚戒指上。\""
		_: return "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙，串起死因、血字和这枚戒指。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查室内。"
func _journal_empty_hint() -> String: return "去室内勘查尸体与血字"

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，屋里的线索都记下了——尸体的中毒痕迹、墙上的血字、还有那枚刻着「L·F」的戒指……指向的恐怕不是德国人。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "死者身份、死因与血字真相（推理战场 M1）",
		"description": "死者是美国克利夫兰人德雷伯，死于生物碱中毒（非暴力）；墙上的「RACHE」血字是凶手伪装成德国人复仇的假象，真正的线索是那枚刻着「L·F」的女性结婚戒指。\n\n活跃假设：\n· H3-01 死者死于服毒非外伤（强）\n· H3-02 血字RACHE是德语'复仇'（中强）\n· H3-03 血字不是德国人写的（中·需Step4检索）\n· H3-04 凶手右手指甲很长（弱·需细看）\n· 承接 H2-02→身高约6英尺 / H2-03→方头靴（升级为强）\n\n矛盾标记：\n· C3-01 服毒死亡 vs 现场无药瓶\n· C3-02 复仇杀人 vs 带走凶器（药瓶）\n· C3-03 血字是德语 vs 书写者不像德国人\n· C3-04 情杀论（戒指）vs 服毒预谋杀人\n\n自我误导陷阱 C-06：指甲缝白色粉末——易误判为毒粉，实为凶手写血字刮下的墙粉。",
		"battlefield": {
			"hypotheses": [
				{"id":"H3-01","text":"死者死于服毒而非外伤","correct":true},
				{"id":"H3-02","text":"血字 RACHE 意为德语「复仇」","correct":true},
				{"id":"H3-03","text":"血字并非德国人所写（伪装）","correct":true},
				{"id":"H3-04","text":"凶手右手指甲很长","correct":true}
			],
			"contradictions": [
				{"id":"C3-01","text":"服毒死亡 vs 现场无药瓶","correct":true},
				{"id":"C3-02","text":"复仇杀人 vs 带走凶器（药瓶）","correct":true},
				{"id":"C3-03","text":"血字是德语 vs 书写者不像德国人","correct":true},
				{"id":"C3-04","text":"情杀论（戒指）vs 服毒预谋杀人","correct":true},
				{"id":"C-06","text":"自我误导：指甲缝白色粉末=墙粉而非毒粉","correct":true}
			],
		}
	}

# ===== 面板内容 =====
func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号·室外", "d":"案发现场花园 — 场景二"},
		{"t":"花园街3号·室内", "d":"尸体现场 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["进入尸体现场", "听取警长说明", "勘查尸体与血字", "推理墙验证"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= HOTSPOTS.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单", "普通", "困难"][_difficulty] + " — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"🔍 放大镜：查看血字笔顺、面部痉挛等细节",
		"🧪 化学试剂盒：场景三起可用，检验尸体中毒痕迹",
		"💡 核心：墙上的「RACHE」是伪装，戒指「L·F」才是真线索",
		"音效：MVP 阶段暂无（M3 补全）",
	]

# ===== 对话阶段 =====
func _enter_arrival() -> void:
	_start_dialogue(_make_nodes([
		["i0","葛莱森","跟我来。死者的遗体还在里面，原封没动过——就躺在这间空屋的地板上。"],
		["i1","华生","（迈入屋内）煤气灯早就熄了，壁炉里只剩冷灰。这屋子空得让人发毛。","","凝思"],
		["i2","福尔摩斯","（环视四周）血字写在墙上，尸体倒在墙角。凶手进过这间屋，却不拿财物——有意思。","","思考"],
		["i3","葛莱森","雷斯垂德已经在里头了，他第一个发现血字。让他给你讲讲经过。"]]), "i0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	_start_dialogue(_make_nodes([
		["j0","雷斯垂德","福尔摩斯，你说巧不巧——墙上这几个字母：R-A-C-H-E。德语，'复仇'的意思。我们多半是碰上德国人了。"],
		["j1","葛莱森","尸体一点外伤都没有，脸色发青，像是中了毒。我们猜凶手下了药。"],
		["j2","福尔摩斯","（凑近血字）德语没错。可你见过哪个真德国人，会在犯罪现场用母语留字、生怕别人认不出来？这字写得太刻意了。","","思考"],
		["j3","雷斯垂德","你是说……不是德国人？那这血字干嘛写的？"],
		["j4","福尔摩斯","伪装。凶手想把我们引向'复仇的德国人'。再看笔顺——歪歪扭扭，像左手蘸血随手抹的。华生，戴上你的放大镜，把屋里每样东西都看一遍：尸体、戒指、随身物。","","指导"]]), "j0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击屋内的标记点开始勘查（共 " + str(HOTSPOTS.size()) + " 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙整理。")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_ui.set_dialogue("福尔摩斯", "华生，证据齐了。把线索摆上推理墙——谁死了、怎么死的、那行血字是真还是假、那枚戒指又指向谁。", "自信")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_start_dialogue(_make_nodes([
		["k0","福尔摩斯","推理墙印证了：死者德雷伯，死于生物碱中毒；血字是伪装，凶手根本不是德国人。真正的线头，是那枚刻着'L·F'的戒指。","","自信"],
		["k1","华生","一枚女人的结婚戒指……德雷伯的原配可没来过伦敦。这背后还有个人。","","思考"],
		["k2","葛莱森","案子比我们想的复杂。接下来去奥德利大院，找找昨晚的巡警问问话。"],
		["k3","福尔摩斯","两位，我建议你们去问问附近的巡警——昨晚有人在这附近看到过一个醉汉，个子很高，脸很红。","","从容"],
		["k4","system","（谜题钩子）死者死于服毒，但现场没有药瓶——药去哪了？凶手为什么带走药瓶？此问题已记入推理战场待验证。","guide"]]), "k0", _go_to_next_scene)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		# 自动存档必须写入本场景的 scene_state（phase + scene_id + clue_ids），
		# 否则读档时 _restore_saved_state 因 scene_id 不匹配而判定「无存档」→ 场景从头重启。
		var ids: Array = []
		for c in _clues: ids.append(c.get("id", ""))
		await SaveSystem.request_save("scene3", Phase.TRANSITION, {"clue_ids": ids})
	SceneLoader.transition_to("res://scenes/scene4.tscn")

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
			_ui.set_dialogue("提示", "已恢复进度 — 室内勘查阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size()) + " 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			_enter_transition(); return true
	return false
