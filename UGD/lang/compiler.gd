class_name compiler extends AST.PROGRAM

var has_errors := false
var code:String = ''



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
	self.misc = p_ast.misc
	pack_code()


func pack_code():
	var packed:PackedStringArray = []
	var class_st = 'class_name %s' % class_n
	if class_n != '':  packed.append(class_st)
	if contains_data():
		for expression in globals + misc + functions:
			packed.append(expression.accept())
	
	print('\n'.join(packed))
	return '\n'.join(packed)
