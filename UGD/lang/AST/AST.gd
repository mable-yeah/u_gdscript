class_name AST ##contains classes needed to form expression tree's

#jane 'jumpy jane' remover save me !!


##base expression class, all expressions extend this
@abstract class Expr:
	var is_valid:bool = false
	
	var reduced_value:Variant = null
	var _tk_st:String = "NONE"
	var type:loader_lang.Type = loader_lang.Type.NONE:
		set(p_type):
			type = p_type
			_tk_st = get_type_name()
	
	
	func type_is(p_type:loader_lang.Type) -> bool:
		return type == p_type
	
	
	func get_type_name() -> String:
		return loader_lang.Type.keys()[type]
	
	var visitor = AST_visitor
	
	
	@abstract func accept() -> String

##basic variable name reference
class variable extends Expr: 
	var name:String = ''
	
	func _init(p_name:String) -> void:
		name = p_name
		type = loader_lang.Type.IDENTIFIER
	
	func accept():
		return visitor.visit_variable(self)
	
	

##basic literal
class literal extends Expr:
	var literal_type:Variant.Type = Variant.Type.TYPE_NIL
	var variant:Variant = null
	
	
	func _init(p_variant:Variant) -> void:
		variant = p_variant
		literal_type = typeof(p_variant) as Variant.Type
		type = loader_lang.Type.LITERAL
	
	func accept():
		return visitor.visit_literal(self)


##'target(argument)'
class function_call extends Expr: 
	var target:Expr
	var args:Array[Expr]
	
	func _init(p_target:Expr,arguments:Array[Expr] = []) -> void:
		type = loader_lang.Type.FUNC_CALL
		target = p_target
		args = arguments

	func accept():
		return visitor.visit_function_call(self)

##'target.function'
class member_Call extends Expr: 
	var target:Expr
	var member:Expr
	
	func _init(p_target:Expr,arg:Expr) -> void:
		type = loader_lang.Type.MEMBER_CALL
		target = p_target
		member = arg

	func accept():
		return visitor.visit_member_call(self)


##enum foo {bar,fungus = 1}
class enumerator extends Expr: 
	var name:String
	var enumerators:Array[Dictionary] = []
	
	func _init(p_name:String,p_enum:Array[Dictionary]) -> void:
		type = loader_lang.Type.ENUM
		enumerators = p_enum
		name = p_name
	
	func accept():
		return visitor.visit_enum(self)

##arr[expression]
class index extends Expr: 
	var target:Expr
	var idx:Expr
	
	func _init(p_target:Expr,p_ind:Expr) -> void:
		type = loader_lang.Type.INDEX
		target = p_target 
		idx = p_ind
	
	func accept():
		return visitor.visit_index(self)


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
	
	func accept():
		return visitor.visit_assignment(self)

##-(1 - 1) || !(1 - 1)
class unary extends Expr:
	var op:loader_lang.Operation #OP_NEGATIVE or OP_NOT
	var operand:Expr
	
	func _init(p_operand:Expr,OP:loader_lang.Operation) -> void:
		type = loader_lang.Type.UNARY_OPERATOR
		op = OP
		operand = p_operand
	
	func accept():
		return visitor.visit_unary(self)


##[value1,value2]
class array extends Expr:
	var elements:Array[Expr] = []
	
	func _init() -> void:
		type = loader_lang.Type.ARRAY

	
	func accept():
		return visitor.visit_array(self)

##{0 = 'string'} || {0 : true}
class dictionary extends Expr:
	enum styling {
		NONE,
		PYTHON_DICT,
		LUA_TABLE
	}
	
	var style:styling = styling.NONE
	var elements:Dictionary = {}
	
	func decide_style(EQUAL:bool,COLON:bool): #called inside of the preparser
		if style != styling.NONE:
			return 
		if EQUAL:
			style = styling.PYTHON_DICT
		elif COLON:
			style = styling.LUA_TABLE

	func _init() -> void:
		type = loader_lang.Type.DICTIONARY
	
	func accept():
		return visitor.visit_dictionary(self)

##x if z else y
class ternary extends Expr:
	var target:Expr #x
	var left:Expr #z
	var right:Expr #y
	#x if bool_here else y
	
	func _init(p_target:Expr,p_left:Expr,p_right:Expr) -> void:
		type = loader_lang.Type.TERNARY_OPERATOR
		target = p_target
		left = p_left
		right = p_right
	
	
	func accept():
		return visitor.visit_ternary(self)


#STATEMENT EXPR

##func statement() (-> hint?) : body
class funcDecl_Statement extends Expr:
	var name = ""
	var type_hint:TOKENS.token # -> (TYPE)
	var params:Dictionary[String,varDecl_Statement]
	var body:Array[Expr] = []
	
	func _init() -> void:
		type = loader_lang.Type.FUNCTION

	
	func accept():
		return visitor.visit_func_decl(self)

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

	
	func accept(needs_body := true):
		return visitor.visit_var_decl(self,needs_body)
class pass_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.PASS

	
	func accept():
		return visitor.visit_pass(self)

class cont_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.CONTINUE

	
	func accept():
		return visitor.visit_continue(self)

class break_Statement extends Expr:
	func _init() -> void:
		type = loader_lang.Type.BREAK

	
	func accept():
		return visitor.visit_break(self)

class expression_Statement extends Expr:
	var expression:Expr
	
	func _init(p_expr:Expr) -> void:
		type = loader_lang.Type.EXPRESSION
		expression = p_expr

	
	func accept():
		return visitor.visit_expression(self)

class return_Statement extends Expr:
	var expression:Expr = null
	func _init(p_expr:Expr = null) -> void:
		type = loader_lang.Type.RETURN
		expression = p_expr
		
	func accept():
		return visitor.visit_return(self)

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
	
	func accept():
		return visitor.visit_for(self)

##while condition: body
class while_Statement extends Expr:
	var condition:Expr
	var body:Array[Expr]
	
	func _init(p_condition:Expr,p_body:Array[Expr]) -> void:
		type = loader_lang.Type.WHILE
		condition = p_condition
		body = p_body
	
	func accept():
		return visitor.visit_while(self)

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

	func accept():
		return visitor.visit_if(self)


##container for the whole program
class PROGRAM: 
	var class_n:String 
	var extends_n:String
	
	var has_class_or_extends:bool :
		get():
			return class_n != "" || extends_n != ""
	
	var misc:Array[Expr] ##used for any expression in the body that isnt a function or variable
	var globals:Array[varDecl_Statement] ##used for variants declared in the class body
	var functions:Array[funcDecl_Statement] ##used for functions declared
	
	##returns if functions/variables are declared yet / used for header stuff
	func contains_data():
		return globals.size() + functions.size() + misc.size() > 0
