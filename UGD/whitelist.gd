class_name Whitelist

const list = [
	'Node',
	'Control',
	'ColorRect',
	'Time',
	'Timer',
	
]


static func available(name:String):
	return name in list
