class_name TOKENS


##the differing available types of TOKENS
enum type {
	EMPTY,
	# Basic
	ANNOTATION,
	IDENTIFIER,
	LITERAL,
	# Comparison
	LESS,
	LESS_EQUAL,
	GREATER,
	GREATER_EQUAL,
	EQUAL_EQUAL,
	BANG_EQUAL,
	# Logical
	AND,
	OR,
	NOT,
	AMPERSAND_AMPERSAND,
	PIPE_PIPE,
	BANG,
	# Bitwise
	AMPERSAND,
	PIPE,
	TILDE,
	CARET,
	LESS_LESS,
	GREATER_GREATER,
	# Math
	PLUS,
	MINUS,
	STAR,
	STAR_STAR,
	SLASH,
	PERCENT,
	# Assignment
	EQUAL,
	PLUS_EQUAL,
	MINUS_EQUAL,
	STAR_EQUAL,
	STAR_STAR_EQUAL,
	SLASH_EQUAL,
	PERCENT_EQUAL,
	LESS_LESS_EQUAL,
	GREATER_GREATER_EQUAL,
	AMPERSAND_EQUAL,
	PIPE_EQUAL,
	CARET_EQUAL,
	# Control flow
	IF,
	ELIF,
	ELSE,
	FOR,
	WHILE,
	BREAK,
	CONTINUE,
	PASS,
	RETURN,
	MATCH,
	WHEN,
	# Keywords
	AS,
	ASSERT,
	AWAIT,
	BREAKPOINT,
	CLASS,
	CLASS_NAME,
	TK_CONST, # Conflict with WinAPI.
	ENUM,
	EXTENDS,
	FUNC,
	TK_IN, # Conflict with WinAPI.
	IS,
	NAMESPACE,
	PRELOAD,
	SELF,
	SIGNAL,
	STATIC,
	SUPER,
	TRAIT,
	VAR,
	TK_VOID, # Conflict with WinAPI.
	YIELD,
	# Punctuation
	BRACKET_OPEN,
	BRACKET_CLOSE,
	BRACE_OPEN,
	BRACE_CLOSE,
	PARENTHESIS_OPEN,
	PARENTHESIS_CLOSE,
	COMMA,
	SEMICOLON,
	PERIOD,
	PERIOD_PERIOD,
	PERIOD_PERIOD_PERIOD,
	COLON,
	DOLLAR,
	FORWARD_ARROW,
	UNDERSCORE,
	# Whitespace
	NEWLINE,
	INDENT,
	DEDENT,
	# Constants
	CONST_PI,
	CONST_TAU,
	CONST_INF,
	CONST_NAN,
	# Error message improvement
	VCS_CONFLICT_MARKER,
	BACKTICK,
	QUESTION_MARK,
	# Special
	ERROR,
	TK_EOF, # "EOF" is reserved
	TK_MAX
}

##KEYWORDS is a dict of strings that assign to specific token tyoes
const KEYWORDS:Dictionary = {
	'as': type.AS,
	'and': type.AND,
	'assert': type.ASSERT,
	'await': type.AWAIT,
	'break': type.BREAK,
	'breakpoint': type.BREAKPOINT,
	'class' : type.CLASS,
	'class_name' : type.CLASS_NAME,
	'const' : type.TK_CONST,
	'continue' : type.CONTINUE,
	'elif' : type.ELIF,
	'else': type.ELSE,
	'enum': type.ENUM,
	'extends': type.EXTENDS,
	'for': type.FOR,
	'func': type.FUNC,
	'if': type.IF,
	'is': type.IS,
	'in': type.TK_IN,
	'match': type.MATCH,
	'namespace': type.NAMESPACE,
	'not': type.NOT,
	'or': type.OR,
	'pass': type.PASS,
	'preload': type.PRELOAD,
	'return': type.RETURN,
	'self': type.SELF,
	'signal': type.SIGNAL,
	'static': type.STATIC,
	'super': type.SUPER,
	'trait': type.TRAIT,
	'var': type.VAR,
	'void': type.TK_VOID,
	'while': type.WHILE,
	'when': type.WHEN,
	'yield': type.YIELD,
	'INF': type.CONST_INF,
	'NAN': type.CONST_NAN,
	'PI': type.CONST_PI,
	'TAU': type.CONST_TAU,
}

##creates a token and returns it
static func create_token(p_type:TOKENS.type = TOKENS.type.EMPTY,p_literal:Variant = null) -> token:
	var tk = token.new(p_type,p_literal)
	return tk


class token:
	var type:TOKENS.type = TOKENS.type.EMPTY
	var literal:Variant
	
	func _init(p_type:TOKENS.type,p_literal:Variant = null) -> void:
		type = p_type
		literal = p_literal

	func get_name() -> String:
		return TOKENS.type.keys()[type]
	
	func can_precede_bin_op() -> bool:
		var types = TOKENS.type
		match type:
			types.IDENTIFIER:
				return true
			types.LITERAL:
				return true
			types.SELF:
				return true
			types.BRACKET_CLOSE:
				return true
			types.BRACE_CLOSE:
				return true
			types.PARENTHESIS_CLOSE:
				return true
			types.CONST_PI:
				return true
			types.CONST_TAU:
				return true
			types.CONST_INF:
				return true
			_:
				return false
	
	
	
	
	
	
	
	func is_identifier() -> bool:
		var types = TOKENS.type
		match type:
			types.IDENTIFIER:
				return true
			types.MATCH:
				return true
			types.WHEN:
				return true
			types.CONST_PI:
				return true
			types.CONST_INF:
				return true
			types.CONST_NAN:
				return true
			types.CONST_TAU:
				return true
			_:
				return false
	
	func is_node_name() -> bool:
		var types = TOKENS.type
		match type:
			types.IDENTIFIER:
				return true
			types.AND:
				return true
			types.AS:
				return true
			types.ASSERT:
				return true
			types.AWAIT:
				return true
			types.BREAK:
				return true
			types.BREAKPOINT:
				return true
			types.CLASS_NAME:
				return true
			types.CLASS:
				return true
			types.TK_CONST:
				return true
			types.CONST_PI:
				return true
			types.CONST_INF:
				return true
			types.CONST_NAN:
				return true
			types.CONST_TAU:
				return true
			types.CONTINUE:
				return true
			types.ELIF:
				return true
			types.ELSE:
				return true
			types.ENUM:
				return true
			types.EXTENDS:
				return true
			types.FOR:
				return true
			types.FUNC:
				return true
			types.IF:
				return true
			types.TK_IN:
				return true
			types.IS:
				return true
			types.MATCH:
				return true
			types.NAMESPACE:
				return true
			types.NOT:
				return true
			types.OR:
				return true
			types.PASS:
				return true
			types.PRELOAD:
				return true
			types.RETURN:
				return true
			types.SELF:
				return true
			types.SIGNAL:
				return true
			types.STATIC:
				return true
			types.SUPER:
				return true
			types.TRAIT:
				return true
			types.UNDERSCORE:
				return true
			types.VAR:
				return true
			types.TK_VOID:
				return true
			types.WHILE:
				return true
			types.WHEN:
				return true
			types.YIELD:
				return true
			_:
				return false
