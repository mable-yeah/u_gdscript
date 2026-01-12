class_name preprocessor

var tk_arr:Array[tokens.token] = []
var errors := []
var annotation_stack:Array[ANNOTATION_NODE] = []

var tk_length:int:
	get():
		return tk_arr.size()

var cursor := 0

var previous:tokens.token = null
var current_tk:tokens.token = null

var lambda_ended = false
var in_lambda = false
var class_end = false
var next_is_static = false
var current_class:Class_container




func _init(p_tk_arr:Array[tokens.token]) -> void:
	tk_arr = p_tk_arr
	parse_program()


func parse_program():
	
	current_class = Class_container.new()
	h_check_class_header()
	c_set(1)
	


func h_check_class_header():
	var tk = tokens.type
	while true:
		advance()
		match current_tk.type:
			tk.CLASS_NAME:
				if not current_class.class_name_defined:
					current_class.class_name_defined = true
					advance()
					if current_tk.type != tk.IDENTIFIER:
						make_error('expected identifier after class_name')
						return
					current_class.c_name = current_tk.literal
					advance()
					continue
				else:
					make_error('"class_name" can only be used once')
					return
			tk.EXTENDS:
				if not current_class.extends_defined:
					current_class.extends_defined = true
					advance()
					if current_tk.type != tk.IDENTIFIER:
						make_error('expected identifier after extends')
						return
					current_class.c_name = current_tk.literal
					advance()
					continue
				else:
					make_error('"extends" can only be used once')
					return
			tk.TK_EOF:
				break
			tk.ANNOTATION:
				var tk_ann = current_tk
				var annotation = parse_annotation(ANNOTATION_NODE.TargetKind.SCRIPT | ANNOTATION_NODE.TargetKind.CLASS_LEVEL | ANNOTATION_NODE.TargetKind.STANDALONE)
				if annotation == null:
					continue
				if annotation.applies_to(ANNOTATION_NODE.TargetKind.SCRIPT):
					if ["tool","icon",'static_unload'].has(tk_ann.literal):
						if current_class.can_extend_or_class_name:
							annotation.resolve() #resolve the annotation here cause it needs 2 be in the heade
							annotation_stack.push_back(annotation)
						else:
							make_error('annotation "%s" needs to be before extends/class_name' % tk_ann.literal)
							return
					else:
						make_error('unexpected annotation "%s"' % tk_ann.literal)
			_:
				continue





func parse_class():
	pass

func parse_class_body():
	pass

func parse_class_member():
	pass


func consume(p_tk_type:tokens.type, str_err:String):
	if tk_match(p_tk_type):
		return true
	push_error(str_err)
	return false


func check(p_tk_type:tokens.type,tk := current_tk) -> bool:
	if tk == null:
		return false
	if p_tk_type == tokens.type.IDENTIFIER:
		return tk.is_identifier()
	return tk.type == p_tk_type

func tk_match(p_tk_type:tokens.type) -> bool:
	if !check(p_tk_type):
		return false
	advance()
	return true

func is_statement_end_token() -> bool:
	return check(tokens.type.NEWLINE) || check(tokens.type.SEMICOLON) || check(tokens.type.TK_EOF)

func is_statement_end() -> bool:
	return lambda_ended || in_lambda || is_statement_end_token() 



func is_at_end():
	return check(tokens.type.TK_EOF)

func make_error(err_st:String):
	printerr(err_st)
	errors.push_back(err_st)

func peek(offset := 0) -> tokens.token:
	var p_cursor = cursor + offset
	if p_cursor >= 0 and p_cursor < tk_length:
		return tk_arr[p_cursor]
	return null

func advance() -> tokens.token:
	previous = current_tk
	current_tk = peek()
	cursor += 1
	return current_tk

func c_set(idx := 0):
	if idx >= 0 and idx <= tk_length:
		cursor = idx - 1
		advance()
		return
	printerr('preprocessor error, cursor location cannot be set to invalid index %s --> [0,%s]' % [idx,tk_length])


class Class_container:
	var c_name = ""
	var extends_defined = false
	var class_name_defined := false
	var can_extend_or_class_name :
		get():
			return false if extends_defined || class_name_defined  else true

#assign an annotation to ANNOTATION class type
func parse_annotation(p_valid_targets:int) -> ANNOTATION_NODE:
	var ann := ANNOTATION_NODE.new()

	ann.name = current_tk.literal
	advance()
	var valid := true
	if not preparser_lang.annotation_list.has(ann.name):
		make_error('annotation does not exist! "@%s"' % ann.name)
		valid = false
	
	if valid:
		ann.target_kind = preparser_lang.annotation_list.get(ann.name,-1)
		if !ann.applies_to(p_valid_targets):
			if ann.applies_to(ANNOTATION_NODE.TargetKind.SCRIPT):
				make_error('annotation %s must be applied to the top of the script, before "extends"/"class_name"' % ann.name)
			else:
				make_error('annotation "%s" is not allowed at this level' % ann.name)
			valid = false
	
	if check(tokens.type.PARENTHESIS_OPEN): #annotations with arguments are unsupported here
		make_error('unsupported annotation type "%s"' % ann.name)
		valid = false
		#im lazy ok, ++ most of these are for the editor anyways which the user shouldn't access (mostly)
	
	if valid:
		return ann
	else:
		return null



class ANNOTATION_NODE:
	var name = ""
	enum TargetKind {
		NONE = 0,
		SCRIPT = 1 << 0,
		CLASS = 1 << 1,
		VARIABLE = 1 << 2,
		CONSTANT = 1 << 3,
		SIGNAL = 1 << 4,
		FUNCTION = 1 << 5,
		STATEMENT = 1 << 6,
		STANDALONE = 1 << 7,
		CLASS_LEVEL = CLASS | VARIABLE | CONSTANT | SIGNAL | FUNCTION,
	}
	
	var resolved = false
	var target_kind = 0
	
	func applies_to(p_target: int) -> bool:
		return (target_kind & p_target) != 0
	
	
	func resolve():
		resolved = true
