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
	{"id":"c301","attribute_tags":["直接物证"],"relation_tags":["H3-A1","H3-A2","H3-A5","H3-A6","H3-C4","C-06"],"label":"尸体·面部与姿态","x":840,"y":410,"w":220,"h":46,
	 "desc":"死者约四十三四岁，中等身材，宽宽的肩膀，黑色鬈发，短硬的胡子。僵硬的脸上露出恐怖、忿恨的表情；紧握双拳、两臂伸开、双腿交叠——临死前有过痛苦的挣扎。放大镜下：面部肌肉扭曲，瞳孔收缩。那种表情，不是一般的死亡。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c302","attribute_tags":["直接物证"],"relation_tags":["H3-A1","H3-A2","C3-02","C3-04"],"label":"尸体·无外伤+嘴唇暗紫","x":880,"y":460,"w":240,"h":46,
	 "desc":"放大镜检查全身：无明显外伤，衣物完整无破损，指甲缝干净无搏斗痕迹；嘴唇黏膜呈暗紫色，微微张开，有少量泡沫状分泌物和极细的水疱。查知识库·生物碱中毒：可致面部痉挛、嘴唇发绀、瞳孔异常——无外伤+痛苦死亡+嘴唇暗紫，毒杀可能性很大。","tool":"化学试剂盒","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c303","attribute_tags":["直接物证"],"relation_tags":["H3-A7"],"label":"尸体·衣着整洁","x":1000,"y":520,"w":240,"h":46,
	 "desc":"身上穿着背心和厚厚的黑呢礼服上衣，浅色裤子，洁白的硬领和袖口整洁——死者衣着体面，身份不低。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ══ B 随身物品（08稿 六步闭环 B-Step1~6：九件物品）══
	{"id":"c304","attribute_tags":["直接物证"],"relation_tags":["H3-B1","H3-B2","H3-B5","H3-B6","H3-B9"],"label":"名片夹与两封信","x":1220,"y":480,"w":220,"h":46,
	 "desc":"俄国制皮名片夹，内有名片：伊诺克·J·德雷伯，克利夫兰——与金表背面「E.J.D.」刻字、衬衣缩写三重印证。两封信：一封寄给德雷伯，一封寄给斯特兰森，均来自盖恩轮船公司，通知轮船从利物浦启程的日期——他们正准备乘船回纽约。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c305","attribute_tags":["直接物证"],"relation_tags":["H3-B4","C3-05"],"label":"金表金链与财物","x":620,"y":500,"w":220,"h":46,
	 "desc":"伦敦巴罗德公司金表、又重又结实的阿尔伯特金链、虎头狗造型红宝石金别针、零钱七英镑十三先令——全部原封未动。死者经济状况良好，且并未遭抢劫，作案动机不在钱财。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c306","attribute_tags":["直接物证"],"relation_tags":["H3-B3","H3-B8"],"label":"共济会金戒指","x":1260,"y":570,"w":200,"h":46,
	 "desc":"死者手上戴着一枚金戒指，刻着共济会图案，内侧有磨损痕迹——佩戴者通常是共济会成员。查知识库：共济会成员多为中产及以上阶层。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c307","attribute_tags":["直接物证"],"relation_tags":["H3-B6","H3-B7"],"label":"袖珍小说《十日谈》","x":460,"y":550,"w":220,"h":46,
	 "desc":"袖珍版薄伽丘《十日谈》，扉页手写着「约瑟夫·斯特兰森」——与信件收件人对上了。斯特兰森是死者的秘书或同伴，两人关系密切。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c308","attribute_tags":["直接物证"],"label":"礼帽","x":340,"y":640,"w":200,"h":46,
	 "desc":"一顶整洁的礼帽，内衬标着帽商标记——指向物品购买地点，可循此溯源死者在伦敦的落脚处。","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ══ C 现场痕迹（08稿 六步闭环 C-Step1~6）══
	{"id":"c309","attribute_tags":["直接物证"],"relation_tags":["H2-05","H3-C1","H3-C2","H3-C3","H3-C4","H3-C7","H3-C9","H3-C10","C-06","C3-03"],"label":"\"RACHE\"血字","x":1450,"y":240,"w":220,"h":46,
	 "desc":"墙角花纸剥落处，黄色粉墙上用鲜血潦草地写着「RACHE」。卷尺测量：离地约6英尺（视线平行高度→书写者身高约6英尺）。放大镜下：笔画边缘有细微墙粉刮痕——写字的人指甲未修剪。查知识库：德语中 RACHE 意为「复仇」。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c310","attribute_tags":["直接物证"],"relation_tags":["H3-C8"],"label":"壁炉旁烟灰","x":1580,"y":640,"w":200,"h":46,
	 "desc":"壁炉旁有一小撮烟灰，颜色深黑、呈薄片状，灰烬结构疏松——与普通纸烟的灰白色粉末状烟灰明显不同。查知识库：这是印度雪茄的烟灰特征。但谁抽的，还不能定论。","tool":"放大镜","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c311","attribute_tags":["直接物证"],"relation_tags":["H2-05","H2-06","H3-C3","H3-C5","H3-C6","H3-C7"],"label":"尘土脚印与靴印","x":420,"y":720,"w":260,"h":46,
	 "desc":"地板尘土中有两组不同的脚印：漆皮靴+方头靴——穿漆皮靴的那位，就躺在我们面前；方头靴属于另一个人。卷尺测量步幅约4.5英尺——和花园里的发现对上了：六英尺的高个子，方头靴。","tool":"卷尺","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	{"id":"c312","attribute_tags":["直接物证"],"relation_tags":["H3-B8","H3-C10","C3-05"],"label":"女式结婚戒指","x":900,"y":660,"w":220,"h":46,
	 "desc":"搬动尸体时，一枚女式结婚戒指从尸体上滚落——尺码纤细，属于一位女性。它为什么会在死者身上？是死者带来的，还是凶手留下的？雷斯垂德认定这是情杀的铁证，但福尔摩斯不置可否。（关键线索 C_SOTCB_303，关联推理链#9复仇动机）","tool":"none","image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	# ── 沉默线索 D1（自由发现，无对话无任务指引，给洞察之星奖励；详见 02 §11）──
	{"id":"d1_top","attribute_tags":["直接物证"],"label":"墙角杂物堆（木陀螺）","x":200,"y":750,"w":220,"h":46,
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
		0,1: return "福尔摩斯（看向华生）：\"华生，你是医生。你告诉我——一个看上去像是被吓死的人，真正的死因，最可能是哪一种？\"（华生：\"中毒——或者心力衰竭。但脸上的表情……\"）"
		2,3: return "福尔摩斯：\"没有外伤——注意，我说的是'没有外伤'。这种'死得干净'，往往比'死得乱'更可怕。\""
		4,5: return "福尔摩斯：\"九件物品，每一件都在说话——你先听哪一件？表壳背面好像有字，戒指上注意图案。\""
		6,7: return "雷斯垂德得意地指着墙角：\"瞧瞧这个！RACHE——写字的人本来要写 RACHEL，一个女人的名字！\"福尔摩斯（摇头）：\"先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。\""
		_: return "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙——谁死了、怎么死的、屋里来过几个人、那行血字到底想说什么。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查室内。"
func _journal_empty_hint() -> String: return "去室内勘查尸体与血字"

# ===== 全部线索收集完成 =====
func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，屋里能记的都记下了——无外伤的尸体、暗紫的嘴唇、墙上的血字、印度雪茄的烟灰、还有那枚女式结婚戒指……下一步，该把它们摆上推理墙了。", "思考")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

# ===== 推理假设 =====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "死者身份、死因与现场痕迹（推理战场 M1）",
		"description": "室内勘查三条线：A 尸体检验（无外伤 + 恐怖表情 + 暗紫泡沫 + 剧烈挣扎 → 毒杀）、B 随身物品（九件物品 → 德雷伯 / 克利夫兰 / 斯特兰森）、C 现场痕迹（血字 RACHE / 两组靴印 / 印度雪茄烟灰）。\n\n推理层级（台词库 §18 场景三）：本场景只作观察事实与浅层推论，不作定论。\n· VERIFIED 已证实：无外伤 / 死前挣扎 / 血字是 RACHE / 现场两人 / 靴子种类 / 死者姓名 / 来自克利夫兰\n· SUPPORTED 有支持待证：毒杀 / 血字为德语复仇 / 书写者身高约六英尺 / 指甲未修剪 / 共济会成员 / 经济宽裕 / 准备乘船回纽约 / 斯特兰森是同伴\n· INSUFFICIENT 证据不足：死于心脏病 / 被吓死 / 斯特兰森涉案 / 与女人有关 / 死于仇杀 / 凶手抽印度雪茄 / 案件是复仇性质\n· CONTRADICTORY 与证据矛盾：与一个叫 RACHEL 的女人有关（雷斯垂德观点）\n\n矛盾标记：\n· C3-01 恐怖忿恨的表情 vs 心脏病/自然死亡的面容\n· C3-02 暗紫+泡沫（生物碱）vs 窒息的青紫\n· C3-03 德语复仇 vs 雷斯垂德的「女人 RACHEL」\n· C3-04 死于服毒 vs 现场没有药瓶\n· C3-05 情杀论（女式戒指）vs 服毒预谋\n· C-06 死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉",
		"battlefield": {
			"hypotheses": [
				# ══ A 尸体检验（台词库 A-Step5 假设清单 A1~A7）══
				{"id":"H3-A1","text":"死者身上没有外伤","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["无外伤"],
				 "gate_clue_ids":["c302","c301"],
				 "adopt_desc":"VERIFIED：放大镜检查全身无伤口，衣物完整无破损，指甲缝干净无搏斗痕迹——没有外伤。这本身就是一条线索。",
				 "new_clue_hint":"知识库·法医学·窒息死亡：窒息死亡常见面部青紫、舌骨骨折，但体表可能无明显外伤。"},
				{"id":"H3-A2","text":"死者是被毒杀的","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["毒杀","生物碱"],
				 "gate_clue_ids":["c302","c301"],
				 "adopt_desc":"SUPPORTED：嘴唇暗紫带泡沫 + 面部恐怖忿恨 + 全身无外伤——生物碱中毒的可能性很大，但还需毒物分析确认。有道理，但还不够。",
				 "new_clue_hint":"知识库·毒物学·生物碱中毒：可导致面部肌肉痉挛、嘴唇发绀、瞳孔异常，死者常露出恐怖表情。"},
				{"id":"H3-A3","text":"死者死于心脏病或自然疾病","kind":"true","correct":false,"dir":"affirm","subject":["死者"],"object":["心脏病","自然死亡"],
				 "gate_clue_ids":["c301"],
				 "adopt_desc":"INSUFFICIENT：无证据支持，也无证据完全排除——但那张脸不像常见的自然死亡。证据太少，别急着下结论。",
				 "reject_desc":"心脏病发作的人，嘴唇是青紫且通常没有泡沫，面容是痛苦扭曲；这张脸是恐怖 + 忿恨，对不上。"},
				{"id":"H3-A4","text":"死者是被吓死的","kind":"true","correct":false,"dir":"affirm","subject":["死者"],"object":["吓死","恐惧"],
				 "gate_clue_ids":["c301"],
				 "adopt_desc":"INSUFFICIENT：恐怖的表情可能由多种原因造成，恐惧只是其中之一。",
				 "reject_desc":"恐怖 + 忿恨，是临死前已经知道会发生什么的人的脸——被迫服毒，而不是单纯受惊。"},
				{"id":"H3-A5","text":"死者死前有过痛苦的挣扎","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["挣扎","双拳"],
				 "gate_clue_ids":["c301"],
				 "adopt_desc":"VERIFIED：双拳紧握、双臂伸开、双腿交叠——死前剧烈挣扎的姿势。不是被一刀毙命的人，是一点点感受着死亡逼近的人。",
				 "new_clue_hint":""},
				{"id":"H3-A6","text":"死者约四十多岁","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["年龄","四十多岁"],
				 "gate_clue_ids":["c301"],
				 "adopt_desc":"SUPPORTED：从外貌判断约四十三四岁，大致准确；精确年龄还需要身份证明。",
				 "new_clue_hint":""},
				{"id":"H3-A7","text":"死者身份不低（从衣着判断）","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["衣着","身份"],
				 "gate_clue_ids":["c303"],
				 "adopt_desc":"SUPPORTED：黑呢礼服上衣、浅色裤子、洁白的硬领和袖口——衣着整洁体面，身份不低。金表金链等财物可进一步印证。",
				 "new_clue_hint":""},
				# ══ B 随身物品（台词库 B-Step5 假设清单 B1~B9）══
				{"id":"H3-B1","text":"死者名叫伊诺克·J·德雷伯","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["德雷伯"],
				 "gate_clue_ids":["c304"],
				 "adopt_desc":"VERIFIED：名片「伊诺克·J·德雷伯」+ 金表背面「E.J.D.」刻字 + 衬衣缩写——三重印证。",
				 "new_clue_hint":""},
				{"id":"H3-B2","text":"死者来自美国克利夫兰","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["克利夫兰","美国"],
				 "gate_clue_ids":["c304"],
				 "adopt_desc":"VERIFIED：名片上明确标注「克利夫兰」。",
				 "new_clue_hint":"知识库·克利夫兰：美国俄亥俄州城市，19世纪后期重要工业城市。"},
				{"id":"H3-B3","text":"死者是共济会成员","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["共济会","戒指"],
				 "gate_clue_ids":["c306"],
				 "adopt_desc":"SUPPORTED：金戒指上刻着共济会图案，内侧有磨损痕迹——佩戴者通常是成员，但不绝对。",
				 "new_clue_hint":"知识库·共济会：近代互助组织，成员多为中产及以上阶层。"},
				{"id":"H3-B4","text":"死者经济状况良好，且并未遭抢劫","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["金表","财物"],
				 "gate_clue_ids":["c305"],
				 "adopt_desc":"SUPPORTED：金表、阿尔伯特金链、红宝石金别针、七英镑十三先令零钱全部原封未动——经济宽裕，作案动机不在钱财。",
				 "new_clue_hint":""},
				{"id":"H3-B5","text":"死者正准备乘船回纽约","kind":"true","correct":true,"dir":"affirm","subject":["死者"],"object":["盖恩轮船公司","回纽约"],
				 "gate_clue_ids":["c304"],
				 "adopt_desc":"SUPPORTED：盖恩轮船公司的信件通知了轮船从利物浦启程的日期——但不排除那其实是斯特兰森的计划。",
				 "new_clue_hint":"知识库·盖恩轮船公司：19世纪从事跨大西洋航运的美国公司。"},
				{"id":"H3-B6","text":"斯特兰森是死者的秘书或同伴","kind":"true","correct":true,"dir":"affirm","subject":["斯特兰森"],"object":["秘书","同伴"],
				 "gate_clue_ids":["c307","c304"],
				 "adopt_desc":"SUPPORTED：两封信分别寄给德雷伯与斯特兰森，小说扉页写着「约瑟夫·斯特兰森」——两人关系密切，具体身份还有待确认。",
				 "new_clue_hint":""},
				{"id":"H3-B7","text":"斯特兰森可能涉案","kind":"true","correct":false,"dir":"affirm","subject":["斯特兰森"],"object":["涉案"],
				 "gate_clue_ids":["c307"],
				 "adopt_desc":"INSUFFICIENT：没有直接证据，只是基于「在场相关人」的常规怀疑。",
				 "reject_desc":"猜得挺快，但证据呢？先把能确定的确定下来。"},
				{"id":"H3-B8","text":"案件与女人有关（从戒指 / 手帕推断）","kind":"true","correct":false,"dir":"affirm","subject":["案件"],"object":["女人","戒指"],
				 "gate_clue_ids":["c306","c312"],
				 "adopt_desc":"INSUFFICIENT：戒指可能是死者本人的，也可能是凶手留下的；女式戒指与手帕都可能是误放置。",
				 "reject_desc":"现场两组脚印都是男式靴子——「与女人有关」的说法和证据对不上。"},
				{"id":"H3-B9","text":"死者死于仇杀（从身份背景推断）","kind":"true","correct":false,"dir":"affirm","subject":["死者"],"object":["仇杀","动机"],
				 "gate_clue_ids":["c304"],
				 "adopt_desc":"INSUFFICIENT：身份信息不能直接推出作案动机。",
				 "reject_desc":"身份背景只说明他是谁，不说明谁杀了他、为什么杀他。"},
				# ══ C 现场痕迹（台词库 C-Step5 假设清单 C1~C10）══
				{"id":"H3-C1","text":"墙上的血字是「RACHE」","kind":"true","correct":true,"dir":"affirm","subject":["血字"],"object":["RACHE"],
				 "gate_clue_ids":["c309"],
				 "adopt_desc":"VERIFIED：亲眼所见——墙角花纸剥落处，黄色粉墙上用鲜血潦草地写着 RACHE。",
				 "new_clue_hint":""},
				{"id":"H3-C2","text":"血字是德语「复仇」的意思","kind":"true","correct":true,"dir":"affirm","subject":["血字"],"object":["德语","复仇"],
				 "gate_clue_ids":["c309"],
				 "adopt_desc":"SUPPORTED：德语中 RACHE 意为复仇——词典确有此词，但写字者的本意是否如此还不确定。有意思的方向，但一个词不等于真相。",
				 "new_clue_hint":"知识库·「RACHE」德语词义：德语中 RACHE 意为「复仇」。"},
				{"id":"H3-C3","text":"写字的人身高约六英尺","kind":"true","correct":true,"dir":"affirm","subject":["书写者"],"object":["身高","六英尺"],
				 "gate_clue_ids":["c309","c311"],
				 "adopt_desc":"SUPPORTED：血字离地约6英尺（人自然写在与视线平行的高度）+ 步幅4.5英尺推算——双重印证，但不是精确测量。六英尺的人，方头靴——和花园里的发现对上了。",
				 "new_clue_hint":"知识库·墙面写字高度心理学：人会写在与视线大致平行的高度，可据此推断书写者身高。"},
				{"id":"H3-C4","text":"写字的人右手指甲未修剪","kind":"true","correct":true,"dir":"affirm","subject":["书写者"],"object":["指甲","未修剪"],
				 "gate_clue_ids":["c309","c301"],
				 "adopt_desc":"SUPPORTED：血字笔画边缘有墙粉刮痕，暗示指甲较长（也可能是写字时用力所致）；而死者指甲缝干净——血字不是死者写的。",
				 "new_clue_hint":""},
				{"id":"H3-C5","text":"现场有两个人来过","kind":"true","correct":true,"dir":"affirm","subject":["现场"],"object":["两个人"],
				 "gate_clue_ids":["c311"],
				 "adopt_desc":"VERIFIED：地板尘土中有两组明显不同的脚印，部分叠压、且都在警察的脚印之下——现场来过两个人。",
				 "new_clue_hint":""},
				{"id":"H3-C6","text":"一人穿方头靴，另一人穿漆皮靴","kind":"true","correct":true,"dir":"affirm","subject":["来人"],"object":["方头靴","漆皮靴"],
				 "gate_clue_ids":["c311"],
				 "adopt_desc":"VERIFIED：靴印清晰可辨——穿漆皮靴的那位，就躺在我们面前；方头靴属于另一个人。",
				 "new_clue_hint":"知识库·19世纪伦敦常见靴子类型：漆皮靴（正装）、方头靴（日常）、高筒靴（户外）。"},
				{"id":"H3-C7","text":"穿方头靴的那个人个子较高","kind":"true","correct":true,"dir":"affirm","subject":["方头靴者"],"object":["高个","步幅"],
				 "gate_clue_ids":["c311","c309"],
				 "adopt_desc":"SUPPORTED：约4.5英尺的大步幅属于方头靴那一组，且血字高度由方头靴者书写的可能性大——两者互相印证。",
				 "new_clue_hint":"知识库·步伐距离与身高关系：一般成年人步幅约等于身高的 0.45 倍。"},
				{"id":"H3-C8","text":"凶手抽印度雪茄","kind":"true","correct":false,"dir":"affirm","subject":["凶手"],"object":["印度雪茄","烟灰"],
				 "gate_clue_ids":["c310"],
				 "adopt_desc":"INSUFFICIENT：烟灰确实是印度雪茄的，但无法确定是谁抽的，也不能确定抽烟的人就是凶手。",
				 "reject_desc":"印度雪茄的判断不错（颜色深黑、呈薄片状）——但谁抽的，还不能定论。",
				 "new_clue_hint":"知识库·印度雪茄烟灰特征：颜色深黑，呈薄片状，灰烬结构疏松。"},
				{"id":"H3-C9","text":"案件是复仇性质","kind":"true","correct":false,"dir":"affirm","subject":["案件"],"object":["复仇","动机"],
				 "gate_clue_ids":["c309"],
				 "adopt_desc":"INSUFFICIENT：这只是基于血字词义的推测，动机需要更多证据。一个词不等于真相。",
				 "reject_desc":"复仇这种事，写在脸上都来不及——凶手为什么要写在墙上？先别把词义当动机。"},
				{"id":"H3-C10","text":"案件与一个叫 RACHEL 的女人有关（雷斯垂德观点）","kind":"mislead","correct":false,"dir":"affirm","subject":["案件"],"object":["RACHEL","女人"],
				 "gate_clue_ids":["c309","c312"],
				 "adopt_desc":"CONTRADICTORY：现场两组脚印都是男式靴子，与「一个女人」的说法矛盾；而那个德语词更可能是复仇，并不是没写完的名字。",
				 "reject_desc":"雷斯垂德的理论？先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。这两个结论，总有一个有问题。"}
			],
		"conclusions": [
			{"id":"CL3-1","text":"死者是美国克利夫兰人伊诺克·J·德雷伯","kind":"true","dir":"affirm","subject":["死者"],"object":["德雷伯","克利夫兰"],"gate_hypo_ids":["H3-B1","H3-B2"],
			 "adopt_desc":"基本盘清楚了：德雷伯，美国人，克利夫兰来的，有钱——但这还不够解释他为什么会死在这里。"},
			{"id":"CL3-2","text":"死者死于毒杀（无外伤+恐怖表情+暗紫泡沫+剧烈挣扎，四线合一）","kind":"true","dir":"affirm","subject":["死者"],"object":["毒杀"],"gate_hypo_ids":["H3-A1","H3-A2","H3-A5"],
			 "adopt_desc":"没有外伤（排除刺杀 / 枪击）+ 死相恐怖（他临死前知道会发生什么）+ 嘴唇暗紫带泡沫（生物碱特征）+ 剧烈挣扎（死亡来得不快）→ 毒杀。每一个看起来'不可能'的特征背后，都藏着一个'唯一可能'的解释。"},
			{"id":"CL3-3","text":"血字 RACHE 是德语「复仇」，书写者身高约六英尺、指甲未修剪","kind":"true","dir":"affirm","subject":["血字"],"object":["复仇","六英尺"],"gate_hypo_ids":["H3-C1","H3-C2","H3-C3","H3-C4"],
			 "adopt_desc":"一行血字读出三件事：写的是 RACHE（德语复仇），写它的人身高约六英尺，而且右手指甲没有修剪——后两条，日后都是认人的凭据。"},
			{"id":"CL3-4","text":"现场两个人：死者穿漆皮靴，另一个穿方头靴、身高约六英尺","kind":"true","dir":"affirm","subject":["现场"],"object":["两个人","方头靴"],"gate_hypo_ids":["H3-C5","H3-C6","H3-C7"],
			 "adopt_desc":"现场有两个人：一个穿漆皮靴，就是死者；一个穿方头靴，高个子——和花园里的马车、脚印连成了一条线。"},
			{"id":"CL3-5","text":"斯特兰森是死者的同伴，两人原定乘船回纽约","kind":"true","dir":"affirm","subject":["斯特兰森"],"object":["同伴","回纽约"],"gate_hypo_ids":["H3-B5","H3-B6"],
			 "adopt_desc":"从克利夫兰到利物浦，再到伦敦……他有个同伴叫斯特兰森，两人正准备乘船回纽约。他在躲什么？还是在追什么？"},
			{"id":"CL3-M1","text":"案件与一个叫 RACHEL 的女人有关","kind":"mislead","dir":"affirm","subject":["案件"],"object":["RACHEL","女人"],"gate_hypo_ids":["H3-C10"],
			 "reject_desc":"雷斯垂德的理论？先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。这两个结论，总有一个有问题。"}
		],
		"contradictions": [
			{"id":"C3-01","text":"恐怖忿恨的表情 vs 心脏病 / 自然死亡的面容","correct":true},
			{"id":"C3-02","text":"嘴唇暗紫+泡沫（生物碱）vs 窒息的青紫+挣扎痕","correct":true},
			{"id":"C3-03","text":"血字是德语「复仇」 vs 雷斯垂德的「女人 RACHEL」","correct":true},
			{"id":"C3-04","text":"死于服毒 vs 现场没有药瓶（凶手把它带走了）","correct":true},
			{"id":"C3-05","text":"情杀论（女式戒指）vs 服毒预谋杀人","correct":true},
			{"id":"C-06","text":"死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉","correct":true}
		],
		"milestones": [
			{"id":"S3-1","text":"死者身份：美国克利夫兰人伊诺克·J·德雷伯"},
			{"id":"S3-2","text":"全身无外伤、嘴唇暗紫带泡沫"},
			{"id":"S3-3","text":"四线合一：无外伤+恐怖表情+暗紫泡沫+剧烈挣扎 → 被迫服毒"},
			{"id":"S3-4","text":"血字 RACHE = 德语「复仇」"},
			{"id":"S3-5","text":"现场两人：漆皮靴（死者）+ 方头靴（高个约六英尺）"},
			{"id":"S3-6","text":"写字的人指甲未修剪——血字不是死者写的"},
			{"id":"S3-7","text":"同伴斯特兰森，两人原定乘船回纽约"},
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
	return ["进入尸体现场", "听取警长说明", "选勘查顺序：尸体/物品/痕迹", "六步闭环勘查", "推理墙验证"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() > 0,
		_clues.size() >= HOTSPOTS.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单", "普通", "困难"][_difficulty] + " — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"🔍 放大镜：查看血字笔顺、面部痉挛等细节",
		"🧪 化学试剂盒：场景三起可用，检验尸体中毒痕迹",
		"💡 核心：无外伤 + 恐怖表情 + 暗紫带泡沫 + 剧烈挣扎 → 毒杀；血字 RACHE 是复仇，还是别的？",
		"音效：MVP 阶段暂无（M3 补全）",
	]

# ===== 对话阶段 =====
func _enter_arrival() -> void:
	acquire_prop("ring", "结婚金戒指", "案发现场拾得的女式结婚戒指，尺码纤细，内侧刻字模糊——关键物证", "res://assets/props/ring.png")
	# 对齐 08 稿 §18 场景三·入场（L1289-1317）：推门→霉味与血味→华生是医生→三条线你说了算
	_start_dialogue(_make_nodes([
		["i0","系统","（演出）福尔摩斯推门——门轴吱呀作响，一股陈腐的霉味混着别的什么味道涌出来。（特写：红蜡烛的火焰被穿堂风压低了一下，又直起来）","","guide"],
		["i1","福尔摩斯","（站在门槛，没急着进，先扫了一眼）……嗯。","","从容"],
		["i2","华生","（在他身后，下意识捂住鼻子）福尔摩斯，这味道……","","疑惑"],
		["i3","福尔摩斯","（没回头）是血。已经开始凝固了。死了至少几个小时。","","从容"],
		["i4","福尔摩斯","（停顿）华生，你是个医生。你比我更熟悉这种味道。","","从容"],
		["i5","华生","（慢慢走进来，目光落在地板上的尸体）……我见过这种味道。在阿富汗。","","思考"],
		["i6","系统","（两人沉默了两秒。福尔摩斯这才迈步进屋，蹲在尸体旁，没看脸，先看手）","","guide"],
		["i7","福尔摩斯","尸体、随身物品、现场痕迹——三条线，从哪里开始，你说了算。（回头看玩家）你在这里是主导。我只在你需要的时候开口。","","从容"]]), "i0", _on_arrival_ended)

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
	# 台词库·入场（L1314-1317）：三个勘查对象由玩家决定从哪一条线开始
	_show_choice_panel("先从哪一条线开始？", [
		{"text": "A. 先检查尸体（面部 / 双拳 / 嘴唇 / 衣着）", "cb": Callable(self, "_start_with").bind("A")},
		{"text": "B. 先检查随身物品（散落在旁的九件物品）", "cb": Callable(self, "_start_with").bind("B")},
		{"text": "C. 先勘查现场痕迹（血字 / 脚印 / 烟灰）", "cb": Callable(self, "_start_with").bind("C")},
		{"text": "我自己安排顺序", "cb": Callable(self, "_start_with").bind("")},
	])

## 选定勘查对象后给一句 Step1 引导（台词库：简单明说 / 普通模糊 / 困难不给），随后进入观察。
func _start_with(group: String) -> void:
	var line: String = _group_hint(group)
	if line == "":
		_begin_observe_indoor(); return
	_start_dialogue(_make_nodes([["g0", "福尔摩斯", line, "", "从容"]]), "g0", _begin_observe_indoor)

func _group_hint(group: String) -> String:
	if group == "": return ""
	var easy: bool = DifficultyManager != null and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY
	var hard: bool = DifficultyManager != null and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD
	if group == "A":
		if easy: return "（低声）先从尸体看起：有没有外伤、嘴唇是什么颜色——每一处都别漏。"
		if hard: return "（蹲在尸体旁，看了你一眼）……自己看。"
		return "让证据自己说话：先看尸体，哪条不对劲就先记哪条。"
	if group == "B":
		if easy: return "九件物品，每一件都在说话——表壳背面好像有字，戒指上注意图案。"
		if hard: return "（看了眼散落在旁的物品）……"
		return "物品都堆在那儿，哪些重要，你自己判断。"
	if group == "C":
		if easy: return "再看血字和脚印：墙上写了什么、离地多高；地板上的靴印有几组。"
		if hard: return "（目光扫过墙角）……"
		return "血字、脚印、烟灰——痕迹不会说谎，但得先找到它们。"
	return ""

func _begin_observe_indoor() -> void:
	_begin_observe("屋内")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_prompt_think("福尔摩斯", "华生，证据齐了。把线索摆上推理墙——谁死了、怎么死的、屋里来过几个人、那行血字到底想说什么。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	# 对齐 08 稿 §18 场景三·阶段末小结（L1846-1977）：
	# ① 教学「读尸体」：恐怖忿恨的表情→被迫服毒 / 暗紫+泡沫→生物碱 / 双拳→剧烈挣扎 → 四线合一 → 毒杀
	# ② 动态总结：只念玩家实际发现并验证过的条目（未发现的不出现）
	# ③ 维金斯登场（吹口哨叫来 + 贝克街小分队）+ 双钩子（RACHE 存疑 / 被带走的药瓶）→ 场景四
	_start_dialogue(_make_nodes([
		["t0","福尔摩斯","（站在尸体旁，没有急着动）等一下。在我们继续之前——（他看了玩家一眼）我希望你自己，把这具尸体「读」出来。","","从容"],
		["t1","福尔摩斯","（蹲下，指着尸体的脸）看他的脸——僵硬的脸上露出恐怖、忿恨的表情。如果他看到了凶手，那种表情该是惊讶；如果他是被刺死的，表情该是痛苦。但他脸上是恐怖 + 忿恨——","","从容"],
		["t2","福尔摩斯","这是临死前已经知道会发生什么的人的脸。这种表情，意味着他是被迫服毒。","","思考"],
		["t3","福尔摩斯","（指着嘴唇）再看嘴唇——暗紫色，微微张开，有泡沫状分泌物。心脏病发作的人，嘴唇是青紫，但通常没有泡沫；窒息的人，嘴唇是青紫加上挣扎痕迹。但这种「暗紫 + 泡沫」——","","从容"],
		["t4","华生","（接话）是生物碱类中毒的典型表现。","","自信"],
		["t5","福尔摩斯","（点头）华生说得对。","","从容"],
		["t6","福尔摩斯","（指着双拳）双拳紧握、双臂伸开、双腿交叠——这是死前剧烈挣扎的姿势。不是被一刀毙命的人，是一点点感受着死亡逼近的人。","","从容"],
		["t7","福尔摩斯","（站起身，平静但有分量）归纳一下——没有外伤（排除了刺杀 / 枪击）+ 死相恐怖（他在临死前知道会发生什么）+ 嘴唇暗紫带泡沫（生物碱特征）+ 剧烈挣扎（死亡来得不快）→ 毒杀。","","自信"],
		["t8","华生","（在小本子上记）四线合一：外伤排除 + 表情分析 + 嘴唇证据 + 挣扎姿态 → 毒杀。","","思考"],
		["t9","福尔摩斯","对了。每一个看起来「不可能」的特征，背后都藏着一个「唯一可能」的解释。找那个唯一——就是推理。","","从容"],
		["t10","系统","——","","guide"],
		["t11","福尔摩斯","好，我们来理一理目前确定的——" + _summary_lines(),"","从容"],
		["t12","福尔摩斯","这些是我们手里的牌——不多，但每一张都是实的。下一步，去找发现尸体的警察，看看他还能告诉我们什么。","","从容"],
		["t13","福尔摩斯","（忽然停下，对玩家）等等——在去找兰斯之前，我先让维金斯去打听点事。","","狡黠"],
		["t14","系统","（演出）福尔摩斯走到门口，吹了一声口哨。一个衣衫褴褛的机灵小子从街角跑了过来。","","guide"],
		["t15","维金斯","（嬉皮笑脸地敬礼）福尔摩斯先生！您找我？","","从容"],
		["t16","福尔摩斯","（掏出一先令递过去）维金斯，去查两件事。第一，德雷伯和斯特兰森在伦敦住过哪些旅馆、常去哪些地方。第二——打听一下最近有没有一个红脸高个的美国马车夫在这一带出没。","","指导"],
		["t17","维金斯","（眼睛一亮）红脸高个美国马车夫？没问题！贝克街分队保证给您查得清清楚楚！","","自信"],
		["t18","福尔摩斯","去吧。有消息直接去贝克街找我。","","从容"],
		["t19","系统","（维金斯一溜烟跑了。福尔摩斯望着他的背影，烟斗叼在嘴里）","","guide"],
		["t20","华生","（好奇）这孩子是……？","","疑惑"],
		["t21","福尔摩斯","（转过身，往外走）维金斯。贝克街小分队的队长——如果你能管这帮小鬼叫「队长」的话。","","从容"],
		["t22","华生","（跟上）他们……是你的帮手？","","疑惑"],
		["t23","福尔摩斯","（停下脚步，看了华生一眼）华生，苏格兰场有几百个侦探，配着全套装备，每年花掉纳税人几十万英镑。这帮孩子一个人一先令，给我跑出来的情报，比他们所有人都多。","","从容"],
		["t24","福尔摩斯","（停顿）不是侦探不行。是大人太显眼——孩子能钻进大人进不去的地方。","","思考"],
		["t25","华生","（点头）原来如此……我之前还以为他们只是街上的小捣蛋。","","思考"],
		["t26","福尔摩斯","（继续走）那是因为你还不够仔细地看他们，华生。——看人，永远比看证据难。","","从容"],
		["t27","系统","（福尔摩斯忽然停下，望着屋内墙上的血字方向）","","guide"],
		["t28","华生","（顺着他的目光看过去）你在看什么？","","疑惑"],
		["t29","福尔摩斯","（低声）RACHE——德语里的「复仇」。写得很大。但复仇这种事，写在脸上都来不及——凶手为什么要写在墙上？","","思考"],
		["t30","华生","（皱眉）你怀疑不是复仇？","","疑惑"],
		["t31","福尔摩斯","（收回目光，继续往外走）我不怀疑。我只是……有疑问。——走，去找发现尸体的警察。看他还能告诉我们什么。","","从容"],
		["t32","system","（谜题钩子）死者死于服毒，但现场没有药瓶——药去哪了？凶手为什么带走药瓶？此问题已记入推理战场待验证。（雷斯垂德告知了兰斯警士的地址 → 前往场景四）","","guide"]]), "t0", _go_to_next_scene)

## 阶段末动态总结（台词库 L1912-1921）：只念玩家实际发现并验证过的条目，未发现的不出现。
func _summary_lines() -> String:
	var parts: Array = []
	if _has_clue("c304"):
		parts.append("死者德雷伯，美国人，克利夫兰来的。")
	if _has_clue("c301") and _has_clue("c302"):
		parts.append("没有外伤，但死相恐怖——毒杀的可能性很大。")
	if _has_clue("c311"):
		parts.append("现场有两个人：一个穿漆皮靴，就是死者；一个穿方头靴，高个子。")
	if _has_clue("c309"):
		parts.append("墙上的血字——「RACHE」，德语里是复仇的意思。")
	if _has_clue("c310"):
		parts.append("烟灰是印度雪茄。")
	if _has_clue("c304") and _has_clue("c307"):
		parts.append("他有个同伴叫斯特兰森，两人正准备乘船回纽约。")
	if parts.is_empty():
		return "……（眼下记下的东西太少，还理不出什么。）"
	var s := ""
	for p in parts:
		s += str(p)
	return s

func _has_clue(cid: String) -> bool:
	for c in _clues:
		if str(c.get("id", "")) == cid: return true
	return false

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
