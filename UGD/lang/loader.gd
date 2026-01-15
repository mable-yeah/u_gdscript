class_name script_loader

var DB = ClassDB

var source_code:String
var lex:lexer
var p_processor:preprocessor
func load_script(code):
	source_code = code
	@warning_ignore("unused_variable")
	lex = lexer.new(source_code,false)
	#if lex.contains_error:
		#return
	#p_processor = preprocessor.new(lex.tk_arr)
