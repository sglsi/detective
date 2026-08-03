"""实测 contact sheet 中 idle@0 帧的头-躯干、躯干-腿 可见间隙（像素）。"""
import json
from PIL import Image
import numpy as np

root = r"D:\AI\detective\godot_project\skeleton_frames"
grid = Image.open(root + r"\contact_sheet_test_rig.png").convert("RGB")
W, H = 360, 620
# idle@0 = frame index 4 -> col0, row1
ci, ri = 0, 1
cell = grid.crop((ci*W, ri*H, ci*W+W, ri*H+H))

arr = np.array(cell).astype(int)
BG = np.array([235, 237, 241])
fg = np.abs(arr - BG).max(axis=2) > 30   # 非背景 = 角色像素

# 角色 x 范围
xs = np.where(fg.any(axis=0))[0]
if len(xs) == 0:
    print("no foreground found"); raise SystemExit
xc1, xc2 = int(xs.min()), int(xs.max())
center = (xc1 + xc2) // 2

# 在中心附近多列合并，得到稳定的 1D 前景掩码（消除手臂/纹理噪点影响）
band = slice(max(0, center-30), min(W, center+30))
col_fg = fg[:, band].any(axis=1)   # 该竖带内任一行有前景即算

rows = np.where(col_fg)[0]
top, bot = int(rows.min()), int(rows.max())
print(f"角色中心 x≈{center}  角色竖直范围 y={top}..{bot} (高 {bot-top}px)")

# 找所有连续前景段
segments = []
start = None
for y in range(top, bot+1):
    if col_fg[y] and start is None:
        start = y
    elif not col_fg[y] and start is not None:
        segments.append((start, y-1))
        start = None
if start is not None:
    segments.append((start, bot))
print("前景段（竖带合并）:", segments)

# 段之间的透明间隙
gaps = []
for i in range(1, len(segments)):
    gap = segments[i][0] - segments[i-1][1] - 1
    gaps.append(gap)
    print(f"  段{i-1}尾 y={segments[i-1][1]} -> 段{i}头 y={segments[i][0]}  间隙={gap}px")
if gaps:
    print("最大间隙 =", max(gaps), "px")
