## SimRunner
## Orchestrates headless Monte Carlo simulation runs.
## Uses FastPhysics (not Godot's physics engine) for speed.
## Can simulate thousands of rounds in seconds.
class_name SimRunner
extends RefCounted

# ── Signals (used when running in async mode via a Node wrapper) ──────────────
# Not emitted directly — SimRunner is a RefCounted, not a Node.
# Callers poll progress or run synchronously.

# ── Configuration ─────────────────────────────────────────────────────────────

const DEFAULT_ROUNDS    := 500
const MAX_STROKES       := 15    # give up after this many strokes per round (DNF)

# ── Public API ────────────────────────────────────────────────────────────────

## Run a full simulation synchronously. Returns SimStats.compute() dict.
## bot:        BotPlayer instance
## hole:       HoleData instance
## num_rounds: how many rounds to simulate
static func run(bot: BotPlayer, hole: HoleData, num_rounds: int = DEFAULT_ROUNDS) -> Dictionary:
	var rounds := _run_rounds(bot, hole, num_rounds)
	return SimStats.compute(rounds, hole.par)

## Run and also return raw round data (for heatmaps, per-stroke analysis).
static func run_detailed(
	bot: BotPlayer,
	hole: HoleData,
	num_rounds: int = DEFAULT_ROUNDS
) -> Dictionary:
	var rounds := _run_rounds(bot, hole, num_rounds, true)
	return {
		"stats":  SimStats.compute(rounds, hole.par),
		"rounds": rounds,
	}

## Run multiple bots on the same hole. Returns dict keyed by bot display name.
static func run_comparison(
	bots: Array,       # Array[BotPlayer]
	hole: HoleData,
	num_rounds: int = DEFAULT_ROUNDS
) -> Dictionary:
	var results := {}
	for bot in bots:
		results[bot.display_name()] = run(bot, hole, num_rounds)
	return results

# ── Internal ──────────────────────────────────────────────────────────────────

static func _run_rounds(
	bot: BotPlayer,
	hole: HoleData,
	num_rounds: int,
	record_paths: bool = false
) -> Array:
	var rounds := []

	for _i in range(num_rounds):
		var round_data := _simulate_round(bot, hole, record_paths)
		rounds.append(round_data)

	return rounds

static func _simulate_round(
	bot: BotPlayer,
	hole: HoleData,
	record_paths: bool
) -> Dictionary:
	var ball_pos    := hole.tee_position
	var strokes     := 0
	var holed       := false
	var stroke_log  : Array[int] = []
	var path_log    : Array      = []   # Array of Array[Vector3] per stroke

	while strokes < MAX_STROKES:
		# Bot decides shot
		var shot := bot.decide_shot(hole, ball_pos)

		# Simulate stroke with fast physics
		var result := FastPhysics.simulate_stroke(
			hole,
			ball_pos,
			shot["direction"],
			shot["power"],
			record_paths
		)

		strokes += 1
		stroke_log.append(strokes)

		if record_paths:
			path_log.append(result.path)

		if result.ended_in_cup:
			holed    = true
			ball_pos = result.final_position
			break

		ball_pos = result.final_position

	var data := {
		"strokes":     strokes,
		"holed":       holed,
		"stroke_log":  stroke_log,
	}
	if record_paths:
		data["paths"] = path_log

	return data
