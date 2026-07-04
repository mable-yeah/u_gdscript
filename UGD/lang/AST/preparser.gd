class_name preparser ##uses the lexer's generated TOKENS to create an AST

const operator_type = loader_lang.Operation
var tk_arr:Array[TOKENS.token] = []
var length:int:
	get():
		return tk_arr.size()


var cursor := 0
var current_token:TOKENS.token = null

#var annotations = []

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


const tk_type = TOKENS.type
var program := AST.PROGRAM.new()


func _init(p_tk:Array[TOKENS.token]) -> void:
	tk_arr = p_tk
	evaluate_program()

#the parser reads top to bottom, so ordering is slightly important!!
func evaluate_program() -> void:
	while !is_at_end(): 
		if check(tk_type.INDENT):
			make_error('indent in class body')
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
			make_error(global_error_types[0] % peek().get_name())
			advance()
		#rest of this is body
		elif check(tk_type.ANNOTATION):
			make_error(global_error_types[0] % peek().get_name())
			advance()
		elif check(tk_type.ENUM):
			var _declaration = parse_enum_declaration()
			if has_errors:
				break
			program.misc.push_back(_declaration)
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
			var meta = [peek().get_name().to_lower(),peek().literal]
			var err = '%s "%s"'  % meta
			if meta[1] == null: err = '"%s"' % meta[0]
			make_error('unexpected %s in class body' % err) ; advance()
		if has_errors:
			break
	#how to teleport tutorial working 2026


func skip_newlines(ignore_indents := false) -> void:
	if !ignore_indents:
		while check(tk_type.NEWLINE):
			advance()
		return
	while check(tk_type.NEWLINE) || check(tk_type.INDENT) || check(tk_type.DEDENT):
		advance()


func parse_enum_declaration() -> AST.enumerator:
	advance()
	var _name = consume(tk_type.IDENTIFIER,'expected enum name, got %s')
	#technically you can use enums without a name BUT i no no wanna do tha
	var _enumerators:Array[Dictionary] = []
	consume(tk_type.BRACE_OPEN,'expected { after enum name')
	while true and not has_errors:
		skip_newlines(true)
		var enum_name = consume(tk_type.IDENTIFIER,'expected identifier in enum, got %s')
		
		if check(tk_type.EQUAL):
			advance()
			if check(tk_type.LITERAL) and peek().literal is int || check(tk_type.IDENTIFIER):  #foo = 2
				_enumerators.push_back({
					'key':enum_name.literal,
					'value':advance().literal
					})
			else:
				make_error('expected IDENTIFIER or LITERAL (type int), got %s' % peek().get_name())
		else:
			_enumerators.push_back({
				'key':enum_name.literal,
				'value':_enumerators.size()
				}) 
			#just push it back with indexing
		if !check(tk_type.COMMA):
			skip_newlines(true)
			break
		advance()
		skip_newlines(true)
	
	consume(tk_type.BRACE_CLOSE,'expected closing } after enum, got %s')
	if has_errors:
		return null
	return AST.enumerator.new(_name.literal,_enumerators)


func parse_func_declaration() -> AST.funcDecl_Statement:
	advance()
	var statement = AST.funcDecl_Statement.new()
	var _name = consume(tk_type.IDENTIFIER,'expected variable name')
	var _type = null
	var params:Dictionary[String,AST.varDecl_Statement]
	
	#define parameters 
	consume(tk_type.PARENTHESIS_OPEN, "expected '(' after function name")
	if !check(tk_type.PARENTHESIS_CLOSE):
		var was_optional:= false
		while true:
			var expression = parse_var_declaration(false,false)
			if has_errors || expression == null:
				break
				
			if expression.initializer != null: was_optional = true
			if was_optional and expression.initializer == null: 
				make_error('cannot have mandatory params after optional params.') ; break
			
			if params.has(expression.name):
				make_error('parameter "%s" was already declared for this function' % expression.name)
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
			make_error('expected identifier or void after "->", got "%s"' % peek().get_name())
		


	statement.body = parse_scope_block()
	statement.type_hint = _type
	statement.params = params
	statement.name = _name.literal
	
	return statement


func parse_scope_block() -> Array[AST.Expr]:
	consume(tk_type.COLON,'expected ":" after statement, got "%s"')
	skip_newlines()
	consume(tk_type.INDENT,'expected indent after statement')
	if has_errors:
		return []
	var lines:Array[AST.Expr] = []
	
	while (!check(tk_type.DEDENT) and !is_at_end()):
		skip_newlines()
		if (!check(tk_type.DEDENT) and !is_at_end()):
			lines.push_back(parse_current_scope())
			if has_errors: return []
	
	consume(tk_type.DEDENT,'expected dedent after scope body')
	return lines

func parse_current_scope() -> AST.Expr:
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



func parse_assignment() -> AST.Expr: #expression or assignment
	var _p_cursor = cursor
	var _left = parse_expression() 
	#this was parse_call before but that messes up assignment for standalone expressions.
	#while standalone lines are useless thats technically wrong
	
	if has_errors: return null
	
	if check(tk_type.EQUAL): #property = value
		advance()
		var _right = parse_expression()
		end_statement('assignment')
		return AST.assignment.new(_left,operator_type.OP_LOGIC_EQUAL,_right,false)
	
	if check(tk_type.STAR_EQUAL) || check(tk_type.SLASH_EQUAL) \
	|| check(tk_type.PLUS_EQUAL) || check(tk_type.MINUS_EQUAL): #property 'operation_equals' value
		var op_tk = advance()
		var _right = parse_expression()
		
		end_statement('assignment')

		var op:operator_type
		if check(tk_type.PLUS_EQUAL,op_tk) || check(tk_type.MINUS_EQUAL,op_tk):
			op = operator_type.OP_ADDITION if check(tk_type.PLUS_EQUAL,op_tk) else operator_type.OP_SUBTRACTION
		elif check(tk_type.STAR_EQUAL,op_tk) || check(tk_type.SLASH_EQUAL,op_tk):
			op = operator_type.OP_MULTIPLICATION if check(tk_type.STAR_EQUAL,op_tk) else operator_type.OP_DIVISION
		
		return AST.assignment.new(_left,op,_right,false)
	
	
	end_statement('assignment')
	return AST.expression_Statement.new(_left)
	



func parse_return() -> AST.return_Statement:
	advance()
	var return_value = null
	if !check(tk_type.NEWLINE):
		return_value = parse_expression()
	#return is the only one that doesnt consume a dedent after parsing
	#its not expected to dedent immediatley after making a function return
	return AST.return_Statement.new(return_value)

func parse_for() -> AST.for_Statement:
	advance()
	
	var name_tk = consume(tk_type.IDENTIFIER,'expected loop iterator name after "for", got %s')
	
	
	consume(tk_type.TK_IN,'expected "in" after iterator name')
	var iter = parse_expression()
	
	
	var body = parse_scope_block()
	return AST.for_Statement.new(name_tk.literal,body,iter)



func parse_while() -> AST.while_Statement:
	advance()
	var expression = parse_expression()
	var body = parse_scope_block()
	return AST.while_Statement.new(expression,body)

func parse_if() -> AST.if_Statement:
	advance()
	var expression = parse_expression()
	
	var then_expr:Array[AST.Expr] = parse_scope_block()
	var else_expr:Array[AST.Expr] = []
	
	skip_newlines()
	if check(tk_type.ELIF):
		else_expr.push_back(parse_if())
	elif check(tk_type.ELSE):
		advance()
		else_expr = parse_scope_block()
	
	if has_errors:
		return null
	return AST.if_Statement.new(expression,then_expr,else_expr)





#starts after 'var' not at 'var', so advance/consume before calling this
func parse_var_declaration(is_const:bool = false,expect_newline := true) -> AST.varDecl_Statement:
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 
	var _type = parse_var_type_hint()
	if has_errors:
		return null
	var _initializer = null
	
	if check(tk_type.EQUAL):
		advance()
		
		_initializer = parse_expression()
		if has_errors:
			return null
	elif is_const:
		make_error('expected initializer after constant name')
	
	if expect_newline:
		if check(tk_type.COLON):
			#if get set WERE supported parse it here
			make_error('colon found after variable declaration "%s", get()/set() is unsupported' % _name.literal)
		else:
			end_statement('var declaration')
	
	return AST.varDecl_Statement.new(_name.literal,_type,_initializer,is_const)

##return variable containing the 'type' needed, else null
func parse_var_type_hint() -> TOKENS.token:
	if not check(tk_type.COLON):
		return
	advance()
	#return the token that contains the supposed 'type' we need.. or null
	if check(tk_type.IDENTIFIER):
		return advance()
	elif check(tk_type.EQUAL):
		return null 
		#return null silently, get it filled by the parsed expression's final type later on
	else:
		make_error('expected/missing type identifier after ":", found %s' %peek().get_name())
		return null


##advances the parser if the type matches, else error
func consume(type:tk_type,message:String) -> TOKENS.token:
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
	if is_at_end() || tk == null: return false
	return tk.type == type

##generates an error and prints it to console
func make_error(st:String) -> void:
	var generic = 'Pre-processor error: \' %s \''
	printerr(generic % st)
	errors.push_back(st)
	return 


func previous() -> TOKENS.token:
	return tk_arr.get(cursor - 1)


func peek(peek_dist = 0) -> TOKENS.token:
	if cursor >= length:
		return null
	return tk_arr.get(cursor + peek_dist)

func advance() -> TOKENS.token:
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
	return parse_is(can_assign)

func parse_is(can_assign):
	var left = parse_ternary_expression(can_assign)
	if check(tk_type.IS):
		advance()
		var right = parse_primary()
		return AST.is_statement.new(left, right)
	return left

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
		left = AST.assignment.new(left,operator_type.OP_LOGIC_OR,right)

	return left

func parse_and_expression(can_assign) -> AST.Expr:
	var left = parse_equality(can_assign)
	while check(tk_type.AND):
		advance()
		var right = parse_equality(can_assign)
		left = AST.assignment.new(left,operator_type.OP_LOGIC_AND,right)
	return left

func parse_equality(can_assign) -> AST.Expr:
	var left = parse_comparison()
	if can_assign:
		while check(tk_type.EQUAL_EQUAL) || check(tk_type.BANG_EQUAL):
			var op_t = advance()
			var right = parse_comparison()
			
			var op = operator_type.OP_COMP_EQUAL \
			if check(tk_type.EQUAL_EQUAL,op_t) else operator_type.OP_COMP_NOT_EQUAL
			
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
				op = operator_type.OP_COMP_LESS_EQUAL
			tk_type.LESS:
				op = operator_type.OP_COMP_LESS
			tk_type.GREATER:
				op = operator_type.OP_COMP_GREATER
			tk_type.GREATER_EQUAL:
				op = operator_type.OP_COMP_GREATER_EQUAL
			_:
				make_error('couldnt match operation :/ %s' % op_t.get_name())
				op = operator_type.OP_COMP_LESS
		left = AST.assignment.new(left,op,right)
	return left

func parse_term() -> AST.Expr:
	var left = parse_factor()
	while check(tk_type.PLUS) || check(tk_type.MINUS):
		var op_t = advance()
		var right = parse_factor()
		var op = operator_type.OP_PLUS if check(tk_type.PLUS,op_t) else operator_type.OP_MINUS
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
				op = operator_type.OP_MULTIPLY
			tk_type.SLASH:
				op = operator_type.OP_DIVIDE
			tk_type.PERCENT:
				op = operator_type.OP_MODULO
			_:
				make_error('couldnt match operation :/ %s' % op_t.get_name())
				op = operator_type.OP_MODULO
		left = AST.assignment.new(left,op,right)
	return left

func parse_unary() -> AST.Expr:
	if check(tk_type.BANG,peek()) || check(tk_type.NOT,peek()):
		var op_t = advance()
		var operand = parse_unary()
		var op = operator_type.OP_NEGATIVE if check(tk_type.BANG,op_t) else operator_type.OP_NOT 
		return AST.unary.new(operand,op)
	return parse_call()

func parse_call(expr = parse_primary()) -> AST.Expr:
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
			if expr.get('name') != null:
				expr =  AST.function_call.new(expr,arg)
				continue
			make_error('invalid call to type of "%s"' % expr.get_type_name())
		elif check(tk_type.BRACKET_OPEN): #arr[0]
			advance()
			var ind = parse_expression()
			consume(tk_type.BRACKET_CLOSE,'expected closing bracket')
			expr = AST.index.new(expr,ind)
		elif check(tk_type.PERIOD): #.property
			advance()
			if !check(tk_type.IDENTIFIER):
				make_error('expected identifier after "." for attribute access') ; break
			var member = AST.variable.new(advance().literal)
			member = parse_call(member)
			expr = AST.member_Call.new(expr,member)
		else:
			break
	return expr

func parse_primary() -> AST.Expr:
	if check(tk_type.SELF):
		advance()
		return AST.literal.new('self')
	
	#BUILT IN VALUES/ DIGITS, STRINGS
	if check(tk_type.LITERAL):
		return AST.literal.new(advance().literal)
	
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
			
			check_token = tk_type.EQUAL if expr.style != style.PYTHON_DICT else tk_type.COLON
			
			if expr.style == style.LUA_TABLE:
				var is_literal =  key.type == loader_lang.Type.LITERAL
				var err = 'expected identifier or string as Lua-style dictionary key, got %s' % key.get_type_name()
				if key.type != loader_lang.Type.IDENTIFIER and !is_literal:
					make_error(err) ; return null
				if is_literal and key.literal_type != TYPE_STRING:
					make_error(err) ; return null
				
				key.reduced_value = key.name \
				if key.type == loader_lang.Type.IDENTIFIER else str(key.variant)
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
	
	make_error('expected expression :/, got %s ' % peek().get_name())
	return null


func end_statement(context:String) -> void:
	var found := false
	
	while is_end_token():  advance() ; found = true
	
	if found: return
	make_error('expected newline or ";" after %s got "%s"' % [context,peek().get_name()])

func is_end_token():
	return check(tk_type.NEWLINE) || check(tk_type.SEMICOLON) || check(tk_type.TK_EOF)
