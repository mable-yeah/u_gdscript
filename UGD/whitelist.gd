class_name Whitelist

const list = [
	'Node',
	'ColorRect',
	'Time',
	'Timer',
	
]


static func available(name:String):
	return name in list
