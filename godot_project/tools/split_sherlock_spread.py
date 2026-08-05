#!/usr/bin/env python3
"""把福尔摩斯 A-pose 张开图（四肢张开、正面）按坐标区域拆成 10 个绑骨部件。

策略：张开图是「星型」（双臂在 y307-552 张开到 x202/822，双腿在 y614 以下），
四肢与躯干在肩/胯处相连，无法用连通块自动分离。改为按实测包围盒做区域硬切：
每个部件取一个矩形框，框内只保留前景像素（透明处留透明），重叠区由躯干盖住。
记录每个部件在原图中的 src_bbox，便于后续精确复原/拼回验证。

输出：
  assets/characters/sherlock_spread/rig/{head,torso,upperarm_L,upperarm_R,
      forearm_L,forearm_R,thigh_L,thigh_R,shin_L,shin_R}.png
  assets/characters/sherlock_spread/rig/_rig_spec.json   (标准技能格式 + src_bbox)
  assets/characters/sherlock_spread/rig/_parts_grid.png   (10 部件独立预览)
  assets/characters/sherlock_spread/rig/_reassembled.png  (按原坐标拼回验证)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis\sherlock_spread_transparent.png")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock_spread\rig")
RIG_JSON = OUT_DIR / "_rig_spec.json"
PADDING = 0  # 贴边裁切，避免透明边淹没 GAP
CENTER_X = 512  # 实测身体中轴

# 各部件在原图中的包围盒 (x0, y0, x1, y1)，含少量与相邻部件的重叠（重叠区由绘制顺序盖住）
# 依据 y-band 扫描：头 y16-190(中心x513)；肩 y184-307；臂张开 y307-552(x202/822)；
# 胯 y552-614；腿 y614 以下（左 x290-512 / 右 x512-735）
BOXES = {
    "head":       (430, 10, 600, 200),
    "torso":      (392, 195, 632, 625),
    "upperarm_L": (178, 198, 408, 398),
    "forearm_L":  (168, 372, 362, 588),
    "upperarm_R": (616, 198, 846, 398),   # 镜像：2*512 - 左框
    "forearm_R":  (662, 372, 856, 588),
    "thigh_L":    (288, 612, 512, 832),
    "shin_L":     (288, 808, 512, 1008),
    "thigh_R":    (512, 612, 736, 832),
    "shin_R":     (512, 808, 736, 1008),
}


def main() -> int:
    if not SRC.exists():
        print(f"[ERR] source not found: {SRC}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    W, H = img.size
    arr = np.array(img)

    parts: dict[str, dict] = {}
    for name, (x0, y0, x1, y1) in BOXES.items():
        x0 = max(0, x0 - PADDING)
        y0 = max(0, y0 - PADDING)
        x1 = min(W - 1, x1 + PADDING)
        y1 = min(H - 1, y1 + PADDING)
        crop = img.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGBA")
        ca = np.array(crop)
        # 只保留前景（alpha>128），背景变透明
        fg = ca[:, :, 3] > 128
        out = ca.copy()
        out[~fg] = (0, 0, 0, 0)
        crop = Image.fromarray(out, "RGBA")
        # 裁剪到内容包围盒（去掉全透明边），但保留原图坐标信息用于复原
        cys, cxs = np.where(fg)
        if len(cxs) == 0:
            print(f"  [WARN] {name}: empty box, skip")
            continue
        # 内容在 crop 内的局部坐标
        lx0, ly0 = int(cxs.min()), int(cys.min())
        lx1, ly1 = int(cxs.max()), int(cys.max())
        tight = crop.crop((lx0, ly0, lx1 + 1, ly1 + 1))
        tight.save(OUT_DIR / f"{name}.png")
        src_bbox = [x0 + lx0, y0 + ly0, x0 + lx1, y0 + ly1]  # 在原图中的实际内容框
        parts[name] = {
            "filename": f"{name}.png",
            "size": [tight.width, tight.height],
            "src_bbox": src_bbox,
        }
        print(f"  -> {name}: tight {tight.width}x{tight.height}  src_bbox={src_bbox}")

    # 生成 rig spec（标准技能格式：bones 数组 + parts_dir）
    spec = build_rig_spec(parts)
    RIG_JSON.write_text(json.dumps(spec, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[INFO] rig spec -> {RIG_JSON}")

    # 预览：部件独立网格 + 按原坐标拼回
    make_previews(img, parts)
    return 0


def build_rig_spec(parts: dict) -> dict:
    def sz(k):
        return parts[k]["size"] if k in parts else [0, 0]

    torso_w, torso_h = sz("torso")
    head_w, head_h = sz("head")
    world_scale = 110.0 / max(torso_h, 1.0)

    spec = {
        "character": "sherlock_spread",
        "parts_dir": "res://assets/characters/sherlock_spread/rig/",
        "scale": world_scale,
        "bones": [],
    }

    def add(name, parent, pos, rot, tex, color):
        sp = parts.get(name)
        w, h = (sp["size"] if sp else [0, 0])
        spec["bones"].append({
            "name": name, "parent": parent,
            "pos": [pos[0], pos[1]], "rot": rot,
            "len": h * world_scale, "wid": w * world_scale,
            "dir": 1, "color": color,
            "tex": (f"{name}.png" if sp else ""),
            "pivot": [w / 2, h * 0.1] if sp else [0, 0],
            "scale": world_scale,
            "src_bbox": sp["src_bbox"] if sp else None,
        })

    skin = [0.86, 0.70, 0.55]
    pants = [0.12, 0.12, 0.16]
    # 以 A-pose 静止姿态摆放（部件纹理已是张开角度，rest rot 设为其自然角）
    add("torso", "", [0, 0], 0, "torso.png", skin)
    add("head", "torso", [0, -torso_h * world_scale * 0.42], 0, "head.png", skin)
    add("upperarm_L", "torso", [-torso_w * 0.32 * world_scale, torso_h * world_scale * 0.05], -32, "upperarm_L.png", skin)
    add("forearm_L", "upperarm_L", [0, sz("upperarm_L")[1] * world_scale], -32, "forearm_L.png", skin)
    add("upperarm_R", "torso", [torso_w * 0.32 * world_scale, torso_h * world_scale * 0.05], 32, "upperarm_R.png", skin)
    add("forearm_R", "upperarm_R", [0, sz("upperarm_R")[1] * world_scale], 32, "forearm_R.png", skin)
    add("thigh_L", "torso", [-torso_w * 0.18 * world_scale, torso_h * world_scale * 0.92], 6, "thigh_L.png", pants)
    add("shin_L", "thigh_L", [0, sz("thigh_L")[1] * world_scale], 0, "shin_L.png", skin)
    add("thigh_R", "torso", [torso_w * 0.18 * world_scale, torso_h * world_scale * 0.92], -6, "thigh_R.png", pants)
    add("shin_R", "thigh_R", [0, sz("thigh_R")[1] * world_scale], 0, "shin_R.png", skin)
    return spec


def make_previews(src_img: Image.Image, parts: dict) -> None:
    # 1) 部件独立网格
    names = ["head", "torso", "upperarm_L", "upperarm_R", "forearm_L", "forearm_R",
             "thigh_L", "thigh_R", "shin_L", "shin_R"]
    cell = 260
    cols = 5
    grid = Image.new("RGBA", (cell * cols, cell * 2), (0, 0, 0, 0))
    from PIL import ImageDraw
    d = ImageDraw.Draw(grid)
    for i, nm in enumerate(names):
        if nm not in parts:
            continue
        p = Image.open(OUT_DIR / parts[nm]["filename"]).convert("RGBA")
        # 等比缩放到 cell 内
        sc = min(cell / p.width, cell / p.height, 1.0) * 0.92
        p = p.resize((max(1, int(p.width * sc)), max(1, int(p.height * sc))), Image.LANCZOS)
        ox = (i % cols) * cell + (cell - p.width) // 2
        oy = (i // cols) * cell + (cell - p.height) // 2
        grid.paste(p, (ox, oy), p)
        d.text((ox, oy), nm, fill=(220, 80, 40, 255))
    grid.convert("RGB").save(OUT_DIR / "_parts_grid.png")
    print(f"[INFO] preview -> {OUT_DIR / '_parts_grid.png'}")

    # 2) 按原图坐标拼回（验证各部件是否无缝复原）
    reassembled = Image.new("RGBA", src_img.size, (0, 0, 0, 0))
    # 绘制顺序：腿→躯干→手臂→头（后画者在上）
    order = ["shin_L", "shin_R", "thigh_L", "thigh_R", "torso",
             "upperarm_L", "upperarm_R", "forearm_L", "forearm_R", "head"]
    for nm in order:
        if nm not in parts:
            continue
        sp = parts[nm]
        p = Image.open(OUT_DIR / sp["filename"]).convert("RGBA")
        bx, by = sp["src_bbox"][0], sp["src_bbox"][1]
        reassembled.paste(p, (bx, by), p)
    reassembled.convert("RGB").save(OUT_DIR / "_reassembled.png")
    print(f"[INFO] reassembled -> {OUT_DIR / '_reassembled.png'}")


if __name__ == "__main__":
    sys.exit(main())
