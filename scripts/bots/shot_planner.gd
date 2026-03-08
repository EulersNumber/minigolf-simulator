## ShotPlanner
## Determines the intended aim direction and power for a shot.
## Uses ray-casting against wall segments to detect obstacles.
## planning_ability controls how much the bot tries to work around obstacles.
class_name ShotPlanner
extends RefCounted

const MAX_POWER := 1.0
const MIN_POWER := 0.3

# ── Public API ────────────────────────────────────────────────────────────────

## Returns a dict { "direction": Vector2, "power": float }
## ball_pos and cup_pos are Vector3 (Y ignored).
## planning_ability: 0.0 = always aim direct; 1.0 = full obstacle reasoning.
## direct_bias: style preference for safe shots (from BotProfile).
static func plan_shot(
	hole: HoleData,
	ball_pos: Vector3,
	cup_pos: Vector3,
	planning_ability: float,
	direct_bias: float
) -> Dictionary:
	var from := Vector2(ball_pos.x, ball_pos.z)
	var to   := Vector2(cup_pos.x,  cup_pos.z)
	var walls := FastPhysics._collect_walls(hole)

	# Distance governs base power
	var dist := from.distance_to(to)
	var base_power := clampf(dist / 10.0, MIN_POWER, MAX_POWER)

	# 1. Try direct shot
	if not _ray_hits_wall(from, to, walls):
		return {"direction": (to - from).normalized(), "power": base_power}

	# 2. Obstacle detected — use planning if ability allows
	if planning_ability < 0.01 or randf() > planning_ability:
		# Low-skill bot just aims directly regardless
		return {"direction": (to - from).normalized(), "power": base_power}

	# 3. Try lateral offsets (fan search)
	var best := _fan_search(from, to, walls, base_power, direct_bias)
	return best

# ── Fan search ────────────────────────────────────────────────────────────────
## Sweeps aiming angles to find a clear path or a reflection.

static func _fan_search(
	from: Vector2,
	to: Vector2,
	walls: Array,
	base_power: float,
	direct_bias: float
) -> Dictionary:
	var direct_dir := (to - from).normalized()
	var best_dir   := direct_dir
	var best_score := -INF

	# Sweep ±45° in 5° steps
	for deg in range(-45, 50, 5):
		var angle := deg_to_rad(float(deg))
		var dir   := direct_dir.rotated(angle)
		var score := _evaluate_direction(from, to, dir, walls, direct_bias)
		if score > best_score:
			best_score = score
			best_dir   = dir

	return {"direction": best_dir, "power": base_power}

## Score a candidate direction. Higher = better.
static func _evaluate_direction(
	from: Vector2,
	to: Vector2,
	direction: Vector2,
	walls: Array,
	direct_bias: float
) -> float:
	# Cast ray for a reasonable distance
	var cast_end := from + direction * 15.0

	if not _ray_hits_wall(from, cast_end, walls):
		# Clear shot — score by angle to cup (closer = better)
		var toward_cup := (to - from).normalized()
		var alignment  := direction.dot(toward_cup)  # -1 to 1
		# Penalise large deviations from direct line
		return alignment - (1.0 - alignment) * direct_bias
	else:
		# Blocked — low score
		return -1.0

# ── Ray-wall intersection ─────────────────────────────────────────────────────

static func _ray_hits_wall(from: Vector2, to: Vector2, walls: Array) -> bool:
	for wall in walls:
		if FastPhysics._segment_intersect(from, to, wall[0], wall[1]) != null:
			return true
	return false
