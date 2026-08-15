extends DetectiveScene
## Scene 3 — 劳瑞斯顿花园街3号 · 室内（尸体现场）
## 架构：与场景二继承同一个统一框架 DetectiveScene，二者结构完全一致，
## 仅「内容」不同（clue_source=indoor、9 处热点、对话与推理假设）。
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.4

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

const HOTSPOTS = [
	# 2026-08-15：按 sc_03_indoor_hd.jpg 实际内容重新分布。
	# 尸体位于画面中下部，故尸体/随身物品热点下移到躯干/手部区域；
	# 血字/烟灰放在后墙与右下角；脚印/戒指/杂物堆放在地板下半区。
	# 所有热点 bottom 仍保持 <850（对话栏起点），避免被 clip_contents 裁切。
	# ══ A 尸体检验（08稿 六步闭环 A-Step1~6）══
	{"id":"c301","relation_tags":["H3-01"],"label":"尸体·面部与姿态","x":840,"y":410,"w":220,"h":46,
	 "desc":"死者约四十三四岁，中等身材，宽宽的肩膀，黑色鬈发，短硬的胡子。僵硬的脸上露出恐怖、忿恨的表情；紧握双拳、两臂伸开、双腿交叠——临死前有过痛苦的挣扎。放大镜下：面部肌肉扭曲，瞳孔收缩。那种表情，不是一般的死亡。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c302","relation_tags":["H3-01","C3-01"],"label":"尸体·无外伤+嘴唇暗紫","x":880,"y":460,"w":240,"h":46,
	 "desc":"放大镜检查全身：无明显外伤，衣物完整无破损，指甲缝干净无搏斗痕迹；嘴唇黏膜呈暗紫色，微微张开，有少量泡沫状分泌物和极细的水疱。查知识库·生物碱中毒：可致面部痉挛、嘴唇发绀、瞳孔异常——无外伤+痛苦死亡+嘴唇暗紫，毒杀可能性很大。","tool":"化学试剂盒","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c303","label":"尸体·衣着整洁","x":1000,"y":520,"w":240,"h":46,
	 "desc":"身上穿着背心和厚厚的黑呢礼服上衣，浅色裤子，洁白的硬领和袖口整洁——死者衣着体面，身份不低。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ══ B 随身物品（08稿 六步闭环 B-Step1~6：九件物品）══
	{"id":"c304","label":"名片夹与两封信","x":1220,"y":480,"w":220,"h":46,
	 "desc":"俄国制皮名片夹，内有名片：伊诺克·J·德雷伯，克利夫兰——与金表背面「E.J.D.」刻字、衬衣缩写三重印证。两封信：一封寄给德雷伯，一封寄给斯特兰森，均来自盖恩轮船公司，通知轮船从利物浦启程的日期——他们正准备乘船回纽约。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c305","label":"金表金链与财物","x":620,"y":500,"w":220,"h":46,
	 "desc":"伦敦巴罗德公司金表、又重又结实的阿尔伯特金链、虎头狗造型红宝石金别针、零钱七英镑十三先令——全部原封未动。死者经济状况良好，且并未遭抢劫，作案动机不在钱财。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c306","label":"共济会金戒指","x":1260,"y":570,"w":200,"h":46,
	 "desc":"死者手上戴着一枚金戒指，刻着共济会图案，内侧有磨损痕迹——佩戴者通常是共济会成员。查知识库：共济会成员多为中产及以上阶层。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c307","label":"袖珍小说《十日谈》","x":460,"y":550,"w":220,"h":46,
	 "desc":"袖珍版薄伽丘《十日谈》，扉页手写着「约瑟夫·斯特兰森」——与信件收件人对上了。斯特兰森是死者的秘书或同伴，两人关系密切。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c308","label":"礼帽","x":340,"y":640,"w":200,"h":46,
	 "desc":"一顶整洁的礼帽，内衬标着帽商标记——指向物品购买地点，可循此溯源死者在伦敦的落脚处。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ══ C 现场痕迹（08稿 六步闭环 C-Step1~6）══
	{"id":"c309","relation_tags":["H3-02","H3-03","H3-04","C3-03","C-06"],"label":"\"RACHE\"血字","x":1450,"y":240,"w":220,"h":46,
	 "desc":"墙角花纸剥落处，黄色粉墙上用鲜血潦草地写着「RACHE」。卷尺测量：离地约6英尺（视线平行高度→书写者身高约6英尺）。放大镜下：笔画边缘有细微墙粉刮痕——写字的人指甲未修剪。查知识库：德语中 RACHE 意为「复仇」。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c310","label":"壁炉旁烟灰","x":1580,"y":640,"w":200,"h":46,
	 "desc":"壁炉旁有一小撮烟灰，颜色深黑、呈薄片状，灰烬结构疏松——与普通纸烟的灰白色粉末状烟灰明显不同。查知识库：这是印度雪茄的烟灰特征。但谁抽的，还不能定论。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c311","relation_tags":["H2-02","H2-03"],"label":"尘土脚印与靴印","x":420,"y":720,"w":260,"h":46,
	 "desc":"地板尘土中有两组不同的脚印：漆皮靴+方头靴——穿漆皮靴的那位，就躺在我们面前；方头靴属于另一个人。卷尺测量步幅约4.5英尺——和花园里的发现对上了：六英尺的高个子，方头靴。","tool":"卷尺","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c312","relation_tags":["C3-04"],"label":"女式结婚戒指","x":900,"y":660,"w":220,"h":46,
	 "desc":"搬动尸体时，一枚女式结婚戒指从尸体上滚落——尺码纤细，属于一位女性。它为什么会在死者身上？是死者带来的，还是凶手留下的？雷斯垂德认定这是情杀的铁证，但福尔摩斯不置可否。（关键线索 C_SOTCB_303，关联推理链#9复仇动机）","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ── 沉默线索 D1（自由发现，无对话无任务指引，给洞察之星奖励；详见 02 §11）──
	{"id":"d1_top","label":"墙角杂物堆（木陀螺）","x":200,"y":750,"w":220,"h":46,
	 "desc":"墙角杂物堆深处，一个老旧的木陀螺静静躺着——刻着简单的花纹，漆皮剥落，缠线还在，落满了灰。空屋里的儿童陀螺——这房子以前也住过一家人吧。（沉默线索 D1：自由探索发现，洞察之星+0.5）","tool":"放大镜","silent":true,"image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
]

# ===== 框架配置 =====
func scene_id() -> String: return "scene3"
func clue_source() -> String: return "indoor"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "劳瑞斯顿花园街 3号 · 室内"
func scene_time_text() -> String: return "DAY 1 正午12:05"
@export var procedural_bg: bool = false

func use_procedural_background() -> bool: return procedural_bg
func wants_atmosphere() -> bool: return false

func scene_background() -> Texture2D: return load("res://assets/scenes/sc_03_indoor_hd.jpg")

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
		0,1: return "福尔摩斯在旁观察：\"注意看他的脸——那种表情，不是一般的死亡。仔细看看嘴唇的颜色。\""
		2,3: return "福尔摩斯：\"没有外伤——注意，我说的是'没有外伤'。无外伤加痛苦死亡，这意味着什么？\""
		4,5: return "福尔摩斯：\"九件物品，每一件都在说话——你先听哪一件？表壳背面好像有字，戒指上注意图案。\""
		6,7: return "雷斯垂德得意地指着墙角：\"瞧瞧这个！RACHE——写字的人本来要写 RACHEL，一个女人的名字！\"福尔摩斯（摇头）：\"先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。\""
		_: return "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙——谁死了、怎么死的、血字是真是假、戒指又指向谁。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查室内。"
func _journal_empty_hint() -> String: return "去室内勘查尸体与血字"

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，屋里的线索都记下了——无外伤的尸体、暗紫的嘴唇、墙上的血字、印度雪茄烟灰、还有那枚女式结婚戒指……指向的恐怕不是德国人。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "死者身份、死因与血字真相（推理战场 M1）",
		"description": "死者是美国克利夫兰人德雷伯，死于生物碱中毒（非暴力）；墙上的「RACHE」血字是德语「复仇」，但书写者未必是德国人；搬动尸体时发现的女式结婚戒指是本案核心疑点——它是谁的？\n\n活跃假设：\n· H3-01 死者死于服毒非外伤（强）\n· H3-02 血字RACHE是德语'复仇'（中强）\n· H3-03 血字不是德国人写的（中·需Step4检索）\n· H3-04 凶手右手指甲很长（弱·需细看）\n· 承接 H2-02→身高约6英尺 / H2-03→方头靴（升级为强）\n\n矛盾标记：\n· C3-01 服毒死亡 vs 现场无药瓶\n· C3-02 复仇杀人 vs 带走凶器（药瓶）\n· C3-03 血字是德语 vs 书写者不像德国人\n· C3-04 情杀论（戒指）vs 服毒预谋杀人\n\n关键排除推理 C-06：死者指甲缝干净无墙粉，而血字笔画边缘有指甲刮痕——血字绝非死者所写；书写者（凶手）的指甲缝里必然残留白色墙粉，这是日后指认凶手的物证。",
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
			{"id":"C-06","text":"死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉","correct":true}
		],
		"milestones": [
			{"id":"S3-1","text":"死因为服毒（非外伤）"},
			{"id":"S3-2","text":"血字 RACHE 意为「复仇」"},
			{"id":"S3-3","text":"凶手右手指甲很长"},
			{"id":"S3-4","text":"死者身份：美国克利夫兰人德雷伯"},
			{"id":"S3-5","text":"凶手伪装德语书写（非德国人）"},
		{"id":"S3-6","text":"凶手指甲缝必沾墙粉（决定性细节）"},
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
		"💡 核心：RACHE=德语「复仇」，但写字的人是德国人吗？戒指又是谁的？",
		"音效：MVP 阶段暂无（M3 补全）",
	]

# ===== 对话阶段 =====
func _enter_arrival() -> void:
	acquire_prop("ring", "结婚金戒指", "案发现场拾得的女式结婚戒指，尺码纤细，内侧刻字模糊——关键物证", "res://assets/props/ring.png")
	# 对齐 08 稿 v3.16.0 场景三·入场（L1214-1229）
	_start_dialogue(_make_nodes([
		["i0","系统","（演出）福尔摩斯走向空屋的门，手按在门把手上。门缓缓推开——一股幽暗的气息扑面而来。","","guide"],
		["i1","系统","屋内光线昏暗，壁炉台上一支红蜡烛摇曳着微光。一具尸体倒在地板上，周围散落着各种痕迹。","","guide"],
		["i2","福尔摩斯","（环视四周，低声）华生，看看这间屋子。尸体、物品、痕迹——三条线，从哪里开始，你说了算。","","从容"]]), "i0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	# 对齐 08 稿 v3.16.0 场景三 C-Step1 警长斗嘴（L1564-1572）+ 02 稿 §11.8 竞争暗线
	# ⚠️ 不同难度不同引导：j5 之后分流（j5_e→j5_n→j5_h→end），难度过滤节点链式为 next。
	_start_dialogue([
		_mk_node("j0","葛莱森","（从门口走进来，拍了拍身上的灰）雷斯垂德，你怎么也来了？这案子是我先找上福尔摩斯先生的。","click",["j1"]),
		_mk_node("j1","雷斯垂德","（反唇相讥，眼睛还盯着墙角）这么大的案子，我不来，某人怕是要走错方向。空屋男尸无伤痕——光靠你那套'查帽子找身份'的老办法，能查到什么时候？","click",["j2"]),
		_mk_node("j2","葛莱森","（脸微微一沉）我已经查明死者身份了。你呢？除了墙上几个字，还发现了什么？","click",["j3"]),
		_mk_node("j3","雷斯垂德","（得意地指着墙角）瞧瞧这个！RACHE——写字的人本来要写 RACHEL，一个女人的名字！","click",["j4"]),
		_mk_node("j4","福尔摩斯","（不置可否，看向华生）你怎么看？","click",["j5"]),
		_mk_node("j5","福尔摩斯","别急着站队。尸体、物品、痕迹——把屋里每样东西都看一遍。","click",["j5_e","j5_n","j5_h"]),
		_mk_node("j5_e","福尔摩斯","（低声）先从尸体看起：有没有外伤、嘴唇什么颜色；再翻九件物品；最后看血字和脚印。每样都别漏。","click",["j5_n"],[],"指导",1),
		_mk_node("j5_n","福尔摩斯","让证据自己说话：尸体、物品、痕迹，哪条不对劲就记哪条。","click",["j5_h"],[],"指导",2),
		_mk_node("j5_h","福尔摩斯","（环视屋子）……屋里每样东西都会说话。你自己看，别先信警长的结论。","click",["end"],[],"从容",3)], "j0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_begin_observe("屋内")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_prompt_think("福尔摩斯", "华生，证据齐了。把线索摆上推理墙——谁死了、怎么死的、那行血字是真还是假、那枚戒指又指向谁。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	# 对齐 08 稿 v3.16.0 场景三·阶段末小结（L1740-1786）+ 02 稿 §11.11 双钩子
	_start_dialogue(_make_nodes([
		["k0","福尔摩斯","好，我们来理一理目前确定的——死者德雷伯，美国人，克利夫兰来的。没有外伤，但死相恐怖——毒杀的可能性很大。","","从容"],
		["k1","福尔摩斯","现场有两个人：一个穿漆皮靴，就是死者；一个穿方头靴，高个子。墙上的血字'RACHE'，德语里是复仇的意思。烟灰是印度雪茄。他有个同伴叫斯特兰森，两人正准备乘船回纽约。","","自信"],
		["k2","福尔摩斯","这些是我们手里的牌——不多，但每一张都是实的。下一步，去找发现尸体的警察，看看他还能告诉我们什么。","","从容"],
		["k3","福尔摩斯","（忽然停下）等等——在去找兰斯之前，我先让维金斯去打听点事。","","狡黠"],
		["k4","系统","（演出）屋外围了不少看热闹的人。福尔摩斯走到门口扫了一眼，在人堆里认出一个熟悉的身影，朝他招了招手。一个衣衫褴褛的机灵小子挤出人群跑了过来。","","guide"],
		["k5","维金斯","（嬉皮笑脸地敬礼）福尔摩斯先生！我就知道这案子您准得来，一早就在这儿候着了。您找我？"],
		["k6","福尔摩斯","（掏出一先令递过去）维金斯，去查两件事。第一，德雷伯和斯特兰森在伦敦住过哪些旅馆、常去哪些地方。第二——打听一下最近有没有一个红脸高个的美国马车夫在这一带出没。","","指导"],
		["k7","维金斯","（眼睛一亮）红脸高个美国马车夫？没问题！贝克街分队保证给您查得清清楚楚！"],
		["k8","华生","（好奇）这孩子是……？","","疑惑"],
		["k9","福尔摩斯","贝克街小分队——我的私人情报网。这些小家伙，一个人的工作成绩比一打官方侦探还显著。官方人士一露面，人家就闭口不言了；可是他们什么地方都能去，什么事都能打听到。","","从容"],
		["k10","福尔摩斯","（望着墙上的血字方向，低声）RACHE——德语里的'复仇'。但真是这样吗？戒指——又是谁的？","","思考"],
		["k11","华生","你怀疑不是复仇？","","疑惑"],
		["k12","福尔摩斯","（收回目光）我什么都不怀疑——我只看证据。走，去找发现尸体的警察，看看他还能告诉我们什么。","","从容"],
		["k13","system","（谜题钩子）死者死于服毒，但现场没有药瓶——药去哪了？凶手为什么带走药瓶？此问题已记入推理战场待验证。","guide"]]), "k0", _go_to_next_scene)

func _go_to_next_scene() -> void:
	# 过渡对话结束后弹出「侦破过程」评价面板（风格对齐场景一），点继续再存档进入下一场景
	_show_scene_rating("场景三 完成 · 侦破过程", "res://scenes/scene4.tscn", Callable(self, "_save_and_transition").bind("scene3", "res://scenes/scene4.tscn"))

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
