import os, sys
from PIL import Image

ROOT = "assets"
TARGETS = ["assets/characters", "assets/portraits", "assets/scenes"]
MAX_DIM = 512
EXTS = (".png", ".jpg", ".jpeg", ".webp")

def is_pixel_art(path):
    # 像素风立绘（福尔摩斯 14 表情）用最近邻，保硬边
    return "portraits/pixel" in path.replace("\\", "/")

def human(n):
    return "%.1fM" % (n / 1024 / 1024)

total_before = total_after = 0
count = 0
for base in TARGETS:
    for dp, _, fns in os.walk(base):
        for fn in fns:
            if not fn.lower().endswith(EXTS):
                continue
            p = os.path.join(dp, fn)
            try:
                im = Image.open(p)
            except Exception as e:
                print("skip(open):", p, e); continue
            w, h = im.size
            if max(w, h) <= MAX_DIM:
                continue
            before = os.path.getsize(p)
            # 保持透明通道
            has_alpha = im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info)
            resample = Image.NEAREST if is_pixel_art(p) else Image.LANCZOS
            scale = MAX_DIM / max(w, h)
            nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
            im = im.convert("RGBA" if has_alpha else "RGB")
            im = im.resize((nw, nh), resample)
            if fn.lower().endswith((".jpg", ".jpeg")):
                im = im.convert("RGB")
                im.save(p, "JPEG", quality=85, optimize=True)
            else:
                im.save(p, "PNG", optimize=True)
            after = os.path.getsize(p)
            total_before += before; total_after += after; count += 1
            print("%s %dx%d->%dx%d %s->%s" % (fn, w, h, nw, nh, human(before), human(after)))

print("=== resized %d files, source %s -> %s ===" % (count, human(total_before), human(total_after)))
