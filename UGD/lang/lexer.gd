class_name lexer

var code := "" 
var length:int:
	get():
		return code.length()


var tab_size := 4

var column := -1
var position := 0

var cursor_column := -1
var cursor := 0

var ch := ""


var paren_stack:Array[String] = []
var tk_arr:Array[tokens.token] = []
var last_token:tokens.token = tokens.create_token()

func _init(p_code) -> void:
	code = lang_utilities.scrub_comments(p_code)
	read_char()
	tokenize()
	debug_token_print()

func tokenize():
	var newtoken:tokens.token = tokens.create_token()
	
	while cursor <= length:
		newtoken = next_token()
		tk_arr.push_back(newtoken)
		last_token = newtoken
		if newtoken.type == tokens.type.TK_EOF:
			break
	return tk_arr

func debug_token_print():
	for token in tk_arr:
		var t_str = token.get_name()
		if t_str == "LITERAL" || t_str == 'IDENTIFIER':
			print("%s --> %s" %[t_str,token.literal])
		else:
			print(t_str)



func next_token() -> tokens.token:
	var newtoken := tokens.create_token()
	eat_whitespace()
	
	if is_at_end():
		newtoken.type = tokens.type.TK_EOF
		return newtoken
	
	var t = get_token_type()
	if t is tokens.type:
		newtoken.type  = t
	else:
		newtoken = t
	
	read_char()
	return newtoken




func get_token_type() -> Variant: #tokens.type or a token
	var types = tokens.type
	var type = tokens.type.ERROR
	var c = ch
	#print(c)
	var p = peek_char()
	
	#catch select numbers and characters as tokens before _: does hopefully
	if is_digit(c):
		return number()
	elif is_unicode_identifier(c): 
		return potential_identifier()
	
	
	match c:
		#string literals
		'"':
			return string()
		'\\':
			return string()
		#annotation
		"@":
			return annotation()
		#single characters
		"~":
			type = types.TILDE
		",":
			type = types.COMMA
		':':
			type = types.COLON
		';':
			type = types.SEMICOLON
		'$':
			type = types.DOLLAR
		'?':
			type = types.QUESTION_MARK
		'`':
			type = types.BACKTICK
		#parens
		"(":
			push_paren(c)
			type = types.PARENTHESIS_OPEN
		"[":
			push_paren(c)
			type = types.BRACKET_OPEN
		"{":
			push_paren(c)
			type = types.BRACE_OPEN
		")":
			if not pop_paren('('):
				return paren_err(c)
			type = types.PARENTHESIS_CLOSE
		
		"]":
			if not pop_paren('['):
				return paren_err(c)
			type = types.BRACKET_CLOSE
		"}":
			if not pop_paren('{'):
				return paren_err(c)
			type = types.BRACE_CLOSE
		#double characters
		'!':
			if p == "=":
				read_char()
				type = types.BANG_EQUAL
			else:
				type = types.BANG
		".":
			if p == ".":
				read_char()
				p = peek_char()
				if p == ".":
					read_char()
					type = types.PERIOD_PERIOD_PERIOD
				else:
					type = types.PERIOD_PERIOD
			else:
				type = types.PERIOD
		"+":
			if p == "=":
				read_char()
				type = types.PLUS_EQUAL
			elif is_digit(p) and last_token.can_precede_bin_op():
				return number()
			else:
				type = types.PLUS
		"-":
			if p == "=":
				read_char()
				type = types.MINUS_EQUAL
			elif is_digit(p) and last_token.can_precede_bin_op():
				return number()
			else:
				type = types.MINUS
		"*":
			if p == "=":
				read_char()
				type = types.STAR_EQUAL
			elif p == "*":
				if peek_char(1) == "=":
					read_char()
					read_char()
					type = types.STAR_STAR_EQUAL
				else:
					type = types.STAR_STAR
			else:
				type = types.STAR
		"/":
			if p == "=":
				read_char()
				type = types.SLASH_EQUAL
			else:
				type = types.SLASH
		"%":
			if p == "=":
				read_char()
				type = types.PERCENT_EQUAL
			else:
				type = types.PERCENT
		"^":
			if p == "=":
				read_char()
				type = types.CARET_EQUAL
			else: 
				if p == '"' || p == '\\':
					return string()
				else:
					type = types.CARET
		"&":
			if p == "&":
				read_char()
				type = types.AMPERSAND_AMPERSAND
			elif p == "=":
				read_char()
				type = types.AMPERSAND_EQUAL
			else: 
				if p == '"' || p == '\\':
					return string()
				else:
					type = types.AMPERSAND
		"|":
			if p == "|":
				read_char()
				type = types.PIPE_PIPE
			elif p == "=":
				read_char()
				type = types.PIPE_EQUAL
			else:
				type = types.PIPE
		"=":
			if p == "=":
				read_char()
				type = types.EQUAL_EQUAL
			else:
				type = types.EQUAL
		"<":
			if p == "=":
				read_char()
				type = types.LESS_EQUAL
			elif p == "<":
				if peek_char(1) == '=':
					read_char()
					read_char()
					type = types.LESS_LESS_EQUAL
				else:
					read_char()
					type = types.LESS_LESS
			else:
				type = types.LESS
		">":
			if p == "=":
				read_char()
				type = types.GREATER_EQUAL
			elif p == ">":
				if peek_char(1) == '=':
					read_char()
					read_char()
					type = types.GREATER_GREATER_EQUAL
				else:
					read_char()
					type = types.GREATER_GREATER
			else:
				type = types.GREATER
		_:
			if is_whitespace(c):
				printerr("invalid whitespace char %s" % c.c_escape())
			else:
				printerr("invalid char %s" % c)
	return type


const MIN_KEYWORD = 2 
const MAX_KEYWORD = 10

##returns a literal token with valid keyword data if found, else error
func potential_identifier():
	var start = cursor - 1
	var only_ascii = as_unicode(peek_char(-1)) < 128
	
	while is_unicode_identifier(peek_char()):
		var c = as_unicode(read_char())
		only_ascii = only_ascii and c < 128
	
	var p_len = cursor - start
	
	
	if p_len == 1 and peek_char(-1) == '_':
		#lone underscore
		return tokens.type.UNDERSCORE
	
	var p_str = span(start,p_len)
	if p_len < MIN_KEYWORD || p_len > MAX_KEYWORD: #keywords are only within this range
		return make_identifier(p_str)
	
	if not only_ascii: #keywords are acii only
		return make_identifier(p_str)
	
	var t = tokens.KEYWORDS.get(p_str)
	if t != null:
		return t 
	
	if p_len == 4:
		if p_str == 'true':
			return make_literal('true');
		elif p_str == 'null':
			return make_literal('null')
	elif p_len == 5:
		if p_str == 'false':
			return make_literal('false');
	return make_identifier(p_str)


##returns a literal token with valid number data if found, else error
func number():
	var start = cursor - 1
	var base := 10
	var has_decimal := false
	#var has_exponent = false
	var need_digits := false
	var digit_check_func = digit_func._is_digit_
	
	if (peek_char(-1) == '+' || peek_char(-1) == '-' and peek_char() == '0'):
		read_char()
	
	if peek_char(-1) == '.':
		has_decimal = true
	elif peek_char(-1) == '0':
		if peek_char() == 'x' || peek_char() == 'X':
			#hex
			base = 16
			digit_check_func = digit_func._is_hex_digit_
			need_digits = true
			read_char()
		elif peek_char() == 'b' || peek_char() == 'B':
			#binary
			base = 2
			digit_check_func = digit_func._is_binary_digit_
			need_digits = true
			read_char()
	
	if base == 10 and peek_char() == '_': # disallow `0x_` and `0b_`.
		return make_error('unexpected underscore after 0%s' % peek_char(-1))
	
	var was_underscore := false
	while digit_check(digit_check_func,peek_char()) || peek_char() == '_':
		var p = peek_char()
		if p == '_':
			if was_underscore:
				return make_error('multiple underscores cannot be placed in a numeric literal')
			was_underscore = true
		else:
			need_digits = false
			was_underscore = false
		read_char()
	
	#check for it being a '..' token instead of a decimal
	if peek_char() == '.' and peek_char(1) != '.':
		match base:
			10:
				if !has_decimal:
					has_decimal = true
				else:
					return make_error('Cannot use a decimal point twice in a number')
			16:
				return make_error('Cannot use a decimal point twice in a hex number')
			_:
				return make_error('Cannot use a decimal point in binary number')
		read_char()
		if peek_char() == '_': #allow 10.0 not 10._ 
			return make_error('unexpected underscore after decimal point')
		was_underscore = false
		while digit_check(digit_check_func,peek_char()) || peek_char() == '_':
			var p = peek_char()
			if p == '_':
				if was_underscore:
					return make_error('multiple underscores cannot be adjacent in a numeric literal')
				was_underscore = true
			else:
				was_underscore = false
			read_char()
	
	if base == 10:
		if peek_char() == 'e' || peek_char() == 'E':
			#has_exponent = true
			read_char()
			if peek_char() == '+' || peek_char() == '-':
				read_char()
			if not is_digit(peek_char()):
				return make_error('Expected exponent value after "e".')
			was_underscore = false
		
		while digit_check(digit_check_func,peek_char()) || peek_char() == '_':
			var p = peek_char()
			if p == '_':
				if was_underscore:
					return make_error('multiple underscores cannot be adjacent in a numeric literal')
				was_underscore = true
			else:
				was_underscore = false
			read_char()
	
	if need_digits:
		printerr(digit_func.keys()[digit_check_func])
		return make_error('expected digits')
	
	if has_decimal && peek_char() == '.' and peek_char(1) != '.':
		return make_error('Cannot use a decimal point twice in a number.')
		
		
	var n_str = span(start,cursor - start)
	return make_literal(n_str)


##returns a literal token with valid string data, else error
func string():
	if peek_char() == 'r' || peek_char() == '^' || peek_char() ==  '&':
			read_char()
	
	var quote_char := peek_char(-1)
	if peek_char() == quote_char and peek_char(1) == quote_char:
		#is_multiline = true
		read_char()
		read_char()
	
	var result := quote_char
	var string_found := false
	while not string_found:
		if is_at_end():
			return make_error("unterminated string")
		var p := peek_char()
		if p == quote_char:
			string_found = true
		
		result += p
		read_char()
		if string_found:
			break
	return make_literal(result)


func is_whitespace(st:String):  
	return st == " " || st == "\t" || st == "\n" || st == "\r"

func eat_whitespace():
	while ch == " " || ch == "\t" || ch == "\n" || ch == "\r":
		read_char() 


func peek_char(ind:int = 0) -> String:
	var p_offs = cursor + ind
	ch =  code[p_offs] if p_offs >= 0 and p_offs < length else ""
	return ch

func read_char() -> String:
	ch = ""
	if not is_at_end():
		cursor += 1
		position += 1
		column += 1
	ch = peek_char(-1)
	return ch



enum digit_func {
	_is_digit_,
	_is_hex_digit_,
	_is_binary_digit_
}
func digit_check(digit_check_func:digit_func,st:String):
	match digit_check_func:
		digit_func._is_digit_:
			return is_digit(st)
		digit_func._is_hex_digit_:
			return is_hex(st)
		digit_func._is_binary_digit_:
			return is_binary(st)
		_:
			return false



func span(start:int,end:int) -> String:
	return code.substr(start,end)

func is_unicode_identifier(st:String) -> bool:
	return st.is_valid_unicode_identifier()

func as_unicode(st:String) -> int:
	return st.unicode_at(0)


func is_at_end() -> bool:
	return cursor > length

func is_digit(st:String) -> bool:
	return st.is_valid_int()

func is_hex(st:String) -> bool:
	return is_char(st) || st.is_valid_int()

func is_binary(st:String) -> bool:
	return st == '0' || st == '1'

func is_char(st:String) -> bool:
	var regex = RegEx.new()
	regex.compile('^[a-zA-Z]')
	var r_match = regex.search(st)
	return r_match != null


func push_paren(paren_str:String):
	paren_stack.push_back(paren_str)

func pop_paren(expected_str:String):
	if paren_stack.is_empty():
		return false
	var actual = paren_stack.pop_back()
	return actual == expected_str

func paren_err(p_paren:String):
	if paren_stack.is_empty():
		printerr("Closing '%s' doesn't have an opening counterpart" % p_paren)
	else:
		printerr("Closing '%s' doesn't match an opening %s" % [p_paren,paren_stack.pop_back()])
	return tokens.type.ERROR

func annotation():
	#var annotation_source = ""
	var annotation_tk = tokens.create_token()
	annotation_tk.type = tokens.type.ANNOTATION 
	#annotation.literal = annotation_source #not doing allat
	return annotation_tk
	

#prints error message ++ returns error token
func make_error(err_str:String):
	printerr(err_str)
	return tokens.type.ERROR

func make_literal(literal_str:String):
	var token = tokens.create_token()
	token.type = tokens.type.LITERAL
	token.literal = literal_str
	return token


func make_identifier(literal_str:String):
	var token = tokens.create_token()
	token.type = tokens.type.IDENTIFIER
	token.literal = literal_str
	return token
