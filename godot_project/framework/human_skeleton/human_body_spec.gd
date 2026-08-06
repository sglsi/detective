class_name HumanBodySpec
extends RefCounted

# =============================================================================
# 人体结构基准规范 (Human Body Base Spec)
# -----------------------------------------------------------------------------
# 这是一套「与具体贴图无关」的人体关节活动基础框架的数据层。
# 设计目标：以人体解剖学关节为锚点，按通用人体比例配置各部位长度，
#          按关节连接约束建立层级，按关节活动范围(ROM)约束各部位运动。
#
# 约定 (2D 正视图)：
#   - 局部坐标系：每个部位(骨段)的近端关节 = 原点 (0,0)。
#   - +Y 方向 = 向下(屏幕坐标)；+X = 向右。
#   - 旋转正方向 = 顺时针(屏幕)。局部角 0 = 沿父段 +Y(即自然下垂/向下)。
#   - 静止姿态(rest)：人体直立，四肢自然下垂微张（A-pose 变体）。
#
# 比例来源：经典艺用人体比例「8 头身」标准（头高=1 比例单位 u）。
#          实际像素 = u * PX_PER_U，全部数值集中在此文件，便于整体调参。
# =============================================================================

const PX_PER_U: float = 60.0   # 1 个头高 = 60px（仅影响显示大小，不影响比例）

# ---- 各部位长度 (单位 u) ----------------------------------------------------
const L := {
	"head": 1.00,        # 头(颈->顶)
	"torso": 2.50,       # 躯干(颈->胯)
	"upper_arm": 1.30,   # 上臂(肩->肘)
	"fore_arm": 1.10,    # 前臂(肘->腕)
	"hand": 0.80,        # 手(腕->指尖)
	"thigh": 1.90,       # 大腿(胯->膝)
	"shin": 1.70,        # 小腿(膝->踝)
	"foot": 0.45,        # 脚(踝->趾)
}

# ---- 各部位宽度 (单位 u) ----------------------------------------------------
const W := {
	"head": 0.72,
	"torso": 0.95,
	"upper_arm": 0.30,
	"fore_arm": 0.24,
	"hand": 0.22,
	"thigh": 0.38,
	"shin": 0.28,
	"foot": 0.34,
}

# ---- 关节锚点：子段近端关节，在【父段局部坐标】中的位置 (单位 u) ------------
# 父段局部坐标：原点=父段近端关节，+Y向下，+X向右。
# 这是「各部位连接的锚点」——关节定准后，部位活动即以这些点为旋转中心。
const ANCHORS := {
	# 头：接躯干顶端(颈)
	"head": Vector2(0.0, 0.0),
	# 肩：躯干顶部两侧（肩线）
	"upper_arm_L": Vector2(-0.52, 0.18),
	"upper_arm_R": Vector2(0.52, 0.18),
	# 肘：上臂末端
	"fore_arm_L": Vector2(0.0, L["upper_arm"]),
	"fore_arm_R": Vector2(0.0, L["upper_arm"]),
	# 腕：前臂末端
	"hand_L": Vector2(0.0, L["fore_arm"]),
	"hand_R": Vector2(0.0, L["fore_arm"]),
	# 胯：躯干底端两侧（髂嵴）
	"thigh_L": Vector2(-0.20, L["torso"]),
	"thigh_R": Vector2(0.20, L["torso"]),
	# 膝：大腿末端
	"shin_L": Vector2(0.0, L["thigh"]),
	"shin_R": Vector2(0.0, L["thigh"]),
	# 踝：小腿末端
	"foot_L": Vector2(0.0, L["shin"]),
	"foot_R": Vector2(0.0, L["shin"]),
}

# ---- 父级映射（构建层级用；"" = 根） ---------------------------------------
const PARENT := {
	"torso": "",
	"head": "torso",
	"upper_arm_L": "torso", "upper_arm_R": "torso",
	"fore_arm_L": "upper_arm_L", "fore_arm_R": "upper_arm_R",
	"hand_L": "fore_arm_L", "hand_R": "fore_arm_R",
	"thigh_L": "torso", "thigh_R": "torso",
	"shin_L": "thigh_L", "shin_R": "thigh_R",
	"foot_L": "shin_L", "foot_R": "shin_R",
}

# ---- 14 个部位的固定顺序（决定建立/遍历顺序） ------------------------------
const SEGMENT_ORDER := [
	"torso",
	"head",
	"upper_arm_L", "upper_arm_R",
	"fore_arm_L", "fore_arm_R",
	"hand_L", "hand_R",
	"thigh_L", "thigh_R",
	"shin_L", "shin_R",
	"foot_L", "foot_R",
]

# 中文名（仅用于标注/调试）
const CN := {
	"torso": "躯干", "head": "头部",
	"upper_arm_L": "左上臂", "upper_arm_R": "右上臂",
	"fore_arm_L": "左前臂", "fore_arm_R": "右前臂",
	"hand_L": "左手", "hand_R": "右手",
	"thigh_L": "左大腿", "thigh_R": "右大腿",
	"shin_L": "左小腿", "shin_R": "右小腿",
	"foot_L": "左脚", "foot_R": "右脚",
}

# ---- 静止姿态局部角度 (弧度)：0=沿父段+Y(下)。正值顺时针 -------------------
# 头朝上 = PI；左右肢微外张呈自然站立。
const REST_ANGLE := {
	"head": PI,
	"upper_arm_L": deg_to_rad(-10.0),
	"upper_arm_R": deg_to_rad(10.0),
	"fore_arm_L": 0.0, "fore_arm_R": 0.0,
	"hand_L": 0.0, "hand_R": 0.0,
	"thigh_L": deg_to_rad(4.0),
	"thigh_R": deg_to_rad(-4.0),
	"shin_L": 0.0, "shin_R": 0.0,
	"foot_L": deg_to_rad(90.0),   # 脚向前(+X)
	"foot_R": deg_to_rad(90.0),
	"torso": 0.0,
}

# ---- 关节活动范围 ROM（绝对局部角 [min,max]，弧度） ------------------------
# 铰链关节(肘/膝/踝)单向；球窝关节(肩/胯/颈)近似为锥形范围。
# 数值参考人体关节常规活动度，已适当放宽以适配 2D 演示。
const ROM := {
	# 颈：头相对躯干，可小幅前倾/后仰/侧倾
	"head": Vector2(deg_to_rad(130.0), deg_to_rad(230.0)),
	# 肩：上臂相对躯干（左右镜像）
	"upper_arm_L": Vector2(deg_to_rad(-180.0), deg_to_rad(30.0)),
	"upper_arm_R": Vector2(deg_to_rad(-30.0), deg_to_rad(180.0)),
	# 肘：前臂相对上臂，仅单向弯曲 0..150
	"fore_arm_L": Vector2(0.0, deg_to_rad(150.0)),
	"fore_arm_R": Vector2(0.0, deg_to_rad(150.0)),
	# 腕：手相对前臂 ±70
	"hand_L": Vector2(deg_to_rad(-70.0), deg_to_rad(70.0)),
	"hand_R": Vector2(deg_to_rad(-70.0), deg_to_rad(70.0)),
	# 胯：大腿相对躯干 ±100
	"thigh_L": Vector2(deg_to_rad(-100.0), deg_to_rad(100.0)),
	"thigh_R": Vector2(deg_to_rad(-100.0), deg_to_rad(100.0)),
	# 膝：小腿相对大腿，单向 0..150
	"shin_L": Vector2(0.0, deg_to_rad(150.0)),
	"shin_R": Vector2(0.0, deg_to_rad(150.0)),
	# 踝：脚相对小腿 40..140
	"foot_L": Vector2(deg_to_rad(40.0), deg_to_rad(140.0)),
	"foot_R": Vector2(deg_to_rad(40.0), deg_to_rad(140.0)),
	# 躯干：根，可小幅左右倾
	"torso": Vector2(deg_to_rad(-30.0), deg_to_rad(30.0)),
}

# ---- 形状与配色（仅用于基础框架可视化；接贴图后可移除） -------------------
const SHAPE := {
	"head": "circle",
	"torso": "capsule", "upper_arm": "capsule", "fore_arm": "capsule", "hand": "capsule",
	"thigh": "capsule", "shin": "capsule", "foot": "capsule",
}

const COLOR := {
	"torso": Color(0.20, 0.35, 0.60),   # 外套蓝
	"head": Color(0.95, 0.80, 0.70),    # 肤色
	"upper_arm": Color(0.20, 0.35, 0.60),
	"fore_arm": Color(0.95, 0.80, 0.70),
	"hand": Color(0.95, 0.80, 0.70),
	"thigh": Color(0.28, 0.28, 0.34),  # 裤
	"shin": Color(0.95, 0.80, 0.70),
	"foot": Color(0.15, 0.15, 0.18),   # 鞋
}
