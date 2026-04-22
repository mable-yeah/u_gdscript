class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script


const errors = {
	'unreachable':'unreachable code found in function %s after return',
	'func':'a function typed "%s" cannot return -> "%s"',
	'expected':'expected "%s" got -> "%s" instead in %s',
	'ternary':'Values of the ternary operator are not mutually compatible. %s -> %s',
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"'
}

var loop_depth = 0
var signatures = []
var scope:Array[Dictionary] = [{}]
var current_scope_idx:int = 0
var current_scope:Dictionary:
	get(): return scope.get(current_scope_idx)

var current_fn:AST.funcDecl_Statement = null

var has_errors := false
var code:String = ''


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)

func _init(p_ast:AST.PROGRAM) -> void:
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



func def_variable(name:String,type := type_string(TYPE_NIL),data = {}):
	if shadows_declared(name): make_error(errors.shadows % [type,name])
	data['type'] = type
	current_scope[name] = data

func shadows_declared(name:String) -> bool:
	var declared = is_declared(name)
	if lang_utilities.is_class_or_type(name): return true
	return declared

func is_declared(name:String) -> bool:
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return true
	return false

func get_reference(name:String):
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return scope[i][name]['type']
	return type_string(TYPE_NIL)


func is_assignable(expr:AST.Expr) -> bool:
	const type = loader_lang.Type
	var assignables = [
		type.IDENTIFIER,
		type.MEMBER_CALL,
		type.INDEX,
		type.LITERAL,
		type.ASSIGNMENT
	]
	return assignables.has(expr.type)

func visit_var_decl(stmt:AST.varDecl_Statement):
	var type = type_string(TYPE_NIL)
	if stmt.initializer != null: 
		type = stmt.initializer.visit(self) #process init first
	elif stmt.is_constant: 
		make_error('constants need initializers "%s"' % stmt.name) ; return
	
	var hint = lang_utilities.get_type_hint(stmt.type_hint)
	if hint != '' and stmt.initializer and type != hint:
		make_error('variable "%s" doesnt match type hint -> %s' % [stmt.name,hint])
	def_variable(stmt.name,type)


func visit_func_decl(stmt:AST.funcDecl_Statement):
	current_fn = stmt
	def_variable(stmt.name,'function') ; def_scope()
	
	var visited_return = false
	for param in stmt.params.values(): param.visit(self) 
	for expression in stmt.body:
		if visited_return and loop_depth == 0: 
			make_error(errors.unreachable % stmt.name)
		expression.visit(self)
		if expression is AST.return_Statement: visited_return = true
	
	if !visited_return: 
		var fallback = AST.return_Statement.new()
		fallback.visit(self)
	
	leave_scope()
	current_fn = null

func visit_enum(expr:AST.enumerator):
	def_variable(expr.name,'enum')
	var enums = {}
	for num in expr.enumerators:
		var name = num.keys()[0]
		if (name not in enums): enums[name] = false ; continue
		make_error('name "%s" was already inside of enum "%s"' % [name,expr.name])

func visit_variable(expr:AST.variable):
	if is_declared(expr.name): 
		return get_reference(expr.name)
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)
	return type_string(TYPE_NIL)

func visit_literal(expr:AST.literal):
	return type_string(expr.literal_type)

func visit_function_call(expr:AST.function_call):
	expr.target.visit(self)
	for arg in expr.args:
		arg.visit(self)
	

func visit_member_call(expr:AST.member_Call):
	expr.target.visit(self)
	expr.member.visit(self)

func visit_index(expr:AST.index):
	expr.target.visit(self)
	expr.idx.visit(self)


func visit_assignment(expr:AST.assignment):
	if !is_assignable(expr.left):
		make_error(errors.assign %[expr.left._tk_st,expr.right._tk_st])
	
	var right = expr.right.visit(self)
	expr.left.visit(self) ; expr.right.visit(self)
	return right

func visit_expression(stmt:AST.expression_Statement):
	stmt.expression.visit(self)

func visit_unary(expr:AST.unary):
	expr.operand.visit(self)

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

func visit_for(stmt:AST.for_Statement):
	loop_depth += 1
	stmt.iter.visit(self) ; def_scope()
	def_variable(stmt.name)
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()

func visit_while(stmt:AST.while_Statement):
	loop_depth += 1 
	stmt.condition.visit(self) ; def_scope()
	for expression in stmt.body:expression.visit(self)
	loop_depth -= 1 ; leave_scope()

func visit_break(_stmt:AST.break_Statement):
	if loop_depth == 0: make_error(errors.loop % 'break')

func visit_continue(_stmt:AST.cont_Statement):
	if loop_depth == 0: make_error(errors.loop % 'continue') 

func visit_pass(_stmt:AST.pass_Statement): 
	pass

func visit_return(stmt:AST.return_Statement):
	var hint = lang_utilities.get_type_hint(current_fn.type_hint)
	var expr_exists = stmt.expression != null
	
	if hint == 'void':
		if expr_exists: make_error(errors.func % ['void', stmt.expression.visit(self)])
		return

	if !expr_exists: 
		if hint != '': make_error(errors.func % [hint, type_string(TYPE_NIL)])
		return

	var expr_type = stmt.expression.visit(self)
	if hint != '' and expr_type != hint:
		make_error(errors.func % [hint, expr_type])

func visit_header():
	if !shadows_declared(class_n): return
	make_error('class name "%s", shadows an internal class/variable' % class_n)

func visit_code():
	if class_n != '': visit_header()
	
	if !contains_data() || has_errors: return
	for expression in (globals + misc + functions):
		expression.visit(self) 
		#visit calls one of the cooresponding functions here


func pack_code():
	var packed:PackedStringArray = []
	
	if class_n == '': class_n = 's_%s' %  (globals + misc + functions).hash()
	class_n = class_n.substr(0,50) ; var class_st = 'class_name %s' % class_n
	packed.append(class_st)
	
	if !contains_data(): return '\n'.join(packed)
	for expression in (globals + misc + functions):
		packed.append(expression.get_code())
		#get_code redirects to AST_codegen
	return '\n'.join(packed)
