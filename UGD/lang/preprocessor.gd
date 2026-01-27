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
			var valid = program.declare_global_Var(_declaration.name,_declaration)
			if not valid:
				make_error('variant "%s" is already a declared constant variable in this context' % _declaration.name)
		elif check(tk_type.VAR):
			advance()
			var _declaration = parse_var_declaration()
			var valid = program.declare_global_Var(_declaration.name,_declaration)
			if not valid:
				make_error('variant "%s" is already a declared variable in this context' % _declaration.name)
			
		elif check(tk_type.FUNC): 
			parse_func_declaration()
		elif check(tk_type.NEWLINE):
			advance()
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
			params[expression.name] = expression
			
			if !check(tk_type.COMMA):
				break
			advance()
	consume(tk_type.PARENTHESIS_CLOSE, "expected ')' after parameters")
	
	
	if check(tk_type.FORWARD_ARROW):
		advance()
		_type = consume(tk_type.IDENTIFIER,'expected identifier after "->", got "%s"')
	consume(tk_type.COLON, "expected ':' after function declaration")
	skip_newlines()
	consume(tk_type.INDENT,'expected indent after function declaration')
	
	
	
	
	
	
	statement.type_hint = _type
	statement.params = params
	statement.name = _name.literal
	return statement






func parse_var_declaration(is_const:bool = false,expect_newline := true) -> AST.VarDeclStatement:
	var statement = AST.VarDeclStatement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 
	var _type = parse_var_type_hint()
	var _initializer = null
	
	if check(tk_type.EQUAL):
		advance()
		_initializer = parse_expression()
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
	#return the token that contains the supposed 'type' we need
	if check(tk_type.IDENTIFIER):
		var t := peek()
		advance()
		return t #here its 'int'
	elif check(tk_type.EQUAL):
		return peek(1) #here its 1
	else:
		make_error('expected/missing identifier after ":"')
		return null
	#this should allow for ':int' as well as ':= 1' as valid typing
	#awell as allowing custom types and certain exposed classes to be used
	#since the check for that should happen, after the preprocessor


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
	if current_token == null:
		return false
	return current_token.type == tk_type.TK_EOF






##expression stuff :p

#the entering/start function for the entire expression chain
func parse_expression():
	return parse_or_expression()

func parse_or_expression():
	var left =  parse_and_expression()
	while check(tk_type.OR):
		advance()
		var right = parse_and_expression()
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_OR,right)

	return left

func parse_and_expression():
	var left = parse_equality()
	while check(tk_type.AND):
		advance()
		var right = parse_equality()
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_AND,right)
	return left

func parse_equality():
	var left = parse_comparison()
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
		printt(preparser_lang.Operation.keys()[op],op_t.get_name())
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
	if check(tk_type.STAR,peek()) || check(tk_type.SLASH,peek()):
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
				while check(tk_type.COMMA):
					arg.push_back(parse_expression())
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
		var expr = parse_expression()
		consume(tk_type.PARENTHESIS_CLOSE,'expected closing parenthesis')
		return expr
	
	#ARRAY
	if check(tk_type.BRACKET_OPEN):
		make_error(global_error_types[0])
		return null
		#pass #while loop here
	
	#DICTIONARY
	if check(tk_type.BRACE_OPEN):
		make_error(global_error_types[0])
		#pass #ANOTHER while loop here
	
	
	
	make_error('pre-processor error, expected expression :/')
	return null
