extends SceneTree

func _init():
    call_deferred("_run")

func _run():
    var all_misleads := []
    for cid in ReasoningChains.ids():
        var data: Dictionary = ReasoningChains.CHAINS[cid]
        var bf: Dictionary = data.wall.get("battlefield", {})
        var hypos: Array = bf.get("hypotheses", [])
        var concls: Array = bf.get("conclusions", [])
        var chain_misleads: Array = []
        for h in hypos:
            if h.get("kind", "") == "mislead" or h.get("correct", true) == false:
                chain_misleads.append({
                    "id": h.id,
                    "type": "hypothesis",
                    "text": h.get("text", ""),
                    "reject_desc": h.get("reject_desc", ""),
                    "gate_clue_count": h.get("gate_clue_ids", []).size(),
                })
        for c in concls:
            if c.get("kind", "") == "mislead":
                chain_misleads.append({
                    "id": c.id,
                    "type": "conclusion",
                    "text": c.get("text", ""),
                    "reject_desc": c.get("reject_desc", ""),
                    "gate_hypo_count": c.get("gate_hypo_ids", []).size(),
                })
        if chain_misleads.size() > 0:
            all_misleads.append({
                "chain_id": cid,
                "chain_name": data.get("name", ""),
                "scene": data.get("scene", ""),
                "core": data.get("core", false),
                "misleads": chain_misleads,
            })
    print(JSON.stringify(all_misleads, "  "))
    quit()
