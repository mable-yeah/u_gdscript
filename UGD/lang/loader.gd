class_name script_loader

#TODO
#-add script loader hints through ::HINT_NAME
#ideally this would be through the tokenizer/lexer i.e before any other operations happen
#
#-move cursors/checks/peeks into their own classes that way both preprocessor and lexer can inherit from
#the same code that is written twice currently 
#(bonus points if i can make that work through the @abstract class stuff )

#-add error lines in the code i.e 'INVALID_THING <--  at line %s column %s'


var DB = ClassDB

var source_code:String

var program_ast:AST.PROGRAM

var p_lexer:lexer
var p_processor:preparser
var p_compiler:compiler

const err_message = {
	STOPPED_AT = 'UGD scripting stopped at %s .'
}

func load_string(code):
	source_code = lang_utilities.scrub_comments_C(code)
	
	p_lexer = lexer.new(source_code)
	if p_lexer.has_errors:
		printerr(err_message.STOPPED_AT % ('Tokenizer/Lexer, error count: %s' % p_lexer.errors.size())) ; return
	
	p_processor = preparser.new(p_lexer.tk_arr)
	if p_processor.has_errors:
		printerr(err_message.STOPPED_AT % 'Pre-parser') ; return
	program_ast = p_processor.program
	
	p_compiler = compiler.new(program_ast)
	if p_compiler.has_errors:
		printerr(err_message.STOPPED_AT % 'Compiler') ; return

##packs the given string as a node
##WARNING this doesn't error handle the code itself, thats what load_string() is for
func pack_string_as_node(code:String,node:Variant = RefCounted.new()):
	if code == '' || node == null:
		return
	var script = GDScript.new()
	script.set_source_code(code)
	script.reload()
	node.set_script(script)
	return node
