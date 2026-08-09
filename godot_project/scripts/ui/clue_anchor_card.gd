extends Control
class_name ClueAnchorCard

## 线索锚点卡片 —— 把「一条线索」牢牢绑在「剧情中某人物/物品/景致的指定部位」上。
##
## 渲染内容（同卡一体，关联一目了然）：
##   - 左侧：该部位的放大裁剪图（按锚点在原图上的区域裁出），外加金框高亮；
##   - 右侧：线索标题 + 描述文字。
## 这样玩家看到的不是「在人物旁边飘几个字」，而是「华生的手腕 → 这条线索」。
##
## 锚点坐标唯一真相源：data/clue_image_anchors.gd
##   cx,cy = 部位中心（0~1，左上原点）；w,h = 框尺寸占比（0~1）。
##
## 健壮性：image/anchor 缺失或图片不存在时，自动退化为纯文字卡片（绝不报错/崩溃），
## 因此场景二~八（无锚点）直接复用本卡也不会坏。

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

## 实例方法：在已 new 的卡片上构建内容（card_w/card_h 为卡片整体尺寸）。
## 调用方：var card = ClueAnchorCard.new(); card.setup_card(img, anchor, title, desc, w, h)
func setup_card(image_path: String, anchor_name: String, title: String, desc: String,
				card_w: float = 600.0, card_h: float = 220.0) -> void:
	custom_minimum_size = Vector2(card_w, card_h)
	size = Vector2(card_w, card_h)
	_build(image_path, anchor_name, title, desc)

## 在整图(img_pos/img_size 指定绘制矩形、tex 为原图)上按锚点画金框 + 部位标签。
## 供观察层「整图 + 高亮部位」使用（与卡片内的放大裁剪互补）。
static func draw_highlight(parent: CanvasItem, img_pos: Vector2, img_size: Vector2,
						   tex: Texture2D, anchor: Dictionary, label: String) -> void:
	if tex == null or anchor.is_empty(): return
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var s: float = min(img_size.x / tw, img_size.y / th)
	var dw: float = tw * s
	var dh: float = th * s
	var dr_x: float = img_pos.x + (img_size.x - dw) / 2.0
	var dr_y: float = img_pos.y + (img_size.y - dh) / 2.0
	var cx: float = dr_x + float(anchor["cx"]) * dw
	var cy: float = dr_y + float(anchor["cy"]) * dh
	var bw: float = float(anchor["w"]) * dw
	var bh: float = float(anchor["h"]) * dh
	var hr := ColorRect.new()
	hr.color = Color(0, 0, 0, 0)
	var hs := StyleBoxFlat.new()
	hs.border_color = Color(0.95, 0.80, 0.35, 1)
	hs.border_width_left = 3; hs.border_width_right = 3
	hs.border_width_top = 3; hs.border_width_bottom = 3
	hs.set_corner_radius_all(6)
	hr.add_theme_stylebox_override("panel", hs)
	hr.name = "ClueAnchorHL"
	hr.position = Vector2(cx - bw / 2.0, cy - bh / 2.0)
	hr.size = Vector2(bw, bh)
	parent.add_child(hr)
	var lab := Label.new()
	lab.text = "📍 " + label
	lab.name = "ClueAnchorHL_lab"
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.98, 0.88, 0.5))
	lab.position = Vector2(cx - bw / 2.0, cy - bh / 2.0 - 26)
	lab.size = Vector2(max(bw, 200), 24)
	parent.add_child(lab)

func _build(image_path: String, anchor_name: String, title: String, desc: String) -> void:
	# 卡片底
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.04, 0.95)
	sb.border_color = Color(0.78, 0.62, 0.28, 0.9)
	sb.border_width_left = 2; sb.border_width_right = 2; sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var tex: Texture2D = null
	if image_path != "" and ResourceLoader.exists(image_path):
		tex = load(image_path)
	var anchor: Dictionary = {}
	if tex != null and anchor_name != "":
		anchor = ClueImageAnchors.get_anchor(image_path, anchor_name)

	if tex != null and not anchor.is_empty():
		# —— 有锚点：左图（部位裁剪放大 + 金框），右文 ——
		var tw := float(tex.get_width()); var th := float(tex.get_height())
		var rx := (float(anchor["cx"]) - float(anchor["w"]) / 2.0) * tw
		var ry := (float(anchor["cy"]) - float(anchor["h"]) / 2.0) * th
		var rw := float(anchor["w"]) * tw
		var rh := float(anchor["h"]) * th
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(rx, ry, rw, rh)
		var pad: float = 16.0
		var side: float = min(size.y - pad * 2.0, 190.0)
		var img := TextureRect.new()
		img.texture = at
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.position = Vector2(pad, (size.y - side) / 2.0)
		img.size = Vector2(side, side)
		# 金框（比图大 6px 包住）
		var frame := Panel.new()
		frame.position = img.position - Vector2(3, 3)
		frame.size = img.size + Vector2(6, 6)
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0, 0, 0, 0)
		fsb.border_color = Color(0.95, 0.80, 0.35, 1)
		fsb.border_width_left = 3; fsb.border_width_right = 3; fsb.border_width_top = 3; fsb.border_width_bottom = 3
		fsb.set_corner_radius_all(6)
		frame.add_theme_stylebox_override("panel", fsb)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame); add_child(img)
		# 部位标签
		var lab := Label.new()
		lab.text = "📍 " + anchor_name
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))
		lab.position = Vector2(pad, img.position.y + side + 4)
		lab.size = Vector2(side + 6, 20)
		add_child(lab)
		# 右文
		var tx: float = pad + side + 18.0
		var tl := Label.new()
		tl.text = title
		tl.add_theme_font_size_override("font_size", 20)
		tl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		tl.position = Vector2(tx, 18); tl.size = Vector2(size.x - tx - 16, 30)
		add_child(tl)
		var dl := Label.new()
		dl.text = desc
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 16)
		dl.add_theme_color_override("font_color", Color(0.70, 0.66, 0.55))
		dl.position = Vector2(tx, 56); dl.size = Vector2(size.x - tx - 16, size.y - 72)
		add_child(dl)
	else:
		# —— 无锚点：纯文字卡片（左侧竖条 + 标题 + 描述），向后兼容场景二~八 ——
		var bar := Panel.new()
		bar.position = Vector2(0, 0); bar.size = Vector2(8, size.y)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.78, 0.62, 0.28, 1)
		bsb.set_corner_radius_all(0)
		bar.add_theme_stylebox_override("panel", bsb)
		add_child(bar)
		var tl := Label.new()
		tl.text = title
		tl.add_theme_font_size_override("font_size", 20)
		tl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		tl.position = Vector2(22, 18); tl.size = Vector2(size.x - 38, 30)
		add_child(tl)
		var dl := Label.new()
		dl.text = desc
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 16)
		dl.add_theme_color_override("font_color", Color(0.70, 0.66, 0.55))
		dl.position = Vector2(22, 56); dl.size = Vector2(size.x - 38, size.y - 72)
		add_child(dl)
