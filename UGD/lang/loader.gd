class_name script_loader


static var scripts:Dictionary[String,GDScript] = {}

const err = {
	STOPPED_AT = 'UGD scripting stopped at %s .',
	CRITICAL = 'ugd critical script error, %s'
}

static func load_string(code:String,className:String) -> Variant:
	code = lang_utilities.scrub_comments_C(code)
	
	var p_lexer = lexer.new(code)
	if p_lexer.has_errors:
		printerr(err.STOPPED_AT % ('Tokenizer/Lexer, error count: %s' % p_lexer.errors.size())) ; return
	
	var p_processor = preparser.new(p_lexer.tk_arr)
	if p_processor.has_errors:
		printerr(err.STOPPED_AT % 'Pre-processor') ; return null
	
	var program_ast = p_processor.program
	var p_compiler = compiler.new(program_ast,className)
	if p_compiler.has_errors:
		printerr(err.STOPPED_AT % 'Compiler') ; return null
	
	#return null
	return pack_string_as_node(p_compiler.code,className)



##packs the given string as a node
##WARNING this doesn't error handle the code itself, thats what load_string() is for
static func pack_string_as_node(code:String,p_class:String) -> Variant:
	var node:Object = ClassDB.instantiate(p_class)
	var sha = code.sha1_text()
	if code == '' || node == null: return null
	
	if scripts.has(sha): node.set_script(scripts[sha]) ; return node
	
	var script = GDScript.new()
	script.set_source_code(code)
	var err_script = script.reload()
	
	
	###ok i lied it DOES error check but only for super serious things that pass every thing else
	##also its not very discriptive when it does check
	if err_script != OK: 
		var msg = err.CRITICAL % error_string(err_script)
		OS.alert(msg) ; OS.crash(msg)

	node.set_script(script)
	scripts[sha] = script
	return node

#NOTE: keeping scripts cached 
#(especially ones that arent being reloaded with new code constantly like in the example scene), 
#is actually better than clearing it when reloading a scene!
#as an internal reference to a script is always kept if it ends up being used anywhere
#I THINK, thats just a theory though
#so basicawwy just clear the node on reload and keep the cache
static func clear_scripts():
	scripts.clear()
