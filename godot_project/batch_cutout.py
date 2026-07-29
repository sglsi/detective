"""Batch remove solid background from all character portrait images."""
import os, glob
from PIL import Image
import numpy as np
from collections import deque
from scipy.ndimage import distance_transform_edt

ROOT = "D:/AI/detective/godot_project"  # absolute for PIL file ops

# === Files to process (PortraitLibrary + scene_controller) ===
# NPC portraits
NPC_FILES = {
    "赫德森太太": "assets/characters/mrs_hudson/mrs_hudson.png",
    "葛莱森警长": "assets/characters/gregson/gregson_portrait.png",
    "葛莱森":     "assets/characters/gregson/gregson_portrait.png",   # alias same file
    "雷斯垂德警长":"assets/characters/lestrade/lestrade.png",
    "雷斯垂德":   "assets/characters/lestrade/lestrade.png",
    "兰斯警士":   "assets/characters/police_constable/police_constable_portrait.png",
    "值班警官":   "assets/characters/police_constable/police_constable_portrait.png",
    "维金斯":     "assets/characters/baker_street_captain/baker_street_captain_portrait.png",
    "杰弗森·霍普":"assets/characters/jefferson_hope/jefferson_hope_portrait.png",
    "卡彭蒂耶太太":"assets/characters/mrs_carpentier/mrs_carpentier_portrait.png",
    "爱莉丝":     "assets/characters/alice/alice_portrait.png",
    "卡彭蒂耶中尉":"assets/characters/lieutenant_carpentier/lieutenant_carpentier_portrait.png",
    "送牛奶的孩子":"assets/characters/milk_boy/milk_boy_portrait.png",
    "伪装者":     "assets/characters/old_woman/old_woman_portrait.png",
    "信使":       "assets/characters/messenger/messenger_portrait.png",
    "人事官员":   "assets/characters/recorder/recorder_portrait.png",
    "斯坦格森":   "assets/characters/stangerson/stangerson_portrait.png",
}
# Sherlock pixel portraits
SHERLOCK_DIR = "assets/portraits/pixel"
# Watson dialogue portraits (skip icon_* and teaching)
WATSON_DIR = "assets/characters/watson"
# Scene controller extra
SCENE_EXTRA = ["assets/characters/watson/watson_standing.jpg"]

SKIP_STEMS = {"watson_teaching"}  # already transparent


def remove_bg(src_path, dst_path, tol=55, feather=2):
    im = Image.open(os.path.join(ROOT, src_path)).convert("RGB")
    arr = np.array(im).astype(np.int32)
    h, w, _ = arr.shape
    # bg reference = median of border pixels
    top = arr[0]; bot = arr[-1]; left = arr[:,0]; right = arr[:,-1]
    border = np.concatenate([top, bot, left, right], axis=0).reshape(-1,3)
    bg = np.median(border, axis=0).astype(np.int32)
    diff = np.sqrt(((arr - bg)**2).sum(axis=2)).astype(np.float32)
    cand = diff <= tol
    # flood fill from border
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
    # feather alpha
    dist_out = distance_transform_edt(~bgmask)
    alpha = np.where(bgmask, 0, 255).astype(np.float32)
    soft = np.minimum(alpha, np.clip(dist_out / max(feather, 0.5) * 255, 0, 255))
    out = np.dstack([arr.astype(np.uint8), soft.astype(np.uint8)])
    full_dst = os.path.join(ROOT, dst_path)
    Image.fromarray(out, "RGBA").save(full_dst)
    pct_removed = round(100 * bgmask.sum() / (h*w), 1)
    print(f"  OK {src_path} -> {dst_path}  bg={tuple(bg)} removed={pct_removed}%")


def main():
    processed = set()
    jpg_to_png = []  # track jpg->png renames

    # NPCs
    for name, rel in NPC_FILES.items():
        if rel in processed: continue
        out_rel = rel  # overwrite PNG in place
        try:
            remove_bg(rel, out_rel)
            processed.add(rel)
        except Exception as e:
            print(f"  FAIL {rel}: {e}")

    # Sherlock
    for f in sorted(glob.glob(os.path.join(ROOT, SHERLOCK_DIR, "sherlock_*.png"))):
        rel = os.path.relpath(f, ROOT).replace("\\","/")
        if rel in processed: continue
        out_rel = rel  # overwrite
        try:
            remove_bg(rel, out_rel)
            processed.add(rel)
        except Exception as e:
            print(f"  FAIL {rel}: {e}")

    # Watson (skip icons + teaching)
    for f in sorted(glob.glob(os.path.join(ROOT, WATSON_DIR, "watson_*.jpg"))):
        base = os.path.splitext(os.path.basename(f))[0]
        if base.startswith("icon_") or base in SKIP_STEMS:
            print(f"  SKIP {os.path.basename(f)} (icon or already transparent)")
            continue
        src_rel = os.path.relpath(f, ROOT).replace("\\","/")
        dst_rel = src_rel.replace(".jpg", ".png")  # convert to PNG
        if dst_rel in processed: continue
        try:
            remove_bg(src_rel, dst_rel)
            processed.add(dst_rel)
            jpg_to_png.append((src_rel, dst_rel))
        except Exception as e:
            print(f"  FAIL {src_rel}: {e}")

    # Scene controller extras
    for rel in SCENE_EXTRA:
        if rel in processed: continue
        dst_rel = rel.replace(".jpg", ".png")
        try:
            remove_bg(rel, dst_rel)
            processed.add(dst_rel)
            if rel != dst_rel:
                jpg_to_png.append((rel, dst_rel))
        except Exception as e:
            print(f"  FAIL {rel}: {e}")

    print(f"\n=== SUMMARY: {len(processed)} files processed ===")
    if jpg_to_png:
        print("JPG -> PNG renames (update code refs):")
        for old, new in jpg_to_png:
            print(f"  {old}  =>  {new}")


if __name__ == "__main__":
    main()
