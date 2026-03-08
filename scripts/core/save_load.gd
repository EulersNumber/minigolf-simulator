## SaveLoad
## Handles reading and writing HoleData to/from JSON files.
class_name SaveLoad
extends RefCounted

const HOLES_DIR := "user://holes/"
const TEMPLATES_DIR := "res://data/templates/"

# ── Save ─────────────────────────────────────────────────────────────────────

static func save_hole(hole: HoleData, file_name: String) -> Error:
	_ensure_dir(HOLES_DIR)
	var path := HOLES_DIR + file_name
	if not path.ends_with(".json"):
		path += ".json"

	var json_string := JSON.stringify(hole.to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveLoad: cannot open '%s' for writing." % path)
		return FileAccess.get_open_error()

	file.store_string(json_string)
	file.close()
	return OK

# ── Load ─────────────────────────────────────────────────────────────────────

static func load_hole(path: String) -> HoleData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveLoad: cannot open '%s' for reading." % path)
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("SaveLoad: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return null

	return HoleData.from_dict(json.data)

# ── List ──────────────────────────────────────────────────────────────────────

static func list_saved_holes() -> Array[String]:
	return _json_files_in(HOLES_DIR)

static func list_templates() -> Array[String]:
	return _json_files_in(TEMPLATES_DIR)

# ── Internal ──────────────────────────────────────────────────────────────────

static func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

static func _json_files_in(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			results.append(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return results
