import glob
from PIL import Image
import numpy as np
from collections import Counter

targets = [
 "assets/portraits/pixel/sherlock_思考.png",
 "assets/portraits/pixel/sherlock_自信.png",
 "assets/characters/watson/watson_平静.jpg",
 "assets/characters/watson/watson_思考.jpg",
 "assets/characters/gregson/gregson_portrait.png",
 "assets/characters/lestrade/lestrade.png",
 "assets/characters/mrs_hudson/mrs_hudson.png",
]
for p in targets:
    im = Image.open(p).convert("RGB")
    arr = np.array(im)
    h,w,_ = arr.shape
    # edge colors
    edges = np.concatenate([arr[0],arr[-1],arr[:,0],arr[:,-1]],axis=0).reshape(-1,3)
    ec = Counter(map(tuple,edges))
    top_edge = ec.most_common(3)
    # global dominant
    flat = arr.reshape(-1,3)
    gc = Counter(map(tuple,flat))
    top_glob = gc.most_common(4)
    unique_ratio = len(gc)/flat.shape[0]
    print(f"\n=== {p}  size={w}x{h} unique={unique_ratio:.3f}")
    print("  edge top3:", top_edge)
    print("  global top4:", top_glob)
