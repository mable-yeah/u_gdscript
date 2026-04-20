class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script


const errors = {
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"'
}

var loop_depth = 0
var scope:Array[Dictionary] = [{}]
var current_scope_idx:int = 0
var current_scope:Dictionary:
	get(): return scope.get(current_scope_idx)


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

func def_variable(name:String,type := 'variant'):
	if shadows_declared(name): make_error(errors.shadows % [type,name])
	current_scope[name] = false

func shadows_declared(name:String) -> bool:
	var declared = is_declared(name)
	if lang_utilities.is_class_or_type(name): return true
	return declared

func is_declared(name:String) -> bool:
	for i in range(current_scope_idx, -1, -1):
		if scope[i].has(name): return true
	return false

func is_assignable(expr) -> bool:
	return expr is AST.variable or expr is AST.member_Call or expr is AST.index


func visit_var_decl(stmt:AST.varDecl_Statement):
	if stmt.initializer != null: stmt.initializer.visit(self) #process init first
	elif stmt.is_constant: make_error('constants need initializers "%s"' % stmt.name) ; return
	
	def_variable(stmt.name)


func visit_func_decl(stmt:AST.funcDecl_Statement):
	def_variable(stmt.name,'function') ; def_scope()
	
	for param in stmt.params.values():param.visit(self) 
	for expression in stmt.body:expression.visit(self)
	
	leave_scope()

func visit_enum(expr:AST.enumerator):
	def_variable(expr.name,'enum')
	var enums = {}
	for num in expr.enumerators:
		var name = num.keys()[0]
		if (name not in enums): enums[name] = false ; continue
		make_error('name "%s" was already inside of enum "%s"' % [name,expr.name])

func visit_variable(expr:AST.variable):
	if is_declared(expr.name): return 
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)

func visit_literal(_expr:AST.literal): #literals contain no embedded expr's
	pass 

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
	if expr.op == loader_lang.Operation.OP_COMP_EQUAL:
		return
	
	if !is_assignable(expr.left):
		make_error(errors.assign %[expr.left._tk_st,expr.right._tk_st])
	
	expr.left.visit(self) ; expr.right.visit(self)

func visit_expression(stmt:AST.expression_Statement):
	stmt.expression.visit(self)

func visit_unary(expr:AST.unary):
	expr.operand.visit(self)

func visit_ternary(expr:AST.ternary):
	expr.target.visit(self) 
	expr.left.visit(self) 
	expr.right.visit(self) 

func visit_array(expr:AST.array):
	for element in expr.elements:
		element.visit(self) 

func visit_dictionary(expr:AST.dictionary):
	for element in expr.elements.values():
		element.visit(self)

func visit_if(stmt:AST.if_Statement):
	stmt.condition.visit(self) 
	def_scope()
	for expression in stmt._then:expression.visit(self)
	leave_scope()
	
	if stmt._else.is_empty(): return 
	
	def_scope()
	for expression in stmt._else:expression.visit(self)
	leave_scope()

func visit_for(stmt:AST.for_Statement):
	loop_depth += 1 ; 
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
	if stmt.expression != null: stmt.expression.visit(self)

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
	
	if class_n == '': class_n = 's_%s' %  (functions.hash() + randi()) 
	class_n = class_n.substr(0,50) ; var class_st = 'class_name %s' % class_n
	packed.append(class_st)
	
	if !contains_data(): return '\n'.join(packed)
	for expression in globals + misc + functions:
		packed.append(expression.get_code())
		#get_code redirects to AST_codegen
	return '\n'.join(packed)
