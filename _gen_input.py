import io

path = "C:/Users/sglsi/WorkBuddy/Claw/detective/godot_project/project.godot"
with open(path, encoding="utf-8") as f:
    content = f.read()

KEY = ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"",'
       '"device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,'
       '"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
       '"keycode":%d,"physical_keycode":0,"key_label":0,"unicode":0,'
       '"location":0,"echo":false,"script":null)')
MOUSE = ('Object(InputEventMouseButton,"resource_local_to_scene":false,'
         '"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
         '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,'
         '"button_mask":0,"position":Vector2(0, 0),'
         '"global_position":Vector2(0, 0),"pressed":false,"button_index":1,'
         '"canceled":false,"double_click":false,"script":null)')


def block(name, codes):
    parts = []
    for c in codes:
        parts.append(KEY % c if isinstance(c, int) else c)
    return "[input/%s]\ndeadzone = 0.5\nevents = [%s]\n" % (name, ", ".join(parts))


actions = [
    ("ui_accept", [4194309, 32]),
    ("ui_cancel", [4194305]),
    ("ui_up", [4194320, 87]),
    ("ui_down", [4194322, 83]),
    ("ui_left", [4194319, 65]),
    ("ui_right", [4194321, 68]),
    ("interact", [69, MOUSE]),
    ("open_map", [77]),
    ("open_notebook", [78]),
    ("open_inventory", [73]),
    ("open_reasoning", [82]),
    ("toggle_ui", [72]),
    ("quick_save", [4194336]),
    ("quick_load", [4194340]),
]

section = "[input]\n\n" + "\n".join(block(n, c) for n, c in actions) + "\n"

marker = "[input_devices]"
if marker not in content:
    raise SystemExit("marker [input_devices] not found")

content = content.replace(marker, section + marker, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("input section written, actions:", len(actions))
