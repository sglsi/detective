import sys
from PIL import Image
import numpy as np

def remove_bg(src, dst, tol=55, feather=2):
    im = Image.open(src).convert("RGB")
    arr = np.array(im).astype(np.int32)
    h, w, _ = arr.shape
    # background reference = median of border pixels
    top = arr[0]; bot = arr[-1]; left = arr[:,0]; right = arr[:,-1]
    border = np.concatenate([top, bot, left, right], axis=0).reshape(-1,3)
    bg = np.median(border, axis=0).astype(np.int32)
    # distance to bg
    diff = np.sqrt(((arr - bg)**2).sum(axis=2)).astype(np.float32)
    # mask of bg-colored pixels
    cand = diff <= tol
    # flood fill from border: keep only cand pixels connected to image border
    from collections import deque
    bgmask = np.zeros((h, w), dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h-1):
            if cand[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w-1):
            if cand[y, x] and not bgmask[y, x]:
                bgmask[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not bgmask[ny, nx]:
                bgmask[ny, nx] = True; dq.append((ny, nx))
    # feather: distance from bg boundary -> soft alpha
    # alpha = 255 outside bg; 0 inside bg; transition near boundary
    alpha = np.where(bgmask, 0, 255).astype(np.float32)
    # dilate bgmask to get boundary band
    from scipy.ndimage import distance_transform_edt
    dist_out = distance_transform_edt(~bgmask)      # distance from bg to nearest non-bg
    dist_in = distance_transform_edt(bgmask)        # distance from non-bg into bg
    # soften edge: pixels just outside bg get partial alpha based on dist_out
    soft = np.minimum(alpha, np.clip(dist_out / feather * 255, 0, 255))
    # also fade the outermost feather pixels of subject
    soft = np.minimum(soft, 255)
    out = np.dstack([arr.astype(np.uint8), soft.astype(np.uint8)])
    Image.fromarray(out, "RGBA").save(dst)
    print(f"  {src} -> {dst}  bg_ref={tuple(bg)} removed={int(bgmask.sum())}/{h*w}")

if __name__ == "__main__":
    tests = [
        ("assets/characters/gregson/gregson_portrait.png", "_cut_test/cut_gregson.png"),
        ("assets/portraits/pixel/sherlock_思考.png", "_cut_test/cut_sherlock.png"),
        ("assets/characters/watson/watson_平静.jpg", "_cut_test/cut_watson.png"),
    ]
    for s, d in tests:
        remove_bg(s, d)
