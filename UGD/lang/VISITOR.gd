class_name ASTVisitor

static func visit_var_decl(stmt:AST.varDecl_Statement):
	var constant = 'const ' if stmt.is_constant else ''
	var value = '= %s' % stmt.initializer.accept() if stmt.initializer != null else ''
	return '%svar %s %s' %  [constant,stmt.name,value]

static func visit_func_decl(stmt:AST.funcDecl_Statement): pass

static func visit_variable(expr:AST.variable):
	return str(expr.name)
	

static func visit_literal(expr:AST.literal): 
	if expr.variant is String:
		var st_wrapper = '"' if expr.variant.contains("'") else "'"
		expr.variant = '%s%s%s' % [st_wrapper,expr.variant,st_wrapper]
	return str(expr.variant)

static func visit_function_call(expr:AST.function_call):
	var packed = parse_body(expr.args)
	return '%s(%s)' % [expr.target.accept(),','.join(packed)]

static func visit_member_call(expr:AST.member_Call): 
	return '%s.%s' % [expr.target.accept(),expr.member.accept()]

static func visit_index(expr:AST.index):
	return '%s[%s]' % [expr.target.accept(),expr.idx.accept()]

static func visit_assignment(expr:AST.assignment):
	return '(%s %s %s)' % [expr.left.accept(),lang_utilities.get_op_st(expr.op),expr.right.accept()]

static func visit_expression(stmt:AST.expression_Statement):
	return stmt.expression.accept()

static func visit_unary(expr:AST.unary):
	var op = 'not ' if expr.op == loader_lang.Operation.OP_NOT else '!'
	return '%s%s' % [op,expr.operand.accept()]

static func visit_ternary(expr:AST.ternary): 
	return '%s if %s else %s' %[expr.target.accept(),expr.left.accept(),expr.right.accept()]

static func visit_array(expr:AST.array): 
	var packed:PackedStringArray
	for member in expr.elements:
		packed.append(member.accept())
	return '[%s]' % ','.join(packed)

static func visit_dictionary(expr:AST.dictionary): pass

static func visit_enum(expr:AST.enumerator): pass

static func visit_if(stmt:AST.if_Statement): pass

static func visit_for(stmt:AST.for_Statement): pass

static func visit_while(stmt:AST.while_Statement): pass

static func visit_break(stmt:AST.break_Statement): 
	return 'break'

static func visit_continue(stmt:AST.cont_Statement): 
	return 'continue'

static func visit_pass(stmt:AST.pass_Statement): 
	return 'pass'

static func visit_return(stmt:AST.return_Statement):
	return 'return %s' % stmt.expression.accept() if stmt.expression != null else ''


static func parse_body(body:Array[AST.Expr]) -> PackedStringArray:
	var body_packed:PackedStringArray
	for expression in body:
		body_packed.append(expression.accept())
	return body_packed
