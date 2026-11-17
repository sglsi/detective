class_name VerdictRules
extends RefCounted

## 星级 / 档位统一事实源（H12 收敛：裁定 3「统一评分源」落地）。
## 权威实现 = 原 WallBranchEvaluator._stars_of / _verdict_of（WBE 注释即裁定 3）。
## 星级阈值取自 CaseBranchTruth.STAR_3/2/1（80/55/25），以 data/ 为唯一阈值来源，
## 消灭 hard_mode_evaluator 里硬编码的双份常量。

const Truth = preload("res://data/case_branch_truth.gd")


## 星级：>=80% →3 / >=55% →2 / >=25% →1 / 否则 0
static func stars_of(ratio: float) -> int:
	if ratio >= Truth.STAR_3:
		return 3
	if ratio >= Truth.STAR_2:
		return 2
	if ratio >= Truth.STAR_1:
		return 1
	return 0


## 四档 verdict：VERIFIED=3 / SUPPORTED=2 / INSUFFICIENT=1 / CONTRADICTORY=0
## 铁律（与三星硬条件一致）：有矛盾(contradicted)或采纳误导项时，最高只能到 SUPPORTED(2)，
## 永不判 VERIFIED(3)；对象未达验证标准故不得判"已证实"。
##   - 有矛盾且 ratio < STAR_1：归 INSUFFICIENT(1)（连基本结构都没有，证据不足）
##   - 有矛盾且 STAR_1 ≤ ratio < STAR_3：CONTRADICTORY(0)
##   - 有矛盾且 ratio ≥ STAR_3：SUPPORTED(2)（方向大致正确但存在硬伤）
##   - 无矛盾：按阈值映射 3 / 2 / 1 / 1（<25% 仍归 INSUFFICIENT 保持四档闭合）
static func verdict_of(ratio: float, contradicted: bool) -> int:
	if contradicted:
		if ratio < Truth.STAR_1:
			return 1  # INSUFFICIENT
		if ratio < Truth.STAR_3:
			return 0  # CONTRADICTORY
		return 2      # SUPPORTED（不判 VERIFIED）
	if ratio >= Truth.STAR_3:
		return 3      # VERIFIED
	if ratio >= Truth.STAR_2:
		return 2      # SUPPORTED
	if ratio >= Truth.STAR_1:
		return 1      # INSUFFICIENT
	return 1          # <25% 仍归 INSUFFICIENT（四档闭合）