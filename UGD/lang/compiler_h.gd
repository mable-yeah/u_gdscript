class_name compiler_h extends AST.PROGRAM
##header for compiler, contains helper functions and u_object/u_kind definition

const errors = {
	'call_param':'a function call parameter of "%s" does not match its expected signature, expected "%s" got "%s"',
	'signature':'function "%s" does not match its parent signature, "%s"',
	'invalid_hint':'could not find type -> "%s"',
	'unreachable':'unreachable code found in function "%s" after return',
	'func':'a function typed "%s" cannot return -> "%s"',
	'expected':'expected "%s" got -> "%s" instead in %s',
	'ternary':'Values of the ternary operator are not mutually compatible. %s -> %s',
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"',
	'unresolved':'unresolved/orphan object found, .new() -> "%s" in "%s"',
	'standalone':'Standalone expression (the line may have no effect) -> "%s"',
	'object_assign':'value of type "%s" cannot be assigned to a variable of type "%s"',
	'unimplemented':'"%s" call unimplemented',
	'object_freed':'object "%s" was freed previously and cannot be addressed now -> "%s"',
}

var current_fn:u_object = null
var current_v:u_object = null

var loop_depth = 0

var orphaned:Dictionary[u_type,Variant] = {}
var scope:Array[Dictionary] = [{}]
var jumped_scopes:Array[Dictionary]
var jump_depth = 0


var current_scope:Dictionary: 
	get(): return scope.back()

var has_errors := false
var code:String = ''

var object_class:String = ''
var base_class:String = ''

#'extends example class_name test'
#object class becomes 'example'
#base class becomes 'Node' (assuming example extends node)


var signatures:Dictionary[String,func_sig] = {}

var unmutables:Dictionary[String,func_sig] = {
	'print':func_sig.new('print','void',[],true),
	'printt':func_sig.new('printt','void',[],true),
	'printerr':func_sig.new('printerr','void',[],true),
	'Vector2':func_sig.new('Vector2','Vector2',[utype(TYPE_FLOAT),utype(TYPE_FLOAT)]),
	'Vector2i':func_sig.new('Vector2i','Vector2',[utype(TYPE_INT),utype(TYPE_INT)]),
	'Color':func_sig.new('Color','Color',[utype(TYPE_FLOAT),utype(TYPE_FLOAT),utype(TYPE_FLOAT),utype(TYPE_FLOAT)]),
	'randf':func_sig.new('randf','float',[],false),
	'randi':func_sig.new('randi','int',[],false),
	'range':func_sig.new('range','Array',[utype(TYPE_INT),utype(TYPE_INT)],false),
	'str':func_sig.new('str','String',[],true),
}


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)



func type_string_(type) -> String:
	if type is Variant.Type and type != TYPE_MAX:
		return type_string(type)
	return '<null>'



func register_class(p_class:String) -> Dictionary[String,func_sig]:
	var registry:Dictionary[String,func_sig] = {}
	var class_methods = lang_utilities.get_class_methods(p_class)
	for method in class_methods:
		var sig = dict_to_sig(method)
		if sig == null: continue
		registry[method.name] = sig
	return registry


func register_class_properties(p_class:String) -> Dictionary[String,u_object]:
	var properties:Dictionary[String,u_object] = {}
	var class_methods = lang_utilities.get_class_properties(p_class)
	
	for property in class_methods:
		var sig = dict_to_sig(property)
		if sig == null: continue
		properties[sig.name] = sig
	return properties


func dict_to_sig(method:Dictionary):
	var is_method := method.has('return')
	if !is_method:
		var obj = u_object.new(method.name)
		obj.hint_n =  method.hint_string if method.class_name.is_empty() else method.class_name
		if obj.hint_n.is_empty():
			obj.hint_n = type_string_(method.type)
		obj.resolve_hint_name()
		return obj
	else:
		var arguments:Array[u_type] = []
		var hint = method.return.class_name
		var type = type_string_(method.return.type) if hint.is_empty() else hint
		
		if type == 'Nil': type = 'void'
		for arg in method.args: arguments.append(utype(arg.type))
		return func_sig.new(method.name,type,arguments,false)




class u_object:
	var is_constant = false
	var name:String
	
	#its worth noting TYPE_MAX, is essentially used like 'TYPE_ANY'
	var hint:u_type ; var hint_n:String
	
	var ast_expr:AST.Expr
	
	
	var params:Array[u_type] = []
	var varadic := false
	
	var resolved := false
	
	var meta := {}
	
	func _init(p_name:String,expr:AST.Expr = null) -> void:
		name = p_name
		ast_expr = expr
	
	func is_resolved(): return resolved
	func resolve(): resolved = true
	
	
	func resolve_hint(tk_hint:TOKENS.token = null,allow_classes = false) -> bool:
		var valid := true
		var hint_st := lang_utilities.get_type_hint(tk_hint)
		valid = resolve_hint_name(hint_st if tk_hint != null else hint_n)
		if !valid and allow_classes:
			valid = resolve_hint_as_class()
		return valid
	

	
	func resolve_hint_name(hint_st := hint_n):
		var valid := true
		var resolved_tk:Variant.Type = lang_utilities.get_builtin_type(hint_st)
		if resolved_tk == TYPE_MAX and hint_st != '':
			if hint_st != 'void':
				valid = false
			else: 
				hint = utype(TYPE_NIL)
		
		hint = utype(resolved_tk)
		hint_n = hint_st
		
		return valid
	
	func resolve_hint_as_class() -> bool:
		var n_is_class = lang_utilities.is_class_or_type(hint_n,false,false)
		
		if !ClassDB.class_exists(hint_n): return false
		
		if !ClassDB.can_instantiate(hint_n): return false
		
		if hint_n == 'RefCounted' || ClassDB.get_inheriters_from_class('RefCounted').has(hint_n): 
			return false
		
		if !n_is_class: return false
		
		if !Whitelist.available(hint_n): return false
		
		#im pretty sure if it can be instanced its an object!!
		hint = utype(TYPE_OBJECT)
		return true
	
	#just straight bullshitting so i dont need two functions for this (like the old version)
	func get_virtual_data(p_name:String,is_property:bool):
		var list:Array ; var to_append:Array
		if lang_utilities.is_builtin(hint_n): return get_method_builtin(p_name)
		
		if hint_n == '': return {}
		list = ClassDB.class_get_property_list(hint_n) if is_property\
		else lang_utilities.get_class_methods(hint_n)
		
		to_append = ClassDB.class_get_property_list('GDScript') if is_property\
		else ClassDB.class_get_method_list('GDScript')
		
		#if is_property: list.append_array(ClassDB.class_get_signal_list(hint_n))
		
		list.append_array(to_append)
		for virtual in list:
			if virtual.get('name',null) != p_name: continue
			return virtual
		return {}
	
	
	func get_method_builtin(p_name:String) -> Dictionary:
		var conversion = {
			'Array':u_Array,'Dictionary':u_Dictionary,
			'Vector2':u_Vector2,'Vector2i':u_Vector2i,
			'Vector3':u_Vector3,'Vector3i':u_Vector3i,
			'Vector4':u_Vector4,'Vector4i':u_Vector4i,
		}
		
		if hint_n in ['int','float']: return {}
		
		var binding_class = conversion.get(hint_n)
		
		if binding_class != null:
			return binding_class.new().get_binding(p_name)
		
		if OS.has_feature("editor"):
			printerr('unimplimented builtin %s' % hint_n)
		return {}
	
	##returns true if objects match
	func compare_object(ref:u_object):
		var hint_valid = hint_n == ref.hint_n ; var name_valid = name == ref.name
		if ref.hint_n == 'void' and hint_n == '': hint_valid = true
		return hint_valid && name_valid && compare_params(ref.params)
	
	##compares params with p_param
	func compare_params(p_param:Array[u_type]) -> bool:
		var valid := true ; var i := 0
		if params.size() != p_param.size(): return false
		while i < params.size():
			var left_param = params[i].type ; var right_param = p_param[i].type
			var is_valid = left_param != right_param and left_param != TYPE_MAX
			if is_valid and !lang_utilities.can_convert(left_param,right_param):
				valid = false ; break
			i += 1
		return valid
	
	##formats an array with types in it to a string, 'int,float'
	static func format_param(p_param:Array[u_type]):
		var p_st = []
		for param in p_param:
			var string = 'any'
			if param.type is Variant.Type and param.type != TYPE_MAX:
				string =  type_string(param.type)
			
			p_st.append(string)
		
		return ','.join(p_st)

	func utype(p_type:Variant.Type):
		return u_type.new(p_type)


#this helps with defining abstract/placeholder functions
class func_sig extends u_object:
	func _init(p_name:String,type_hint:String,p_param:Array[u_type],p_varadic = false) -> void:
		name = p_name ; params = p_param ; varadic = p_varadic ; hint_n = type_hint
		resolve_hint(null,true)
	
	##returns function as 'func_name(param_type) -> return_type'
	func sig_string() -> String:
		return '%s(%s) -> %s' % [name,format_param(params),hint_n]

func utype(p_type:Variant.Type):
	return u_type.new(p_type)

class u_type:
	var type:Variant.Type
	var meta:Dictionary
	
	func _init(p_type:Variant.Type):
		type = p_type 
