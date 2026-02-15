class_name lang_utilities ##utilities for manipulating code in strings



##gets string from type hint token
func get_type_hint(tk:TOKENS.token) -> String:
	if tk == null:return ""
	const types = TOKENS.type
	match tk.type:
		types.TK_VOID:
			return 'void'
		types.IDENTIFIER:
			return tk.literal
	printerr('could not determine type from token %s' % tk.get_name())
	return ""

##returns operation enum as string
func get_op_st(op:loader_lang.Operation) -> String:
	var op_enum = loader_lang.Operation
	match op:
		op_enum.OP_ADDITION:return '+'
		op_enum.OP_SUBTRACTION:return  '-' 
		op_enum.OP_MULTIPLICATION:return  '*' 
		op_enum.OP_DIVISION:return  '/' 
		op_enum.OP_MODULO:return  '%' 
		op_enum.OP_POWER:return  '**' 
		op_enum.OP_BIT_LEFT_SHIFT:return  '<<' 
		op_enum.OP_BIT_RIGHT_SHIFT:return  '>>' 
		op_enum.OP_BIT_AND:return  '&' 
		op_enum.OP_BIT_OR:return  '|' 
		op_enum.OP_BIT_XOR:return  '^' 
		op_enum.OP_COMP_EQUAL:return  '==' 
		op_enum.OP_COMP_NOT_EQUAL:return  '!=' 
		op_enum.OP_COMP_LESS:return  '<' 
		op_enum.OP_COMP_LESS_EQUAL:return  '<=' 
		op_enum.OP_COMP_GREATER:return  '>' 
		op_enum.OP_COMP_GREATER_EQUAL:return  '>='
		op_enum.OP_LOGIC_OR: return '||'
		op_enum.OP_LOGIC_AND: return '&&'
		op_enum.OP_LOGIC_EQUAL: return '='
		_: printerr('could not find operation at index %s' % op) ; return ''





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
