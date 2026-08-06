from PIL import Image, ImageDraw
import os, math

SRC = "D:\\AI\\detective\\godot_project\\assets\\sherlock_parts\\sherlock_clean.png"
OUT_DIR = "D:\\AI\\detective\\godot_project\\assets\\sherlock_parts"
IMG = Image.open(SRC).convert("RGBA")
W, H = IMG.size

u_px = H / 8.0
CX = W / 2.0

L = {"head":1.0, "torso":2.5, "upper_arm":1.3, "fore_arm":1.1, "hand":0.8,
     "thigh":1.9, "shin":1.7, "foot":0.45}
Wdt = {"head":0.72, "torso":0.95, "upper_arm":0.30, "fore_arm":0.24, "hand":0.22,
       "thigh":0.38, "shin":0.28, "foot":0.34}

# 全局关节坐标（像素）
neck_y = L["head"]*u_px
shoulder_y = neck_y + 0.18*u_px
shoulder_dx = 0.52*u_px
elbow_y = shoulder_y + L["upper_arm"]*u_px
wrist_y = elbow_y + L["fore_arm"]*u_px
finger_y = wrist_y + L["hand"]*u_px
hip_y = neck_y + L["torso"]*u_px
knee_y = hip_y + L["thigh"]*u_px
ankle_y = knee_y + L["shin"]*u_px
toe_y = ankle_y + L["foot"]*u_px

# 从视觉估算的肢体外张角（度；0=垂直向下，正=顺时针/右，负=逆时针/左）
ANG = {
    "upper_arm_L": -26, "upper_arm_R": 26,
    "fore_arm_L": -18,  "fore_arm_R": 18,
    "hand_L": -12,      "hand_R": 12,
    "thigh_L": -6,      "thigh_R": 6,
    "shin_L": -2,       "shin_R": 2,
    "foot_L": -85,      "foot_R": 85,
}

def pt_from(p, deg, dist):
    rad = math.radians(deg)
    return (p[0] + math.sin(rad)*dist, p[1] + math.cos(rad)*dist)

def extract_straight(p1, p2, width, pad=4):
    """以 p1 为顶部中心，沿 p1->p2 方向切出矩形，再旋转拉直。
       返回的贴图：顶部中心=(p1)，+Y 向下，长度=|p1-p2|。"""
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dx, dy))  # 正=顺时针偏离垂直
    # 旋转原图使肢体垂直（以 p1 为中心）
    rotated = IMG.rotate(-angle, resample=Image.Resampling.BICUBIC,
                         expand=False, center=p1, fillcolor=(0,0,0,0))
    x1 = int(p1[0] - width/2 - pad)
    y1 = int(p1[1] - pad)
    x2 = int(p1[0] + width/2 + pad)
    y2 = int(p1[1] + length + pad)
    return rotated.crop((max(0,x1), max(0,y1), min(W,x2), min(H,y2)))

# 关节点
J = {
    "head_top": (CX, 0),
    "neck":     (CX, neck_y),
    "shoulder_L": (CX - shoulder_dx, shoulder_y),
    "shoulder_R": (CX + shoulder_dx, shoulder_y),
    "hip_L":    (CX - 0.20*u_px, hip_y),
    "hip_R":    (CX + 0.20*u_px, hip_y),
}
# 由角度推算远端关节
J["elbow_L"] = pt_from(J["shoulder_L"], ANG["upper_arm_L"], L["upper_arm"]*u_px)
J["elbow_R"] = pt_from(J["shoulder_R"], ANG["upper_arm_R"], L["upper_arm"]*u_px)
J["wrist_L"] = pt_from(J["elbow_L"], ANG["fore_arm_L"], L["fore_arm"]*u_px)
J["wrist_R"] = pt_from(J["elbow_R"], ANG["fore_arm_R"], L["fore_arm"]*u_px)
J["finger_L"] = pt_from(J["wrist_L"], ANG["hand_L"], L["hand"]*u_px)
J["finger_R"] = pt_from(J["wrist_R"], ANG["hand_R"], L["hand"]*u_px)
J["knee_L"]  = pt_from(J["hip_L"], ANG["thigh_L"], L["thigh"]*u_px)
J["knee_R"]  = pt_from(J["hip_R"], ANG["thigh_R"], L["thigh"]*u_px)
J["ankle_L"] = pt_from(J["knee_L"], ANG["shin_L"], L["shin"]*u_px)
J["ankle_R"] = pt_from(J["knee_R"], ANG["shin_R"], L["shin"]*u_px)
J["toe_L"]   = pt_from(J["ankle_L"], ANG["foot_L"], L["foot"]*u_px)
J["toe_R"]   = pt_from(J["ankle_R"], ANG["foot_R"], L["foot"]*u_px)

segments = {
    # name: (p1 近端, p2 远端, 宽度)
    "torso":      (J["neck"], (CX, hip_y), Wdt["torso"]*u_px),
    "head":       (J["neck"], J["head_top"], Wdt["head"]*u_px),
    "upper_arm_L":(J["shoulder_L"], J["elbow_L"], Wdt["upper_arm"]*u_px),
    "upper_arm_R":(J["shoulder_R"], J["elbow_R"], Wdt["upper_arm"]*u_px),
    "fore_arm_L": (J["elbow_L"], J["wrist_L"], Wdt["fore_arm"]*u_px),
    "fore_arm_R": (J["elbow_R"], J["wrist_R"], Wdt["fore_arm"]*u_px),
    "hand_L":     (J["wrist_L"], J["finger_L"], Wdt["hand"]*u_px),
    "hand_R":     (J["wrist_R"], J["finger_R"], Wdt["hand"]*u_px),
    "thigh_L":    (J["hip_L"], J["knee_L"], Wdt["thigh"]*u_px),
    "thigh_R":    (J["hip_R"], J["knee_R"], Wdt["thigh"]*u_px),
    "shin_L":     (J["knee_L"], J["ankle_L"], Wdt["shin"]*u_px),
    "shin_R":     (J["knee_R"], J["ankle_R"], Wdt["shin"]*u_px),
    "foot_L":     (J["ankle_L"], J["toe_L"], Wdt["foot"]*u_px),
    "foot_R":     (J["ankle_R"], J["toe_R"], Wdt["foot"]*u_px),
}

for name, (p1, p2, w) in segments.items():
    img = extract_straight(p1, p2, w)
    img.save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"saved {name}.png size={img.size}")

# 预览：画出关节点与切分线
preview = IMG.copy()
draw = ImageDraw.Draw(preview, "RGBA")
for k, v in J.items():
    draw.ellipse([v[0]-4, v[1]-4, v[0]+4, v[1]+4], fill="red")
    draw.text((v[0]+6, v[1]-6), k, fill="red")
for name, (p1, p2, w) in segments.items():
    draw.line([p1, p2], fill="cyan", width=2)
preview.save(os.path.join(OUT_DIR, "_joints_preview.png"))
print("saved _joints_preview.png")
