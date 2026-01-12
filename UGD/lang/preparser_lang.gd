class_name preparser_lang


#about half of these are not usable BUT im declaring them just in case i wanna fix them later
const annotation_list := {
#script annotations
"tool":preprocessor.ANNOTATION_NODE.TargetKind.SCRIPT,
"icon":preprocessor.ANNOTATION_NODE.TargetKind.SCRIPT,
"static_unload":preprocessor.ANNOTATION_NODE.TargetKind.SCRIPT,
"abstract":preprocessor.ANNOTATION_NODE.TargetKind.SCRIPT | preprocessor.ANNOTATION_NODE.TargetKind.CLASS | preprocessor.ANNOTATION_NODE.TargetKind.FUNCTION,
#variable/export annotations
"onready":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_enum":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_file":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_file_path":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_dir":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_global_file":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_global_dir":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_multiline":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_placeholder":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_range":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_exp_easing":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_color_no_alpha":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_node_path":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_2d_render":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_2d_physics":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_2d_navigation":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_3d_render":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_3d_physics":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_3d_navigation":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_flags_avoidance":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_storage":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_custom":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
"export_tool_button":preprocessor.ANNOTATION_NODE.TargetKind.VARIABLE,
#export category 
"export_category":preprocessor.ANNOTATION_NODE.TargetKind.STANDALONE,
"export_group":preprocessor.ANNOTATION_NODE.TargetKind.STANDALONE,
"export_subgroup":preprocessor.ANNOTATION_NODE.TargetKind.STANDALONE,
#warning
"warning_ignore":preprocessor.ANNOTATION_NODE.TargetKind.CLASS_LEVEL | preprocessor.ANNOTATION_NODE.TargetKind.STATEMENT ,
"warning_ignore_start":preprocessor.ANNOTATION_NODE.TargetKind.STANDALONE,
"warning_ignore_restore":preprocessor.ANNOTATION_NODE.TargetKind.STANDALONE,
#networking
"rpc":preprocessor.ANNOTATION_NODE.TargetKind.FUNCTION
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
