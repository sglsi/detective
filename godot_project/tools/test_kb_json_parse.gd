extends SceneTree

func _initialize() -> void:
	var path := "res://data/knowledge/knowledge_base.json"
	var ok := FileAccess.file_exists(path)
	print("FILE_EXISTS=%s" % ok)
	if not ok:
		print("KB_PARSE_DONE count=-1 (file missing -> fallback 7)")
		quit()
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	print("FILE_LEN=%d" % txt.length())
	var jp := JSON.new()
	var parsed = jp.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		print("KB_PARSE_DONE count=-1 PARSE_ERROR=%s" % jp.get_error_message())
		quit()
	print("KB_PARSE_DONE count=%d" % parsed.size())
	# domain coverage
	var domains := {}
	for e in parsed:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: String = e.get("domain", "?")
		domains[d] = domains.get(d, 0) + 1
	var keys := []
	for k in domains.keys():
		keys.append("%s:%d" % [k, domains[k]])
	keys.sort()
	print("DOMAINS=" + ", ".join(keys))
	# metadata coverage
	for mf in ["era","source","limitation","case_ref"]:
		var n := 0
		for e in parsed:
			if typeof(e) == TYPE_DICTIONARY and e.has(mf) and e[mf] not in [null, ""]:
				n += 1
		print("META %s=%d/%d" % [mf, n, parsed.size()])
	quit()
