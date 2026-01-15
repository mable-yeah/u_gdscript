class_name preprocessor
var tk_arr:Array[tokens.token] = []
var length:int:
	get():
		return tk_arr.size()


var cursor := 0
var current_token:tokens.token = null

var errors = []

var has_errors:bool:
	get():
		return !errors.is_empty()


const tk_type = tokens.type



func _init(p_tk:Array[tokens.token]) -> void:
	tk_arr = p_tk
	evaluate_program()

func evaluate_program():
	while cursor < length:
		if current_token == null:
			advance()
		

func check(type:tk_type):
	if is_at_end(): return false
	return peek().type == type


func make_error(st:String) -> void:
	printerr(st)
	errors.push_back(st)
	return 

func previous() -> tokens.token:
	return tk_arr.get(cursor - 1)

func peek() -> tokens.token:
	return tk_arr.get(cursor)

func advance() -> void:
	if is_at_end():
		return
	cursor += 1
	current_token = previous()


func is_at_end() -> bool:
	return cursor >= length
