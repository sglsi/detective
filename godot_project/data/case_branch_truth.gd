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
##   - **core 链（破案必经，10 条）**：未激活按 R=0 计入分母——否则玩家只需把最短
##     一条链做满即可三星（洞1）。
##   - **optional 链（6 条）**：激活才计分，做砸不拖分——保住「错误无惩罚」。
##   - **节点文本真源**：场景一教学墙由链库 battlefield 提供；场景二~八的墙 UI 仍由
##     各 sceneN.gd 的 reasoning_hypothesis() 提供（CaseReasoningRegistry 聚合），
##     与链库条目同源同构。Phase 1 已把 CH09F 的 CL8-1/CL8-FINAL 落进 scene8 钩子。
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


## 全部 16 条推理链真相。返回深拷贝，避免调用方污染。
## Phase 1（2026-10-30）完成后单一事实源 = data/reasoning_chains.gd 链库：
## 真相表由链库 battlefield gate 机械派生（ReasoningChains.derive_truth），
## 改链只改链库文件；本表退化为薄封装（含顺序、星级阈值、练习墙常量）。
## 返回顺序 = 链库 CHAINS 声明顺序（CH01W..CH09F，与原手工表一致）。
## 原手工真相表已删，快照存档于 tools/phase1_legacy_snapshot.json（回归锚，见 t_phase1_equivalence.gd）。
static func branches() -> Array:
	var out: Array = []
	for id in ReasoningChains.CHAINS:
		out.append(ReasoningChains.derive_truth(id))
	return out
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
