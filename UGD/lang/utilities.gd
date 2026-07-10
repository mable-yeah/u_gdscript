class_name lang_utilities ##utilities for manipulating code in strings

##TODO, cleanup, ts is BLOATED with other stuff that i do not need anymore

const interchangeable = [
	[TYPE_INT,TYPE_FLOAT],
	[TYPE_STRING,TYPE_STRING_NAME]
]

static func can_convert(type:Variant.Type,type_2:Variant.Type) -> bool:
	for group in interchangeable:
		if type in group and type_2 in group:
			return true
	return false


static func inheritence(ClassName:StringName,inherits:StringName):
	if !ClassDB.class_exists(ClassName): return ClassName == inherits
	return ClassDB.get_inheriters_from_class(ClassName).has(inherits) || ClassName == inherits

##gets string from type hint token
static func get_type_hint(tk:TOKENS.token) -> String:
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
static func get_op_st(op:loader_lang.Operation) -> String:
	var op_enum = loader_lang.Operation
	match op:
		op_enum.OP_MINUS:return '-'
		op_enum.OP_DIVIDE:return '/'
		op_enum.OP_MULTIPLY:return '*'
		op_enum.OP_PLUS:return '+'
		op_enum.OP_ADDITION:return '+='
		op_enum.OP_SUBTRACTION:return  '-=' 
		op_enum.OP_MULTIPLICATION:return  '*=' 
		op_enum.OP_DIVISION:return  '/=' 
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





static func get_class_methods(name:String):
	if !is_class_or_type(name,true,true):
		return [{}]
	
	var base_class = get_base_class(name)
	var method_list = ClassDB.class_get_method_list(base_class)
	if base_class == name: return method_list
	
	var registry = loader_lang.global_class_registry.get(name,null)
	if registry != null:
		var script = load(registry['path'])
		method_list.append_array(script.get_script_method_list())
		return method_list
	
	printerr('could not get globally declared class methods %s' % name)
	return [{}]



static func get_base_class(class_n:String) -> String:
	var class_list = loader_lang.class_list
	if class_list.has(class_n):
		return class_n
	
	var registry = loader_lang.global_class_registry.get(class_n,null)
	if registry != null:
		return registry['base']
	
	printerr('could not get base class type of %s, this class may not exist or be registered' % class_n)
	return ''

##return's true if string matches a class type or builtin type
static func is_class_or_type(st:String,allow_type:=true,global_classes:=false) -> bool:
	var class_list = loader_lang.class_list.duplicate()
	if global_classes:	class_list.append_array(loader_lang.global_class_list)
	var t = get_builtin_type(st)
	if allow_type:
		return t != TYPE_MAX || class_list.has(st)
	return class_list.has(st)


##'float' -> TYPE_FLOAT
static func get_builtin_type(st_type:String) -> Variant.Type:
	return loader_lang.built_in_types.get(st_type,TYPE_MAX)

static func is_builtin(st_type:String):
	return loader_lang.built_in_types.keys().has(st_type)

static func pack_AST(p_ast:compiler) -> String:
	var packed:PackedStringArray = []
	packed.append('extends %s' % p_ast.object_class)
	
	if !p_ast.class_n.is_empty():
		p_ast.class_n = p_ast.class_n.substr(0,50) ; var class_st = 'class_name %s' % p_ast.class_n
		packed.append(class_st)
	
	
	if !p_ast.contains_data(): return '\n'.join(packed)
	for expression in (p_ast.globals + p_ast.misc + p_ast.functions):
		packed.append(expression.get_code())
	return '\n'.join(packed)
