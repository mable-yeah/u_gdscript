class_name u_Dictionary extends u_bindings

func _init() -> void:
	bindings = {
		'hash':_bind('hash',TYPE_INT),
		'is_empty':_bind('is_empty',TYPE_BOOL),
		
		'get':_bind('get',TYPE_MAX,[TYPE_MAX,TYPE_MAX]),
		'get_or_add':_bind('get',TYPE_MAX,[TYPE_MAX,TYPE_MAX]),
		
		'has':_bind('has',TYPE_BOOL,[TYPE_MAX]),
		'erase':_bind('erase',TYPE_BOOL,[TYPE_MAX]),
		'duplicate':_bind('duplicate',TYPE_DICTIONARY,[TYPE_BOOL]),
		'clear':_bind('clear',TYPE_NIL)
	}
