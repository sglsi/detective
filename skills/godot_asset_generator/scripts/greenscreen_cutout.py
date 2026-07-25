#!/usr/bin/env python3
"""
绿幕抠图脚本 - Godot 游戏元素生成器

功能：将 AI 生成的绿幕图片转换为透明底 PNG
用法：
    python3 greenscreen_cutout.py --input <输入图片> --output <输出 PNG>
    python3 greenscreen_cutout.py --input input.jpg --output output.png
    python3 greenscreen_cutout.py --input input.jpg --output output.png --bg-color 0,255,0
    python3 greenscreen_cutout.py --input input.jpg --output output.png --threshold 60 --fade-range 40
"""

import argparse
import numpy as np
from PIL import Image
from collections import Counter


def detect_background_color(img_data, sample_size=10):
    """
    自动检测背景色
    
    通过统计图片边缘像素颜色，找出最常见的颜色作为背景色
    
    Args:
        img_data: numpy 数组，RGB 格式
        sample_size: 边缘采样宽度（像素）
    
    Returns:
        numpy 数组，背景色 RGB 值
    """
    # 采样图片边缘（上下左右）
    edge_pixels = []
    edge_pixels.extend(img_data[:sample_size, :].reshape(-1, 3))  # 上边
    edge_pixels.extend(img_data[-sample_size:, :].reshape(-1, 3))  # 下边
    edge_pixels.extend(img_data[:, :sample_size].reshape(-1, 3))   # 左边
    edge_pixels.extend(img_data[:, -sample_size:].reshape(-1, 3))  # 右边
    
    # 转换为元组列表以便计数
    pixel_tuples = [tuple(p) for p in edge_pixels]
    color_counts = Counter(pixel_tuples)
    
    # 获取最常见的颜色作为背景色
    bg_color = np.array(color_counts.most_common(1)[0][0])
    
    return bg_color


def greenscreen_cutout(input_path, output_path, bg_color=None, threshold=60, fade_range=40):
    """
    绿幕抠图主函数
    
    Args:
        input_path: 输入图片路径（JPG 或 PNG）
        output_path: 输出透明底 PNG 路径
        bg_color: 背景色 RGB 值（numpy 数组），None 表示自动检测
        threshold: 透明阈值（默认 60）
        fade_range: 渐变过渡范围（默认 40）
    
    Returns:
        dict: 统计信息（透明/半透明/不透明像素占比）
    """
    # 打开图片
    img = Image.open(input_path).convert('RGBA')
    data = np.array(img)
    
    print(f"输入文件：{input_path}")
    print(f"原始尺寸：{img.size}")
    print(f"原始模式：{img.mode}")
    
    # 检测或使用指定的背景色
    if bg_color is None:
        bg_color = detect_background_color(data[:,:,:3])
        print(f"自动检测背景色：RGB{tuple(bg_color)}")
    else:
        print(f"使用指定背景色：RGB{tuple(bg_color)}")
    
    # 计算每个像素与背景色的距离
    diff = np.abs(data[:,:,:3].astype(float) - bg_color.astype(float))
    distance = np.sqrt(np.sum(diff**2, axis=2))
    
    # 创建渐变透明 Alpha 通道
    alpha = np.zeros(distance.shape, dtype=np.uint8)
    alpha[distance > threshold + fade_range] = 255
    mask = (distance > threshold) & (distance <= threshold + fade_range)
    alpha[mask] = ((distance[mask] - threshold) / fade_range * 255).astype(np.uint8)
    
    # 应用 Alpha 通道
    data[:,:,3] = alpha
    
    # 保存
    result = Image.fromarray(data)
    result.save(output_path, 'PNG')
    
    # 统计信息
    total_pixels = alpha.size
    transparent = np.sum(alpha == 0) / total_pixels * 100
    semi_transparent = np.sum((alpha > 0) & (alpha < 255)) / total_pixels * 100
    opaque = np.sum(alpha == 255) / total_pixels * 100
    
    stats = {
        'transparent': transparent,
        'semi_transparent': semi_transparent,
        'opaque': opaque,
        'output_size': result.size,
        'output_path': output_path
    }
    
    print(f"\n输出文件：{output_path}")
    print(f"输出尺寸：{result.size}")
    print(f"\n像素统计：")
    print(f"  透明像素：{transparent:.1f}%")
    print(f"  半透明像素：{semi_transparent:.1f}%")
    print(f"  不透明像素：{opaque:.1f}%")
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description='绿幕抠图脚本 - 将 AI 生成的绿幕图片转换为透明底 PNG',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例：
    python3 greenscreen_cutout.py --input bigben.jpg --output bigben.png
    python3 greenscreen_cutout.py --input character.jpg --output character.png --bg-color 0,255,0
    python3 greenscreen_cutout.py --input prop.jpg --output prop.png --threshold 50 --fade-range 30
        """
    )
    
    parser.add_argument('--input', required=True, help='输入图片路径（JPG 或 PNG）')
    parser.add_argument('--output', required=True, help='输出透明底 PNG 路径')
    parser.add_argument('--bg-color', help='背景色 RGB 值，格式：R,G,B（默认自动检测）')
    parser.add_argument('--threshold', type=int, default=60, help='透明阈值（默认 60）')
    parser.add_argument('--fade-range', type=int, default=40, help='渐变过渡范围（默认 40）')
    
    args = parser.parse_args()
    
    # 解析背景色
    bg_color = None
    if args.bg_color:
        try:
            r, g, b = map(int, args.bg_color.split(','))
            bg_color = np.array([r, g, b])
        except ValueError:
            print(f"错误：背景色格式不正确，应为 R,G,B（如 0,255,0）")
            return
    
    # 执行抠图
    try:
        stats = greenscreen_cutout(
            input_path=args.input,
            output_path=args.output,
            bg_color=bg_color,
            threshold=args.threshold,
            fade_range=args.fade_range
        )
        print("\n✓ 抠图完成")
    except Exception as e:
        print(f"\n✗ 抠图失败：{e}")
        return 1
    
    return 0


if __name__ == '__main__':
    exit(main())
