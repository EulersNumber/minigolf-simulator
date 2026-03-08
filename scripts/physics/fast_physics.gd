## FastPhysics
## Lightweight headless 2.5D physics for Monte Carlo simulation.
## Models the ball as a point mass on a flat XZ plane using:
##   - Linear motion with friction/damping
##   - Elastic wall reflection (angle of incidence = angle of reflection)
##   - Cup detection via proximity
## No Godot physics engine is used — pure GDScript math, runs ~1000× real-time.
class_name FastPhysics
extends RefCounted

# ── Tuning ────────────────────────────────────────────────────────────────────

const FRICTION         := 0.985   # velocity multiplier per step (rolling friction)
const RESTITUTION      := 0.55    # energy retained on wall bounce
const STEP_DT          := 1.0/60  # fixed time step (seconds)
const MAX_STEPS        := 600     # max steps per stroke (10 seconds)
const STOP_SPEED       := 0.04    # m/s — ball considered stopped
const CUP_RADIUS       := 0.22    # metres — detection radius
const MAX_POWER        := 12.0    # m/s at full power (matches BallController)

# ── Result struct ─────────────────────────────────────────────────────────────

class StrokeResult:
	var ended_in_cup: bool   = false
	var final_position: Vector3 = Vector3.ZERO
	var steps_taken: int    = 0
	var path: Array[Vector3] = []   # populated only when record_path = true

# ── Public API ────────────────────────────────────────────────────────────────

## Simulate a single stroke.
## hole:          HoleData describing the geometry
## ball_pos:      starting position (Vector3, Y ignored internally)
## direction:     unit vector in XZ plane
## power:         0.0–1.0
## record_path:   if true, StrokeResult.path is filled (slower)
static func simulate_stroke(
	hole: HoleData,
	ball_pos: Vector3,
	direction: Vector3,
	power: float,
	record_path: bool = false
) -> StrokeResult:
	var result := StrokeResult.new()

	# Work in 2D (XZ). Y is ignored for flat holes.
	var pos  := Vector2(ball_pos.x, ball_pos.z)
	var vel  := Vector2(direction.x, direction.z).normalized() * (power * MAX_POWER)
	var cup2 := Vector2(hole.cup_position.x, hole.cup_position.z)

	# Build wall segment list from hole data
	var walls := _collect_walls(hole)

	for step in range(MAX_STEPS):
		if vel.length() < STOP_SPEED:
			break

		vel *= FRICTION
		var next_pos := pos + vel * STEP_DT

		# Wall collision
		var hit := _first_wall_hit(pos, next_pos, walls)
		if hit != null:
			pos = hit["pos"]
			vel = hit["vel"] * RESTITUTION
		else:
			pos = next_pos

		if record_path:
			result.path.append(Vector3(pos.x, ball_pos.y, pos.y))

		# Cup detection
		if pos.distance_to(cup2) <= CUP_RADIUS:
			result.ended_in_cup = true
			result.steps_taken  = step + 1
			result.final_position = Vector3(pos.x, ball_pos.y, pos.y)
			return result

		result.steps_taken = step + 1

	result.final_position = Vector3(pos.x, ball_pos.y, pos.y)
	return result

# ── Wall geometry ─────────────────────────────────────────────────────────────

## Returns a flat list of wall segments as pairs of Vector2 endpoints.
static func _collect_walls(hole: HoleData) -> Array:
	var walls := []
	for item in hole.obstacles:
		walls.append_array(_box_to_segments(item["pos"], item["size"], item["rot_y"]))
	for item in hole.boundary_walls:
		walls.append_array(_box_to_segments(item["pos"], item["size"], item["rot_y"]))
	return walls

## Convert a box (3D position/size/rot_y) to four 2D wall segments.
static func _box_to_segments(pos: Vector3, size: Vector3, rot_y: float) -> Array:
	var cx := pos.x
	var cz := pos.z
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	var angle := deg_to_rad(rot_y)

	# Local corners (XZ)
	var corners_local := [
		Vector2(-hw, -hd),
		Vector2( hw, -hd),
		Vector2( hw,  hd),
		Vector2(-hw,  hd),
	]

	# Rotate and translate
	var corners: Array[Vector2] = []
	for c in corners_local:
		var rx := c.x * cos(angle) - c.y * sin(angle)
		var ry := c.x * sin(angle) + c.y * cos(angle)
		corners.append(Vector2(cx + rx, cz + ry))

	# Four edges
	var segs := []
	for i in 4:
		segs.append([corners[i], corners[(i + 1) % 4]])
	return segs

# ── Collision detection ───────────────────────────────────────────────────────

## Returns the first wall hit along the move segment, or null.
## Returns dict { "pos": Vector2, "vel": Vector2 } on hit.
static func _first_wall_hit(from: Vector2, to: Vector2, walls: Array):
	var best_t := 1.0
	var best_normal := Vector2.ZERO
	var best_hit_pos := Vector2.ZERO

	for wall in walls:
		var wa: Vector2 = wall[0]
		var wb: Vector2 = wall[1]
		var result := _segment_intersect(from, to, wa, wb)
		if result != null and result["t"] < best_t:
			best_t        = result["t"]
			best_normal   = result["normal"]
			best_hit_pos  = result["pos"]

	if best_t >= 1.0:
		return null

	# Reflect velocity
	var move_dir := to - from
	var reflected := move_dir.normalized().reflect(best_normal)
	var remaining_t := 1.0 - best_t
	var new_pos := best_hit_pos + reflected * move_dir.length() * remaining_t

	return {"pos": new_pos, "vel": reflected * (to - from).length() / STEP_DT}

## Segment-segment intersection. Returns { t, pos, normal } or null.
static func _segment_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2):
	var d1 := p2 - p1
	var d2 := p4 - p3
	var cross := d1.x * d2.y - d1.y * d2.x

	if abs(cross) < 1e-8:
		return null  # parallel

	var t := ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / cross
	var u := ((p3.x - p1.x) * d1.y - (p3.y - p1.y) * d1.x) / cross

	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return null

	var hit_pos := p1 + d1 * t
	# Wall normal (perpendicular to wall, pointing toward p1)
	var wall_dir := (p4 - p3).normalized()
	var normal := Vector2(-wall_dir.y, wall_dir.x)
	if normal.dot(p1 - p3) < 0:
		normal = -normal

	return {"t": t, "pos": hit_pos, "normal": normal}
