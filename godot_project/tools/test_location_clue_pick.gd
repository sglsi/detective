extends SceneTree
# M2.x 回归：地点类线索的命中区/提示圈挂入摄像机世界层(_world)，
# scale=1 时屏幕位置无回归；缩放/平移后随相机一起变换（缩放后仍精准可点）。
#
# 注：--script 模式无帧推进，子节点全局变换不会自动重算（且 force_update_transform
# 会因未收到 entered-tree 通知而报 !is_inside_tree）。故用组合公式
#   child 全局中心 = world.global_position + child.position*world.scale + child.size*world.scale*0.5
# 直接验证耦合（world.global_position 在改 scale/position 后会即时更新，已实测）。

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	sf.name = "ui"
	root.add_child(sf)
	sf._ready()   # --script 下无帧推进，_ready 不会自动跑，手动强制同步构建世界子树
	var world: Control = sf.get_world_layer()
	var off: Vector2 = sf.get_world_offset()
	if world == null:
		print("LOC_PICK: FAIL (no world layer)"); quit()

	var txt := Label.new(); var spk := Label.new()
	var hotspot := {"id":"gate","label":"花园门","x":260.0,"y":430.0,"w":120.0,"h":80.0,"desc":"测试"}
	var obs = load("res://scripts/clue/clue_observer.gd").new()
	# 地点类：portrait_ctrl=null，传入 world 层 + 偏移
	obs.setup(sf, txt, spk, [hotspot], null, null, "", world, off)
	obs.show()

	# 1) 命中区挂在 world 层
	var btn = obs._btns[0]
	if btn.get_parent() != world:
		print("LOC_PICK: FAIL (btn parent != world, got ", (btn.get_parent().name if btn.get_parent() else "null"), ")"); quit()

	# 2) scale=1 局部位置 == hotspot - offset
	var expect_local := Vector2(hotspot["x"], hotspot["y"]) - off
	if btn.position.distance_to(expect_local) > 0.5:
		print("LOC_PICK: FAIL (local pos mismatch: ", btn.position, " vs ", expect_local, ")"); quit()

	# 3) scale=1 全局中心 == 场景根热点中心（无回归：与改动前一致）
	var expect_global := Vector2(hotspot["x"] + hotspot["w"] * 0.5, hotspot["y"] + hotspot["h"] * 0.5)
	var c1: Vector2 = world.get_global_position() + btn.position * world.scale + btn.size * world.scale * 0.5
	if c1.distance_to(expect_global) > 1.0:
		print("LOC_PICK: FAIL (global center mismatch at scale1: ", c1, " vs ", expect_global, ")"); quit()

	# 4) 缩放/平移后随相机变换（位置改变，仍由相机驱动）
	world.scale = Vector2(2.0, 2.0)
	world.position = Vector2(60.0, 40.0)
	var c2: Vector2 = world.get_global_position() + btn.position * world.scale + btn.size * world.scale * 0.5
	if c2.distance_to(expect_global) < 1.0:
		print("LOC_PICK: FAIL (did not transform with zoom: ", c2, ")"); quit()

	# 5) 提示圈也画在 world 层（模拟简单/普通模式高亮），且随相机变换
	obs._mark_clue_at_anchor("gate", 2)
	var circle = world.get_node_or_null("hl_gate")
	if circle == null:
		print("LOC_PICK: FAIL (no hint circle in world layer)"); quit()
	var c3: Vector2 = world.get_global_position() + circle.position * world.scale + circle.size * world.scale * 0.5
	if c3.distance_to(expect_global) < 1.0:
		print("LOC_PICK: FAIL (hint circle did not transform with zoom: ", c3, ")"); quit()

	# 6) 收集后提示圈移除（_remove_clue_circle 清理世界层）。
	# --script 无帧推进，queue_free 延迟到下一帧才真正脱离树，故用 is_queued_for_deletion 确认已请求移除。
	obs._remove_clue_circle("gate")
	var leftover = world.get_node_or_null("hl_gate")
	if leftover == null or not leftover.is_queued_for_deletion():
		print("LOC_PICK: FAIL (hint circle not removed from world)"); quit()

	print("LOC_PICK: PASS")
	quit()
