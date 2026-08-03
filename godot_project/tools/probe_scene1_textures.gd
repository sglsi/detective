extends SceneTree

## 运行时探针：实例化 scene1，打印观察器/立绘实际持有的纹理路径。
## 用途：证明游戏运行时到底加载了哪张教学图（排查"图片没换过来"）。
## 用法：godot --headless --script tools/probe_scene1_textures.gd

func _initialize() -> void:
	await create_timer(0.2).timeout

	var ps := load("res://scenes/scene1.tscn") as PackedScene
	if ps == null:
		print("PROBE: scene1.tscn 加载失败")
		quit(); return
	var s := ps.instantiate()
	root.add_child(s)
	await create_timer(0.5).timeout

	print("=== SCENE1 运行时纹理探针 ===")

	for pair in [["华生观察器", "_watson_obs"], ["信使观察器", "_messenger_obs"]]:
		var obs = s.get(pair[1])
		if obs == null:
			print("%s: 未创建" % pair[0]); continue
		var t = obs.get("_portrait_texture")
		var p := "null"
		var sz := "-"
		if t != null:
			p = str(t.resource_path)
			sz = "%dx%d" % [t.get_width(), t.get_height()]
		print("%s: texture=%s  size=%s" % [pair[0], p, sz])

	for pair2 in [["华生立绘", "_portrait_ctrl"], ["信使立绘", "_messenger_portrait_ctrl"]]:
		var ctrl = s.get(pair2[1])
		if ctrl == null:
			print("%s: 未创建" % pair2[0]); continue
		var found := _find_texture_recursive(ctrl)
		print("%s: texture=%s" % [pair2[0], found])

	# 锚点表命中检查
	var ClueImageAnchors = load("res://data/clue_image_anchors.gd")
	for spec in [["res://assets/characters/watson/watson_teaching.png", ["wrist","shoulder","face","pose"]],
				 ["res://assets/characters/messenger/messenger_spritesheet.png", ["tattoo","beard","posture","manner","sleeve","limp"]]]:
		var img: String = spec[0]
		var ids: Array = spec[1]
		var hit := 0
		for i in ids:
			if not ClueImageAnchors.get_anchor(img, str(i)).is_empty(): hit += 1
		print("锚点命中 %s : %d/%d" % [img.get_file(), hit, ids.size()])

	# —— 一致性检查：观察器实际热点 id 是否都能在锚点表命中 ——
	var all_ok := true
	for pair3 in [["华生", "_watson_obs", "res://assets/characters/watson/watson_teaching.png"],
				  ["信使", "_messenger_obs", "res://assets/characters/messenger/messenger_spritesheet.png"]]:
		var obs2 = s.get(pair3[1])
		if obs2 == null: continue
		var hs: Array = obs2.get("_hotspots")
		var miss: Array = []
		for h in hs:
			var hid := str(h.get("id",""))
			if ClueImageAnchors.get_anchor(str(pair3[2]), hid).is_empty():
				miss.append(hid)
		if miss.is_empty():
			print("%s 热点id↔锚点表: 全部命中 (%d 个)" % [pair3[0], hs.size()])
		else:
			print("%s 热点id↔锚点表: 缺失 %s" % [pair3[0], str(miss)]); all_ok = false

	# 场景目录 id 与观察器 id 是否一致（防 arm/shoulder 这类错位）
	var cat_ids: Array = []
	for h2 in s._all_hotspots(): cat_ids.append(str(h2.get("id","")))
	var obs_ids: Array = []
	for pn in ["_watson_obs","_messenger_obs"]:
		var o = s.get(pn)
		if o == null: continue
		for h3 in o.get("_hotspots"): obs_ids.append(str(h3.get("id","")))
	var orphan: Array = []
	for cid in cat_ids:
		if not (cid in obs_ids): orphan.append(cid)
	if orphan.is_empty():
		print("场景目录id↔观察器id: 一致 (%d 个)" % cat_ids.size())
	else:
		print("场景目录id↔观察器id: 悬空 %s" % str(orphan)); all_ok = false

	print("PROBE_RESULT: %s" % ("PASS" if all_ok else "FAIL"))
	print("=== 探针结束 ===")
	quit()

func _find_texture_recursive(n: Node) -> String:
	if n is TextureRect and n.texture != null:
		return str(n.texture.resource_path)
	if n is Sprite2D and n.texture != null:
		return str(n.texture.resource_path)
	for c in n.get_children():
		var r := _find_texture_recursive(c)
		if r != "": return r
	return ""
