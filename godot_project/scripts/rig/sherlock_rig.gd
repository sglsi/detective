# 自动生成：tools/gen_sherlock_rig.py —— 福尔摩斯绑骨定义
class_name SherlockRig
const DEF := {
	"bones": [
		{"name":"head","parent":"","pos":Vector2(0,0),"rot":0,"len":80,"wid":46,"dir":-1,"color":Color(0.86,0.70,0.55),"tex":"res://assets/characters/sherlock/rig/sherlock_head.png","pivot":Vector2(766.396,0),"scale":0.0390625},
		{"name":"neck","parent":"head","pos":Vector2(0,80),"rot":0,"len":18,"wid":14,"dir":-1,"color":Color(0.86,0.70,0.55),"tex":"","pivot":Vector2(0,0),"scale":1},
		{"name":"torso","parent":"neck","pos":Vector2(0,18),"rot":0,"len":110,"wid":42,"dir":-1,"color":Color(0.16,0.18,0.26),"tex":"res://assets/characters/sherlock/rig/sherlock_torso.png","pivot":Vector2(932.425,0),"scale":0.0734312},
		{"name":"hip","parent":"torso","pos":Vector2(0,110),"rot":0,"len":16,"wid":30,"dir":-1,"color":Color(0.12,0.12,0.16),"tex":"","pivot":Vector2(0,0),"scale":1},
		{"name":"shoulder_L","parent":"torso","pos":Vector2(-22,10),"rot":0,"len":6,"wid":14,"dir":-1,"color":Color(0.16,0.18,0.26),"tex":"","pivot":Vector2(0,0),"scale":1},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0,0),"rot":70,"len":60,"wid":16,"dir":1,"color":Color(0.24,0.26,0.36),"tex":"res://assets/characters/sherlock/rig/sherlock_upperarm_L.png","pivot":Vector2(722.208,0),"scale":0.0300451},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(0,60),"rot":8,"len":55,"wid":13,"dir":1,"color":Color(0.86,0.70,0.55),"tex":"res://assets/characters/sherlock/rig/sherlock_forearm_L.png","pivot":Vector2(344.344,0),"scale":0.0281474},
		{"name":"shoulder_R","parent":"torso","pos":Vector2(22,10),"rot":0,"len":6,"wid":14,"dir":-1,"color":Color(0.16,0.18,0.26),"tex":"","pivot":Vector2(0,0),"scale":1},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0,0),"rot":-70,"len":60,"wid":16,"dir":1,"color":Color(0.24,0.26,0.36),"tex":"res://assets/characters/sherlock/rig/sherlock_upperarm_R.png","pivot":Vector2(836.796,0),"scale":0.030303},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(0,60),"rot":-8,"len":55,"wid":13,"dir":1,"color":Color(0.86,0.70,0.55),"tex":"res://assets/characters/sherlock/rig/sherlock_forearm_R.png","pivot":Vector2(198.629,0),"scale":0.0278905},
		{"name":"thigh_L","parent":"hip","pos":Vector2(-16,6),"rot":0,"len":80,"wid":22,"dir":1,"color":Color(0.12,0.12,0.16),"tex":"res://assets/characters/sherlock/rig/sherlock_thigh_L.png","pivot":Vector2(509.647,0),"scale":0.0431965},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(0,80),"rot":0,"len":80,"wid":17,"dir":1,"color":Color(0.24,0.26,0.36),"tex":"res://assets/characters/sherlock/rig/sherlock_shin_L.png","pivot":Vector2(292.885,0),"scale":0.045403},
		{"name":"thigh_R","parent":"hip","pos":Vector2(16,6),"rot":0,"len":80,"wid":22,"dir":1,"color":Color(0.12,0.12,0.16),"tex":"res://assets/characters/sherlock/rig/sherlock_thigh_R.png","pivot":Vector2(625.782,0),"scale":0.0428725},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(0,80),"rot":0,"len":80,"wid":17,"dir":1,"color":Color(0.24,0.26,0.36),"tex":"res://assets/characters/sherlock/rig/sherlock_shin_R.png","pivot":Vector2(742.971,0),"scale":0.0410467},
		{"name":"hat","parent":"head","pos":Vector2(0,0),"rot":180,"len":34,"wid":64,"dir":-1,"color":Color(0.55,0.42,0.28),"tex":"res://assets/characters/sherlock/rig/sherlock_hat.png","pivot":Vector2(118.237,1650),"scale":0.0206061}
	]
}
static func rig_def() -> Dictionary:
	return DEF
