class_name preprocessor


var tk_arr:Array[tokens.token] = []
var length:int:
	get():
		return tk_arr.size()


var cursor := 0
var current_token:tokens.token = null

var annotations = []

#whenever an error has multiple locations it can be used, define it here pls
#else just typing in the error is fine lol
var global_error_types = {
	0:'disallowed expression in UGD, "%s"',
	1:'disallowed expression in the current scope %s',
	
}


var errors = []

var has_errors:bool:
	get():
		return !errors.is_empty()


const tk_type = tokens.type
var program := AST.PROGRAM.new()


func _init(p_tk:Array[tokens.token]) -> void:
	tk_arr = p_tk
	evaluate_program()

#the parser reads top to bottom, so ordering is slightly important!!
func evaluate_program() -> void:
	while !is_at_end(): 
		if check(tk_type.INDENT):
			printerr('indent in class body')
			advance()
		
		
		if (check(tk_type.CLASS_NAME) || check(tk_type.EXTENDS)) and program.contains_data():
			make_error('header %s defined after class functions/variables' % peek().get_name())
		
		if check(tk_type.CLASS_NAME): # // HEADER BEGIN
			advance()
			var c_tk = consume(tk_type.IDENTIFIER,'expected identifier / class name after class_name not "%s"')
			if has_errors:
				continue
			if program.class_n == "":
				program.class_n = c_tk.literal
				continue
			make_error('class name is already defined as "%s" in this context' %[program.class_n])
		if check(tk_type.EXTENDS):
			advance()
			var c_tk = consume(tk_type.IDENTIFIER,'expected identifier / class name after class_name not "%s"')
			if has_errors:
				continue
			if program.extends_n == "":
				program.extends_n = c_tk.literal
				continue
			make_error('class extention is already defined as "%s" in this context' %[program.extends_n])
		
		#rest of this is body
		elif check(tk_type.ANNOTATION):
			make_error(global_error_types[0] % peek().get_name())
			advance()
		elif check(tk_type.ENUM):
			var _declaration = parse_enum_declaration()
		elif check(tk_type.TK_CONST):
			advance()
			var _declaration = parse_var_declaration(true)
			if has_errors:
				break
			program.globals.push_back(_declaration)
		elif check(tk_type.VAR):
			advance()
			var _declaration = parse_var_declaration()
			if has_errors:
				break
			program.globals.push_back(_declaration)
			
		elif check(tk_type.FUNC): 
			var _declaration = parse_func_declaration()
			if has_errors:
				break
			program.functions.push_back(_declaration)
		elif check(tk_type.NEWLINE):
			skip_newlines()
		else:
			#make_error(global_error_types[0] % peek().get_name())
			advance()
		if has_errors:
			break
	#how to teleport tutorial working 2026


func skip_newlines(ignore_indents := false):
	if !ignore_indents:
		while check(tk_type.NEWLINE):
			advance()
	else: 
		while check(tk_type.NEWLINE) || check(tk_type.INDENT) || check(tk_type.DEDENT):
			advance()

func parse_enum_declaration():
	advance()
	var _name = consume(tk_type.IDENTIFIER,'expected enum name, got %s')
	consume(tk_type.BRACE_OPEN,'expected { after enum name')
	while true:
		skip_newlines(true)
		consume(tk_type.IDENTIFIER,'expected identifier in enum, got %s')
		if check(tk_type.EQUAL):
			advance()
			if check(tk_type.LITERAL): #foo = 2
				if peek().literal is int: advance()
				else:
					make_error('Enum values must be integers, got %s instead' % type_string(typeof(peek().literal)))
			elif check(tk_type.IDENTIFIER): #foo = bar (bar representing const of 2)
				advance()
			else:
				make_error('expected IDENTIFIER or LITERAL (type int), got %s')
		
		if !check(tk_type.COMMA):
			skip_newlines(true)
			break
		advance()
		skip_newlines(true)
	consume(tk_type.BRACE_CLOSE,'expected closing } after enum, got %s')
	return


const yep := 2
enum foo {
	bar = yep
}




func parse_func_declaration() -> AST.funcDecl_Statement:
	advance()
	var statement = AST.funcDecl_Statement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name')
	var _type = null
	var params:Dictionary[String,AST.Expr]
	
	#define parameters 
	consume(tk_type.PARENTHESIS_OPEN, "expected '(' after function name")
	if !check(tk_type.PARENTHESIS_CLOSE):
		while true:
			var expression = parse_var_declaration(false,false)
			if params.has(expression.name):
				make_error('parameter "%s" was already declared for this function' % expression.name)
				break
			if expression == null:
				make_error('null as expression :/')
				break
			
			params[expression.name] = expression
			
			if !check(tk_type.COMMA):
				break
			advance()
	consume(tk_type.PARENTHESIS_CLOSE, "expected ')' after parameters")
	
	
	if check(tk_type.FORWARD_ARROW):
		advance()
		if check(tk_type.IDENTIFIER) || check(tk_type.TK_VOID):
			_type = advance()
		else:
			make_error('expected identifier or void after "->", got "%s"' % peek())
		
	consume(tk_type.COLON,'expected ":" after function declaration, got "%s"')
	skip_newlines()
	consume(tk_type.INDENT,'expected indent after function declaration')

	statement.body = parse_scope_block()
	statement.type_hint = _type
	statement.params = params
	statement.name = _name.literal
	
	return statement


func parse_scope_block() -> Array[AST.Expr]:
	if has_errors:
		return []
	var lines:Array[AST.Expr] = []
	while (!check(tk_type.DEDENT) and !is_at_end()):
		skip_newlines()
		if (!check(tk_type.DEDENT) and !is_at_end()):
			lines.push_back(parse_current_scope())
			if has_errors:
				return []
	
	consume(tk_type.DEDENT,'expected dedent after scope body')
	return lines

func parse_current_scope():
	skip_newlines()
	
	if check(tk_type.VAR) || check(tk_type.TK_CONST):
		var is_const = check(tk_type.TK_CONST)
		advance()
		return parse_var_declaration(is_const)
	
	if check(tk_type.IF):
		return parse_if()
	
	if check(tk_type.WHILE):
		return parse_while()
	
	if check(tk_type.FOR):
		return parse_for()
	
	if check(tk_type.RETURN):
		return parse_return()
	
	if check(tk_type.BREAK):
		advance()
		return AST.break_Statement.new()
	
	if check(tk_type.PASS):
		advance()
		return AST.pass_Statement.new()
	
	if check(tk_type.CONTINUE):
		advance()
		return AST.cont_Statement.new()
	
	return parse_assignment()

func parse_assignment():
	var _p_cursor = cursor
	var _left = parse_call()
	if has_errors:
		return null
	var name = null
	
	if _left is AST.member_Call:
		name = _left.target.get('name')
	else:
		name = _left.get('name')
	
	if check(tk_type.EQUAL): #property = value
		advance()
		var _right = parse_expression()
		
		consume(tk_type.NEWLINE,'expected newline after assignment, got %s instead')
		
		if name != null and name != '':
			return AST.assign_Statement.new(name,_right)
		else:
			return AST.assign_Statement.new(_left,_right)
	
	
	if name != null and name != '':
		if check(tk_type.STAR_EQUAL) || check(tk_type.SLASH_EQUAL) \
		|| check(tk_type.PLUS_EQUAL) || check(tk_type.MINUS_EQUAL): #property 'operation_equals' value
			var ref = AST.variable.new(name)
			var op_tk = advance()
			var _right = parse_expression()
			consume(tk_type.NEWLINE,'expected newline after op assignment')

			var op:preparser_lang.Operation
			if check(tk_type.PLUS_EQUAL,op_tk) || check(tk_type.MINUS_EQUAL,op_tk):
				op = preparser_lang.Operation.OP_ADDITION if check(tk_type.PLUS_EQUAL,op_tk) else preparser_lang.Operation.OP_SUBTRACTION
			elif check(tk_type.STAR_EQUAL,op_tk) || check(tk_type.SLASH_EQUAL,op_tk):
				op = preparser_lang.Operation.OP_MULTIPLICATION if check(tk_type.STAR_EQUAL,op_tk) else preparser_lang.Operation.OP_DIVISION
			
			var _expr = AST.binary_Statement.new(ref,op,_right)
			
			return AST.assign_Statement.new(name,_expr)
		
	
	consume(tk_type.NEWLINE,'expected newline after expression, got %s')
	return AST.expression_Statement.new(_left)
	



func parse_return():
	advance()
	var return_value = null
	if !check(tk_type.NEWLINE):
		return_value = parse_expression()
	#return is the only one that doesnt consume a dedent after parsing
	#its not expected to dedent immediatley after making a function return
	return AST.return_Statement.new(return_value)

func parse_for():
	advance()
	
	var name_tk = consume(tk_type.IDENTIFIER,'expected loop iterator name after "for", got %s')
	
	
	consume(tk_type.TK_IN,'expected "in" after iterator name')
	var iter = parse_expression()
	
	consume(tk_type.COLON,'expected ":" after for statement')
	skip_newlines()
	consume(tk_type.INDENT,'expected "indent" after for statement')
	
	if has_errors:
		return null
	
	var body = parse_scope_block()
	return AST.for_Statement.new(name_tk.literal,body,iter)



func parse_while():
	advance()
	var expression = parse_expression()
	consume(tk_type.COLON,'expected ":" after while statement')
	skip_newlines()
	consume(tk_type.INDENT,'expected "indent" after if statement')
	
	if has_errors:
		return null
	
	var body = parse_scope_block()
	return AST.while_Statement.new(expression,body)

func parse_if():
	advance()
	var expression = parse_expression()
	consume(tk_type.COLON,'expected ":" after if statement')
	skip_newlines()
	consume(tk_type.INDENT,'expected "indent" after if statement')
	
	if has_errors:
		return null
	
	var then_expr:Array[AST.Expr] = parse_scope_block()
	var else_expr:Array[AST.Expr] = []
	
	skip_newlines()
	if check(tk_type.ELIF):
		else_expr.push_back(parse_if())
	elif check(tk_type.ELSE):
		consume(tk_type.COLON,'expected ":" after else')
		skip_newlines()
		consume(tk_type.INDENT,'expected "indent" after if statement')
		else_expr = parse_scope_block()
	if has_errors:
		return null
	return AST.if_Statement.new(expression,then_expr,else_expr)




#starts after 'var' not at 'var', so advance/consume before calling this
func parse_var_declaration(is_const:bool = false,expect_newline := true) -> AST.varDecl_Statement:
	var statement = AST.varDecl_Statement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 
	var _type = parse_var_type_hint()
	if has_errors:
		return statement
	var _initializer = null
	
	if check(tk_type.EQUAL):
		advance()
		
		_initializer = parse_expression()
		if has_errors:
			return statement
	elif is_const:
		make_error('expected initializer after constant name')
	
	if expect_newline:
		if check(tk_type.COLON):
			#if get set WERE supported parse it here
			make_error('colon found after variable declaration "%s", get()/set() is unsupported' % _name.literal)
		else:
			consume(tk_type.NEWLINE,'expected newline after variable declaration, found %s') 
	
	statement.name = _name.literal
	statement.type_hint = _type
	statement.initializer = _initializer
	statement.is_constant = is_const
	
	return statement

##return identifier token containing the 'type' needed, else null
func parse_var_type_hint() -> tokens.token:
	if not check(tk_type.COLON):
		return
	advance()
	#return the token that contains the supposed 'type' we need.. or null
	if check(tk_type.IDENTIFIER):
		var t := peek()
		advance()
		return t 
	elif check(tk_type.EQUAL):
		return null 
		#return null silently, get it filled by the parsed expression's final type later on
	else:
		make_error('expected/missing type identifier after ":", found %s' %peek().get_name())
		return null


##advances the parser if the type matches, else error
func consume(type:tk_type,message:String) -> tokens.token:
	var p = peek()
	if check(type):
		advance()
		return p
	
	if message.contains('%s'):
		message = message % p.get_name()
	
	make_error(message)
	return p

##matches type, doesnt throw error if false
func check(type:tk_type,tk := peek()) -> bool:
	#printerr(tk.get_name())
	if is_at_end() || tk == null: return false
	return tk.type == type

##generates an error and prints it to console
func make_error(st:String) -> void:
	var generic = 'Pre-processor error: \' %s \''
	printerr(generic % st)
	errors.push_back(st)
	return 


func previous() -> tokens.token:
	return tk_arr.get(cursor - 1)


func peek(peek_dist = 0) -> tokens.token:
	if cursor >= length:
		return null
	return tk_arr.get(cursor + peek_dist)

func advance() -> tokens.token:
	var previous_token = peek() #required for expressions
	if is_at_end():
		return
	cursor += 1
	current_token = peek()
	return previous_token


func is_at_end() -> bool:
	return peek() == null or peek().type == tk_type.TK_EOF






##expression stuff :p

##the entering/start function for the entire expression chain
func parse_expression(can_assign:=true) -> AST.Expr:
	return parse_ternary_expression(can_assign)


func parse_ternary_expression(can_assign) -> AST.Expr:
	var left = parse_or_expression(can_assign)
	if check(tk_type.IF):
		advance()
		var expr = parse_expression(true)
		
		#not too sure if doing this is good or not but it hasn't generated any errors yet
		consume(tk_type.ELSE, 'expected "else" in ternary expression, got %s')
		if has_errors:
			return null
		
		var right = parse_ternary_expression(can_assign)
		return AST.ternary.new(left, expr, right)
	return left



func parse_or_expression(can_assign) -> AST.Expr:
	var left = parse_and_expression(can_assign)
	while check(tk_type.OR) || check(tk_type.PIPE_PIPE):
		advance()
		var right = parse_and_expression(can_assign)
		left = AST.assignment.new(left,preparser_lang.Operation.OP_BIT_OR,right)

	return left

func parse_and_expression(can_assign) -> AST.Expr:
	var left = parse_equality(can_assign)
	while check(tk_type.AND):
		advance()
		var right = parse_equality(can_assign)
		left = AST.assignment.new(left,preparser_lang.Operation.OP_BIT_AND,right)
	return left

func parse_equality(can_assign) -> AST.Expr:
	var left = parse_comparison()
	if can_assign:
		while check(tk_type.EQUAL_EQUAL) || check(tk_type.BANG_EQUAL):
			var op_t = advance()
			var right = parse_comparison()
			
			var op = preparser_lang.Operation.OP_COMP_EQUAL \
			if check(tk_type.EQUAL_EQUAL,op_t) else preparser_lang.Operation.OP_COMP_NOT_EQUAL
			
			left = AST.assignment.new(left,op,right)
	
	return left

func parse_comparison() -> AST.Expr:
	var left = parse_term()
	
	while check(tk_type.LESS) || check(tk_type.LESS_EQUAL) || \
	check(tk_type.GREATER) || check(tk_type.GREATER_EQUAL):
		var op_t = advance()
		var right = parse_term()
		var op
		match op_t.type:
			tk_type.LESS_EQUAL:
				op = preparser_lang.Operation.OP_COMP_LESS_EQUAL
			tk_type.LESS:
				op = preparser_lang.Operation.OP_COMP_LESS
			tk_type.GREATER:
				op = preparser_lang.Operation.OP_COMP_GREATER
			tk_type.GREATER_EQUAL:
				op = preparser_lang.Operation.OP_COMP_GREATER_EQUAL
			_:
				make_error('couldnt match operation :/ %s' % op_t.get_name())
				op = preparser_lang.Operation.OP_COMP_LESS
		
		
		left = AST.assignment.new(left,op,right)
	
	return left

func parse_term() -> AST.Expr:
	var left = parse_factor()
	while check(tk_type.PLUS) || check(tk_type.MINUS):
		var op_t = advance()
		var right = parse_factor()
		var op = preparser_lang.Operation.OP_ADDITION if check(tk_type.PLUS,op_t) else preparser_lang.Operation.OP_SUBTRACTION
		left = AST.assignment.new(left,op,right)
	
	return left

func parse_factor() -> AST.Expr:
	var left = parse_unary()
	while check(tk_type.STAR) || check(tk_type.SLASH) || check(tk_type.PERCENT):
		var op_t = advance()
		var right = parse_unary()
		var op
		
		match op_t.type:
			tk_type.STAR:
				op = preparser_lang.Operation.OP_MULTIPLICATION
			tk_type.SLASH:
				op = preparser_lang.Operation.OP_DIVISION
			tk_type.PERCENT:
				op = preparser_lang.Operation.OP_MODULO
			_:
				make_error('couldnt match operation :/ %s' % op_t.get_name())
				op = preparser_lang.Operation.OP_MODULO
		left = AST.assignment.new(left,op,right)
	return left

func parse_unary() -> AST.Expr:
	if check(tk_type.MINUS,peek()) || check(tk_type.NOT,peek()):
		var op_t = advance()
		var operand = parse_unary()
		var op = AST.unary.Operation.OP_NEGATIVE if check(tk_type.MINUS,op_t) else AST.unary.Operation.OP_NOT 
		return AST.unary.new(operand,op)
	return parse_call()


func parse_call() -> AST.Expr:
	var expr = parse_primary()
	while true:
		if check(tk_type.PARENTHESIS_OPEN): #(arg1,arg2)
			advance()
			var arg:Array[AST.Expr] = []
			if !check(tk_type.PARENTHESIS_CLOSE):
				while true:
					skip_newlines(true)
					arg.push_back(parse_expression())
					if !check(tk_type.COMMA):
						skip_newlines(true)
						break
					advance()
			consume(tk_type.PARENTHESIS_CLOSE,'expected closing parenthesis after arguments, got %s instead')
			var func_name = expr.get('name')
			if func_name != null:
				return AST._call.new(func_name,arg)
			make_error('invalid call to type of "%s"' % expr.get_type_name())
		
		elif check(tk_type.BRACKET_OPEN): #arr[0]
			advance()
			var ind = parse_expression()
			consume(tk_type.BRACKET_CLOSE,'expected closing bracket')
			return AST.index.new(expr,ind)
		
		elif check(tk_type.PERIOD): #.property
			advance()
			var arg:Array[AST.Expr] = []
			
			if check(tk_type.IDENTIFIER): #add property to array
				arg.push_back(parse_expression(false))
			
			if check(tk_type.PERIOD): #if property is '.property.value()' continue chain
				advance()
				arg.push_back(parse_expression())
				
			
			if check(tk_type.PARENTHESIS_OPEN): #+ parameters
				advance()
				if !check(tk_type.PARENTHESIS_CLOSE):
					while true:
						arg.push_back(parse_expression())
						if !check(tk_type.COMMA):
							break
						advance()
				consume(tk_type.PARENTHESIS_CLOSE,'expected closing parenthesis after "." property arguments')

			
			return AST.member_Call.new(expr,arg)
		else:
			break
	
	return expr

func parse_primary() -> AST.Expr:
	if check(tk_type.SELF):
		advance()
		return AST.literal.new('self')

	#BUILT IN VALUES/ DIGITS, STRINGS
	if check(tk_type.LITERAL):
		var lit:AST.literal
		match current_token.literal:
			'true':
				lit = AST.literal.new(true)
			'false':
				lit = AST.literal.new(false)
			'null':
				lit = AST.literal.new(null)
			_:
				#digits/strings are inferred, the literal is already in the correct typing
				lit = AST.literal.new(current_token.literal)
		advance()
		return lit
	
	#VARIABLE/OBJECT NAME
	if check(tk_type.IDENTIFIER):
		return AST.variable.new(advance().literal)
	
	if check(tk_type.PARENTHESIS_OPEN):
		advance()
		var expr = parse_expression()
		consume(tk_type.PARENTHESIS_CLOSE,'expected closing parenthesis')
		return expr
	
	#ARRAY
	if check(tk_type.BRACKET_OPEN):
		var expr = AST.array.new()
		advance()
		if check(tk_type.BRACKET_CLOSE): #empty array
			advance()
			return expr
		
		while true:
			skip_newlines(true)
			if check(tk_type.BRACKET_CLOSE):
				break
			var tk = parse_expression()
			if has_errors:
				return null
			expr.elements.append(tk)
			if !check(tk_type.COMMA):
				skip_newlines(true)
				break
			advance()
		consume(tk_type.BRACKET_CLOSE,'expected closing bracket in array, got %s')
		return expr
	
	#DICTIONARY
	if check(tk_type.BRACE_OPEN):
		var style = AST.dictionary.styling
		var expr = AST.dictionary.new()
		var check_token = null
		advance()
		if check(tk_type.BRACE_CLOSE): #empty dict
			advance()
			return expr
		
		while true:
			skip_newlines(true)
			
			var key = parse_expression(false)
			if has_errors:
				return null
			
			expr.decide_style(check(tk_type.EQUAL),check(tk_type.COLON))
			if expr.style == style.NONE:
				return null
			
			check_token = tk_type.EQUAL if expr.style == style.PYTHON_DICT else tk_type.COLON
			
			if expr.style == style.LUA_TABLE:
				if key.type != preparser_lang.Type.IDENTIFIER and key.type != preparser_lang.Type.LITERAL:
					make_error('expected identifier or string as Lua-style dictionary key, got %s' % expr.get_type_name())
					return null
				key.reduced_value = key.name \
				if key.type == preparser_lang.Type.IDENTIFIER else \
				str(key.variant)
				#print(key.reduced_value)
				#this all helps with grabbing proper key names inside of lua tables :p
				#however python styling doesnt follow these rules
			
			consume(check_token,'expected "%s" after dictionary key, mixing types is not allowed' %tk_type.keys()[check_token])
			
			var value = parse_expression()
			
			if has_errors:
				return null
			
			expr.elements[key] = value
			if !check(tk_type.COMMA):
				skip_newlines(true)
				break
			advance()
		skip_newlines(true)
		consume(tk_type.BRACE_CLOSE,'expected closing brace in dictionary, got %s')
		return expr
	

	make_error('pre-processor error, expected expression :/, got %s ' % peek().get_name())
	return null
