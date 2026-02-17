class_name compiler 

var has_errors := false
var program:AST.PROGRAM
var code:String = ''

func _init(p_program:AST.PROGRAM) -> void:
	program = p_program

func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)
	return
