class_name lang_utilities ##utilities for manipulating code in strings


##return a basic list of script method names
static func get_methods(value:Object) -> Array[String]:
	var method_n_list:Array[String] = []
	if value == null: return []
	var script:Script = value.get_script()
	if script == null: return []
	var properties_list = script.get_method_list()
	for property in properties_list:
		var n = property.get('name')
		method_n_list.append(n)
	return method_n_list


##return a basic list of script property names
static func get_property_names(value:Object) -> Array[String]:
	var property_n_list:Array[String] = []
	if value == null: return []
	var script:Script  = value.get_script()
	if script == null: return []
	var properties_list = script.get_script_property_list()
	for property in properties_list:
		var n = property.get('name')
		if n == '' || n == 'Built-in script':
			continue
		property_n_list.append(n)
	return property_n_list


##return's true if string matches a class type or builtin type
static func is_class_or_type(st:String,allow_type:=true) -> bool:
	var t = get_builtin_type(st)
	if allow_type:
		return t != TYPE_NIL || loader_lang.class_list.has(st)
	else:
		return loader_lang.class_list.has(st)


##return from all available classes and global classes (and types)
static func get_class_or_type(st:String) -> Variant:
	var t = get_builtin_type(st)
	if t != TYPE_NIL:
		return t
	
	if loader_lang.class_list.has(st):
		return loader_lang.class_list.find(st)
	
	print(loader_lang.global_class_list)
	
	return -1

##'float' -> TYPE_FLOAT
static func get_builtin_type(st_type:String) -> Variant.Type:
	if loader_lang.built_in_types.is_empty(): #build it if its empty
		for i in Variant.Type.TYPE_MAX:
			var type = i as Variant.Type
			loader_lang.built_in_types[type_string(type)] = type
	return loader_lang.built_in_types.get(st_type,TYPE_NIL)

##scrubs godot style comments, '##','#'
static func scrub_comments_GD(script_code:String) -> String:
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
			line = line.erase(comment_idx,line_length)
			code_packed[i] = line
	return "\n".join(code_packed)

##scrubs C++ style comments, '/*','*/', '//'
static func scrub_comments_C(script_code:String) -> String:
	var code_packed = script_code.split("\n",true)
	var comment_block = -1
	for i in code_packed.size():
		var line = code_packed[i]
		var line_length = line.length()
		var comment_idx = -1
		var comment_block_start = line.find('/*')
		var comment_block_end = line.find('*/')
		var comment = line.find('//')
		if comment_block_start > -1:
			comment_block += 1
			printt(comment_block_start,comment_block_end)
			comment_idx = comment_block_start
		if comment_block_end > -1:
			comment_block -= 1
		if comment > -1:
			comment_idx = comment
		if comment_idx > -1 || comment_block > -1:
			line = line.erase(comment_idx,line_length)
			code_packed[i] = line
		
	if comment_block != -1:
		printerr('uncapped C++ style comment block')
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
