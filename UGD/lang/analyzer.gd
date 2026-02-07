class_name analyzer ##analyzes the current program's AST and validates/invalidates it

var has_errors := false
var program:AST.PROGRAM


func _init(p_program:AST.PROGRAM) -> void:
	program = p_program
	analyze()

func analyze():
	validate_header()
	if has_errors:return
	if !program.contains_data():return



func validate_header():
	if !program.has_class_or_extends:return
	if program.class_n != "" and lang_utilities.is_class_or_type(program.class_n):
		make_error('class name reflects a built in type/class: "%s"' %program.class_n) ; return
	if program.extends_n != "" and !lang_utilities.is_class_or_type(program.extends_n,false):
		make_error('could not find base class: "%s"' %program.extends_n) ; return


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Analyzer error: \' %s \''
	printerr(generic % st)
	return 
