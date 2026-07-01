class_name script_loader

static var sha_cache:Dictionary[String,GDScript] = {}

const err = {
	STOPPED_AT = 'UGD scripting stopped at %s .',
	CRITICAL = 'ugd critical script error, %s'
}

static func load_string(code:String,className:String,cache:bool = false) -> Variant:
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
	
	return pack_string_as_node(p_compiler.code,className,cache)





##packs the given string as a node
##WARNING this only throws an error if code seriously goes wrong 
##(something that cant be caught through the loader steps)
static func pack_string_as_node(code:String,p_class:String,cache:bool = false) -> Variant:
	p_class = lang_utilities.get_base_class(p_class)
	var node:Object = ClassDB.instantiate(p_class)
	var sha = code.sha1_text()
	if code == '' || node == null: return null
	
	if sha in sha_cache and cache:
		node.set_script(sha_cache[sha]) ; return node
	
	var script = GDScript.new() ; script.set_source_code(code)
	var err_script = script.reload() ; script.unreference() 
	#godot keeps a spere ref in reload(), so just unref it
	
	if err_script != OK: 
		var msg = err.CRITICAL % error_string(err_script)
		OS.alert(msg) ; OS.crash(msg)
		return null
	if cache: sha_cache[sha] = script
	node.set_script(script)
	return node

static func empty_cache(clean_lang := false) -> void: 
	if clean_lang: clean_lang_cache()
	sha_cache.clear()


static func clean_lang_cache():
	loader_lang.global_class_list.clear()
	loader_lang.class_list.clear()
	loader_lang.built_in_types.clear()
