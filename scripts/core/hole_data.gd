## HoleData
## The canonical data model for a single minigolf hole.
## All geometry is expressed in metres, Y-up coordinate system.
## This class is pure data — no nodes, no rendering.
class_name HoleData
extends Resource

# ── Identity ────────────────────────────────────────────────────────────────

@export var hole_name: String = "Unnamed Hole"
@export var par: int = 3
@export var description: String = ""

# ── Key positions ────────────────────────────────────────────────────────────

## Where the ball starts each stroke
@export var tee_position: Vector3 = Vector3(0.0, 0.15, 0.0)

## Centre of the cup (hole target)
@export var cup_position: Vector3 = Vector3(0.0, 0.05, 8.0)

# ── Floor segments ───────────────────────────────────────────────────────────
## Each dict: { "center": Vector3, "size": Vector3, "rot_y": float }
## rot_y is in degrees. Size.y is always floor thickness (~0.2).
@export var floor_segments: Array[Dictionary] = []

# ── Obstacles ────────────────────────────────────────────────────────────────
## Each dict: { "type": String, "pos": Vector3, "size": Vector3, "rot_y": float }
## Supported types: "wall", "ramp"
@export var obstacles: Array[Dictionary] = []

# ── Boundary walls ───────────────────────────────────────────────────────────
## Auto-generated from floor_segments if empty, or specified manually.
## Each dict: { "pos": Vector3, "size": Vector3, "rot_y": float }
@export var boundary_walls: Array[Dictionary] = []

# ── Serialisation ────────────────────────────────────────────────────────────

static func from_dict(d: Dictionary) -> HoleData:
	var h := HoleData.new()
	h.hole_name = d.get("name", "Unnamed Hole")
	h.par = d.get("par", 3)
	h.description = d.get("description", "")
	h.tee_position = _vec3(d.get("tee_position", [0, 0.15, 0]))
	h.cup_position = _vec3(d.get("cup_position", [0, 0.05, 8]))

	for seg in d.get("floor_segments", []):
		h.floor_segments.append({
			"center": _vec3(seg.get("center", [0, 0, 0])),
			"size":   _vec3(seg.get("size",   [3, 0.2, 6])),
			"rot_y":  float(seg.get("rot_y", 0.0)),
			"rot_x":  float(seg.get("rot_x", 0.0)),
		})

	for obs in d.get("obstacles", []):
		var obs_type: String = obs.get("type", "wall")
		if obs_type == "cylinder":
			h.obstacles.append({
				"type":   obs_type,
				"pos":    _vec3(obs.get("pos", [0, 0, 0])),
				"radius": float(obs.get("radius", 0.5)),
				"height": float(obs.get("height", 1.0)),
				"role":   obs.get("role", ""),
			})
		else:
			h.obstacles.append({
				"type":  obs_type,
				"pos":   _vec3(obs.get("pos", [0, 0, 0])),
				"size":  _vec3(obs.get("size", [0.2, 0.5, 1.0])),
				"rot_y": float(obs.get("rot_y", 0.0)),
			})

	for bw in d.get("boundary_walls", []):
		h.boundary_walls.append({
			"pos":   _vec3(bw.get("pos", [0, 0, 0])),
			"size":  _vec3(bw.get("size", [0.2, 0.5, 1.0])),
			"rot_y": float(bw.get("rot_y", 0.0)),
		})

	return h

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"name":        hole_name,
		"par":         par,
		"description": description,
		"tee_position": _vec3_arr(tee_position),
		"cup_position": _vec3_arr(cup_position),
		"floor_segments": [],
		"obstacles":      [],
		"boundary_walls": [],
	}
	for seg in floor_segments:
		d["floor_segments"].append({
			"center": _vec3_arr(seg["center"]),
			"size":   _vec3_arr(seg["size"]),
			"rot_y":  seg["rot_y"],
		})
	for obs in obstacles:
		d["obstacles"].append({
			"type":  obs["type"],
			"pos":   _vec3_arr(obs["pos"]),
			"size":  _vec3_arr(obs["size"]),
			"rot_y": obs["rot_y"],
		})
	for bw in boundary_walls:
		d["boundary_walls"].append({
			"pos":   _vec3_arr(bw["pos"]),
			"size":  _vec3_arr(bw["size"]),
			"rot_y": bw["rot_y"],
		})
	return d

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _vec3(a) -> Vector3:
	if a is Vector3:
		return a
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

static func _vec3_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
