class_name AST_visitor
##this class handles basic code generation 
##all AST expressions except the base class should contain an accept function that leads here
##in turn all of these functions should be static and return a string of theoretically formatted/usable code

const err = 'statement type "%s" doesnt have a valid visit function / returns null'



static func visit_var_decl(stmt:AST.varDecl_Statement,needs_body := true) -> String:
	var type_hint = lang_utilities.get_type_hint(stmt.type_hint)
	var initializer = '%s' % stmt.initializer.accept() if stmt.initializer != null else ''
	if !needs_body: return initializer
	
	var constant = 'const ' if stmt.is_constant else ''
	var value = ' = %s' % initializer if initializer != '' else ''
	if type_hint != '': value = ':%s%s' % [type_hint,value]
	return '%svar %s%s' %  [constant,stmt.name,value]

static func visit_func_decl(stmt:AST.funcDecl_Statement) -> String:
	var body:PackedStringArray = parse_body(stmt.body)
	var parameters:PackedStringArray
	for p_name in stmt.params:
		var value = stmt.params[p_name].accept(false)
		if value != '':
			p_name = '%s := %s' % [p_name,value]
		parameters.append(p_name)
	
	var colon = ':' if stmt.type_hint == null else ' -> %s:' % lang_utilities.get_type_hint(stmt.type_hint)
	return 'func %s(%s)%s%s' %[stmt.name,','.join(parameters),colon,join_body(body)]

static func visit_variable(expr:AST.variable) -> String:
	return str(expr.name)

static func visit_literal(expr:AST.literal) -> String: 
	match typeof(expr.variant):
		TYPE_NIL:
			expr.variant = 'null'
		TYPE_STRING:
			var st_wrapper = '"' if expr.variant.contains("'") else "'"
			expr.variant = '%s%s%s' % [st_wrapper,expr.variant,st_wrapper]
	return str(expr.variant)

static func visit_function_call(expr:AST.function_call) -> String:
	var packed = parse_body(expr.args)
	return '%s(%s)' % [expr.target.accept(),','.join(packed)]

static func visit_member_call(expr:AST.member_Call) -> String: 
	return '%s.%s' % [expr.target.accept(),expr.member.accept()]

static func visit_index(expr:AST.index) -> String:
	return '%s[%s]' % [expr.target.accept(),expr.idx.accept()]

static func visit_assignment(expr:AST.assignment) -> String:
	return '(%s %s %s)' % [expr.left.accept(),lang_utilities.get_op_st(expr.op),expr.right.accept()]

static func visit_expression(stmt:AST.expression_Statement) -> String:
	return stmt.expression.accept()

static func visit_unary(expr:AST.unary) -> String:
	var op = 'not ' if expr.op == loader_lang.Operation.OP_NOT else '!'
	return '%s%s' % [op,expr.operand.accept()]

static func visit_ternary(expr:AST.ternary) -> String: 
	return '%s if %s else %s' %[expr.target.accept(),expr.left.accept(),expr.right.accept()]

static func visit_array(expr:AST.array) -> String: 
	var packed:PackedStringArray
	for member in expr.elements:
		packed.append(member.accept())
	return '[%s]' % ','.join(packed)

static func visit_dictionary(expr:AST.dictionary) -> String:
	var dict:PackedStringArray = []
	var dict_ch = ':' if expr.style == expr.styling.LUA_TABLE else '='
	for element in expr.elements:
		dict.append('%s %s %s' % [element.accept(),dict_ch,expr.elements[element].accept()])
	return '{%s}' % ','.join(dict)

static func visit_enum(expr:AST.enumerator) -> String:
	var pairs:PackedStringArray = []
	for enumerator in expr.enumerators: 
		#enum values cannot be expressions or expr strings; so i dont need to .accept them :D
		var name = enumerator.keys()[0]
		var value = enumerator[name]
		pairs.append('%s = %s' % [name,value])
	return 'enum %s {%s}' % [expr.name,','.join(pairs)]

#technicawwy doing it this way causes elifs to decondense into if else but it SHOULDNT effect much
#since this is internal code
static func visit_if(stmt:AST.if_Statement) -> String: 
	var body = parse_body(stmt._then)
	var else_body = parse_body(stmt._else)
	var stmt_else = '\n\t/d else:%s' % join_body(else_body) if !stmt._else.is_empty() else ''
	return 'if %s:%s' % [stmt.condition.accept(),join_body(body)] + stmt_else

static func visit_for(stmt:AST.for_Statement) -> String: 
	var body = parse_body(stmt.body)
	return 'for %s in %s:%s' % [stmt.name,stmt.iter.accept(),join_body(body)]

static func visit_while(stmt:AST.while_Statement) -> String:
	var body = parse_body(stmt.body)
	return 'while %s:%s' % [stmt.condition.accept(),join_body(body)]

static func visit_break(_stmt:AST.break_Statement) -> String: 
	return 'break'

static func visit_continue(_stmt:AST.cont_Statement) -> String: 
	return 'continue'

static func visit_pass(_stmt:AST.pass_Statement) -> String: 
	return 'pass'

static func visit_return(stmt:AST.return_Statement) -> String:
	return 'return %s' % stmt.expression.accept() if stmt.expression != null else ''

##parses an array of expressions into a PackedStringArray
static func parse_body(body:Array[AST.Expr]) -> PackedStringArray:
	if body.is_empty():return []
	var body_packed:PackedStringArray
	for expression in body:
		var visit = expression.accept()
		if visit != null:
			body_packed.append(visit) ; continue
	return body_packed

##joins code lines into a format the body can use
static func join_body(body:PackedStringArray) -> String:
	for i in body.size():
		if !body[i].contains('\t'):continue
		body[i] = increase_tabs(body[i])
	return '\n\t%s' % '\n\t'.join(body)

##adds to previously generated indentation by one, handles exceptions with /d
static func increase_tabs(st:String) -> String:
	var lines:PackedStringArray = st.split('\n')
	for x in lines.size():
		var line:String = lines[x]
		
		if line.count('/d') > 0: #/d skips increasing indent when needed
			var t = line.count('\t')
			line = line.strip_edges()
			if line.begins_with('/d'):
				line = line.lstrip('/d').strip_edges()
				lines[x] = line.indent('\t'.repeat(t))
				continue
			line = line.indent('\t'.repeat(t))
		
		if line.count('\t') <= 0: continue
		lines[x] = line.indent('\t')
	return '\n'.join(lines)
