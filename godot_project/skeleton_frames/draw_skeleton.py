import json, math, os
from PIL import Image

W, H = 360, 620
COLS, ROWS = 4, 4
root = os.path.dirname(os.path.abspath(__file__))

# 读取 poses.json
with open(os.path.join(root, "poses.json")) as f:
    line = f.read().strip()
assert line.startswith("POSEJSON ")
frames = json.loads(line[len("POSEJSON "):])
print("frames:", len(frames))

# 读取 rig spec（纹理 / pivot / flip / scale）
with open(os.path.join(root, "rig_sherlock_spec.json")) as f:
    spec = json.load(f)
spec_by_name = {b["name"]: b for b in spec["bones"]}

# 预加载纹理
tex_cache = {}
for b in spec["bones"]:
    tex_cache[b["name"]] = Image.open(b["tex"]).convert("RGBA")

# 绘制顺序（后→前）
DRAW_ORDER = ["thigh_L", "shin_L", "thigh_R", "shin_R", "torso", "hip",
              "neck", "upperarm_L", "forearm_L", "upperarm_R", "forearm_R",
              "head", "hat"]

def composite_bone(cell, bone_pose, name):
    if name not in spec_by_name:
        return
    sp = spec_by_name[name]
    piv = sp["pivot"]; flip = sp["flip"]; sc = sp["scale"]
    ox, oy, th = bone_pose["x"], bone_pose["y"], bone_pose["rot"]
    img = tex_cache[name]
    iw, ih = img.size
    c = math.cos(th); s = math.sin(th)
    if not flip:
        a = sc * c;  b = -sc * s
        d = sc * s;  e = sc * c
        cc = ox - sc * (c * piv[0] - s * piv[1])
        ff = oy - sc * (s * piv[0] + c * piv[1])
    else:
        a = sc * c;  b = sc * s
        d = sc * s;  e = -sc * c
        cc = ox - sc * (c * piv[0] + s * piv[1])
        ff = oy - sc * (s * piv[0] - c * piv[1])
    warped = img.transform((W, H), Image.AFFINE, (a, b, cc, d, e, ff),
                           resample=Image.BICUBIC)
    cell.paste(warped, (0, 0), warped)

grid = Image.new("RGB", (W * COLS, H * ROWS), (235, 237, 241))
for i, fr in enumerate(frames):
    if i >= COLS * ROWS:
        break
    ci, ri = i % COLS, i // COLS
    cell = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bones = {b["name"]: b for b in fr["bones"]}
    for nm in DRAW_ORDER:
        if nm in bones:
            composite_bone(cell, bones[nm], nm)
    cell_rgb = Image.new("RGB", (W, H), (235, 237, 241))
    cell_rgb.paste(cell, (0, 0), cell)
    from PIL import ImageDraw
    ImageDraw.Draw(cell_rgb).text((8, 6), "%s  t=%.2f" % (fr["anim"], fr["t"]), fill=(20, 20, 30))
    grid.paste(cell_rgb, (ci * W, ri * H))
grid.save(os.path.join(root, "contact_sheet.png"))
print("saved contact_sheet.png", grid.size)
