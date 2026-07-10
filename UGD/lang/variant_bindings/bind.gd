class_name u_bindings
#godot doesnt expose the method bindings for built-ins so we gotta do this manually

#assigned on _init
var bindings:Dictionary[String,bind]

static func _bind(p_name:String,p_return_type:Variant.Type,p_args:Array[Variant.Type] = [],p_property := false):
	return bind.new(p_name,p_return_type,p_args,p_property)

func get_binding(name:String) -> Dictionary:
	if !bindings.has(name): return {}
	return bindings[name].get_bind()

class bind:
	var is_property = false
	var name:String
	var args:Array[Variant.Type] = []
	var return_type:Variant.Type
	

	func _init(p_name:String,p_return_type:Variant.Type,p_args:Array[Variant.Type] = [],p_property := false) -> void:
		name = p_name ; args = p_args ; return_type = p_return_type ; is_property = p_property

	#args, default_args, flags, id, name, return: (class_name, hint, hint_string, name, type, usage)
	func get_bind() -> Dictionary:
		if is_property:
			return {'name':name,'type':return_type}
		return {'args':bind_arg(),'name':name,'return':{'type':return_type,'class_name':''}}
	
	func bind_arg():
		var output = []
		for arg in args: output.append({'name':'','class_name ':'','type':arg,'hint_string':'','usage':6})
		return output
