from PIL import Image
import numpy as np
import sys

inp = sys.argv[1]
out = sys.argv[2]
threshold = int(sys.argv[3]) if len(sys.argv) > 3 else 250

img = Image.open(inp).convert("RGBA")
arr = np.array(img)
# 标记接近白色的背景
mask = (arr[:,:,0] > threshold) & (arr[:,:,1] > threshold) & (arr[:,:,2] > threshold)
arr[mask] = [0, 0, 0, 0]
Image.fromarray(arr).save(out)
print(f"saved {out}, threshold={threshold}")
