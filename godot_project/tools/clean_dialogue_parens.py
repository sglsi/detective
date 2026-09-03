#!/usr/bin/env python3
"""按台词库规则清洗场景一至四对话 tres：
台词/提示文本内的小括号演出指示、设计标注不上屏。
- 整条皆为指示的节点：text 置空（dialogue_manager 对空 text 自动流转）+ 原文迁 stage_direction
- 嵌在台词中的指示段：剥离，指示迁 stage_direction
- 玩家功能信息/线索内容类括号（如（0-10 滑杆）（可记录在线索墙）（身高6英尺+…））保留
幂等：重复执行无副作用。用法：python3 tools/clean_dialogue_parens.py
"""
import re
import sys

MIG = lambda t: ("__MIG__", t)
STRIP = lambda t, sd: ("__STRIP__", t, sd)

EDITS = {
    "scene_01_phase1_tutorial.tres": [
        ("s1_step1_hard", STRIP("仔细观察周围环境……", "无提示")),
        ("s1_step1_observe_done", MIG("（等待玩家点击华生身上的可交互区域）")),
        ("s1_step2_easy", STRIP("系统自动推荐工具：试试放大镜？", "放大镜图标高亮闪烁")),
        ("s1_step2_hard", MIG("（工具选择界面，无提示）")),
        ("s1_step4_prompt", MIG("（4个部位全部记录完成）")),
        ("s1_step4_hard", MIG("（无提示——知识库可自行从菜单打开）")),
        ("s1_step5_hard", MIG("（推理墙打开，无任何引导）")),
        ("s1_step6_hard", MIG("（无验证提示，玩家自行判断）")),
    ],
    "scene_02_garden.tres": [
        ("s2_step1_hard", MIG("（无提示——自行在场景中寻找可交互的痕迹）")),
        ("s2_step1_observe_done", MIG("（等待玩家点击：车轮印 / 马蹄印 / 行人脚印）")),
        ("s2_step2_hard", MIG("（工具选择界面，无提示）")),
        ("s2_step3_hard", MIG("（空白笔记，自由记录）")),
        ("s2_step4_prompt", MIG("（测量与记录完成）")),
        ("s2_step4_hard", MIG("（无提示——知识库可自行从菜单打开）")),
        ("s2_step5_hard", MIG("（推理墙开启，无任何引导）")),
        ("s2_step6_hard", MIG("（无验证提示，玩家自行判断何时证据充分）")),
    ],
    "scene_03_indoor.tres": [
        ("s3_easy_intro", MIG("（轻引导提示：本案关键在「无伤痕的尸体」与「墙上的血字」。先观察，福尔摩斯会等你先想。）")),
    ],
    "scene_04_police.tres": [
        ("s4_start", STRIP("我已经在局里全都报告过了！……那我就从头再讲一遍。", "（福尔摩斯把玩半镑金币）")),
        ("s4_step1_normal", STRIP("夜里两点巡逻发现空屋灯光与尸体，叫来同伴。", "（同 EASY：夜里两点巡逻发现空屋灯光与尸体，叫来同伴）")),
        ("s4_step1_hard", MIG("（无提示——自行从兰斯叙述中提取有效信息）")),
        ("s4_step2_normal", STRIP("可选追问方向：外貌/衣着/是否持物/有无马车。选对关键问题→获得完整醉汉特征。", "（70%概率提示）")),
        ("s4_step2_hard", MIG("（玩家自行选择追问；无关问题兰斯不再重复）")),
        ("s4_step3_hard", MIG("（空白笔记，自由记录）")),
        ("s4_step4_prompt", MIG("（测量与记录完成）")),
        ("s4_step4_hard", MIG("（无提示）")),
        ("s4_step5_hard", MIG("（推理墙开启，无引导）")),
        ("s4_step6_hard", MIG("（无验证提示，玩家自行判断何时证据充分）")),
        ("s4_return_choice", STRIP("醉汉返回现场的原因是：", None)),
    ],
}


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def already_applied(block: str, action) -> bool:
    """幂等判定：text 已是目标值即视为已应用。"""
    m = re.search(r'^text = "(.*)"$', block, re.M)
    return m is not None and m.group(1) == esc(action[1])


def main() -> int:
    total = 0
    for fname, edits in EDITS.items():
        path = f"resources/dialogues/{fname}"
        src = open(path, encoding="utf-8").read()
        blocks = src.split("[sub_resource ")
        out = [blocks[0]]
        changed = 0
        for b in blocks[1:]:
            nid_m = re.search(r'^node_id = "([^"]+)"$', b, re.M)
            nid = nid_m.group(1) if nid_m else None
            rule = next((e for e in edits if e[0] == nid), None)
            if not rule:
                out.append(b)
                continue
            _, action = rule
            new_b = b
            if action[0] == "__MIG__":
                new_b = re.sub(r'^text = ".*"$', 'text = ""', b, flags=re.M)
                new_b = re.sub(r'^stage_direction = ""$',
                               'stage_direction = "%s"' % esc(action[1]), new_b, flags=re.M)
            else:
                new_b = re.sub(r'^text = ".*"$', 'text = "%s"' % esc(action[1]), b, flags=re.M)
                if action[2]:
                    new_b = re.sub(r'^stage_direction = ""$',
                                   'stage_direction = "%s"' % esc(action[2]), new_b, flags=re.M)
            if new_b != b:
                changed += 1
                print(f"  [OK] {fname} :: {nid}")
            elif not already_applied(b, action):
                print(f"  [FAIL] {fname} :: {nid}", file=sys.stderr)
                return 1
            out.append(new_b)
        open(path, "w", encoding="utf-8").write("[sub_resource ".join(out))
        total += changed
        print(f"{fname}: {changed} 处修改")
    print(f"\n共修改 {total} 条")
    return 0


if __name__ == "__main__":
    sys.exit(main())
