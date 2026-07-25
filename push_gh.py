import subprocess, json, tempfile, os, base64, sys

os.chdir(r"C:\Users\sglsi\WorkBuddy\Claw\detective")
TOKEN = os.environ["GH_PAT"]
REPO = "sglsi/detective"
BRANCH = "main"
GIT = r"C:\Users\sglsi\.workbuddy\vendor\PortableGit\mingw64\bin\git.exe"

def git(*args):
    r = subprocess.run([GIT] + list(args), capture_output=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.decode()[:200]}")
    return r

def curl(method, path, data=None):
    cmd = ["curl","-sS","--max-time","300","-X",method,f"https://api.github.com/{path}",
           "-H",f"Authorization: Bearer {TOKEN}",
           "-H","Accept: application/vnd.github+json",
           "-H","X-GitHub-Api-Version: 2022-11-28","-w","\nHTTP:%{http_code}"]
    bf = None
    if data is not None:
        fd, bf = tempfile.mkstemp(suffix=".json")
        os.write(fd, data.encode())
        os.close(fd)
        cmd += ["-H","Content-Type: application/json","--data-binary",f"@{bf}"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=320)
        body,_,status = r.stdout.strip().rpartition("\nHTTP:")
        if status not in ("","200","201","202","204"):
            raise RuntimeError(f"{method} {path} HTTP {status}: {body[:200]}")
        return json.loads(body) if body.strip() else None
    finally:
        if bf and os.path.exists(bf): os.remove(bf)

print("1. Get remote HEAD...")
ref = curl("GET", f"repos/{REPO}/git/ref/heads/{BRANCH}")
parent = ref["object"]["sha"]
print(f"   parent: {parent[:12]}")

print("2. List local files...")
r = git("ls-tree","-r","-z","HEAD")
entries = []
for line in r.stdout.split(b'\0'):
    if not line.strip(): continue
    try:
        line_str = line.decode(errors='replace')
        parts = line_str.split("\t",1)
        meta = parts[0].split()
        if len(meta) < 3: continue
        mode,typ,oid,fname = meta[0],meta[1],meta[-1],parts[1] if len(parts)>1 else ""
        if typ in ("tree","commit"): continue
        entries.append((fname, oid, mode))
    except: pass

print(f"   {len(entries)} files to upload")

print("3. Upload blobs...")
blob_map = {}
for i,(fname,oid,mode) in enumerate(entries):
    r2 = git("cat-file","-p",oid)
    b64 = base64.b64encode(r2.stdout).decode()
    resp = curl("POST", f"repos/{REPO}/git/blobs", json.dumps({"content":b64,"encoding":"base64"}))
    blob_map[fname] = {"sha":resp["sha"],"mode":mode}
    if (i+1)%50==0: print(f"   {i+1}/{len(entries)}")

print("4. Create tree...")
tl = [{"path":f.replace("\\","/"),"mode":i["mode"],"type":"blob","sha":i["sha"]} for f,i in blob_map.items()]
t = curl("POST", f"repos/{REPO}/git/trees", json.dumps({"base_tree":parent,"tree":tl}))
print(f"   tree: {t['sha'][:12]}")

print("5. Commit...")
c = curl("POST", f"repos/{REPO}/git/commits", json.dumps({"message":"M1 scene1 refactor: SceneFramework+ClueObserver+walls+buttons","tree":t["sha"],"parents":[parent]}))
print(f"   commit: {c['sha'][:12]}")

print("6. Push...")
curl("PATCH", f"repos/{REPO}/git/refs/heads/{BRANCH}", json.dumps({"sha":c["sha"],"force":True}))
print("DONE! Pushed to GitHub.")
