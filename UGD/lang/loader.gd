class_name script_loader

var DB = ClassDB

var source_code:String

func load_script(code):
	source_code = code
	@warning_ignore("unused_variable")
	var lex = lexer.new(source_code)
