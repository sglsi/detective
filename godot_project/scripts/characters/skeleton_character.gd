class_name SkeletonCharacter2D
extends Node2D

# 数据驱动的可复用 2D 骨架角色。
# - 无美术依赖：部件可用彩色 Polygon2D（demo / 占位）。
# - 真素材：每个骨可挂一张肢体贴图（tex），替换 Polygon 即得到可绑骨角色。
# 姿态用程序化函数计算（idle/walk/wave/talk/look），apply_pose(name,t) 可直接设姿态，便于离屏截图验证。

var _bones: Dictionary = {}        # name -> Bone2D
var _base_rot: Dictionary = {}     # name -> float (本地基准弧度)
var _base_visual_rot: Dictionary = {}  # name -> float (世界视觉基准弧度，从根累加)
var _cur_rot: Dictionary = {}      # name -> float (当前弧度，apply_pose 时更新)
var _bones_def: Array = []
var _built: bool = false

var _anim: String = "idle"
var _t: float = 0.0
var _playing: bool = false
var _speed: float = 1.0

# ---- 公开 API ----

func build_demo(palette: String = "sherlock") -> void:
	_bones_def = _demo_def(palette)
	_build()

# 真素材接入点：传入 rig 定义（含各骨 tex 路径）即可替换 demo。
func build_from_def(def: Dictionary) -> void:
	_bones_def = def["bones"]
	_build()

func play(name: String, speed: float = 1.0) -> void:
	_anim = name
	_speed = speed
	_playing = true

func stop() -> void:
	_playing = false

# 直接设姿态（截图/调试用），不依赖 _process 时序。
func apply_pose(name: String, t: float) -> void:
	_anim = name
	_t = t
	var r: Dictionary = {}
	for bn in _base_rot.keys():
		r[bn] = _base_rot[bn]
	match name:
		"default":
			pass  # 保持 _base_rot，即原图 A-pose 精确拼合
		"idle":
			r["torso"] = r["torso"] + deg_to_rad(2.0) * sin(TAU * 0.5 * t)
			r["head"]  = r["head"]  + deg_to_rad(3.0) * sin(TAU * 0.5 * t)
			r["upperarm_L"] = r["upperarm_L"] + deg_to_rad(3.0) * sin(TAU * 0.5 * t)
			r["upperarm_R"] = r["upperarm_R"] - deg_to_rad(3.0) * sin(TAU * 0.5 * t)
		"walk":
			var sw: float = sin(TAU * t)
			r["thigh_L"] = r["thigh_L"] + deg_to_rad(25.0) * sw
			r["thigh_R"] = r["thigh_R"] - deg_to_rad(25.0) * sw
			r["shin_L"]  = r["shin_L"] + deg_to_rad(22.0) * max(0.0, sw)
			r["shin_R"]  = r["shin_R"] + deg_to_rad(22.0) * max(0.0, -sw)
			# A-pose 手臂已经张开 60°，步行摆动幅度不宜过大
			r["upperarm_L"] = r["upperarm_L"] - deg_to_rad(12.0) * sw
			r["upperarm_R"] = r["upperarm_R"] + deg_to_rad(12.0) * sw
			r["torso"] = r["torso"] + deg_to_rad(4.0)
			r["hip"]   = r["hip"] + deg_to_rad(sin(TAU * 2.0 * t) * 1.5)
		"wave":
			# 从 A-pose 出发的挥手：右臂抬到水平偏上，前臂相对上臂向上弯曲。
			# 直接指定目标本地角（= 目标视觉角，因为 shoulder 无旋转）。
			var wave_s: float = sin(TAU * 2.0 * t)
			r["upperarm_R"] = deg_to_rad(-90.0 + 8.0 * wave_s)
			r["forearm_R"]  = deg_to_rad(-60.0 + 15.0 * wave_s)
			r["head"] = r["head"] + deg_to_rad(6.0)
		"talk":
			r["head"] = r["head"] + deg_to_rad(5.0) * sin(TAU * 3.0 * t)
			r["upperarm_L"] = r["upperarm_L"] + deg_to_rad(12.0) * sin(TAU * 2.0 * t)
	for bn in r.keys():
		if _bones.has(bn):
			_bones[bn].rotation = r[bn]
	_cur_rot = r

func _process(delta: float) -> void:
	if _playing and _anim != "":
		_t += delta * _speed
		apply_pose(_anim, _t)

# ---- 构建 ----

func _build() -> void:
	if _built:
		return
	for c in get_children():
		c.queue_free()
	_bones.clear()
	_base_rot.clear()
	_base_visual_rot.clear()
	var sk := Skeleton2D.new()
	sk.name = "Skeleton"
	add_child(sk)
	var nodes: Dictionary = {}
	for b in _bones_def:
		var bone := Bone2D.new()
		bone.name = b["name"]
		bone.position = b["pos"]
		var base: float = deg_to_rad(float(b["rot"]))
		bone.rotation = base
		nodes[b["name"]] = bone
		_base_rot[b["name"]] = base
		# 计算世界视觉基准角（从根累加）
		if b["parent"] == "":
			_base_visual_rot[b["name"]] = base
		else:
			_base_visual_rot[b["name"]] = _base_visual_rot[b["parent"]] + base
	for b in _bones_def:
		var bone: Bone2D = nodes[b["name"]]
		if b["parent"] == "":
			sk.add_child(bone)
		else:
			nodes[b["parent"]].add_child(bone)
	for bb in _bones_def:
		var part: Node2D = _make_part(bb)
		nodes[bb["name"]].add_child(part)
		_bones[bb["name"]] = nodes[bb["name"]]
	_built = true
	_cur_rot = _base_rot.duplicate()

# 导出真实骨骼世界姿态（供离屏预览绘制，避免 headless GPU 渲染不稳）。
func get_pose_data(origin: Vector2) -> Array:
	var lt: Dictionary = {}
	for b in _bones_def:
		var nm: String = b["name"]
		var rot: float = _cur_rot.get(nm, _base_rot.get(nm, 0.0))
		var d: float = 1.0
		if b.has("dir"):
			d = b["dir"]
		lt[nm] = {"parent": b["parent"], "pos": b["pos"], "rot": rot,
			"len": b["len"], "wid": b["wid"], "dir": d, "color": b["color"]}
	var cache: Dictionary = {}
	var out: Array = []
	for b in _bones_def:
		var nm: String = b["name"]
		var w: Dictionary = _world_of(nm, lt, cache)
		var col: Color = lt[nm]["color"]
		out.append({
			"name": nm,
			"x": origin.x + w["pos"].x,
			"y": origin.y + w["pos"].y,
			"rot": w["rot"],
			"len": lt[nm]["len"],
			"wid": lt[nm]["wid"],
			"dir": lt[nm]["dir"],
			"color": [col.r, col.g, col.b],
		})
	return out

func _world_of(nm: String, lt: Dictionary, cache: Dictionary) -> Dictionary:
	if cache.has(nm):
		return cache[nm]
	var cur: Dictionary = lt[nm]
	if cur["parent"] == "":
		var w: Dictionary = {"pos": cur["pos"], "rot": cur["rot"]}
		cache[nm] = w
		return w
	var pw: Dictionary = _world_of(cur["parent"], lt, cache)
	var c: float = cos(pw["rot"])
	var s: float = sin(pw["rot"])
	var lp: Vector2 = cur["pos"]
	var wp: Vector2 = Vector2(lp.x * c - lp.y * s, lp.x * s + lp.y * c) + pw["pos"]
	var wr: float = pw["rot"] + cur["rot"]
	var w: Dictionary = {"pos": wp, "rot": wr}
	cache[nm] = w
	return w

func _make_part(b: Dictionary) -> Node2D:
	if b.has("tex"):
		var tex_path: String = b["tex"]
		if tex_path != "" and ResourceLoader.exists(tex_path):
			var sp := Sprite2D.new()
			sp.texture = load(tex_path)
			sp.centered = false
			var sc: float = b.get("scale", 1.0)
			var flip: bool = b.get("flip", false)
			var piv: Vector2 = b.get("pivot", Vector2(0, 0))
			if flip:
				sp.flip_v = true
				piv.y = float(sp.texture.get_height()) - piv.y
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(-piv.x * sc, -piv.y * sc)
			return sp
	var poly := Polygon2D.new()
	var w: float = b["wid"]
	var l: float = b["len"]
	var col: Color = b["color"]
	var dir: float = 1.0
	if b.has("dir"):
		dir = b["dir"]
	var pts: PackedVector2Array = PackedVector2Array()
	if dir < 0.0:
		pts = [Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, -l), Vector2(-w * 0.5, -l)]
	else:
		pts = [Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, l), Vector2(-w * 0.5, l)]
	poly.polygon = pts
	poly.color = col
	return poly

# ---- demo 人偶（带 Sherlock 配色，blocky 风格，仅用于演示骨架机制）----

func _demo_def(palette: String) -> Array:
	var skin: Color = Color(0.86, 0.70, 0.55)
	var coat: Color = Color(0.16, 0.18, 0.26)
	var coat_l: Color = Color(0.24, 0.26, 0.36)
	var hat: Color = Color(0.55, 0.42, 0.28)
	var pants: Color = Color(0.12, 0.12, 0.16)
	if palette == "watson":
		coat = Color(0.30, 0.26, 0.22)
		coat_l = Color(0.40, 0.34, 0.28)
		hat = Color(0.45, 0.36, 0.26)
	var d: Array = [
		{"name":"hip","parent":"","pos":Vector2(0,0),"rot":0.0,"len":20.0,"wid":32.0,"dir":-1.0,"color":pants},
		{"name":"torso","parent":"hip","pos":Vector2(0,-15.0),"rot":0.0,"len":95.0,"wid":42.0,"dir":-1.0,"color":coat},
		{"name":"chest","parent":"torso","pos":Vector2(0,-95.0),"rot":0.0,"len":8.0,"wid":36.0,"dir":-1.0,"color":coat_l},
		{"name":"neck","parent":"chest","pos":Vector2(0,-8.0),"rot":0.0,"len":18.0,"wid":16.0,"dir":-1.0,"color":skin},
		{"name":"head","parent":"neck","pos":Vector2(0,-18.0),"rot":0.0,"len":56.0,"wid":50.0,"dir":-1.0,"color":skin},
		{"name":"hat","parent":"head","pos":Vector2(0,-50.0),"rot":0.0,"len":22.0,"wid":66.0,"dir":-1.0,"color":hat},
		{"name":"shoulder_L","parent":"chest","pos":Vector2(-16.0,-6.0),"rot":0.0,"len":6.0,"wid":14.0,"dir":-1.0,"color":coat},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0,0),"rot":70.0,"len":58.0,"wid":16.0,"dir":1.0,"color":coat_l},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(0,58.0),"rot":8.0,"len":52.0,"wid":13.0,"dir":1.0,"color":skin},
		{"name":"shoulder_R","parent":"chest","pos":Vector2(16.0,-6.0),"rot":0.0,"len":6.0,"wid":14.0,"dir":-1.0,"color":coat},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0,0),"rot":-70.0,"len":58.0,"wid":16.0,"dir":1.0,"color":coat_l},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(0,58.0),"rot":-8.0,"len":52.0,"wid":13.0,"dir":1.0,"color":skin},
		{"name":"thigh_L","parent":"hip","pos":Vector2(-14.0,5.0),"rot":0.0,"len":62.0,"wid":22.0,"dir":1.0,"color":pants},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(0,62.0),"rot":0.0,"len":62.0,"wid":17.0,"dir":1.0,"color":coat_l},
		{"name":"thigh_R","parent":"hip","pos":Vector2(14.0,5.0),"rot":0.0,"len":62.0,"wid":22.0,"dir":1.0,"color":pants},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(0,62.0),"rot":0.0,"len":62.0,"wid":17.0,"dir":1.0,"color":coat_l},
	]
	return d
