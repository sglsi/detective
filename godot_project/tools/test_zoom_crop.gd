extends SceneTree
## 验证 _open_zoom 的图片裁切：地点类（场景二/三）做上下文放大裁切、角色立绘（场景一）保持原裁切；
## 并确认场景三靠「线索 id 兜底」能取到锚点。仅做数据校验，不依赖渲染像素（不预加载 ClueObserver，
## 避免 --script 模式下 autoload 未加载导致的编译失败）。裁切数学与 clue_observer.gd._zoom_crop_region 保持一致。

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

func _zoom_crop_region(img_path: String, a: Dictionary) -> Rect2:
	var tex: Texture2D = load(img_path)
	if tex == null:
		return Rect2()
	var tw := float(tex.get_width()); var th := float(tex.get_height())
	var acx := float(a["cx"]); var acy := float(a["cy"])
	var aw := float(a["w"]); var ah := float(a["h"])
	var half: float = max(aw, ah) * 1.7
	half = max(half, 0.18)
	var x0: float = clampf(acx - half, 0.0, 1.0)
	var y0: float = clampf(acy - half, 0.0, 1.0)
	var x1: float = clampf(acx + half, 0.0, 1.0)
	var y1: float = clampf(acy + half, 0.0, 1.0)
	return Rect2(x0 * tw, y0 * th, (x1 - x0) * tw, (y1 - y0) * th)

func _init() -> void:
	var all_ok := true
	var cases := [
		{"name":"场景二 c201(地点·车轮印)", "img":"res://assets/scenes/sc_02_garden.png", "anchor":"c201", "loc":true, "id":"c201"},
		{"name":"场景二 c206(地点·右边缘)", "img":"res://assets/scenes/sc_02_garden.png", "anchor":"c206", "loc":true, "id":"c206"},
		{"name":"场景三 c301(地点·面部·id兜底)", "img":"res://assets/scenes/sc_03_indoor_hd.jpg", "anchor":"", "loc":true, "id":"c301"},
		{"name":"场景三 c309(地点·血字·右边缘)", "img":"res://assets/scenes/sc_03_indoor_hd.jpg", "anchor":"c309", "loc":true, "id":"c309"},
		{"name":"场景一 face(角色·不扩张)", "img":"res://assets/characters/watson/watson_teaching.png", "anchor":"face", "loc":false, "id":"face"},
	]
	for c in cases:
		var img_path: String = c["img"]
		var anchor_name: String = c["anchor"]
		if anchor_name == "":
			anchor_name = c["id"]   # 模拟 _open_zoom 的兜底
		var a: Dictionary = ClueImageAnchors.get_anchor(img_path, anchor_name)
		if a.is_empty():
			print("FAIL %s: 锚点未找到 (anchor=%s)" % [c["name"], anchor_name]); all_ok = false; continue
		var tex: Texture2D = load(img_path)
		if tex == null:
			print("FAIL %s: 图片加载失败 %s" % [c["name"], img_path]); all_ok = false; continue
		var tw := float(tex.get_width()); var th := float(tex.get_height())
		var region: Rect2
		if c["loc"]:
			region = _zoom_crop_region(img_path, a)
		else:
			region = Rect2((float(a["cx"]) - float(a["w"])/2.0)*tw, (float(a["cy"]) - float(a["h"])/2.0)*th, float(a["w"])*tw, float(a["h"])*th)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region
		var ok := at.get_width() > 0 and at.get_height() > 0
		var in_bounds := region.position.x >= -1 and region.position.y >= -1 and (region.position.x + region.size.x) <= tw + 1 and (region.position.y + region.size.y) <= th + 1
		print("%s: anchor=%s region=%s atlas=%sx%s in_bounds=%s %s" % [
			c["name"], anchor_name, region, at.get_width(), at.get_height(), in_bounds, "OK" if (ok and in_bounds) else "FAIL"])
		if not (ok and in_bounds):
			all_ok = false
	var s3 := "res://assets/scenes/sc_03_indoor_hd.jpg"
	var ids := ["c301","c302","c303","c304","c305","c306","c307","c308","c309","c310","c311","c312","d1_top"]
	var missing := []
	for id in ids:
		if ClueImageAnchors.get_anchor(s3, id).is_empty():
			missing.append(id)
	if missing.is_empty():
		print("场景三 13 锚点齐全 OK")
	else:
		print("FAIL 场景三 缺锚点: %s" % missing); all_ok = false
	print("RESULT: %s" % ("ALL_OK" if all_ok else "HAS_FAIL"))
	quit(0 if all_ok else 1)
