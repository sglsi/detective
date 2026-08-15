extends SceneTree
## 验证线索放大弹出框的统一改造：
##  1) 场景二型（有锚点 image+anchor）：弹出框含说明文字(RichTextLabel) + 裁切放大图(AtlasTexture)
##  2) 场景三型（仅 image 无 anchor）：弹出框含说明文字 + 整图放大兜底(TextureRect 非 AtlasTexture)
##  3) 说明文字不再写入底部对话框（_text_lbl / _speaker_lbl 保持空）
##
## 统一机制：场景一/二/三 共用 ClueObserver._open_zoom；场景三此前因缺 image/anchor 整图不显示。

var ok := true

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var Gd = load("res://scripts/ui/scene_framework.gd")
	var CO = load("res://scripts/clue/clue_observer.gd")
	var DM = get_root().get_node_or_null("/root/DifficultyManager")
	if DM != null:
		DM.set_difficulty(0)   # EASY，避免 _draw_initial_hints 因 null 报错

	var sf = Gd.new()
	sf.name = "ui"
	root.add_child(sf)
	sf.setup("测试", "TEST", null)
	var world = sf.get_world_layer()
	var woff = sf.get_world_offset()

	# ── 用例 A：场景二型热点（image + anchor 齐全）──
	var hs2 := [
		{"id":"c201","label":"碾轧的花草","x":180.0,"y":800.0,"w":150.0,"h":42.0,
		 "desc":"路边草地被压过了——两道平行的印子，草地上有两道平行的凹痕，像是车轮碾轧留下的。有马车在此停靠过。","tool":"none",
		 "image":"res://assets/scenes/sc_02_garden.png","anchor":"c201"},
	]
	var obs2 = CO.new(); obs2.name = "obs2"; root.add_child(obs2)
	obs2.setup(sf, Label.new(), Label.new(), hs2, null, null, "", world, woff)
	obs2.show()
	obs2._btns[0].emit_signal("pressed")
	await create_timer(0.02).timeout
	_check_popup(obs2, "路边草地被压过了", true, "A(场景二·裁切)", "c201")
	obs2.hide()
	obs2.queue_free()

	# ── 用例 B：场景三型热点（仅 image，无 anchor）──
	var hs3 := [
		{"id":"c301","label":"尸体·面部与姿态","x":840.0,"y":410.0,"w":220.0,"h":46.0,
		 "desc":"死者约四十三四岁，中等身材，宽宽的肩膀，黑色鬈发，短硬的胡子。僵硬的脸上露出恐怖、忿恨的表情。","tool":"放大镜",
		 "image":"res://assets/scenes/sc_03_indoor_hd.jpg"},
	]
	var obs3 = CO.new(); obs3.name = "obs3"; root.add_child(obs3)
	obs3.setup(sf, Label.new(), Label.new(), hs3, null, null, "", world, woff)
	obs3.show()
	obs3._btns[0].emit_signal("pressed")
	await create_timer(0.02).timeout
	_check_popup(obs3, "死者约四十三四岁", false, "B(场景三·整图兜底)", "c301")
	obs3.hide()
	obs3.queue_free()

	sf.queue_free()
	print("[POPUP]", "PASS ✅" if ok else "FAIL ❌")
	quit()

func _check_popup(obs, desc_sub: String, expect_crop: bool, tag: String, cid: String) -> void:
	var popup = obs._zoom_popup
	if popup == null:
		print("  [%s] FAIL 弹出框未创建" % tag); ok = false; return
	var rl = _find_first(popup, "RichTextLabel")
	var tr = _find_first(popup, "TextureRect")
	if rl == null:
		print("  [%s] FAIL 弹出框缺少说明文字(RichTextLabel)" % tag); ok = false; return
	if desc_sub not in rl.text:
		print("  [%s] FAIL 说明文字未含 '%s' (text=%s)" % [tag, desc_sub, rl.text.substr(0, 20)]); ok = false
	else:
		print("  [%s] OK 说明文字含 '%s'" % [tag, desc_sub])
	if tr == null:
		print("  [%s] FAIL 弹出框缺少放大图(TextureRect)" % tag); ok = false
	elif tr.texture == null:
		print("  [%s] FAIL 放大图 texture 为空" % tag); ok = false
	else:
		var is_atlas = tr.texture is AtlasTexture
		if expect_crop and not is_atlas:
			print("  [%s] WARN 期望裁切(AtlasTexture)但得到整图" % tag)
		if not expect_crop and is_atlas:
			print("  [%s] FAIL 场景三应整图兜底但却是 AtlasTexture 裁切" % tag); ok = false
		else:
			print("  [%s] OK 放大图 texture=%s" % [tag, "AtlasTexture(裁切)" if is_atlas else "整图"])
	var tl = obs._text_lbl
	if tl != null and desc_sub in str(tl.text):
		print("  [%s] FAIL 说明文字泄露到底部对话框(_text_lbl)" % tag); ok = false
	else:
		print("  [%s] OK 底部对话框未写入说明" % tag)
	print("    [%s] _zoomed=%s" % [tag, obs._zoomed])

## 递归查找首个指定类名的子孙节点（RichTextLabel / TextureRect 可能嵌套在 Panel 内）
func _find_first(node: Node, type_name: String) -> Node:
	for ch in node.get_children():
		if ch.get_class() == type_name:
			return ch
		var deep = _find_first(ch, type_name)
		if deep != null:
			return deep
	return null
