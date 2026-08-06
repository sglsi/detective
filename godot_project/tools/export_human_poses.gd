extends SceneTree

# headless 导出示范姿势：构建 HumanSkeleton，对若干示范动作设置关节角，
# 输出每帧各关节的世界坐标(POSEJSON)，供 Python 绘制 contact sheet 验证。
# 用法: godot --headless --script tools/export_human_poses.gd > skeleton_frames/human_poses.json

const SkeletonScript := preload("res://framework/human_skeleton/human_skeleton.gd")

var sk

func _initialize() -> void:
	await create_timer(0.1).timeout
	sk = SkeletonScript.new()
	root.add_child(sk)
	sk.build()
	await create_timer(0.1).timeout

	# 示范姿势：key = 关节 id，value = 绝对局部角(度)，越界会被 ROM clamp。
	var poses := {
		"rest": {},
		"wave": {"upper_arm_R": 165, "fore_arm_R": 35, "head": 205},
		"walk1": {"torso": 4, "thigh_L": -35, "thigh_R": 25, "shin_L": 25, "shin_R": 6,
		          "upper_arm_L": 25, "upper_arm_R": -25},
		"walk2": {"torso": 4, "thigh_L": 25, "thigh_R": -35, "shin_L": 6, "shin_R": 25,
		          "upper_arm_L": -25, "upper_arm_R": 25},
		"sit": {"thigh_L": 90, "thigh_R": 90, "shin_L": 90, "shin_R": 90,
		        "upper_arm_L": -18, "upper_arm_R": 18},
		"reach": {"upper_arm_L": -150, "fore_arm_L": 25, "head": 160},
		"kick": {"thigh_R": -85, "shin_R": 85, "thigh_L": 12,
		         "upper_arm_L": 22, "upper_arm_R": -22},
		"point": {"upper_arm_R": 150, "fore_arm_R": 30, "head": 205, "upper_arm_L": -20},
	}

	var frames := []
	for pname in poses.keys():
		sk.reset_pose()
		for k in poses[pname].keys():
			sk.set_pose(k, float(poses[pname][k]))
		await create_timer(0.06).timeout
		var arr := []
		for id in sk.spec.SEGMENT_ORDER:
			var b = sk.bones[id]
			var p: Vector2 = b.global_position
			var q: Vector2 = b.global_transform * Vector2(0.0, b.length)
			arr.append({
				"id": id,
				"p": [p.x, p.y],
				"q": [q.x, q.y],
				"w": b.width,
				"c": [b.color.r, b.color.g, b.color.b],
				"shape": b.shape,
			})
		frames.append({"pose": pname, "bones": arr})

	print("POSEJSON " + JSON.stringify(frames))
	quit()
