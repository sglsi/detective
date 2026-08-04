"""将场景二背景图高质量放大到 1920x1080。

说明：本环境无 ImageGen / OpenCV superres / torch，无法做神经网络的真·AI 超分。
这里用 PIL LANCZOS（高质量双三次类）做 cover 缩放保证不变形，再用 UnsharpMask
轻微锐化，得到清晰可用的 1920x1080 背景。若用户后续提供 ESRGAN 权重或允许联网下载
模型，可再替换为真·AI 超分。
"""
import sys
from PIL import Image, ImageFilter

SRC = "D:/AI/detective/godot_project/assets/scenes/sc_02_garden.png"
DST = SRC
TW, TH = 1920, 1080

def main():
    im = Image.open(SRC).convert("RGB")
    print("source size", im.size)
    scale = max(TW / im.width, TH / im.height)
    nw, nh = int(round(im.width * scale)), int(round(im.height * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - TW) // 2
    top = (nh - TH) // 2
    im = im.crop((left, top, left + TW, top + TH))
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=3))
    im.save(DST, "PNG", optimize=True)
    print("saved", im.size, "to", DST)

if __name__ == "__main__":
    main()
