# 自动生成：tools/json_to_gd_rig_sherlock_spread.py
class_name SherlockSpreadRig
const DEF := {
	"bones": [
		{"name":"head","parent":"","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":11.2210,"wid":7.5390,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/head.png","pivot":Vector2(66.5000, 157.2500),"scale":0.2380857570},
		{"name":"neck","parent":"head","pos":Vector2(0.2380, 1.1900),"rot":0.0,"len":0.2833,"wid":3.3332,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2380857570},
		{"name":"torso","parent":"neck","pos":Vector2(0.0000, 1.1900),"rot":0.0,"len":26.1894,"wid":8.1966,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"res://assets/characters/sherlock_spread/rig/torso.png","pivot":Vector2(120.5000, 0.0000),"scale":0.2380857570},
		{"name":"hip","parent":"torso","pos":Vector2(0.0000, 110.0000),"rot":0.0,"len":-3.5713,"wid":7.6187,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2380857570},
		{"name":"shoulder_L","parent":"torso","pos":Vector2(-24.7610, 7.1430),"rot":0.0,"len":1.4285,"wid":3.3332,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2380857570},
		{"name":"shoulder_R","parent":"torso","pos":Vector2(24.7610, 6.4280),"rot":0.0,"len":1.4285,"wid":3.3332,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2380857570},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0.0000, 0.0000),"rot":-32.685,"len":11.6514,"wid":3.8091,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_L.png","pivot":Vector2(56.0000, 17.4000),"scale":0.2380857570},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(0.0000, 48.9380),"rot":-4.422,"len":13.7178,"wid":5.4757,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_L.png","pivot":Vector2(80.5000, 19.4000),"scale":0.2380857570},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0.0000, 0.0000),"rot":32.239,"len":11.7950,"wid":3.8091,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_R.png","pivot":Vector2(56.0000, 17.7000),"scale":0.2380857570},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(0.0000, 49.5410),"rot":4.868,"len":13.7178,"wid":5.4757,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_R.png","pivot":Vector2(80.5000, 19.4000),"scale":0.2380857570},
		{"name":"thigh_L","parent":"hip","pos":Vector2(-6.4280, 11.9050),"rot":-28.207,"len":14.1513,"wid":3.7101,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_L.png","pivot":Vector2(59.5000, 17.6800),"scale":0.2380857570},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(0.0000, 59.4380),"rot":-7.662,"len":13.6404,"wid":4.1096,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_L.png","pivot":Vector2(72.5000, 10.0000),"scale":0.2380857570},
		{"name":"thigh_R","parent":"hip","pos":Vector2(5.2380, 11.9050),"rot":28.61,"len":14.2051,"wid":3.7725,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_R.png","pivot":Vector2(60.5000, 17.6800),"scale":0.2380857570},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(0.0000, 59.6640),"rot":4.066,"len":13.3340,"wid":3.9396,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_R.png","pivot":Vector2(69.5000, 10.0000),"scale":0.2380857570}
	]
}
static func rig_def() -> Dictionary:
	return DEF