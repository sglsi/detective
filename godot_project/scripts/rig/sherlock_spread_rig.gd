# 自动生成：tools/json_to_gd_rig_sherlock_spread.py
class_name SherlockSpreadRig
const DEF := {
	"bones": [
		{"name":"head","parent":"","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":50.6390,"wid":34.0230,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/head.png","pivot":Vector2(66.5000, 184.0000),"scale":0.2558139535},
		{"name":"neck","parent":"head","pos":Vector2(12.4070, -1.2790),"rot":0.0,"len":12.4730,"wid":14.0000,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"torso","parent":"neck","pos":Vector2(0.0000, 0.0000),"rot":0.0,"len":118.1910,"wid":36.9910,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"res://assets/characters/sherlock_spread/rig/torso.png","pivot":Vector2(170.0000, 0.0000),"scale":0.2558139535},
		{"name":"hip","parent":"torso","pos":Vector2(-43.2330, 110.0000),"rot":0.0,"len":-15.0000,"wid":32.0000,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"shoulder_L","parent":"torso","pos":Vector2(-39.3950, 7.6740),"rot":0.0,"len":6.0000,"wid":14.0000,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0.0000, 0.0000),"rot":-32.685,"len":39.4030,"wid":17.1910,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_L.png","pivot":Vector2(111.0000, 0.0000),"scale":0.2558139535},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(-30.2110, 25.2950),"rot":-4.422,"len":61.9080,"wid":24.7120,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_L.png","pivot":Vector2(160.0000, 0.0000),"scale":0.2558139535},
		{"name":"shoulder_R","parent":"torso","pos":Vector2(13.8140, 6.9070),"rot":0.0,"len":6.0000,"wid":14.0000,"dir":1,"color":Color(0.1600, 0.1800, 0.2600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0.0000, 0.0000),"rot":32.239,"len":40.1360,"wid":17.1910,"dir":1,"color":Color(0.2400, 0.2600, 0.3600),"tex":"res://assets/characters/sherlock_spread/rig/upperarm_R.png","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(30.4230, 26.1790),"rot":4.868,"len":61.9080,"wid":24.7120,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/forearm_R.png","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"thigh_L","parent":"hip","pos":Vector2(23.5350, -3.3260),"rot":-28.207,"len":51.4440,"wid":16.7430,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_L.png","pivot":Vector2(118.0000, 0.0000),"scale":0.2558139535},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(-33.8440, 38.7440),"rot":-7.662,"len":61.5580,"wid":18.5470,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_L.png","pivot":Vector2(144.0000, 0.0000),"scale":0.2558139535},
		{"name":"thigh_R","parent":"hip","pos":Vector2(36.0700, -3.3260),"rot":28.61,"len":51.6830,"wid":17.0240,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/sherlock_spread/rig/thigh_R.png","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(35.0140, 38.0150),"rot":4.066,"len":60.1750,"wid":17.7790,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/sherlock_spread/rig/shin_R.png","pivot":Vector2(0.0000, 0.0000),"scale":0.2558139535}
	]
}
static func rig_def() -> Dictionary:
	return DEF