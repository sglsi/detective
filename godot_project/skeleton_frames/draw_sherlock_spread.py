import json, math, os
from PIL import Image

COLS = 4
root = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(root)

# 读取 poses
with open(os.path.join(root, "poses_sherlock_spread.json")) as f:
    line = f.read().strip()
assert line.startswith("POSEJSON ")
frames = json.loads(line[len("POSEJSON "):])
print("frames:", len(frames))

# 读取 rig spec
spec_path = os.path.join(project_root, "assets", "characters", "sherlock_spread", "rig", "_rig_spec.json")
with open(spec_path) as f:
    spec = json.load(f)
spec_by_name = {b["name"]: b for b in spec["bones"]}

# 解析 res:// 路径为绝对路径
parts_dir = spec["parts_dir"]
if parts_dir.startswith("res://"):
    parts_dir = os.path.join(project_root, parts_dir[len("res://"):].replace("/", os.sep))

# 预加载纹理
tex_cache = {}
max_tex_radius = 0.0
for b in spec["bones"]:
    tex = b["tex"]
    if tex:
        path = os.path.join(parts_dir, tex)
        img = Image.open(path).convert("RGBA")
        tex_cache[b["name"]] = img
        r = max(img.width, img.height) * b["scale"] * 0.5
        max_tex_radius = max(max_tex_radius, r)
    else:
        tex_cache[b["name"]] = None

print(f"max texture radius: {max_tex_radius:.1f}")

# 绘制顺序（后→前）
DRAW_ORDER = ["thigh_L", "shin_L", "thigh_R", "shin_R", "hip", "torso",
              "neck", "shoulder_L", "upperarm_L", "forearm_L",
              "shoulder_R", "upperarm_R", "forearm_R", "head"]


def frame_position_bounds(fr):
    """仅用骨骼世界位置（不含纹理尺寸）计算 AABB。"""
    min_x = min(b["x"] for b in fr["bones"])
    min_y = min(b["y"] for b in fr["bones"])
    max_x = max(b["x"] for b in fr["bones"])
    max_y = max(b["y"] for b in fr["bones"])
    return min_x, min_y, max_x, max_y


# 用骨骼位置 AABB + 纹理半径边距决定单元格大小
MARGIN = int(math.ceil(max_tex_radius * 2.5)) + 8
global_min_x, global_min_y, global_max_x, global_max_y = 1e9, 1e9, -1e9, -1e9
for fr in frames:
    mn_x, mn_y, mx_x, mx_y = frame_position_bounds(fr)
    global_min_x = min(global_min_x, mn_x)
    global_min_y = min(global_min_y, mn_y)
    global_max_x = max(global_max_x, mx_x)
    global_max_y = max(global_max_y, mx_y)

W = int(math.ceil(global_max_x - global_min_x)) + MARGIN * 2
H = int(math.ceil(global_max_y - global_min_y)) + MARGIN * 2
print(f"auto cell size: {W}x{H}  margin: {MARGIN}")

ROWS = (len(frames) + COLS - 1) // COLS


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
    iw, ih = img.size
    c = math.cos(th)
    s = math.sin(th)

    a = c / sc
    b = s / sc
    d = -s / sc
    e = c / sc
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

    # 居中：用本帧骨骼位置 AABB 的中心
    mn_x, mn_y, mx_x, mx_y = frame_position_bounds(fr)
    cx = (mn_x + mx_x) / 2.0
    cy = (mn_y + mx_y) / 2.0
    offset_x = W / 2.0 - cx
    offset_y = H / 2.0 - cy

    bones = {b["name"]: b for b in fr["bones"]}
    for nm in DRAW_ORDER:
        if nm in bones:
            bpose = bones[nm].copy()
            bpose["x"] += offset_x
            bpose["y"] += offset_y
            composite_bone(cell, bpose, nm)
    cell_rgb = Image.new("RGB", (W, H), (235, 237, 241))
    cell_rgb.paste(cell, (0, 0), cell)
    from PIL import ImageDraw
    ImageDraw.Draw(cell_rgb).text((8, 6), "%s  t=%.2f" % (fr["anim"], fr["t"]), fill=(20, 20, 30))
    grid.paste(cell_rgb, (ci * W, ri * H))
out_path = os.path.join(root, "contact_sheet_sherlock_spread.png")
grid.save(out_path)
print("saved", out_path, grid.size)
