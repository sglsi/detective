#!/usr/bin/env python3
"""把福尔摩斯 A-pose 张开图按坐标区域拆成 10 个绑骨部件，并保留关节重叠。

策略：张开图四肢与躯干在肩/胯处相连，无法用连通块自动分离。改用坐标框硬切，
但每个部件的矩形框向相邻部件外延 12-20px，使得部件在关节处保留重叠像素；
这样旋转时缝隙被重叠区盖住。输出部件保存为完整框（含透明边），以便 pivot
可以直接用框内关节坐标，无需再 tight 换算。

输出：
  assets/characters/sherlock_spread/rig/{head,torso,upperarm_L,upperarm_R,
      forearm_L,forearm_R,thigh_L,thigh_R,shin_L,shin_R}.png
  assets/characters/sherlock_spread/rig/_rig_spec.json
  assets/characters/sherlock_spread/rig/_parts_grid.png
  assets/characters/sherlock_spread/rig/_reassembled.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis\sherlock_spread_transparent.png")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock_spread\rig")
RIG_JSON = OUT_DIR / "_rig_spec.json"
CENTER_X = 512

# 各部件在原图中的核心区域 (x0, y0, x1, y1)。
# 关节处会额外外延 OVERLAP，使相邻部件共享像素，旋转时盖住缝隙。
OVERLAP = 18
BOXES_CORE = {
    "head":       (430,  10, 600, 195),
    "torso":      (392, 180, 632, 625),
    "upperarm_L": (178, 198, 408, 398),
    "forearm_L":  (168, 372, 362, 588),
    "upperarm_R": (616, 198, 846, 398),
    "forearm_R":  (662, 372, 856, 588),
    "thigh_L":    (288, 612, 512, 832),
    "shin_L":     (288, 808, 512, 1008),
    "thigh_R":    (512, 612, 736, 832),
    "shin_R":     (512, 808, 736, 1008),
}

# 每个框向哪些方向外延（+x, -x, +y, -y）。用 neighbor 共享重叠。
EXTEND = {
    "head":       {"top": 0,  "bottom": 20, "left": 0,  "right": 0},   # 头底与 torso 颈根重叠
    "torso":      {"top": 20, "bottom": 20, "left": 45, "right": 45},  # 与头/手臂/大腿都重叠，左右加宽覆盖肩袖
    "upperarm_L": {"top": 0,  "bottom": 20, "left": 0,  "right": 30}, # 内侧（right）与 torso 肩袖重叠，覆盖腋窝
    "forearm_L":  {"top": 28, "bottom": 0,  "left": 0,  "right": 0},  # 顶与上臂肘部重叠
    "upperarm_R": {"top": 0,  "bottom": 20, "left": 30, "right": 0}, # 内侧（left）与 torso 肩袖重叠，覆盖腋窝
    "forearm_R":  {"top": 28, "bottom": 0,  "left": 0,  "right": 0},
    "thigh_L":    {"top": 20, "bottom": 20, "left": 0,  "right": 20}, # 顶与 hip，底与 shin，内侧与躯干
    "shin_L":     {"top": 20, "bottom": 0,  "left": 0,  "right": 0},
    "thigh_R":    {"top": 20, "bottom": 20, "left": 20, "right": 0},
    "shin_R":     {"top": 20, "bottom": 0,  "left": 0,  "right": 0},
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
    for name, (x0, y0, x1, y1) in BOXES_CORE.items():
        ext = EXTEND[name]
        x0 = max(0, x0 - ext["left"])
        y0 = max(0, y0 - ext["top"])
        x1 = min(W - 1, x1 + ext["right"])
        y1 = min(H - 1, y1 + ext["bottom"])

        crop = img.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGBA")
        ca = np.array(crop)
        fg = ca[:, :, 3] > 128
        out = ca.copy()
        out[~fg] = (0, 0, 0, 0)
        crop = Image.fromarray(out, "RGBA")

        # 保存完整框（保留透明边），便于 pivot 直接用框内坐标
        crop.save(OUT_DIR / f"{name}.png")
        parts[name] = {
            "filename": f"{name}.png",
            "size": [crop.width, crop.height],
            # 记录该部件框左上角在原图中的坐标（用于拼回验证 / 关节计算）
            "src_bbox": [x0, y0, x0 + crop.width - 1, y0 + crop.height - 1],
        }
        print(f"  -> {name}: box {crop.width}x{crop.height}  src_bbox={parts[name]['src_bbox']}")

    spec = build_rig_spec(parts)
    RIG_JSON.write_text(json.dumps(spec, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[INFO] rig spec -> {RIG_JSON}")

    make_previews(img, parts)
    return 0


def build_rig_spec(parts: dict) -> dict:
    """占位 spec；真正的精确 spec 由 build_sherlock_spread_rig.py 覆盖。
    这里保留 parts_meta（含完整框 src_bbox），供 rig builder 精确还原关节。"""
    return {
        "character": "sherlock_spread",
        "parts_dir": "res://assets/characters/sherlock_spread/rig/",
        "scale": 0.2558,
        "parts_meta": [{"name": k, "src_bbox": v["src_bbox"], "size": v["size"]} for k, v in parts.items()],
        "bones": [],
    }


def make_previews(src_img: Image.Image, parts: dict) -> None:
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
        sc = min(cell / p.width, cell / p.height, 1.0) * 0.92
        p = p.resize((max(1, int(p.width * sc)), max(1, int(p.height * sc))), Image.LANCZOS)
        ox = (i % cols) * cell + (cell - p.width) // 2
        oy = (i // cols) * cell + (cell - p.height) // 2
        grid.paste(p, (ox, oy), p)
        d.text((ox, oy), nm, fill=(220, 80, 40, 255))
    grid.convert("RGB").save(OUT_DIR / "_parts_grid.png")
    print(f"[INFO] preview -> {OUT_DIR / '_parts_grid.png'}")

    reassembled = Image.new("RGBA", src_img.size, (0, 0, 0, 0))
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
