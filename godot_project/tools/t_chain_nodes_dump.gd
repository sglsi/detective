extends SceneTree
func _init(): call_deferred("_run")
func _run():
    var out: Dictionary = {}
    for cid in ReasoningChains.ids():
        var chain: Dictionary = ReasoningChains.CHAINS[cid]
        var bf: Dictionary = chain.wall.get("battlefield", {})
        var hypos: Array = bf.get("hypotheses", [])
        var concls: Array = bf.get("conclusions", [])
        var true_h: Array = []
        for h in hypos:
            if h.get("correct", false):
                var d: Dictionary = {}
                d["id"] = h.id
                var t: String = str(h.get("text", ""))
                if t.length() > 45: t = t.left(45) + "..."
                d["text"] = t
                true_h.append(d)
        var true_c: Array = []
        for c in concls:
            if c.get("kind", "") == "true":
                var d: Dictionary = {}
                d["id"] = c.id
                var t: String = str(c.get("text", ""))
                if t.length() > 45: t = t.left(45) + "..."
                d["text"] = t
                true_c.append(d)
        var rec: Dictionary = {}
        rec["scene"] = chain.get("scene", "")
        rec["name"] = chain.get("name", "")
        rec["true_hypos"] = true_h
        rec["true_concls"] = true_c
        out[cid] = rec
    print(JSON.stringify(out, "  "))
    quit()
