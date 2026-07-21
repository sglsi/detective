#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复版本历史顺序：v3.12.0和v3.11.0应该在v3.13.0之后
"""

FILE_PATH = "/app/data/所有对话/主对话/维多利亚伦敦探案项目/02_核心设计/08_血字的研究_对话台词库.md"

def read_file():
    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(content):
    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    content = read_file()
    
    # 找到v3.14.0到v3.13.0之间的内容（包含v3.12和v3.11）
    # 把它们移到v3.13.0之后
    
    # 找到v3.14.0结束的结尾和v3.13.0开始之间的内容（即v3.12和v3.11）
    # 我们需要:
    # 1. 提取v3.12.0和v3.11.0的完整内容
    # 2. 从v3.14.0和v3.13.0之间删除它们
    # 3. 插入到v3.13.0和v3.6.0之间
    
    # 让我们先找到各个版本的位置
    import re
    
    # 查找v3.14.0结束位置
    v314_start = content.find('### v3.14.0 —')
    v312_start = content.find('### v3.12.0 —')
    v311_start = content.find('### v3.11.0 —')
    v313_start = content.find('### v3.13.0 —')
    v36_start = content.find('### v3.6.0 —')
    
    print(f"v3.14.0 开始位置: {v314_start}")
    print(f"v3.12.0 开始位置: {v312_start}")
    print(f"v3.11.0 开始位置: {v311_start}")
    print(f"v3.13.0 开始位置: {v313_start}")
    print(f"v3.6.0 开始位置: {v36_start}")
    
    # 确认顺序是否正确
    if v312_start < v313_start:
        print("✗ 版本顺序错误，v3.12.0在v3.13.0之前")
        
        # 提取v3.12.0和v3.11.0的内容
        # v312_v311_content = content[v312_start:v313_start]
        
        # 删除v3.14.0之后、v3.12.0之前的分隔符也要处理
        # v314_end_content = content[v314_start:v312_start]
        
        # 提取v3.13.0到v3.6.0之前的内容
        v313_content = content[v313_start:v36_start]
        
        # 重新组合
        before_v314 = content[:v314_start]
        after_v36 = content[v36_start:]
        
        # 新顺序: v3.14.0 -> v3.13.0 -> v3.12.0 -> v3.11.0 -> v3.6.0
        # 但是v3.14.0结尾和v3.13.0开头之间的内容需要调整
        # v3.14.0结尾应该有分隔线，v3.13.0结尾也应该有分隔线
        
        # 让我们更简单地处理：
        # 1. 提取v3.12.0和v3.11.0完整内容
        # 2. 从原位置删除
        # 3. 插入到v3.13.0之后
        
        # 找到v3.11.0结束的位置（即v3.13.0开始之前）
        v311_end = v313_start
        
        # v3.12.0和v3.11.0的完整内容（包括它们之间的分隔线）
        v12_11_content = content[v312_start:v311_end]
        
        # 删除原位置的内容（v3.14.0结尾的分隔线 + v3.12 + v3.11）
        # v3.14.0的结尾应该在v3.12.0开始之前
        # 我们需要保留v3.14.0的结尾分隔线，然后直接接v3.13.0
        
        # 找到v3.14.0区块的结束（即v3.12.0之前的内容）
        v314_full_end = v312_start
        
        # v3.14.0的完整内容
        v314_content = content[v314_start:v314_full_end]
        
        # v3.13.0的完整内容（到v3.6.0之前）
        v313_content_full = content[v313_start:v36_start]
        
        # 重新组合：
        # before_v314 + v3.14.0 + v3.13.0 + v3.12.0 + v3.11.0 + v3.6.0 + after
        
        # 但是需要确保每个版本之间有正确的分隔线
        # v3.14.0结尾应该有"---\n\n"
        # v3.13.0结尾也应该有"---\n\n"
        
        # 让我们检查v3.14.0结尾
        # v314_content结尾应该是"---\n\n"
        # 我们需要确保正确的分隔
        
        # 最简单的方法：
        # 1. 提取v3.12和v3.11
        # 2. 删除它们
        # 3. 在v3.13.0结尾之后插入
        
        # 先删除v3.12和v3.11
        content_without_12_11 = content[:v312_start:v312_start + (v311_end - v312_start)]
        content_without_12_11 = content[:v312_start] + content[v311_end:]
        
        # 现在在v3.13.0之后插入v3.12和v3.11
        # 找到新的v3.13.0的位置和v3.6.0的位置
        new_v313_start = content_without_12_11.find('### v3.13.0 —')
        new_v36_start = content_without_12_11.find('### v3.6.0 —')
        
        # 找到v3.13.0的结尾（即v3.6.0开始之前
        v313_end = new_v36_start
        
        # 在v3.13.0结尾插入v3.12和v3.11
        # 确保有正确的分隔线
        final_content = content_without_12_11[:v313_end] + v12_11_content + content_without_12_11[v313_end:]
        
        content = final_content
        print("✓ 版本顺序已修复：v3.14 → v3.13 → v3.12 → v3.11 → v3.10...")
    else:
        print("✓ 版本顺序正确")
    
    write_file(content)
    
    # 验证顺序验证
    v315 = content.find('### v3.15.0')
    v314 = content.find('### v3.14.0')
    v313 = content.find('### v3.13.0')
    v312 = content.find('### v3.12.0')
    v311 = content.find('### v3.11.0')
    v310 = content.find('## v3.10.0')
    
    print(f"\n验证版本顺序：")
    print(f"v3.15.0: {v315}")
    print(f"v3.14.0: {v314}")
    print(f"v3.13.0: {v313}")
    print(f"v3.12.0: {v312}")
    print(f"v3.11.0: {v311}")
    print(f"v3.10.0: {v310}")
    
    if v315 < v314 < v313 < v312 < v311 < v310:
        print("✓ 版本顺序正确（降序）")
    else:
        print("✗ 版本顺序仍有问题")

if __name__ == "__main__":
    main()
