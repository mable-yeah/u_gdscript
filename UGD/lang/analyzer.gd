class_name analyzer ##analyzes the current program's AST and validates/invalidates it

var has_errors := false
var program:AST.PROGRAM
var expr := Expression.new()

func _init(p_program:AST.PROGRAM) -> void:
	program = p_program
	analyze()

func analyze():
	validate_header()
	if has_errors:return
	if !program.contains_data():return
	
	for variant in program.globals:
		parse_expression(variant)





#gets string from type hint token
func get_type_hint(tk:TOKENS.token) -> String:
	if tk == null:return ""
	const types = TOKENS.type
	match tk.type:
		types.TK_VOID:
			return 'void'
		types.IDENTIFIER:
			return tk.literal
	make_error('could not determine type from token %s' % tk.get_name())
	return ""
	



func validate_header():
	if !program.has_class_or_extends:return
	if program.class_n != "" and lang_utilities.is_class_or_type(program.class_n):
		make_error('class name reflects a built in type/class: "%s"' %program.class_n) ; return
	


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Analyzer error: \' %s \''
	printerr(generic % st)
	return

#not conchas; concha a big bag with one concha in it 
func parse_expression(expression:AST.Expr):
	if expression == null: #should never happen ideally
		make_error('expression is null in parse expression')
		return
	
	if expression is AST.funcDecl_Statement:
		pass
	elif expression is AST.varDecl_Statement:
		if expression.initializer != null:
			expression.reduced_value = parse_expression(expression.initializer)
	elif expression is AST.pass_Statement:
		pass
	elif expression is AST.cont_Statement:
		pass
	elif expression is AST.break_Statement:
		pass
	elif expression is AST.binary_Statement:
		pass
	elif expression is AST.assign_Statement:
		pass
	elif expression is AST.expression_Statement:
		pass
	elif expression is AST.return_Statement:
		pass
	elif expression is AST.for_Statement:
		pass
	elif expression is AST.while_Statement:
		pass
	elif expression is AST.if_Statement:
		pass
	elif expression is AST.variable:
		return 0 #placeholder
	elif expression is AST.literal:
		return expression.variant
	elif expression is AST.member_Call:
		pass
	elif expression is AST._call:
		pass
	elif expression is AST._enum:
		pass
	elif expression is AST.index:
		pass
	elif expression is AST.assignment: # this handles 1 + (2 + 1000) n shi
		var left = parse_expression(expression.left)
		var right = parse_expression(expression.right)
		var expr_st = '%s %s %s' % [left,loader_lang.Operation_String[expression.op],right]
		var parse = expr.parse(expr_st)
		if parse != OK:
			make_error("%s, %s" % [expr.get_error_text(),expr_st])
		return  expr.execute()
	elif expression is AST.unary:
		pass
	elif expression is AST.array:
		pass
	elif expression is AST.dictionary:
		pass
	elif expression is AST.ternary:
		pass
	else:
		var err_st = 'expression not found in the expression chain %s' % expression.get_type_name()
		make_error(err_st)
