class_name lexer ##converts a string into usable TOKENS for the preprocessor

const tk_type = TOKENS.type
var has_errors:bool:
	get():
		return !errors.is_empty()

const MIN_KEYWORD = 2 
const MAX_KEYWORD = 10

var code := ""

var length:int:
	get():
		return code.length()


const tab_size := 4

var last_newline:TOKENS.token = TOKENS.create_token()
var pending_newline := false
var multiline_mode := false
var line_continuous := false
var pending_EOF := false


var pending_indents := 0

var column := 0
var cursor := 0

var ch := " "

var indent_char = ''

var current_indent_char := ''

var errors = []
var continuation_lines = []
var indent_stack:Array[int] = []
var paren_stack:Array[String] = []
var tk_arr:Array[TOKENS.token] = []
var last_token:TOKENS.token = TOKENS.create_token()

func _init(p_code,debug_print:bool = false) -> void:
	code = lang_utilities.scrub_comments_GD(p_code)
	code = code.insert(0,'\n') + '\n' 
	#since i cant directly manage the start and ending of the file
	#both ends are represented by an extra new line
	#this helps the parser not tweak out when indenting on the first line
	#and helps it dedent on the last one
	
	
	
	tokenize() 
	#make this only work inside of godot editor itself
	if debug_print and OS.has_feature("editor"): 
		debug_token_print()


##prints the available TOKENS as their tk_type, and prints literals and identifiers as '%s -> %s'
func debug_token_print(debug_print := true) -> String:
	var tk_name = []
	for token in tk_arr:
		var append_str = ""
		var t_str = token.get_name()
		if t_str == "LITERAL" || t_str == 'IDENTIFIER':
			append_str = "%s -> %s" %[t_str,token.literal]
		else:
			append_str = t_str
		if debug_print:
			print(append_str)
		tk_name.append(append_str)
	return '\n'.join(tk_name)
	

##advances through the length of the code string, assigning all valid characters into TOKENS
func tokenize() -> Array:
	var newtoken:TOKENS.token = TOKENS.create_token()
	
	while cursor <= length:
		eat_whitespace()
		newtoken = next_token()
		tk_arr.push_back(newtoken)
		last_token = newtoken
		
		if newtoken.type == tk_type.TK_EOF:
			break
		
	return tk_arr



##gets the current token type and advances characters, returning a new token
func next_token() -> TOKENS.token:
	var newtoken := TOKENS.create_token()
	
	if pending_newline:
		pending_newline = false
		if multiline_mode:
			return last_newline
	
	if pending_indents != 0:
		if pending_indents > 0:
			pending_indents -= 1
			newtoken.type = tk_type.INDENT
			return newtoken
		else:
			pending_indents += 1
			newtoken.type = tk_type.DEDENT
			return newtoken
	
	if is_at_end():
		if pending_EOF:
			newtoken.type = tk_type.TK_EOF
			return newtoken
		else:
			pending_EOF = true
			if is_whitespace(ch) || ch == "":
				return next_token()
	
	var t = get_token_type()
	if t is tk_type:
		newtoken.type  = t
	else:
		newtoken = t
		
	
	read_char()
	return newtoken



##returns a token type based on the current ch, else generates an error token
func get_token_type() -> Variant: #tk_type OR a token
	var type = tk_type.ERROR
	var c = ch
	var p = peek_char()

	
	if c == '\\':
		return handle_newline()
	line_continuous = false
	
	#catch select numbers and characters as TOKENS before _: does hopefully
	if is_digit(c):
		return number()
	elif is_unicode_identifier_start(c):
		return potential_identifier()
	
	
	match c:
		#string literals
		'"':
			return string()
		"'":
			return string()
		#annotation
		"@":
			return annotation()
		#single characters
		"~":
			type = tk_type.TILDE
		",":
			type = tk_type.COMMA
		':':
			type = tk_type.COLON
		';':
			type = tk_type.SEMICOLON 
		'$':
			type = tk_type.DOLLAR
		'?':
			type = tk_type.QUESTION_MARK
		'`':
			type = tk_type.BACKTICK
		#parens
		"(":
			push_paren(c)
			type = tk_type.PARENTHESIS_OPEN
		"[":
			push_paren(c)
			type = tk_type.BRACKET_OPEN
		"{":
			push_paren(c)
			type = tk_type.BRACE_OPEN
		")":
			if not pop_paren('('):
				return paren_err(c)
			type = tk_type.PARENTHESIS_CLOSE
		
		"]":
			if not pop_paren('['):
				return paren_err(c)
			type = tk_type.BRACKET_CLOSE
		"}":
			if not pop_paren('{'):
				return paren_err(c)
			type = tk_type.BRACE_CLOSE
		#double characters
		'!':
			if p == "=":
				read_char()
				type = tk_type.BANG_EQUAL
			else:
				type = tk_type.BANG
		".":
			if p == ".":
				read_char()
				p = peek_char()
				if p == ".":
					read_char()
					type = tk_type.PERIOD_PERIOD_PERIOD
				else:
					type = tk_type.PERIOD_PERIOD
			else:
				type = tk_type.PERIOD
		"+":
			if p == "=":
				read_char()
				type = tk_type.PLUS_EQUAL
			elif is_digit(p) and not last_token.can_precede_bin_op():
				#if the last token can precede an op, then treat this token like its actual token type
				#else treat it like a number
				#'1+1' or '1 + 1' both generate the same way, along with any other variation of that
				#BUT '1+-1' generates a one token, a plus token and a negative one token
				return number()
			else:
				type = tk_type.PLUS
		"-":
			if p == "=":
				read_char()
				type = tk_type.MINUS_EQUAL
			elif is_digit(p) and not last_token.can_precede_bin_op():
				return number()
			elif p == ">":
				read_char()
				type = tk_type.FORWARD_ARROW
			else:
				type = tk_type.MINUS
		"*":
			if p == "=":
				read_char()
				type = tk_type.STAR_EQUAL
			elif p == "*":
				if peek_char(1) == "=":
					read_char()
					read_char()
					type = tk_type.STAR_STAR_EQUAL
				else:
					type = tk_type.STAR_STAR
			else:
				type = tk_type.STAR
		"/":
			if p == "=":
				read_char()
				type = tk_type.SLASH_EQUAL
			else:
				type = tk_type.SLASH
		"%":
			if p == "=":
				read_char()
				type = tk_type.PERCENT_EQUAL
			else:
				type = tk_type.PERCENT
		"^":
			if p == "=":
				read_char()
				type = tk_type.CARET_EQUAL
			else: 
				if p == '"' || p == '\\':
					return string()
				else:
					type = tk_type.CARET
		"&":
			if p == "&":
				read_char()
				type = tk_type.AMPERSAND_AMPERSAND
			elif p == "=":
				read_char()
				type = tk_type.AMPERSAND_EQUAL
			else: 
				if p == '"' || p == '\\':
					return string()
				else:
					type = tk_type.AMPERSAND
		"|":
			if p == "|":
				read_char()
				type = tk_type.PIPE_PIPE
			elif p == "=":
				read_char()
				type = tk_type.PIPE_EQUAL
			else:
				type = tk_type.PIPE
		"=":
			if p == "=":
				read_char()
				type = tk_type.EQUAL_EQUAL
			else:
				type = tk_type.EQUAL
		"<":
			if p == "=":
				read_char()
				type = tk_type.LESS_EQUAL
			elif p == "<":
				if peek_char(1) == '=':
					read_char()
					read_char()
					type = tk_type.LESS_LESS_EQUAL
				else:
					read_char()
					type = tk_type.LESS_LESS
			else:
				type = tk_type.LESS
		">":
			if p == "=":
				read_char()
				type = tk_type.GREATER_EQUAL
			elif p == ">":
				if peek_char(1) == '=':
					read_char()
					read_char()
					type = tk_type.GREATER_GREATER_EQUAL
				else:
					read_char()
					type = tk_type.GREATER_GREATER
			else:
				type = tk_type.GREATER
		_:
			if is_whitespace(c):
				make_error("invalid whitespace char %s" % c.c_escape())
			else:
				make_error("invalid char %s" % c)
	return type


##handles a code newline/ '\' if found, else error
func handle_newline():
	var p = peek_char()
	if p == '\r':
		if peek_char(1) != '\n':
			return make_error('unexpected carriage return char')
		read_char()
	if p != '\n':
		return make_error('expected newline after \\')
	read_char()
	eat_whitespace(false)
	line_continuous = true
	continuation_lines.push_back(cursor)
	return get_token_type()



##returns a literal token with valid keyword data if found, else error
func potential_identifier():
	var start = cursor - 1
	var only_ascii = as_unicode(peek_char(-1)) < 128
	
	while is_unicode_identifier_continue(peek_char()):
		var c = as_unicode(read_char())
		only_ascii = only_ascii and c < 128
	
	var p_len = cursor - start
	
	
	if p_len == 1 and peek_char(-1) == '_':
		#lone underscore
		return tk_type.UNDERSCORE
	
	var p_str = span(start,p_len)
	
	if p_len < MIN_KEYWORD || p_len > MAX_KEYWORD: #keywords are only within this range
		return make_identifier(p_str)
	
	if not only_ascii: #keywords are acii only
		return make_identifier(p_str)
	
	var t = TOKENS.KEYWORDS.get(p_str)
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
	var has_exponent = false
	var need_digits := false
	var digit_check_func = digit_func._is_digit_

	if (peek_char(-1) == '+' || peek_char(-1) == '-' || peek_char() == '0'):
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
				return make_error('multiple underscores cannot be placed adjacently in a numeric literal')
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
					return make_error('cannot use a decimal point twice in a number')
			16:
				return make_error('cannot use a decimal point twice in a hex number')
			_:
				return make_error('cannot use a decimal point in binary number')
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
			has_exponent = true
			read_char()
			if peek_char() == '+' || peek_char() == '-':
				read_char()
			if not is_digit(peek_char()):
				return make_error('expected exponent value after "e".')
			was_underscore = false
	
	#var binary = 0b012
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
		return make_error('expected digits, got: %s' % digit_func.keys()[digit_check_func])
	
	
	if has_decimal && peek_char() == '.' and peek_char(1) != '.':
		return make_error('cannot use a decimal point twice in a number.')
	elif is_unicode_identifier_start(peek_char()) || not digit_check(digit_check_func,peek_char()):
		if is_char(peek_char()):
			return make_error('invalid numeric notation. %s...' % span(start,cursor - start))
	
	#invalidate 0b00012 or 1000.0qqweqw as thats INVALID NOTATION! ! ! !
	
	var n_str = span(start,cursor - start)
	var n_literal = -INF
	
	#on a sidenote if i wanted to add another silly digit type, it would be here
	#since technically after this point its either a float or int
	match base:
		16:
			n_literal = n_str.hex_to_int()
		2:
			n_literal = n_str.bin_to_int()
		_:
			if has_decimal || has_exponent:
				n_literal = n_str.to_float()
			else:
				n_literal = n_str.to_int()
	#also if the number is too large it generates a warning in godot itself BUT 
	#it doesnt crash so whatevs
	
	return make_literal(n_literal)

##returns a literal token with valid string data, else error
func string():
	if peek_char() == 'r' || peek_char() == '^' || peek_char() ==  '&':
		read_char()
	
	var quote_char := peek_char(-1)
	if peek_char() == quote_char and peek_char(1) == quote_char:
		read_char()
		read_char()
	var result := ""
	var string_found := false
	while not string_found:
		if is_at_end():
			return make_error("unterminated string")
		var p := peek_char()
		
		if p == '\\':
			read_char()
			result += peek_char()
		elif p == quote_char:
			string_found = true
		else:
			result += p
		
		read_char()
		if string_found:
			break
	return make_literal('%s%s%s' % [quote_char,result,quote_char])

##returns an annotation token if found, else error
func annotation():
	if is_unicode_identifier_start(peek_char()):
		read_char()
	else:
		return make_error('expected annotation identifier after @, got %s' % peek_char())
	
	var start = cursor - 1
	while is_unicode_identifier_continue(peek_char()):
		read_char()
	
	var a_len = cursor - start
	var annotation_source = span(start,a_len)
	var annotation_tk = TOKENS.create_token(tk_type.ANNOTATION,annotation_source)
	return annotation_tk




func is_whitespace(st:String):  
	return st == " " || st == "\t" || st == "\n" || st == "\r"

func eat_whitespace(generate_newline := true):
	if pending_indents != 0:
		return
	
	var beggining_of_line := column == 1
	
	if beggining_of_line:
		check_indent()
		return
	
	while true:
		match ch:
			' ':
				
				read_char()
				continue
			'\t':
				
				read_char()
				column += tab_size - 1
				continue
			'\n':
				
				#skip newline token generation, if EOF is pending, as that last newline is just an extra newline
				#to satisfy indent/dedent generation
				newline(false if pending_EOF || !generate_newline else !beggining_of_line)
				check_indent()
				read_char()
				continue
			'\r':
				read_char()
				if peek_char() != '\n': #generate error but, forgive it kind of
					tk_arr.append(make_error("stray carriage return character in source code."))
				continue
			_:
				return


func peek_char(ind:int = 0) -> String:
	var p_offs = cursor + ind
	return code[p_offs] if p_offs >= 0 and p_offs < length else " "

func read_char() -> String:
	if is_at_end():
		ch = ""
		return ch
	ch = peek_char()
	column += 1
	cursor += 1
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


#both of these are neccessary in order to match correct literal naming schemes
func is_unicode_identifier_start(st:String) -> bool:
	return st.is_valid_unicode_identifier()

func is_unicode_identifier_continue(st:String) -> bool:
	return st.is_valid_unicode_identifier() || st.is_valid_int()

#essentially asking if its a valid letter/underscore
#and reading as a valid letter/underscore/int until invalid (white space or otherwise)



func as_unicode(st:String) -> int:
	return st.unicode_at(0)


func is_at_end() -> bool:
	return cursor >= length

func is_digit(st:String) -> bool:
	return st.is_valid_int()


func is_hex(st:String) -> bool:
	return is_char(st,"A-F") || st.is_valid_int()

func is_binary(st:String) -> bool:
	return st == '0' || st == '1'

func is_char(st:String,ch_range := "A-Z") -> bool:
	var ch_set = [ch_range.to_lower(),ch_range.to_upper()]
	var regex = RegEx.new()
	regex.compile('^[%s%s]' % ch_set)
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
		make_error("closing '%s' doesn't have an opening counterpart" % p_paren)
	else:
		make_error("closing '%s' doesn't match an opening %s" % [p_paren,paren_stack.pop_back()])
	return tk_type.ERROR


func newline(make_token:bool = false):
	if make_token and !pending_newline and !line_continuous:
		var token = TOKENS.create_token(tk_type.NEWLINE)
		pending_newline = true
		last_newline = token
		last_token = token
		tk_arr.push_back(token)
	column = 1

func check_indent():
	
	if column != 1:
		make_error('checking tokenizer indentation in the middle of a line')
		return
	#eat_whitespace()
	
	if is_at_end():
		if line_continuous || multiline_mode:
			return
		pending_indents -= indent_level()
		indent_stack.clear()
		return
	
	
	
	while true:
		current_indent_char = peek_char()
		var indent_count = 0
		if current_indent_char != '\t' and current_indent_char != ' ':
			if is_whitespace(current_indent_char):
				read_char()
				continue
			#First character of the line is not any tab characters, so we clear all indentation levels.
			#unless continuous or multiline of course
			if line_continuous || multiline_mode:
				return
			pending_indents -= indent_level()
			indent_stack.clear()
			return
		
		
		
		var mixed = false
		while not is_at_end():
			var space =  peek_char()
			if space == '\t':
				column += tab_size - 1
				indent_count += tab_size
			elif space == ' ':
				indent_count += 1
			else:
				break
			mixed = mixed || space != current_indent_char
			read_char()
		
		if is_at_end():
			pending_indents -= indent_level()
			indent_stack.clear()
			return
	
		if mixed and line_continuous and !multiline_mode:
			tk_arr.append(make_error_tk('Mixed use of tabs and spaces for indentation.'))
			return
		if line_continuous || multiline_mode:
			#We cleared up all the whitespace at the beginning of the line.
			#If this is a line continuation or we're in multiline mode then we don't want any indentation changes.
			return
		
		
		if indent_char == '':
			#print('current indent char : ',current_indent_char.c_escape())
			#first time indenting, init stuffs
			indent_char = current_indent_char
		elif current_indent_char != indent_char:
			if current_indent_char == "" || current_indent_char == " ":
				current_indent_char = "SPACE_SYMBOL"
			if indent_char == "" || indent_char == " ":
				indent_char = "SPACE_SYMBOL"
			tk_arr.append(make_error_tk('Mixed use of indentation characters, expected %s but got %s' % [indent_char.c_escape(),current_indent_char.c_escape()]))
		
		var previous_indent := 0
		if indent_level() > 0:
			previous_indent = indent_stack.back()
		if indent_count == previous_indent:
			return #no changes
		
		
		if indent_count > previous_indent:
			indent_stack.push_back(indent_count)
			pending_indents += 1
		else:
			if indent_level() == 0:
				tk_arr.append(make_error_tk('Tokenizer bug: trying to dedent without previous indent.'))
				return
			
			if indent_count > previous_indent:
				indent_stack.push_back(indent_count)
				pending_indents += 1
			
			while indent_level() > 0 and indent_stack.back() > indent_count:
				indent_stack.pop_back()
				pending_indents -= 1
			if indent_level() > 0 and indent_stack.back() != indent_count || indent_level() == 0 and indent_count != 0:
				tk_arr.append(make_error_tk("unindent doesn't match the previous indentation level."))
				indent_stack.push_back(indent_count)
		
		break
	

func indent_level() -> int:
	return indent_stack.size()

##prints error message ++ returns error token (type)
func make_error(st:String):
	var generic = 'Tokenizer/Lexer error: \' %s \''
	printerr(generic % st)
	errors.push_back(st)
	return tk_type.ERROR

##prints error message ++ returns error token (object)
func make_error_tk(err_str:String):
	var token = TOKENS.create_token(tk_type.ERROR)
	make_error(err_str)
	return token

##creates literal token
func make_literal(literal_str:Variant):
	var token = TOKENS.create_token(tk_type.LITERAL,literal_str)
	return token

##creates identifier token
func make_identifier(literal_str:Variant):
	var token = TOKENS.create_token(tk_type.IDENTIFIER,literal_str)
	return token
