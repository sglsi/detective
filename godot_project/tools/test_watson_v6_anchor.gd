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
	# 伸出的右手：画面左侧中上（cx≈0.20, cy≈0.33）
	if float(wrist["cx"]) > 0.35:
		print("FAIL wrist should be on left (outstretched hand)"); ok = false
	if float(wrist["cy"]) < 0.20 or float(wrist["cy"]) > 0.45:
		print("FAIL wrist mid-upper region"); ok = false
	# 左肩（用户裁定沿用旧版锚定 044519a：头下偏右上胸）
	if float(sh["cx"]) < 0.52 or float(sh["cx"]) > 0.68:
		print("FAIL shoulder near upper chest"); ok = false
	if float(sh["cy"]) < 0.15 or float(sh["cy"]) > 0.35:
		print("FAIL shoulder below head"); ok = false
	# 躯干：中央、与头部框不重叠（face 底 0.14 < torso 顶 0.26）
	if float(torso["cy"]) < 0.25 or float(torso["cy"]) > 0.55:
		print("FAIL torso center region"); ok = false
	if float(face["cy"]) + float(face["h"]) * 0.5 > float(torso["cy"]) - float(torso["h"]) * 0.5:
		print("FAIL torso must not overlap face"); ok = false
	# 与手腕框不重叠（wrist 右缘 0.30 < torso 左缘 0.35）
	if float(wrist["cx"]) + float(wrist["w"]) * 0.5 > float(torso["cx"]) - float(torso["w"]) * 0.5:
		print("FAIL torso must not overlap wrist"); ok = false
	if abs(float(pose["w"]) - 1.0) > 0.001 or abs(float(pose["h"]) - 1.0) > 0.001:
		print("FAIL pose full image"); ok = false
	print(("CLUE_ANCHOR_OK" if ok else "CLUE_ANCHOR_FAIL"))
	quit()
