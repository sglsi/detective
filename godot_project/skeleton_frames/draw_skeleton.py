import json, math, os
from PIL import Image, ImageDraw

W, H = 360, 620
COLS, ROWS = 4, 4
root = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(root, "poses.json")) as f:
    line = f.read().strip()
assert line.startswith("POSEJSON ")
frames = json.loads(line[len("POSEJSON "):])
print("frames:", len(frames))


def bone_end(b):
    x, y, rot, ln, dr = b["x"], b["y"], b["rot"], b["len"], b["dir"]
    if dr < 0:
        dx, dy = math.sin(rot), -math.cos(rot)
    else:
        dx, dy = -math.sin(rot), math.cos(rot)
    return x + dx * ln, y + dy * ln


def draw_cell(draw, fr):
    draw.rectangle([0, 0, W, H], fill=(232, 234, 238))
    draw.line([(0, H - 40), (W, H - 40)], fill=(200, 202, 208), width=2)
    for b in fr["bones"]:
        r, g, bl = [int(c * 255) for c in b["color"]]
        col = (r, g, bl)
        x0, y0 = b["x"], b["y"]
        x1, y1 = bone_end(b)
        w = max(3, int(b["wid"]))
        draw.line([(x0, y0), (x1, y1)], fill=col, width=w)
        for (cx, cy) in [(x0, y0), (x1, y1)]:
            draw.ellipse([cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2], fill=col)
        if b["name"] in ("head", "hat"):
            mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            rad = w / 2 + 6
            draw.ellipse([mx - rad, my - rad, mx + rad, my + rad], fill=col)
    for b in fr["bones"]:
        jr = max(3, int(b["wid"]) / 2)
        draw.ellipse([b["x"] - jr, b["y"] - jr, b["x"] + jr, b["y"] + jr], fill=(60, 60, 70))


grid = Image.new("RGB", (W * COLS, H * ROWS), (255, 255, 255))
for i, fr in enumerate(frames):
    ci, ri = i % COLS, i // COLS
    cell = Image.new("RGB", (W, H))
    draw_cell(ImageDraw.Draw(cell), fr)
    ImageDraw.Draw(cell).text((8, 6), "%s  t=%.2f" % (fr["anim"], fr["t"]), fill=(20, 20, 30))
    grid.paste(cell, (ci * W, ri * H))
grid.save(os.path.join(root, "contact_sheet.png"))
print("saved contact_sheet.png", grid.size)
