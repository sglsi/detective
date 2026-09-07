extends SceneTree
# 校验：watson_teaching.png（2026-09-05 换 watson01.png, 640×1663 像素画）后，
# 锚点表 5 锚点几何符合新华生身体部位相对关系：
#   头在顶部中央、伸出的右手在画面左侧、垂下的左臂在画面右侧、躯干在中央、全身=整图。
const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

func _initialize() -> void:
	await create_timer(0.1).timeout
	var ok := true
	var base := "res://assets/characters/watson/watson_teaching.png"
	for nm in ["face", "wrist", "shoulder", "torso", "pose"]:
		var a := ClueImageAnchors.get_anchor(base, nm)
		if a.is_empty():
			print("FAIL missing anchor ", nm); ok = false; continue
		print(nm, " -> cx=", a["cx"], " cy=", a["cy"], " w=", a["w"], " h=", a["h"])

	var face := ClueImageAnchors.get_anchor(base, "face")
	var wrist := ClueImageAnchors.get_anchor(base, "wrist")
	var sh := ClueImageAnchors.get_anchor(base, "shoulder")
	var torso := ClueImageAnchors.get_anchor(base, "torso")
	var pose := ClueImageAnchors.get_anchor(base, "pose")
	# 头部：顶部中央（cy≈0.07）
	if abs(float(face["cx"]) - 0.49) > 0.03 or abs(float(face["cy"]) - 0.07) > 0.05:
		print("FAIL face pos"); ok = false
	if float(face["cy"]) > 0.25:
		print("FAIL face upper region"); ok = false
	# 伸出的右手：画面左侧中上（cx≈0.26, cy≈0.285）
	if float(wrist["cx"]) > 0.35:
		print("FAIL wrist should be on left (outstretched hand)"); ok = false
	if float(wrist["cy"]) < 0.20 or float(wrist["cy"]) > 0.45:
		print("FAIL wrist mid-upper region"); ok = false
	# 指尖右缘 0.427 实测：右缘必须覆盖到 0.44 以上（防指尖再被切）
	if float(wrist["cx"]) + float(wrist["w"]) * 0.5 < 0.44:
		print("FAIL wrist must cover fingertip right edge"); ok = false
	if float(wrist["w"]) < 0.34 or float(wrist["h"]) < 0.26:
		print("FAIL wrist covers hand+forearm"); ok = false
	# 左肩+左上臂（watson03 实测：人物左=画面右侧，肩+上臂为主，不得偏左胸）
	if float(sh["cx"]) < 0.68 or float(sh["cx"]) > 0.80:
		print("FAIL shoulder on left-shoulder zone"); ok = false
	if float(sh["cy"]) < 0.18 or float(sh["cy"]) > 0.34:
		print("FAIL shoulder below head"); ok = false
	# 消毒液视图：腹部以上全部区域（大视图含脸/手是设计使然，检查尺寸而非不重叠）
	if float(torso["cx"]) < 0.45 or float(torso["cx"]) > 0.55:
		print("FAIL torso center x"); ok = false
	if float(torso["cy"]) < 0.25 or float(torso["cy"]) > 0.35:
		print("FAIL torso center y"); ok = false
	if float(torso["w"]) < 0.75 or float(torso["h"]) < 0.55:
		print("FAIL torso covers belly-up area"); ok = false
	# 手腕与左肩视图互不重叠（左右分居）
	if float(wrist["cx"]) + float(wrist["w"]) * 0.5 - (float(sh["cx"]) - float(sh["w"]) * 0.5) > 0.06:
		print("FAIL wrist-shoulder x overlap too wide"); ok = false
	if abs(float(pose["w"]) - 1.0) > 0.001 or abs(float(pose["h"]) - 1.0) > 0.001:
		print("FAIL pose full image"); ok = false
	print(("CLUE_ANCHOR_OK" if ok else "CLUE_ANCHOR_FAIL"))
	quit()
