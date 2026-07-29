import os, glob
from PIL import Image
import numpy as np

roots = ["assets/characters", "assets/portraits"]
files = []
for r in roots:
    for ext in ("*.png", "*.jpg", "*.jpeg"):
        files += glob.glob(os.path.join(r, "**", ext), recursive=True)

def info(p):
    try:
        im = Image.open(p)
        mode = im.mode
        if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
            a = np.array(im.convert("RGBA").split()[-1])
            transp = int((a <= 10).sum())
            pct = round(100 * transp / a.size, 1)
            # sample corner colors to detect solid bg
            rgb = im.convert("RGB")
            arr = np.array(rgb)
            corner = np.concatenate([arr[0, :], arr[-1, :], arr[:, 0], arr[:, -1]], axis=0)
            corner_cols, counts = np.unique(corner.reshape(-1, 3), axis=0, return_counts=True)
            top = corner_cols[np.argsort(-counts)[:3]]
            return f"ALPHA mode={mode} transparent={pct}% corner_top={top.tolist()[:1]}"
        return f"NO_ALPHA mode={mode} (jpg/opaque)"
    except Exception as e:
        return f"ERR {e}"

for f in sorted(set(files)):
    print(f"{info(f):70}  {f}")
