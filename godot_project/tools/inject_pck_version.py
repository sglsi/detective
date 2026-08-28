import re, sys, json

path = "web_build/index.html"
ts = sys.argv[1] if len(sys.argv) > 1 else "TS"
with open(path, "r", encoding="utf-8") as f:
    s = f.read()

# Remove any previously injected mainPack FIRST — otherwise re-injecting onto an
# already-stamped index.html (without re-exporting) leaves two mainPack keys and
# JSON keeps the LAST one, i.e. the old timestamp silently wins.
new, n_rm = re.subn(r',"mainPack":"[^"]*"', '', s)
if n_rm:
    print("REMOVED %d stale mainPack key(s)" % n_rm)

# Documented injection (MEMORY.md 2026-08-11): insert mainPack right after
# "executable":"index" — DO NOT swallow the comma that follows executable.
new = re.sub(r'("executable":"index")', r'\1,"mainPack":"index.pck?v=' + ts + '"', new, count=1)
if new == s:
    print("ERROR: pattern \"executable\":\"index\" not found, injection skipped")
    sys.exit(1)
# Anti-cache: make the browser always revalidate index.html itself.
# Without this, python -m http.server sends no Cache-Control, so the browser
# uses heuristic caching and keeps serving a stale index.html -> stale pck URL.
NOCACHE = ('<meta http-equiv="Cache-Control" '
           'content="no-cache, no-store, must-revalidate">\n'
           '<meta http-equiv="Expires" content="0">\n'
           '<meta http-equiv="Pragma" content="no-cache">')
if 'http-equiv="Cache-Control"' in new:
    new = re.sub(r'<meta http-equiv="Cache-Control"[^>]*>',
                 '<meta http-equiv="Cache-Control" '
                 'content="no-cache, no-store, must-revalidate">', new, count=1)
    print("UPDATED no-cache meta")
else:
    mh = re.search(r'<head[^>]*>', new, re.I)
    if mh:
        new = new[:mh.end()] + "\n" + NOCACHE + new[mh.end():]
        print("INSERTED no-cache meta")
    else:
        print("WARN: <head> not found, no-cache meta skipped")

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
