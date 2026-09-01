extends SceneTree
# 校验：watson_teaching.png 替换为新立绘后，锚点表 4 锚点几何符合新华生身体部位相对关系
const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

func _initialize() -> void:
	await create_timer(0.1).timeout
	var ok := true
	var base := "res://assets/characters/watson/watson_teaching.png"
	for nm in ["face", "wrist", "shoulder", "pose"]:
		var a := ClueImageAnchors.get_anchor(base, nm)
		if a.is_empty():
			print("FAIL missing anchor ", nm); ok = false; continue
		print(nm, " -> cx=", a["cx"], " cy=", a["cy"], " w=", a["w"], " h=", a["h"])

	var face := ClueImageAnchors.get_anchor(base, "face")
	var wrist := ClueImageAnchors.get_anchor(base, "wrist")
	var sh := ClueImageAnchors.get_anchor(base, "shoulder")
	var pose := ClueImageAnchors.get_anchor(base, "pose")
	# 几何关系检验：头在上部、肩高于手、手在中下部、全身=整图
	if abs(float(face["cx"]) - 0.501) > 0.02 or abs(float(face["cy"]) - 0.146) > 0.05:
		print("FAIL face pos"); ok = false
	if float(sh["cy"]) > float(wrist["cy"]):
		print("FAIL shoulder should be higher than wrist"); ok = false
	if float(wrist["cy"]) < 0.35 or float(wrist["cy"]) > 0.55:
		print("FAIL wrist mid-lower region"); ok = false
	if float(face["cy"]) > 0.25:
		print("FAIL face upper region"); ok = false
	if abs(float(pose["w"]) - 1.0) > 0.001 or abs(float(pose["h"]) - 1.0) > 0.001:
		print("FAIL pose full image"); ok = false
	print(("CLUE_ANCHOR_OK" if ok else "CLUE_ANCHOR_FAIL"))
	quit()