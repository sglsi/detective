## 案件推理链（分枝）真相登记表
## 用途：为「推理墙分枝计分」提供**唯一的真相源**。设计依据见
##   《设计文档/L2_详细设计/系统设计/10_推理墙分枝计分_设计补充说明.md》
##
## 背景（为什么需要本表）：
##   原评价体系只看「有没有连边」——只要玩家建了任意关系，推理之星就给高分，
##   导致「乱选也能拿好评」。本表把设计文档 02 §16 / 附录 B 的 14 条推理链
##   落成**可逐项比对的真相数据**（节点 + 边 + 误导项），让评分不再数边，而是
##   「按分枝整体逐项比对」。
##
## 设计要点：
##   - **分枝 = 推理链**：不新造概念，直接用设计文档 §7.2.2 / 附录 B 的 14 条推理链
##     （#6 已与 #3 合并故跳过编号，共 14 条）。
##   - **core 链（破案必经，8 条）**：未激活按 R=0 计入分母——否则玩家只需把最短
##     一条链做满即可三星（洞1）。
##   - **optional 链（6 条）**：激活才计分，做砸不拖分——保住「错误无惩罚」。
##   - **只引 id，不重复录文本**：节点文本仍由各 sceneN.gd 的 reasoning_hypothesis()
##     提供（沿用 CaseReasoningRegistry 的聚合机制），避免两处维护漂移。
##     本表中尚未在 sceneN.gd 落地的 id 属「预留」，引擎查不到时按「未建」处理，安全。
##   - **layer 用于展示与诊断**：clue(线索) / hypo(推断) / concl(结论) / person(人物)。
##   - **边 kind**：support=肯定推导，oppose=否定/排除。玩家建的虚线(dashed)边不参与计分。
##   - **misleads.expect**："negate" 表示玩家应否定它。玩家对它建 support 边（=采纳）
##     → 该项 0 分，且**三星硬条件直接失败**（洞2）。
##
## 结论节点 id 归一化：画布上结论节点 id 形如 "conclusion_CL3-1"，
## 本表统一写裸 id "CL3-1"，由 WallBranchEvaluator._norm() 双向归一化。
class_name CaseBranchTruth
extends RefCounted

## 星级阈值（思傅 2026-09-02 裁定：80 / 55 / 25）
const STAR_3 := 0.80
const STAR_2 := 0.55
const STAR_1 := 0.25

## 练习墙（场景一华生墙/信使墙）不计分——裁定 5
const PRACTICE_SCENES := ["scene1"]


## 全部 14 条推理链真相。返回深拷贝，避免调用方污染。
static func branches() -> Array:
	return [
		# ───────────────────────── 场景一 · 练习墙（不计分） ─────────────────────────
		{
			"id": "CH01W", "name": "华生教学（练习）", "scene": "scene1", "core": false, "practice": true,
			"nodes": [
				{"id": "wrist", "layer": "clue"}, {"id": "face_dark", "layer": "clue"},
				{"id": "pose", "layer": "clue"}, {"id": "medical", "layer": "clue"},
				{"id": "face_haggard", "layer": "clue"}, {"id": "arm", "layer": "clue"},
				{"id": "W-A1", "layer": "hypo"}, {"id": "W-B1", "layer": "hypo"},
				{"id": "W-C1", "layer": "hypo"}, {"id": "W-C2", "layer": "hypo"},
				{"id": "W-C3", "layer": "hypo"},
				{"id": "C-A1", "layer": "concl"}, {"id": "C-C1", "layer": "concl"},
				{"id": "C-MAIN", "layer": "concl"},
				{"id": "person:NPC_WT", "layer": "person"},
			],
			"edges": [
				{"from": "wrist", "to": "W-A1", "kind": "support"},
				{"from": "face_dark", "to": "W-A1", "kind": "support"},
				{"from": "pose", "to": "W-B1", "kind": "support"},
				{"from": "medical", "to": "W-B1", "kind": "support"},
				{"from": "face_haggard", "to": "W-C1", "kind": "support"},
				{"from": "arm", "to": "W-C2", "kind": "support"},
				{"from": "W-C1", "to": "W-C3", "kind": "support"},
				{"from": "W-C2", "to": "W-C3", "kind": "support"},
				{"from": "W-A1", "to": "C-A1", "kind": "support"},
				{"from": "W-C3", "to": "C-C1", "kind": "support"},
				{"from": "W-A1", "to": "C-MAIN", "kind": "support"},
				{"from": "W-B1", "to": "C-MAIN", "kind": "support"},
				{"from": "W-C3", "to": "C-MAIN", "kind": "support"},
				{"from": "C-MAIN", "to": "person:NPC_WT", "kind": "support"},
			],
			"misleads": [],
		},
		{
			"id": "CH01M", "name": "信使判定（练习）", "scene": "scene1", "core": false, "practice": true,
			"nodes": [
				{"id": "tattoo", "layer": "clue"}, {"id": "beard", "layer": "clue"},
				{"id": "manner", "layer": "clue"}, {"id": "posture", "layer": "clue"},
				{"id": "sleeve", "layer": "clue"}, {"id": "limp", "layer": "clue"},
				{"id": "M-01", "layer": "hypo"},
				{"id": "person:NPC_MSG", "layer": "person"},
			],
			"edges": [
				{"from": "tattoo", "to": "M-01", "kind": "support"},
				{"from": "beard", "to": "M-01", "kind": "support"},
				{"from": "manner", "to": "M-01", "kind": "support"},
				{"from": "posture", "to": "M-01", "kind": "support"},
				{"from": "M-01", "to": "person:NPC_MSG", "kind": "support"},
			],
			# 裁定 5 的示范：干扰项（袖口磨损、轻微跛行）不计入真相边，
			# 玩家给它们建边会变大分母 → 拉低正确率（练习墙不计分，仅用于教学反馈）。
			"misleads": [],
		},

		# ───────────────────────── 场景二 ─────────────────────────
		{
			"id": "CH02", "name": "马车与车夫行踪", "scene": "scene2", "core": true,
			# 台词库§18 推理链#2：出租马车 / 右前蹄铁新换 / 马曾无人看管 → 三线合一「车夫进屋」（假设级）
			"nodes": [
				{"id": "c201", "layer": "clue"}, {"id": "c202", "layer": "clue"},
				{"id": "c203", "layer": "clue"}, {"id": "c204", "layer": "clue"},
				{"id": "H2-01", "layer": "hypo"}, {"id": "H2-02", "layer": "hypo"},
				{"id": "H2-03", "layer": "hypo"},
				{"id": "CL2-1", "layer": "concl"}, {"id": "CL2-2", "layer": "concl"},
				{"id": "CL2-3", "layer": "concl"}, {"id": "CL2-4", "layer": "concl"},
			],
			"edges": [
				{"from": "c201", "to": "H2-01", "kind": "support"},
				{"from": "c202", "to": "H2-01", "kind": "support"},
				{"from": "c203", "to": "H2-02", "kind": "support"},
				{"from": "c204", "to": "H2-03", "kind": "support"},
				{"from": "H2-01", "to": "CL2-1", "kind": "support"},
				{"from": "H2-02", "to": "CL2-2", "kind": "support"},
				{"from": "H2-03", "to": "CL2-3", "kind": "support"},
				{"from": "H2-01", "to": "CL2-4", "kind": "support"},
				{"from": "H2-02", "to": "CL2-4", "kind": "support"},
				{"from": "H2-03", "to": "CL2-4", "kind": "support"},
			],
			"misleads": [
				{"id": "H2-M2", "expect": "negate"},   # 来客徒步踏泥大步进入花园
			],
		},
		{
			"id": "CH03", "name": "来客特征（多场景综合）", "scene": "scene2", "core": true,
			# 台词库§18 推理链#3：夜间来客两人 / 高个约6英尺 / 高个穿方头靴（范围估计，不作定论）
			"nodes": [
				{"id": "c205", "layer": "clue"}, {"id": "c206", "layer": "clue"},
				{"id": "c311", "layer": "clue"},
				{"id": "c309", "layer": "clue"},          # 血字离地6英尺 → 身高精确化锚点
				{"id": "C_SOTCB_402", "layer": "clue"},   # 醉汉身高6英尺+（场景四交叉验证）
				{"id": "H2-04", "layer": "hypo"}, {"id": "H2-05", "layer": "hypo"},
				{"id": "H2-06", "layer": "hypo"}, {"id": "H2-07", "layer": "hypo"},
				{"id": "CL2-5", "layer": "concl"}, {"id": "CL2-6", "layer": "concl"},
			],
			"edges": [
				{"from": "c205", "to": "H2-04", "kind": "support"},
				{"from": "c206", "to": "H2-04", "kind": "support"},
				{"from": "c206", "to": "H2-05", "kind": "support"},
				{"from": "c309", "to": "H2-05", "kind": "support"},
				{"from": "C_SOTCB_402", "to": "H2-05", "kind": "support"},
				{"from": "c205", "to": "H2-06", "kind": "support"},
				{"from": "c311", "to": "H2-06", "kind": "support"},
				{"from": "c206", "to": "H2-07", "kind": "support"},
				{"from": "H2-04", "to": "CL2-5", "kind": "support"},
				{"from": "H2-05", "to": "CL2-6", "kind": "support"},
				{"from": "H2-06", "to": "CL2-6", "kind": "support"},
			],
			"misleads": [
				{"id": "H2-M1", "expect": "negate"},   # 来的是身材矮小的报童
				{"id": "CL2-M1", "expect": "negate"},  # 来客是身材矮小的少年
				{"id": "CL2-2M", "expect": "negate"},  # 来客身材矮小、体格瘦弱
				{"id": "CL2-3M", "expect": "negate"},  # 高个子穿小步漆皮靴
			],
		},

		# ───────────────────────── 场景三 ─────────────────────────
		{
			"id": "CH04", "name": "服毒判定（场景三 A 组·尸体检验）", "scene": "scene3", "core": true,
			# 台词库 §18 A 组：无外伤(A1 VERIFIED) + 恐怖表情/暗紫泡沫(A2 SUPPORTED) + 剧烈挣扎(A5 VERIFIED)
			# → CL3-2 毒杀（四线合一）。A3 心脏病 / A4 被吓死 为 INSUFFICIENT，不入 truth（采纳零分，不封顶）。
			"nodes": [
				{"id": "c301", "layer": "clue"}, {"id": "c302", "layer": "clue"},
				{"id": "c303", "layer": "clue"},
				{"id": "H3-A1", "layer": "hypo"}, {"id": "H3-A2", "layer": "hypo"},
				{"id": "H3-A5", "layer": "hypo"}, {"id": "H3-A6", "layer": "hypo"},
				{"id": "H3-A7", "layer": "hypo"},
				{"id": "CL3-2", "layer": "concl"},
			],
			"edges": [
				{"from": "c301", "to": "H3-A1", "kind": "support"},
				{"from": "c301", "to": "H3-A2", "kind": "support"},
				{"from": "c302", "to": "H3-A1", "kind": "support"},
				{"from": "c302", "to": "H3-A2", "kind": "support"},
				{"from": "c301", "to": "H3-A5", "kind": "support"},
				{"from": "c301", "to": "H3-A6", "kind": "support"},
				{"from": "c303", "to": "H3-A7", "kind": "support"},
				{"from": "H3-A1", "to": "CL3-2", "kind": "support"},
				{"from": "H3-A2", "to": "CL3-2", "kind": "support"},
				{"from": "H3-A5", "to": "CL3-2", "kind": "support"},
			],
			"misleads": [],
		},
		{
			"id": "CH05", "name": "RACHE 血字与现场痕迹（场景三 C 组）", "scene": "scene3", "core": true,
			# 台词库 §18 C 组：血字 RACHE(C1 VERIFIED) + 德语复仇(C2) + 书写者六英尺(C3) + 指甲未修剪(C4)
			# → CL3-3；现场两人(C5) + 方头靴/漆皮靴(C6) + 方头靴者较高(C7) → CL3-4。
			# C10「与女人 RACHEL 有关」为 CONTRADICTORY → misleads（采纳封顶 / 否定命中）。
			"nodes": [
				{"id": "c309", "layer": "clue"}, {"id": "c311", "layer": "clue"},
				{"id": "c301", "layer": "clue"},          # 死者指甲 → 反证血字书写者另有其人
				{"id": "H3-C1", "layer": "hypo"}, {"id": "H3-C2", "layer": "hypo"},
				{"id": "H3-C3", "layer": "hypo"}, {"id": "H3-C4", "layer": "hypo"},
				{"id": "H3-C5", "layer": "hypo"}, {"id": "H3-C6", "layer": "hypo"},
				{"id": "H3-C7", "layer": "hypo"},
				{"id": "CL3-3", "layer": "concl"}, {"id": "CL3-4", "layer": "concl"},
			],
			"edges": [
				{"from": "c309", "to": "H3-C1", "kind": "support"},
				{"from": "c309", "to": "H3-C2", "kind": "support"},
				{"from": "c309", "to": "H3-C3", "kind": "support"},
				{"from": "c309", "to": "H3-C4", "kind": "support"},
				{"from": "c301", "to": "H3-C4", "kind": "support"},
				{"from": "c309", "to": "H3-C7", "kind": "support"},
				{"from": "c311", "to": "H3-C3", "kind": "support"},
				{"from": "c311", "to": "H3-C5", "kind": "support"},
				{"from": "c311", "to": "H3-C6", "kind": "support"},
				{"from": "c311", "to": "H3-C7", "kind": "support"},
				{"from": "H3-C1", "to": "CL3-3", "kind": "support"},
				{"from": "H3-C2", "to": "CL3-3", "kind": "support"},
				{"from": "H3-C3", "to": "CL3-3", "kind": "support"},
				{"from": "H3-C4", "to": "CL3-3", "kind": "support"},
				{"from": "H3-C5", "to": "CL3-4", "kind": "support"},
				{"from": "H3-C6", "to": "CL3-4", "kind": "support"},
				{"from": "H3-C7", "to": "CL3-4", "kind": "support"},
			],
			"misleads": [
				{"id": "H3-C10", "expect": "negate"},   # 与一个叫 RACHEL 的女人有关（雷斯垂德观点）
				{"id": "CL3-M1", "expect": "negate"},   # 同上，结论层
			],
		},
		{
			"id": "CH06", "name": "死者身份与随身物品（场景三 B 组）", "scene": "scene3", "core": true,
			# 注：CH06 为原 14 链编号中跳过的空号，此处补作场景三 B 组专链。
			# 台词库 §18 B 组：德雷伯(B1 VERIFIED) + 克利夫兰(B2 VERIFIED) + 共济会(B3) + 经济良好(B4)
			# + 回纽约(B5) + 斯特兰森是同伴(B6) → CL3-1 / CL3-5。
			# B7 斯特兰森涉案 / B8 与女人有关 / B9 仇杀 为 INSUFFICIENT，不入 truth。
			"nodes": [
				{"id": "c304", "layer": "clue"}, {"id": "c305", "layer": "clue"},
				{"id": "c306", "layer": "clue"}, {"id": "c307", "layer": "clue"},
				{"id": "H3-B1", "layer": "hypo"}, {"id": "H3-B2", "layer": "hypo"},
				{"id": "H3-B3", "layer": "hypo"}, {"id": "H3-B4", "layer": "hypo"},
				{"id": "H3-B5", "layer": "hypo"}, {"id": "H3-B6", "layer": "hypo"},
				{"id": "CL3-1", "layer": "concl"}, {"id": "CL3-5", "layer": "concl"},
			],
			"edges": [
				{"from": "c304", "to": "H3-B1", "kind": "support"},
				{"from": "c304", "to": "H3-B2", "kind": "support"},
				{"from": "c304", "to": "H3-B5", "kind": "support"},
				{"from": "c304", "to": "H3-B6", "kind": "support"},
				{"from": "c306", "to": "H3-B3", "kind": "support"},
				{"from": "c305", "to": "H3-B4", "kind": "support"},
				{"from": "c307", "to": "H3-B6", "kind": "support"},
				{"from": "H3-B1", "to": "CL3-1", "kind": "support"},
				{"from": "H3-B2", "to": "CL3-1", "kind": "support"},
				{"from": "H3-B5", "to": "CL3-5", "kind": "support"},
				{"from": "H3-B6", "to": "CL3-5", "kind": "support"},
			],
			"misleads": [],
		},

		# ───────────────────────── 场景四 ─────────────────────────
		{
			"id": "CH07", "name": "醉汉=凶手", "scene": "scene4", "core": true,
			"nodes": [
				{"id": "C_SOTCB_401", "layer": "clue"}, {"id": "C_SOTCB_402", "layer": "clue"},
				{"id": "C_SOTCB_403", "layer": "clue"}, {"id": "C_SOTCB_404", "layer": "clue"},
				{"id": "C_SOTCB_405", "layer": "clue"},
				{"id": "H4-01", "layer": "hypo"},
				{"id": "CL4-1", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_401", "to": "H4-01", "kind": "support"},
				{"from": "C_SOTCB_402", "to": "H4-01", "kind": "support"},
				{"from": "C_SOTCB_403", "to": "H4-01", "kind": "support"},
				{"from": "C_SOTCB_404", "to": "H4-01", "kind": "support"},
				{"from": "C_SOTCB_405", "to": "H4-01", "kind": "support"},
				{"from": "H4-01", "to": "CL4-1", "kind": "support"},
			],
			"misleads": [],
		},
		{
			"id": "CH08", "name": "凶手回来找戒指", "scene": "scene4", "core": false,
			"nodes": [
				{"id": "c312", "layer": "clue"}, {"id": "c305", "layer": "clue"},
				{"id": "C_SOTCB_401", "layer": "clue"}, {"id": "C_SOTCB_405", "layer": "clue"},
				{"id": "H4-02", "layer": "hypo"},
				{"id": "CL4-2", "layer": "concl"},
			],
			"edges": [
				{"from": "c312", "to": "H4-02", "kind": "support"},
				{"from": "c305", "to": "H4-02", "kind": "support"},
				{"from": "C_SOTCB_401", "to": "H4-02", "kind": "support"},
				{"from": "H4-02", "to": "CL4-2", "kind": "support"},
			],
			"misleads": [],
		},

		# ───────────────────────── 场景五 ─────────────────────────
		{
			"id": "CH09A", "name": "老太婆伪装", "scene": "scene5", "core": false,
			"nodes": [
				{"id": "C_SOTCB_503", "layer": "clue"}, {"id": "C_SOTCB_507", "layer": "clue"},
				{"id": "H5-01", "layer": "hypo"},
				{"id": "CL5-1", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_503", "to": "H5-01", "kind": "support"},
				{"from": "C_SOTCB_507", "to": "H5-01", "kind": "support"},
				{"from": "H5-01", "to": "CL5-1", "kind": "support"},
			],
			"misleads": [],
		},

		# ───────────────────────── 场景六 ─────────────────────────
		{
			"id": "CH09B", "name": "卡彭蒂耶排除", "scene": "scene6", "core": false,
			"nodes": [
				{"id": "C_SOTCB_603", "layer": "clue"}, {"id": "C_SOTCB_605", "layer": "clue"},
				{"id": "C_SOTCB_601", "layer": "clue"}, {"id": "C_SOTCB_602", "layer": "clue"},
				{"id": "H6-01", "layer": "hypo"},
				{"id": "CL6-1", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_603", "to": "H6-01", "kind": "support"},
				{"from": "C_SOTCB_605", "to": "H6-01", "kind": "support"},
				{"from": "H6-01", "to": "CL6-1", "kind": "support"},
			],
			"misleads": [],
		},
		{
			"id": "CH09C", "name": "哈珀证词", "scene": "scene6", "core": false,
			"nodes": [
				{"id": "C_SOTCB_604", "layer": "clue"},
				{"id": "H6-02", "layer": "hypo"},
				{"id": "CL6-2", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_604", "to": "H6-02", "kind": "support"},
				{"from": "H6-02", "to": "CL6-2", "kind": "support"},
			],
			"misleads": [],
		},

		# ───────────────────────── 场景七 ─────────────────────────
		{
			"id": "CH09D", "name": "斯特兰森", "scene": "scene7", "core": true,
			"nodes": [
				{"id": "C_SOTCB_701", "layer": "clue"}, {"id": "C_SOTCB_702", "layer": "clue"},
				{"id": "C_SOTCB_703", "layer": "clue"}, {"id": "C_SOTCB_706", "layer": "clue"},
				{"id": "C_SOTCB_707", "layer": "clue"},
				{"id": "H7-01", "layer": "hypo"}, {"id": "H7-03", "layer": "hypo"},
				{"id": "CL7-1", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_701", "to": "H7-01", "kind": "support"},
				{"from": "C_SOTCB_702", "to": "H7-03", "kind": "support"},
				{"from": "C_SOTCB_703", "to": "H7-03", "kind": "support"},
				{"from": "C_SOTCB_706", "to": "H7-03", "kind": "support"},
				{"from": "C_SOTCB_707", "to": "CL7-1", "kind": "support"},   # 钱袋完好→非谋财
				{"from": "H7-01", "to": "CL7-1", "kind": "support"},
				{"from": "H7-03", "to": "CL7-1", "kind": "support"},
			],
			"misleads": [],
		},
		{
			"id": "CH09E", "name": "药丸推理", "scene": "scene7", "core": true,
			"nodes": [
				{"id": "C_SOTCB_704", "layer": "clue"}, {"id": "C_SOTCB_710", "layer": "clue"},
				{"id": "H7-02", "layer": "hypo"},
				{"id": "CL7-2", "layer": "concl"},
			],
			"edges": [
				{"from": "C_SOTCB_704", "to": "H7-02", "kind": "support"},
				{"from": "C_SOTCB_710", "to": "H7-02", "kind": "support"},
				{"from": "H7-02", "to": "CL7-2", "kind": "support"},
			],
			"misleads": [],
		},

		# ───────────────────────── 场景八 · 含阶段结论 synthesize ─────────────────────────
		{
			"id": "CH09F", "name": "复仇动机", "scene": "scene8", "core": true,
			"nodes": [
				{"id": "C_SOTCB_801", "layer": "clue"}, {"id": "C_SOTCB_802", "layer": "clue"},
				{"id": "C_SOTCB_803", "layer": "clue"}, {"id": "C_SOTCB_804", "layer": "clue"},
				{"id": "C_SOTCB_805", "layer": "clue"}, {"id": "C_SOTCB_806", "layer": "clue"},
				{"id": "C_SOTCB_807", "layer": "clue"},
				{"id": "C_SOTCB_706", "layer": "clue"},   # J.H.现欧洲电报（场景七带入）
				{"id": "c312", "layer": "clue"},          # 戒指 L·F（场景三带入）
				{"id": "H8-01", "layer": "hypo"}, {"id": "H8-02", "layer": "hypo"},
				{"id": "CL8-1", "layer": "concl"},
				# 阶段结论：由前序结论综合再推导（synthesize）——输入边跨结论层
				{"id": "CL8-FINAL", "layer": "concl", "synthesize": true},
				{"id": "person:NPC_HOPE", "layer": "person"},
			],
			"edges": [
				{"from": "C_SOTCB_801", "to": "H8-01", "kind": "support"},
				{"from": "C_SOTCB_802", "to": "H8-01", "kind": "support"},
				{"from": "C_SOTCB_706", "to": "H8-01", "kind": "support"},
				{"from": "C_SOTCB_804", "to": "H8-02", "kind": "support"},
				{"from": "C_SOTCB_805", "to": "H8-02", "kind": "support"},
				{"from": "C_SOTCB_806", "to": "H8-02", "kind": "support"},
				{"from": "C_SOTCB_807", "to": "H8-02", "kind": "support"},
				{"from": "c312", "to": "H8-02", "kind": "support"},
				{"from": "H8-01", "to": "CL8-1", "kind": "support"},
				{"from": "H8-02", "to": "CL8-1", "kind": "support"},
				# 阶段结论：CL7-1(同一凶手) + CL7-2(上帝裁决) + CL8-1(霍普复仇) → 全案闭环
				{"from": "CL7-1", "to": "CL8-FINAL", "kind": "support"},
				{"from": "CL7-2", "to": "CL8-FINAL", "kind": "support"},
				{"from": "CL8-1", "to": "CL8-FINAL", "kind": "support"},
				{"from": "CL8-FINAL", "to": "person:NPC_HOPE", "kind": "support"},
			],
			"misleads": [],
		},
	].duplicate(true)


## 按 id 取单条链（深拷贝）。
static func branch(bid: String) -> Dictionary:
	for b in branches():
		if str(b.get("id", "")) == bid:
			return b
	return {}


## core 链 id 列表（破案必经）。
static func core_ids() -> Array:
	var out: Array = []
	for b in branches():
		if bool(b.get("core", false)):
			out.append(str(b.get("id", "")))
	return out


## 真相项总数（节点 + 边），供诊断/单测使用。
static func truth_size(bid: String) -> int:
	var b := branch(bid)
	if b.is_empty():
		return 0
	return b.get("nodes", []).size() + b.get("edges", []).size()
