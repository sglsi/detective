extends SceneTree

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
const ClueObserverCls = preload("res://scripts/clue/clue_observer.gd")

func _initialize() -> void:
	await create_timer(0.2).timeout
	var ok := true

	# 1) 锚点表可取
	var a := ClueImageAnchors.get_anchor("res://assets/characters/watson/watson_teaching.png", "wrist")
	if a.is_empty() or abs(float(a["cx"]) - 0.385) > 0.001:
		print("FAIL anchor get_anchor"); ok = false
	# 新线索：肩部（左肩）
	var sh := ClueImageAnchors.get_anchor("res://assets/characters/watson/watson_teaching.png", "shoulder")
	if sh.is_empty() or abs(float(sh["cx"]) - 0.594) > 0.001:
		print("FAIL shoulder anchor"); ok = false

	# 2) crop -> anchor 转换
	var c := ClueImageAnchors.crop_to_anchor({"x":0.1,"y":0.55,"cx":0.42,"cy":0.85})
	if abs(float(c["cx"]) - 0.26) > 0.001 or abs(float(c["w"]) - 0.32) > 0.001:
		print("FAIL crop_to_anchor cx/w"); ok = false

	# 3) ClueObserver 放大 + 绘制矩形
	var ctrl := Control.new()
	root.add_child(ctrl)
	var tex := load("res://assets/characters/watson/watson_teaching.png") as Texture2D
	var obs := ClueObserverCls.new()
	obs.setup(ctrl, null, null, [{"id":"wrist","label":"手腕","x":0,"y":0,"w":10,"h":10,"desc":"d"}], tex)
	ctrl.add_child(obs)
	await create_timer(0.1).timeout

	var zoom := obs._make_zoom(tex, a, 1.0)
	if not (zoom is AtlasTexture) or zoom.region.size.x <= 0:
		print("FAIL _make_zoom region"); ok = false
	var dr := obs._drawn_rect(Vector2(220, 80), Vector2(440, 600), tex)
	if dr.size.x <= 0 or dr.size.y <= 0:
		print("FAIL _drawn_rect"); ok = false

	# 4) 实际弹出观察层：必须生成 上下文图 / 锚点标记 / 放大图
	obs._show_observation_layer("wrist", "desc test")
	await create_timer(0.1).timeout
	if ctrl.find_child("obs_img", true, false) == null: print("FAIL no obs_img"); ok = false
	if ctrl.find_child("obs_marker", true, false) == null: print("FAIL no obs_marker"); ok = false
	if ctrl.find_child("obs_zoom", true, false) == null: print("FAIL no obs_zoom"); ok = false
	obs._clear_observation_layer()

	# 5) 信使文身锚点也应可取
	var mt := ClueImageAnchors.get_anchor("res://assets/characters/messenger/messenger_spritesheet.png", "tattoo")
	if mt.is_empty(): print("FAIL messenger tattoo anchor"); ok = false

	# 5b) 华生 + 信使教学流程全部锚点：放大区必须【严格等于校准框】且合法
	#     防回归历史 bug：factor=2.4 会把校准框稀释到只占放大图 17.4%，
	#     且 w/h=1.0 的全图锚点会算出负起点导致 AtlasTexture 采样异常。
	var teach_sets := {
		"res://assets/characters/watson/watson_teaching.png": ["wrist","shoulder","face","pose"],
		"res://assets/characters/messenger/messenger_spritesheet.png": ["tattoo","beard","posture","manner","sleeve","limp"],
	}
	for img_path in teach_sets.keys():
		var t2 := load(img_path) as Texture2D
		if t2 == null:
			print("FAIL teaching texture missing: ", img_path); ok = false; continue
		var tw := float(t2.get_width())
		var th := float(t2.get_height())
		for cid in teach_sets[img_path]:
			var ma := ClueImageAnchors.get_anchor(img_path, cid)
			if ma.is_empty():
				print("FAIL anchor missing: ", img_path, " ", cid); ok = false; continue
			var mz := obs._make_zoom(t2, ma, 1.0)
			if not (mz is AtlasTexture):
				print("FAIL zoom not atlas: ", cid); ok = false; continue
			var r: Rect2 = mz.region
			# a) 起点非负
			if r.position.x < -0.01 or r.position.y < -0.01:
				print("FAIL zoom negative origin: ", cid, " ", r); ok = false
			# b) 不越界
			if r.position.x + r.size.x > tw + 0.5 or r.position.y + r.size.y > th + 0.5:
				print("FAIL zoom out of bounds: ", cid, " ", r); ok = false
			# c) 尺寸严格等于校准框（误差 < 1px）——所见即所校准
			var want_w: float = float(ma["w"]) * tw
			var want_h: float = float(ma["h"]) * th
			if abs(r.size.x - want_w) > 1.0 or abs(r.size.y - want_h) > 1.0:
				print("FAIL zoom size != calibrated box: ", cid,
					" got=", r.size, " want=", Vector2(want_w, want_h)); ok = false

	print("CLUE_ANCHOR_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
