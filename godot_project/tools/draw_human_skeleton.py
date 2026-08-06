#!/usr/bin/env python3
"""根据 human_poses.json (POSEJSON 行) 绘制人体关节活动基础框架的 contact sheet。

每帧按各关节世界坐标用粗线(胶囊)绘制部位，并标红各关节锚点，
按所有帧 AABB 自动居中，确保完整显示。
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_PATHS = [
    Path("assets/fonts/simhei.ttf"),
    Path("C:/Windows/Fonts/simhei.ttf"),
    Path("C:/Windows/Fonts/msyh.ttc"),
]


def get_font(size: int = 18):
    for p in FONT_PATHS:
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


SRC = Path("skeleton_frames/human_poses.json")
OUT = Path("skeleton_frames/human_contact_sheet.png")

CN = {
    "torso": "躯干", "head": "头部",
    "upper_arm_L": "左上臂", "upper_arm_R": "右上臂",
    "fore_arm_L": "左前臂", "fore_arm_R": "右前臂",
    "hand_L": "左手", "hand_R": "右手",
    "thigh_L": "左大腿", "thigh_R": "右大腿",
    "shin_L": "左小腿", "shin_R": "右小腿",
    "foot_L": "左脚", "foot_R": "右脚",
}


def load_frames(path: Path):
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("POSEJSON "):
            return json.loads(line[len("POSEJSON "):])
    raise RuntimeError("POSEJSON not found in %s" % path)


POSE_CN = {
    "rest": "静止", "wave": "挥手", "walk1": "走步1", "walk2": "走步2",
    "sit": "坐姿", "reach": "伸手", "kick": "踢腿", "point": "指向",
}


def draw_frame(draw: ImageDraw.ImageDraw, bones, ox: int, oy: int, scale: float):
    # 部位绘制：head 只画圆；其余画胶囊(粗线 + 圆端)
    for b in bones:
        p = (ox + b["p"][0] * scale, oy + b["p"][1] * scale)
        q = (ox + b["q"][0] * scale, oy + b["q"][1] * scale)
        w = max(2, int(b["w"] * scale))
        col = tuple(int(255 * c) for c in b["c"])
        if b["shape"] == "circle":
            rr = int(b["w"] * 0.5 * scale)
            cy = p[1] - rr
            draw.ellipse([p[0] - rr, cy - rr, p[0] + rr, cy + rr], fill=col)
            draw.ellipse([p[0] - rr - 2, cy - rr - 2, p[0] + rr + 2, cy + rr + 2], outline=col)
        else:
            draw.line([p, q], fill=col, width=w)
            r = w // 2
            draw.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=col)
            draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)
    # 关节锚点（红点）
    for b in bones:
        p = (ox + b["p"][0] * scale, oy + b["p"][1] * scale)
        draw.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=(217, 38, 38))
        draw.ellipse([p[0] - 1.5, p[1] - 1.5, p[0] + 1.5, p[1] + 1.5], fill=(255, 255, 255))


def main():
    frames = load_frames(SRC)
    # 计算全局 AABB（用 p 和 q 端点）
    minx = miny = float("inf")
    maxx = maxy = float("-inf")
    for f in frames:
        for b in f["bones"]:
            for pt in (b["p"], b["q"]):
                minx = min(minx, pt[0]); maxx = max(maxx, pt[0])
                miny = min(miny, pt[1]); maxy = max(maxy, pt[1])
    margin = 30.0
    bw = (maxx - minx) + margin * 2
    bh = (maxy - miny) + margin * 2
    # 单元格尺寸（统一），scale=1（世界坐标已是 px）
    cell = 360
    cols = 4
    rows = (len(frames) + cols - 1) // cols
    W = cols * cell
    H = rows * cell
    img = Image.new("RGB", (W, H), (245, 245, 248))
    draw = ImageDraw.Draw(img)
    font = get_font(18)

    for i, f in enumerate(frames):
        ci = i % cols
        ri = i // cols
        ox = ci * cell - minx * 1.0 + margin
        oy = ri * cell - miny * 1.0 + margin
        draw_frame(draw, f["bones"], ox, oy, 1.0)
        # 标题
        draw.text((ci * cell + 10, ri * cell + 8), POSE_CN.get(f["pose"], f["pose"]),
                  fill=(30, 30, 40), font=font)

    OUT.write_bytes(img.tobytes() if False else _save(img))
    print("wrote", OUT, img.size)


def _save(img):
    import io
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


if __name__ == "__main__":
    main()
