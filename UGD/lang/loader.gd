class_name script_loader
#TODO
#add script loader hints through ::HINT_NAME
#ideally this would be through the tokenizer 


var DB = ClassDB

var source_code:String
var lex:lexer
var p_processor:preprocessor

func load_string(code):
	source_code = lang_utilities.scrub_comments_C(code)
	lex = lexer.new(source_code,false)
	if lex.contains_error:
		return
	p_processor = preprocessor.new(lex.tk_arr)
