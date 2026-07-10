class_name loader_lang ##extra language enums/functions that dont belong to any specific loader resource


enum Operation {
	OP_MINUS,
	OP_DIVIDE,
	OP_MULTIPLY,
	OP_PLUS,
	OP_NEGATIVE,
	OP_NOT,
	OP_ADDITION,
	OP_SUBTRACTION,
	OP_MULTIPLICATION,
	OP_DIVISION,
	OP_MODULO,
	OP_POWER,
	OP_BIT_LEFT_SHIFT,
	OP_BIT_RIGHT_SHIFT,
	OP_BIT_AND,
	OP_BIT_OR,
	OP_BIT_XOR,
	OP_LOGIC_AND,
	OP_LOGIC_OR,
	OP_LOGIC_EQUAL,
	OP_CONTENT_TEST,
	OP_COMP_EQUAL,
	OP_COMP_NOT_EQUAL,
	OP_COMP_LESS,
	OP_COMP_LESS_EQUAL,
	OP_COMP_GREATER,
	OP_COMP_GREATER_EQUAL,
};


enum Type {
	NONE,
	IDENTIFIER,
	LITERAL,
	MEMBER_CALL,
	FUNC_CALL,
	ENUM,
	ASSIGNMENT,
	UNARY_OPERATOR,
	ARRAY,
	DICTIONARY,
	TERNARY_OPERATOR,
	FUNCTION,
	VARIABLE,
	PASS,
	RETURN,
	CONTINUE,
	BREAK,
	EXPRESSION,
	FOR,
	IF,
	WHILE,
	INDEX
}

static var global_class_registry:Dictionary[String,Dictionary]:
	get():
		if global_class_registry.is_empty():
			build_global_class_list()
		return global_class_registry


static var global_class_list:PackedStringArray:
	get():
		if global_class_registry.is_empty():
			build_global_class_list()
		return global_class_registry.keys()

static var class_list:PackedStringArray:
	get():
		if class_list.is_empty():
			build_class_list()
		return class_list

static var built_in_types:Dictionary[String,Variant.Type] = {}:
	get():
		if built_in_types.is_empty():
			build_built_in_types()
		return built_in_types




static func build_class_list():
	class_list = ClassDB.get_class_list()

static func build_global_class_list():
	var class_packed:Dictionary[String,Dictionary] = {}
	for class_data in ProjectSettings.get_global_class_list():
		class_packed[class_data['class']] = class_data
	global_class_registry = class_packed

static func build_built_in_types():
	var types:Dictionary[String,Variant.Type] = {}
	for i in Variant.Type.TYPE_MAX:
		var type = i as Variant.Type
		types[type_string(type)] = type
	built_in_types = types

static func list_classes():
	print(class_list) ; print(global_class_list)
