# 自动生成：tools/json_to_gd_rig_sherlock_spread.py
class_name SherlockSpreadRig
const DEF := {
	"bones": [
		{"name":"head","parent":"","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":45.1340,"wid":38.7840,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/head.png","pivot":Vector2(85.5000, 205.0000),"scale":0.2268041237},
		{"name":"neck","parent":"head","pos":Vector2(-0.7940, -12.4740),"rot":0.0,"len":12.4990,"wid":14.0000,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2268041237},
		{"name":"torso","parent":"neck","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":110.0000,"wid":45.0430,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"res://assets/characters/sherlock_spread/rig/torso.png","pivot":Vector2(165.0000, 0.0000),"scale":0.2268041237},
		{"name":"hip","parent":"torso","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":-15.0000,"wid":32.0000,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2268041237},
		{"name":"shoulder_L","parent":"torso","pos":Vector2(-16.7840, 12.4740),"rot":0.0,"len":6.0000,"wid":14.0000,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2268041237},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0.0000, 0.0000),"rot":-37.363,"len":39.5610,"wid":35.5180,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_L.png","pivot":Vector2(260.0000, 17.0000),"scale":0.2268041237},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(0.0000, 39.5610),"rot":3.913,"len":54.8870,"wid":26.5360,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_L.png","pivot":Vector2(194.0000, 28.0000),"scale":0.2268041237},
		{"name":"shoulder_R","parent":"torso","pos":Vector2(16.7840, 11.7940),"rot":0.0,"len":6.0000,"wid":14.0000,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2268041237},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0.0000, 0.0000),"rot":36.602,"len":40.1740,"wid":35.5180,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_R.png","pivot":Vector2(0.0000, 14.0000),"scale":0.2268041237},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(0.0000, 40.1740),"rot":-3.152,"len":54.8870,"wid":26.5360,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_R.png","pivot":Vector2(0.0000, 28.0000),"scale":0.2268041237},
		{"name":"thigh_L","parent":"hip","pos":Vector2(0.0000, 0.0000),"rot":-32.713,"len":48.5450,"wid":30.5620,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_L.png","pivot":Vector2(244.0000, 20.0000),"scale":0.2268041237},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(0.0000, 48.5450),"rot":-1.648,"len":55.3860,"wid":25.5150,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_L.png","pivot":Vector2(158.0000, 20.0000),"scale":0.2268041237},
		{"name":"thigh_R","parent":"hip","pos":Vector2(0.0000, 0.0000),"rot":26.917,"len":45.9340,"wid":30.5620,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_R.png","pivot":Vector2(34.0000, 20.0000),"scale":0.2268041237},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(0.0000, 45.9340),"rot":3.777,"len":53.9110,"wid":25.5150,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_R.png","pivot":Vector2(65.0000, 20.0000),"scale":0.2268041237}
	]
}
static func rig_def() -> Dictionary:
	return DEF