class_name u_Array extends u_bindings

func _init() -> void:
	bindings = {
	'hash':_bind('hash',TYPE_INT),
	'is_empty':_bind('is_empty',TYPE_BOOL),
	
	'get':_bind('get',TYPE_MAX,[TYPE_INT]),
	'has':_bind('has',TYPE_BOOL,[TYPE_MAX]),
	
	'insert':_bind('insert',TYPE_INT,[TYPE_INT,TYPE_MAX]),
	
	'pop_back':_bind('pop_back',TYPE_MAX),
	'pop_front':_bind('pop_back',TYPE_MAX),
	
	'push_back':_bind('pop_back',TYPE_NIL,[TYPE_MAX]),
	'push_front':_bind('pop_back',TYPE_NIL,[TYPE_MAX]),
	
	'remove_at':_bind('remove_at',TYPE_NIL,[TYPE_INT]),
	'resize':_bind('resize',TYPE_INT,[TYPE_INT]),
	
	'duplicate':_bind('duplicate',TYPE_ARRAY,[TYPE_BOOL]),
	'clear':_bind('clear',TYPE_NIL),
	'erase':_bind('erase',TYPE_NIL,[TYPE_MAX]),
	'fill':_bind('fill',TYPE_NIL,[TYPE_MAX])
}
