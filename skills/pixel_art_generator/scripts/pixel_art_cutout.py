#!/usr/bin/env python3
"""
像素艺术风格生成器 - 绿幕抠图 + 像素化处理

功能：
1. 绿幕抠图（自动检测背景色）
2. 像素化处理（缩小后放大，产生像素效果）
3. 调色板量化（限制颜色数量）
4. 输出透明底 PNG

使用方法：
    python3 pixel_art_cutout.py --input <绿幕图> --output <输出 PNG> [选项]

选项：
    --pixel-size SIZE   目标像素尺寸（默认 64，可选 16/32/64/128/256）
    --colors N          调色板颜色数（默认 16，可选 8/16/32/64）
    --no-pixelate       跳过像素化处理，只抠图
    --bg-color R,G,B    手动指定背景色（默认自动检测）
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("错误：需要安装 Pillow 库")
    print("安装命令：pip install Pillow")
    sys.exit(1)


def detect_background_color(img_data):
    """
    检测背景色（采样图片边缘）
    """
    # 确保是 RGB 模式（3 通道）
    if img_data.shape[2] == 4:
        img_data = img_data[:, :, :3]

    # 采样边缘像素（上下左右各 10 像素宽）
    edge_pixels = []
    edge_pixels.extend(img_data[:10, :].reshape(-1, 3))
    edge_pixels.extend(img_data[-10:, :].reshape(-1, 3))
    edge_pixels.extend(img_data[:, :10].reshape(-1, 3))
    edge_pixels.extend(img_data[:, -10:].reshape(-1, 3))

    # 统计最常见的颜色
    from collections import Counter
    pixel_tuples = [tuple(p) for p in edge_pixels]
    color_counts = Counter(pixel_tuples)

    # 返回最常见的颜色
    bg_color = np.array(color_counts.most_common(1)[0][0])
    return bg_color


def remove_background(img_data, bg_color, threshold=60, fade_range=40):
    """
    移除背景（基于颜色距离）
    """
    # 确保是 RGBA 模式
    if img_data.shape[2] == 3:
        img_data = np.dstack([img_data, np.full(img_data.shape[:2], 255, dtype=np.uint8)])

    # 计算每个像素与背景色的距离（只比较 RGB 通道）
    diff = np.abs(img_data[:, :, :3].astype(float) - bg_color.astype(float))
    distance = np.sqrt(np.sum(diff ** 2, axis=2))

    # 创建透明度（渐变过渡）
    alpha = np.zeros(distance.shape, dtype=np.uint8)
    alpha[distance > threshold + fade_range] = 255
    mask = (distance > threshold) & (distance <= threshold + fade_range)
    alpha[mask] = ((distance[mask] - threshold) / fade_range * 255).astype(np.uint8)

    # 应用 Alpha 通道
    img_data[:, :, 3] = alpha
    return img_data


def pixelate(img, target_size):
    """
    像素化处理（缩小后放大）
    """
    original_size = img.size

    # 缩小到目标尺寸
    small = img.resize((target_size, target_size), Image.NEAREST)

    # 放大回原始尺寸（保持像素风格）
    pixelated = small.resize(original_size, Image.NEAREST)

    return pixelated


def quantize_colors(img, num_colors):
    """
    调色板量化（限制颜色数量）
    """
    # 转换为 RGBA 模式
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # 分离 Alpha 通道
    alpha = img.split()[3]

    # 转换为 RGB 进行量化
    rgb = img.convert('RGB')

    # 量化颜色（使用 Pillow 的量化功能）
    quantized = rgb.quantize(colors=num_colors, method=Image.MEDIANCUT)

    # 转换回 RGBA
    result = quantized.convert('RGBA')

    # 恢复 Alpha 通道
    result.putalpha(alpha)

    return result


def process_image(input_path, output_path, pixel_size=64, num_colors=16,
                  pixelate_enabled=True, bg_color=None):
    """
    处理图片：抠图 + 像素化 + 调色板量化
    """
    print(f"输入文件：{input_path}")
    print(f"输出文件：{output_path}")

    # 打开图片
    img = Image.open(input_path).convert('RGBA')
    img_data = np.array(img)

    print(f"原始尺寸：{img.size}")
    print(f"原始模式：{img.mode}")

    # 检测或使用指定的背景色
    if bg_color is None:
        bg_color = detect_background_color(img_data)
        print(f"检测到背景色：RGB{tuple(bg_color)}")
    else:
        print(f"使用指定背景色：RGB{tuple(bg_color)}")

    # 移除背景
    img_data = remove_background(img_data, bg_color)
    img = Image.fromarray(img_data)

    # 统计透明像素
    alpha = np.array(img)[:, :, 3]
    transparent = np.sum(alpha == 0) / alpha.size * 100
    opaque = np.sum(alpha == 255) / alpha.size * 100
    print(f"透明像素：{transparent:.1f}%")
    print(f"不透明像素：{opaque:.1f}%")

    # 像素化处理
    if pixelate_enabled:
        print(f"像素化处理：目标尺寸 {pixel_size}x{pixel_size}")
        img = pixelate(img, pixel_size)

    # 调色板量化
    print(f"调色板量化：{num_colors} 色")
    img = quantize_colors(img, num_colors)

    # 保存
    img.save(output_path, 'PNG')
    print(f"\n已生成：{output_path}")

    # 输出文件信息
    output_size = Path(output_path).stat().st_size
    print(f"文件大小：{output_size / 1024:.1f} KB")
    print(f"最终尺寸：{img.size}")
    print(f"最终模式：{img.mode}")

    return True


def main():
    parser = argparse.ArgumentParser(
        description='像素艺术风格生成器 - 绿幕抠图 + 像素化处理',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例：
  # 基本用法（自动检测背景色，64x64 像素，16 色）
  python3 pixel_art_cutout.py --input input.jpg --output output.png

  # 指定像素尺寸和颜色数
  python3 pixel_art_cutout.py --input input.jpg --output output.png --pixel-size 32 --colors 8

  # 只抠图不像素化
  python3 pixel_art_cutout.py --input input.jpg --output output.png --no-pixelate

  # 手动指定背景色
  python3 pixel_art_cutout.py --input input.jpg --output output.png --bg-color 0,255,0
        """
    )

    parser.add_argument('--input', required=True, help='输入图片路径（绿幕图）')
    parser.add_argument('--output', required=True, help='输出图片路径（透明底 PNG）')
    parser.add_argument('--pixel-size', type=int, default=64,
                        choices=[16, 32, 64, 128, 256],
                        help='目标像素尺寸（默认 64）')
    parser.add_argument('--colors', type=int, default=16,
                        choices=[8, 16, 32, 64],
                        help='调色板颜色数（默认 16）')
    parser.add_argument('--no-pixelate', action='store_true',
                        help='跳过像素化处理，只抠图')
    parser.add_argument('--bg-color', type=str, default=None,
                        help='手动指定背景色（格式：R,G,B）')

    args = parser.parse_args()

    # 解析背景色
    bg_color = None
    if args.bg_color:
        try:
            parts = args.bg_color.split(',')
            bg_color = np.array([int(p) for p in parts])
        except:
            print(f"错误：背景色格式错误，应为 R,G,B（如 0,255,0）")
            sys.exit(1)

    # 处理图片
    success = process_image(
        input_path=args.input,
        output_path=args.output,
        pixel_size=args.pixel_size,
        num_colors=args.colors,
        pixelate_enabled=not args.no_pixelate,
        bg_color=bg_color
    )

    if success:
        print("\n处理完成！")
    else:
        print("\n处理失败！")
        sys.exit(1)


if __name__ == '__main__':
    main()
