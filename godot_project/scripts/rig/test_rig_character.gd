# 自动生成：tools/json_to_gd_rig.py
class_name TestRigCharacter
const DEF := {
	"bones": [
		{"name":"head","parent":"","pos":Vector2(0.0000, 0.0000),"rot":0,"len":7.3337,"wid":6.1151,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/head.png","pivot":Vector2(138.0000, 281.3500),"scale":0.1488497970},
		{"name":"neck","parent":"head","pos":Vector2(0.0000, 7.3904),"rot":0,"len":0.4465,"wid":2.0839,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.1488497970},
		{"name":"torso","parent":"neck","pos":Vector2(0.0000, 3.0000),"rot":0,"len":16.3735,"wid":5.1713,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/torso.png","pivot":Vector2(194.5000, 0.0000),"scale":0.1488497970},
		{"name":"hip","parent":"torso","pos":Vector2(0.0000, 110.0000),"rot":0,"len":-2.2327,"wid":4.7632,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.1488497970},
		{"name":"shoulder_L","parent":"torso","pos":Vector2(-20.2659, 0.0000),"rot":0,"len":0.8931,"wid":2.0839,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.1488497970},
		{"name":"upperarm_L","parent":"shoulder_L","pos":Vector2(0.0000, 0.0000),"rot":-70,"len":5.9157,"wid":1.5554,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/upperarm_L.png","pivot":Vector2(58.5000, 26.7000),"scale":0.1488497970},
		{"name":"forearm_L","parent":"upperarm_L","pos":Vector2(0.0000, 47.3126),"rot":-8,"len":13.6039,"wid":1.5687,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/forearm_L.png","pivot":Vector2(59.0000, 30.7000),"scale":0.1488497970},
		{"name":"shoulder_R","parent":"torso","pos":Vector2(20.2659, 0.0000),"rot":0,"len":0.8931,"wid":2.0839,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"","pivot":Vector2(0.0000, 0.0000),"scale":0.1488497970},
		{"name":"upperarm_R","parent":"shoulder_R","pos":Vector2(0.0000, 0.0000),"rot":70,"len":5.9157,"wid":1.5554,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/upperarm_R.png","pivot":Vector2(58.5000, 26.7000),"scale":0.1488497970},
		{"name":"forearm_R","parent":"upperarm_R","pos":Vector2(0.0000, 47.3126),"rot":8,"len":13.6039,"wid":1.5687,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/forearm_R.png","pivot":Vector2(59.0000, 30.7000),"scale":0.1488497970},
		{"name":"thigh_L","parent":"hip","pos":Vector2(-22.6884, -9.0698),"rot":0,"len":11.0338,"wid":1.8644,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/test_rig_character/rig/thigh_L.png","pivot":Vector2(76.5000, 39.8400),"scale":0.1488497970},
		{"name":"shin_L","parent":"thigh_L","pos":Vector2(0.0000, 80.5582),"rot":0,"len":10.2140,"wid":1.6950,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/shin_L.png","pivot":Vector2(76.5000, 23.0500),"scale":0.1488497970},
		{"name":"thigh_R","parent":"hip","pos":Vector2(22.8112, -9.0698),"rot":0,"len":11.0338,"wid":1.8279,"dir":1,"color":Color(0.1200, 0.1200, 0.1600),"tex":"res://assets/characters/test_rig_character/rig/thigh_R.png","pivot":Vector2(75.0000, 39.8400),"scale":0.1488497970},
		{"name":"shin_R","parent":"thigh_R","pos":Vector2(0.0000, 80.5582),"rot":0,"len":10.2140,"wid":1.6617,"dir":1,"color":Color(0.8600, 0.7000, 0.5500),"tex":"res://assets/characters/test_rig_character/rig/shin_R.png","pivot":Vector2(75.0000, 23.0500),"scale":0.1488497970}
	]
}
static func rig_def() -> Dictionary:
	return DEF