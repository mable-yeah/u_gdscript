class_name script_loader
#TODO
#-add script loader hints through ::HINT_NAME
#ideally this would be through the tokenizer/lexer
#
#-move cursors/checks/peeks into their own classes that way both preprocessor and lexer can inherit from
#the same code that is written twice currently 
#(bonus points if i can make that work through the @abstract class stuff )

var DB = ClassDB

var source_code:String
var lex:lexer
var p_processor:preprocessor

const err_message = {
	STOPPED_AT = 'UGD scripting stopped at %s'
}

func load_string(code):
	source_code = lang_utilities.scrub_comments_C(code)
	lex = lexer.new(source_code,false)
	if lex.has_errors:
		printerr(err_message.STOPPED_AT % ('Tokenizer/Lexer, error count: %s' % lex.errors.size())) ; return
	p_processor = preprocessor.new(lex.tk_arr)
	if p_processor.has_errors:
		printerr(err_message.STOPPED_AT % 'Pre-processor') ; return
		
