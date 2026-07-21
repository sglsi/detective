#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
补充修改：添加遗漏的两个沉默线索
1. 场景四：兰斯家墙上的旧照片
2. 场景六：书架上的法律书籍
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
    modifications = []
    
    # ============================================================
    # 补充1：场景六书架增加法律书籍（沉默线索）
    # ============================================================
    old_bookshelf = '''**观察点 C3：书架**

    书架上大多是宗教书籍和家庭医药手册。
    还有几本航海题材的小说，书脊有明显翻阅痕迹。

    → 【记录】家中有航海小说（可能是中尉的）'''
    
    new_bookshelf = '''**观察点 C3：书架**

    书架上大多是宗教书籍和家庭医药手册。
    还有几本航海题材的小说，书脊有明显翻阅痕迹。
    下层摆着几本厚厚的法律书籍，书脊也有磨损痕迹。

    → 【记录】家中有航海小说（可能是中尉的）
    
    【沉默线索·D1：法律书籍】
    → 仔细看法律书籍：都是海军军法和海商法相关的，边角有批注
    → 【环境细节记录】这位中尉不只是个武夫，还挺懂法的。这样的人，不太可能一时冲动就动手杀人吧？
    → 洞察之星 +0.5
    → 【独特"发现"音效触发】'''
    
    if old_bookshelf in content:
        content = content.replace(old_bookshelf, new_bookshelf)
        modifications.append(('场景六·沉默线索法律书籍', 'C3书架观察点'))
    else:
        print("WARNING: 场景六书架原文未找到，跳过")
    
    # ============================================================
    # 补充2：场景四兰斯家墙上旧照片（沉默线索）
    # ============================================================
    # 在Step 1观察发现的简单模式中加入房间环境的沉默线索
    old_scene4_easy_start = '''    [简单模式]  {
    
    【高亮提示】兰斯叙述中有4处关键信息点会自动高亮闪烁：'''
    
    new_scene4_easy_start = '''    [简单模式]  {
    
    【沉默线索·D1：墙上的旧照片】（全难度可选，不影响主线）
    [点击背景墙上的照片] → 特写：一张泛黄的军队合影照片，挂在有些歪斜的钉子上
    → 【环境细节记录】兰斯巡警以前当过兵——难怪他对醉汉的军人站姿没什么反应，见怪不怪了
    → 洞察之星 +0.5
    → 【独特"发现"音效触发】
    
    【高亮提示】兰斯叙述中有4处关键信息点会自动高亮闪烁：'''
    
    if old_scene4_easy_start in content:
        content = content.replace(old_scene4_easy_start, new_scene4_easy_start)
        modifications.append(('场景四·沉默线索旧照片（简单模式）', 'Step 1观察发现·简单模式'))
    else:
        print("WARNING: 场景四简单模式原文未找到，跳过")
    
    # 普通模式也加
    old_scene4_normal_start = '''    [普通模式]  {
    
    【微光提示】兰斯叙述时整体有提示，但不指明哪句重要
    
    兰斯（坐下，点了烟斗）：'''
    
    new_scene4_normal_start = '''    [普通模式]  {
    
    【微光提示】兰斯叙述时整体有提示，但不指明哪句重要
    
    【沉默线索·D1：墙上的旧照片】（全难度可选，不影响主线）
    [点击背景墙上的照片] → 特写：一张泛黄的军队合影照片，挂在有些歪斜的钉子上
    → 【环境细节记录】兰斯巡警以前当过兵——难怪他对醉汉的军人站姿没什么反应，见怪不怪了
    → 洞察之星 +0.5
    → 【独特"发现"音效触发】
    
    兰斯（坐下，点了烟斗）：'''
    
    if old_scene4_normal_start in content:
        content = content.replace(old_scene4_normal_start, new_scene4_normal_start)
        modifications.append(('场景四·沉默线索旧照片（普通模式）', 'Step 1观察发现·普通模式'))
    else:
        print("WARNING: 场景四普通模式原文未找到，跳过")
    
    # 困难模式也加
    old_scene4_hard_start = '''    [困难模式]  {
    
    【无提示】兰斯一段话说完，没有任何高亮或提示
    
    兰斯（坐下，点了烟斗，语速很快）：'''
    
    new_scene4_hard_start = '''    [困难模式]  {
    
    【无提示】兰斯一段话说完，没有任何高亮或提示
    
    【沉默线索·D1：墙上的旧照片】（全难度可选，不影响主线）
    [点击背景墙上的照片] → 特写：一张泛黄的军队合影照片，挂在有些歪斜的钉子上
    → 【环境细节记录】兰斯巡警以前当过兵——难怪他对醉汉的军人站姿没什么反应，见怪不怪了
    → 洞察之星 +0.5
    → 【独特"发现"音效触发】
    
    兰斯（坐下，点了烟斗，语速很快）：'''
    
    if old_scene4_hard_start in content:
        content = content.replace(old_scene4_hard_start, new_scene4_hard_start)
        modifications.append(('场景四·沉默线索旧照片（困难模式）', 'Step 1观察发现·困难模式'))
    else:
        print("WARNING: 场景四困难模式原文未找到，跳过")
    
    # ============================================================
    # 写入文件
    # ============================================================
    write_file(content)
    
    lines = content.split('\n')
    print(f"补充修改完成！")
    print(f"当前总行数：{len(lines)}")
    print()
    print("新增沉默线索：")
    for i, (name, location) in enumerate(modifications, 1):
        print(f"  {i}. {name} —— {location}")

if __name__ == '__main__':
    main()
