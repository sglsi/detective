import re, io

P = r"C:/Users/sglsi/WorkBuddy/Claw/detective/godot_project/scripts/scene/scene1.gd"
with open(P, "r", encoding="utf-8") as f:
    lines = f.read().split("\n")

T = "\t"

def replace_func(lines, name, new_text):
    """Replace the whole top-level `func name(...)` (body through first col-0 line) with new_text."""
    out = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        if re.match(r'^func ' + re.escape(name) + r'\(', line):
            j = i + 1
            while j < n and (lines[j].startswith(T) or lines[j].strip() == ''):
                j += 1
            # skip lines[i..j-1]; insert replacement
            if new_text.strip() != '':
                out.extend(new_text.split('\n'))
                out.append('')
            i = j
            continue
        out.append(line)
        i += 1
    return out

# 1) _do_think: 推理阶段可重新打开墙（修关墙软锁）
new_do_think = (
    "func _do_think() -> void:" + "\n" +
    T + "if _phase == Phase.OBSERVE_WATSON and _watson_obs.get_recorded() > 0:" + "\n" +
    T + T + "_show_watson_reasoning_wall()" + "\n" +
    T + "elif _phase == Phase.MESSENGER_OBSERVE and _messenger_obs.get_recorded() > 0:" + "\n" +
    T + T + "_show_messenger_reasoning_wall()" + "\n" +
    T + "elif _phase == Phase.WATSON_REASONING:" + "\n" +
    T + T + "_show_watson_reasoning_wall()   # 已关墙后可重新打开" + "\n" +
    T + "elif _phase == Phase.MESSENGER_REASONING:" + "\n" +
    T + T + "_show_messenger_reasoning_wall()" + "\n" +
    T + "else:" + "\n" +
    T + T + '_create_notification("请先收集至少 1 条线索再使用推理墙")'
)
lines = replace_func(lines, "_do_think", new_do_think)

# 2) 两个推理墙展示函数：改为调用基类统一 _open_wall（唯一机制）
new_watson = (
    "func _show_watson_reasoning_wall() -> void:" + "\n" +
    T + "_watson_obs.hide(); _phase = Phase.WATSON_REASONING" + "\n" +
    T + 'var hypo := {"title": "华生刚从阿富汗回来？", "description": "从华生身上的痕迹（手腕肤色分界、左臂旧伤、面色憔悴、军人站姿）推断其身份与经历。"}' + "\n" +
    T + '_open_wall("watson", hypo, func(v: int):' + "\n" +
    T + T + "_watson_v = v" + "\n" +
    T + T + "_start_messenger_phase()" + "\n" +
    T + ")"
)
new_messenger = (
    "func _show_messenger_reasoning_wall() -> void:" + "\n" +
    T + "_messenger_obs.hide(); _phase = Phase.MESSENGER_REASONING" + "\n" +
    T + 'var hypo := {"title": "信使是海军陆战队军士？", "description": "从信使身上（锚形文身、络腮胡、挺拔站姿、发号施令神态、袖口磨损）推断其军旅身份；注意分辨干扰项（袖口磨损、轻微跛行）。"}' + "\n" +
    T + '_open_wall("messenger", hypo, func(v: int):' + "\n" +
    T + T + "_messenger_v = v" + "\n" +
    T + T + "_calc_stars(); _show_rating()" + "\n" +
    T + ")"
)
lines = replace_func(lines, "_show_watson_reasoning_wall", new_watson)
lines = replace_func(lines, "_show_messenger_reasoning_wall", new_messenger)

# 3) 删除场景一手搓墙相关死函数（改由基类 reasoning_wall.gd 统一承载）
for fn in ["_mk_wall", "_on_watson_card_pressed", "_on_watson_verify",
           "_on_watson_skip", "_on_messenger_verify", "_on_messenger_skip",
           "_show_verdict", "_open_evidence"]:
    lines = replace_func(lines, fn, "")

# 4) 新增 _clue_sources 覆盖（证据库同时列出华生/信使两组线索）
text = "\n".join(lines)
anchor = "func _open_notebook() -> void:"
inject = ("func _clue_sources() -> Array:" + "\n" +
          T + 'return ["watson", "messenger"]' + "\n\n" + anchor)
if anchor in text and "_clue_sources" not in text:
    text = text.replace(anchor, inject, 1)
else:
    print("WARN: _open_notebook anchor missing or _clue_sources already present")

with open(P, "w", encoding="utf-8") as f:
    f.write(text)

print("scene1.gd refactored. lines:", len(text.split('\n')))
