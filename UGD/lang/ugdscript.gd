class_name UGDScript
extends GDScript


func _init(code):
	set_source_code(code)
	reload(code)
