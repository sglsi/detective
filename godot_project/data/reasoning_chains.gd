extends RefCounted
class_name ReasoningChains
## 统一推理链描述库（单一事实源，2026-09-07 模块化重构）。
## 每条推理链一个条目：wall 为 reasoning_wall 需要的完整运行数据（与各场景
## reasoning_hypothesis() 钩子同构），misleads 为干扰项期望表。
## 真相表（case_branch_truth.gd）不再手工维护——由 derive_truth() 从 wall 数据
## 机械派生，"真相表与 gate 同源"由构造保证。新增链只需在此加一个条目。

const CHAINS := {
	"CH01W": {
		"name": "华生教学（练习）", "scene": "scene1", "core": false, "practice": true,
		"misleads": [],
		"wall": {
			"title": "华生刚从阿富汗回来？",
			"persons": [{"id": "NPC_WT"}],
			"description": "从华生身上的痕迹（手腕肤色分明、脸色黝黑、军人站姿、消毒液气味、左臂旧伤、面容憔悴）逐层推断：肤色→热带生活→英国殖民地为阿富汗；军人气质＋医疗行业→军医；旧伤＋久病→伤痛来自军事任务；三线闭合→在阿富汗服役过。",
			"battlefield": {
				"hypotheses": [
					{"id": "W-A1", "text": "不是原来的肤色", "correct": true, "gate_clue_ids": ["wrist", "face_dark"]},
					{"id": "W-B1", "text": "多年军事行业形成的气质", "correct": true, "gate_clue_ids": ["pose"]},
					{"id": "W-B2", "text": "从事医疗行业", "correct": true, "gate_clue_ids": ["medical"]},
					{"id": "W-C1", "text": "左臂受过伤未完全恢复", "correct": true, "gate_clue_ids": ["arm"]},
					{"id": "W-C2", "text": "久病初愈而又历尽了苦难", "correct": true, "gate_clue_ids": ["face_haggard"]},
				],
				"conclusions": [
					{"id": "C-A1", "text": "曾经在热带生活过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["热带"], "match_keys": ["在热带生活过", "热带生活", "热带待过", "在热带待过"], "gate_hypo_ids": ["W-A1"], "adopt_desc": "肤色分明与黝黑的脸——他曾在热带生活过。"},
				{"id": "C-B1", "text": "是名军医", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["军医", "医生"], "match_keys": ["军医", "是医生", "医疗兵", "医务人员"], "gate_hypo_ids": ["W-B1", "W-B2"], "adopt_desc": "军人气质与医疗行业的痕迹，合起来是一名军医。"},
				{"id": "C-A2", "text": "英国在热带的殖民地为阿富汗", "correct": true, "dir": "affirm", "subject": ["英国"], "object": ["阿富汗"], "match_keys": ["阿富汗", "英国殖民地是阿富汗", "热带殖民地是阿富汗", "去过阿富汗"], "gate_hypo_ids": ["conclusion_C-A1"], "adopt_desc": "英国在热带的殖民地——最近的那块是阿富汗。"},
				# 2026-09-10：去除过渡结论「承受了这个年龄本不该承受的伤痛」(原 C-C1)，
				# W-C1(左臂旧伤) 与 W-C2(久病初愈) 直接指向 C-C2(军事任务)，伤痛线缩短为 2 层。
				{"id": "C-C2", "text": "不该有的伤害只可能来自军事任务", "correct": true, "dir": "affirm", "subject": ["伤害"], "object": ["军事任务"], "match_keys": ["军事任务", "伤害来自军事", "战场负伤", "军旅负伤"], "gate_hypo_ids": ["W-C1", "W-C2"], "adopt_desc": "旧伤未愈、久病初愈——这样的伤痛，只可能来自军事任务。"},
					{"id": "C-MAIN", "text": "在阿富汗服役过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["阿富汗", "服役"], "match_keys": ["在阿富汗服役", "阿富汗服役过", "去过阿富汗当兵", "阿富汗当兵"], "gate_hypo_ids": ["conclusion_C-A2", "conclusion_C-B1", "conclusion_C-C2"], "target": "person:NPC_WT", "adopt_desc": "热带殖民地、军医身份、军事任务的伤痛——三线闭合，他在阿富汗服役过。"},
				],
				"contradictions": [],
			},
			"milestones": [
				{"id": "MW-1", "text": "华生曾在热带生活过（肤色推导）"},
				{"id": "MW-2", "text": "华生是名军医（军人气质＋医疗行业）"},
				{"id": "MW-3", "text": "华生的旧伤与久病指向军事任务（不该有的伤害只可能来自军事任务）"},
				{"id": "MW-4", "text": "华生曾在阿富汗服役（三线闭合）"},
			],
			# 裁定 5：练习墙不计分。scene_id 供分枝评分引擎定位到场景一的练习链。
			"scene_id": "scene1", "practice": true,
		},
	},
	"CH01M": {
		"name": "信使判定（练习）", "scene": "scene1", "core": false, "practice": true,
		"misleads": [],
		"wall": {
			"title": "信使是海军陆战队军士？",
			"persons": [
				{"id": "NPC_MSG", "name": "信使"},
				{"id": "NPC_SERGEANT", "name": "海军军士"},
			],
			"description": "从信使身上（手臂锚文身、军人式络腮胡、笔挺站姿、发号施令神态）推断其海军陆战队军士身份；注意分辨干扰项（袖口磨损、轻微跛行）。",
			"battlefield": {
				# 表格六列映射：线索→推导(MT 层)→结论1(M-01/02/04)→结论2(CL1-01)→结论3(CL1-02)→人物
				"hypotheses": [
					{"id": "MT-1", "text": "锚文身是海员中的常见标志", "correct": true, "gate_clue_ids": ["tattoo"]},
					{"id": "MT-2", "text": "军人式络腮胡，军人中常见", "correct": true, "gate_clue_ids": ["beard"]},
					{"id": "MT-3", "text": "站姿笔挺是军事训练中形成的肌肉记忆", "correct": true, "gate_clue_ids": ["posture"]},
					{"id": "MT-4", "text": "发号施令中形成的气质", "correct": true, "gate_clue_ids": ["manner"]},
					{"id": "M-05", "text": "袖口磨损说明常年奔波劳碌", "correct": false, "gate_clue_ids": ["sleeve"]},
					{"id": "M-06", "text": "走路轻微跛行受过伤", "correct": false, "gate_clue_ids": ["limp"]},
				],
				"conclusions": [
					{"id": "M-01", "text": "在海军中当兵", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["海军"], "match_keys": ["在海军中当兵", "海军"], "gate_hypo_ids": ["MT-1"]},
					{"id": "M-02", "text": "当过兵", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["兵"], "match_keys": ["当过兵", "军人"], "gate_hypo_ids": ["MT-2", "MT-3"]},
					{"id": "M-04", "text": "当过军士", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["军士"], "match_keys": ["当过军士", "军士"], "gate_hypo_ids": ["MT-4"]},
					{"id": "CL1-01", "text": "海军陆战队员", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["海军", "海军陆战队"], "match_keys": ["海军陆战队员", "是陆战队员", "海军陆战队"], "gate_hypo_ids": ["conclusion_M-01", "conclusion_M-02"], "adopt_desc": "在海军中当兵，又是正规军人出身——海军陆战队员。"},
					{"id": "CL1-02", "text": "海军军士", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["军士"], "match_keys": ["海军军士", "军士"], "gate_hypo_ids": ["conclusion_M-04", "conclusion_CL1-01"], "target": "person:NPC_MSG", "adopt_desc": "陆战队员的底子，再加发号施令的军士气度——他是海军军士。"},
				],
				"contradictions": [],
			},
			"milestones": [
				{"id": "MM-0", "text": "先从线索归纳身份特征（海员标志、军人气质）"},
				{"id": "MM-1", "text": "信使是海军陆战队员（在海军当兵＋当过兵）"},
				{"id": "MM-2", "text": "信使是海军军士（陆战队员＋当过军士）"},
				{"id": "MM-3", "text": "袖口磨损/跛行为干扰项，非身份证据"},
			],
			# 裁定 5：练习墙不计分（信使墙为教学示范，干扰项用于教「信号 vs 噪音」）
			"scene_id": "scene1", "practice": true,
		},
	},
	"CH02": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H2-M2"
}, {
"expect": "negate",
"id": "CL2-1M"
}],
"name": "马车与车夫行踪",
"practice": false,
"scene": "scene2",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "三链之一：轴距6英尺10英寸符合留存实车实测的伦敦出租四轮马车（brougham型）——私家大型马车约8英尺6英寸，不会这么短。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-01"],
"id": "CL2-1",
"kind": "true",
"object": ["轴距", "6英尺10英寸", "82英寸", "6.8英尺"],
"subject": ["出租马车"],
"text": "来的是一辆出租马车"
}, {
"adopt_desc": "三链之二：右前蹄铁是新的，其余三只磨损——这匹马最近被人特别关照过。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-02"],
"id": "CL2-2",
"kind": "true",
"object": ["右前蹄铁", "新换"],
"subject": ["马"],
"text": "这匹马最近被特别关照过（右前蹄铁新换）"
}, {
"adopt_desc": "三链之三：马蹄印零乱无章，不是直线行进——赶车的人不在车上，他下了车。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-03"],
"id": "CL2-3",
"kind": "true",
"object": ["蹄印零乱", "下车"],
"subject": ["赶车人"],
"text": "赶车的人不在车上——他下了车"
}, {
"adopt_desc": "一辆出租马车、一匹刚换过蹄铁的马、一个不在车上的车夫——他进了那栋空房子。此为假设级结论，待室内证据验证。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-01", "H2-02", "H2-03"],
"id": "CL2-4",
"kind": "true",
"object": ["空房子"],
"subject": ["马车夫"],
"text": "马车夫进了那栋空房子（三线合一·假设级）"
}, {
"dir": "affirm",
"gate_hypo_ids": ["H2-M2"],
"id": "CL2-1M",
"kind": "mislead",
"object": ["徒步", "泥地", "大步"],
"reject_desc": "并行车轮印与碾轧花草说明来客是乘马车抵达，非徒步大步进入。",
"subject": ["来客"],
"text": "来客徒步踏泥大步进入花园"
}],
"contradictions": [{
"correct": true,
"id": "C2-01",
"text": "现场出现两组不同脚印（方头靴 vs 尖头漆皮靴）"
}, {
"correct": true,
"id": "C2-02",
"text": "乘马车来 vs 泥地大步走进入花园"
}, {
"correct": true,
"id": "C2-03",
"text": "一只马蹄铁是新的、其余三只是旧的"
}, {
"correct": true,
"id": "C2-04",
"text": "方头靴印双趟（有进有出）vs 尖头靴印单趟（只进无出）"
}],
"hypotheses": [{
"adopt_desc": "轴距6英尺10英寸（82英寸）符合留存实车实测的出租四轮马车（brougham型）典型轴距；私家大型马车约8英尺6英寸、公共马车更长。轴距越短转弯半径越小，出租马车才能在伦敦小巷里穿行调头——私家大型马车不会这么短。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c201", "c202"],
"id": "H2-01",
"kind": "true",
"new_clue_hint": "知识库·伦敦马车类型：出租四轮马车（brougham型）轴距约6英尺10英寸；私家大型马车约8英尺6英寸。",
"object": ["轴距", "6英尺10英寸", "82英寸", "6.8英尺"],
"subject": ["出租马车", "马车"],
"text": "来车是一辆出租四轮马车"
}, {
"adopt_desc": "右前蹄铁无磨损、边缘锐利，与其余三只磨损状态差异显著；正常使用的马四个蹄铁磨损应大致均匀。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c203"],
"id": "H2-02",
"kind": "true",
"new_clue_hint": "知识库·马蹄铁与马车：单个蹄铁特别新，说明该蹄铁最近更换过。",
"object": ["右前蹄", "新换"],
"subject": ["马", "蹄铁"],
"text": "右前蹄铁是新换的——这匹马最近被特别关照过"
}, {
"adopt_desc": "蹄印方向散乱、有迂回和停顿痕迹，非正常行进路线。如果有人驾驭，马不会走得这么乱——赶车的不在车上。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c204"],
"id": "H2-03",
"kind": "true",
"new_clue_hint": "知识库·马蹄铁与马车：马蹄印迹分布零乱（非直线行走），说明马曾无人驾驭。",
"object": ["蹄印零乱", "无人看管"],
"subject": ["马", "赶车人"],
"text": "马曾无人看管——赶车的人不在车上"
}, {
"adopt_desc": "",
"correct": false,
"gate_clue_ids": ["c202"],
"id": "H2-M2",
"kind": "mislead",
"reject_desc": "若徒步进入，泥地应留有连续大步足迹；已见并行车轮印与碾轧花草，与乘马车抵达矛盾。",
"text": "来客徒步踏泥大步进入花园"
}]
},
"description": "一辆伦敦出租马车停在花园街3号门口；泥地里有两组脚印——一高一矮，高个穿方头靴，两人并肩而行。

推理层级（台词库§18）：场景二只作观察事实与浅层推论，「马车夫是凶手」为假设级结论，不作定论。

活跃假设：
· H2-01 来车是出租四轮马车（轴距6英尺10英寸）
· H2-02 右前蹄铁新换——马被特别关照
· H2-03 马曾无人看管——赶车人不在车上
· H2-04 案发当晚有两个人来过（一高一矮）
· H2-05 其中一人身高约6英尺（范围估计）
· H2-06 高个子穿方头靴
· H2-07 高个子体格强壮（弱-中·可选）
· H2-08 两人并肩同行抵达（相距很近）
· H2-09 尖头漆皮靴者体态清瘦（身高约5英尺8英寸）
· H2-10 方头靴者离开、尖头靴者留在屋内

矛盾标记：
· C2-01 两组不同脚印（方头靴 vs 尖头漆皮靴）
· C2-02 乘马车来 vs 泥地大步走
· C2-03 新蹄铁一只 vs 三只旧蹄铁
· C2-04 方头靴印双趟（有进有出）vs 尖头靴印单趟（只进无出）",
"milestones": [],
"persons": [],
"title": "案发当晚的交通与人员（推理战场 M1）"
}
},
	"CH03": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H2-M1"
}, {
"expect": "negate",
"id": "CL2-M1"
}, {
"expect": "negate",
"id": "CL2-2M"
}, {
"expect": "negate",
"id": "CL2-3M"
}],
"name": "来客特征（多场景综合）",
"practice": false,
"scene": "scene2",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "两串脚印挨得极近、叠压在警察脚印之下——两个来客，一个步长2.6~2.9英尺，一个2.4~2.7英尺。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-04"],
"id": "CL2-5",
"kind": "true",
"object": ["两个人", "一高一矮"],
"subject": ["来客"],
"text": "夜间来客共两人，一高一矮"
}, {
"adopt_desc": "步长2.6~2.9英尺推算身高约6英尺，鞋印长11.5英寸、宽4英寸、压痕最深；方头靴是体力活的穿法——高个子体貌的关键观察结论（范围估计，不作定论）。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H2-05", "H2-06"],
"id": "CL2-6",
"kind": "true",
"object": ["6英尺", "方头靴"],
"subject": ["高个子"],
"text": "高个子身高约6英尺、穿方头靴"
}, {
"dir": "affirm",
"gate_hypo_ids": ["H2-M1"],
"id": "CL2-M1",
"kind": "mislead",
"object": ["矮小", "少年"],
"reject_desc": "小步漆皮靴与方头靴主组矛盾：来客并非矮小少年。",
"subject": ["来客"],
"text": "来客是身材矮小的少年"
}, {
"dir": "affirm",
"gate_hypo_ids": ["H2-05"],
"id": "CL2-2M",
"kind": "mislead",
"object": ["矮小", "瘦弱"],
"reject_desc": "现场方头靴步长（2.6~2.9英尺→身高6英尺）、印宽4英寸、压痕最深，均指向高大强壮者，与矮小瘦弱矛盾。",
"subject": ["来客"],
"text": "来客身材矮小、体格瘦弱"
}, {
"dir": "affirm",
"gate_hypo_ids": ["H2-06"],
"id": "CL2-3M",
"kind": "mislead",
"object": ["漆皮靴", "小步"],
"reject_desc": "大步脚印为方头靴，小步漆皮靴属另一位来客，两者不是同一人。",
"subject": ["高个子"],
"text": "高个子穿小步漆皮靴"
}],
"contradictions": [{
"correct": true,
"id": "C2-01",
"text": "现场出现两组不同脚印（方头靴 vs 尖头漆皮靴）"
}, {
"correct": true,
"id": "C2-02",
"text": "乘马车来 vs 泥地大步走进入花园"
}, {
"correct": true,
"id": "C2-03",
"text": "一只马蹄铁是新的、其余三只是旧的"
}, {
"correct": true,
"id": "C2-04",
"text": "方头靴印双趟（有进有出）vs 尖头靴印单趟（只进无出）"
}],
"hypotheses": [{
"adopt_desc": "泥地里有两组明显不同的脚印，彼此挨得很近、部分叠压且都在警察脚印之下——夜间来客共两人，都比警察的脚印早。方头靴那串长11.5英寸、步长约2.6~2.9英尺；尖头漆皮靴那串长11英寸、步长约2.4~2.7英尺。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c205", "c206"],
"id": "H2-04",
"kind": "true",
"new_clue_hint": "",
"object": ["两个人", "步长"],
"subject": ["来客"],
"text": "案发当晚有两个人来过（一高一矮）"
}, {
"adopt_desc": "方头靴那串步长2.6~2.9英尺（中值2.75），按步长/身高比0.45推算，身高约6英尺（183cm）；鞋印长11.5英寸、宽4英寸、压痕最深，也符合成年男子的靴底。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c206", "c309", "C_SOTCB_402"],
"id": "H2-05",
"kind": "true",
"new_clue_hint": "知识库·步长与身高：成人步长约为身高的0.45倍（贝蒂荣）；步幅（同脚相邻两印）约为步长的两倍，两者别混用。",
"object": ["身高", "6英尺"],
"subject": ["高个子"],
"text": "其中一人身高约6英尺（范围估计）"
}, {
"adopt_desc": "大步脚印的鞋头呈方形，非尖头皮靴，与方头靴特征吻合——穿这种靴子的多半是干体力活的。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c205", "c311"],
"id": "H2-06",
"kind": "true",
"new_clue_hint": "放大镜观察脚印形状：大步是方头靴，小步是漆皮靴。",
"object": ["方头靴", "靴"],
"subject": ["高个子"],
"text": "高个子穿方头靴（体力活的穿法）"
}, {
"adopt_desc": "步幅跨度与印痕深度显示来者体格强壮，属可选强化推断。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c206"],
"id": "H2-07",
"kind": "true",
"new_clue_hint": "",
"object": ["体格强壮", "强壮"],
"pool": "manual",
"subject": ["高个子"],
"text": "高个子体格强壮"
}, {
"adopt_desc": "",
"correct": false,
"gate_clue_ids": ["c205"],
"id": "H2-M1",
"kind": "mislead",
"reject_desc": "报童小步与方头靴大码脚印矛盾：现场主要脚印是方头靴，尺寸与报童不合。",
"text": "来的是身材矮小的报童"
}]
},
"description": "一辆伦敦出租马车停在花园街3号门口；泥地里有两组脚印——一高一矮，高个穿方头靴，两人并肩而行。

推理层级（台词库§18）：场景二只作观察事实与浅层推论，「马车夫是凶手」为假设级结论，不作定论。

活跃假设：
· H2-01 来车是出租四轮马车（轴距6英尺10英寸）
· H2-02 右前蹄铁新换——马被特别关照
· H2-03 马曾无人看管——赶车人不在车上
· H2-04 案发当晚有两个人来过（一高一矮）
· H2-05 其中一人身高约6英尺（范围估计）
· H2-06 高个子穿方头靴
· H2-07 高个子体格强壮（弱-中·可选）
· H2-08 两人并肩同行抵达（相距很近）
· H2-09 尖头漆皮靴者体态清瘦（身高约5英尺8英寸）
· H2-10 方头靴者离开、尖头靴者留在屋内

矛盾标记：
· C2-01 两组不同脚印（方头靴 vs 尖头漆皮靴）
· C2-02 乘马车来 vs 泥地大步走
· C2-03 新蹄铁一只 vs 三只旧蹄铁
· C2-04 方头靴印双趟（有进有出）vs 尖头靴印单趟（只进无出）",
"milestones": [],
"persons": [],
"title": "案发当晚的交通与人员（推理战场 M1）"
}
},
	"CH04": {
"core": true,
"misleads": [],
"name": "服毒判定（场景三 A 组·尸体检验）",
"practice": false,
"scene": "scene3",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "没有外伤（排除刺杀 / 枪击）+ 死相恐怖（他临死前知道会发生什么）+ 嘴唇暗紫带泡沫（生物碱特征）+ 剧烈挣扎（死亡来得不快）→ 毒杀。每一个看起来'不可能'的特征背后，都藏着一个'唯一可能'的解释。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H3-A1", "H3-A2", "H3-A5"],
"id": "CL3-2",
"kind": "true",
"object": ["毒杀"],
"subject": ["死者"],
"text": "死者死于毒杀（无外伤+恐怖表情+暗紫泡沫+剧烈挣扎，四线合一）"
}],
"contradictions": [{
"correct": true,
"id": "C3-01",
"text": "恐怖忿恨的表情 vs 心脏病 / 自然死亡的面容"
}, {
"correct": true,
"id": "C3-02",
"text": "嘴唇暗紫+泡沫（生物碱）vs 窒息的青紫+挣扎痕"
}, {
"correct": true,
"id": "C3-03",
"text": "血字是德语「复仇」 vs 雷斯垂德的「女人 RACHEL」"
}, {
"correct": true,
"id": "C3-04",
"text": "死于服毒 vs 现场没有药瓶（凶手把它带走了）"
}, {
"correct": true,
"id": "C3-05",
"text": "情杀论（女式戒指）vs 服毒预谋杀人"
}, {
"correct": true,
"id": "C-06",
"text": "死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉"
}],
"hypotheses": [{
"adopt_desc": "VERIFIED：放大镜检查全身无伤口，衣物完整无破损，指甲缝干净无搏斗痕迹——没有外伤。这本身就是一条线索。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c301", "c302"],
"id": "H3-A1",
"kind": "true",
"new_clue_hint": "知识库·法医学·窒息死亡：窒息死亡常见面部青紫、舌骨骨折，但体表可能无明显外伤。",
"object": ["无外伤"],
"subject": ["死者"],
"text": "死者身上没有外伤"
}, {
"adopt_desc": "SUPPORTED：嘴唇暗紫带泡沫 + 面部恐怖忿恨 + 全身无外伤——生物碱中毒的可能性很大，但还需毒物分析确认。有道理，但还不够。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c301", "c302"],
"id": "H3-A2",
"kind": "true",
"new_clue_hint": "知识库·毒物学·生物碱中毒：可导致面部肌肉痉挛、嘴唇发绀、瞳孔异常，死者常露出恐怖表情。",
"object": ["毒杀", "生物碱"],
"subject": ["死者"],
"text": "死者是被毒杀的"
}, {
"adopt_desc": "VERIFIED：双拳紧握、双臂伸开、双腿交叠——死前剧烈挣扎的姿势。不是被一刀毙命的人，是一点点感受着死亡逼近的人。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c301"],
"id": "H3-A5",
"kind": "true",
"new_clue_hint": "",
"object": ["挣扎", "双拳"],
"subject": ["死者"],
"text": "死者死前有过痛苦的挣扎"
}, {
"adopt_desc": "SUPPORTED：从外貌判断约四十三四岁，大致准确；精确年龄还需要身份证明。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c301"],
"id": "H3-A6",
"kind": "true",
"new_clue_hint": "",
"object": ["年龄", "四十多岁"],
"subject": ["死者"],
"text": "死者约四十多岁"
}, {
"adopt_desc": "SUPPORTED：黑呢礼服上衣、浅色裤子、洁白的硬领和袖口——衣着整洁体面，身份不低。金表金链等财物可进一步印证。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c303"],
"id": "H3-A7",
"kind": "true",
"new_clue_hint": "",
"object": ["衣着", "身份"],
"subject": ["死者"],
"text": "死者身份不低（从衣着判断）"
}]
},
"description": "室内勘查三条线：A 尸体检验（无外伤 + 恐怖表情 + 暗紫泡沫 + 剧烈挣扎 → 毒杀）、B 随身物品（九件物品 → 德雷伯 / 克利夫兰 / 斯特兰森）、C 现场痕迹（血字 RACHE / 两组靴印 / 印度雪茄烟灰）。

推理层级（台词库 §18 场景三）：本场景只作观察事实与浅层推论，不作定论。
· VERIFIED 已证实：无外伤 / 死前挣扎 / 血字是 RACHE / 现场两人 / 靴子种类 / 死者姓名 / 来自克利夫兰
· SUPPORTED 有支持待证：毒杀 / 血字为德语复仇 / 书写者身高约六英尺 / 指甲未修剪 / 共济会成员 / 经济宽裕 / 准备乘船回纽约 / 斯特兰森是同伴
· INSUFFICIENT 证据不足：死于心脏病 / 被吓死 / 斯特兰森涉案 / 与女人有关 / 死于仇杀 / 凶手抽印度雪茄 / 案件是复仇性质
· CONTRADICTORY 与证据矛盾：与一个叫 RACHEL 的女人有关（雷斯垂德观点）

矛盾标记：
· C3-01 恐怖忿恨的表情 vs 心脏病/自然死亡的面容
· C3-02 暗紫+泡沫（生物碱）vs 窒息的青紫
· C3-03 德语复仇 vs 雷斯垂德的「女人 RACHEL」
· C3-04 死于服毒 vs 现场没有药瓶
· C3-05 情杀论（女式戒指）vs 服毒预谋
· C-06 死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉",
"milestones": [],
"persons": [],
"title": "死者身份、死因与现场痕迹（推理战场 M1）"
}
},
	"CH05": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H3-C10"
}, {
"expect": "negate",
"id": "CL3-M1"
}],
"name": "RACHE 血字与现场痕迹（场景三 C 组）",
"practice": false,
"scene": "scene3",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "一行血字读出三件事：写的是 RACHE（德语复仇），写它的人身高约六英尺，而且右手指甲没有修剪——后两条，日后都是认人的凭据。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H3-C1", "H3-C2", "H3-C3", "H3-C4"],
"id": "CL3-3",
"kind": "true",
"object": ["复仇", "六英尺"],
"subject": ["血字"],
"text": "血字 RACHE 是德语「复仇」，书写者身高约六英尺、指甲未修剪"
}, {
"adopt_desc": "现场有两个人：一个穿漆皮靴，就是死者；一个穿方头靴，高个子——和花园里的马车、脚印连成了一条线。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H3-C5", "H3-C6", "H3-C7"],
"id": "CL3-4",
"kind": "true",
"object": ["两个人", "方头靴"],
"subject": ["现场"],
"text": "现场两个人：死者穿漆皮靴，另一个穿方头靴、身高约六英尺"
}, {
"dir": "affirm",
"gate_hypo_ids": ["H3-C10"],
"id": "CL3-M1",
"kind": "mislead",
"object": ["RACHEL", "女人"],
"reject_desc": "雷斯垂德的理论？先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。这两个结论，总有一个有问题。",
"subject": ["案件"],
"text": "案件与一个叫 RACHEL 的女人有关"
}],
"contradictions": [{
"correct": true,
"id": "C3-01",
"text": "恐怖忿恨的表情 vs 心脏病 / 自然死亡的面容"
}, {
"correct": true,
"id": "C3-02",
"text": "嘴唇暗紫+泡沫（生物碱）vs 窒息的青紫+挣扎痕"
}, {
"correct": true,
"id": "C3-03",
"text": "血字是德语「复仇」 vs 雷斯垂德的「女人 RACHEL」"
}, {
"correct": true,
"id": "C3-04",
"text": "死于服毒 vs 现场没有药瓶（凶手把它带走了）"
}, {
"correct": true,
"id": "C3-05",
"text": "情杀论（女式戒指）vs 服毒预谋杀人"
}, {
"correct": true,
"id": "C-06",
"text": "死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉"
}],
"hypotheses": [{
"adopt_desc": "VERIFIED：亲眼所见——墙角花纸剥落处，黄色粉墙上用鲜血潦草地写着 RACHE。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c309"],
"id": "H3-C1",
"kind": "true",
"new_clue_hint": "",
"object": ["RACHE"],
"subject": ["血字"],
"text": "墙上的血字是「RACHE」"
}, {
"adopt_desc": "SUPPORTED：德语中 RACHE 意为复仇——词典确有此词，但写字者的本意是否如此还不确定。有意思的方向，但一个词不等于真相。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c309"],
"id": "H3-C2",
"kind": "true",
"new_clue_hint": "知识库·「RACHE」德语词义：德语中 RACHE 意为「复仇」。",
"object": ["德语", "复仇"],
"subject": ["血字"],
"text": "血字是德语「复仇」的意思"
}, {
"adopt_desc": "SUPPORTED：血字字迹中心离地约5英尺7英寸半（171厘米），正落在站立书写者的眼睛高度（站立眼高≈身高×0.94）→ 反推书写者身高约6英尺（183cm）；再加方头靴步长2.6~2.9英尺推算——双重印证，但不是精确测量。六英尺的人，方头靴——和花园里的发现对上了。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c309", "c311"],
"id": "H3-C3",
"kind": "true",
"new_clue_hint": "知识库·人体测量（KB-B-2）：人在墙面书写时字迹大致落在双眼高度，站立眼高≈身高×0.93~0.94，故书写者身高≈字迹离地高度÷0.94。",
"object": ["身高", "六英尺"],
"subject": ["书写者"],
"text": "写字的人身高约六英尺"
}, {
"adopt_desc": "SUPPORTED：血字笔画边缘有墙粉刮痕，暗示指甲较长（也可能是写字时用力所致）；而死者指甲缝干净——血字不是死者写的。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c309", "c301"],
"id": "H3-C4",
"kind": "true",
"new_clue_hint": "",
"object": ["指甲", "未修剪"],
"subject": ["书写者"],
"text": "写字的人右手指甲未修剪"
}, {
"adopt_desc": "VERIFIED：地板尘土中有两组明显不同的脚印，部分叠压、且都在警察的脚印之下——现场来过两个人。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c311"],
"id": "H3-C5",
"kind": "true",
"new_clue_hint": "",
"object": ["两个人"],
"subject": ["现场"],
"text": "现场有两个人来过"
}, {
"adopt_desc": "VERIFIED：靴印清晰可辨——穿漆皮靴的那位，就躺在我们面前；方头靴属于另一个人。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c311"],
"id": "H3-C6",
"kind": "true",
"new_clue_hint": "知识库·19世纪伦敦常见靴子类型：漆皮靴（正装）、方头靴（日常）、高筒靴（户外）。",
"object": ["方头靴", "漆皮靴"],
"subject": ["来人"],
"text": "一人穿方头靴，另一人穿漆皮靴"
}, {
"adopt_desc": "SUPPORTED：约2.6~2.9英尺的步长属于方头靴那一组，且血字高度由方头靴者书写的可能性大——两者互相印证。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c309", "c311"],
"id": "H3-C7",
"kind": "true",
"new_clue_hint": "知识库·步伐距离与身高关系：一般成年人步幅约等于身高的 0.45 倍。",
"object": ["高个", "步幅"],
"subject": ["方头靴者"],
"text": "穿方头靴的那个人个子较高"
}, {
"adopt_desc": "CONTRADICTORY：现场两组脚印都是男式靴子，与「一个女人」的说法矛盾；而那个德语词更可能是复仇，并不是没写完的名字。",
"correct": false,
"dir": "affirm",
"gate_clue_ids": ["c309", "c312"],
"id": "H3-C10",
"kind": "mislead",
"object": ["RACHEL", "女人"],
"reject_desc": "雷斯垂德的理论？先看看两组脚印——穿漆皮靴的那位，就躺在我们面前。这两个结论，总有一个有问题。",
"subject": ["案件"],
"text": "案件与一个叫 RACHEL 的女人有关（雷斯垂德观点）"
}]
},
"description": "室内勘查三条线：A 尸体检验（无外伤 + 恐怖表情 + 暗紫泡沫 + 剧烈挣扎 → 毒杀）、B 随身物品（九件物品 → 德雷伯 / 克利夫兰 / 斯特兰森）、C 现场痕迹（血字 RACHE / 两组靴印 / 印度雪茄烟灰）。

推理层级（台词库 §18 场景三）：本场景只作观察事实与浅层推论，不作定论。
· VERIFIED 已证实：无外伤 / 死前挣扎 / 血字是 RACHE / 现场两人 / 靴子种类 / 死者姓名 / 来自克利夫兰
· SUPPORTED 有支持待证：毒杀 / 血字为德语复仇 / 书写者身高约六英尺 / 指甲未修剪 / 共济会成员 / 经济宽裕 / 准备乘船回纽约 / 斯特兰森是同伴
· INSUFFICIENT 证据不足：死于心脏病 / 被吓死 / 斯特兰森涉案 / 与女人有关 / 死于仇杀 / 凶手抽印度雪茄 / 案件是复仇性质
· CONTRADICTORY 与证据矛盾：与一个叫 RACHEL 的女人有关（雷斯垂德观点）

矛盾标记：
· C3-01 恐怖忿恨的表情 vs 心脏病/自然死亡的面容
· C3-02 暗紫+泡沫（生物碱）vs 窒息的青紫
· C3-03 德语复仇 vs 雷斯垂德的「女人 RACHEL」
· C3-04 死于服毒 vs 现场没有药瓶
· C3-05 情杀论（女式戒指）vs 服毒预谋
· C-06 死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉",
"milestones": [],
"persons": [],
"title": "死者身份、死因与现场痕迹（推理战场 M1）"
}
},
	"CH06": {
"core": true,
"misleads": [],
"name": "死者身份与随身物品（场景三 B 组）",
"practice": false,
"scene": "scene3",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "基本盘清楚了：德雷伯，美国人，克利夫兰来的，有钱——但这还不够解释他为什么会死在这里。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H3-B1", "H3-B2"],
"id": "CL3-1",
"kind": "true",
"object": ["德雷伯", "克利夫兰"],
"subject": ["死者"],
"text": "死者是美国克利夫兰人伊诺克·J·德雷伯"
}, {
"adopt_desc": "从克利夫兰到利物浦，再到伦敦……他有个同伴叫斯特兰森，两人正准备乘船回纽约。他在躲什么？还是在追什么？",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H3-B5", "H3-B6"],
"id": "CL3-5",
"kind": "true",
"object": ["同伴", "回纽约"],
"subject": ["斯特兰森"],
"text": "斯特兰森是死者的同伴，两人原定乘船回纽约"
}],
"contradictions": [{
"correct": true,
"id": "C3-01",
"text": "恐怖忿恨的表情 vs 心脏病 / 自然死亡的面容"
}, {
"correct": true,
"id": "C3-02",
"text": "嘴唇暗紫+泡沫（生物碱）vs 窒息的青紫+挣扎痕"
}, {
"correct": true,
"id": "C3-03",
"text": "血字是德语「复仇」 vs 雷斯垂德的「女人 RACHEL」"
}, {
"correct": true,
"id": "C3-04",
"text": "死于服毒 vs 现场没有药瓶（凶手把它带走了）"
}, {
"correct": true,
"id": "C3-05",
"text": "情杀论（女式戒指）vs 服毒预谋杀人"
}, {
"correct": true,
"id": "C-06",
"text": "死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉"
}],
"hypotheses": [{
"adopt_desc": "VERIFIED：名片「伊诺克·J·德雷伯」+ 金表背面「E.J.D.」刻字 + 衬衣缩写——三重印证。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c304"],
"id": "H3-B1",
"kind": "true",
"new_clue_hint": "",
"object": ["德雷伯"],
"subject": ["死者"],
"text": "死者名叫伊诺克·J·德雷伯"
}, {
"adopt_desc": "VERIFIED：名片上明确标注「克利夫兰」。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c304"],
"id": "H3-B2",
"kind": "true",
"new_clue_hint": "知识库·克利夫兰：美国俄亥俄州城市，19世纪后期重要工业城市。",
"object": ["克利夫兰", "美国"],
"subject": ["死者"],
"text": "死者来自美国克利夫兰"
}, {
"adopt_desc": "SUPPORTED：金戒指上刻着共济会图案，内侧有磨损痕迹——佩戴者通常是成员，但不绝对。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c306"],
"id": "H3-B3",
"kind": "true",
"new_clue_hint": "知识库·共济会：近代互助组织，成员多为中产及以上阶层。",
"object": ["共济会", "戒指"],
"subject": ["死者"],
"text": "死者是共济会成员"
}, {
"adopt_desc": "SUPPORTED：金表、阿尔伯特金链、红宝石金别针、七英镑十三先令零钱全部原封未动——经济宽裕，作案动机不在钱财。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c305"],
"id": "H3-B4",
"kind": "true",
"new_clue_hint": "",
"object": ["金表", "财物"],
"subject": ["死者"],
"text": "死者经济状况良好，且并未遭抢劫"
}, {
"adopt_desc": "SUPPORTED：盖恩轮船公司的信件通知了轮船从利物浦启程的日期——但不排除那其实是斯特兰森的计划。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c304"],
"id": "H3-B5",
"kind": "true",
"new_clue_hint": "知识库·盖恩轮船公司：19世纪从事跨大西洋航运的美国公司。",
"object": ["盖恩轮船公司", "回纽约"],
"subject": ["死者"],
"text": "死者正准备乘船回纽约"
}, {
"adopt_desc": "SUPPORTED：两封信分别寄给德雷伯与斯特兰森，小说扉页写着「约瑟夫·斯特兰森」——两人关系密切，具体身份还有待确认。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["c304", "c307"],
"id": "H3-B6",
"kind": "true",
"new_clue_hint": "",
"object": ["秘书", "同伴"],
"subject": ["斯特兰森"],
"text": "斯特兰森是死者的秘书或同伴"
}]
},
"description": "室内勘查三条线：A 尸体检验（无外伤 + 恐怖表情 + 暗紫泡沫 + 剧烈挣扎 → 毒杀）、B 随身物品（九件物品 → 德雷伯 / 克利夫兰 / 斯特兰森）、C 现场痕迹（血字 RACHE / 两组靴印 / 印度雪茄烟灰）。

推理层级（台词库 §18 场景三）：本场景只作观察事实与浅层推论，不作定论。
· VERIFIED 已证实：无外伤 / 死前挣扎 / 血字是 RACHE / 现场两人 / 靴子种类 / 死者姓名 / 来自克利夫兰
· SUPPORTED 有支持待证：毒杀 / 血字为德语复仇 / 书写者身高约六英尺 / 指甲未修剪 / 共济会成员 / 经济宽裕 / 准备乘船回纽约 / 斯特兰森是同伴
· INSUFFICIENT 证据不足：死于心脏病 / 被吓死 / 斯特兰森涉案 / 与女人有关 / 死于仇杀 / 凶手抽印度雪茄 / 案件是复仇性质
· CONTRADICTORY 与证据矛盾：与一个叫 RACHEL 的女人有关（雷斯垂德观点）

矛盾标记：
· C3-01 恐怖忿恨的表情 vs 心脏病/自然死亡的面容
· C3-02 暗紫+泡沫（生物碱）vs 窒息的青紫
· C3-03 德语复仇 vs 雷斯垂德的「女人 RACHEL」
· C3-04 死于服毒 vs 现场没有药瓶
· C3-05 情杀论（女式戒指）vs 服毒预谋
· C-06 死者指甲干净 vs 血字有指甲刮痕 → 血字是凶手写的，凶手指甲缝必沾墙粉",
"milestones": [],
"persons": [],
"title": "死者身份、死因与现场痕迹（推理战场 M1）"
}
},
	"CH07": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H4-M1"
}],
"name": "醉汉=凶手（马车夫）",
"practice": false,
"scene": "scene4",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "马鞭。马车。车夫。——你把这些拼起来：一个人赶着马车，把受害人送进那栋空房子，然后自己又唱着歌走出来。但别急。我们还在猜。猜得再漂亮，也不是证据。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H4-07", "H4-05", "H4-10"],
"id": "CL4-1",
"kind": "true",
"object": ["马车夫"],
"subject": ["凶手"],
"text": "醉汉就是凶手——一个赶着马车来的车夫"
}, {
"adopt_desc": "最危险的地方就是最安全的地方。一个烂醉的流浪汉，谁会把他和杀人犯联系在一起？——他的表演本身就是供词。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H4-07", "H4-11"],
"id": "CL4-2",
"kind": "true",
"object": ["伪装"],
"subject": ["凶手"],
"text": "凶手伪装成醉汉逃走——灯下黑"
}],
"contradictions": [{
"correct": true,
"id": "C4-01",
"text": "兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事"
}, {
"correct": true,
"id": "C4-02",
"text": "精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）"
}, {
"correct": true,
"id": "C4-03",
"text": "无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的"
}, {
"correct": true,
"id": "C4-04",
"text": "'有个女的' vs 现场两组男式靴印（无女式鞋印）"
}],
"hypotheses": [{
"adopt_desc": "VERIFIED：兰斯亲眼看见——街灯底下，唱得震天响，站都站不住，他还提灯过去想轰走他。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401"],
"id": "H4-03",
"kind": "true",
"new_clue_hint": "",
"object": ["醉汉"],
"subject": ["现场"],
"text": "门口有个醉汉"
}, {
"adopt_desc": "SUPPORTED：街灯下、提灯照脸、一两步的距离——这份证词就可靠了。高个、红脸，和花园街'凶手高个红脸'的画像对上了。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_402", "C_SOTCB_403"],
"id": "H4-04",
"kind": "true",
"new_clue_hint": "",
"object": ["高个", "红脸"],
"subject": ["醉汉"],
"text": "醉汉高个红脸"
}, {
"adopt_desc": "SUPPORTED：提灯照着看得真真的——一件棕色外衣，是伦敦出租马车夫常见的装束。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_404"],
"id": "H4-05",
"kind": "true",
"new_clue_hint": "",
"object": ["棕色外衣", "马车夫"],
"subject": ["醉汉"],
"text": "醉汉穿棕色外衣（马车夫装束）"
}, {
"adopt_desc": "SUPPORTED：凌晨两点，一个高个红脸的男人，站在一栋空房子门口唱歌——喝醉了。嗯，这是个'巧合'。你信巧合吗？——华生，你太善良了。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401", "C_SOTCB_402", "C_SOTCB_403"],
"id": "H4-07",
"kind": "true",
"new_clue_hint": "",
"object": ["凶手"],
"subject": ["醉汉"],
"text": "醉汉就是凶手"
}, {
"adopt_desc": "SUPPORTED：花园街的出租马车轮印 + 兰斯证词'巡夜时有一两辆马车路过'——现场确实有马车出没。马鞭。马车。车夫。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_407"],
"id": "H4-10",
"kind": "true",
"new_clue_hint": "",
"object": ["马车"],
"subject": ["凶手"],
"text": "凶手坐马车来（案发时有马车出没）"
}, {
"adopt_desc": "SUPPORTED：一个人看到屋里有尸体，第一反应是什么？是吹警笛叫人。那一刻，谁会去看门口一个唱得难听的醉汉？——'灯下黑'三个字，你今天第一次用对了地方。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_405", "C_SOTCB_407"],
"id": "H4-11",
"kind": "true",
"new_clue_hint": "",
"object": ["伪装", "灯下黑"],
"subject": ["凶手"],
"text": "凶手伪装成醉汉逃走"
}, {
"adopt_desc": "CONTRADICTORY：现场两组男式靴印，一组方头、一组漆皮——没有第三组，没有任何女式鞋印。兰斯是真的看见了，还是——他需要'看见'？证人说谎，有时候不是为害人，是为了让自己在故事里更像个主角。",
"correct": false,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401"],
"id": "H4-M1",
"kind": "mislead",
"object": ["女人"],
"reject_desc": "好眼力——但记住：证人需要'看见'的时候，就会'看见'。这条先放一放，跟靴印对一对再说。",
"subject": ["醉汉"],
"text": "醉汉旁边还有一个女人（兰斯证词）"
}]
},
"description": "人证调查六步闭环：从兰斯的叙述中筛出有用信息、识别可能的记忆偏差，并与场景二/三的发现交叉印证。

核心原则：未追问到的细节不出现在后续推理中；证词是证人说的，不是事实。

推理层级（台词库 §18 场景四）：
· VERIFIED 已证实：案发时间≈凌晨两点 / 正在下雨 / 门口有个醉汉
· SUPPORTED 有支持待证：高个红脸 / 棕色外衣 / 醉汉=凶手 / 凶手坐马车来 / 凶手伪装醉汉逃走 / 兰斯错过凶手
· INSUFFICIENT 证据不足：可能有马鞭 / 醉汉是同伙 / 醉汉无关路过
· CONTRADICTORY 与证据矛盾（困难模式误导）：醉汉旁边还有个女人（现场两组男式靴印，无女式鞋印）

矛盾标记：
· C4-01 兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事
· C4-02 精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）
· C4-03 无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的
· C4-04 '有个女的' vs 现场两组男式靴印",
"milestones": [],
"persons": [],
"title": "醉汉=凶手（兰斯证词 · 推理战场 M1）"
}
},
	"CH08": {
"core": false,
"misleads": [],
"name": "兰斯证词时间线",
"practice": false,
"scene": "scene4",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "两点十分、雨里、几分钟后才叫人——时间线收口了。而凶手，就在这几分钟里从兰斯的眼皮底下走掉了。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H4-01", "H4-02", "H4-12"],
"id": "CL4-3",
"kind": "true",
"object": ["凌晨两点"],
"subject": ["时间线"],
"text": "案发时间线：凌晨两点、下雨，兰斯错过了凶手"
}],
"contradictions": [{
"correct": true,
"id": "C4-01",
"text": "兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事"
}, {
"correct": true,
"id": "C4-02",
"text": "精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）"
}, {
"correct": true,
"id": "C4-03",
"text": "无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的"
}, {
"correct": true,
"id": "C4-04",
"text": "'有个女的' vs 现场两组男式靴印（无女式鞋印）"
}],
"hypotheses": [{
"adopt_desc": "VERIFIED：兰斯明确证词——两点出头、两点过十分。他在里面待了几分钟就吹了警笛，摩契他们两三分钟就到。时间线收口了。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401"],
"id": "H4-01",
"kind": "true",
"new_clue_hint": "",
"object": ["凌晨两点"],
"subject": ["案发"],
"text": "案发时间约凌晨两点"
}, {
"adopt_desc": "VERIFIED：夜里一点开始下雨——兰斯巡夜全程在雨里，花园街泥地的痕迹也对得上。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401"],
"id": "H4-02",
"kind": "true",
"new_clue_hint": "",
"object": ["下雨"],
"subject": ["案发"],
"text": "案发时正在下雨"
}, {
"adopt_desc": "SUPPORTED：他进屋看见尸体，第一反应是叫人——光顾着吹警笛，没注意门口那个'醉汉'又待了多久、往哪边走了。",
"correct": true,
"dir": "affirm",
"gate_clue_ids": ["C_SOTCB_401"],
"id": "H4-12",
"kind": "true",
"new_clue_hint": "",
"object": ["错过"],
"subject": ["兰斯"],
"text": "兰斯错过了凶手"
}]
},
"description": "人证调查六步闭环：从兰斯的叙述中筛出有用信息、识别可能的记忆偏差，并与场景二/三的发现交叉印证。

核心原则：未追问到的细节不出现在后续推理中；证词是证人说的，不是事实。

推理层级（台词库 §18 场景四）：
· VERIFIED 已证实：案发时间≈凌晨两点 / 正在下雨 / 门口有个醉汉
· SUPPORTED 有支持待证：高个红脸 / 棕色外衣 / 醉汉=凶手 / 凶手坐马车来 / 凶手伪装醉汉逃走 / 兰斯错过凶手
· INSUFFICIENT 证据不足：可能有马鞭 / 醉汉是同伙 / 醉汉无关路过
· CONTRADICTORY 与证据矛盾（困难模式误导）：醉汉旁边还有个女人（现场两组男式靴印，无女式鞋印）

矛盾标记：
· C4-01 兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事
· C4-02 精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）
· C4-03 无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的
· C4-04 '有个女的' vs 现场两组男式靴印",
"milestones": [],
"persons": [],
"title": "醉汉=凶手（兰斯证词 · 推理战场 M1）"
}
},
	"CH09A": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H5-06"
}],
"name": "老太婆伪装识破",
"practice": false,
"scene": "scene5",
"wall": {
"battlefield": {
"conclusions": [{
"correct": true,
"gate_clue_ids": [],
"gate_hypo_ids": ["H5-04"],
"id": "CL5-1",
"text": "伪装识破：老太婆是年轻人男扮女装"
}, {
"correct": true,
"gate_clue_ids": [],
"gate_hypo_ids": ["H5-08"],
"id": "CL5-3",
"text": "戒指对凶手非同小可（必回来取）"
}],
"contradictions": [{
"correct": true,
"id": "C5-01",
"text": "老太婆虚弱 vs 跳上马车敏捷"
}, {
"correct": true,
"id": "C5-02",
"text": "凶手缜密 vs 亲自冒险取戒指"
}, {
"correct": true,
"id": "C5-03",
"text": "葛莱森政治阴谋论 vs 私人恩怨背景"
}, {
"correct": true,
"id": "C5-04",
"text": "雷斯垂德马车夫方向 vs 他查的都错"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_507"],
"id": "H5-03",
"text": "来者和案件有关，是凶手派来的"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_503", "C_SOTCB_507"],
"gate_hypo_ids": ["H5-03"],
"id": "H5-04",
"text": "来者就是凶手本人伪装的"
}, {
"correct": false,
"id": "H5-06",
"kind": "mislead",
"text": "不用跟踪，放她走也没关系"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_503"],
"id": "H5-08",
"text": "戒指是凶手故意掉的，引蛇出洞"
}]
},
"description": "来领戒指的'老太婆'脱逃揭晓为年轻人伪装；两份电报 + 伪装识破 + 美国背景锁定霍普。

活跃假设：
· H5-01 来者就是普通失主（错：脱逃推翻）
· H5-02 来者是来占便宜的（错：为戒指冒风险说不通）
· H5-03 来者和案件有关，是凶手派来的（中：脱逃证明有问题）
· H5-04 来者就是凶手本人伪装（强：脱逃目击换装）
· H5-05 应该跟踪她（对：跟踪获得关键验证）
· H5-06 不用跟踪放她走（误导：错过脱逃验证）
· H5-07 凶手是马车夫（强：无马鞭+出租马车+伪装跳上马车逃走）
· H5-08 戒指是凶手故意掉的，引蛇出洞（中：他确实回来找戒指）
· H5-09 马车夫常在泰晤士河北岸活动（B路线·铁匠铺证词 gate）

矛盾标记：
· C5-01 老太婆虚弱 vs 跳上马车敏捷（识破伪装后自动解决）
· C5-02 凶手缜密 vs 亲自冒险取戒指（场景八揭示：戒指是露西遗物）
· C5-03 葛莱森政治阴谋论 vs 私人恩怨背景（推翻葛莱森假设的关键）
· C5-04 雷斯垂德马车夫方向 vs 他查的都错（贝克街分队找到正确的人）",
"milestones": [],
"persons": [],
"title": "老太婆是伪装，凶手=杰弗森·霍普（推理战场 M1）"
}
},
	"CH09A2": {
"core": false,
"misleads": [],
"name": "凶手=北岸马车夫",
"practice": false,
"scene": "scene5",
"wall": {
"battlefield": {
"conclusions": [{
"correct": true,
"gate_clue_ids": [],
"gate_hypo_ids": ["H5-07", "H5-09"],
"id": "CL5-2",
"text": "凶手=北岸马车夫（杰弗森·霍普）"
}],
"contradictions": [{
"correct": true,
"id": "C5-01",
"text": "老太婆虚弱 vs 跳上马车敏捷"
}, {
"correct": true,
"id": "C5-02",
"text": "凶手缜密 vs 亲自冒险取戒指"
}, {
"correct": true,
"id": "C5-03",
"text": "葛莱森政治阴谋论 vs 私人恩怨背景"
}, {
"correct": true,
"id": "C5-04",
"text": "雷斯垂德马车夫方向 vs 他查的都错"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_501"],
"id": "H5-07",
"text": "凶手是马车夫"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_508"],
"id": "H5-09",
"text": "马车夫常在泰晤士河北岸活动"
}]
},
"description": "来领戒指的'老太婆'脱逃揭晓为年轻人伪装；两份电报 + 伪装识破 + 美国背景锁定霍普。

活跃假设：
· H5-01 来者就是普通失主（错：脱逃推翻）
· H5-02 来者是来占便宜的（错：为戒指冒风险说不通）
· H5-03 来者和案件有关，是凶手派来的（中：脱逃证明有问题）
· H5-04 来者就是凶手本人伪装（强：脱逃目击换装）
· H5-05 应该跟踪她（对：跟踪获得关键验证）
· H5-06 不用跟踪放她走（误导：错过脱逃验证）
· H5-07 凶手是马车夫（强：无马鞭+出租马车+伪装跳上马车逃走）
· H5-08 戒指是凶手故意掉的，引蛇出洞（中：他确实回来找戒指）
· H5-09 马车夫常在泰晤士河北岸活动（B路线·铁匠铺证词 gate）

矛盾标记：
· C5-01 老太婆虚弱 vs 跳上马车敏捷（识破伪装后自动解决）
· C5-02 凶手缜密 vs 亲自冒险取戒指（场景八揭示：戒指是露西遗物）
· C5-03 葛莱森政治阴谋论 vs 私人恩怨背景（推翻葛莱森假设的关键）
· C5-04 雷斯垂德马车夫方向 vs 他查的都错（贝克街分队找到正确的人）",
"milestones": [],
"persons": [],
"title": "老太婆是伪装，凶手=杰弗森·霍普（推理战场 M1）"
}
},
	"CH09B": {
"core": false,
"misleads": [{
"expect": "negate",
"id": "H6-05"
}, {
"expect": "negate",
"id": "H6-06"
}],
"name": "卡彭蒂耶排除",
"practice": false,
"scene": "scene6",
"wall": {
"battlefield": {
"conclusions": [{
"gate_clue_ids": [],
"gate_hypo_ids": ["H6-01", "H6-07"],
"id": "CL6-1",
"text": "卡彭蒂耶中尉被排除（体貌不符+不在场证明）"
}],
"contradictions": [{
"correct": true,
"id": "C6-01",
"text": "身高5.8英尺 vs 凶手6英尺+"
}, {
"correct": true,
"id": "C6-02",
"text": "有动机 vs 有不在场证明"
}, {
"correct": true,
"id": "C6-03",
"text": "木棍「凶器」 vs 死者服毒"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_603", "C_SOTCB_605"],
"id": "H6-01",
"text": "卡彭蒂耶中尉不是凶手"
}, {
"correct": false,
"id": "H6-05",
"kind": "mislead",
"text": "卡彭蒂耶中尉是凶手（葛莱森错误结论）"
}, {
"correct": false,
"id": "H6-06",
"kind": "mislead",
"text": "阿瑟追打德雷伯时失手杀人"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_603", "C_SOTCB_605"],
"id": "H6-07",
"text": "德雷伯跳上的马车有问题"
}]
},
"description": "葛莱森以「动机+木棍+时间」断定阿瑟是凶手，但三份证词 + 房间环境给出三组矛盾，将其彻底排除。

活跃假设：
· H6-01 卡彭蒂耶中尉不是凶手（强：身高矛盾 + 不在场证明 + 体格矛盾）
· H6-02 威廉·哈珀证词可信（中强：海军中士身份 + 具体时间线）

矛盾标记（推理战场「矛盾标记」功能集中展示）：
· C6-01 事实矛盾：卡彭蒂耶身高5.8英尺 vs 凶手6英尺+（身高差4英寸，不可能同一人）
· C6-02 逻辑矛盾：有动机杀人 vs 有完美不在场证明（案发时正与哈珀长谈）
· C6-03 证据矛盾：木棍「凶器」 vs 死者死于服毒（葛莱森连死因都没搞清就抓人）

玩家可提交假设池（9条）：卡彭蒂耶=凶手 / 太太隐瞒 / 6小时空白期 / 阿瑟失手 / 马车有问题 / 爱莉丝真话 / 体貌不符 / W.H.=哈珀 / 哈珀可作证。",
"milestones": [],
"persons": [],
"title": "排除阿瑟·卡彭蒂耶中尉，确认其为错误嫌疑（推理战场矛盾标记展示）"
}
},
	"CH09C": {
"core": false,
"misleads": [],
"name": "哈珀证词",
"practice": false,
"scene": "scene6",
"wall": {
"battlefield": {
"conclusions": [{
"gate_clue_ids": [],
"gate_hypo_ids": ["H6-02", "H6-09"],
"id": "CL6-2",
"text": "哈珀证词坐实阿瑟不在场证明"
}],
"contradictions": [{
"correct": true,
"id": "C6-01",
"text": "身高5.8英尺 vs 凶手6英尺+"
}, {
"correct": true,
"id": "C6-02",
"text": "有动机 vs 有不在场证明"
}, {
"correct": true,
"id": "C6-03",
"text": "木棍「凶器」 vs 死者服毒"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_604"],
"id": "H6-02",
"text": "威廉·哈珀证词可信"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_604"],
"id": "H6-09",
"text": "W.H.就是威廉·哈珀"
}]
},
"description": "葛莱森以「动机+木棍+时间」断定阿瑟是凶手，但三份证词 + 房间环境给出三组矛盾，将其彻底排除。

活跃假设：
· H6-01 卡彭蒂耶中尉不是凶手（强：身高矛盾 + 不在场证明 + 体格矛盾）
· H6-02 威廉·哈珀证词可信（中强：海军中士身份 + 具体时间线）

矛盾标记（推理战场「矛盾标记」功能集中展示）：
· C6-01 事实矛盾：卡彭蒂耶身高5.8英尺 vs 凶手6英尺+（身高差4英寸，不可能同一人）
· C6-02 逻辑矛盾：有动机杀人 vs 有完美不在场证明（案发时正与哈珀长谈）
· C6-03 证据矛盾：木棍「凶器」 vs 死者死于服毒（葛莱森连死因都没搞清就抓人）

玩家可提交假设池（9条）：卡彭蒂耶=凶手 / 太太隐瞒 / 6小时空白期 / 阿瑟失手 / 马车有问题 / 爱莉丝真话 / 体貌不符 / W.H.=哈珀 / 哈珀可作证。",
"milestones": [],
"persons": [],
"title": "排除阿瑟·卡彭蒂耶中尉，确认其为错误嫌疑（推理战场矛盾标记展示）"
}
},
	"CH09D": {
"core": true,
"misleads": [{
"expect": "negate",
"id": "H7-08"
}],
"name": "斯特兰森",
"practice": false,
"scene": "scene7",
"wall": {
"battlefield": {
"conclusions": [{
"gate_clue_ids": ["C_SOTCB_707"],
"gate_hypo_ids": ["H7-01", "H7-02", "H7-03", "H7-05"],
"id": "CL7-1",
"text": "斯特兰森亦被霍普所杀，两案同一凶手"
}, {
"gate_clue_ids": [],
"gate_hypo_ids": ["H7-04", "H7-12"],
"id": "CL7-3",
"text": "凶手=杰弗森·霍普"
}],
"contradictions": [{
"correct": true,
"id": "C7-01",
"text": "服毒 vs 刀杀（两种杀人方式）"
}, {
"correct": true,
"id": "C7-02",
"text": "谨慎缜密 vs 留血字RACHE"
}, {
"correct": true,
"id": "C7-03",
"text": "钱袋80镑未失 vs 谋财"
}, {
"correct": true,
"id": "C7-04",
"text": "雷斯垂德找到 vs 找到的是尸体"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_702", "C_SOTCB_706"],
"id": "H7-01",
"text": "斯特兰森死于刀伤，非服毒"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_701"],
"id": "H7-02",
"text": "药丸一毒一无毒（上帝裁决）"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_703"],
"id": "H7-03",
"text": "两起案件为同一凶手"
}, {
"correct": true,
"gate_clue_ids": [],
"id": "H7-04",
"text": "凶手=杰弗森·霍普"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_703"],
"id": "H7-05",
"text": "凶手从窗户逃走"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_708"],
"id": "H7-06",
"text": "凶手心理素质极强"
}, {
"correct": false,
"id": "H7-08",
"kind": "mislead",
"text": "两案不同凶手（雷斯垂德观）"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_706"],
"id": "H7-12",
"text": "J.H.就是杰弗森·霍普"
}]
},
"description": "斯特兰森死于利刃（与德雷伯服毒不同手法），但窗户非常规进出、木匣两粒药丸（一毒一无毒的「上帝裁决」）、J.H.电报、送奶工目击（大个子红脸棕外衣）与德雷伯案同源。

活跃假设：
· H7-01 斯特兰森死于刀伤，非服毒（强：致命伤口+无药丸痕迹）
· H7-02 药丸一毒一无毒（上帝裁决）（中强：实验结果+两粒外观一致）
· H7-03 两起案件为同一凶手（强：体貌+红脸+高个+马车夫+血字 RACHE）
· H7-04 凶手=杰弗森·霍普（强：J.H.电报+美国背景+复仇动机+马车夫）

矛盾标记：
· C7-01 事实矛盾：德雷伯服毒 vs 斯特兰森被刀杀（同一凶手，为何两种手法？→ 斯特兰森拒选药丸，被迫动刀）
· C7-02 逻辑矛盾：凶手谨慎缜密 vs 留下血字 RACHE（血字是复仇宣言/仪式，非失误）
· C7-03 证据矛盾：钱袋80镑分文不少 vs 谋财害命（推翻谋财，确认复仇动机）
· C7-04 证据矛盾：雷斯垂德找到斯特兰森 vs 找到的是尸体（方向对但慢一步）",
"milestones": [],
"persons": [],
"title": "斯特兰森亦被杰弗森·霍普所杀，两案为同一凶手（矛盾标记：两种杀人方式）"
}
},
	"CH09E": {
"core": true,
"misleads": [],
"name": "药丸推理",
"practice": false,
"scene": "scene7",
"wall": {
"battlefield": {
"conclusions": [{
"gate_clue_ids": [],
"gate_hypo_ids": ["H7-02", "H7-11"],
"id": "CL7-2",
"text": "药丸一毒一无毒（上帝裁决）"
}],
"contradictions": [{
"correct": true,
"id": "C7-01",
"text": "服毒 vs 刀杀（两种杀人方式）"
}, {
"correct": true,
"id": "C7-02",
"text": "谨慎缜密 vs 留血字RACHE"
}, {
"correct": true,
"id": "C7-03",
"text": "钱袋80镑未失 vs 谋财"
}, {
"correct": true,
"id": "C7-04",
"text": "雷斯垂德找到 vs 找到的是尸体"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_704", "C_SOTCB_710"],
"id": "H7-02",
"text": "药丸一毒一无毒（上帝裁决）"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_704", "C_SOTCB_710"],
"id": "H7-11",
"text": "药丸就是德雷伯中的毒药"
}]
},
"description": "斯特兰森死于利刃（与德雷伯服毒不同手法），但窗户非常规进出、木匣两粒药丸（一毒一无毒的「上帝裁决」）、J.H.电报、送奶工目击（大个子红脸棕外衣）与德雷伯案同源。

活跃假设：
· H7-01 斯特兰森死于刀伤，非服毒（强：致命伤口+无药丸痕迹）
· H7-02 药丸一毒一无毒（上帝裁决）（中强：实验结果+两粒外观一致）
· H7-03 两起案件为同一凶手（强：体貌+红脸+高个+马车夫+血字 RACHE）
· H7-04 凶手=杰弗森·霍普（强：J.H.电报+美国背景+复仇动机+马车夫）

矛盾标记：
· C7-01 事实矛盾：德雷伯服毒 vs 斯特兰森被刀杀（同一凶手，为何两种手法？→ 斯特兰森拒选药丸，被迫动刀）
· C7-02 逻辑矛盾：凶手谨慎缜密 vs 留下血字 RACHE（血字是复仇宣言/仪式，非失误）
· C7-03 证据矛盾：钱袋80镑分文不少 vs 谋财害命（推翻谋财，确认复仇动机）
· C7-04 证据矛盾：雷斯垂德找到斯特兰森 vs 找到的是尸体（方向对但慢一步）",
"milestones": [],
"persons": [],
"title": "斯特兰森亦被杰弗森·霍普所杀，两案为同一凶手（矛盾标记：两种杀人方式）"
}
},
	"CH09F": {
"core": true,
"misleads": [],
"name": "复仇动机",
"practice": false,
"scene": "scene8",
"wall": {
"battlefield": {
"conclusions": [{
"adopt_desc": "自白动机＋戒指归还原主——杰弗森·霍普杀德雷伯，是为露茜·费里尔复仇。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["H8-01", "H8-02"],
"id": "CL8-1",
"kind": "true",
"object": ["复仇", "费里尔"],
"subject": ["霍普"],
"text": "霍普为费里尔父女复仇（动机闭环）"
}, {
"adopt_desc": "同一凶手（两案同一人）、上帝裁决（两案一毒一刀）、复仇动机（露茜·费里尔）——三线闭合，全案真相成立。",
"dir": "affirm",
"gate_clue_ids": [],
"gate_hypo_ids": ["conclusion_CL7-1", "conclusion_CL7-2", "conclusion_CL8-1"],
"id": "CL8-FINAL",
"kind": "true",
"object": ["复仇闭环", "杰弗森·霍普"],
"subject": ["全案"],
"target": "person:NPC_HOPE",
"text": "全案闭环：霍普连杀德雷伯与斯特兰森，为费里尔父女复仇"
}],
"contradictions": [{
"correct": true,
"id": "C8-01",
"text": "老太婆伪装 vs 霍普本人"
}, {
"correct": true,
"id": "C8-02",
"text": "血字RACHE=复仇 vs 误导"
}, {
"correct": true,
"id": "C8-03",
"text": "卡彭蒂耶动机吻合 vs 排除"
}],
"hypotheses": [{
"correct": true,
"gate_clue_ids": ["C_SOTCB_801", "C_SOTCB_802", "C_SOTCB_706"],
"id": "H8-01",
"text": "凶手=杰弗森·霍普"
}, {
"correct": true,
"gate_clue_ids": ["C_SOTCB_804", "C_SOTCB_805", "C_SOTCB_806", "C_SOTCB_807", "c312"],
"id": "H8-02",
"text": "复仇动机（露茜·费里尔）"
}]
},
"description": "霍普自白动机（十八年前费里尔父女被摩门教迫害，立誓复仇）；手背血迹证其到过现场；衣领马虱卵是马车夫职业铁证；戒指归还完成物证闭环；上帝裁决解释两种杀人方式。

活跃假设（全案最终确认）：
· H8-01 凶手=杰弗森·霍普（极强：自白+物证+人证）
· H8-02 复仇动机（露茜·费里尔）（极强：自白+戒指+背景）
· H8-03 凶手是马车夫（强：车轮印+马蹄印+无马鞭+跳上马车+马虱卵）

矛盾解决总览（全案21组矛盾清零）：
· C8-01 老太婆=霍普伪装 vs 霍普本人（已验证：跳上马车+换装+自白）
· C8-02 血字RACHE=复仇宣言 vs 误导警方（实为双重含义，皆成立）
· C8-03 卡彭蒂耶中尉=排除 vs 动机吻合（体貌+不在场证明+尸体无伤三重排除）",
"milestones": [],
"persons": [{
"id": "NPC_HOPE"
}],
"title": "真相闭环：杰弗森·霍普为费里尔父女复仇，连杀德雷伯与斯特兰森"
}
},
}
static func ids() -> Array:
	return CHAINS.keys()

static func has(id: String) -> bool:
	return CHAINS.has(id)

## L3 链聚焦：返回指定链的所有节点 id（hypo + conclusion + person），用于图谱聚焦高亮。
## 返回的 id 是图谱侧使用的形式：hypo 用原名，conclusion 带 "conclusion_" 前缀，person 用人物 id。
static func get_chain_node_ids(chain_id: String) -> Array:
	var ch: Dictionary = CHAINS.get(chain_id, {})
	if ch.is_empty():
		return []
	var bf: Dictionary = ch.get("wall", {}).get("battlefield", {})
	var res: Array = []
	for h in bf.get("hypotheses", []):
		res.append(str(h.get("id", "")))
	for c in bf.get("conclusions", []):
		res.append("conclusion_" + str(c.get("id", "")))
		var tgt: String = str(c.get("target", ""))
		if tgt.begins_with("person:"):
			res.append(tgt.replace("person:", ""))
	for p in ch.get("wall", {}).get("persons", []):
		res.append(str(p.get("id", "")))
	# 去重
	var seen := []
	for id in res:
		if not id in seen and id != "":
			seen.append(id)
	return seen

## 返回 reasoning_wall 需要的完整运行 dict（与 reasoning_hypothesis() 钩子同构）。
## 深拷贝：场景侧可安全改写（如重置 verified）而不污染链库。
static func build_wall_dict(id: String) -> Dictionary:
	var ch: Dictionary = CHAINS.get(id, {})
	if ch.is_empty():
		return {}
	var d: Dictionary = ch["wall"].duplicate(true)
	var ml := Engine.get_main_loop() as SceneTree
	var dm: Node = null if ml == null or ml.root == null else ml.root.get_node_or_null("DifficultyManager")
	if dm != null and dm.mislead_chance <= 0.0:
		var bf: Dictionary = d.get("battlefield", {})
		var kept: Array = []
		for h in bf.get("hypotheses", []):
			if h.get("correct", true):
				kept.append(h)
		bf["hypotheses"] = kept
	return d

## 派生准入：in_truth 显式排除 > kind:"mislead"（误导结论卡）> correct:false（INSUFFICIENT 项）。
static func _entry_in_truth(e: Dictionary) -> bool:
	if not bool(e.get("in_truth", true)):
		return false
	if str(e.get("kind", "true")) == "mislead":
		return false
	return bool(e.get("correct", true))

## 从 wall 数据机械派生真相表（与手写版逐条等价）：
## clue 层 = 入 truth 的 hypotheses/conclusions 的 gate_clue_ids 并集；
## hypo 层 = 准入的 hypotheses；concl 层 = 准入的 conclusions；
## person 层 = conclusions 的 target（仅 wall.persons 非空时派生——案件大墙无人物锚列，
## 强行派生会造出玩家无法建出的真相项，重蹈 CH03 跨场景扣分覆辙）。
## 边：clue→hypo / hypo→hypo（Phase 1：hypotheses 支持 gate_hypo_ids，如 CH09A H5-03→H5-04）/
## hypo→concl / concl→concl / clue→concl（Phase 1：conclusions 支持 gate_clue_ids，如 CH09D C_SOTCB_707→CL7-1）/ concl→person。
## "conclusion_" 前缀引用剥前缀；跨链结论引用（CH09F synthesize）允许，validate 白名单放行。
static func derive_truth(id: String) -> Dictionary:
	var ch: Dictionary = CHAINS.get(id, {})
	if ch.is_empty():
		return {}
	var bf: Dictionary = ch["wall"].get("battlefield", {})
	var has_persons: bool = not ch["wall"].get("persons", []).is_empty()
	var nodes: Array = []
	var seen := {}
	for h in bf.get("hypotheses", []):
		if not _entry_in_truth(h):
			continue
		for c in h.get("gate_clue_ids", []):
			if not seen.has(c):
				seen[c] = true
				nodes.append({"id": c, "layer": "clue"})
	for c in bf.get("conclusions", []):
		if not _entry_in_truth(c):
			continue
		for cl in c.get("gate_clue_ids", []):
			if not seen.has(cl):
				seen[cl] = true
				nodes.append({"id": cl, "layer": "clue"})
	for h in bf.get("hypotheses", []):
		if _entry_in_truth(h) and not seen.has(h["id"]):
			seen[h["id"]] = true
			nodes.append({"id": h["id"], "layer": "hypo"})
	for c in bf.get("conclusions", []):
		if _entry_in_truth(c) and not seen.has(c["id"]):
			seen[c["id"]] = true
			nodes.append({"id": c["id"], "layer": "concl"})
	var edges: Array = []
	for h in bf.get("hypotheses", []):
		if not _entry_in_truth(h):
			continue
		for c in h.get("gate_clue_ids", []):
			edges.append({"from": c, "to": h["id"], "kind": "support"})
		for g in h.get("gate_hypo_ids", []):
			var hg: String = g
			if hg.begins_with("conclusion_"):
				hg = hg.substr("conclusion_".length())
			edges.append({"from": hg, "to": h["id"], "kind": "support"})
	for c in bf.get("conclusions", []):
		if not _entry_in_truth(c):
			continue
		for g in c.get("gate_hypo_ids", []):
			var src: String = g
			if src.begins_with("conclusion_"):
				src = src.substr("conclusion_".length())
			edges.append({"from": src, "to": c["id"], "kind": "support"})
		for cl in c.get("gate_clue_ids", []):
			edges.append({"from": cl, "to": c["id"], "kind": "support"})
		var t: String = c.get("target", "")
		if t != "" and has_persons:
			if t.begins_with("person:") and not seen.has(t):
				seen[t] = true
				nodes.append({"id": t, "layer": "person"})
			edges.append({"from": c["id"], "to": t, "kind": "target"})
	return {
		"id": id, "name": ch.get("name", ""), "scene": ch.get("scene", ""),
		"core": ch.get("core", false), "practice": ch.get("practice", false),
		"nodes": nodes, "edges": edges, "misleads": ch.get("misleads", []),
	}

## 闭合自检：返回错误清单（空数组 = 通过）。建议导出前对全部链跑一遍。
## 校验项：边端点闭合（本链节点 ∪ 全库节点——跨链 synthesize 引用白名单）、
## gate 引用可解析、conclusion_ 前缀指向全库结论、target 为 person: 前缀。
static func validate(id: String) -> Array:
	var errs: Array = []
	var t := derive_truth(id)
	if t.is_empty():
		return ["chain not found: " + id]
	var all_ids := {}
	var all_concls := {}
	for cid in CHAINS:
		var t2: Dictionary = derive_truth(cid)
		for n in t2.get("nodes", []):
			all_ids[n["id"]] = true
			if n["layer"] == "concl":
				all_concls[n["id"]] = true
	var ids := {}
	for n in t["nodes"]:
		ids[n["id"]] = true
	var concl_ids := {}
	for n in t["nodes"]:
		if n["layer"] == "concl":
			concl_ids[n["id"]] = true
	for e in t["edges"]:
		if not ids.has(e["from"]) and not all_ids.has(e["from"]):
			errs.append("%s: edge from 未定义 %s" % [id, e["from"]])
		if not ids.has(e["to"]) and not all_ids.has(e["to"]):
			errs.append("%s: edge to 未定义 %s" % [id, e["to"]])
	var bf: Dictionary = CHAINS[id]["wall"].get("battlefield", {})
	for h in bf.get("hypotheses", []):
		if not _entry_in_truth(h):
			continue
		for c in h.get("gate_clue_ids", []):
			if not ids.has(c):
				errs.append("%s: %s gate 线索未定义 %s" % [id, h["id"], c])
		for g in h.get("gate_hypo_ids", []):
			if g.begins_with("conclusion_"):
				if not all_concls.has(g.substr("conclusion_".length())):
					errs.append("%s: %s 引用结论不存在 %s" % [id, h["id"], g])
			elif not ids.has(g):
				errs.append("%s: %s gate 假设未定义 %s" % [id, h["id"], g])
	for c in bf.get("conclusions", []):
		if not _entry_in_truth(c):
			continue
		for g in c.get("gate_hypo_ids", []):
			if g.begins_with("conclusion_"):
				if not all_concls.has(g.substr("conclusion_".length())):
					errs.append("%s: %s 引用结论不存在 %s" % [id, c["id"], g])
			elif not ids.has(g):
				errs.append("%s: %s gate 假设未定义 %s" % [id, c["id"], g])
		for cl in c.get("gate_clue_ids", []):
			if not ids.has(cl):
				errs.append("%s: %s gate 线索未定义 %s" % [id, c["id"], cl])
		var t3: String = c.get("target", "")
		if t3 != "" and not t3.begins_with("person:"):
			errs.append("%s: %s target 非 person: %s" % [id, c["id"], t3])
	return errs

static func validate_all() -> Array:
	var errs: Array = []
	for id in CHAINS:
		errs.append_array(validate(id))
	return errs
