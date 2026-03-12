class_name compiler extends AST.PROGRAM

var has_errors := false
var code:String = ''

var indentation:int = 0
func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)
	return

func _init(p_ast:AST.PROGRAM) -> void:
	self.class_n =  p_ast.class_n
	self.extends_n = p_ast.extends_n
	self.globals = p_ast.globals
	self.functions = p_ast.functions
	
	for global in globals:
		print(global.accept())
	
	for function in functions:
		print(function.accept())
