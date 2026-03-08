## HoleGenerator
## Produces HoleData instances from named templates or procedurally.
## All templates are based on real minigolf design archetypes.
class_name HoleGenerator
extends RefCounted

# ── Public API ────────────────────────────────────────────────────────────────

## Load a built-in template by name. Returns null if not found.
static func from_template(template_name: String) -> HoleData:
	var path := "res://data/templates/%s.json" % template_name
	if FileAccess.file_exists(path):
		return SaveLoad.load_hole(path)
	push_error("HoleGenerator: template '%s' not found." % template_name)
	return null

## Return all available template names (without extension).
static func list_templates() -> Array[String]:
	var names: Array[String] = []
	for path in SaveLoad.list_templates():
		names.append(path.get_file().get_basename())
	return names

## Generate a hole procedurally based on a style hint.
## style: "straight" | "dogleg_left" | "dogleg_right" | "s_bend" | "island"
static func generate(style: String = "straight", par: int = 3) -> HoleData:
	match style:
		"straight":      return _straight(par)
		"dogleg_left":   return _dogleg(par, -1)
		"dogleg_right":  return _dogleg(par,  1)
		"s_bend":        return _s_bend(par)
		"island":        return _island(par)
		_:
			push_warning("HoleGenerator: unknown style '%s', using straight." % style)
			return _straight(par)

# ── Templates ─────────────────────────────────────────────────────────────────

static func _straight(par: int) -> HoleData:
	var h := HoleData.new()
	h.hole_name = "Straight Classic"
	h.par = par
	h.description = "A simple straight hole — a good baseline for testing bots."
	h.tee_position = Vector3(0, 0.15, 0)
	h.cup_position  = Vector3(0, 0.05, 10)

	h.floor_segments = [{
		"center": Vector3(0, 0, 5),
		"size":   Vector3(2.5, 0.2, 10),
		"rot_y":  0.0,
	}]

	# A single deflecting wall off-centre
	h.obstacles = [{
		"type":  "wall",
		"pos":   Vector3(0.6, 0.25, 5.5),
		"size":  Vector3(0.2, 0.4, 1.8),
		"rot_y": 25.0,
	}]

	h.boundary_walls = _boundary_for_segments(h.floor_segments)
	return h

static func _dogleg(par: int, direction: int) -> HoleData:
	# direction: -1 = left, +1 = right
	var side := float(direction)
	var h := HoleData.new()
	h.hole_name = "Dog-Leg %s" % ("Left" if direction < 0 else "Right")
	h.par = par
	h.description = "A classic dog-leg — requires planning the bend."
	h.tee_position = Vector3(0, 0.15, 0)
	h.cup_position  = Vector3(side * 4.0, 0.05, 12.0)

	h.floor_segments = [
		{
			"center": Vector3(0, 0, 4),
			"size":   Vector3(2.5, 0.2, 8),
			"rot_y":  0.0,
		},
		{
			"center": Vector3(side * 2.0, 0, 9.5),
			"size":   Vector3(2.5, 0.2, 3),
			"rot_y":  0.0,
		},
		{
			"center": Vector3(side * 4.0, 0, 11.5),
			"size":   Vector3(2.5, 0.2, 4),
			"rot_y":  0.0,
		},
	]

	# Corner blocker that forces the bend
	h.obstacles = [{
		"type":  "wall",
		"pos":   Vector3(-side * 0.5, 0.25, 7.5),
		"size":  Vector3(0.2, 0.4, 2.0),
		"rot_y": 0.0,
	}]

	h.boundary_walls = _boundary_for_segments(h.floor_segments)
	return h

static func _s_bend(par: int) -> HoleData:
	var h := HoleData.new()
	h.hole_name = "S-Bend"
	h.par = par
	h.description = "Two opposing bends — challenging but fair."
	h.tee_position = Vector3(0, 0.15, 0)
	h.cup_position  = Vector3(0, 0.05, 14)

	h.floor_segments = [
		{"center": Vector3(0, 0, 2.5),  "size": Vector3(2.5, 0.2, 5),  "rot_y": 0.0},
		{"center": Vector3(1.5, 0, 6),  "size": Vector3(2.5, 0.2, 3),  "rot_y": 0.0},
		{"center": Vector3(0, 0, 9),    "size": Vector3(2.5, 0.2, 3),  "rot_y": 0.0},
		{"center": Vector3(-1.5, 0, 12),"size": Vector3(2.5, 0.2, 3),  "rot_y": 0.0},
		{"center": Vector3(0, 0, 14),   "size": Vector3(2.5, 0.2, 2),  "rot_y": 0.0},
	]

	h.obstacles = [
		{"type": "wall", "pos": Vector3(-0.4, 0.25, 4.5),  "size": Vector3(0.2, 0.4, 1.5), "rot_y": 15.0},
		{"type": "wall", "pos": Vector3(0.4, 0.25, 10.5),  "size": Vector3(0.2, 0.4, 1.5), "rot_y": -15.0},
	]

	h.boundary_walls = _boundary_for_segments(h.floor_segments)
	return h

static func _island(par: int) -> HoleData:
	var h := HoleData.new()
	h.hole_name = "Island Green"
	h.par = par
	h.description = "Miss the landing zone and start over — precision required."
	h.tee_position = Vector3(0, 0.15, 0)
	h.cup_position  = Vector3(0, 0.05, 11)

	h.floor_segments = [
		# Tee platform
		{"center": Vector3(0, 0, 2),   "size": Vector3(2.5, 0.2, 4), "rot_y": 0.0},
		# Narrow bridge
		{"center": Vector3(0, 0, 5.5), "size": Vector3(0.8, 0.2, 3), "rot_y": 0.0},
		# Island green
		{"center": Vector3(0, 0, 10),  "size": Vector3(3.0, 0.2, 4), "rot_y": 0.0},
	]

	h.obstacles = [{
		"type":  "wall",
		"pos":   Vector3(0.5, 0.25, 9),
		"size":  Vector3(0.2, 0.4, 1.0),
		"rot_y": 30.0,
	}]

	h.boundary_walls = _boundary_for_segments(h.floor_segments)
	return h

# ── Boundary generation ───────────────────────────────────────────────────────
## Generates simple side walls for each floor segment.
## This is a basic approximation — aligned axis-only, no mitre joins.

static func _boundary_for_segments(segments: Array[Dictionary]) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	var wall_h := 0.4
	var wall_t := 0.15

	for seg in segments:
		var c: Vector3 = seg["center"]
		var s: Vector3 = seg["size"]
		var ry: float  = seg.get("rot_y", 0.0)

		# Left and right side walls (along Z axis of the segment)
		for side in [-1, 1]:
			var offset := Vector3(side * (s.x * 0.5 + wall_t * 0.5), wall_h * 0.5, 0)
			if ry != 0.0:
				offset = offset.rotated(Vector3.UP, deg_to_rad(ry))
			walls.append({
				"pos":   c + offset,
				"size":  Vector3(wall_t, wall_h, s.z),
				"rot_y": ry,
			})

		# Back and front cap walls
		for cap in [-1, 1]:
			var offset := Vector3(0, wall_h * 0.5, cap * (s.z * 0.5 + wall_t * 0.5))
			if ry != 0.0:
				offset = offset.rotated(Vector3.UP, deg_to_rad(ry))
			walls.append({
				"pos":   c + offset,
				"size":  Vector3(s.x + wall_t * 2, wall_h, wall_t),
				"rot_y": ry,
			})

	return walls
