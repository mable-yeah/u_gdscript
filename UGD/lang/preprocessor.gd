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
	1:'unrecognized token variant in pre-processor, "%s"'
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
func evaluate_program():
	while !is_at_end(): 
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
			make_error(global_error_types[0] % previous().get_name())
			skip_newlines() # // HEADER END
		
		#rest of this is body
		elif check(tk_type.ANNOTATION):
			advance()
			make_error(global_error_types[0] % previous().get_name())
		elif check(tk_type.TK_CONST): 
			advance()
			var _declaration = parse_var_declaration(true)
			if has_errors:
				break
			var valid = program.declare_global_Var(_declaration.name,_declaration)
			if not valid:
				make_error('variant "%s" is already a declared constant variable in this context' % _declaration.name)
		elif check(tk_type.VAR):
			advance()
			var _declaration = parse_var_declaration()
			if has_errors:
				break
			var valid = program.declare_global_Var(_declaration.name,_declaration)
			if not valid:
				make_error('variant "%s" is already a declared variable in this context' % _declaration.name)
			
		elif check(tk_type.FUNC): 
			var _declaration = parse_func_declaration()
			if has_errors:
				break
			var valid = program.declare_func(_declaration.name,_declaration)
			if not valid:
				make_error('function "%s" is already a declared variable in this context' % _declaration.name)
			
		if check(tk_type.INDENT):
			make_error('indent in class body')
		elif check(tk_type.NEWLINE):
			skip_newlines()
		else:
			advance()
		if has_errors:
			break
	#how to teleport tutorial working 2026







func skip_newlines():
	while check(tk_type.NEWLINE):
		consume(tk_type.NEWLINE,'expected newline')


func parse_func_declaration():
	advance()
	var statement = AST.funcDeclStatement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name')
	var _type = null
	var params:Dictionary[String,AST.Expr]
	
	#define parameters 
	consume(tk_type.PARENTHESIS_OPEN, "expected '(' after function name")
	if !check(tk_type.PARENTHESIS_CLOSE):
		while true:
			var expression = parse_var_declaration(false,false)
			if params.has(expression.name):
				make_error('Parameter "%s" was already declared for this function' % expression.name)
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

	statement.body = parse_func_scope()
	statement.type_hint = _type
	statement.params = params
	statement.name = _name.literal
	
	return statement


func parse_func_scope() -> Array:
	if has_errors:
		return []
	var lines = []
	while (!check(tk_type.DEDENT) and !is_at_end()):
		skip_newlines()
		if (!check(tk_type.DEDENT) and !is_at_end()):
			lines.push_back(parse_current_scope())
	consume(tk_type.DEDENT,'expected dedent after function body')
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
		pass
	
	if check(tk_type.FOR):
		pass
	
	if check(tk_type.RETURN):
		pass
	
	if check(tk_type.BREAK):
		advance()
		return AST.break_Statement.new()
	
	if check(tk_type.PASS):
		advance()
		return AST.pass_Statement.new()
	
	if check(tk_type.CONTINUE):
		advance()
		return AST.cont_Statement.new()

	make_error('unexpected token type "%s" in function body' % peek().get_name())
	advance()
	return null




func parse_if():
	advance()
	var expression = parse_expression()
	consume(tk_type.COLON,'expected ":" after if statement')
	skip_newlines()
	consume(tk_type.INDENT,'expected "indent" after if statement')
	
	if has_errors:
		return null
	
	var then_expr:Array[AST.Expr] = [parse_current_scope()]
	var else_expr:Array[AST.Expr] = []
	
	skip_newlines()
	if check(tk_type.ELIF):
		else_expr.push_back(parse_if())
	elif check(tk_type.ELSE):
		consume(tk_type.COLON,'expected ":" after else')
		skip_newlines()
		consume(tk_type.INDENT,'expected "indent" after if statement')
		else_expr.append(parse_current_scope())
	if has_errors:
		return null
	return AST.if_Statement.new(expression,then_expr,else_expr)



#starts after 'var' not at 'var', so advance/consume before calling this
func parse_var_declaration(is_const:bool = false,expect_newline := true) -> AST.VarDeclStatement:
	var statement = AST.VarDeclStatement.new()
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
func consume(type:tk_type,message:String):
	var p = peek()
	if check(type):
		advance()
		return p
	
	if message.contains('%s'):
		message = message % p.get_name()
	
	make_error(message)
	return p

##matches type, doesnt throw error if false
func check(type:tk_type,tk := peek()):
	#printerr(tk.get_name())
	if is_at_end() || tk == null: return false
	return tk.type == type

##generates an error and prints it to console
func make_error(st:String) -> void:
	printerr(st)
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
func parse_expression(can_assign:=true):
	return parse_or_expression(can_assign)

func parse_or_expression(can_assign):
	var left =  parse_and_expression(can_assign)
	while check(tk_type.OR):
		advance()
		var right = parse_and_expression(can_assign)
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_OR,right)

	return left

func parse_and_expression(can_assign):
	var left = parse_equality(can_assign)
	while check(tk_type.AND):
		advance()
		var right = parse_equality(can_assign)
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_AND,right)
	return left

func parse_equality(can_assign):
	var left = parse_comparison()
	if can_assign:
		while check(tk_type.EQUAL) || check(tk_type.BANG_EQUAL):
			var op_t = advance()
			var right = parse_comparison()
			
			var op = preparser_lang.Operation.OP_COMP_EQUAL \
			if check(tk_type.EQUAL,op_t) else preparser_lang.Operation.OP_COMP_NOT_EQUAL
			
			left = AST.Assignment.new(left,op,right)
	
	return left

func parse_comparison():
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
		
		
		left = AST.Assignment.new(left,op,right)
	
	return left

func parse_term():
	var left = parse_factor()
	while check(tk_type.PLUS) || check(tk_type.MINUS):
		var op_t = advance()
		var right = parse_factor()
		var op = preparser_lang.Operation.OP_ADDITION if check(tk_type.PLUS,op_t) else preparser_lang.Operation.OP_SUBTRACTION
		left = AST.Assignment.new(left,op,right)
	
	return left

func parse_factor():
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
		
		left = AST.Assignment.new(left,op,right)
	return left

func parse_unary():
	if check(tk_type.MINUS,peek()) || check(tk_type.NOT,peek()):
		var op_t = advance()
		var operand = parse_unary()
		var op = AST.Unary.Operation.OP_NEGATIVE if check(tk_type.MINUS,op_t) else AST.Unary.Operation.OP_NOT 
		return AST.Unary.new(operand,op)
		
	return parse_call()


func parse_call():
	var expr = parse_primary()
	while true:
		if check(tk_type.PARENTHESIS_OPEN):
			advance()
			var arg:Array[AST.Expr] = []
			if !check(tk_type.PARENTHESIS_CLOSE):
				while true:
					arg.push_back(parse_expression())
					if !check(tk_type.COMMA):
						break
					advance()
			consume(tk_type.PARENTHESIS_CLOSE,'expected closing parenthesis after arguments')
			#bruh we aint ever gon get this done girl :crying_emoji:
		else:
			break
	return expr

	




func parse_primary():
	#BUILT IN VALUES/ DIGITS, STRINGS
	if check(tk_type.LITERAL):
		var lit:AST.literalExpr
		match current_token.literal:
			'true':
				lit = AST.literalExpr.new(true)
			'false':
				lit = AST.literalExpr.new(false)
			'null':
				lit = AST.literalExpr.new(null)
			_:
				#digits/strings are inferred, the literal is already in the correct typing
				lit = AST.literalExpr.new(current_token.literal)
		advance()
		return lit
	
	#VARIABLE/OBJECT NAME
	if check(tk_type.IDENTIFIER):
		return AST.variableExpr.new(advance().literal)
	
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
			if check(tk_type.BRACKET_CLOSE):
				break
			var tk = parse_expression()
			if has_errors:
				return null
			expr.elements.append(tk)
			if !check(tk_type.COMMA):
				break
			advance()
		consume(tk_type.BRACKET_CLOSE,'expected closing bracket in array')
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
			skip_newlines()
			
			var key = parse_expression(false)
			if has_errors:
				return null
			
			expr.decide_style(check(tk_type.EQUAL),check(tk_type.COLON))
			if expr.style == style.NONE:
				return null
			
			check_token = tk_type.EQUAL if expr.style == style.PYTHON_DICT else tk_type.COLON
			
			if expr.style == style.LUA_TABLE:
				if key.type != preparser_lang.Type.IDENTIFIER and key.type != preparser_lang.Type.LITERAL:
					make_error('Expected identifier or string as Lua-style dictionary key, found %s' % preparser_lang.Type.keys()[key.type])
					return null
				key.reduced_value = key.name \
				if key.type == preparser_lang.Type.IDENTIFIER else \
				str(key.variant)
				print(key.reduced_value)
				#this all helps with grabbing proper key names inside of lua tables :p
				#however python styling doesnt follow these rules
			
			consume(check_token,'expected "%s" after dictionary key, mixing types is not allowed' %tk_type.keys()[check_token])
			
			var value = parse_expression()
			
			if has_errors:
				return null
			
			expr.elements[key] = value
			if !check(tk_type.COMMA):
				break
			advance()
		skip_newlines()
		consume(tk_type.BRACE_CLOSE,'expected closing brace in dictionary')
		return expr
	
	make_error('pre-processor error, expected expression :/, %s' % peek().get_name())
	return null
