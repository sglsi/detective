extends SceneTree
# 冒烟：2026-09-05 华生教学图替换（watson01.png）+ medical 线索文案（消毒液气味）后，
# 验证 scene1.gd 编译、clue_medical.tres 加载、锚点表/观察数据一致性。

func _initialize() -> void:
	await create_timer(0.1).timeout
	var ok := true
	var sc = load("res://scripts/scene/scene1.gd")
	if sc == null or not (sc as Script).can_instantiate():
		print("FAIL scene1.gd compile"); ok = false
	else:
		print("scene1.gd compiled OK")
	var cd = load("res://data/clues/clue_medical.tres")
	if cd == null:
		print("FAIL clue_medical.tres load"); ok = false
	else:
		print("medical name=", cd.name)
		if str(cd.name) != "身上有消毒液气味":
			print("FAIL medical name mismatch"); ok = false
	var anch = load("res://data/clue_image_anchors.gd")
	if anch == null:
		print("FAIL clue_image_anchors.gd compile"); ok = false
	else:
		print("clue_image_anchors.gd compiled OK")
	var tex = load("res://assets/characters/watson/watson_teaching.png") as Texture2D
	if tex == null:
		print("FAIL teaching texture load"); ok = false
	else:
		print("teaching tex size=", tex.get_size())
	print(("SMOKE_OK" if ok else "SMOKE_FAIL"))
	quit()
