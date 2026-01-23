class_name preparser_lang



enum Operation {
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
	ANNOTATION,
	ARRAY,
	ASSERT,
	ASSIGNMENT,
	AWAIT,
	BINARY_OPERATOR,
	BREAK,
	BREAKPOINT,
	CALL,
	CAST,
	CLASS,
	CONSTANT,
	CONTINUE,
	DICTIONARY,
	ENUM,
	FOR,
	FUNCTION,
	GET_NODE,
	IDENTIFIER,
	IF,
	LAMBDA,
	LITERAL,
	MATCH,
	MATCH_BRANCH,
	PARAMETER,
	PASS,
	PATTERN,
	PRELOAD,
	RETURN,
	SELF,
	SIGNAL,
	SUBSCRIPT,
	SUITE,
	TERNARY_OPERATOR,
	TYPE,
	TYPE_TEST,
	UNARY_OPERATOR,
	VARIABLE,
	WHILE,
}

enum TargetKind {
	NONE = 0,
	SCRIPT = 1 << 0,
	CLASS = 1 << 1,
	VARIABLE = 1 << 2,
	CONSTANT = 1 << 3,
	SIGNAL = 1 << 4,
	FUNCTION = 1 << 5,
	STATEMENT = 1 << 6,
	STANDALONE = 1 << 7,
	CLASS_LEVEL = CLASS | VARIABLE | CONSTANT | SIGNAL | FUNCTION,
}

#about half of these are not usable BUT im declaring them just in case i wanna fix them later
const annotation_list := {
#script annotations
"tool":TargetKind.SCRIPT,
"icon":TargetKind.SCRIPT,
"static_unload":TargetKind.SCRIPT,
"abstract":TargetKind.SCRIPT | TargetKind.CLASS | TargetKind.FUNCTION,
#variable/export annotations
"onready":TargetKind.VARIABLE,
"export":TargetKind.VARIABLE,
"export_enum":TargetKind.VARIABLE,
"export_file":TargetKind.VARIABLE,
"export_file_path":TargetKind.VARIABLE,
"export_dir":TargetKind.VARIABLE,
"export_global_file":TargetKind.VARIABLE,
"export_global_dir":TargetKind.VARIABLE,
"export_multiline":TargetKind.VARIABLE,
"export_placeholder":TargetKind.VARIABLE,
"export_range":TargetKind.VARIABLE,
"export_exp_easing":TargetKind.VARIABLE,
"export_color_no_alpha":TargetKind.VARIABLE,
"export_node_path":TargetKind.VARIABLE,
"export_flags":TargetKind.VARIABLE,
"export_flags_2d_render":TargetKind.VARIABLE,
"export_flags_2d_physics":TargetKind.VARIABLE,
"export_flags_2d_navigation":TargetKind.VARIABLE,
"export_flags_3d_render":TargetKind.VARIABLE,
"export_flags_3d_physics":TargetKind.VARIABLE,
"export_flags_3d_navigation":TargetKind.VARIABLE,
"export_flags_avoidance":TargetKind.VARIABLE,
"export_storage":TargetKind.VARIABLE,
"export_custom":TargetKind.VARIABLE,
"export_tool_button":TargetKind.VARIABLE,
#export category 
"export_category":TargetKind.STANDALONE,
"export_group":TargetKind.STANDALONE,
"export_subgroup":TargetKind.STANDALONE,
#warning
"warning_ignore":TargetKind.CLASS_LEVEL | TargetKind.STATEMENT ,
"warning_ignore_start":TargetKind.STANDALONE,
"warning_ignore_restore":TargetKind.STANDALONE,
#networking
"rpc":TargetKind.FUNCTION
}






static var global_class_list:Array[Dictionary]:
	get():
		if global_class_list.is_empty():
			build_global_class_list()
		return global_class_list

static var class_list:PackedStringArray:
	get():
		if class_list.is_empty():
			build_class_list()
		return class_list

static var built_in_types:Dictionary[String,Variant.Type] = {}

static func build_class_list():
	if class_list.is_empty():
		class_list = ClassDB.get_class_list()

static func build_global_class_list():
	if global_class_list.is_empty():
		global_class_list = ProjectSettings.get_global_class_list()
