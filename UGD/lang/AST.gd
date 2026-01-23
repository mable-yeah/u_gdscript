class_name AST

#jumpy jane save me

class Expr:
	var type:preparser_lang.Type = preparser_lang.Type.NONE

class VarDeclStatement extends Expr:
	var name = ""
	var type_hint:tokens.token
	var initializer = null #non constant values can be initialized as null
	var is_constant := false
	
	func _init() -> void:
		type = preparser_lang.Type.VARIABLE


#variable name reference 'x'
class variableExpr extends Expr:
	var name = ""
	func _init(p_name:String) -> void:
		name = p_name


#passing in the value 'true' should infer the type of 'bool',
#i.e passing in the string "true" should infer 'string' 
class literalExpr extends Expr:
	var literal_type:Variant.Type = Variant.Type.TYPE_NIL
	var variant:Variant = null
	
	
	func _init(p_variant:Variant) -> void:
		variant = p_variant
		literal_type = typeof(p_variant) as Variant.Type
		type = preparser_lang.Type.LITERAL
#-


class Assignment extends Expr:
	var left:Expr
	var op:preparser_lang.Operation
	var right:Expr
	
	func _init(LEFT:Expr,OP:preparser_lang.Operation,RIGHT:Expr) -> void:
		type = preparser_lang.Type.ASSIGNMENT
		left = LEFT
		op = OP
		right = RIGHT
		

class Unary extends Expr:
	enum Operation {OP_NEGATIVE,OP_NOT}
	
	var op:Operation
	var operand:Expr
	
	func _init(p_operand:Expr,OP:Operation) -> void:
		type = preparser_lang.Type.UNARY_OPERATOR
		op = OP
		operand = p_operand

class funcDeclStatement extends Expr:
	var name = ""
	var type_hint:tokens.token # -> (TYPE)
	var params:Array[VarDeclStatement]
	
	func _init() -> void:
		type = preparser_lang.Type.FUNCTION




class PROGRAM: 
	#these are dictionarys so i can double check for already declared variables/functions
	var globals:Dictionary[String,VarDeclStatement]
	var functions:Dictionary
