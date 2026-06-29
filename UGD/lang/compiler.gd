class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script

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
	'unresolved':'unresolved/ophan object found, .new() -> "%s" in function "%s"',
	'standalone':'Standalone expression (the line may have no effect) -> "%s',
	'object_assign':'value of type "%s" cannot be assigned to a variable of type "%s"',
	'unimplemented':'"%s" call unimplemented',
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
}


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)


func _init(p_ast:AST.PROGRAM,base_className:String) -> void:
	object_class = base_className
	self.class_n =  p_ast.class_n
	self.extends_n = p_ast.extends_n
	self.globals = p_ast.globals
	self.functions = p_ast.functions
	self.misc = p_ast.misc
	visit_code()
	if has_errors: return
	code = lang_utilities.pack_AST(self)

func visit_code():
	visit_header()
	if !contains_data() || has_errors: return
	
	for stmt in functions:
		def_variable(u_object.new(stmt.name,stmt))
	
	#resolve the signature if its not already being re-defined
	for sig in signatures.values():
		if is_declared(sig.name): continue
		sig.resolve() ; def_variable(sig)

	for sig in unmutables.values():
		sig.resolve() ; current_scope[sig.name] = sig


	for expression in (globals + misc + functions):
		expression.visit(self) 
		##visit calls one of the cooresponding functions here
	
	
	
	if orphaned.is_empty(): return
	for unresolved:u_type in orphaned.keys():
		var info = [\
		unresolved.meta.get('object_type','unknown object type'),\
		unresolved.meta.get('root','unknown function name')
		]
		make_error(errors.unresolved % info)
	

func def_scope(): scope.append({})

func leave_scope(): scope.pop_back()

func jump_scope():
	var local_scope = scope.duplicate() ; local_scope.reverse()
	var size = scope.size() - 1
	
	jump_depth = loop_depth ; loop_depth = 0
	jumped_scopes = local_scope.slice(0,size) ; scope = local_scope.slice(size)

func append_jumps():
	loop_depth = jump_depth ; jump_depth = 0
	jumped_scopes.reverse() ; scope.append_array(jumped_scopes)


func scope_range(): return range(scope.size() - 1, -1, -1)



func def_variable(ref:u_object):
	if shadows_declared(ref.name): make_error(errors.shadows % ['',ref.name])
	current_scope[ref.name] = ref

func shadows_declared(name:String) -> bool:
	var declared = is_declared(name)
	if lang_utilities.is_class_or_type(name,true,true): return true
	return declared

func is_declared(name:String) -> bool:
	return !(get_reference(name) == null)

func get_reference(name:String) -> u_object:
	for i in scope_range():
		if name in scope[i]: return scope[i][name]
	return null


func is_assignable(expr:AST.Expr,literal_allowed = true) -> bool:
	const type = loader_lang.Type
	var assignables = [
		type.IDENTIFIER,type.MEMBER_CALL,
		type.INDEX,type.ASSIGNMENT
	] 
	if literal_allowed: assignables.append(type.LITERAL)
	return expr.type in assignables


func visit_header():
	if !lang_utilities.is_class_or_type(object_class,false,true):
		make_error('ugd could not initialize, class type is invalid -> "%s"' % object_class)
		return
	
	base_class = lang_utilities.get_base_class(object_class)
	
	if lang_utilities.inheritence(base_class,'Node'):
		unmutables['add_child'] = func_sig.new('add_child','void',[utype(TYPE_OBJECT)])
	
	signatures.merge(register_class(object_class))
	
	if class_n != '':
		if !shadows_declared(class_n): return
		make_error('class name "%s", shadows an internal class/variable' % class_n)
	

	
func visit_var_decl(stmt:AST.varDecl_Statement):
	var ref = u_object.new(stmt.name,stmt) ; current_v = ref
	var hint_valid = ref.resolve_hint(stmt.type_hint,true)
	var init = stmt.initializer != null
	
	if !hint_valid and ref.hint_n != '':
		make_error(errors.invalid_hint % ref.hint_n)
	
	if stmt.is_constant and !init:
		make_error('constants need initializers "%s"' % stmt.name)
	if init:
		var init_type:u_type = stmt.initializer.visit(self)
		var init_object = init_type.meta.get('object_type',type_string_(init_type.type))
		
		if init_type.type == TYPE_MAX || init_type.type == TYPE_NIL:
			make_error('variable "%s" could not be assigned as its initializer is un-typed or void' % ref.name)
		
		if ref.hint_n != '' and ref.hint.type != init_type.type and !lang_utilities.can_convert(ref.hint.type,init_type.type):
			make_error('variable "%s" doesnt match type hint -> %s, got %s' % [ref.name,ref.hint_n,type_string_(init_type.type)])
		
		if ref.hint_n != init_object and ref.hint.type == TYPE_OBJECT:
			make_error('variable "%s" doesnt match type hint -> %s, got %s' % [ref.name,ref.hint_n,init_object])
		
		ref.hint_n = init_object
		ref.hint = init_type
	elif ref.hint_n != '':
		if ref.hint.type == TYPE_OBJECT:
			ref.hint.meta['object_type'] = ref.hint_n
		#need to assign metadata for laterrr
	
	def_variable(ref)
	current_v = null
	return ref

func visit_func_decl(stmt:AST.funcDecl_Statement):
	var ref := get_reference(stmt.name)
	if ref.is_resolved(): return ref
	var hint_valid = ref.resolve_hint(stmt.type_hint)
	var visited_return := false
	jump_scope() ; def_scope()
	current_fn = ref
	if !hint_valid and ref.hint_n != '':
		make_error(errors.invalid_hint % ref.hint_n)
	
	for param in stmt.params.values(): 
		var p_ref = param.visit(self)
		ref.params.append(p_ref.hint)
	
	if signatures.has(ref.name) and !ref.compare_object(signatures[ref.name]):
		var sig = signatures[ref.name].sig_string()
		make_error(errors.signature % [ref.name,sig])
	
	
	for expression in stmt.body:
		if visited_return and loop_depth == 0: 
			make_error(errors.unreachable % stmt.name) ; break
		expression.visit(self)
		if expression is AST.return_Statement: visited_return = true
	
	if !visited_return and ref.hint_n != '' and ref.hint_n != 'void':
		make_error('not all code paths return a value / function is typed but the main body doesnt return')
	
	ref.resolve()
	leave_scope() ; append_jumps()
	current_fn = null
	return ref



func visit_return(stmt:AST.return_Statement) -> u_type:
	var expr_exists = stmt.expression != null
	var ref = current_fn
	var expr_hint = stmt.expression.visit(self) if expr_exists else utype(TYPE_NIL)
	
	if ref == null: return utype(TYPE_NIL)
	
	#hint exists and is void AND a return expression exists
	if ref.hint_n and ref.hint.type == TYPE_MAX and expr_exists:
		make_error(errors.func % ['void', type_string_(expr_hint.type)])
		return utype(TYPE_NIL)
	
	#hint exists but expression doesnt
	if !expr_exists: 
		if ref.hint_n != '': make_error(errors.func % [ref.hint_n, type_string_(TYPE_NIL)])
		return utype(TYPE_NIL)
	
	#hint exists but expression doesnt match it
	if ref.hint_n != '' and ref.hint.type != expr_hint.type:
		make_error(errors.func % [ref.hint_n, type_string_(expr_hint.type)])
		return utype(TYPE_NIL)
	
	return ref.hint



func visit_literal(expr:AST.literal) -> u_type:
	var variant = str(expr.variant)
	
	if variant.contains("'") || variant.contains('"'):
		return utype(TYPE_STRING)
	
	if variant in ['true','false']: 
		return utype(TYPE_BOOL)
	
	if variant == 'null': 
		return utype(TYPE_NIL)
	
	return utype(expr.literal_type)

func visit_variable(expr:AST.variable):
	if is_declared(expr.name): 
		var ref = get_reference(expr.name)
		if ref != null: return ref.hint
	
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)
	return utype(TYPE_NIL)

func visit_expression(stmt:AST.expression_Statement):
	stmt.expression.visit(self)
	return utype(TYPE_NIL)

func visit_unary(expr:AST.unary):
	expr.operand.visit(self)
	return utype(TYPE_NIL)

func visit_ternary(expr:AST.ternary) -> u_type:
	var target = expr.target.visit(self) 
	var left = expr.left.visit(self) 
	var right = expr.right.visit(self)
	
	if left != TYPE_BOOL: make_error(errors.expected % ['boolean',type_string_(left.type),'ternary'])
	if target != right: make_error(errors.ternary % [type_string_(target.type),type_string_(right.type)])
	return target

func visit_is(expr:AST.is_statement) -> u_type:
	var _left = expr.left.visit(self) ; var right =  expr.right.visit(self)
	
	var right_expr = expr.right
	if right_expr is AST.variable and lang_utilities.is_builtin(right_expr.name):
		return utype(TYPE_BOOL)
	
	make_error('expected type identifier after "is"')
	return utype(TYPE_NIL)

func visit_if(stmt:AST.if_Statement) -> u_type:
	var _condition = stmt.condition.visit(self) 
	
	def_scope()
	for expression in stmt._then:expression.visit(self)
	leave_scope()
	
	if stmt._else.is_empty(): return 
	
	def_scope()
	for expression in stmt._else:expression.visit(self)
	leave_scope()
	return utype(TYPE_NIL)



func visit_assignment(expr:AST.assignment) -> u_type:
	var literal_allowed = !(expr.op == loader_lang.Operation.OP_LOGIC_EQUAL)
	if !is_assignable(expr.left,literal_allowed): 
		var err = 'invalid assignment target, only identifier, attribute, and subscriptions can be assigned'
		if literal_allowed:
			err = errors.assign %[expr.left._tk_st,expr.right._tk_st]
		make_error(err) #helps fix being able to do 2 = 5
		return utype(TYPE_NIL)
	
	var right = expr.right.visit(self)
	var left = expr.left.visit(self)
	
	var left_obj = left.meta.get('object_type')
	var right_obj = right.meta.get('object_type')
	
	
	if right.type in [TYPE_MAX,TYPE_NIL]:
		make_error('cannot assign a functions result, if the function is un-typed or void')
		return utype(TYPE_NIL)
	
	if expr.left.type == loader_lang.Type.IDENTIFIER:
		var ref = get_reference(expr.left.name)
		if ref == null: return utype(TYPE_NIL)
		
		if ref.is_weak: #re-assign and return
			ref.hint = right
			return right
	
	
	if left.type != right.type and !lang_utilities.can_convert(left.type,right.type):
		make_error(errors.assign % [type_string_(left.type),type_string_(right.type)])
	elif left_obj != right_obj:
		make_error(errors.object_assign % [right_obj,left_obj])
	
	return right


func visit_function_call(expr:AST.function_call) -> u_type:
	var name := expr.target.name
	var ref := get_reference(name)
	
	
	if ref == null: 
		make_error('function does not exist -> "%s"' % name)
		return utype(TYPE_NIL)
	
	if !ref.is_resolved():
		ref.ast_expr.visit(self)


	#varadic functions generally dont follow any typing througout
	#but still visit the arguments to confirm they exist in the first place
	if ref.varadic: 
		for arg in expr.args: arg.visit(self)
		return ref.hint 
	
	var param_s = ref.params.size() ; var arg_s = expr.args.size()
	var err = 'few' if param_s > arg_s else 'many'
	
	
	
	if param_s != arg_s:
		make_error('too %s arguments for call "%s"' % [err,name])
		return utype(TYPE_NIL)
	
	var local_args:Array[u_type] = []
	for arg in expr.args: 
		var visit = arg.visit(self)
		if !(visit is u_type): continue
		local_args.append(visit)
	
	
	if !ref.compare_params(local_args):
		var err_arr = [ref.name,u_object.format_param(ref.params),u_object.format_param(local_args)]
		make_error(errors.call_param % err_arr)
		return utype(TYPE_NIL)
	
	if ref.name == 'add_child':
		var meta_visit = expr.args[0].visit(self)
		var meta:Dictionary = meta_visit.meta
		if !meta.get('orphaned',false):
			make_error('cannot add an already parented node %s' % expr.args[0].get_code())
			return utype(TYPE_NIL)
		meta['orphaned'] = false
		orphaned.erase(meta_visit)
		return ref.hint
	
	if ref.hint.type == TYPE_OBJECT:
		ref.hint.meta['object_type'] = ref.hint_n
	
	return ref.hint


func visit_for(stmt:AST.for_Statement):
	loop_depth += 1
	stmt.iter.visit(self) ; def_scope()
	def_variable(u_object.new(stmt.name))
	for expression in stmt.body:
		expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return utype(TYPE_NIL)

func visit_while(stmt:AST.while_Statement):
	loop_depth += 1 
	
	if !is_assignable(stmt.condition,true):
		make_error('expected assignable condition after while, got %s instead' % stmt.condition.get_type_name())
		return utype(TYPE_NIL)
	
	stmt.condition.visit(self) ; def_scope()
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return utype(TYPE_NIL)

func visit_break(_stmt:AST.break_Statement):
	if loop_depth == 0: make_error(errors.loop % 'break')
	return utype(TYPE_NIL)

func visit_continue(_stmt:AST.cont_Statement):
	if loop_depth == 0: make_error(errors.loop % 'continue') 
	return utype(TYPE_NIL)

func visit_pass(_stmt:AST.pass_Statement): 
	return utype(TYPE_NIL)


func visit_array(expr:AST.array) -> u_type:
	if current_v == null:  make_error(errors.standalone % 'array') ; return utype(TYPE_ARRAY)
	
	for index in expr.elements.size():
		var data = expr.elements[index].visit(self)
		current_v.meta[str(index)] = {
			'element':data,
		}
	return utype(TYPE_ARRAY)

func visit_dictionary(expr:AST.dictionary) -> u_type:
	if current_v == null:  make_error(errors.standalone % 'dictionary') ; return utype(TYPE_DICTIONARY)
	for key in expr.elements.keys():
		var element_visited = expr.elements[key].visit(self)
		var key_data = key.visit(self) if key is AST.Expr else key
		var key_code = key.get_code() if key is AST.Expr else key
		
		
		current_v.meta[key_code] = {
			'key':key_data,
			'element':element_visited,
		}
		
	return utype(TYPE_DICTIONARY)
#this begs the question? why did the dictionary choose key over the bread?

func visit_index(expr:AST.index) -> u_type:
	var target = expr.target.visit(self)
	var index = expr.idx.get_code()
	if !(target.type in [TYPE_DICTIONARY,TYPE_ARRAY]):
		make_error('Cannot use subscript operator on a base of type "%s"' % type_string_(target.type))
		return utype(TYPE_NIL)
	
	if !(expr.target is AST.variable):
		make_error('index target needs to be a variable' % type_string_(target.type))
		return utype(TYPE_NIL)
	
	var name = expr.target.name
	var ref:u_object = get_reference(name)
	var from_meta = ref.meta.get(index,null)
	if from_meta == null:
		make_error('cannot get index "%s" on base of %s' % [expr.idx.get_code(),name])
		return utype(TYPE_NIL)
	
	return from_meta.element



func visit_member_call(stmt:AST.member_Call) -> u_type:
	var target_is_var = stmt.target is AST.variable
	var target_visited = null if target_is_var else stmt.target.visit(self) 
	var name:String = stmt.target.name if target_is_var else target_visited.meta.get('object_type','')
	var ref:u_object = get_reference(name) if target_is_var else null
	var member = stmt.member_name
	
	if has_errors: return ref.hint if ref != null else utype(TYPE_NIL)
	
	if ref == null:
		ref = u_object.new(name) ; ref.hint_n = name
		if !ref.resolve_hint_as_class(): 
			return utype(TYPE_NIL)
		
		
		if member == 'new':
			ref.hint.meta = {
				'orphaned' = true,
				'object_type' = name,
				'root' = current_fn.name
			}
			orphaned[ref.hint] = null
			return ref.hint
	
	var data = ref.get_virtual_data(member,stmt.is_property)
	if data.is_empty(): 
		make_error('property/method "%s" does not exist in -> "%s" on base of "%s"' % [member,ref.name,ref.hint_n])
		return utype(TYPE_NIL)
	
	var return_type = TYPE_NIL
	
	if data.has('return'): return_type = data['return']['type']
	elif data.has('type'): return_type = data['type']
	return utype(return_type)

func type_string_(type) -> String:
	if type is Variant.Type and type != TYPE_MAX:
		return type_string(type)
	return '<null>'


func register_class(p_class:String) -> Dictionary[String,func_sig]:
	var registry:Dictionary[String,func_sig] = {}
	var class_methods = lang_utilities.get_class_methods(p_class)
	for method in class_methods:
		var arguments:Array[u_type] = []
		var hint = method.return.class_name
		var type = type_string_(method.return.type) if hint.is_empty() else hint
		
		if type == 'Nil': type = 'void'
		for arg in method.args: arguments.append(utype(arg.type))
		registry[method.name] = func_sig.new(method.name,type,arguments,false)
	return registry

class u_object:
	var name:String
	
	#its worth noting TYPE_MAX, is essentially used like 'TYPE_ANY'
	var hint:u_type ; var hint_n:String
	
	var ast_expr:AST.Expr
	
	var is_weak:bool:
		get():
			return hint_n == ''
	#if hint exists but the hint_n is empty, the object type can change
	#i.e its 'weak'

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
		
		if !n_is_class: 
			if ClassDB.class_exists(hint_n): 
				if !ClassDB.can_instantiate(hint_n): return false
			else:
				return false
			printerr('cannot resolve "%s" as a valid class' % hint_n)
			return false
		#im pretty sure if it can be instanced its an object!!
		hint = utype(TYPE_OBJECT)
		return true
	
	#just straight bullshitting so i dont need two functions for this (like the old version)
	func get_virtual_data(p_name:String,is_property:bool):
		var list:Array ; var to_append:Array
		if hint_n == '': return {}
		list = ClassDB.class_get_property_list(hint_n) if is_property\
		else lang_utilities.get_class_methods(hint_n)
		
		to_append = ClassDB.class_get_property_list('GDScript') if is_property\
		else ClassDB.class_get_method_list('GDScript')
		
		if is_property: list.append_array(ClassDB.class_get_signal_list(hint_n))
		
		list.append_array(to_append)
		for virtual in list:
			if virtual.get('name',null) != p_name: continue
			return virtual
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
		for param in p_param: p_st.append(type_string(param.type))
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
