#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4 内容深度打磨补丁
========================
对现有 dialogue .tres 进行结构化/内容补全，解决报告中两处缺口：
  1. 场景三（sc_03_indoor）所有节点 exploration_step=0、无验证分支 ——
     补齐六步标注与四级验证分支，同时保留原有「轻引导 + 推理选择题」的叙事流程。
  2. 场景七（sc_07_hotel）无华生对话 —— 插入 4 处华生反应/追问节点，增强角色互动。

输出直接覆盖原 .tres 文件（已纳入 Git，可回滚）。
"""

import re
import os
import sys
import ast
from pathlib import Path

# 复用 convert_dialogue_to_tres 的格式与函数
sys.path.insert(0, str(Path(__file__).parent))
from convert_dialogue_to_tres import (
    TRES_HEADER, NODE_TEMPLATE, RESOURCE_BODY,
    generate_tres_file, sanitize_text
)

# ============ 解析器 ============

def parse_tres(path: str):
    """将现有 .tres 解析为 (nodes_list, meta_dict, uid_str)。"""
    text = open(path, encoding="utf-8").read()
    uid = re.search(r'uid="uid://([^"]+)"', text).group(1)
    blocks = re.split(r"\n\n\n\[sub_resource type=\"Resource\" id=\"node_(\d+)\"\]\n", text)[1:]
    nodes = []
    for i in range(0, len(blocks), 2):
        content = blocks[i + 1]
        node = {}
        def field(pattern, default=""):
            m = re.search(pattern, content)
            return m.group(1) if m else default

        node["node_id"] = field(r'node_id = "(.*?)"')
        node["speaker"] = field(r'speaker = "(.*?)"')
        # text 可能包含转义双引号，需非贪婪到行尾
        node["text"] = field(r'text = "(.*)"')
        node["mood"] = field(r'mood = "(.*?)"', "neutral")
        node["trigger"] = field(r'trigger = "(.*?)"', "auto")
        # next_nodes 数组
        nm = re.search(r'next_nodes = \[(.*?)\]', content, re.S)
        if nm:
            raw = nm.group(1).strip()
            if raw == "":
                node["next_nodes"] = []
            else:
                node["next_nodes"] = re.findall(r'"([^"]*)"', raw)
        else:
            node["next_nodes"] = []
        node["diff_filter"] = int(field(r'difficulty_filter = (\d+)', "0"))
        node["verify_filter"] = field(r'verify_filter = "(.*?)"', "")
        node["step"] = int(field(r'exploration_step = (\d+)', "0"))
        node["is_entry"] = field(r'is_step_entry = (\w+)', "false") == "true"
        node["stage_dir"] = field(r'stage_direction = "(.*?)"', "")
        node["note_text"] = field(r'note_text = "(.*)"', "")
        nodes.append(node)

    # 解析 resource body 元数据（包括 nodes 列表之后的字段）
    meta = {}
    body = text.split("[resource]\n", 1)[1]
    for line in body.strip().split('\n'):
        line = line.strip()
        if line.startswith("nodes = ["):
            continue
        if '=' in line:
            k, v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            # 字符串去引号
            if v.startswith('"') and v.endswith('"'):
                v = v[1:-1]
            # 数组解析
            elif v.startswith('[') and v.endswith(']'):
                try:
                    v = ast.literal_eval(v)
                except Exception:
                    pass
            # 整数
            elif v.isdigit():
                v = int(v)
            meta[k] = v
    return nodes, meta, uid


# ============ 场景三：补齐六步 + 验证分支 ============

def patch_scene_03(nodes, meta, uid, out_path: str):
    # 将现有节点映射到六步
    step_map = {
        # 引言 / 开场
        "s3_easy_intro": 0, "s3_start": 0,
        # Step 1 观察：尸体 + 死因问题
        "s3_body1": 1, "s3_body2": 1, "s3_body3": 1,
        "s3_q1": 1, "s3_q1_right": 1, "s3_q1_a": 1, "s3_q1_b": 1, "s3_q1_d": 1,
        # Step 2 工具/细查：随身物品与信件
        "s3_items_start": 2, "s3_items1": 2, "s3_items2": 2,
        "s3_letter": 2, "s3_letter1": 2,
        # Step 3 记录：血字 RACHE
        "s3_blood": 3, "s3_blood1": 3,
        "s3_q2": 3, "s3_q2_right": 3, "s3_q2_a": 3, "s3_q2_b": 3, "s3_q2_c": 3,
        # Step 4 知识：凶手侧写
        "s3_profile_start": 4, "s3_profile1": 4,
        "s3_q3": 4, "s3_q3_right": 4, "s3_q3_b": 4, "s3_q3_c": 4, "s3_q3_d": 4,
        # Step 5 假设：戒指线索
        "s3_ring_start": 5, "s3_ring1": 5,
        "s3_q4": 5, "s3_q4_right": 5, "s3_q4_a": 5, "s3_q4_b": 5, "s3_q4_c": 5,
        # Step 6 验证：兰斯证词与最终判断
        "s3_lans_start": 6, "s3_lans1": 6,
        "s3_q5": 6, "s3_q5_right": 6, "s3_q5_a": 6, "s3_q5_b": 6, "s3_q5_c": 6,
        "s3_end": 0,
    }
    entry_nodes = {"s3_body1": 1, "s3_items_start": 2, "s3_blood": 3,
                   "s3_profile_start": 4, "s3_ring_start": 5, "s3_q5": 6}

    for n in nodes:
        nid = n["node_id"]
        n["step"] = step_map.get(nid, 0)
        n["is_entry"] = nid in entry_nodes

    # 找到 s3_q5_right 并改道到验证门
    right = next(n for n in nodes if n["node_id"] == "s3_q5_right")
    right["next_nodes"] = ["s3_verify_gate"]

    # 新增验证门与四级结果分支
    verify_nodes = [
        {
            "node_id": "s3_verify_gate",
            "speaker": "system",
            "text": "【六步闭环 Step 6】验证结论 —— 综合所有线索，判断推理等级",
            "mood": "guide",
            "trigger": "auto",
            "next_nodes": ["s3_v_verified", "s3_v_supported", "s3_v_insufficient", "s3_v_contradictory"],
            "diff_filter": 0,
            "verify_filter": "",
            "step": 6,
            "is_entry": True,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s3_v_verified",
            "speaker": "福尔摩斯",
            "text": "很好。所有线索 converged 到同一个结论：这是有预谋的复仇，凶手正是那个被兰斯放走的醉汉。推理等级：VERIFIED。",
            "mood": "自信",
            "trigger": "milestone",
            "next_nodes": ["s3_end"],
            "diff_filter": 0,
            "verify_filter": "VERIFIED",
            "step": 6,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "【里程碑】室内勘查推理完成 ⭐",
        },
        {
            "node_id": "s3_v_supported",
            "speaker": "福尔摩斯",
            "text": "方向正确，但还缺一块关键拼图。戒指、RACHE、红脸凶手都已出现，却还没连成闭环。再回去看看尸体与血字。",
            "mood": "思考",
            "trigger": "auto",
            "next_nodes": ["s3_end"],
            "diff_filter": 0,
            "verify_filter": "SUPPORTED",
            "step": 6,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s3_v_insufficient",
            "speaker": "福尔摩斯",
            "text": "线索还不够。一个醉汉、一个戒指、一行血字，任意两点都构不成完整的复仇图景。继续勘查。",
            "mood": "严肃",
            "trigger": "auto",
            "next_nodes": ["s3_end"],
            "diff_filter": 0,
            "verify_filter": "INSUFFICIENT",
            "step": 6,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s3_v_contradictory",
            "speaker": "福尔摩斯",
            "text": "你的结论和证据矛盾。一个杀人劫财的凶手不会留下 RACHE 这种复仇签名，也不会把情人的戒指带到现场。重想。",
            "mood": "严肃",
            "trigger": "auto",
            "next_nodes": ["s3_end"],
            "diff_filter": 0,
            "verify_filter": "CONTRADICTORY",
            "step": 6,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
    ]
    nodes.extend(verify_nodes)

    # 适配 generate_tres_file 的元数据键名
    meta["milestone"] = meta.get("milestone_name", "")
    meta["easy_start_node_override"] = meta.get("easy_start_node", "")
    meta["normal_start_node_override"] = meta.get("normal_start_node", "")
    meta["hard_start_node_override"] = meta.get("hard_start_node", "")

    # 更新主资源（保留原有元数据，uid 不变）
    generate_tres_file(nodes, meta, out_path)
    _restore_uid(out_path, uid)
    print(f"  ✅ scene_03_indoor: {len(nodes)} 节点，已补齐六步标注与四级验证分支")


def _restore_uid(path: str, uid: str):
    """generate_tres_file 会生成新 uid，这里恢复为原文件的 uid。"""
    text = open(path, encoding="utf-8").read()
    text = re.sub(r'uid="uid://[^"]+"', f'uid="uid://{uid}"', text, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


# ============ 场景七：插入华生对话 ============

def insert_after(nodes, target_id, new_node):
    """在 target_id 节点之后插入新节点，并承接其 next_nodes。"""
    target = next(n for n in nodes if n["node_id"] == target_id)
    new_node["next_nodes"] = target["next_nodes"].copy()
    target["next_nodes"] = [new_node["node_id"]]
    nodes.append(new_node)


def patch_scene_07(nodes, meta, uid, out_path: str):
    watson_nodes = [
        {
            "node_id": "s7_watson_react",
            "speaker": "华生",
            "text": "又是一具尸体……而且同样的 RACHE。凶手简直在向我们挑衅。",
            "mood": "凝重",
            "trigger": "auto",
            "diff_filter": 0,
            "verify_filter": "",
            "step": 0,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s7_watson_pill",
            "speaker": "华生",
            "text": "这个药丸盒很可疑——两粒珍珠灰的药丸，一粒应该剧毒，另一粒却无毒。凶手给了死者一个「选择」？",
            "mood": "疑惑",
            "trigger": "auto",
            "diff_filter": 0,
            "verify_filter": "",
            "step": 2,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s7_watson_question",
            "speaker": "华生",
            "text": "如果两次命案都是同一人所为，他为何对德雷伯用毒，对斯特兰森却用刀？这背后一定有某种……仪式感？",
            "mood": "思考",
            "trigger": "auto",
            "diff_filter": 0,
            "verify_filter": "",
            "step": 4,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
        {
            "node_id": "s7_watson_close",
            "speaker": "华生",
            "text": "上帝裁决……两粒药丸，一个选择。这个杰弗森·霍普，不仅是个复仇者，还是个审判者。",
            "mood": "疲惫",
            "trigger": "auto",
            "diff_filter": 0,
            "verify_filter": "",
            "step": 6,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        },
    ]
    insert_after(nodes, "s7_start", watson_nodes[0])
    insert_after(nodes, "s7_step2_hard", watson_nodes[1])
    insert_after(nodes, "s7_step4_hard", watson_nodes[2])
    insert_after(nodes, "s7_step6_contradictory", watson_nodes[3])

    # 适配 generate_tres_file 的元数据键名
    meta["milestone"] = meta.get("milestone_name", "")
    meta["easy_start_node_override"] = meta.get("easy_start_node", "")
    meta["normal_start_node_override"] = meta.get("normal_start_node", "")
    meta["hard_start_node_override"] = meta.get("hard_start_node", "")

    generate_tres_file(nodes, meta, out_path)
    _restore_uid(out_path, uid)
    print(f"  ✅ scene_07_hotel: {len(nodes)} 节点，已插入 4 处华生对话")


# ============ 主入口 ============

def main():
    base = "/workspace/维多利亚伦敦探案项目/godot_project/resources/dialogues"
    print("🔧 P5-4 对话内容补丁")

    nodes, meta, uid = parse_tres(os.path.join(base, "scene_03_indoor.tres"))
    patch_scene_03(nodes, meta, uid, os.path.join(base, "scene_03_indoor.tres"))

    nodes, meta, uid = parse_tres(os.path.join(base, "scene_07_hotel.tres"))
    patch_scene_07(nodes, meta, uid, os.path.join(base, "scene_07_hotel.tres"))

    print("   完成。请重新运行 Godot --import 以更新导入缓存。")


if __name__ == "__main__":
    main()
