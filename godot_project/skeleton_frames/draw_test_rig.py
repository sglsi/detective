import json, math, os
from PIL import Image

W, H = 360, 620
COLS, ROWS = 4, 4
root = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(root)

# 读取 poses
with open(os.path.join(root, "poses_test_rig.json")) as f:
    line = f.read().strip()
assert line.startswith("POSEJSON ")
frames = json.loads(line[len("POSEJSON "):])
print("frames:", len(frames))

# 读取 rig spec
spec_path = os.path.join(project_root, "assets", "characters", "test_rig_character", "rig", "_rig_spec.json")
with open(spec_path) as f:
    spec = json.load(f)
spec_by_name = {b["name"]: b for b in spec["bones"]}

# 解析 res:// 路径为绝对路径
parts_dir = spec["parts_dir"]
if parts_dir.startswith("res://"):
    parts_dir = os.path.join(project_root, parts_dir[len("res://"):].replace("/", os.sep))

# 预加载纹理
tex_cache = {}
for b in spec["bones"]:
    tex = b["tex"]
    if tex:
        path = os.path.join(parts_dir, tex)
        tex_cache[b["name"]] = Image.open(path).convert("RGBA")
    else:
        tex_cache[b["name"]] = None

# 绘制顺序（后→前）：腿 → 躯干 → 手臂 → 头
DRAW_ORDER = ["thigh_L", "shin_L", "thigh_R", "shin_R", "torso", "hip",
              "neck", "upperarm_L", "forearm_L", "upperarm_R", "forearm_R",
              "head"]

def composite_bone(cell, bone_pose, name):
    if name not in spec_by_name:
        return
    sp = spec_by_name[name]
    img = tex_cache.get(name)
    if img is None:
        return
    piv = sp["pivot"]
    sc = sp["scale"]
    ox, oy, th = bone_pose["x"], bone_pose["y"], bone_pose["rot"]
    c = math.cos(th); s = math.sin(th)

    # PIL AFFINE: 输出像素 (x,y) 到输入像素 (x',y') 的映射。
    # 我们要让纹理在输出中呈现 "缩放 sc、旋转 +th"，因此输出→输入需要
    # 缩放 1/sc、旋转 -th。
    a =  c / sc
    b =  s / sc
    d = -s / sc
    e =  c / sc
    cc = piv[0] - (c * ox + s * oy) / sc
    ff = piv[1] - (-s * ox + c * oy) / sc

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
out_path = os.path.join(root, "contact_sheet_test_rig.png")
grid.save(out_path)
print("saved", out_path, grid.size)
