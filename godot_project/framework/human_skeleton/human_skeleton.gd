extends Node2D

# 人体骨架：根据 HumanBodySpec 构建 14 个关节节点的层级树。
# 关键点：
#   - 每个部位 = 一个 HumanBone 节点，其 position = 在【父段局部坐标】中的关节锚点，
#     其 rotation = 该关节相对父段的局部角。
#   - 正向运动学(FK)由 Godot 的节点变换自动完成：子节点 world = 父 world * (锚点 + 旋转)。
#   - set_pose 设置某关节的局部角，并 clamp 到该关节的 ROM —— 这就是「关节活动范围约束」。
#   - 因此「定准关节 + 约束活动范围」后，人体各部位的活动天然被定位，不会错位/脱节。
#
# 注：跨文件引用用 preload（不依赖 headless 下的全局 class_name 缓存）。

const SpecScript := preload("res://framework/human_skeleton/human_body_spec.gd")
const BoneScript := preload("res://framework/human_skeleton/human_bone.gd")

var bones: Dictionary = {}
var spec = SpecScript.new()


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	bones.clear()
	# 1) 创建所有节点并写入几何/约束参数
	for id in spec.SEGMENT_ORDER:
		# L/W/SHAPE/COLOR 按"部位类型"键(去掉 _L/_R 后缀)
		var t = id.replace("_L", "").replace("_R", "")
		var b = BoneScript.new()
		b.name = id
		b.seg_id = id
		b.length = spec.L[t] * spec.PX_PER_U
		b.width = spec.W[t] * spec.PX_PER_U
		b.shape = spec.SHAPE[t]
		b.color = spec.COLOR[t]
		b.rom = spec.ROM[id]
		b.rest_angle = spec.REST_ANGLE[id]
		b.rotation = b.rest_angle
		bones[id] = b
	# 2) 建立父子关系与关节锚点定位
	for id in spec.SEGMENT_ORDER:
		var parent = spec.PARENT[id]
		if parent == "":
			add_child(bones[id])
		else:
			bones[parent].add_child(bones[id])
			bones[id].position = spec.ANCHORS[id] * spec.PX_PER_U


# 设置某关节的局部角(度)，自动 clamp 到 ROM。
func set_pose(id: String, angle_deg: float) -> void:
	if not bones.has(id):
		return
	var a := deg_to_rad(angle_deg)
	a = clampf(a, bones[id].rom.x, bones[id].rom.y)
	bones[id].rotation = a


# 批量设置（dict: id -> 角度(度)）
func apply_pose(p: Dictionary) -> void:
	for k in p.keys():
		set_pose(k, float(p[k]))


# 回到静止姿态
func reset_pose() -> void:
	for id in bones.keys():
		bones[id].rotation = bones[id].rest_angle


# 近端关节世界坐标（锚点）
func joint_world(id: String) -> Vector2:
	return bones[id].global_position


# 远端关节世界坐标（该段末端，下一关节所在）
func tip_world(id: String) -> Vector2:
	return bones[id].global_transform * Vector2(0.0, bones[id].length)
