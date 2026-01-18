class_name AST

class Expr:
	var type:preparser_lang.Type = preparser_lang.Type.NONE
	var is_expression := false

class VarDecl extends Expr:
	var name = ""
	var type_hint:tokens.token
	var initializer = null #non constant values can be initialized as null
	var is_constant := false
