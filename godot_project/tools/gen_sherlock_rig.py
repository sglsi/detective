#!/usr/bin/env python3
"""根据已抠图并紧裁的 rig 部件，生成福尔摩斯骨架定义。
输出：
  - scripts/rig/sherlock_rig.gd        (Godot 可用 const DEF，供 build_from_def)
  - skeleton_frames/rig_sherlock_spec.json  (供 draw_skeleton.py 离屏合成预览)
设计：自上而下骨架，每个骨 origin=近端关节，向 +Y(下) 延伸至远端；无需翻转级联。
"""
import os, json, glob
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RIG_PNG = os.path.join(ROOT, "assets", "characters", "sherlock", "rig")
SPEC_OUT = os.path.join(ROOT, "skeleton_frames", "rig_sherlock_spec.json")
GD_OUT = os.path.join(ROOT, "scripts", "rig", "sherlock_rig.gd")

# 颜色（与 skeleton_character._demo_def 对齐）
SKIN = (0.86, 0.70, 0.55)
COAT = (0.16, 0.18, 0.26)
COAT_L = (0.24, 0.26, 0.36)
HATC = (0.55, 0.42, 0.28)
PANTS = (0.12, 0.12, 0.16)

def load_h(name):
    p = os.path.join(RIG_PNG, "sherlock_%s.png" % name)
    im = Image.open(p).convert("RGBA")
    return im, im.size[1]

def proximal_pivot_x(im, bottom=False, frac=0.06):
    """近端关节的水平中心：默认取顶部若干行质心；hat 取底部。"""
    w, h = im.size
    a = im.split()[3]
    px = a.load()
    band = int(h * frac) + 1
    if bottom:
        y0, y1 = h - band, h
    else:
        y0, y1 = 0, band
    xs = []
    for y in range(y0, y1):
        for x in range(w):
            if px[x, y] > 30:
                xs.append(x)
    if not xs:
        return w / 2
    return sum(xs) / len(xs)

# 骨拓扑：(name, parent, pos(x,y), rot_deg, len, wid, dir, color, tex_suffix or "", is_hat)
BONES = [
    ("head",       "",        (0, 0),    0,   80, 46, -1, SKIN,  "head",       False),
    ("neck",       "head",    (0, 80),   0,   18, 14, -1, SKIN,  "",           False),
    ("torso",      "neck",    (0, 18),   0,  110, 42, -1, COAT,  "torso",      False),
    ("hip",        "torso",   (0, 110),  0,   16, 30, -1, PANTS, "",           False),
    ("shoulder_L", "torso",   (-22, 10), 0,    6, 14, -1, COAT,  "",           False),
    ("upperarm_L", "shoulder_L", (0, 0), 70,  60, 16,  1, COAT_L,"upperarm_L", False),
    ("forearm_L",  "upperarm_L", (0, 60), 8,  55, 13,  1, SKIN,  "forearm_L",  False),
    ("shoulder_R", "torso",   (22, 10),  0,    6, 14, -1, COAT,  "",           False),
    ("upperarm_R", "shoulder_R", (0, 0), -70, 60, 16,  1, COAT_L,"upperarm_R", False),
    ("forearm_R",  "upperarm_R", (0, 60), -8, 55, 13,  1, SKIN,  "forearm_R",  False),
    ("thigh_L",    "hip",     (-16, 6),  0,   80, 22,  1, PANTS, "thigh_L",    False),
    ("shin_L",     "thigh_L", (0, 80),   0,   80, 17,  1, COAT_L,"shin_L",     False),
    ("thigh_R",    "hip",     (16, 6),   0,   80, 22,  1, PANTS, "thigh_R",    False),
    ("shin_R",     "thigh_R", (0, 80),   0,   80, 17,  1, COAT_L,"shin_R",     False),
    ("hat",        "head",    (0, 0),    180, 34, 64, -1, HATC,  "hat",        True),
]

def color_str(c):
    return "Color(%.2f,%.2f,%.2f)" % c

spec = {"bones": []}
gd_bones = []

for (name, parent, pos, rot, length, wid, d, col, tex, is_hat) in BONES:
    if tex:
        im, H = load_h(tex)
        piv_x = proximal_pivot_x(im, bottom=is_hat)
        scale = float(length) / H
        pivot = (piv_x, H if is_hat else 0.0)
        tex_path = "res://assets/characters/sherlock/rig/sherlock_%s.png" % tex
        # spec for compositor (absolute image path, original-image pivot, flip)
        spec["bones"].append({
            "name": name, "tex": os.path.join(RIG_PNG, "sherlock_%s.png" % tex),
            "pivot": [piv_x, H if is_hat else 0.0], "flip": is_hat, "scale": scale,
        })
    else:
        tex_path = ""
        pivot = (0.0, 0.0)
        scale = 1.0
    gd = ('\t\t{"name":"%s","parent":"%s","pos":Vector2(%g,%g),"rot":%g,"len":%g,'
          '"wid":%g,"dir":%g,"color":%s,"tex":"%s","pivot":Vector2(%g,%g),"scale":%g}'
          % (name, parent, pos[0], pos[1], rot, length, wid, d, color_str(col),
             tex_path, pivot[0], pivot[1], scale))
    gd_bones.append(gd)

bones_str = ",\n".join(gd_bones)
gd_text = (
    "# 自动生成：tools/gen_sherlock_rig.py —— 福尔摩斯绑骨定义\n"
    "class_name SherlockRig\n"
    "const DEF := {\n"
    '\t"bones": [\n'
    + bones_str + "\n"
    + "\t]\n"
    "}\n"
    "static func get() -> Dictionary:\n"
    "\treturn DEF\n"
)
os.makedirs(os.path.dirname(GD_OUT), exist_ok=True)
with open(GD_OUT, "w", encoding="utf-8") as f:
    f.write(gd_text)
with open(SPEC_OUT, "w", encoding="utf-8") as f:
    json.dump(spec, f, ensure_ascii=False, indent=2)
print("wrote", GD_OUT)
print("wrote", SPEC_OUT, "textured bones:", len(spec["bones"]))
for b in spec["bones"]:
    print("  %-12s pivot=%s scale=%.4f flip=%s" % (b["name"], [round(v,1) for v in b["pivot"]], b["scale"], b["flip"]))
