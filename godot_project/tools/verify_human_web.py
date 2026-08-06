"""离线复刻网页版人体 FK 与走/跑/跳/站立姿态，渲染 2x2 验证图。
与 web_preview/human_skeleton_preview.html 使用同源规范，仅用于静态核对几何。"""
from PIL import Image, ImageDraw, ImageFont
import math
from pathlib import Path

PX = 52
L = dict(head=1.0, torso=2.5, upper_arm=1.3, fore_arm=1.1, hand=0.8, thigh=1.9, shin=1.7, foot=0.45)
W = dict(head=0.72, torso=0.95, upper_arm=0.30, fore_arm=0.24, hand=0.22, thigh=0.38, shin=0.28, foot=0.34)
ANCHORS = {
    "head":[0,0],
    "upper_arm_L":[-0.52,0.18], "upper_arm_R":[0.52,0.18],
    "fore_arm_L":[0,L["upper_arm"]], "fore_arm_R":[0,L["upper_arm"]],
    "hand_L":[0,L["fore_arm"]], "hand_R":[0,L["fore_arm"]],
    "thigh_L":[-0.20,L["torso"]], "thigh_R":[0.20,L["torso"]],
    "shin_L":[0,L["thigh"]], "shin_R":[0,L["thigh"]],
    "foot_L":[0,L["shin"]], "foot_R":[0,L["shin"]],
}
PARENT = {"torso":None,"head":"torso","upper_arm_L":"torso","upper_arm_R":"torso",
    "fore_arm_L":"upper_arm_L","fore_arm_R":"upper_arm_R","hand_L":"fore_arm_L","hand_R":"fore_arm_R",
    "thigh_L":"torso","thigh_R":"torso","shin_L":"thigh_L","shin_R":"thigh_R",
    "foot_L":"shin_L","foot_R":"shin_R"}
REST = dict(torso=0,head=180,upper_arm_L=-10,upper_arm_R=10,fore_arm_L=0,fore_arm_R=0,
    hand_L=0,hand_R=0,thigh_L=4,thigh_R=-4,shin_L=0,shin_R=0,foot_L=90,foot_R=90)
ROM = {"head":[130,230],"upper_arm_L":[-180,30],"upper_arm_R":[-30,180],
    "fore_arm_L":[0,150],"fore_arm_R":[0,150],"hand_L":[-70,70],"hand_R":[-70,70],
    "thigh_L":[-100,100],"thigh_R":[-100,100],"shin_L":[0,150],"shin_R":[0,150],
    "foot_L":[40,140],"foot_R":[40,140],"torso":[-30,30]}
COLOR = {"torso":(0.20,0.35,0.60),"head":(0.95,0.80,0.70),"upper_arm":(0.20,0.35,0.60),
    "fore_arm":(0.95,0.80,0.70),"hand":(0.95,0.80,0.70),"thigh":(0.28,0.28,0.34),
    "shin":(0.95,0.80,0.70),"foot":(0.15,0.15,0.18)}
SHAPE = {"head":"circle"}
ORDER = ["torso","head","upper_arm_L","upper_arm_R","fore_arm_L","fore_arm_R","hand_L","hand_R",
    "thigh_L","thigh_R","shin_L","shin_R","foot_L","foot_R"]
BONES = {}
for _id in ORDER:
    t = _id.replace("_L","").replace("_R","")
    BONES[_id] = dict(parent=PARENT[_id], anchor=[ANCHORS.get(_id,[0,0])[0]*PX, ANCHORS.get(_id,[0,0])[1]*PX],
        length=L[t]*PX, width=W[t]*PX, rest=REST[_id], rom=ROM[_id], color=COLOR[t],
        shape=SHAPE.get(t,"capsule"))


def compute_pose(moving, running, on_ground, phase, t, facing):
    off = {_id:0.0 for _id in ORDER}
    if not on_ground:
        off["thigh_L"]=-70; off["thigh_R"]=-70; off["shin_L"]=72; off["shin_R"]=72
        off["upper_arm_L"]=-55; off["upper_arm_R"]=55; off["fore_arm_L"]=40; off["fore_arm_R"]=40
        off["foot_L"]=105; off["foot_R"]=105; off["torso"]=6*facing
        return off, "jump"
    if moving:
        amp = 40 if running else 26; armAmp = 32 if running else 18
        kneeBend = 58 if running else 38; th = phase*math.pi*2
        off["thigh_L"]=amp*math.sin(th); off["thigh_R"]=amp*math.sin(th+math.pi)
        off["shin_L"]=kneeBend*max(0,math.sin(th+math.pi)); off["shin_R"]=kneeBend*max(0,math.sin(th))
        off["upper_arm_L"]=armAmp*math.sin(th+math.pi); off["upper_arm_R"]=armAmp*math.sin(th)
        off["fore_arm_L"]=60 if running else 26; off["fore_arm_R"]=60 if running else 26
        off["torso"]=(13 if running else 3)*facing
        return off, ("run" if running else "walk")
    off["torso"]=2*math.sin(t*1.4); off["head"]=1.5*math.sin(t*1.1)
    off["upper_arm_L"]=3*math.sin(t*1.4); off["upper_arm_R"]=3*math.sin(t*1.4+0.6)
    return off, "idle"


def fk(rootx, rooty, off):
    ang = {}; world = {}
    for _id in ORDER:
        a = math.radians(BONES[_id]["rest"] + off[_id])
        lo, hi = BONES[_id]["rom"]; a = max(math.radians(lo), min(math.radians(hi), a))
        ang[_id] = a
    for _id in ORDER:
        b = BONES[_id]
        if b["parent"] is None:
            px, py, pa = rootx, rooty, ang[_id]
        else:
            p = world[b["parent"]]; pa = p["a"] + ang[_id]
            c, s = math.cos(p["a"]), math.sin(p["a"])
            ax, ay = b["anchor"]
            rx = ax*c - ay*s; ry = ax*s + ay*c
            px, py = p["x"]+rx, p["y"]+ry
        c, s = math.cos(pa), math.sin(pa)
        tx = px + 0*c - b["length"]*s; ty = px*0 + py + b["length"]*c
        world[_id] = dict(x=px, y=py, a=pa, tx=tx, ty=ty)
    return world


def draw_cell(draw, ox, ground_y, off, label):
    world = fk(0, 0, off)
    pts = []
    for _id in ORDER:
        w = world[_id]; pts.append((w["x"],w["y"])); pts.append((w["tx"],w["ty"]))
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    minx, maxx = min(xs), max(xs); miny, maxy = min(ys), max(ys)
    cx = ox - (minx+maxx)/2
    cy = ground_y - maxy                  # 让脚底贴合单元格底部
    order = ["thigh_R","shin_R","foot_R","upper_arm_R","fore_arm_R","hand_R","torso","head",
             "thigh_L","shin_L","foot_L","upper_arm_L","fore_arm_L","hand_L"]
    for _id in order:
        b = BONES[_id]; w = world[_id]
        X1, Y1 = cx+w["x"], cy+w["y"]; X2, Y2 = cx+w["tx"], cy+w["ty"]
        c = tuple(int(255*v) for v in b["color"])
        if b["shape"] == "circle":
            r = b["width"]*0.62
            mx, my = (X1+X2)/2, (Y1+Y2)/2
            draw.ellipse([mx-r,my-r,mx+r,my+r], fill=c, outline=(0,0,0))
        else:
            lw = max(3, int(b["width"]))
            draw.line([X1,Y1,X2,Y2], fill=c, width=lw)
    for _id in ORDER:
        w = world[_id]; draw.ellipse([cx+w["x"]-3,cy+w["y"]-3,cx+w["x"]+3,cy+w["y"]+3], fill=(127,212,255))
    draw.text((cx-80, ground_y-cell+24), label, fill=(230,235,242), font=font)


frames = [
    ("站立 idle", compute_pose(False,False,True,0,1.0,1)[0]),
    ("行走 walk", compute_pose(True,False,True,0.25,0,1)[0]),
    ("奔跑 run", compute_pose(True,True,True,0.25,0,1)[0]),
    ("跳跃 jump", compute_pose(False,False,False,0,0,1)[0]),
]
cell = 400
img = Image.new("RGB",(cell*2, cell*2),(14,17,22))
d = ImageDraw.Draw(img)
font_paths = [
    Path("C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
    Path("assets/fonts/simhei.ttf"),
]
font = None
for fp in font_paths:
    if fp.exists():
        try:
            font = ImageFont.truetype(str(fp), 22)
            break
        except Exception:
            pass
if font is None:
    font = ImageFont.load_default()
# 地面线
for r in range(2):
    for c in range(2):
        ox = c*cell + cell//2
        ground_y = r*cell + cell - 14
        draw_cell(d, ox, ground_y, frames[r*2+c][1], frames[r*2+c][0])
        # 地面
        d.line([c*cell, ground_y, c*cell+cell, ground_y], fill=(43,54,69), width=2)
img.save("skeleton_frames/human_web_verify.png")
print("saved skeleton_frames/human_web_verify.png")
