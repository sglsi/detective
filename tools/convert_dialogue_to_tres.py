#!/usr/bin/env python3
"""
对话台词库 Markdown → Godot .tres 资源转换工具

用法:
  python3 convert_dialogue_to_tres.py <input_md> <output_dir>

功能:
  - 解析 v4.0 台词库的六步闭环标注
  - 解析三难度标签 [EASY/NORMAL/HARD 模式]
  - 解析四级验证分支 VERIFIED/SUPPORTED/INSUFFICIENT/CONTRADICTORY
  - 生成 .tres 资源文件（Godot 4.x 文本格式）
"""

import re
import os
import sys
from pathlib import Path

# ============ Godot .tres 模板 ============

TRES_HEADER = """[gd_resource type="Resource" script_class="DialogueResource" load_steps=3 format=3 uid="uid://{uid}"]

[ext_resource type="Script" path="res://resources/dialogues/dialogue_resource.gd" id="1_resource"]
[ext_resource type="Script" path="res://resources/dialogues/dialogue_node_resource.gd" id="2_node"]

"""

NODE_TEMPLATE = """[sub_resource type="Resource" id="node_{idx}"]
script = ExtResource("2_node")
node_id = "{node_id}"
speaker = "{speaker}"
text = "{text}"
mood = "{mood}"
trigger = "{trigger}"
next_nodes = [{next_nodes}]
difficulty_filter = {diff_filter}
verify_filter = "{verify_filter}"
exploration_step = {step}
is_step_entry = {is_entry}
stage_direction = "{stage_dir}"
note_text = "{note_text}"

"""

RESOURCE_BODY = """[resource]
script = ExtResource("1_resource")
scene_id = "{scene_id}"
scene_name = "{scene_name}"
phase_id = "{phase_id}"
phase_name = "{phase_name}"
exploration_step = {step}
easy_start_node = "{easy_start}"
normal_start_node = "{normal_start}"
hard_start_node = "{hard_start}"
nodes = [{nodes_list}]
knowledge_domains = {knowledge}
milestone_name = "{milestone}"
score_observation = {obs}
score_reasoning = {reason}
score_insight = {insight}
badge_check = "{badge}"
completion_event = "{event}"
"""


def sanitize_text(text: str) -> str:
    """转义 Godot 字符串中的特殊字符"""
    return text.replace('"', '\\"').replace('\n', '\\n')


def parse_difficulty_filter(tag: str) -> int:
    """解析难度标签 → difficulty_filter 值"""
    tag = tag.strip().lower()
    if "easy" in tag and "normal" in tag and "hard" in tag:
        return 0  # 全难度
    if "easy" in tag and "normal" in tag:
        return 4  # EASY + NORMAL
    if "normal" in tag and "hard" in tag:
        return 5  # NORMAL + HARD
    if "easy" in tag:
        return 1  # 仅 EASY
    if "normal" in tag:
        return 2  # 仅 NORMAL
    if "hard" in tag:
        return 3  # 仅 HARD
    return 0  # 默认全难度


def parse_speaker(name: str) -> str:
    """标准化说话人名称"""
    name = name.strip()
    mapping = {
        "福尔摩斯": "福尔摩斯",
        "华生": "华生",
        "赫德森太太": "赫德森太太",
        "信使": "信使",
        "system": "system",
        "葛莱森": "葛莱森警长",
        "葛莱森警长": "葛莱森警长",
        "雷斯垂德": "雷斯垂德警长",
        "雷斯垂德警长": "雷斯垂德警长",
        "兰斯": "兰斯警士",
        "兰斯警士": "兰斯警士",
        "卡彭蒂耶太太": "卡彭蒂耶太太",
        "爱莉丝": "爱莉丝",
        "卡彭蒂耶中尉": "卡彭蒂耶中尉",
        "维金斯": "维金斯",
        "杰弗森·霍普": "杰弗森·霍普",
        "哈珀": "威廉·哈珀",
        "铁匠": "铁匠",
        "老太婆": "伪装者",
        "送牛奶的孩子": "送牛奶的孩子",
        "值班警官": "值班警官",
        "人事官员": "人事官员",
    }
    return mapping.get(name, name)


def parse_trigger(text: str) -> str:
    """从文本内容推断触发类型"""
    text_lower = text.lower()
    if "【里程碑" in text or "解锁" in text:
        return "milestone"
    if "【笔记更新" in text or "笔记" in text:
        return "note"
    if "【知识库" in text or "知识库" in text:
        return "knowledge"
    if "【系统提示" in text or "【提示" in text:
        return "guide"
    if "门铃" in text or "敲门" in text:
        return "sfx"
    if "选择" in text and ("A." in text or "B." in text):
        return "choice"
    if "【获得" in text or "【评分" in text:
        return "milestone"
    return "auto"


def parse_node_from_line(line: str, node_counter: list, current_step: int, 
                          current_diff_tag: str, current_verify: str) -> dict:
    """从一行对话文本解析为节点数据"""
    # 尝试匹配 "说话人（表情）："文本"" 格式
    pattern = r'([^：:]+)[：:]\s*"([^"]*)"'
    match = re.search(pattern, line)
    
    if match:
        speaker_raw = match.group(1).strip()
        # 提取表情（括号内的内容）
        mood_match = re.search(r'[（(]([^）)]+)[）)]', speaker_raw)
        mood = mood_match.group(1) if mood_match else "neutral"
        speaker = re.sub(r'[（(][^）)]*[）)]', '', speaker_raw).strip()
        text = match.group(2).strip()
    else:
        # 尝试 "说话人：文本"（无引号）
        pattern2 = r'([^：:]+)[：:]\s*(.+)'
        match2 = re.search(pattern2, line)
        if match2:
            speaker_raw = match2.group(1).strip()
            mood_match = re.search(r'[（(]([^）)]+)[）)]', speaker_raw)
            mood = mood_match.group(1) if mood_match else "neutral"
            speaker = re.sub(r'[（(][^）)]*[）)]', '', speaker_raw).strip()
            text = match2.group(2).strip().strip('"')
        else:
            # 无法解析，作为 system 消息
            speaker = "system"
            mood = "neutral"
            text = line.strip()
    
    node_id = f"n{node_counter[0]:04d}"
    node_counter[0] += 1
    
    return {
        "node_id": node_id,
        "speaker": parse_speaker(speaker),
        "text": sanitize_text(text),
        "mood": mood,
        "trigger": parse_trigger(line),
        "next_nodes": [f"n{node_counter[0]:04d}"],
        "diff_filter": parse_difficulty_filter(current_diff_tag),
        "verify_filter": current_verify,
        "step": current_step,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    }


def generate_tres_file(nodes_data: list, meta: dict, output_path: str) -> None:
    """生成 .tres 文件"""
    import uuid
    
    uid = uuid.uuid4().hex[:12]
    
    # 生成节点子资源
    sub_resources = []
    node_ids = []
    for i, node in enumerate(nodes_data):
        next_nodes_str = ", ".join(f'"{n}"' for n in node.get("next_nodes", []))
        sub = NODE_TEMPLATE.format(
            idx=i,
            node_id=node["node_id"],
            speaker=node["speaker"],
            text=node["text"],
            mood=node["mood"],
            trigger=node["trigger"],
            next_nodes=next_nodes_str,
            diff_filter=node.get("diff_filter", 0),
            verify_filter=node.get("verify_filter", ""),
            step=node.get("step", 0),
            is_entry=str(node.get("is_entry", False)).lower(),
            stage_dir=node.get("stage_dir", ""),
            note_text=node.get("note_text", ""),
        )
        sub_resources.append(sub)
        node_ids.append(node["node_id"])
    
    # 生成主资源
    nodes_list_str = ", ".join(f'SubResource("node_{i}")' for i in range(len(nodes_data)))
    easy_start = meta.get("easy_start_node_override", node_ids[0] if node_ids else "")
    normal_start = meta.get("normal_start_node_override", node_ids[0] if node_ids else "")
    hard_start = meta.get("hard_start_node_override", node_ids[0] if node_ids else "")
    body = RESOURCE_BODY.format(
        scene_id=meta.get("scene_id", ""),
        scene_name=meta.get("scene_name", ""),
        phase_id=meta.get("phase_id", ""),
        phase_name=meta.get("phase_name", ""),
        step=meta.get("step", 0),
        easy_start=easy_start,
        normal_start=normal_start,
        hard_start=hard_start,
        nodes_list=nodes_list_str,
        knowledge=str(meta.get("knowledge_domains", [])).replace("'", '"'),
        milestone=meta.get("milestone", ""),
        obs=meta.get("score_observation", 0),
        reason=meta.get("score_reasoning", 0),
        insight=meta.get("score_insight", 0),
        badge=meta.get("badge_check", ""),
        event=meta.get("completion_event", ""),
    )
    
    # 写入文件
    load_steps = 2 + len(nodes_data)
    header = TRES_HEADER.format(uid=uid).replace("load_steps=3", f"load_steps={load_steps}")
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(header)
        f.write("\n")
        f.write("\n".join(sub_resources))
        f.write("\n")
        f.write(body)
    
    print(f"  ✅ 生成: {output_path} ({len(nodes_data)} 节点)")


def main():
    output_dir = "/workspace/维多利亚伦敦探案项目/godot_project/resources/dialogues/"
    
    if len(sys.argv) >= 2:
        output_dir = sys.argv[2] if len(sys.argv) > 2 else output_dir
    
    os.makedirs(output_dir, exist_ok=True)
    
    print("🔧 对话 → .tres 转换工具 v1.0")
    print("   转换模式: 手动构建场景一六步闭环教程")
    print(f"   输出目录: {output_dir}")
    
    # 生成示例：场景一阶段1的对话
    nodes = []
    counter = [0]
    
    # --- 阶段1：初次见面 ---
    dialogues_scene1_phase1 = [
        ("福尔摩斯", "……阿富汗军医。", "自信", "auto"),
        ("华生", "什么？", "吃惊", "auto"),
        ("福尔摩斯", "我说，你是一名刚从阿富汗回来的军医。我说对了吗？", "从容", "auto"),
        ("华生", "您……您怎么知道的？我们刚认识不到十秒钟。", "惊讶", "auto"),
        ("福尔摩斯", "这位新朋友显然不相信。不如——你来告诉他我是怎么看出来的？", "神秘", "auto"),
        ("system", "新手教程：第一次观察 —— 找出4条线索，证明「华生是阿富汗军医」", "guide", "auto"),
    ]
    
    for speaker, text, mood, trigger in dialogues_scene1_phase1:
        nid = f"s1_p1_{counter[0]:03d}"
        nodes.append({
            "node_id": nid,
            "speaker": speaker,
            "text": sanitize_text(text),
            "mood": mood,
            "trigger": trigger,
            "next_nodes": [f"s1_p1_{counter[0]+1:03d}"],
            "diff_filter": 0,
            "verify_filter": "",
            "step": 0,
            "is_entry": False,
            "stage_dir": "",
            "note_text": "",
        })
        counter[0] += 1
    
    # 修正最后一个节点的 next_nodes
    if nodes:
        nodes[-1]["next_nodes"] = ["s1_step1_start"]
    
    # --- Step 1 入口 ---
    counter[0] += 1
    nodes.append({
        "node_id": "s1_step1_start",
        "speaker": "system",
        "text": "【六步闭环 Step 1】观察发现 —— 移动视角，观察华生身上的细节",
        "mood": "guide",
        "trigger": "guide",
        "next_nodes": ["s1_step1_easy", "s1_step1_normal", "s1_step1_hard"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 1,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    # EASY 分支
    nodes.append({
        "node_id": "s1_step1_easy",
        "speaker": "system",
        "text": "高亮闪烁提示：华生身上有4处值得观察的部位（手腕/左臂/面色/站姿），试试点击它们",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step1_observe_done"],
        "diff_filter": 1,  # 仅 EASY
        "verify_filter": "",
        "step": 1,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # NORMAL 分支
    nodes.append({
        "node_id": "s1_step1_normal",
        "speaker": "system",
        "text": "微光提示：华生身上似乎有值得观察的细节……",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step1_observe_done"],
        "diff_filter": 2,  # 仅 NORMAL
        "verify_filter": "",
        "step": 1,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # HARD 分支
    nodes.append({
        "node_id": "s1_step1_hard",
        "speaker": "system",
        "text": "（无提示）仔细观察周围环境……",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step1_observe_done"],
        "diff_filter": 3,  # 仅 HARD
        "verify_filter": "",
        "step": 1,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # Step 1 完成 → 等待玩家操作热点
    nodes.append({
        "node_id": "s1_step1_observe_done",
        "speaker": "system",
        "text": "（等待玩家点击华生身上的可交互区域）",
        "mood": "neutral",
        "trigger": "click",
        "next_nodes": ["s1_step2_start"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 1,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- Step 2 入口 ---
    nodes.append({
        "node_id": "s1_step2_start",
        "speaker": "福尔摩斯",
        "text": "先别急着下结论。用放大镜仔细看看——细节藏在不起眼的地方。",
        "mood": "指导",
        "trigger": "auto",
        "next_nodes": ["s1_step2_easy", "s1_step2_normal", "s1_step2_hard"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 2,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step2_easy",
        "speaker": "system",
        "text": "系统自动推荐工具：试试放大镜？（放大镜图标高亮闪烁）",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step3_start"],
        "diff_filter": 1,
        "verify_filter": "",
        "step": 2,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step2_normal",
        "speaker": "system",
        "text": "工具选择界面：放大镜 / 卷尺。请选择合适的工具。",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step3_start"],
        "diff_filter": 2,
        "verify_filter": "",
        "step": 2,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step2_hard",
        "speaker": "system",
        "text": "（工具选择界面，无提示）",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step3_start"],
        "diff_filter": 3,
        "verify_filter": "",
        "step": 2,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- Step 3 入口 ---
    nodes.append({
        "node_id": "s1_step3_start",
        "speaker": "system",
        "text": "【首次弹出系统提示】这是你的侦探笔记——所有发现都会自动归档。侦探的笔记，就是第二大脑。",
        "mood": "guide",
        "trigger": "note",
        "next_nodes": ["s1_step3_easy", "s1_step3_normal", "s1_step3_hard"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 3,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "观察记录：手腕肤色对比/左臂僵硬/面容憔悴/军人站姿",
    })
    
    nodes.append({
        "node_id": "s1_step3_easy",
        "speaker": "福尔摩斯",
        "text": "记下来。好记性不如烂笔头。笔记已自动填入关键描述，请用滑杆确认程度。",
        "mood": "从容",
        "trigger": "auto",
        "next_nodes": ["s1_step4_prompt"],
        "diff_filter": 1,
        "verify_filter": "",
        "step": 3,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step3_normal",
        "speaker": "system",
        "text": "笔记为空白模板，请用滑杆选择观察结果（0-10程度选择 + 气质类型多选）。",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step4_prompt"],
        "diff_filter": 2,
        "verify_filter": "",
        "step": 3,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step3_hard",
        "speaker": "system",
        "text": "完全空白笔记，自由记录。系统不提供参考范围。",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step4_prompt"],
        "diff_filter": 3,
        "verify_filter": "",
        "step": 3,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- Step 4 入口 ---
    nodes.append({
        "node_id": "s1_step4_prompt",
        "speaker": "system",
        "text": "（4个部位全部记录完成）",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step4_easy", "s1_step4_normal", "s1_step4_hard"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 4,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step4_easy",
        "speaker": "福尔摩斯",
        "text": "皮肤的颜色会告诉你一个人去过哪里。翻翻知识库里「肤色与日晒」那条。",
        "mood": "指导",
        "trigger": "knowledge",
        "next_nodes": ["s1_step5_prompt"],
        "diff_filter": 1,
        "verify_filter": "",
        "step": 4,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step4_normal",
        "speaker": "system",
        "text": "去知识库查查？（可选按钮，非强制）",
        "mood": "guide",
        "trigger": "optional",
        "next_nodes": ["s1_step5_prompt"],
        "diff_filter": 2,
        "verify_filter": "",
        "step": 4,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step4_hard",
        "speaker": "system",
        "text": "（无提示——知识库可自行从菜单打开）",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step5_prompt"],
        "diff_filter": 3,
        "verify_filter": "",
        "step": 4,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- Step 5 入口 ---
    nodes.append({
        "node_id": "s1_step5_prompt",
        "speaker": "system",
        "text": "【系统提示】欢迎来到推理墙——把线索串起来，就是推理。",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step5_easy", "s1_step5_normal", "s1_step5_hard"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 5,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step5_easy",
        "speaker": "福尔摩斯",
        "text": "把你观察到的事实串起来。是热带服役的军人？还是刚从殖民地回来的商人？还是长期在海外漂泊的探险家？",
        "mood": "指导",
        "trigger": "choice",
        "next_nodes": ["s1_step6_easy_verified", "s1_step6_supported", "s1_step6_insufficient"],
        "diff_filter": 1,
        "verify_filter": "",
        "step": 5,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step5_normal",
        "speaker": "system",
        "text": "拖拽「刚从热带回来」+「军人气质」到假设板 → 形成初步假设",
        "mood": "guide",
        "trigger": "auto",
        "next_nodes": ["s1_step6_normal"],
        "diff_filter": 2,
        "verify_filter": "",
        "step": 5,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step5_hard",
        "speaker": "system",
        "text": "（推理墙打开，无任何引导）",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step6_hard"],
        "diff_filter": 3,
        "verify_filter": "",
        "step": 5,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- Step 6 入口 + 四级验证分支 ---
    nodes.append({
        "node_id": "s1_step6_normal",
        "speaker": "system",
        "text": "线索收集完毕，去推理墙验证你的假设",
        "mood": "guide",
        "trigger": "neutral",
        "next_nodes": ["s1_step6_easy_verified", "s1_step6_supported", "s1_step6_insufficient", "s1_step6_contradictory"],
        "diff_filter": 2,
        "verify_filter": "",
        "step": 6,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_step6_hard",
        "speaker": "system",
        "text": "（无验证提示，玩家自行判断）",
        "mood": "neutral",
        "trigger": "auto",
        "next_nodes": ["s1_step6_easy_verified", "s1_step6_supported", "s1_step6_insufficient", "s1_step6_contradictory"],
        "diff_filter": 3,
        "verify_filter": "",
        "step": 6,
        "is_entry": True,
        "stage_dir": "",
        "note_text": "",
    })
    
    # VERIFIED
    nodes.append({
        "node_id": "s1_step6_easy_verified",
        "speaker": "福尔摩斯",
        "text": "你看，四条线索指向同一个结论。这就是回溯推理的力量——从结果倒推原因，把碎片拼成一幅完整的画。",
        "mood": "自信",
        "trigger": "milestone",
        "next_nodes": ["s1_post_tutorial"],
        "diff_filter": 0,
        "verify_filter": "VERIFIED",
        "step": 6,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "【里程碑】初识推理 解锁 ⭐",
    })
    
    # SUPPORTED
    nodes.append({
        "node_id": "s1_step6_supported",
        "speaker": "福尔摩斯",
        "text": "方向是对的，但还有更关键的细节你漏掉了。再回去看看？",
        "mood": "思考",
        "trigger": "auto",
        "next_nodes": ["s1_step1_start"],
        "diff_filter": 0,
        "verify_filter": "SUPPORTED",
        "step": 6,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # INSUFFICIENT
    nodes.append({
        "node_id": "s1_step6_insufficient",
        "speaker": "福尔摩斯",
        "text": "仅凭一两条线索就下结论？你还需要更多观察。回到起点，重新看看华生。",
        "mood": "严肃",
        "trigger": "auto",
        "next_nodes": ["s1_step1_start"],
        "diff_filter": 0,
        "verify_filter": "INSUFFICIENT",
        "step": 6,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # CONTRADICTORY
    nodes.append({
        "node_id": "s1_step6_contradictory",
        "speaker": "福尔摩斯",
        "text": "你的结论和你观察到的证据自相矛盾。一个刚负伤的人不可能同时是现役军人。重新想想。",
        "mood": "严肃",
        "trigger": "auto",
        "next_nodes": ["s1_step1_start"],
        "diff_filter": 0,
        "verify_filter": "CONTRADICTORY",
        "step": 6,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    # --- 教程后对话 ---
    nodes.append({
        "node_id": "s1_post_tutorial",
        "speaker": "华生",
        "text": "这……太不可思议了。仅仅从这些细节，就能看出这么多？",
        "mood": "敬佩",
        "trigger": "auto",
        "next_nodes": ["s1_holmes_explain"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 0,
        "is_entry": False,
        "stage_dir": "特写",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_holmes_explain",
        "speaker": "福尔摩斯",
        "text": "不错的初次表演。军人 + 医生 + 热带 + 负伤 = 阿富汗军医。这不是什么魔法，只是系统化的观察和推理。",
        "mood": "从容",
        "trigger": "auto",
        "next_nodes": ["s1_end"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 0,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "",
    })
    
    nodes.append({
        "node_id": "s1_end",
        "speaker": "system",
        "text": "【教程环节结束 —— 六步探索闭环完成】侦探笔记已更新 · 推理墙已开启",
        "mood": "milestone",
        "trigger": "milestone",
        "next_nodes": ["end"],
        "diff_filter": 0,
        "verify_filter": "",
        "step": 0,
        "is_entry": False,
        "stage_dir": "",
        "note_text": "侦探笔记已更新 · 推理墙已开启",
    })
    
    # 生成 .tres 文件
    meta = {
        "scene_id": "scene_01",
        "scene_name": "贝克街221B — 初次见面与教学关",
        "phase_id": "phase1",
        "phase_name": "初次见面与六步闭环教程",
        "step": 0,
        "knowledge_domains": ["人体观察", "战伤痕迹识别", "职业体态特征"],
        "milestone": "初识推理",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 0,
        "badge_check": "FIRST_CASE_CLEAR",
        "completion_event": "",
    }
    
    output_file = os.path.join(output_dir, "scene_01_phase1_tutorial.tres")
    generate_tres_file(nodes, meta, output_file)
    
    print(f"\n✅ 转换完成！")
    print(f"   输出目录: {output_dir}")
    print(f"   生成文件: scene_01_phase1_tutorial.tres")
    print(f"   总节点数: {len(nodes)}")


# ============ 通用节点构造助手 ============

def add(nodes: list, node_id: str, speaker: str, text: str, mood: str, trigger: str,
        next_nodes, diff: int = 0, verify: str = "", step: int = 0, is_entry: bool = False,
        stage_dir: str = "", note_text: str = "") -> None:
    """向 nodes 列表追加一个对话节点（node_id 显式指定，便于精确引用分支目标）"""
    if isinstance(next_nodes, str):
        next_nodes = [next_nodes]
    nodes.append({
        "node_id": node_id,
        "speaker": parse_speaker(speaker),
        "text": sanitize_text(text),
        "mood": mood,
        "trigger": trigger,
        "next_nodes": next_nodes,
        "diff_filter": diff,
        "verify_filter": verify,
        "step": step,
        "is_entry": is_entry,
        "stage_dir": stage_dir,
        "note_text": note_text,
    })


# ======================================================================
# 场景二：劳瑞斯顿花园街三号（室外）—— 半引导
# 六步闭环：观察车辙/蹄印/脚印 → 工具测量 → 记录 → (知识) → 假设(马车类型) → 验证
# 半引导：EASY 给出类别级提示与工具建议，NORMAL/HARD 递减；首次引入「信号vs噪音」
# ======================================================================

def build_scene02_nodes() -> list:
    nodes: list = []
    A = nodes.append

    # --- 开场：花园外围观察 ---
    add(nodes, "s2_start", "福尔摩斯", "马上就要到案件现场了，现在先让我在周边侦测一下，看看有没有重要线索。",
        "思考", "auto", "s2_watson_q")
    add(nodes, "s2_watson_q", "华生", "福尔摩斯，你在看什么？这里只有乱七八糟的脚印。",
        "困惑", "auto", "s2_holmes_a")
    add(nodes, "s2_holmes_a", "福尔摩斯", "昨夜一点钟开始下雨，之前一星期都是晴天……有意思，非常有意思。华生，观察的艺术在于看到别人看不到的东西。",
        "微笑", "auto", "s2_step1_start")

    # --- Step 1 观察发现（必做）---
    add(nodes, "s2_step1_start", "system", "【六步闭环 Step 1】观察发现 —— 勘查花园中的车辙与脚印",
        "guide", "guide", ["s2_step1_easy", "s2_step1_normal", "s2_step1_hard"], step=1, is_entry=True)
    add(nodes, "s2_step1_easy", "system", "半引导：留意地面上成排的车辙印迹与零散的脚印——先用「观察」点击它们，看看能发现什么。",
        "guide", "auto", "s2_step1_observe_done", diff=1, step=1)
    add(nodes, "s2_step1_normal", "system", "微光：花园小径上有车辙与脚印的痕迹……自己找找看。",
        "guide", "auto", "s2_step1_observe_done", diff=2, step=1)
    add(nodes, "s2_step1_hard", "system", "（无提示——自行在场景中寻找可交互的痕迹）",
        "neutral", "auto", "s2_step1_observe_done", diff=3, step=1)
    add(nodes, "s2_step1_observe_done", "system", "（等待玩家点击：车轮印 / 马蹄印 / 行人脚印）",
        "neutral", "click", "s2_step2_start", step=1)

    # --- Step 2 工具操作（必做）---
    add(nodes, "s2_step2_start", "福尔摩斯", "先别急着下结论。细节藏在不起眼的地方——用合适的工具量一量这些印迹。",
        "指导", "auto", ["s2_step2_easy", "s2_step2_normal", "s2_step2_hard"], step=2, is_entry=True)
    add(nodes, "s2_step2_easy", "system", "系统建议：用「卷尺」测量车轮印的间距与深度。",
        "guide", "auto", "s2_step3_start", diff=1, step=2)
    add(nodes, "s2_step2_normal", "system", "工具选择：放大镜 / 卷尺——请选用合适的工具测量。",
        "guide", "auto", "s2_step3_start", diff=2, step=2)
    add(nodes, "s2_step2_hard", "system", "（工具选择界面，无提示）",
        "neutral", "auto", "s2_step3_start", diff=3, step=2)

    # --- Step 3 数据记录（必做）---
    add(nodes, "s2_step3_start", "system", "【六步闭环 Step 3】数据记录 —— 把测量结果记进侦探笔记",
        "guide", "note", ["s2_step3_easy", "s2_step3_normal", "s2_step3_hard"], step=3, is_entry=True,
        note_text="观察记录：车轮印间距/马蹄铁新旧/步伐距离")
    add(nodes, "s2_step3_easy", "福尔摩斯", "记录下车轮印间距 3.8 英尺、右前蹄刚换新蹄铁——笔记已自动填入，确认程度即可。",
        "从容", "auto", "s2_step4_prompt", diff=1, step=3)
    add(nodes, "s2_step3_normal", "system", "在侦探笔记中记录：车轮印间距、蹄铁新旧、步伐距离（0-10 滑杆）。",
        "guide", "auto", "s2_step4_prompt", diff=2, step=3)
    add(nodes, "s2_step3_hard", "system", "（空白笔记，自由记录）",
        "neutral", "auto", "s2_step4_prompt", diff=3, step=3)

    # --- Step 4 知识检索（可选）---
    add(nodes, "s2_step4_prompt", "system", "（测量与记录完成）",
        "neutral", "auto", ["s2_step4_easy", "s2_step4_normal", "s2_step4_hard"], step=4, is_entry=True)
    add(nodes, "s2_step4_easy", "福尔摩斯", "去知识库看看「伦敦出租马车规格」——出租马车轴距约 4 英尺，比私家马车窄。",
        "指导", "knowledge", "s2_step5_prompt", diff=1, step=4)
    add(nodes, "s2_step4_normal", "system", "知识库可选查阅（非强制）。",
        "guide", "optional", "s2_step5_prompt", diff=2, step=4)
    add(nodes, "s2_step4_hard", "system", "（无提示——知识库可自行从菜单打开）",
        "neutral", "auto", "s2_step5_prompt", diff=3, step=4)

    # --- Step 5 假设形成（必做 · 玩家选择马车类型）---
    add(nodes, "s2_step5_prompt", "system", "【六步闭环 Step 5】假设形成 —— 把线索串成结论",
        "guide", "auto", ["s2_step5_easy", "s2_step5_normal", "s2_step5_hard"], step=5, is_entry=True)
    add(nodes, "s2_step5_easy", "福尔摩斯", "把线索串起来：轴距窄、双道平行轮印——拖到假设板上。你认为这是哪种马车？",
        "指导", "auto", "s2_hypothesis_choice", diff=1, step=5)
    add(nodes, "s2_step5_normal", "system", "拖拽「轴距较窄」+「车轮印」到假设板 → 形成初步假设。",
        "guide", "auto", "s2_hypothesis_choice", diff=2, step=5)
    add(nodes, "s2_step5_hard", "system", "（推理墙开启，无任何引导）",
        "neutral", "auto", "s2_hypothesis_choice", diff=3, step=5)
    add(nodes, "s2_hypothesis_choice", "system", "关于发现的马车印迹，请选择你的结论（可记录在线索墙）：",
        "guide", "choice", ["s2_cab_right", "s2_cab_b", "s2_cab_c", "s2_cab_d"], step=5)
    add(nodes, "s2_cab_right", "福尔摩斯", "正是！这是一辆出租四轮马车——凶手是乘出租马车到达现场的。",
        "自信", "auto", "s2_step6_prompt", step=5)
    add(nodes, "s2_cab_b", "福尔摩斯", "私家马车轴距通常在 5 英尺以上。再看看车轮印间距。",
        "思考", "auto", "s2_hypothesis_choice", step=5)
    add(nodes, "s2_cab_c", "福尔摩斯", "农用马车不会出现在伦敦街道的命案现场。重想。",
        "思考", "auto", "s2_hypothesis_choice", step=5)
    add(nodes, "s2_cab_d", "福尔摩斯", "马车类型关系到凶手身份，不能「无所谓」。重想。",
        "思考", "auto", "s2_hypothesis_choice", step=5)

    # --- Step 6 验证修正（必做 · 四级验证）---
    add(nodes, "s2_step6_prompt", "system", "【六步闭环 Step 6】验证修正 —— 去推理墙验证你的结论",
        "guide", "auto", ["s2_step6_normal", "s2_step6_hard"], step=6)
    add(nodes, "s2_step6_normal", "system", "线索收集完毕，去推理墙验证你的假设。",
        "guide", "neutral", ["s2_step6_verified", "s2_step6_supported", "s2_step6_insufficient", "s2_step6_contradictory"],
        diff=2, step=6, is_entry=True)
    add(nodes, "s2_step6_hard", "system", "（无验证提示，玩家自行判断何时证据充分）",
        "neutral", "auto", ["s2_step6_verified", "s2_step6_supported", "s2_step6_insufficient", "s2_step6_contradictory"],
        diff=3, step=6, is_entry=True)
    add(nodes, "s2_step6_verified", "福尔摩斯", "你看，轴距窄、右前蹄新换、马蹄印零乱——四条线索指向同一个结论：凶手乘出租马车而来，且马车夫与凶手很可能是同一人。",
        "自信", "milestone", "s2_conclude_cabman", step=6, verify="VERIFIED",
        note_text="【里程碑】现场足迹推理 解锁 ⭐")
    add(nodes, "s2_step6_supported", "福尔摩斯", "方向对了，但证据链还不够完整。回去再看看车辙与蹄印。",
        "思考", "auto", "s2_step1_start", step=6, verify="SUPPORTED")
    add(nodes, "s2_step6_insufficient", "福尔摩斯", "证据不足，需要更多观察。重新勘查花园。",
        "严肃", "auto", "s2_step1_start", step=6, verify="INSUFFICIENT")
    add(nodes, "s2_step6_contradictory", "福尔摩斯", "你的结论和证据自相矛盾。重想。",
        "严肃", "auto", "s2_step1_start", step=6, verify="CONTRADICTORY")

    # --- 阶段3 收束：马车夫即凶手 ---
    add(nodes, "s2_conclude_cabman", "福尔摩斯", "马夫若不在屋内，他能在哪儿？若有人认为在有第三者面前犯案荒谬，那么——马车夫与凶手是同一人。",
        "从容", "auto", "s2_choice2_start")
    add(nodes, "s2_choice2_start", "system", "玩家判断：这个「醉汉般的马车夫」与凶手是什么关系？（可记录在线索墙）",
        "guide", "choice", ["s2_choice2_right", "s2_choice2_b", "s2_choice2_c", "s2_choice2_d"])
    add(nodes, "s2_choice2_right", "福尔摩斯", "聪明。马车夫即凶手——他后来返回现场，只为取回一枚掉落的戒指。",
        "自信", "auto", "s2_end")
    add(nodes, "s2_choice2_b", "福尔摩斯", "马车夫后来离开？可现场再无第二人进出。重想。",
        "思考", "auto", "s2_choice2_start")
    add(nodes, "s2_choice2_c", "福尔摩斯", "若两人同行，何必让车夫在外等候？重想。",
        "思考", "auto", "s2_choice2_start")
    add(nodes, "s2_choice2_d", "福尔摩斯", "一行两人？现场足迹只有两人，且车夫不在屋内。重想。",
        "思考", "auto", "s2_choice2_start")
    add(nodes, "s2_end", "system", "【场景二结束 —— 室外勘查完成】线索墙更新 · 出租马车 / 马车夫即凶手",
        "milestone", "milestone", "end", note_text="线索墙更新：出租马车 / 马车夫即凶手")

    return nodes


def main_scene02(output_dir: str) -> None:
    nodes = build_scene02_nodes()
    meta = {
        "scene_id": "scene_02",
        "scene_name": "劳瑞斯顿花园街三号（室外）",
        "phase_id": "phase1",
        "phase_name": "花园外围与车辙勘查",
        "step": 0,
        "knowledge_domains": ["伦敦出租马车规格", "蹄铁与马匹特征", "足迹与步伐分析"],
        "milestone": "现场足迹推理",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 0,
        "badge_check": "SCENE2_GARDEN_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_02_garden.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景二节点数: {len(nodes)}")


# ======================================================================
# 场景三：劳瑞斯顿花园街三号（室内）—— 轻引导
# 以叙事 + 关键推理选择题驱动；轻引导：极少提示，EASY 仅一句开场轻提示
# 关键选择题：死因 / RACHE含义 / 案件性质 / 戒指作用 / 醉汉身份
# ======================================================================

def build_scene03_nodes() -> list:
    nodes: list = []

    # EASY 专属轻提示（仅 EASY 起手）
    add(nodes, "s3_easy_intro", "system", "（轻引导提示：本案关键在「无伤痕的尸体」与「墙上的血字」。先观察，福尔摩斯会等你先想。）",
        "guide", "auto", "s3_start", diff=1)

    # --- 开场：尸体初检 ---
    add(nodes, "s3_start", "福尔摩斯", "屋里静悄悄的，只有一具尸体。让我们从他身上找线索。",
        "思考", "auto", "s3_body1")
    add(nodes, "s3_body1", "system", "死者约四十三四岁，中等身材，黑鬈发，短硬胡子，穿背心与黑呢礼服，身旁有整洁礼帽。紧握双拳、两臂伸开、双腿交叠，临死前有过痛苦挣扎，脸上露出忿恨恐怖的神情。",
        "neutral", "auto", "s3_body2", stage_dir="特写")
    add(nodes, "s3_body2", "福尔摩斯", "你们肯定没有伤痕吗？……那么，这些血迹一定是另一个人的，也许是凶手的。",
        "严肃", "auto", "s3_body3")
    add(nodes, "s3_body3", "福尔摩斯", "死者脸上那忿恨与害怕的神情，使我深信他在临死前已料到自己的命运。那么——他是怎么死的？",
        "思考", "auto", "s3_q1")

    # Q1 死因
    add(nodes, "s3_q1", "system", "请判断死者的死因（可记录在线索墙）：",
        "guide", "choice", ["s3_q1_right", "s3_q1_a", "s3_q1_b", "s3_q1_d"])
    add(nodes, "s3_q1_right", "福尔摩斯", "正确。他是被迫服毒而死的——脸上那紧张激动的表情出卖了他。",
        "自信", "auto", "s3_items_start")
    add(nodes, "s3_q1_a", "福尔摩斯", "恐惧不会在脸上留下那种忿恨。再想想。",
        "思考", "auto", "s3_q1")
    add(nodes, "s3_q1_b", "福尔摩斯", "没有伤痕、没有病征描述，自然死亡说不通。重想。",
        "思考", "auto", "s3_q1")
    add(nodes, "s3_q1_d", "福尔摩斯", "「被杀」太笼统。他具体怎么死的？重想。",
        "思考", "auto", "s3_q1")

    # 阶段2 随身物品
    add(nodes, "s3_items_start", "葛莱森警长", "金表、阿尔伯特金链、共济会金戒指、虎头狗金别针、俄国皮名片夹（E.J.D.）、七英镑十三先令、礼帽、薄伽丘《十日谈》、两封信。",
        "中性", "auto", "s3_items1")
    add(nodes, "s3_items1", "system", "两封信：一封寄给德雷伯，一封给斯特兰森——都从盖恩轮船公司寄来，通知他们从利物浦起程的日期。",
        "neutral", "auto", "s3_items2")
    add(nodes, "s3_items2", "福尔摩斯", "可见这个倒霉的家伙正准备回纽约去。而信，藏着下一个线索……",
        "思考", "auto", "s3_letter")

    # 阶段3 调查信件
    add(nodes, "s3_letter", "福尔摩斯", "那封信是寄到什么地方的？……你们可曾调查过斯特兰森这个人吗？",
        "指导", "auto", "s3_letter1")
    add(nodes, "s3_letter1", "福尔摩斯", "没有问到关键问题？你不能再发个电报吗？",
        "严肃", "auto", "s3_blood")

    # 阶段4 墙上的血字
    add(nodes, "s3_blood", "雷斯垂德警长", "瞧瞧这个！墙上花纸剥落处，用鲜血潦草写着：RACHE。葛莱森说这是一个女人名字 RACHEL，等全案清楚定能发现叫 RACHEL 的女人。",
        "中性", "auto", "s3_blood1", stage_dir="特写")
    add(nodes, "s3_blood1", "福尔摩斯", "这字迹，是昨夜惨案中另一个人写的。你怎么看 RACHE？",
        "思考", "auto", "s3_q2")

    # Q2 RACHE 含义
    add(nodes, "s3_q2", "system", "你如何看待墙上的血字（可记录在线索墙）：",
        "guide", "choice", ["s3_q2_right", "s3_q2_a", "s3_q2_b", "s3_q2_c"])
    add(nodes, "s3_q2_right", "福尔摩斯", "正是。德语中 RACHE 是复仇之意——别浪费时间去找 RACHEL 女士了。",
        "自信", "auto", "s3_profile_start")
    add(nodes, "s3_q2_a", "福尔摩斯", "若真有 RACHEL，为何凶手写下半个名字便停手？可疑。重想。",
        "思考", "auto", "s3_q2")
    add(nodes, "s3_q2_b", "福尔摩斯", "社会党圈套？字迹仿德文印刷体，更像个人复仇。重想。",
        "思考", "auto", "s3_q2")
    add(nodes, "s3_q2_c", "福尔摩斯", "暂不厘清含义，正中凶手下怀。重想。",
        "思考", "auto", "s3_q2")

    # 阶段5 凶手特征
    add(nodes, "s3_profile_start", "福尔摩斯", "凶手是个男人，身高六英尺多，正当中年，脚小，穿方头靴，抽印度特里其雪茄，与被害者同坐一辆四轮马车，红脸，右手指甲长。",
        "从容", "auto", "s3_profile1")
    add(nodes, "s3_profile1", "福尔摩斯", "那么，这是一件什么样的案子？",
        "思考", "auto", "s3_q3")

    # Q3 案件性质
    add(nodes, "s3_q3", "system", "经过前期调查，你认为这是一件什么样的案件（可记录在线索墙）：",
        "guide", "choice", ["s3_q3_right", "s3_q3_b", "s3_q3_c", "s3_q3_d"])
    add(nodes, "s3_q3_right", "福尔摩斯", "谋杀。而且是有预谋的复仇——不是图财。",
        "自信", "auto", "s3_ring_start")
    add(nodes, "s3_q3_b", "福尔摩斯", "钱袋分文未少，何来抢劫？重想。",
        "思考", "auto", "s3_q3")
    add(nodes, "s3_q3_c", "福尔摩斯", "激情犯罪不会如此周密布置血字与马车。重想。",
        "思考", "auto", "s3_q3")
    add(nodes, "s3_q3_d", "福尔摩斯", "证据已指向谋杀。重想。",
        "思考", "auto", "s3_q3")

    # 阶段5 戒指
    add(nodes, "s3_ring_start", "福尔摩斯", "搬运尸体时掉落一只女人的结婚金戒指（朴素），内径刻有 L·F（露茜·费里尔）。",
        "中性", "auto", "s3_ring1", stage_dir="特写")
    add(nodes, "s3_ring1", "福尔摩斯", "这只戒指有什么作用？",
        "思考", "auto", "s3_q4")

    # Q4 戒指作用
    add(nodes, "s3_q4", "system", "这只戒指有什么作用（可记录在线索墙）：",
        "guide", "choice", ["s3_q4_right", "s3_q4_a", "s3_q4_b", "s3_q4_c"])
    add(nodes, "s3_q4_right", "福尔摩斯", "正确。这是凶手带在身边、准备送给其情人的戒指——也是他落下的破绽。",
        "自信", "auto", "s3_lans_start")
    add(nodes, "s3_q4_a", "福尔摩斯", "受害者在场却无此物？重想。",
        "思考", "auto", "s3_q4")
    add(nodes, "s3_q4_b", "福尔摩斯", "若受害人准备送情人，何必在自己尸体旁掉落？重想。",
        "思考", "auto", "s3_q4")
    add(nodes, "s3_q4_c", "福尔摩斯", "凶手身边之物，却掉到案发现场——为何？重想。",
        "思考", "auto", "s3_q4")

    # 阶段6 询问兰斯
    add(nodes, "s3_lans_start", "福尔摩斯", "现在我要和发现尸体的警察谈一谈。雷斯垂德：他叫约翰·兰斯，肯宁顿公园门路奥德利大院四十六号。",
        "中性", "auto", "s3_lans1")
    add(nodes, "s3_lans1", "福尔摩斯", "兰斯说门口有个烂醉的醉汉。这个醉汉，和本案是什么关系？",
        "思考", "auto", "s3_q5")

    # Q5 醉汉身份
    add(nodes, "s3_q5", "system", "玩家判断：这个醉汉与本案的关系（可记录在线索墙）：",
        "guide", "choice", ["s3_q5_right", "s3_q5_a", "s3_q5_b", "s3_q5_c"])
    add(nodes, "s3_q5_right", "福尔摩斯", "正是！那个醉汉就是凶手——兰斯完美地错过了一个升任警长的机会。",
        "自信", "auto", "s3_end")
    add(nodes, "s3_q5_a", "福尔摩斯", "无关？可他的描述与现场高度吻合。重想。",
        "思考", "auto", "s3_q5")
    add(nodes, "s3_q5_b", "福尔摩斯", "路人或许能提供线索，但更可能是当事人。重想。",
        "思考", "auto", "s3_q5")
    add(nodes, "s3_q5_c", "福尔摩斯", "同伙？可现场只有一人进出。重想。",
        "思考", "auto", "s3_q5")

    add(nodes, "s3_end", "system", "【场景三结束 —— 室内勘查完成】线索墙更新 · 强迫服毒 / RACHE=复仇 / 凶手红脸方头靴 / 女人戒指L·F / 醉汉即凶手",
        "milestone", "milestone", "end", note_text="线索墙更新：服毒/复仇/红脸方头靴/戒指L·F/醉汉即凶手")

    return nodes


def main_scene03(output_dir: str) -> None:
    nodes = build_scene03_nodes()
    meta = {
        "scene_id": "scene_03",
        "scene_name": "劳瑞斯顿花园街三号（室内）",
        "phase_id": "phase1",
        "phase_name": "室内尸体与物证勘查",
        "step": 0,
        "knowledge_domains": ["法医学：服毒征象", "德语与血字密码", "足迹与体态推断", "维多利亚时期物证"],
        "milestone": "室内勘查推理",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 0,
        "badge_check": "SCENE3_INDOOR_DONE",
        "completion_event": "",
    }
    # EASY 起手轻提示节点，NORMAL/HARD 直接进主线（体现「轻引导」三难度差异）
    meta["easy_start_node_override"] = "s3_easy_intro"
    meta["normal_start_node_override"] = "s3_start"
    meta["hard_start_node_override"] = "s3_start"
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_03_indoor.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景三节点数: {len(nodes)}")


# ======================================================================
# 场景四 ~ 场景八：自主探索（无引导）
# 复用同一套六步闭环 + 三难度分支 + 四级验证结构；引导强度统一为自主（无引导）。
# 差异主要体现在叙事内容与关键推理选择题，结构完全对齐场景二/三。
# ======================================================================

def _scene_autonomous_6steps(nodes: list, p: str, title: str,
                             step1_easy, step1_normal, step1_hard,
                             step2_easy, step2_normal, step2_hard,
                             step3_note, step3_easy, step3_normal, step3_hard,
                             step4_easy, step4_normal, step4_hard,
                             step5_easy, step5_normal, step5_hard,
                             hypo_choice, hypo_right, hypo_b, hypo_c, hypo_d,
                             conclude_text, milestone_note) -> None:
    """参数化生成「自主探索」场景的六步闭环骨架（场景 4-8 共用）。"""
    # Step 1 观察发现
    add(nodes, "%s_step1_start" % p, "system", "【六步闭环 Step 1】观察发现 —— %s" % title,
        "guide", "guide", ["%s_step1_easy" % p, "%s_step1_normal" % p, "%s_step1_hard" % p], step=1, is_entry=True)
    add(nodes, "%s_step1_easy" % p, "system", step1_easy, "guide", "auto", "%s_step2_start" % p, diff=1, step=1)
    add(nodes, "%s_step1_normal" % p, "system", step1_normal, "guide", "auto", "%s_step2_start" % p, diff=2, step=1)
    add(nodes, "%s_step1_hard" % p, "system", step1_hard, "neutral", "auto", "%s_step2_start" % p, diff=3, step=1)
    # Step 2 工具/追问
    add(nodes, "%s_step2_start" % p, "system", "【六步闭环 Step 2】工具操作 —— 锁定关键细节",
        "guide", "guide", ["%s_step2_easy" % p, "%s_step2_normal" % p, "%s_step2_hard" % p], step=2, is_entry=True)
    add(nodes, "%s_step2_easy" % p, "福尔摩斯", step2_easy, "指导", "auto", "%s_step3_start" % p, diff=1, step=2)
    add(nodes, "%s_step2_normal" % p, "system", step2_normal, "guide", "auto", "%s_step3_start" % p, diff=2, step=2)
    add(nodes, "%s_step2_hard" % p, "system", step2_hard, "neutral", "auto", "%s_step3_start" % p, diff=3, step=2)
    # Step 3 记录
    add(nodes, "%s_step3_start" % p, "system", "【六步闭环 Step 3】数据记录 —— 把发现记进侦探笔记",
        "guide", "note", ["%s_step3_easy" % p, "%s_step3_normal" % p, "%s_step3_hard" % p], step=3, is_entry=True, note_text=step3_note)
    add(nodes, "%s_step3_easy" % p, "福尔摩斯", step3_easy, "从容", "auto", "%s_step4_prompt" % p, diff=1, step=3)
    add(nodes, "%s_step3_normal" % p, "system", step3_normal, "guide", "auto", "%s_step4_prompt" % p, diff=2, step=3)
    add(nodes, "%s_step3_hard" % p, "system", step3_hard, "neutral", "auto", "%s_step4_prompt" % p, diff=3, step=3)
    # Step 4 知识
    add(nodes, "%s_step4_prompt" % p, "system", "（测量与记录完成）", "neutral", "auto",
        ["%s_step4_easy" % p, "%s_step4_normal" % p, "%s_step4_hard" % p], step=4, is_entry=True)
    add(nodes, "%s_step4_easy" % p, "福尔摩斯", step4_easy, "指导", "knowledge", "%s_step5_prompt" % p, diff=1, step=4)
    add(nodes, "%s_step4_normal" % p, "system", step4_normal, "guide", "optional", "%s_step5_prompt" % p, diff=2, step=4)
    add(nodes, "%s_step4_hard" % p, "system", step4_hard, "neutral", "auto", "%s_step5_prompt" % p, diff=3, step=4)
    # Step 5 假设
    add(nodes, "%s_step5_prompt" % p, "system", "【六步闭环 Step 5】假设形成 —— 把线索串成结论",
        "guide", "auto", ["%s_step5_easy" % p, "%s_step5_normal" % p, "%s_step5_hard" % p], step=5, is_entry=True)
    add(nodes, "%s_step5_easy" % p, "福尔摩斯", step5_easy, "指导", "auto", "%s_hypo_choice" % p, diff=1, step=5)
    add(nodes, "%s_step5_normal" % p, "system", step5_normal, "guide", "auto", "%s_hypo_choice" % p, diff=2, step=5)
    add(nodes, "%s_step5_hard" % p, "system", step5_hard, "neutral", "auto", "%s_hypo_choice" % p, diff=3, step=5)
    add(nodes, "%s_hypo_choice" % p, "system", hypo_choice, "guide", "choice",
        ["%s_hypo_right" % p, "%s_hypo_b" % p, "%s_hypo_c" % p, "%s_hypo_d" % p], step=5)
    add(nodes, "%s_hypo_right" % p, "福尔摩斯", hypo_right, "自信", "auto", "%s_step6_prompt" % p, step=5)
    add(nodes, "%s_hypo_b" % p, "福尔摩斯", hypo_b, "思考", "auto", "%s_hypo_choice" % p, step=5)
    add(nodes, "%s_hypo_c" % p, "福尔摩斯", hypo_c, "思考", "auto", "%s_hypo_choice" % p, step=5)
    add(nodes, "%s_hypo_d" % p, "福尔摩斯", hypo_d, "思考", "auto", "%s_hypo_choice" % p, step=5)
    # Step 6 验证（四级）
    add(nodes, "%s_step6_prompt" % p, "system", "【六步闭环 Step 6】验证修正 —— 去推理墙验证你的结论",
        "guide", "auto", ["%s_step6_normal" % p, "%s_step6_hard" % p], step=6)
    add(nodes, "%s_step6_normal" % p, "system", "线索收集完毕，去推理墙验证你的假设。",
        "guide", "neutral", ["%s_step6_verified" % p, "%s_step6_supported" % p, "%s_step6_insufficient" % p, "%s_step6_contradictory" % p],
        diff=2, step=6, is_entry=True)
    add(nodes, "%s_step6_hard" % p, "system", "（无验证提示，玩家自行判断何时证据充分）",
        "neutral", "auto", ["%s_step6_verified" % p, "%s_step6_supported" % p, "%s_step6_insufficient" % p, "%s_step6_contradictory" % p],
        diff=3, step=6, is_entry=True)
    add(nodes, "%s_step6_verified" % p, "福尔摩斯", conclude_text, "自信", "milestone", "%s_conclude" % p, step=6, verify="VERIFIED", note_text=milestone_note)
    add(nodes, "%s_step6_supported" % p, "福尔摩斯", "方向对了，但证据链还不够完整。回去再看看关键线索。", "思考", "auto", "%s_step1_start" % p, step=6, verify="SUPPORTED")
    add(nodes, "%s_step6_insufficient" % p, "福尔摩斯", "证据不足，需要更多观察。重新梳理。", "严肃", "auto", "%s_step1_start" % p, step=6, verify="INSUFFICIENT")
    add(nodes, "%s_step6_contradictory" % p, "福尔摩斯", "你的结论和证据自相矛盾。重想。", "严肃", "auto", "%s_step1_start" % p, step=6, verify="CONTRADICTORY")


# ---------- 场景四：劳瑞斯顿花园街（巡警兰斯问询）----------

def build_scene04_nodes() -> list:
    nodes: list = []
    add(nodes, "s4_start", "兰斯警士", "我已经在局里全都报告过了！……（福尔摩斯把玩半镑金币）那我就从头再讲一遍。",
        "不高兴", "auto", "s4_step1_start")
    _scene_autonomous_6steps(nodes, "s4", "巡警兰斯叙述案发经过",
        "夜里两点巡逻到布瑞克斯顿路，看见空屋窗口有灯光，推门进去发现尸体，吹警笛叫来摩契和另外两个警察。",
        "（同 EASY）夜里两点巡逻发现空屋灯光与尸体，叫来同伴。",
        "（无提示——自行从兰斯叙述中提取有效信息）",
        "逐一追问：他高个子、红脸、棕色外衣、没有马鞭。注意——兰斯说醉汉没有马鞭，但现场勘查凶手应该有马鞭。那个人就是凶手！",
        "可选追问方向（70%概率提示）：外貌/衣着/是否持物/有无马车。选对关键问题→获得完整醉汉特征。",
        "（玩家自行选择追问；无关问题兰斯不再重复）",
        "笔记：醉汉=高个/红脸/棕衣/无马鞭；与凶手特征吻合",
        "笔记已自动填入：高个子、红脸、棕色外衣、无马鞭——与现场推断的凶手特征高度吻合。",
        "在侦探笔记记录：醉汉特征，对比凶手特征（身高6英尺+/红脸/方头靴/可能马鞭）。",
        "（空白笔记，自由记录）",
        "知识库「犯罪心理」：凶手返回现场的行为模式——遗失重要物品→返回寻找。想想我们在现场发现的戒指。",
        "知识库可选查阅（非强制）。",
        "（无提示）",
        "高个子、红脸、棕色外衣——和你在现场推断的凶手特征完全吻合。他是谁？",
        "拖拽线索到假设板，自行判断醉汉与案件关系。",
        "（推理墙开启，无引导）",
        "关于那个醉汉，你的判断是：",
        "聪明！那个醉汉就是凶手——兰斯，你完美地错过了一个升任警长的机会！",
        "一个过路人？那他的特征为何与凶手完全吻合？重想。",
        "同伙？现场足迹只有两人，无第二人。重想。",
        "线索不会说谎——特征吻合即同一人。重想。",
        "那个醉汉就是凶手！特征完全吻合——高个、红脸、棕衣、无马鞭。",
        "【里程碑】醉汉=凶手 解锁 ⭐")
    # 阶段2：醉汉返回原因 + 失物招领分支
    add(nodes, "s4_conclude", "福尔摩斯", "他为何去而复返？戒指——他回来是为了取回掉落的戒指。", "从容", "auto", "s4_return_choice")
    add(nodes, "s4_return_choice", "system", "醉汉（凶手）返回现场的原因是：", "guide", "choice", ["s4_return_right", "s4_return_b", "s4_return_c", "s4_return_d"])
    add(nodes, "s4_return_right", "福尔摩斯", "正确——回来寻找失落的戒指。他一定会在晚报招领栏寻找，几小时内你就能见到他。", "自信", "auto", "s4_branch_choice")
    add(nodes, "s4_return_b", "福尔摩斯", "回来看警方进度？那何必装醉逃走？重想。", "思考", "auto", "s4_return_choice")
    add(nodes, "s4_return_c", "福尔摩斯", "挑衅警方？他当时吓得要命，没那胆量。重想。", "思考", "auto", "s4_return_choice")
    add(nodes, "s4_return_d", "福尔摩斯", "自负？他慌不择路才装醉，谈不上自负。重想。", "思考", "auto", "s4_return_choice")
    add(nodes, "s4_branch_choice", "system", "是否在晚报刊登失物招领启事？", "guide", "choice", ["s4_branch_publish", "s4_branch_skip"])
    add(nodes, "s4_branch_publish", "福尔摩斯", "刊登启事——当晚在贝克街等待「失主」，识破伪装的老太婆，发动贝克街分队。", "从容", "auto", "s4_end")
    add(nodes, "s4_branch_skip", "福尔摩斯", "不发布——直接去马车站调查新换的马蹄铁，车主登记名「杰弗森·霍普」。", "从容", "auto", "s4_end")
    add(nodes, "s4_end", "system", "【场景四结束】醉汉=凶手确认 · 戒指线索与贝克街分队已铺开", "milestone", "milestone", "end", note_text="线索墙更新：醉汉=凶手/戒指")
    return nodes


def main_scene04(output_dir: str) -> None:
    nodes = build_scene04_nodes()
    meta = {
        "scene_id": "scene_04",
        "scene_name": "劳瑞斯顿花园街（巡警兰斯问询）",
        "phase_id": "phase1",
        "phase_name": "醉汉特征与凶手身份推理",
        "step": 0,
        "knowledge_domains": ["犯罪心理：凶手返回现场", "足迹与体态推断"],
        "milestone": "醉汉即凶手",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 1,
        "badge_check": "SCENE4_POLICE_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_04_police.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景四节点数: {len(nodes)}")


# ---------- 场景五：会客厅（等待/伪装/识别）----------

def build_scene05_nodes() -> list:
    nodes: list = []
    add(nodes, "s5_start", "赫德森太太", "先生们，茶凉了。今晚我们可能有客人——一位要来领取戒指的老太太。", "中性", "auto", "s5_step1_start")
    _scene_autonomous_6steps(nodes, "s5", "老太婆进门，注意步态/声音/手部",
        "满脸皱纹、走路蹒跚、老眼昏花；痉挛颤抖的手指在衣袋里摸索。注意她的步态与手部。",
        "（同 EASY）老太婆进门；赫德森太太（轻声，70%概率）提示声音有些怪。",
        "（无提示，仅靠玩家自己观察）",
        "她答得太快、信息过多；住址前后矛盾（宏兹迪池区 vs 培克罕）。真正的失主不会这样。",
        "对照住址矛盾点，自行判断来人是否可信。",
        "（玩家自行追问，无关问题不再重复）",
        "笔记：来人自称索叶太太，住址矛盾、信息过量、步态不自然、声音低沉",
        "笔记已自动填入：步态不自然、声音低沉、回答过于流利——明显是伪装。",
        "在侦探笔记记录：来人特征与矛盾点。",
        "（空白笔记，自由记录）",
        "知识库「伪装术基础」：步态难伪装、手部皮肤暴露年龄、声音难长期伪装。",
        "知识库可选查阅（非强制）。",
        "（无提示）",
        "她的步态不自然、声音低沉、信息过多——这不是真的老太太。",
        "拖拽线索到假设板，自行判断来人身份。",
        "（推理墙开启，无引导）",
        "对于前来领取戒指的「老太婆」，你的判断是：",
        "正确！她与凶手是同伙，必须跟踪——这是一个精于伪装的人。",
        "她只是占便宜的糊涂老太婆？福尔摩斯险些被她骗过，绝非无关。重想。",
        "她真是老太太的亲戚？住址矛盾已露破绽。重想。",
        "线索不会说谎——步态与声音出卖了她。重想。",
        "来人就是伪装的同伙——跟踪她，必有所获。",
        "【里程碑】识破伪装 解锁 ⭐")
    # 阶段2：跟踪脱逃 + 贝克街分队
    add(nodes, "s5_conclude", "华生", "那个身体虚弱的老太婆，竟能瞒过我们跳车逃脱？！",
        "震惊", "auto", "s5_track_choice")
    add(nodes, "s5_track_choice", "system", "福尔摩斯总结：跟踪失败，但凶手精通伪装、具有反侦察意识。下一步：", "guide", "choice", ["s5_track_right", "s5_track_b", "s5_track_c", "s5_track_d"])
    add(nodes, "s5_track_right", "福尔摩斯", "发动贝克街分队，找一个身高六英尺、红脸、棕色大衣、操美国口音的马车夫——杰弗森·霍普。", "自信", "auto", "s5_end")
    add(nodes, "s5_track_b", "福尔摩斯", "单打独斗？伦敦这么大，你找得到谁？重想。", "思考", "auto", "s5_track_choice")
    add(nodes, "s5_track_c", "福尔摩斯", "放弃？线索就此断了。重想。", "思考", "auto", "s5_track_choice")
    add(nodes, "s5_track_d", "福尔摩斯", "上报苏格兰场？他们刚被我们嘲笑，先靠自己。重想。", "思考", "auto", "s5_track_choice")
    add(nodes, "s5_end", "system", "【场景五结束】伪装识破 · 贝克街分队出动追查杰弗森·霍普", "milestone", "milestone", "end", note_text="线索墙更新：伪装同伙/杰弗森·霍普")
    return nodes


def main_scene05(output_dir: str) -> None:
    nodes = build_scene05_nodes()
    meta = {
        "scene_id": "scene_05",
        "scene_name": "会客厅（等待/伪装/识别）",
        "phase_id": "phase1",
        "phase_name": "伪装识破与跟踪",
        "step": 0,
        "knowledge_domains": ["伪装术基础", "反侦察行为模式"],
        "milestone": "识破伪装",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 1,
        "badge_check": "SCENE5_PARLOR_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_05_parlor.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景五节点数: {len(nodes)}")


# ---------- 场景六：卡彭蒂耶公寓（排除嫌疑）----------

def build_scene06_nodes() -> list:
    nodes: list = []
    add(nodes, "s6_start", "葛莱森警长", "福尔摩斯先生！我从死者那顶帽子查到帽店，顺藤摸瓜找到了陶尔魁里卡彭蒂耶公寓的德雷伯！", "得意", "auto", "s6_step1_start")
    _scene_autonomous_6steps(nodes, "s6", "卡彭蒂耶太太与爱莉丝的证词",
        "卡彭蒂耶太太脸色苍白；爱莉丝红着眼。德雷伯八点离开，赶九点一刻去利物浦的火车。",
        "（同 EASY）卡彭蒂耶太太叙述德雷伯入住三周、调戏爱莉丝、被儿子阿瑟赶走。",
        "（无提示，自行从证词中抓取不在场与体型信息）",
        "注意墙上照片：卡彭蒂耶中尉清秀、消瘦——与现场方头靴印的强壮大个子完全不符；身高约5.8英尺，低于现场推断的6英尺。",
        "对比照片中人物特征与现场推断的凶手特征，自行判断。",
        "（玩家自行观察照片，无关提问不再重复）",
        "笔记：卡彭蒂耶中尉=消瘦/5.8英尺/海军；与凶手(强壮/6英尺+/方头靴)不符",
        "笔记已自动填入：体型、身高、不在场证明——与凶手特征不符。",
        "在侦探笔记记录：体型/身高/不在场证明。",
        "（空白笔记，自由记录）",
        "知识库「犯罪动机与不在场证明」：动机≠罪行，如何排除有动机的嫌疑人。",
        "知识库可选查阅（非强制）。",
        "（无提示）",
        "有动机不等于有罪。照片里的清瘦中尉，和现场强壮的凶手根本不是一个人。",
        "拖拽线索到假设板，自行判断卡彭蒂耶中尉是否为凶手。",
        "（推理墙开启，无引导）",
        "对于葛莱森「卡彭蒂耶中尉是凶手」的推测，你的判断是：",
        "正确！体型、身高、不在场证明都不符——卡彭蒂耶中尉并非凶手。",
        "认同葛莱森？照片里的清瘦身材骗不了人。重想。",
        "也许是双胞胎？毫无证据。重想。",
        "线索不会说谎——体型差异决定性。重想。",
        "卡彭蒂耶中尉嫌疑排除——凶手是更强壮的高个男人。",
        "【里程碑】排除冤案 解锁 ⭐")
    # 阶段2：哈珀证词排除
    add(nodes, "s6_conclude", "福尔摩斯", "卡彭蒂耶的不在场证明需要核实——去找他的老战友威廉·哈珀。", "从容", "auto", "s6_alibi_choice")
    add(nodes, "s6_alibi_choice", "system", "是否追查威廉·哈珀的不在场证词？", "guide", "choice", ["s6_alibi_right", "s6_alibi_b", "s6_alibi_c", "s6_alibi_d"])
    add(nodes, "s6_alibi_right", "哈珀", "当晚我和卡彭蒂耶聊了很久，一直到下雨才各自回家——他绝不可能在那个时间作案。", "诚恳", "auto", "s6_end")
    add(nodes, "s6_alibi_b", "福尔摩斯", "直接逮捕？证据还差一环。重想。", "思考", "auto", "s6_alibi_choice")
    add(nodes, "s6_alibi_c", "福尔摩斯", "转向斯特兰森？先排除眼前这个更稳妥。重想。", "思考", "auto", "s6_alibi_choice")
    add(nodes, "s6_alibi_d", "福尔摩斯", "放任不管？他会成为永远的疑点。重想。", "思考", "auto", "s6_alibi_choice")
    add(nodes, "s6_end", "system", "【场景六结束】卡彭蒂耶中尉嫌疑排除 · 调查转向斯特兰森", "milestone", "milestone", "end", note_text="线索墙更新：排除卡彭蒂耶/追查斯特兰森")
    return nodes


def main_scene06(output_dir: str) -> None:
    nodes = build_scene06_nodes()
    meta = {
        "scene_id": "scene_06",
        "scene_name": "卡彭蒂耶公寓（排除嫌疑）",
        "phase_id": "phase1",
        "phase_name": "嫌疑辨析与佐证排查",
        "step": 0,
        "knowledge_domains": ["犯罪动机与不在场证明", "体态与足迹推断"],
        "milestone": "排除冤案",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 1,
        "badge_check": "SCENE6_APARTMENT_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_06_apartment.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景六节点数: {len(nodes)}")


# ---------- 场景七：第二被害人（药丸实验）----------

def build_scene07_nodes() -> list:
    nodes: list = []
    add(nodes, "s7_start", "福尔摩斯", "斯特兰森没跑掉——房门反锁，强行进入后发现他又是一具尸体，墙上同样写着 RACHE。", "严肃", "auto", "s7_step1_start")
    _scene_autonomous_6steps(nodes, "s7", "第二具尸体、血迹、药丸盒",
        "死者被刀刺死（非毒杀），墙上 RACHE。血迹由门缝流出；目击送牛奶的孩子：大个子、红脸、棕色外衣。",
        "（同 EASY）斯特兰森被刺死、墙上 RACHE；送牛奶孩子目击大个子红脸棕衣的凶手。",
        "（无提示，自行比对两次作案的凶手特征）",
        "脸盆有水（凶手从容洗手）、钱袋八十多镑分文未少（非谋财）、电报「J.H.现欧洲」（杰弗森·霍普）、药丸珍珠灰透明。",
        "比对两案凶器与动机，自行推断。",
        "（玩家自行勘验，无关提问不再重复）",
        "笔记：斯特兰森被刺/非谋财/电报J.H./药丸透明",
        "笔记已自动填入：两案凶手特征一致，但手法不同（毒杀 vs 刺死）。",
        "在侦探笔记记录：凶器差异与共同特征。",
        "（空白笔记，自由记录）",
        "知识库「南美箭毒生物碱」「连环杀手行为模式」：同一凶手对不同受害者用不同手法。",
        "知识库可选查阅（非强制）。",
        "（无提示）",
        "德雷伯死于中毒，斯特兰森被刺死——同一凶手，为何手法不同？",
        "拖拽线索到假设板，自行形成假设。",
        "（推理墙开启，无引导）",
        "对于两起命案，你的假设是：",
        "正确！同一凶手、不同手法——斯特兰森拒绝选药丸，所以被直接刺死。",
        "两个不同凶手？特征完全吻合，绝非巧合。重想。",
        "斯特兰森自杀？被刺死且现场血字 RACHE 说明是他杀。重想。",
        "线索不会说谎——同一红脸棕衣大个子。重想。",
        "同一凶手、不同手法——药丸即毒杀德雷伯的凶器。",
        "【里程碑】毒理学家 解锁 ⭐")
    # 阶段2：药丸实验验证
    add(nodes, "s7_conclude", "福尔摩斯", "木匣里两粒药丸，一粒烈性毒药、一粒无毒——上帝裁决。", "坚定", "auto", "s7_pill_choice")
    add(nodes, "s7_pill_choice", "system", "药丸实验：为何第一粒放入试剂毫无反应？", "guide", "choice", ["s7_pill_right", "s7_pill_b", "s7_pill_c", "s7_pill_d"])
    add(nodes, "s7_pill_right", "福尔摩斯", "正是！两粒药丸一粒有毒一粒无毒——德雷伯选中了毒药，斯特兰森不愿选才被刺死。", "自信", "auto", "s7_end")
    add(nodes, "s7_pill_b", "福尔摩斯", "药丸过期？它刚从死者身边发现。重想。", "思考", "auto", "s7_pill_choice")
    add(nodes, "s7_pill_c", "福尔摩斯", "试剂有问题？同一试管对第二粒剧烈反应。重想。", "思考", "auto", "s7_pill_choice")
    add(nodes, "s7_pill_d", "福尔摩斯", "更大剂量？半粒已致人死，无需更多。重想。", "思考", "auto", "s7_pill_choice")
    add(nodes, "s7_end", "system", "【场景七结束】凶器确认（南美箭毒药丸+匕首） · 同一凶手坐实", "milestone", "milestone", "end", note_text="线索墙更新：药丸毒杀/同一凶手")
    return nodes


def main_scene07(output_dir: str) -> None:
    nodes = build_scene07_nodes()
    meta = {
        "scene_id": "scene_07",
        "scene_name": "郝黎代旅馆（第二被害人）",
        "phase_id": "phase1",
        "phase_name": "药丸实验与同一凶手确认",
        "step": 0,
        "knowledge_domains": ["南美箭毒生物碱", "连环杀手行为模式", "毒理学基础"],
        "milestone": "毒理学家",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 1,
        "badge_check": "SCENE7_HOTEL_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_07_hotel.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景七节点数: {len(nodes)}")


# ---------- 场景八：起居室（最终对决/真相揭示）----------

def build_scene08_nodes() -> list:
    nodes: list = []
    add(nodes, "s8_start", "维金斯", "先生，马车已经喊到了，就在下边！贝克街分队报告：杰弗森·霍普已定位。", "兴奋", "auto", "s8_step1_start")
    _scene_autonomous_6steps(nodes, "s8", "贝克街分队报告霍普位置",
        "福尔摩斯设计诱捕：假装需要车夫帮忙搬箱子，把霍普骗上楼，用手铐将其擒获。",
        "（同 EASY）福尔摩斯佯装搬箱，诱使马车夫上前帮忙，趁其不备铐住。",
        "（无提示，自行体会诱捕策略的精妙）",
        "钢手铐咔嚓一响，马车夫正是杰弗森·霍普——杀死德雷伯与斯特兰森的凶手落网。",
        "复盘擒获过程，自行总结策略关键点。",
        "（玩家自行复盘，无关提问不再重复）",
        "笔记：诱捕成功/凶手=杰弗森·霍普/主动脉瘤症",
        "笔记已自动填入：以智取胜，凶手身份确认。",
        "在侦探笔记记录：抓捕策略与凶手身份。",
        "（空白笔记，自由记录）",
        "知识库「审讯心理学」「连环复仇动机」：二十年追踪的执念。",
        "知识库可选查阅（非强制）。",
        "（无提示）",
        "从马蹄铁到戒指，从伪装到第二被害人——所有线索都指向同一个人。",
        "拖拽线索到假设板，确认最终结论。",
        "（推理墙开启，无引导）",
        "对于本案真凶，你的最终结论是：",
        "正确！凶手就是杰弗森·霍普——为露茜·费里尔复仇二十年。",
        "另有其人？所有物证都指向霍普。重想。",
        "或许是误判？血字 RACHE、药丸、戒指环环相扣。重想。",
        "线索不会说谎——霍普即凶手。重想。",
        "凶手身份确认：杰弗森·霍普——本案真相大白。",
        "【里程碑】连环追踪 解锁 ⭐")
    # 阶段2：完整自白 + 点评 + 结局分支
    add(nodes, "s8_conclude", "杰弗森·霍普", "我得了主动脉瘤症，活不长了……但我在死前，要把这件事交代明白。", "平静", "auto", "s8_confess_choice")
    add(nodes, "s8_confess_choice", "system", "福尔摩斯点评：法律不是唯一的正义。本案结局取决于你的整体表现——", "guide", "choice", ["s8_end_legend", "s8_end_great", "s8_end_pass", "s8_end_trainee"])
    add(nodes, "s8_end_legend", "福尔摩斯", "【传奇结局】你的推理令人印象深刻——观察⭐⭐⭐ 推理⭐⭐⭐ 洞察⭐⭐⭐，总星9/9 PERFECT！推理大师实至名归。", "赞赏", "milestone", "end", note_text="徽章：KEEN_EYE/MASTER_DEDUCER/DEPTH_SEEKER/PERFECT_SCORE")
    add(nodes, "s8_end_great", "福尔摩斯", "【杰出结局】你的推理很强，案件告破——总星6~7/9。继续磨练，推理大师离你不远。", "满意", "milestone", "end", note_text="徽章：FIRST_CASE_CLEAR")
    add(nodes, "s8_end_pass", "福尔摩斯", "【合格结局】推理很强，但观察与逻辑还需提升——总星5/9。继续努力！", "鼓励", "milestone", "end", note_text="徽章：FIRST_CASE_CLEAR")
    add(nodes, "s8_end_trainee", "福尔摩斯", "【见习结局】离真相还差一点，但思路值得推荐——总星≤4/9。回到线索墙重新梳理吧。", "温和", "milestone", "end", note_text="徽章：FIRST_CASE_CLEAR")
    return nodes


def main_scene08(output_dir: str) -> None:
    nodes = build_scene08_nodes()
    meta = {
        "scene_id": "scene_08",
        "scene_name": "起居室（最终对决）",
        "phase_id": "phase1",
        "phase_name": "诱捕凶手与真相揭示",
        "step": 0,
        "knowledge_domains": ["审讯心理学", "连环复仇动机", "毒理学基础"],
        "milestone": "连环追踪",
        "score_observation": 1,
        "score_reasoning": 1,
        "score_insight": 1,
        "badge_check": "SCENE8_FINALE_DONE",
        "completion_event": "",
    }
    os.makedirs(output_dir, exist_ok=True)
    out = os.path.join(output_dir, "scene_08_finale.tres")
    generate_tres_file(nodes, meta, out)
    print(f"  场景八节点数: {len(nodes)}")


# ============ 调度入口 ============

def main_run() -> None:
    output_dir = "/workspace/维多利亚伦敦探案项目/godot_project/resources/dialogues/"
    scene = sys.argv[1].lower() if len(sys.argv) > 1 else "scene1"

    print("🔧 对话 → .tres 转换工具 v1.0 (P2: 场景 4-8)")
    print(f"   输出目录: {output_dir}")

    if scene in ("scene1", "s1", "all"):
        main()  # 场景一（保持原有行为）
    if scene in ("scene2", "s2", "all"):
        main_scene02(output_dir)
    if scene in ("scene3", "s3", "all"):
        main_scene03(output_dir)
    if scene in ("scene4", "s4", "all"):
        main_scene04(output_dir)
    if scene in ("scene5", "s5", "all"):
        main_scene05(output_dir)
    if scene in ("scene6", "s6", "all"):
        main_scene06(output_dir)
    if scene in ("scene7", "s7", "all"):
        main_scene07(output_dir)
    if scene in ("scene8", "s8", "all"):
        main_scene08(output_dir)

    print("\n✅ 转换完成！")


if __name__ == "__main__":
    main_run()
