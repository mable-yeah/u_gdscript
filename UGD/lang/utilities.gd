class_name lang_utilities






static func get_builtin_type(st_type:String) -> Variant.Type:
	if preparser_lang.built_in_types.is_empty(): #build it if its empty
		for i in Variant.Type.TYPE_MAX:
			var type = i as Variant.Type
			preparser_lang.built_in_types[type_string(type)] = type
	return preparser_lang.built_in_types.get(st_type,Variant.Type.TYPE_MAX)


##scrubs comment lines from code
static func scrub_comments(script_code:String) -> String:
	var code_packed = script_code.split("\n",true)
	for i in code_packed.size():
		var line = code_packed[i]
		var line_length = line.length()
		var comment_idx = -1
		var comment_special = line.find('##')
		var comment = line.find('#')
		if comment_special > -1:
			comment_idx = comment_special
		elif comment > -1:
			comment_idx = comment
		
		if comment_idx > -1:
			line = line.erase(comment,line_length)
			code_packed[i] = line
	return "\n".join(code_packed)


##scrubs whitespace from code
static func scrub_whitespace(script_code:String) -> String:
	var code_packed = script_code.split("\n",true)
	var scrubbed = code_packed.duplicate()
	for i in code_packed.size():
		var line = code_packed[i]
		if line.strip_edges() == "":
			scrubbed.erase(line)
	return "\n".join(scrubbed)
