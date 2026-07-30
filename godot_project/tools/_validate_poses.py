import json, math

# 父关系 + 子骨相对父骨的局部偏移（取自 sherlock_rig.gd）
PARENT = {
    "head": "", "neck": "head", "torso": "neck", "hip": "torso",
    "shoulder_L": "torso", "upperarm_L": "shoulder_L", "forearm_L": "upperarm_L",
    "shoulder_R": "torso", "upperarm_R": "shoulder_R", "forearm_R": "upperarm_R",
    "thigh_L": "hip", "shin_L": "thigh_L", "thigh_R": "hip", "shin_R": "thigh_R",
    "hat": "head",
}
# 局部偏移（子骨 origin 相对父骨 origin），用于校验连通性
LOCAL = {
    "head": (0,0), "neck": (0,80), "torso": (0,18), "hip": (0,110),
    "shoulder_L": (-22,10), "upperarm_L": (0,0), "forearm_L": (0,60),
    "shoulder_R": (22,10), "upperarm_R": (0,0), "forearm_R": (0,60),
    "thigh_L": (-16,6), "shin_L": (0,80), "thigh_R": (16,6), "shin_R": (0,80),
    "hat": (0,0),
}

with open("skeleton_frames/poses.json") as f:
    raw = f.read()
assert raw.startswith("POSEJSON "), "missing POSEJSON prefix"
frames = json.loads(raw[len("POSEJSON "):])

problems = []
print(f"frames={len(frames)}")
for fr in frames:
    anim = fr["anim"]; t = fr.get("t")
    bones = {b["name"]: b for b in fr["bones"]}
    if len(bones) != 15:
        problems.append(f"{anim}@{t}: bone count {len(bones)} != 15")
    for nm, b in bones.items():
        x, y, r = b["x"], b["y"], b["rot"]
        if not (math.isfinite(x) and math.isfinite(y) and math.isfinite(r)):
            problems.append(f"{anim}@{t}: {nm} non-finite x/y/rot")
        p = PARENT[nm]
        if p == "":
            continue
        if p not in bones:
            problems.append(f"{anim}@{t}: {nm} parent {p} missing")
            continue
        dx = x - bones[p]["x"]; dy = y - bones[p]["y"]
        dist = math.hypot(dx, dy)
        expect = math.hypot(*LOCAL[nm])
        # 局部偏移经父骨世界旋转后长度不变，故 dist 应≈|local|
        if abs(dist - expect) > 2.0:
            problems.append(f"{anim}@{t}: {nm} dist-to-parent={dist:.1f} != |local|={expect:.1f}")

# 取 idle@0 检查整体朝向：head 应在 hip 上方（y 更小）
idle0 = next(fr for fr in frames if fr["anim"] == "idle" and fr.get("t") == 0.0)
bb = {b["name"]: b for b in idle0["bones"]}
xs = [b["x"] for b in idle0["bones"]]; ys = [b["y"] for b in idle0["bones"]]
minx, maxx = min(xs), max(xs); miny, maxy = min(ys), max(ys)
print(f"idle@0 bbox: x[{minx:.0f},{maxx:.0f}] y[{miny:.0f},{maxy:.0f}]  w={maxx-minx:.0f} h={maxy-miny:.0f}")
if not (bb["head"]["y"] < bb["torso"]["y"] < bb["hip"]["y"]):
    problems.append("idle@0: head/torso/hip y-order not upright (head should be above hip)")
if (maxy - miny) < 200 or (maxy - miny) > 800:
    problems.append(f"idle@0: implausible height {maxy-miny:.0f}")

if problems:
    print("VALIDATION: FAIL")
    for p in problems[:30]:
        print("  -", p)
else:
    print("VALIDATION: PASS (all 16 frames coherent, bones connected, upright)")
