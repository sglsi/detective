extends SceneTree
## H12 · 双评估器 verdict/stars 档位对齐（收为单一事实源 VerdictRules）
## 全遍历：ratio 0.00~1.00 步长 0.01 × contradicted ∈ {false,true}，共 202 组。
## 断言：
##   1) WBE 与 HME 的 _verdict_of / _stars_of 在每一组完全一致
##   2) contradicted=true 时 verdict ∈ {0,1,2}，永不 3（有矛盾不得判 VERIFIED）
##   3) contradicted=false 且 ratio >= 0.80 → verdict == 3

const WBE := preload("res://scripts/clue/wall_branch_evaluator.gd")
const HME := preload("res://scripts/clue/hard_mode_evaluator.gd")

var _ok: int = 0
var _fail: int = 0
var _total: int = 0

func _check(cond: bool, msg: String, actual: Variant, expect: String) -> void:
	_total += 1
	if cond:
		_ok += 1
	else:
		_fail += 1
		print("FAIL | %s | 实际=%s | 预期=%s" % [msg, str(actual), expect])

func _initialize() -> void:
	await process_frame
	for i in range(101):
		var ratio: float = float(i) / 100.0
		for c in [false, true]:
			var wv: int = WBE._verdict_of(ratio, c)
			var hv: int = HME._verdict_of(ratio, c)
			var ws: int = WBE._stars_of(ratio)
			var hs: int = HME._stars_of(ratio)
			var tag := "r=%.2f c=%s" % [ratio, str(c)]
			_check(wv == hv, tag + " verdict WBE==HME", [wv, hv], "一致")
			_check(ws == hs, tag + " stars WBE==HME", [ws, hs], "一致")
			if c:
				_check(wv <= 2, tag + " 有矛盾不判VERIFIED", wv, "≤2 {0,1,2}")
			else:
				if ratio >= 0.80:
					_check(wv == 3, tag + " 无矛盾高分=VERIFIED", wv, "3")
	## H12 收尾 A：HARD 下 grade 与 stars/verdict 同轴（grade 判据 = display_ratio），
	## 内心 band 必须完全一致 —— 若 grade 回落 raw 而 stars 用 display，band 会在此处崩开。
	var band_grade := {3: "优秀", 2: "良好", 1: "合格", 0: "待加强"}
	for i in range(101):
		var x: float = float(i) / 100.0
		var hs2: int = HME._stars_of(x)
		var eg: String = band_grade[hs2]
		var g: String = HME._grade_of(x)
		_check(g == eg, "HME grade band==stars band r=%.2f" % x, g, eg)
	print("总计: %d 通过 / %d 失败 / 共 %d" % [_ok, _fail, _total])
	quit(0 if _fail == 0 else 1)