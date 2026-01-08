class_name script_loader

var DB = ClassDB

var source_code:String
var lex:lexer

func load_script(code):
	source_code = code
	@warning_ignore("unused_variable")
	lex = lexer.new(source_code,true)
	if lex.contains_error:
		return
