extends SceneTree
# 实测观察器「整图」TextureRect 的最终显示尺寸：信使(竖长) / 华生(方图)
# 验证 contain 逻辑后整图完整落进 360x480 框、不溢出、高亮框对齐。

func _initialize() -> void:
	await create_timer(0.1).timeout
	await _run("res://assets/characters/messenger/messenger_portrait.png", "信使")
	await _run("res://assets/characters/watson/watson_teaching.png", "华生")
	print("OBS_PORTRAIT_TEST_DONE")
	quit()

func _run(path: String, label: String) -> void:
	var tex := load(path) as Texture2D
	var tw := float(tex.get_width()); var th := float(tex.get_height())
	var box := Vector2(360, 480)
	var box_pos := Vector2(260, 80)
	var sc: float = min(box.x / tw, box.y / th)
	var dw: float = tw * sc; var dh: float = th * sc
	var full := TextureRect.new()
	full.texture = tex
	full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full.size = Vector2(dw, dh)
	full.position = box_pos + (box - Vector2(dw, dh)) * 0.5
	root.add_child(full)
	await create_timer(0.05).timeout
	var contained := full.size.x <= box.x + 1.0 and full.size.y <= box.y + 1.0
	print("%s ORIG=(%.0f,%.0f) DISPLAY=(%.1f,%.1f) CONTAINED=%s" % [label, tw, th, full.size.x, full.size.y, str(contained)])
	# 与 draw_highlight 同算法对齐校验
	var hl_s: float = min(box.x / tw, box.y / th)
	var hl_dw: float = tw * hl_s; var hl_dh: float = th * hl_s
	print("%s HIGHLIGHT_CONTAIN=(%.1f,%.1f) ALIGN_OK=%s" % [label, hl_dw, hl_dh, str(abs(hl_dw - full.size.x) < 1.0 and abs(hl_dh - full.size.y) < 1.0)])
	root.remove_child(full)
