class_name u_Vector3i extends u_bindings


func _init() -> void:
	bindings = {
	'abs': _bind('abs', TYPE_VECTOR3I),
	'clamp': _bind('clamp', TYPE_VECTOR3I, [TYPE_VECTOR3I, TYPE_VECTOR3I]),
	'clampi': _bind('clampi', TYPE_VECTOR3I, [TYPE_INT, TYPE_INT]),
	'distance_squared_to': _bind('distance_squared_to', TYPE_INT, [TYPE_VECTOR3I]),
	'distance_to': _bind('distance_to', TYPE_FLOAT, [TYPE_VECTOR3I]),
	'length': _bind('length', TYPE_FLOAT),
	'length_squared': _bind('length_squared', TYPE_INT),
	'max': _bind('max', TYPE_VECTOR3I, [TYPE_VECTOR3I]),
	'max_axis_index': _bind('max_axis_index', TYPE_INT),
	'maxi': _bind('maxi', TYPE_VECTOR3I, [TYPE_INT]),
	'min': _bind('min', TYPE_VECTOR3I, [TYPE_VECTOR3I]),
	'min_axis_index': _bind('min_axis_index', TYPE_INT),
	'mini': _bind('mini', TYPE_VECTOR3I, [TYPE_INT]),
	'sign': _bind('sign',TYPE_VECTOR3I),
	'snapped': _bind('snapped', TYPE_VECTOR3I, [TYPE_VECTOR3I]),
	'snappedi': _bind('snappedi', TYPE_VECTOR3I, [TYPE_INT]),
	
	
	'x': _bind('x', TYPE_INT, [],true),
	'y': _bind('y', TYPE_INT, [],true),
	'z': _bind('z', TYPE_INT, [],true),
}
