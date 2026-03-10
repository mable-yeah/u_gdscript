class_name AST ##contains classes needed to form expression tree's

#jane 'jumpy jane' remover save me !!


##base expression classs, all expressions extend this
class Expr:
	var _tk_st:String = "NONE"
	var type:loader_lang.Type = loader_lang.Type.NONE:
		set(p_type):
			type = p_type
			_tk_st = get_type_name()
	
	
	func type_is(p_type:loader_lang.Type) -> bool:
		return type == p_type
	
	
	func get_type_name() -> String:
		return loader_lang.Type.keys()[type]
	


class variable extends Expr: ##variable name reference 'x'
	var name:String = ''
	
	func _init(p_name:String) -> void:
		name = p_name
		type = loader_lang.Type.IDENTIFIER
		


##passing in the value 'true' should infer the type of 'bool',
##i.e passing in the string "true" should infer 'string' 
class literal extends Expr:
	var literal_type:Variant.Type = Variant.Type.TYPE_NIL
	var variant:Variant = null
	
	
	func _init(p_variant:Variant) -> void:
		variant = p_variant
		literal_type = typeof(p_variant) as Variant.Type
		type = loader_lang.Type.LITERAL
	



##'target(argument)'
class function_call extends Expr: 
	var target:Expr
	var args:Array[Expr]
	
	func _init(p_target:Expr,arguments:Array[Expr] = []) -> void:
		type = loader_lang.Type.FUNC_CALL
		target = p_target
		args = arguments
	

##'target.function'
class member_Call extends Expr: 
	var target:Expr
	var member:Expr
	
	func _init(p_target:Expr,arg:Expr) -> void:
		type = loader_lang.Type.MEMBER_CALL
		target = p_target
		member = arg
	




##enum foo {bar,fungus = 1}
class _enum extends Expr: 
	var enumerators:Array[Dictionary] = []
	
	func _init(p_enum:Array[Dictionary]) -> void:
		type = loader_lang.Type.ENUM
		enumerators = p_enum
	


##arr[expression]
class index extends Expr: 
	var target:Expr
	var idx:Expr
	
	func _init(p_target:Expr,p_ind:Expr) -> void:
		type = loader_lang.Type.INDEX
		target = p_target 
		idx = p_ind
	



##exp1 +/=/> expr2
class assignment extends Expr:
	var left:Expr
	var op:loader_lang.Operation
	var right:Expr
	
	func _init(LEFT:Expr,OP:loader_lang.Operation,RIGHT:Expr) -> void:
		type = loader_lang.Type.ASSIGNMENT
		left = LEFT
		op = OP
		right = RIGHT


##-(1 - 1) || !(1 - 1)
class unary extends Expr:
	enum Operation {OP_NEGATIVE,OP_NOT}
	
	var op:Operation
	var operand:Expr
	
	func _init(p_operand:Expr,OP:Operation) -> void:
		type = loader_lang.Type.UNARY_OPERATOR
		op = OP
		operand = p_operand



##[value1,value2]
class array extends Expr:
	var elements:Array[Expr] = []
	
	func _init() -> void:
		type = loader_lang.Type.ARRAY


##{0 = 'string'} || {0 : 'not_string'}
class dictionary extends Expr:
	enum styling {
		NONE,
		PYTHON_DICT,
		LUA_TABLE
	}
	
	var style:styling = styling.NONE
	var elements:Dictionary = {}
	
	func decide_style(EQUAL:bool,COLON:bool):
		if style != styling.NONE:
			return 
		if EQUAL:
			style = styling.PYTHON_DICT
		elif COLON:
			style = styling.LUA_TABLE

	func _init() -> void:
		type = loader_lang.Type.DICTIONARY


##x if z else y
class ternary extends Expr:
	var target:Expr #x
	var left:Expr #if z else
	var right:Expr #y
	#x if bool_here else y
	
	func _init(p_target:Expr,p_left:Expr,p_right:Expr) -> void:
		type = loader_lang.Type.TERNARY_OPERATOR
		target = p_target
		left = p_left
		right = p_right
	



#STATEMENT EXPR

##func statement() -> hint:body
class funcDecl_Statement extends Expr:
	var name = ""
	var type_hint:TOKENS.token # -> (TYPE)
	var params:Dictionary[String,Expr]
	var body:Array[Expr] = []
	
	func _init() -> void:
		type = loader_lang.Type.FUNCTION


##(const?) var = expression
class varDecl_Statement extends Expr:
	var name:String
	var type_hint:TOKENS.token #TOKENS.token or variant type
	var initializer:Expr = null #non constant values can be initialized as null
	var is_constant:bool = false
	
	func _init(p_name:String,p_type_hint:Variant,p_initializer:Variant,p_is_constant:bool) -> void:
		type = loader_lang.Type.VARIABLE
		name = p_name
		type_hint  = p_type_hint
		initializer = p_initializer
		is_constant = p_is_constant


class pass_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.PASS



class cont_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.CONTINUE


class break_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.BREAK




class expression_Statement extends Expr:
	var expression:Expr
	
	func _init(p_expr:Expr) -> void:
		type = loader_lang.Type.EXPRESSION
		expression = p_expr




class return_Statement extends Expr:
	var expression:Expr = null
	func _init(p_expr:Expr = null) -> void:
		type = loader_lang.Type.RETURN
		expression = p_expr
	



##for x in iter: body
class for_Statement extends Expr:
	var name:String #name of iterator variable 'x'
	var iter:Expr #expression to iterate on.. like an array or something
	
	var body:Array[Expr] #body of for statement
	
	func _init(p_name:String,p_body:Array[Expr],p_iter:Expr) -> void:
		type = loader_lang.Type.FOR
		name = p_name
		body = p_body
		iter = p_iter


##while condition: body
class while_Statement extends Expr:
	var condition:Expr
	var body:Array[Expr]
	
	func _init(p_condition:Expr,p_body:Array[Expr]) -> void:
		type = loader_lang.Type.WHILE
		condition = p_condition
		body = p_body


##if condition: then_body else: else_body
class if_Statement extends Expr:
	var condition:Expr
	var _then:Array[Expr] = []
	var _else:Array[Expr] = []
	
	func _init(p_condition:Expr,p_then:Array[Expr],p_else:Array[Expr]) -> void:
		type = loader_lang.Type.IF
		condition = p_condition
		_then = p_then
		_else = p_else



##container for the whole program
class PROGRAM: 
	var class_n:String 
	var extends_n:String
	
	var has_class_or_extends:bool :
		get():
			return class_n != "" || extends_n != ""
	
	
	var globals:Array[varDecl_Statement]
	var functions:Array[funcDecl_Statement]
	
	##returns if functions/variables are declared yet / used for header stuff
	func contains_data():
		return globals.size() + functions.size() > 0
