class_name ASTVisitor

static func visit_var_decl(stmt:AST.varDecl_Statement,needs_body := true):
	var initializer = '%s' % stmt.initializer.accept() if stmt.initializer != null else ''
	if !needs_body: return initializer
	
	var constant = 'const ' if stmt.is_constant else ''
	var value = '= %s' % initializer if initializer != '' else ''
	return '%svar %s %s' %  [constant,stmt.name,value]

static func visit_func_decl(stmt:AST.funcDecl_Statement):
	var body:PackedStringArray = parse_body(stmt.body)
	var parameters:PackedStringArray
	for p_name in stmt.params:
		var value = stmt.params[p_name].accept(false)
		if value != '':
			p_name = '%s := %s' % [p_name,value]
		parameters.append(p_name)
	return 'func %s(%s):%s' %[stmt.name,','.join(parameters),join_body(body)]

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

static func visit_if(stmt:AST.if_Statement): 
	var body = parse_body(stmt._then)
	var else_body = parse_body(stmt._else)
	var stmt_else = '\n\t/d else:%s' % join_body(else_body) if !stmt._else.is_empty() else ''
	return 'if %s:%s' % [stmt.condition.accept(),join_body(body)] + stmt_else

static func visit_for(stmt:AST.for_Statement): 
	var body = parse_body(stmt.body)
	return 'for %s in %s:%s' % [stmt.name,stmt.iter.accept(),join_body(body)]

static func visit_while(stmt:AST.while_Statement):
	var body = parse_body(stmt.body)
	return 'while %s:%s' % [stmt.condition.accept(),join_body(body)]

static func visit_break(_stmt:AST.break_Statement): 
	return 'break'

static func visit_continue(_stmt:AST.cont_Statement): 
	return 'continue'

static func visit_pass(_stmt:AST.pass_Statement): 
	return 'pass'

static func visit_return(stmt:AST.return_Statement):
	return 'return %s' % stmt.expression.accept() if stmt.expression != null else ''


static func parse_body(body:Array[AST.Expr]) -> PackedStringArray:
	const err = 'statement type "%s" doesnt have a valid visit function / returns null'
	if body.is_empty():return []
	var body_packed:PackedStringArray
	for expression in body:
		var visit = expression.accept()
		if visit != null:
			body_packed.append(visit) ; continue
		printerr(err % expression.get_type_name())
	return body_packed

static func join_body(body:PackedStringArray):
	for i in body.size():
		if !body[i].contains('\t'):continue
		body[i] = count_tabs(body[i])
	return '\n\t%s' % '\n\t'.join(body)

static func count_tabs(st:String):
	var lines:PackedStringArray = st.split('\n')
	for x in lines.size():
		var line:String = lines[x]
		
		if line.count('/d') > 0: #dedent skip a new indent if needed
			var t = line.count('\t')
			line = line.strip_edges().lstrip('/d').strip_edges()
			line = line.indent('\t'.repeat(t))
			lines[x] = line
			continue
		
		if line.count('\t') <= 0: continue
		lines[x] = line.indent('\t')
	return '\n'.join(lines)
