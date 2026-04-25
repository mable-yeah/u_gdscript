class_name ugd_globalscope
##this class exists to expose globalscope methods to ugd
##all of these functions should return dummy values
##as they arent the actual functions being used

@warning_ignore("unused_parameter")
func print(...arg) -> void:
	pass

@warning_ignore("unused_parameter")
func Vector2(x:float,y:float) -> Vector2:
	return Vector2()


@warning_ignore("unused_parameter")
func add_child(child:Node) -> void:
	pass


@warning_ignore("unused_parameter")
func Vector2i(x:int,y:int) -> Vector2i:
	return Vector2i()
