class_name u_Vector2i extends u_bindings


func _init() -> void:
	bindings = {
	'abs': _bind('abs', TYPE_VECTOR2I),
	'aspect': _bind('aspect', TYPE_FLOAT),
	'clamp': _bind('clamp', TYPE_VECTOR2I, [TYPE_VECTOR2I, TYPE_VECTOR2I]),
	'clampi': _bind('clampi', TYPE_VECTOR2I, [TYPE_INT, TYPE_INT]),
	'distance_squared_to': _bind('distance_squared_to', TYPE_INT, [TYPE_VECTOR2I]),
	'distance_to': _bind('distance_to', TYPE_FLOAT, [TYPE_VECTOR2I]),
	'length': _bind('length', TYPE_FLOAT),
	'length_squared': _bind('length_squared', TYPE_INT),
	'max': _bind('max', TYPE_VECTOR2I, [TYPE_VECTOR2I]),
	'max_axis_index': _bind('max_axis_index', TYPE_INT),
	'maxi': _bind('maxi', TYPE_VECTOR2I, [TYPE_INT]),
	'min': _bind('min', TYPE_VECTOR2I, [TYPE_VECTOR2I]),
	'min_axis_index': _bind('min_axis_index', TYPE_INT),
	'mini': _bind('mini', TYPE_VECTOR2I, [TYPE_INT]),
	'sign': _bind('sign',TYPE_VECTOR2I),
	'snapped': _bind('snapped', TYPE_VECTOR2I, [TYPE_VECTOR2I]),
	'snappedi': _bind('snappedi', TYPE_VECTOR2I, [TYPE_INT]),

	'x': _bind('x', TYPE_INT, [],true),
	'y': _bind('y', TYPE_INT, [],true),
}
