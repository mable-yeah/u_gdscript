class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script


const errors = {
	'builtin':'Builtin type cannot be used as a name on its own -> "%s"',
	'unreachable':'unreachable code found in function "%s" after return',
	'func':'a function typed "%s" cannot return -> "%s"',
	'expected':'expected "%s" got -> "%s" instead in %s',
	'ternary':'Values of the ternary operator are not mutually compatible. %s -> %s',
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"'
}

var loop_depth = 0
var fn_signatures:Dictionary = {}
var scope:Array[Dictionary] = [{}]
var current_scope_idx:int = 0
var current_scope:Dictionary:
	get(): return scope.get(current_scope_idx)

var current_fn:AST.funcDecl_Statement = null


var has_errors := false
var code:String = ''
var base_class:String = ''


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)

func _init(p_ast:AST.PROGRAM,base_className) -> void:
	base_class = base_className
	self.class_n =  p_ast.class_n
	self.extends_n = p_ast.extends_n
	self.globals = p_ast.globals
	self.functions = p_ast.functions
	self.misc = p_ast.misc
	visit_code()
	if has_errors: return
	code = pack_code()
	print(code)

func def_scope():
	scope.append({}) ; current_scope_idx += 1

func leave_scope():
	scope.pop_back() ; current_scope_idx -= 1


func def_signature(function:AST.funcDecl_Statement,varadic = false):
	var sig = {}
	sig['params'] = []
	sig['hint'] = lang_utilities.get_type_hint(function.type_hint)
	sig['varadic'] = varadic
	for param in function.params.keys():
		if !is_declared(param): 
			make_error('param "%s" isnt in the current scope?' % param)
			continue
		var p_sig = {}
		p_sig['name'] = param
		p_sig['type'] = get_reference_type(param)
		sig['params'].append(p_sig)
	
	
	sig['param_s'] = sig['params'].size()
	fn_signatures[function.name] = sig

func def_variable(name:String,type := type_string(TYPE_NIL),data = {}):
	if !data.get('skip',false):
		if shadows_declared(name): make_error(errors.shadows % [type,name])
	
	data['type'] = type
	current_scope[name] = data

func shadows_declared(name:String) -> bool:
	var declared = is_declared(name)
	if lang_utilities.is_class_or_type(name,true,true): return true
	return declared

func is_declared(name:String) -> bool:
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return true
	return false

func get_reference_type(name:String):
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return scope[i][name]['type']
	return type_string(TYPE_NIL)

func get_reference(name:String):
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return scope[i][name]
	return {}

func get_signature(name:String):
	if name in fn_signatures:
		return fn_signatures[name]
	make_error('function called without signature/definition "%s"' % name)
	return {}

func is_assignable(expr:AST.Expr,literal_allowed = true) -> bool:
	const type = loader_lang.Type
	var assignables = [
		type.IDENTIFIER,
		type.MEMBER_CALL,
		type.INDEX,
		type.ASSIGNMENT
	] 
	if literal_allowed: assignables += [type.LITERAL]
	return assignables.has(expr.type)

func visit_var_decl(stmt:AST.varDecl_Statement):
	var type = type_string(TYPE_NIL)
	var hint = lang_utilities.get_type_hint(stmt.type_hint)
	
	if stmt.initializer != null:
		type = str(stmt.initializer.visit(self)) #process init first
		if stmt.initializer.type_is(loader_lang.Type.IDENTIFIER):
			if lang_utilities.is_builtin(stmt.initializer.name):
				make_error(errors.builtin % ('%s in %s' % [stmt.initializer.name,stmt.name]))
				return type
		
	elif stmt.is_constant: 
		make_error('constants need initializers "%s"' % stmt.name) ; return type
	if hint != '' and stmt.initializer and type != hint:
		make_error('variable "%s" doesnt match type hint -> %s' % [stmt.name,hint])
	
	
	
	if type == type_string(TYPE_NIL) and hint != '': type = hint
	def_variable(stmt.name,type,{'is_strong' : hint != ''})
	
	return type


func visit_func_decl(stmt:AST.funcDecl_Statement):
	current_fn = stmt
	def_variable(stmt.name,'function',{'skip':stmt.skip_processing}) ; def_scope()
	
	var visited_return = false
	for param in stmt.params.values(): param.visit(self) 
	def_signature(stmt,stmt.varadic)
	
	for expression in stmt.body:
		if visited_return and loop_depth == 0: 
			make_error(errors.unreachable % stmt.name) ; break
		expression.visit(self)
		if expression is AST.return_Statement: visited_return = true
	
	if !visited_return and !stmt.skip_processing: 
		var fallback = AST.return_Statement.new()
		fallback.visit(self)
		fallback = null
	
	leave_scope()
	current_fn = null
	return lang_utilities.get_type_hint(stmt.type_hint)

func visit_enum(expr:AST.enumerator):
	def_variable(expr.name,'enum')
	var enums = {}
	for num in expr.enumerators:
		var name = num.keys()[0]
		if (name not in enums): enums[name] = false ; continue
		make_error('name "%s" was already inside of enum "%s"' % [name,expr.name])

func visit_variable(expr:AST.variable):
	if is_declared(expr.name): return get_reference_type(expr.name)
	
	if lang_utilities.is_class_or_type(expr.name): return expr.name
	
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)
	return type_string(TYPE_NIL)

func visit_literal(expr:AST.literal):
	var variant = str(expr.variant)
	
	if variant.contains("'") || variant.contains("'"):
		return type_string(TYPE_STRING)
	
	if ['true','false'].has(variant): 
		return type_string(TYPE_BOOL)
	
	if variant == 'null': 
		return type_string(TYPE_NIL)
	
	return type_string(expr.literal_type)



func visit_function_call(expr:AST.function_call):
	var name = expr.target.name
	var sig = get_signature(name)
	if sig.is_empty(): return type_string(TYPE_NIL)
	
	if sig['varadic']: return sig['hint']
	var err = 'few' if sig['param_s'] > expr.args.size() else 'many'
	if sig['param_s'] != expr.args.size():
		make_error('too %s arguments for call "%s"' % [err,name])
		return sig['hint']
	
	for i in expr.args.size():
		var arg = expr.args[i]
		var arg_type = arg.visit(self)
		var out_type = sig['params'][i]['type']
		
		#ints/floats get converted within the script to the correct type
		#so i dont need to enforce values within vector2/vector2i as ints/floats
		if ['int','float'].has(arg_type) and arg_type != out_type: arg_type = out_type
		
		if !lang_utilities.inheritence(out_type,arg_type): 
			make_error('%s argument %s should be -> %s, got "%s" instead' % [name,i + 1,out_type,arg_type])
	return sig['hint']

func visit_member_call(expr:AST.member_Call):
	var target = expr.target.visit(self)
	var resolved = resolve_as_object(target)
	var member = expr.member
	if resolved == null: 
		make_error('could not resolve "%s" into a valid object -> member_call' % target)
		return type_string(TYPE_NIL)
	
	def_scope() #for the sake of easing my brain enter a scope here
	if member is AST.function_call: 
		member = member.target.name
		if resolved is String and member is String:
			var method = get_virtual_method(resolved,member)
			if method == null: return type_string(TYPE_NIL)
			method.visit(self)
			method = null
	elif member is AST.variable: 
		member = member.name
		var property = get_virtual_property(resolved,member)
		if property == null: return type_string(TYPE_NIL)
		target = property.visit(self)
		property = null
	
	expr.member.visit(self)
	leave_scope() ; return target

func visit_index(expr:AST.index):
	var target = expr.target.visit(self)
	var index = expr.idx.visit(self)
	
	match target:
		'Array':
			if index != 'int':
				make_error('Invalid index type "%s" on base Array' % index)
				return type_string(TYPE_NIL)
			
		'Dictionary': 
			pass
			#dicts allow basically everything for indexing
			#u can witawee do 'dict[func():pass] = null' and it'll work
			
		'String':
			if index != 'int':
				make_error('Invalid index type "%s" on base Array' % index)
				return type_string(TYPE_NIL)
			
		_:
			make_error('cannot use subscript operator on a base of type "%s"' % target)
			return type_string(TYPE_NIL)
	
	return type_string(TYPE_NIL)


func visit_is(expr:AST.is_statement):
	var left = expr.left.visit(self) ; var right =  expr.right.visit(self)
	
	if !lang_utilities.inheritence(left,right) and not (expr.left is AST.variable):
		make_error('expression is of type "%s" so it cant be of type "%s"' % [left,right])
		return type_string(TYPE_NIL)
	
	
	var right_expr = expr.right
	if right_expr is AST.variable and lang_utilities.is_builtin(right_expr.name):
		return type_string(TYPE_BOOL)
	
	make_error('expected type identifier after "is"')
	return type_string(TYPE_NIL)


func visit_assignment(expr:AST.assignment):
	#kind of janky workaround for being able to do
	#5 = 1, usually that typa stuff stops in the pre-parser
	#but not allowing literals at all blocks x = (5+5) + 2
	var literal_allowed = !(expr.op == loader_lang.Operation.OP_LOGIC_EQUAL)
	if !is_assignable(expr.left,literal_allowed):
		make_error(errors.assign %[expr.left._tk_st,expr.right._tk_st])
	
	var right = expr.right.visit(self)
	var left = expr.left.visit(self)
	
	#this is STUPID, fix it later future me
	if left == 'StringName': left = 'String'
	if right == 'void': make_error(errors.assign % [left,right])
	
	
	
	if expr.left.type == loader_lang.Type.IDENTIFIER:
		if !get_reference(expr.left.name)['is_strong']: return right
		#skip checks if the variant isnt strongly typed
	
	if !lang_utilities.inheritence(left,right): make_error(errors.assign % [left,right])
	return right

func visit_expression(stmt:AST.expression_Statement):
	stmt.expression.visit(self)
	return type_string(TYPE_NIL)

func visit_unary(expr:AST.unary):
	expr.operand.visit(self)
	return type_string(TYPE_NIL)

func visit_ternary(expr:AST.ternary):
	var target = expr.target.visit(self) 
	var left = expr.left.visit(self) 
	var right = expr.right.visit(self)
	
	if left != type_string(TYPE_BOOL): make_error(errors.expected % ['boolean',left,'ternary'])
	if target != right: make_error(errors.ternary % [target,right])
	return target

func visit_array(expr:AST.array):
	for element in expr.elements:
		element.visit(self) 
	return type_string(TYPE_ARRAY)

func visit_dictionary(expr:AST.dictionary):
	for element in expr.elements.values():
		element.visit(self)
	return type_string(TYPE_DICTIONARY)
	
func visit_if(stmt:AST.if_Statement):
	var _condition = stmt.condition.visit(self) 
	
	def_scope()
	for expression in stmt._then:expression.visit(self)
	leave_scope()
	
	if stmt._else.is_empty(): return 
	
	def_scope()
	for expression in stmt._else:expression.visit(self)
	leave_scope()
	return type_string(TYPE_NIL)

func visit_for(stmt:AST.for_Statement):
	loop_depth += 1
	stmt.iter.visit(self) ; def_scope()
	def_variable(stmt.name)
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return type_string(TYPE_NIL)

func visit_while(stmt:AST.while_Statement):
	loop_depth += 1 
	stmt.condition.visit(self) ; def_scope()
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()
	return type_string(TYPE_NIL)

func visit_break(_stmt:AST.break_Statement):
	if loop_depth == 0: make_error(errors.loop % 'break')
	return type_string(TYPE_NIL)

func visit_continue(_stmt:AST.cont_Statement):
	if loop_depth == 0: make_error(errors.loop % 'continue') 
	return type_string(TYPE_NIL)

func visit_pass(_stmt:AST.pass_Statement): 
	return type_string(TYPE_NIL)

func visit_return(stmt:AST.return_Statement):
	if current_fn == null: return type_string(TYPE_NIL)
	
	var hint = lang_utilities.get_type_hint(current_fn.type_hint)
	var expr_exists = stmt.expression != null
	
	if hint == 'void':
		if expr_exists: make_error(errors.func % ['void', stmt.expression.visit(self)])
		return type_string(TYPE_NIL)

	if !expr_exists: 
		if hint != '': make_error(errors.func % [hint, type_string(TYPE_NIL)])
		return type_string(TYPE_NIL)

	var expr_type = stmt.expression.visit(self)
	if hint != '' and expr_type != hint:
		make_error(errors.func % [hint, expr_type])
	
	return hint

func visit_header():
	if !shadows_declared(class_n): return
	make_error('class name "%s", shadows an internal class/variable' % class_n)



#this is needed to register some base level functions to ugd
func get_builtins():
	var globalscope = ugd_globalscope.new()
	
	var globalscope_methods = lang_utilities.get_methods(globalscope,false)
	for method in globalscope_methods:
		method_from_dict(method).visit(self)
	
	globalscope = null

func get_virtual_method(value:StringName,method_name:String) -> AST.funcDecl_Statement:
	if value == '': make_error('virtual_method provided value is null') ; return null
	var method_list = ClassDB.class_get_method_list(value)
	method_list.append_array(ClassDB.class_get_method_list('GDScript'))
	for method in method_list:
		if method['name'] != method_name: continue
		return method_from_dict(method)
	
	make_error('could not find method "%s" in -> "%s"' % [method_name,value])
	return null


func get_virtual_property(value:StringName,property_name:String):
	if value == '': make_error('virtual_property provided value is null') ; return null
	var property_list = ClassDB.class_get_property_list(value)
	property_list.append_array(ClassDB.class_get_property_list('GDScript'))
	
	for property in property_list:
		if property['name'] != property_name: continue
		return property_from_dict(property)
	#
	make_error('could not find property "%s" in -> "%s"' % [property_name,value])
	return null



func property_from_dict(property:Dictionary) -> AST.varDecl_Statement:
	var return_type = type_string(property['type'])
	var return_tk = TOKENS.create_token(TOKENS.type.IDENTIFIER,return_type)
	var name = property['name']
	return AST.varDecl_Statement.new(name,return_tk,null,false)



func method_from_dict(method:Dictionary) -> AST.funcDecl_Statement:
	var function = AST.funcDecl_Statement.new()
	function.skip_processing = true
	function.name = method['name']
	function.varadic = method['flags'] == 17
	
	for argument in method['args']:
		if function.varadic: break
		function.params[argument['name']] = property_from_dict(argument)
	
	var return_type = type_string(method['return']['type'])
	var return_tk = TOKENS.create_token(TOKENS.type.IDENTIFIER,return_type)
	function.type_hint = return_tk
	return function

func resolve_as_object(value:String) -> Variant:
	if !lang_utilities.is_class_or_type(value,false,false): return null
	return value




func visit_code():
	get_builtins()
	if class_n != '': visit_header()
	if !contains_data() || has_errors: return
	
	for expression in (globals + misc + functions):
		expression.visit(self) 
		#visit calls one of the cooresponding functions here



func pack_code():
	var packed:PackedStringArray = []
	packed.append('extends %s' % base_class)
	if class_n == '': class_n = 's_%s' %  globals.hash()
	class_n = class_n.substr(0,50) ; var class_st = 'class_name %s' % class_n
	packed.append(class_st)
	
	
	if !contains_data(): return '\n'.join(packed)
	for expression in (globals + misc + functions):
		packed.append(expression.get_code())
		#get_code redirects to AST_codegen
	return '\n'.join(packed)
