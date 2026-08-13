import re, sys, json

path = "web_build/index.html"
ts = sys.argv[1] if len(sys.argv) > 1 else "TS"
with open(path, "r", encoding="utf-8") as f:
    s = f.read()

# Documented injection (MEMORY.md 2026-08-11): insert mainPack right after
# "executable":"index" — DO NOT swallow the comma that follows executable.
new = re.sub(r'("executable":"index")', r'\1,"mainPack":"index.pck?v=' + ts + '"', s, count=1)
if new == s:
    print("ERROR: pattern \"executable\":\"index\" not found, injection skipped")
    sys.exit(1)
with open(path, "w", encoding="utf-8") as f:
    f.write(new)
print("INJECTED mainPack=index.pck?v=" + ts)

# Validate the GODOT_CONFIG object literal is still valid JSON (no comma swallowed).
m = re.search(r'const GODOT_CONFIG = (\{.*\});', new)
if not m:
    print("ERROR: GODOT_CONFIG line not found")
    sys.exit(2)
try:
    cfg = json.loads(m.group(1))
    assert cfg.get("mainPack") == "index.pck?v=" + ts, "mainPack mismatch"
    assert cfg.get("executable") == "index", "executable field broken"
    print("OK GODOT_CONFIG valid JSON; mainPack=" + cfg["mainPack"] +
          "; index.wasm size=" + str(cfg["fileSizes"]["index.wasm"]))
except Exception as e:
    print("ERROR: GODOT_CONFIG invalid: " + str(e))
    sys.exit(3)
