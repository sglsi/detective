extends SceneTree
## headless 自检：确认 _make_portrait 创建的立绘 TextureRect 使用
## EXPAND_FIT_WIDTH_PROPORTIONAL（按宽等比缩放、完整放进 size 框），
## 而非 IGNORE_SIZE（按原始像素尺寸渲染 -> 信使巨大只露头）。
func _initialize() -> void:
	await create_timer(0.1).timeout
	var fw = load("res://scripts/ui/scene_framework.gd").new()
	var tex = load("res://assets/characters/messenger/messenger_portrait.png")
	var ctrl = fw._make_portrait(tex, "信使", Vector2(560, 343), Vector2(150, 447), false)
	var img = ctrl.get_node("img")
	var w := int(150 - 12)
	var h := int(round(float(w) / (float(tex.get_size().x) / float(tex.get_size().y))))
	print("TEXTURE_ORIG=%s" % str(tex.get_size()))
	print("EXPAND_MODE=%d (1=FIT_WIDTH_PROPORTIONAL, 0=IGNORE_SIZE)" % img.expand_mode)
	print("DISPLAY_W=%d DISPLAY_H=%d (框 150x447)" % [w, h])
	if img.expand_mode == TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL:
		print("PORTRAIT_EXPAND_OK")
	else:
		print("PORTRAIT_EXPAND_FAIL")
	quit()
