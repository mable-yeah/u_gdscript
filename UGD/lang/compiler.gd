class_name compiler extends AST.PROGRAM
##handles AST analysis and re-compiling code into gd script

const errors = {
	'builtin':'Builtin type cannot be used as a name on its own -> "%s"',
	'unreachable':'unreachable code found in function "%s" after return',
	'func':'a function typed "%s" cannot return -> "%s"',
	'expected':'expected "%s" got -> "%s" instead in %s',
	'ternary':'Values of the ternary operator are not mutually compatible. %s -> %s',
	'assign':'invalid assignment from %s to %s',
	'loop':'cannot use "%s" from outside of a loop',
	'shadows':'%s shadows previously declared/internal class : "%s"'
}



var current_fn:AST.funcDecl_Statement = null

var loop_depth = 0
var scope:Array[Dictionary] = [{}]


const kind = u_object.kind


enum data_type {
	TYPE_NIL,
	TYPE_VOID,
	TYPE_OBJECT,
	TYPE_BOOL,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_ARRAY,
	TYPE_DICT,
	TYPE_ENUM,
}


#this is KIND of what im thinkin of doing here
#just putting out the commit just so i can have a fallback point
#to refrence when i fuck up
#SO BASICAWWY, the old compiler uses a shit ton of string comparison
#and i want to change that because its very very difficult to evaluate
#so instead things are seperated into "u_object's/ref's"
#that way i can instead just get the reference to an object/variable/function
#and call a function on that reference instead of calling something like
#'get_virtual_method' on the old compiler
#ALSO i need to support abstract methods too

#maybe also make a wrapper class for types
#like "u_kind" or something



var current_scope:Dictionary: 
	get(): return scope.back()


var has_errors := false
var code:String = ''
var base_class:String = ''


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Compiler error: \' %s \''
	printerr(generic % st)


func _init(p_ast:AST.PROGRAM,base_className:String) -> void:
	base_class = base_className
	self.class_n =  p_ast.class_n
	self.extends_n = p_ast.extends_n
	self.globals = p_ast.globals
	self.functions = p_ast.functions
	self.misc = p_ast.misc
	visit_code()
	if has_errors: return
	code = lang_utilities.pack_AST(self)
	print(code)

func visit_code():
	#get_builtins()
	if class_n != '': visit_header()
	if !contains_data() || has_errors: return
	
	
	#doin this so function declarations arent that linear
	#i.e u dont HAVE to have test() declared before _ready()
	#if u need to call test() inside _ready
	for stmt in functions:
		def_variable(u_object.new(stmt.name,kind.FUNCTION))
	
	for expression in (globals + misc + functions):
		expression.visit(self) 
		#visit calls one of the cooresponding functions here


func def_scope(): scope.append({})

func leave_scope(): scope.pop_back()

func scope_range(): return range(scope.size() - 1, -1, -1)


func def_variable(ref:u_object):
	if shadows_declared(ref.name): make_error(errors.shadows % [ref.typing(),ref.name])
	current_scope[ref.name] = ref

func shadows_declared(name:String) -> bool:
	var declared = is_declared(name)
	if lang_utilities.is_class_or_type(name,true,true): return true
	return declared

func is_declared(name:String) -> bool:
	return !(get_reference(name) == null)

func get_reference(name:String) -> u_object:
	for i in scope_range():
		if name in scope[i]: return scope[i][name]
	return null


func is_assignable(expr:AST.Expr,literal_allowed = true) -> bool:
	const type = loader_lang.Type
	var assignables = [
		type.IDENTIFIER,type.MEMBER_CALL,
		type.INDEX,type.ASSIGNMENT
	] 
	if literal_allowed: assignables.append(type.LITERAL)
	return expr.type in assignables


func visit_header():
	if !shadows_declared(class_n): return
	make_error('class name "%s", shadows an internal class/variable' % class_n)


func visit_var_decl(stmt:AST.varDecl_Statement):
	var ref = u_object.new(stmt.name,kind.VARIABLE)
	var type:data_type = data_type.TYPE_NIL
	ref.hint = lang_utilities.get_type_hint(stmt.type_hint)
	def_variable(ref)
	
	if stmt.initializer != null:
		type = stmt.initializer.visit(self) #process init first
		if type in [data_type.TYPE_NIL,data_type.TYPE_VOID]:
			make_error('invalid direct assignment of %s in %s' % [type,stmt.name])
			return ref.hint
		
		if stmt.initializer.type_is(loader_lang.Type.IDENTIFIER):
			if lang_utilities.is_builtin(stmt.initializer.name):
				make_error(errors.builtin % ('%s in %s' % [stmt.initializer.name,stmt.name]))
				return ref.hint
	
	elif stmt.is_constant: 
		make_error('constants need initializers "%s"' % stmt.name) ; return ref.hint
	if ref.hint != '' and stmt.initializer and as_string(type) != ref.hint:
		make_error('variable "%s" doesnt match type hint -> %s' % [stmt.name,ref.hint])
	
	return ref.hint

func visit_func_decl(stmt:AST.funcDecl_Statement):
	var ref := get_reference(stmt.name)
	var visited_return := false
	ref.hint = lang_utilities.get_type_hint(stmt.type_hint)
	
	current_fn = stmt
	def_scope()
	for param in stmt.params.values(): param.visit(self) 
	
	for expression in stmt.body:
		if visited_return and loop_depth == 0: 
			make_error(errors.unreachable % stmt.name) ; break
		expression.visit(self)
		if expression is AST.return_Statement: visited_return = true
	
	if !visited_return and !stmt.skip_processing: 
		var fallback = AST.return_Statement.new()
		fallback.visit(self)
		fallback = null
	
	leave_scope()
	current_fn = null
	
	return ref


func visit_variable(expr:AST.variable):
	if is_declared(expr.name): 
		return get_reference(expr.name).type
	
	if lang_utilities.is_class_or_type(expr.name): return expr.name
	
	make_error('variable reference does not exist in the current scope "%s"' % expr.name)
	return data_type.TYPE_NIL

class u_object:
	enum kind {
		FUNCTION,
		VARIABLE,
	}
	
	var type:kind
	var name:String
	var hint:String
	

	
	var meta = {}
	
	func _init(p_name:String,p_type:kind) -> void:
		name = p_name
		type = p_type
	
	
	func typing() -> String:
		return kind.keys()[type]


func as_string(type:data_type) -> String:
	var data = {
	data_type.TYPE_NIL:'null',
	data_type.TYPE_VOID:'void',
	data_type.TYPE_BOOL:'bool',
	data_type.TYPE_INT:'int',
	data_type.TYPE_FLOAT:'float',
	data_type.TYPE_STRING:'String',
	data_type.TYPE_ARRAY:'Array',
	data_type.TYPE_DICT:'Dictionary',
	data_type.TYPE_ENUM:'Enum',
	data_type.TYPE_OBJECT:'Object',
	}
	
	return data.get(type,data_type.TYPE_NIL)
