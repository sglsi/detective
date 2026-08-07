from PIL import Image
import numpy as np
import sys
import cv2

inp = sys.argv[1]
out = sys.argv[2]
TARGET_BG = np.array([10, 14, 20], dtype=np.float32)
color_dist = float(sys.argv[3]) if len(sys.argv) > 3 else 12.0

img_bgr = cv2.imread(inp)
if img_bgr is None:
    raise RuntimeError(f"cannot read {inp}")
img = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
h, w = img.shape[:2]

# 1. 背景色 = 四角中位数
bg_samples = []
for y0, x0 in [(0,0),(0,w-12),(h-12,0),(h-12,w-12)]:
    block = img[max(0,y0):min(h,y0+12), max(0,x0):min(w,x0+12)]
    bg_samples.append(np.median(block.reshape(-1,3), axis=0))
bg_color = np.mean(bg_samples, axis=0)
print(f"bg color: {bg_color}")

# 2. 颜色距离 -> 前景候选
dist = np.linalg.norm(img.astype(np.float32) - bg_color, axis=2)
fg = (dist > color_dist).astype(np.uint8) * 255

# 3. 形态学连接前景：把黑衣服、白衬衫、皮肤连成一个整体
kernel = np.ones((3,3), np.uint8)
fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, kernel, iterations=5)
fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, kernel, iterations=1)

# 4. 取最大连通区域（人物），并估算人物 bbox
num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(fg, connectivity=8)
if num_labels > 1:
    largest = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    fg = (labels == largest).astype(np.uint8) * 255
    bx, by, bw, bh, _ = stats[largest]
else:
    bx, by, bw, bh = 0, 0, w, h

# 5. 头部保护：人物 bbox 顶部中心区域强制保留为前景（避免黑发和深色背景融合被抠掉）
cx = bx + bw // 2
cy = by + int(bh * 0.08)
hr = int(min(bw, bh) * 0.12)
head_mask = np.zeros((h, w), dtype=np.uint8)
cv2.ellipse(head_mask, (cx, cy), (int(hr*0.55), hr), 0, 0, 360, 255, -1)
fg = cv2.bitwise_or(fg, head_mask)

# 5. 边缘羽化 mask
fg_f = fg.astype(np.float32) / 255.0
fg_f = cv2.GaussianBlur(fg_f, (5,5), 1.0)

# 6. 合成：前景保留原色，背景替换为目标色；alpha 用 fg_f
rgba = np.zeros((h, w, 4), dtype=np.float32)
for c in range(3):
    rgba[:, :, c] = img[:, :, c] * fg_f + TARGET_BG[c] * (1 - fg_f)
rgba[:, :, 3] = fg_f * 255

out_img = Image.fromarray(rgba.astype(np.uint8))
out_img.save(out)
print(f"saved {out}, color_dist={color_dist}")
