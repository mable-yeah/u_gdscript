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



func _init(p_tk:Array[tokens.token]) -> void:
	tk_arr = p_tk
	evaluate_program()

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
		elif check(tk_type.TK_CONST): #constants need to be checked before regular var's
			advance()
			var _declaration = parse_var_declaration(true)
		elif check(tk_type.VAR):
			advance()
			var _declaration = parse_var_declaration()
		elif check(tk_type.FUNC):
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



func parse_var_declaration(is_const:bool = false):
	var _name = consume(tk_type.IDENTIFIER,'expected variable name') 
	var _type = parse_type_hint()
	var _initializer = null
	if check(tk_type.EQUAL):
		advance()
		consume(tk_type.LITERAL,'expected expression for initalizer after =')
	elif is_const:
		make_error('expected initializer after constant name')
	consume(tk_type.NEWLINE,'expected newline after variable declaration, found %s') 




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






##expressions

func parse_expression():
	pass

func parse_or_expression():
	pass

func parse_and_expression():
	pass

func parse_equality():
	pass

func parse_comparison():
	pass

func parse_term():
	pass

func parse_factor():
	pass

func parse_unary():
	pass

func parse_call():
	pass

func parse_primary():
	pass
