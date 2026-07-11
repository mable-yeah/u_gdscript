class_name compiler extends compiler_h
##handles AST analysis and re-compiling code into gd script

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
	
	
	#for property in 
	
	
	for expression in (globals + misc + functions):
		expression.visit(self) 
		##visit calls one of the cooresponding functions here
	
	
	if orphaned.is_empty(): return
	for unresolved:u_type in orphaned.keys():
		var info = [\
		unresolved.meta.get('object_type','unknown object type'),\
		unresolved.meta.get('root','main body')
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
	if literal_allowed:assignables.append(type.LITERAL)
	return expr.type in assignables

func can_reduce(expr:AST.Expr) -> bool:
	const type = loader_lang.Type
	match expr.type:
		type.ARRAY:
			var elements:Array[bool]
			for e in expr.elements: elements.append(can_reduce(e))
			return !elements.has(false)
		type.DICTIONARY:
			var elements:Array[bool]
			
			for e in expr.elements.keys():
				elements.append(can_reduce(e) if e is AST.Expr else true)
			
			for e in expr.elements.values(): 
				elements.append(can_reduce(e))
			
			return !elements.has(false)
		type.LITERAL:
			return true
		type.UNARY_OPERATOR:
			return can_reduce(expr.operand)
		type.ASSIGNMENT:
			return can_reduce(expr.left) and can_reduce(expr.right)
	return false

func visit_header():
	if !lang_utilities.is_class_or_type(object_class,false,true):
		make_error('ugd could not initialize, class type is invalid -> "%s"' % object_class)
		return
	
	base_class = lang_utilities.get_base_class(object_class)
	
	if lang_utilities.inheritence(base_class,'Node'):
		unmutables['add_child'] = func_sig.new('add_child','void',[utype(TYPE_OBJECT)])
	
	signatures.merge(register_class(object_class))
	
	current_scope.merge(register_class_properties(object_class))
	
	
	if class_n != '':
		if !shadows_declared(class_n): return
		make_error('class name "%s", shadows an internal class/variable' % class_n)
	

	
func visit_var_decl(stmt:AST.varDecl_Statement):
	var ref = u_object.new(stmt.name,stmt) ; current_v = ref
	var hint_valid = ref.resolve_hint(stmt.type_hint,true)
	var init = stmt.initializer != null
	
	ref.is_constant = stmt.is_constant
	if !hint_valid and ref.hint_n != '':
		make_error(errors.invalid_hint % ref.hint_n)
	
	if stmt.is_constant:
		if init:
			if !can_reduce(stmt.initializer): 
				make_error('assigned value for constant "%s" isnt a constant expression.' % ref.name)
		else:
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

func visit_enum(expr:AST.enumerator):
	var ref = u_object.new(expr.name) 
	ref.hint_n = 'enum.%s' % ref.name
	
	for num in expr.enumerators:
		if num.key in ref.meta:
			make_error('name "%s" was already in enum -> "%s"' % [num.key,ref.name])
			break
		ref.meta[num.key] = {  #set it up like a dictionary anyways
			'key':num.key,
			'element':num.value,
			'type':TYPE_INT
		}
	
	def_variable(ref)
	return ref



func visit_func_decl(stmt:AST.funcDecl_Statement):
	var ref := get_reference(stmt.name)
	if ref.is_resolved(): return ref
	var hint_valid = ref.resolve_hint(stmt.type_hint,true)
	var visited_return := false
	jump_scope() ; def_scope()
	current_fn = ref
	if !hint_valid and ref.hint_n != '':
		make_error('could not resolve function hint type -> "%s"' % ref.hint_n)
	
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
	return expr.operand.visit(self)

func visit_ternary(expr:AST.ternary) -> u_type:
	var target = expr.target.visit(self) 
	var left = expr.left.visit(self) 
	var right = expr.right.visit(self)
	
	if left.type != TYPE_BOOL: make_error(errors.expected % ['boolean',type_string_(left.type),'ternary'])
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
	var objects_exist = left_obj != null and right_obj != null
	
	if right.type in [TYPE_MAX,TYPE_NIL]:
		make_error('cannot assign a functions result, if the function is un-typed or void')
		return utype(TYPE_NIL)
	
	if expr.left.type == loader_lang.Type.IDENTIFIER:
		var ref = get_reference(expr.left.name)
		if ref == null: return utype(TYPE_NIL)
		if ref.is_constant:
			make_error('cannot assign a new value to a constant. -> "%s"' % ref.name)
		if !ref.hint.meta.is_empty():
			orphaned.erase(ref.hint)
		ref.hint = right
		ref.hint_n = right.meta.get('object_type',type_string_(right.type))
		return right
	
	
	if left.type != right.type and !lang_utilities.can_convert(left.type,right.type):
		make_error(errors.assign % [type_string_(left.type),type_string_(right.type)])
	elif left_obj != right_obj and left.type == TYPE_OBJECT:
		if objects_exist and ClassDB.get_inheriters_from_class(left_obj).has(right_obj):
			return right
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
	
	validate_function(ref,expr)
	
	
	if ref.name == 'add_child':
		var meta_visit = expr.args[0].visit(self)
		var meta:Dictionary = meta_visit.meta
		if meta.get('freed'):
			make_error(errors.object_freed % [expr.args[0].get_code(),ref.name])
			return utype(TYPE_NIL)
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
	loop_depth += 1 ; def_scope()
	
	const iter_types = [TYPE_ARRAY,TYPE_DICTIONARY,TYPE_INT,TYPE_FLOAT]
	var iter:u_type = stmt.iter.visit(self)
	if !(iter.type in iter_types):
		make_error('cannot iterate on base type -> "%s"' % type_string_(iter.type))
		return utype(TYPE_NIL)
	
	var ref = u_object.new(stmt.name)
	ref.hint_n = 'int' ; ref.hint = u_type.new(TYPE_INT)
	def_variable(ref)
	
	for expression in stmt.body:
		expression.visit(self)
	leave_scope()
	loop_depth -= 1
	return utype(TYPE_NIL)

#generally while loops cause things to freeze, so not doing it for now :/
func visit_while(_stmt:AST.while_Statement):
	make_error(errors.unimplemented % 'while')
	return utype(TYPE_NIL)


func visit_break(_stmt:AST.break_Statement):
	if loop_depth == 0: make_error(errors.loop % 'break')
	return utype(TYPE_NIL)

func visit_continue(_stmt:AST.cont_Statement):
	if loop_depth == 0: make_error(errors.loop % 'continue') 
	return utype(TYPE_NIL)

func visit_pass(_stmt:AST.pass_Statement): 
	return utype(TYPE_NIL)


#TODO currently arrays and dictionarys rely on being defined through a variable
#this blocks for i [0,0,0] as it throws a standalone warning
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
		var element_visited:u_type = expr.elements[key].visit(self)
		var key_data = key.visit(self) if key is AST.Expr else key
		var key_code = key.get_code() if key is AST.Expr else key
		
		current_v.meta[key_code] = {
			'key':key_data,
			'element':element_visited,
			'type':element_visited.type
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
	if has_errors: return utype(TYPE_NIL)
	var name:String = stmt.target.name if target_is_var else target_visited.meta.get('object_type','')
	var ref:u_object = get_reference(name) if target_is_var else null
	var member = stmt.member_name
	

	#something like 'Node.new().name' would cause such cases
	if stmt.member is AST.member_Call:
		make_error('invalid member call chain on -> "%s"' % name)
	elif member == '': 
		make_error('invalid member address on -> "%s"' % name)
	elif ref != null and ref.hint.meta.has('freed'):
		make_error(errors.object_freed % [name,member])
	
	if has_errors: return utype(TYPE_NIL)
	
	if ref == null:
		ref = u_object.new(name) ; ref.hint_n = name
		if !ref.resolve_hint_as_class():
			make_error(errors.invalid_hint % ref.hint_n)
			return utype(TYPE_NIL)
		
		if member == 'new':
			ref.hint.meta = {
				'orphaned' = true,
				'object_type' = name,
			}
			
			if current_fn != null: ref.hint.meta['root'] = 'function %s' % current_fn.name 
			orphaned[ref.hint] = null
			return ref.hint
	

	
	var data = null
	
	#because of the way some member data is stored; i have to do this, particularly for dictionarys/enums
	for key in ref.meta.keys(): 
		var string_matches = (key.contains('"') || key.contains("'")) and key.contains(member)
		if key != member and !string_matches: continue
		data = ref.meta.get(key,null) ; break
	
	if data == null: 
		var is_instanced = ref.hint.meta.has('orphaned')
		data = ref.get_virtual_data(member,stmt.is_property)
		if !is_instanced and ref.hint.type == TYPE_OBJECT:
			make_error('cannot call property/method -> "%s" on base "%s" as this object needs to be instanced first' % [member,ref.name])
			return utype(TYPE_NIL)
	
	if data.is_empty(): 
		make_error('property/method "%s" does not exist in -> "%s" on base of "%s"' % [member,ref.name,ref.hint_n])
		return utype(TYPE_NIL)
	
	var return_type:u_type = utype(TYPE_NIL)
	
	#TODO currently some returned function calls dont get registered as 
	#variables as they have variant returns/TYPE_MAX, ideally i need to figure out how to assign a 
	#new non-placeholder value
	if data.has('return'): 
		if stmt.member is AST.function_call:
			var fn_sig = dict_to_sig(data)
			if fn_sig != null:
				return_type = validate_function(fn_sig,stmt.member)
		
	elif data.has('type'): return_type = utype(data['type'])
	
	if member == 'free' and ref.hint.meta.has('object_type'):
		ref.hint.meta['freed'] = true
		orphaned.erase(ref.hint)
	
	return return_type

func validate_function(ref:func_sig,expr:AST.function_call) -> u_type:
	var name := expr.target.name
	const void_err = 'cannot use a function or value that returns "void" inside of a call (%s) argument -> %s'
	
	#varadic functions generally dont follow any typing througout
	#but still visit the arguments to confirm they exist in the first place
	if ref.varadic: 
		for i in expr.args.size(): 
			var arg = expr.args[i]
			var visit = arg.visit(self)
			if visit.type == TYPE_MAX: make_error(void_err % [name,i])
		return ref.hint 
	
	var param_s = ref.params.size() ; var arg_s = expr.args.size()
	var err = 'few' if param_s > arg_s else 'many'
	
	if param_s != arg_s:
		make_error('too %s arguments for call "%s"' % [err,name])
		return utype(TYPE_NIL)
	
	var local_args:Array[u_type] = []
	for i in expr.args.size(): 
		var arg = expr.args[i]
		var visit = arg.visit(self)
		if !(visit is u_type): continue
		if visit.type == TYPE_MAX: make_error(void_err % [name,i])
		local_args.append(visit)
	
	
	if !ref.compare_params(local_args):
		var err_arr = [ref.name,u_object.format_param(ref.params),u_object.format_param(local_args)]
		make_error(errors.call_param % err_arr)
		return utype(TYPE_NIL)
	
	return ref.hint
