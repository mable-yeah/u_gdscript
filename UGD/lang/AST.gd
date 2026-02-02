class_name AST

#jumpy jane save me
##base expression classs, all expressions extend this
class Expr:
	var reduced_value = null
	var _tk_st = "NONE"
	
	
	var type:preparser_lang.Type = preparser_lang.Type.NONE:
		set(p_type):
			type = p_type
			_tk_st = get_type_name()
	
	
	func get_type_name() -> String:
		return preparser_lang.Type.keys()[type]

#variable name reference 'x'
class variable extends Expr:
	var name = ""
	
	func _init(p_name:String) -> void:
		name = p_name
		type = preparser_lang.Type.IDENTIFIER

#passing in the value 'true' should infer the type of 'bool',
#i.e passing in the string "true" should infer 'string' 
class literal extends Expr:
	var literal_type:Variant.Type = Variant.Type.TYPE_NIL
	var variant:Variant = null
	
	
	func _init(p_variant:Variant) -> void:
		variant = p_variant
		literal_type = typeof(p_variant) as Variant.Type
		type = preparser_lang.Type.LITERAL


class member_Call extends Expr: #.function(expression)
	var target:Expr
	var args:Array[Expr]
	
	func _init(p_target:Expr,arguments:Array[Expr] = []) -> void:
		type = preparser_lang.Type.CALL
		target = p_target
		args = arguments


class _call extends Expr: #(expression)
	var name:String
	var args:Array[Expr]
	
	func _init(p_target:String,arguments:Array[Expr] = []) -> void:
		type = preparser_lang.Type.CALL
		name = p_target
		args = arguments


class index extends Expr: #arr[expression]
	var target:Expr
	var idx:Expr
	
	func _init(p_target:Expr,p_ind:Expr) -> void:
		type = preparser_lang.Type.CALL
		target = p_target 
		idx = p_ind


class assignment extends Expr:
	var left:Expr
	var op:preparser_lang.Operation
	var right:Expr
	
	func _init(LEFT:Expr,OP:preparser_lang.Operation,RIGHT:Expr) -> void:
		type = preparser_lang.Type.ASSIGNMENT
		left = LEFT
		op = OP
		right = RIGHT


class unary extends Expr:
	enum Operation {OP_NEGATIVE,OP_NOT}
	
	var op:Operation
	var operand:Expr
	
	func _init(p_operand:Expr,OP:Operation) -> void:
		type = preparser_lang.Type.UNARY_OPERATOR
		op = OP
		operand = p_operand


class array extends Expr:
	var elements:Array[Expr] = []
	
	func _init() -> void:
		type = preparser_lang.Type.ARRAY


class dictionary extends Expr:
	enum styling {
		NONE,
		PYTHON_DICT,
		LUA_TABLE
	}
	
	var style:styling = styling.NONE
	var elements:Dictionary = {}
	
	#supply with check(TOKEN_TYPE) from the preprocessor
	func decide_style(EQUAL:bool,COLON:bool):
		if style != styling.NONE:
			return 
		if EQUAL:
			style = styling.PYTHON_DICT
		elif COLON:
			style = styling.LUA_TABLE



	func _init() -> void:
		type = preparser_lang.Type.DICTIONARY

class ternary extends Expr:
	var target:Expr #x
	var left:Expr #if __ else
	var right:Expr #y
	#x if bool_here else y
	
	func _init(p_target:Expr,p_left:Expr,p_right:Expr) -> void:
		type = preparser_lang.Type.TERNARY_OPERATOR
		target = p_target
		left = p_left
		right = p_right


#STATEMENT EXPR

class funcDecl_Statement extends Expr:
	var name = ""
	var type_hint:tokens.token # -> (TYPE)
	var params:Dictionary[String,Expr]
	var body:Array = []
	
	func _init() -> void:
		type = preparser_lang.Type.FUNCTION


class varDecl_Statement extends Expr:
	var name = ""
	var type_hint:Variant #tokens.token or variant type
	var initializer = null #non constant values can be initialized as null
	var is_constant := false
	
	func _init() -> void:
		type = preparser_lang.Type.VARIABLE


class pass_Statement extends Expr:
	func _init() -> void:
		type = preparser_lang.Type.PASS


class cont_Statement extends Expr:
	func _init() -> void:
		type = preparser_lang.Type.CONTINUE


class break_Statement extends Expr:
	func _init() -> void:
		type = preparser_lang.Type.BREAK


class binary_Statement extends Expr:
	var left:Expr
	var op:preparser_lang.Operation
	var right:Expr
	
	
	func _init(p_left:Expr,p_op:preparser_lang.Operation,p_right:Expr) -> void:
		type = preparser_lang.Type.BINARY_OPERATOR
		left = p_left
		op = p_op
		right = p_right


class assign_Statement extends Expr:
	var left:Variant #String (representing a variable) or Expr
	var right:Expr
	
	func _init(p_left:Variant,p_right:Expr) -> void:
		type = preparser_lang.Type.ASSIGNMENT
		right = p_right
		left = p_left


class expression_Statement extends Expr:
	var expression:Expr
	
	func _init(p_expr:Expr) -> void:
		type = preparser_lang.Type.LITERAL
		expression = p_expr


class return_Statement extends Expr:
	
	var expression:Expr = null
	func _init(p_expr:Expr = null) -> void:
		type = preparser_lang.Type.RETURN
		expression = p_expr


class for_Statement extends Expr:
	var name:String #name of iterator variable 'x'
	var iter:Expr #expression to iterate on.. like an array or something
	
	var body:Array[Expr] #body of for statement
	
	func _init(p_name:String,p_body:Array[Expr],p_iter:Expr) -> void:
		type = preparser_lang.Type.FOR
		name = p_name
		body = p_body
		iter = p_iter


class while_Statement extends Expr:
	var condition:Expr
	var body:Expr
	
	func _init(p_condition:Expr,p_body:Expr) -> void:
		type = preparser_lang.Type.WHILE
		condition = p_condition
		body = p_body


class if_Statement extends Expr:
	var condition:Expr
	var _then:Array[Expr] = []
	var _else:Array[Expr] = []
	
	func _init(p_condition:Expr,p_then:Array[Expr],p_else:Array[Expr]) -> void:
		type = preparser_lang.Type.IF
		condition = p_condition
		_then = p_then
		_else = p_else


class PROGRAM: 
	var class_n:String 
	var extends_n:String
	
	var globals:Array[varDecl_Statement]
	var functions:Array[funcDecl_Statement]
