class_name compiler #reconstructs the ast back into gd script

var has_errors := false
var program:AST.PROGRAM

var script_tree := tree.new()

var indentation := 0


class tree:
	var global_scope:Array[String] = []
	var current_scope:Array[String] = []
	
	func variant_exists(variant_name:String):
		return (global_scope + current_scope).has(variant_name)
	
	
	var base:Array[tree_expression] = []
	
	func add_scope(name:String):
		current_scope.append(name)
	
	func append(expression:tree_expression,name:String = '',global = false):
		base.push_back(expression)
		
		if name != '':
			if global:
				global_scope.push_back(name)
				return
			current_scope.push_back(name)
	
	##returns tree as strings
	func get_tree() -> PackedStringArray:
		var compiled:PackedStringArray = []
		for expression in base:
			compiled.push_back(expression.get_code())
		return compiled

#i love glorified containers !!! ! !
class tree_expression:
	var indentation_level:= 0
	var code:String = ''
	
	func _init(p_code:String,p_ind:int) -> void:
		indentation_level = p_ind
		code = p_code
	
	func indent(st:String,level = 0) -> String:
		if level == 0: return st
		return st.indent('\t'.repeat(level))
	
	#returns code indented
	func get_code() -> String:
		return indent(code,indentation_level)



func _init(p_program:AST.PROGRAM) -> void:
	program = p_program
	compile()

func compile():
	#validate_header()
	#if has_errors:return
	if !program.contains_data():return
	
	#no point in doing these seperatley as theyre parsed the same way
	for variant in program.globals + program.functions:
		pass
	print('\n'.join(script_tree.get_tree()))




##gets string from type hint token
func get_type_hint(tk:TOKENS.token) -> String:
	if tk == null:return ""
	const types = TOKENS.type
	match tk.type:
		types.TK_VOID:
			return 'void'
		types.IDENTIFIER:
			return tk.literal
	make_error('could not determine type from token %s' % tk.get_name())
	return ""
	



func validate_header():
	if !program.has_class_or_extends:return
	if program.class_n != "" and lang_utilities.is_class_or_type(program.class_n):
		make_error('class name reflects a built in type/class: "%s"' %program.class_n) ; return
	script_tree.append(tree_expression.new('class_name %s' %program.class_n,0),'yeah',true)


func make_error(st:String) -> void:
	has_errors = true
	var generic = 'Analyzer error: \' %s \''
	printerr(generic % st)
	return






##not conchas; concha a big bag with one concha in it !
#func parse_expression(expr:AST.Expr,in_loop = false):
	#if expr == null: #should never happen ideally
		#make_error('expression is null in parse expression')
		#return
	#
	#if increase_next_expr:
		#indentation += 1
	#
	#if expr is AST.funcDecl_Statement:
		#var function_tree = []
		#function_tree.append(get_func_decl(expr)) #func foo(bar = 0) -> void:
		#if has_errors:return []
		#indentation += 1
		#for expression in expr.body:
			#function_tree.append(parse_expression(expression))
		#script_tree.reset_scope()
		#indentation = 0
		#return function_tree
	#
	#elif expr is AST.varDecl_Statement:
		#return get_var_decl(expr,true)
	#
	#elif expr is AST.pass_Statement:
		#return tree_expression.new('pass',indentation)
	#
	#elif expr is AST.cont_Statement:
		#if !in_loop:make_error('cannot use continue outside of loop')
		#return tree_expression.new('continue',indentation)
	#
	#elif expr is AST.break_Statement:
		#if !in_loop:make_error('cannot use break outside of loop')
		#return tree_expression.new('break',indentation)
	#
	#elif expr is AST.expression_Statement:
		#return parse_expression(expr.expression)
	#elif expr is AST.return_Statement:
		#var ret_v = ''
		#if expr.expression != null:
			#ret_v = parse_expression(expr.expression)
		#return tree_expression.new('return %s' % ret_v,indentation)
	#elif expr is AST.for_Statement:
		#pass
	#elif expr is AST.while_Statement:
		#pass
	#elif expr is AST.if_Statement:
		#var statement = tree_expression.new('if %s:' % parse_expression(expr.condition),indentation)
		#return statement
	#elif expr is AST.variable:
		#return expr.name
	#elif expr is AST.literal:
		#return str(expr.variant)
	#elif expr is AST.member_Call || expr is AST._call:
		#pass
	#elif expr is AST._enum:
		#pass
	#elif expr is AST.index:
		#pass
	#elif expr is AST.unary:
		#pass
	#elif expr is AST.array:
		#pass
	#elif expr is AST.dictionary:
		#pass
	#elif expr is AST.ternary:
		#return '%s if %s else %s' % [
			#parse_expression(expr.target),
			#parse_expression(expr.left),
			#parse_expression(expr.right)
			#]
	#elif expr is AST.binary_Statement || expr is AST.assignment: 
		#return "(%s %s %s)" % [ #grouping just cause its easier logically
			#parse_expression(expr.left),
			#get_op_st(expr.op),
			#parse_expression(expr.right)
		#]
	#else:
		#var err_st = 'expr not found in the expr chain %s' % expr.get_type_name()
		#make_error(err_st)
#
#func get_func_decl(expr:AST.funcDecl_Statement):
	#var type_hint:String = get_type_hint(expr.type_hint)
	#var params:PackedStringArray = []
	#
	#for param in expr.params.values():
		#var p_tree = get_var_decl(param,false)
		#if has_errors:break
		#params.push_back(p_tree.get_code())
		#script_tree.add_scope(param.name)
#
	#var hint_line:String = ' -> %s' % type_hint if type_hint != '' else ''
	#var param_line:String = '(%s)' % ','.join(params)
	#var line:String = 'func %s%s%s:' % [expr.name,param_line,hint_line]
	#return tree_expression.new(line,0)
#
#
#func get_var_decl(expr:AST.varDecl_Statement,needs_constructor = false):
	#var constructor_type = ('var' if !expr.is_constant else 'const') if needs_constructor else ''
	#var line = "%s %s" % [constructor_type,expr.name]
	#if expr.initializer != null:
		#line = "%s = %s" % [line,parse_expression(expr.initializer)]
		#
	#if script_tree.variant_exists(expr.name):
		#make_error('variant "%s" already exists in the current scope' % expr.name)
		#return null
	#return tree_expression.new(line,indentation) 


const op_enum = loader_lang.Operation
func get_op_st(op:op_enum) -> String:
	match op:
		op_enum.OP_ADDITION:return '+'
		op_enum.OP_SUBTRACTION:return  '-' 
		op_enum.OP_MULTIPLICATION:return  '*' 
		op_enum.OP_DIVISION:return  '/' 
		op_enum.OP_MODULO:return  '%' 
		op_enum.OP_POWER:return  '**' 
		op_enum.OP_BIT_LEFT_SHIFT:return  '<<' 
		op_enum.OP_BIT_RIGHT_SHIFT:return  '>>' 
		op_enum.OP_BIT_AND:return  '&' 
		op_enum.OP_BIT_OR:return  '|' 
		op_enum.OP_BIT_XOR:return  '^' 
		op_enum.OP_COMP_EQUAL:return  '==' 
		op_enum.OP_COMP_NOT_EQUAL:return  '!=' 
		op_enum.OP_COMP_LESS:return  '<' 
		op_enum.OP_COMP_LESS_EQUAL:return  '<=' 
		op_enum.OP_COMP_GREATER:return  '>' 
		op_enum.OP_COMP_GREATER_EQUAL:return  '>='
		op_enum.OP_LOGIC_OR: return '||'
		op_enum.OP_LOGIC_AND: return '&&'
		op_enum.OP_LOGIC_EQUAL: return '='
		_:make_error('operation not found %s' %  op); return ''
