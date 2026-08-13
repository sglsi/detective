from PIL import Image, ImageDraw, ImageFont

IMG_PATH = "assets/characters/messenger/messenger_portrait.png"
OUT_PATH = "tools/anchor_calib_messenger_portrait_proposed.png"

# Proposed anchors after visual calibration
anchors = {
    "tattoo":  {"cx": 0.25, "cy": 0.19, "w": 0.20, "h": 0.10},
    "beard":   {"cx": 0.49, "cy": 0.09, "w": 0.18, "h": 0.08},
    "posture": {"cx": 0.50, "cy": 0.50, "w": 1.00, "h": 1.00},
    "manner":  {"cx": 0.49, "cy": 0.07, "w": 0.20, "h": 0.10},
    "sleeve":  {"cx": 0.73, "cy": 0.18, "w": 0.17, "h": 0.09},
    "limp":    {"cx": 0.30, "cy": 0.75, "w": 0.18, "h": 0.20},
}

colors = {
    "tattoo": (255, 0, 0),
    "beard": (0, 255, 0),
    "posture": (128, 128, 128),
    "manner": (0, 0, 255),
    "sleeve": (255, 165, 0),
    "limp": (128, 0, 128),
}

img = Image.open(IMG_PATH).convert("RGBA")
W, H = img.size
print(f"Image size: {W}x{H}")
draw = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
except Exception:
    font = ImageFont.load_default()

for name, a in anchors.items():
    cx = a["cx"] * W
    cy = a["cy"] * H
    w = a["w"] * W
    h = a["h"] * H
    x0 = cx - w/2
    y0 = cy - h/2
    x1 = cx + w/2
    y1 = cy + h/2
    col = colors[name]
    draw.rectangle([x0, y0, x1, y1], outline=col, width=3)
    draw.ellipse([cx-5, cy-5, cx+5, cy+5], fill=col)
    draw.text((x0, y0-18), name, fill=col, font=font)
    print(f"{name}: rect=({x0:.0f},{y0:.0f},{x1:.0f},{y1:.0f}) center=({cx:.0f},{cy:.0f})")

img.save(OUT_PATH)
print(f"Saved: {OUT_PATH}")
