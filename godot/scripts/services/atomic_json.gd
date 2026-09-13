class_name GameAtomicJSON
extends RefCounted
## Small atomic JSON store. A failed write leaves the previous file intact.

const MAX_BYTES: int = 16 * 1024 * 1024


static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return failure("File is missing or unreadable")
	if file.get_length() > MAX_BYTES:
		return failure("JSON file exceeds 16 MiB")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return failure("Invalid JSON at line %d" % parser.get_error_line())
	if not parser.data is Dictionary:
		return failure("Expected a JSON object")
	if not is_serializable(parser.data):
		return failure("JSON contains unsupported values or exceeds the nesting limit")
	return {"success": true, "data": decode(parser.data)}


static func write_file(path: String, value: Dictionary) -> Dictionary:
	if not is_serializable(value):
		return failure("State contains an unsupported or non-finite value")
	var payload := JSON.stringify(encode(value), "\t") + "\n"
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		return failure("JSON file exceeds 16 MiB")
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return failure("Cannot create the save directory")
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failure("Cannot open temporary save")
	file.store_string(payload)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return failure("Cannot write temporary save")
	var verified := read_file(temporary)
	if not verified.success:
		DirAccess.remove_absolute(temporary)
		return failure("Cannot verify temporary save")
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		return failure("Cannot replace the save file")
	return {"success": true}


static func failure(message: String) -> Dictionary:
	return {"success": false, "error": message}


static func is_serializable(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return is_finite(float(value.x)) and is_finite(float(value.y))
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			for item: Variant in value:
				if not is_serializable(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not is_serializable(value[key], depth + 1):
					return false
			return true
	return false


static func encode(value: Variant) -> Variant:
	if value is Vector2:
		return {"$vector2": [value.x, value.y]}
	if value is Vector2i:
		return {"$vector2i": [value.x, value.y]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = encode(value[key])
		return result
	if typeof(value) in [TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY]:
		var result: Array = []
		for item: Variant in value:
			result.append(encode(item))
		return result
	return value


static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		for tag: String in ["$vector2", "$vector2i"]:
			if value.size() == 1 and value.has(tag):
				var point: Variant = value[tag]
				if point is Array and point.size() == 2 and is_number(point[0]) and is_number(point[1]):
					if tag == "$vector2i":
						return Vector2i(int(point[0]), int(point[1]))
					return Vector2(float(point[0]), float(point[1]))
		var result: Dictionary = {}
		for key: String in value:
			result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(decode(item))
		return result
	return value


static func is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func is_integer(value: Variant) -> bool:
	return is_number(value) and float(value) == floorf(float(value))


static func is_point(value: Variant) -> bool:
	return (value is Vector2 or value is Vector2i) or (value is Dictionary and is_number(value.get("x")) and is_number(value.get("y")))
