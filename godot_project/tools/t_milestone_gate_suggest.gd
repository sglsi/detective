extends SceneTree

func _init():
    call_deferred("_run")

func _run():
    var results: Array = []
    for cid in ReasoningChains.ids():
        var data: Dictionary = ReasoningChains.CHAINS[cid]
        var bf: Dictionary = data.wall.get("battlefield", {})
        var hypos: Array = bf.get("hypotheses", [])
        var concls: Array = bf.get("conclusions", [])
        var contradictions: Array = bf.get("contradictions", [])
        
        var true_hypo_ids: Array = []
        var mislead_hypo_ids: Array = []
        for h in hypos:
            if h.get("kind", "") == "true" or h.get("correct", false):
                true_hypo_ids.append(h.id)
            elif h.get("kind", "") == "mislead" or h.get("correct", true) == false:
                mislead_hypo_ids.append(h.id)
        
        var true_concl_ids: Array = []
        var mislead_concl_ids: Array = []
        for c in concls:
            if c.get("kind", "") == "true":
                true_concl_ids.append(c.id)
            elif c.get("kind", "") == "mislead":
                mislead_concl_ids.append(c.id)
        
        # 第一层结论：只依赖真假设（不依赖其他结论）且依赖 ≤2 个
        var first_layer: Array = []
        for c in concls:
            if c.get("kind", "") != "true":
                continue
            var ghs: Array = c.get("gate_hypo_ids", [])
            var gcs: Array = c.get("gate_clue_ids", [])
            var depends_on_concl := false
            for g in ghs:
                if str(g).begins_with("conclusion_") or true_concl_ids.has(str(g)):
                    depends_on_concl = true
                    break
            if not depends_on_concl and ghs.size() <= 2 and ghs.size() > 0:
                var all_true := true
                for g in ghs:
                    if not true_hypo_ids.has(str(g)):
                        all_true = false
                        break
                if all_true:
                    first_layer.append(c.id)
        
        # 最终结论：有 target 或依赖 ≥2 个结论节点
        var final_concls: Array = []
        var target_persons: Array = []
        for c in concls:
            if c.get("kind", "") != "true":
                continue
            var t: String = str(c.get("target", ""))
            if t.begins_with("person:"):
                final_concls.append(c.id)
                target_persons.append(t.substr(7))
                continue
            var ghs: Array = c.get("gate_hypo_ids", [])
            var concl_deps: int = 0
            for g in ghs:
                var gs := str(g)
                if gs.begins_with("conclusion_") or true_concl_ids.has(gs):
                    concl_deps += 1
            if concl_deps >= 2:
                final_concls.append(c.id)
        
        # 关键矛盾（correct=true 且文本含 "vs"）
        var key_contradictions: Array = []
        for ct in contradictions:
            if bool(ct.get("correct", false)) and str(ct.get("text", "")).find("vs") >= 0:
                key_contradictions.append(ct.id)
        
        # 合并建议 gate（去重保序）
        var suggested: Array = []
        for arr in [first_layer, final_concls, target_persons, key_contradictions]:
            for g in arr:
                if not suggested.has(g):
                    suggested.append(g)
        
        results.append({
            "chain_id": cid,
            "name": data.get("name", ""),
            "scene": data.get("scene", ""),
            "core": data.get("core", false),
            "num_hypo_true": true_hypo_ids.size(),
            "num_hypo_mislead": mislead_hypo_ids.size(),
            "num_concl_true": true_concl_ids.size(),
            "num_concl_mislead": mislead_concl_ids.size(),
            "first_layer_conclusions": first_layer,
            "final_conclusions": final_concls,
            "target_persons": target_persons,
            "key_contradictions": key_contradictions,
            "suggested_gates": suggested,
            "num_suggested": suggested.size(),
        })
    
    # 输出 JSON
    print(JSON.stringify(results, "  "))
    quit()
