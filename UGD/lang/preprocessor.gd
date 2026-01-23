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
			consume(tk_type.IDENTIFIER,'expected identifier / class name after class_name')
		if check(tk_type.EXTENDS):
			advance()
			consume(tk_type.IDENTIFIER,'expected identifier / valid class name after extends')
			skip_newlines() # // HEADER END
		
		#rest of this is body
		elif check(tk_type.ANNOTATION):
			advance()
			make_error(global_error_types[0] % current_token.get_name())
		elif check(tk_type.TK_CONST): 
			advance()
			var _declaration = parse_var_declaration(true)
		elif check(tk_type.VAR):
			advance()
			var _declaration = parse_var_declaration()
		elif check(tk_type.FUNC): 
			#this should send the parser into a 'sub mode' where statements are validated
			parse_func_declaration()
		elif check(tk_type.NEWLINE):
			advance()
		else:
			if current_token != null:
				printerr(current_token.get_name())
			advance()
		if has_errors:
			break
	#how to teleport tutorial working 2026







func skip_newlines():
	while check(tk_type.NEWLINE):
		consume(tk_type.NEWLINE,'expected newline')


func parse_func_declaration():
	advance()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 



func parse_var_declaration(is_const:bool = false) -> AST.VarDeclStatement:
	var statement = AST.VarDeclStatement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 
	var _type = parse_type_hint()
	var _initializer = null
	if check(tk_type.EQUAL):
		advance()
		_initializer = consume(tk_type.LITERAL,'expected expression for initalizer after =')
	elif is_const:
		make_error('expected initializer after constant name')
	consume(tk_type.NEWLINE,'expected newline after variable declaration, found %s') 
	
	
	statement.name = _name.literal
	statement.type_hint = _type
	statement.initializer = _initializer
	statement.is_constant = is_const
	
	return statement



##return identifier token containing the 'type' needed, else null
func parse_type_hint() -> tokens.token:
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
	if is_at_end() || tk == null: return false
	return tk.type == type

##generates an error and prints it to console
func make_error(st:String) -> void:
	printerr(st)
	errors.push_back(st)
	return 


func previous() -> tokens.token:
	return tk_arr.get(cursor - 1)


func peek(peel_dist = 0) -> tokens.token:
	if cursor >= length:
		return null
	return tk_arr.get(cursor + peel_dist)

func advance() -> tokens.token:
	if is_at_end():
		return
	cursor += 1
	current_token = peek()
	return current_token


func is_at_end() -> bool:
	if current_token == null:
		return false
	return current_token.type == tk_type.TK_EOF






##expression stuff :p

func parse_expression():
	return parse_or_expression()

func parse_or_expression():
	var left =  parse_and_expression()
	while check(tk_type.OR):
		var right = parse_and_expression()
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_OR,right)
	
	return left

func parse_and_expression():
	var left = parse_equality()
	while check(tk_type.AND):
		var right = parse_equality()
		left = AST.Assignment.new(left,preparser_lang.Operation.OP_BIT_AND,right)
	return left

func parse_equality():
	var left = parse_comparison()
	while check(tk_type.EQUAL) || check(tk_type.BANG_EQUAL):
		var right = parse_comparison()
		
		var op = preparser_lang.Operation.OP_COMP_EQUAL \
		if check(tk_type.EQUAL) else preparser_lang.Operation.OP_COMP_NOT_EQUAL
		
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
		var right = parse_factor()
		var op = preparser_lang.Operation.OP_ADDITION if check(tk_type.PLUS) else preparser_lang.Operation.OP_SUBTRACTION
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
		var op = AST.Unary.Operation.OP_NEGATIVE if op_t.type == tk_type.MINUS else AST.Unary.Operation.OP_NOT 
		
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
	return expr

func parse_primary():
	if check(tk_type.LITERAL):
		pass
	
	
	
	return null
