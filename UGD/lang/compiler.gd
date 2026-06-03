class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script

const errors = {
	'call_param':'a function call parameter of "%s" does not match its expected signature, expected "%s" got "%s"',
	'signature':'function "%s" does not match its parent signature, "%s"',
	'invalid_hint':'could not find type -> "%s"',
	'builtin':'Builtin type cannot be used as a name on its own -> "%s"',
	'unreachable':'unreachable code found in function "%s" after return',
	'func':'a function typed "%s" cannot return -> "%s"',
	'expected':'expected "%s" got -> "%s" instead in %s',
	'ternary':'Values of the ternary operator are not mutually compatible. %s -> %s',
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"',
	'unimplemented':'%s call unimplemented'
}

var current_fn:u_object = null

var loop_depth = 0


var scope:Array[Dictionary] = [{}]
var jumped_scopes:Array[Dictionary]
var jump_depth = 0


var current_scope:Dictionary: 
	get(): return scope.back()

var has_errors := false
var code:String = ''
var base_class:String = ''

var signatures:Dictionary[String,func_sig] = {
	'print':func_sig.new('print','void',[],true),
	'printt':func_sig.new('printt','void',[],true),
	'printerr':func_sig.new('printerr','void',[],true)
} 

func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)


func _init(p_ast:AST.PROGRAM,base_className:String) -> void:
	base_class = base_className
	self.class_n =  p_ast.class_n
	self.extends_n = p_ast.extends_n
	self.globals = p_ast.globals
	self.functions = p_ast.functions
	self.misc = p_ast.misc
	visit_code()
	if has_errors: return
	code = lang_utilities.pack_AST(self)
	print_rich('[color=green]%s[/color]' % code)

func visit_code():
	signatures.merge(register_class(base_class))
	if class_n != '': visit_header()
	if !contains_data() || has_errors: return
	
	for stmt in functions:
		def_variable(u_object.new(stmt.name,stmt))
	
	#resolve the signature if its not already being re-defined
	for sig in signatures.values():
		if is_declared(sig.name): continue
		sig.resolve() ; def_variable(sig)
	
	for expression in (globals + misc + functions):
		expression.visit(self) 
		#visit calls one of the cooresponding functions here


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
	if !shadows_declared(class_n): return
	make_error('class name "%s", shadows an internal class/variable' % class_n)


func visit_var_decl(stmt:AST.varDecl_Statement):
	var ref = u_object.new(stmt.name,stmt)
	var hint_valid = ref.resolve_hint(stmt.type_hint)
	var init = stmt.initializer != null
	
	if !hint_valid and ref.hint_n != '':
		make_error(errors.invalid_hint % ref.hint_n)
	
	if stmt.is_constant and !init:
		make_error('constants need initializers "%s"' % stmt.name)
	
	if init:
		var init_type:Variant.Type = stmt.initializer.visit(self)
		
		if stmt.initializer is AST.member_Call: #assign .new manually :/
			var name = stmt.initializer.target.name
			var member_call = stmt.initializer.member_name
			if member_call == 'new' and !hint_valid:
				ref.hint_n = name
				ref.resolve_hint_as_class()
				init_type = ref.hint
			#theres probs a big downside to this aside from it being ugly
			#but for now it works
		
		
		if init_type == TYPE_MAX:
			make_error('variable "%s" could not be assigned as its initializer is typed "void"' % ref.name)
			
		if ref.hint_n != '' and ref.hint != init_type:
			make_error('variable "%s" doesnt match type hint -> %s' % [ref.name,ref.hint_n])
		
		ref.hint = init_type
	
	def_variable(ref)
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



func visit_return(stmt:AST.return_Statement):
	var expr_exists = stmt.expression != null
	var ref = current_fn
	var expr_hint = stmt.expression.visit(self) if expr_exists else TYPE_NIL
	
	if ref == null: return TYPE_NIL
	
	#hint exists and is void AND a return expression exists
	if ref.hint_n and ref.hint == TYPE_MAX and expr_exists:
		make_error(errors.func % ['void', type_string(expr_hint)])
		return TYPE_NIL
	
	#hint exists but expression doesnt
	if !expr_exists: 
		if ref.hint_n != '': make_error(errors.func % [ref.hint_n, type_string(TYPE_NIL)])
		return TYPE_NIL
	
	#hint exists but expression doesnt match it
	if ref.hint_n != '' and ref.hint != expr_hint:
		make_error(errors.func % [ref.hint_n, type_string(expr_hint)])
		return TYPE_NIL
	
	return ref.hint



func visit_literal(expr:AST.literal):
	var variant = str(expr.variant)
	
	if variant.contains("'") || variant.contains('"'):
		return TYPE_STRING
	
	if variant in ['true','false']: 
		return TYPE_BOOL
	
	if variant == 'null': 
		return TYPE_NIL
	
	return expr.literal_type

func visit_variable(expr:AST.variable):
	if is_declared(expr.name): 
		var ref = get_reference(expr.name)
		if ref != null: return ref.hint
	
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)
	return TYPE_NIL

func visit_expression(stmt:AST.expression_Statement):
	stmt.expression.visit(self)
	return TYPE_NIL

func visit_unary(expr:AST.unary):
	expr.operand.visit(self)
	return TYPE_NIL

func visit_ternary(expr:AST.ternary):
	var target = expr.target.visit(self) 
	var left = expr.left.visit(self) 
	var right = expr.right.visit(self)
	
	if left != TYPE_BOOL: make_error(errors.expected % ['boolean',type_string(left),'ternary'])
	if target != right: make_error(errors.ternary % [type_string(target),type_string(right)])
	return target

func visit_is(expr:AST.is_statement):
	var _left = expr.left.visit(self) ; var right =  expr.right.visit(self)
	
	var right_expr = expr.right
	if right_expr is AST.variable and lang_utilities.is_builtin(right_expr.name):
		return TYPE_BOOL
	
	make_error('expected type identifier after "is"')
	return TYPE_NIL

func visit_if(stmt:AST.if_Statement):
	var _condition = stmt.condition.visit(self) 
	
	def_scope()
	for expression in stmt._then:expression.visit(self)
	leave_scope()
	
	if stmt._else.is_empty(): return 
	
	def_scope()
	for expression in stmt._else:expression.visit(self)
	leave_scope()
	return TYPE_BOOL





func visit_assignment(expr:AST.assignment):
	var literal_allowed = !(expr.op == loader_lang.Operation.OP_LOGIC_EQUAL)
	if !is_assignable(expr.left,literal_allowed): 
		var err = 'invalid assignment target, only identifier, attribute, and subscriptions can be assigned'
		if literal_allowed:
			err = errors.assign %[expr.left._tk_st,expr.right._tk_st]
		make_error(err) #helps fix being able to do 2 = 5
		return TYPE_NIL
	
	var right = expr.right.visit(self)
	var left = expr.left.visit(self)
	
	if right == TYPE_MAX || right == TYPE_NIL:
		make_error('cannot assign a functions result, if the function is un-typed or void')
		return TYPE_NIL
	
	if expr.left.type == loader_lang.Type.IDENTIFIER:
		var ref = get_reference(expr.left.name)
		if ref == null: return TYPE_NIL
		
		if ref.is_weak: #re-assign and return
			ref.hint = right
			return right
	
	if left != right: make_error(errors.assign % [type_string(left),type_string(right)])
	return right


func visit_function_call(expr:AST.function_call):
	var name := expr.target.name
	var ref := get_reference(name)
	
	if ref == null: 
		make_error('function does not exist -> "%s"' % name)
		return TYPE_NIL
	
	if !ref.is_resolved():
		ref.ast_expr.visit(self)
	
	#varadic functions generally dont follow any typing througout
	if ref.varadic: return ref.hint 
	
	var param_s = ref.params.size() ; var arg_s = expr.args.size()
	var err = 'few' if param_s > arg_s else 'many'
	
	if param_s != arg_s:
		make_error('too %s arguments for call "%s"' % [err,name])
		return TYPE_NIL
	
	var local_args:Array[Variant.Type] = []
	for arg in expr.args: 
		var visit = arg.visit(self)
		if !(visit is Variant.Type): continue
		local_args.append(visit)
	
	
	if !ref.compare_params(local_args):
		var err_arr = [ref.name,u_object.format_param(ref.params),u_object.format_param(local_args)]
		make_error(errors.call_param % err_arr)
	
	return ref.hint


func visit_for(stmt:AST.for_Statement):
	loop_depth += 1
	stmt.iter.visit(self) ; def_scope()
	def_variable(u_object.new(stmt.name))
	for expression in stmt.body:
		expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return TYPE_NIL

func visit_while(stmt:AST.while_Statement):
	loop_depth += 1 
	stmt.condition.visit(self) ; def_scope()
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return TYPE_NIL



func visit_break(_stmt:AST.break_Statement):
	if loop_depth == 0: make_error(errors.loop % 'break')
	return TYPE_NIL

func visit_continue(_stmt:AST.cont_Statement):
	if loop_depth == 0: make_error(errors.loop % 'continue') 
	return TYPE_NIL

func visit_pass(_stmt:AST.pass_Statement): 
	return TYPE_NIL


func visit_array(_expr:AST.array):
	make_error(errors.unimplemented % 'array')
	return TYPE_NIL

func visit_dictionary(_expr:AST.dictionary):
	make_error(errors.unimplemented % 'dictionary')
	return TYPE_NIL


func visit_index(_expr:AST.index):
	make_error(errors.unimplemented % 'index')
	return TYPE_NIL

func visit_member_call(stmt:AST.member_Call):
	if !(stmt.target is AST.variable):
		make_error('cannot call a member on a non-variable reference -> "%s"' % stmt.target.get_type_name())
		return TYPE_NIL
	
	var member = stmt.member_name; var name = stmt.target.name
	var ref:u_object = get_reference(name)
	if ref == null:
		ref = u_object.new(name) ; ref.hint_n = name
		if !ref.resolve_hint_as_class(): 
			make_error('cannot resolve name "%s" as a class or variable in this scope' % ref.name)
			return TYPE_NIL
			#only allowing node's to be instanced member wise
			#forces direct references i.e
			#'x = Node.new()' ; rather than allowing 'x = Node'
	
	
	var data = ref.get_virtual_data(member,stmt.is_property)
	if data.is_empty(): 
		make_error('property/method "%s" does not exist in -> "%s"' % [member,ref.name])
		return TYPE_NIL
	
	var return_type = TYPE_NIL
	
	
	if data.has('return'): return_type = data['return']['type']
	elif data.has('type'): return_type = data['type']
	return return_type



func register_class(p_class:String) -> Dictionary[String,func_sig]:
	var registry:Dictionary[String,func_sig] = {}
	var class_methods = lang_utilities.get_class_methods(p_class)
	for method in class_methods:
		var arguments:Array[Variant.Type] = []
		var type = type_string(method.return.type)
		
		if type == 'Nil': type = 'void'
		for arg in method.args: arguments.append(arg.type)
		
		registry[method.name] = func_sig.new(method.name,type,arguments,false)
	return registry

class u_object:
	var name:String
	
	#its worth noting TYPE_MAX, is essentially used like 'TYPE_ANY'
	var hint:Variant.Type ; var hint_n:String
	
	var ast_expr:AST.Expr
	
	var is_weak:bool:
		get():
			return hint_n == ''
	#if hint exists but the hint_n is empty, the object type can change
	#i.e its 'weak'

	var params:Array[Variant.Type] = []
	var varadic := false
	
	var resolved := false
	
	var is_classed := false
	
	var meta := {}
	
	
	func _init(p_name:String,expr:AST.Expr = null) -> void:
		name = p_name
		ast_expr = expr
	
	func is_resolved(): return resolved
	func resolve(): resolved = true
	
	##only resolves built in types, so custom classes shouldn't work
	func resolve_hint(tk_hint:TOKENS.token) -> bool:
		var valid := true
		var hint_st := lang_utilities.get_type_hint(tk_hint)
		var resolved_tk:Variant.Type = lang_utilities.get_builtin_type(hint_st)
		
		if resolved_tk == TYPE_MAX and hint_st != '':
			if hint_st != 'void': valid = false
			else: hint = TYPE_NIL
		
		hint = resolved_tk
		hint_n = hint_st
		return valid
	
	
	func resolve_hint_as_class() -> bool:
		var n_is_class = ClassDB.class_exists(hint_n)
		if !n_is_class: 
			printerr('cannot resolve %s as a valid class' % hint_n)
			return false
		
		#jank maybe ???? idkkkk, this might always resolve as TYPE_OBJECT
		hint = typeof(ClassDB.instantiate(hint_n)) as Variant.Type
		hint_n = hint_n
		return true
	
	#just straight bullshitting so i dont need two functions for this (like the old version)
	func get_virtual_data(p_name:String,is_property:bool):
		var list:Array ; var to_append:Array
		if hint_n == '': return {}
		list = ClassDB.class_get_property_list(hint_n) if is_property\
		else lang_utilities.get_class_methods(hint_n)
		
		to_append = ClassDB.class_get_property_list('GDScript') if is_property\
		else ClassDB.class_get_method_list('GDScript')
		
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
	func compare_params(p_param:Array[Variant.Type]) -> bool:
		var valid := true ; var i := 0
		if params.size() != p_param.size(): return false
		while i < params.size():
			if params[i] != p_param[i] and params[i] != TYPE_MAX:
				valid = false ; break
			i += 1
		return valid
	
	##formats an array with types in it to a string, 'int,float'
	static func format_param(p_param:Array[Variant.Type]):
		var p_st = []
		for param in p_param: p_st.append(type_string(param))
		return ','.join(p_st)

#this helps with defining abstract/placeholder functions
class func_sig extends u_object:
	func _init(p_name:String,type_hint:String,p_param:Array[Variant.Type],p_varadic = false) -> void:
		name = p_name ; params = p_param ; varadic = p_varadic
		resolve_hint(TOKENS.create_token(TOKENS.type.IDENTIFIER,type_hint))
	
	##returns function as 'func_name(param_type) -> return_type'
	func sig_string() -> String:
		return '%s(%s) -> %s' % [name,format_param(params),hint_n]
