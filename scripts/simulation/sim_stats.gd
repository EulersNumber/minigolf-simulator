## SimStats
## Computes summary statistics from a completed simulation run.
## All methods are pure functions — no side effects.
class_name SimStats
extends RefCounted

# ── Input data structure ──────────────────────────────────────────────────────
## SimRunner produces an Array of round dicts:
##   { "strokes": int, "holed": bool, "strokes_log": Array[int] }
## strokes_log: stroke count after each stroke attempt (always length == strokes used)

# ── Summary statistics ────────────────────────────────────────────────────────

static func compute(rounds: Array, par: int) -> Dictionary:
	if rounds.is_empty():
		return {}

	var total_rounds  := rounds.size()
	var holed_rounds  := 0
	var stroke_counts := []
	var hio_count     := 0

	for r in rounds:
		if r["holed"]:
			holed_rounds  += 1
			stroke_counts.append(r["strokes"])
			if r["strokes"] == 1:
				hio_count += 1

	var completion_rate := float(holed_rounds) / float(total_rounds)

	# Stats only on completed rounds
	var avg_strokes   := 0.0
	var std_strokes   := 0.0
	var min_strokes   := 0
	var max_strokes   := 0
	var median_strokes := 0.0

	if not stroke_counts.is_empty():
		avg_strokes = _mean(stroke_counts)
		std_strokes = _std_dev(stroke_counts, avg_strokes)
		stroke_counts.sort()
		min_strokes    = stroke_counts[0]
		max_strokes    = stroke_counts[-1]
		median_strokes = _median(stroke_counts)

	# Par distribution (how many rounds finished eagle/birdie/par/bogey/etc.)
	var par_distribution := {}
	for n in stroke_counts:
		var diff: int = int(n) - par
		var label := _par_label(diff)
		par_distribution[label] = par_distribution.get(label, 0) + 1

	return {
		"total_rounds":      total_rounds,
		"holed_rounds":      holed_rounds,
		"completion_rate":   completion_rate,
		"hio_count":         hio_count,
		"hio_probability":   float(hio_count) / float(total_rounds),
		"avg_strokes":       avg_strokes,
		"std_strokes":       std_strokes,
		"min_strokes":       min_strokes,
		"max_strokes":       max_strokes,
		"median_strokes":    median_strokes,
		"par":               par,
		"par_distribution":  par_distribution,
	}

## Format a stats dict into a human-readable multi-line string.
static func format(stats: Dictionary) -> String:
	if stats.is_empty():
		return "No data."
	var lines := [
		"=== Simulation Results ===",
		"Rounds:          %d  (completed: %d, %.1f%%)" % [
			stats["total_rounds"],
			stats["holed_rounds"],
			stats["completion_rate"] * 100.0,
		],
		"Hole-in-one:     %d  (%.2f%%)" % [
			stats["hio_count"],
			stats["hio_probability"] * 100.0,
		],
		"Avg strokes:     %.2f  (par %d)" % [stats["avg_strokes"], stats["par"]],
		"Std deviation:   %.2f" % stats["std_strokes"],
		"Min / Max:       %d / %d" % [stats["min_strokes"], stats["max_strokes"]],
		"Median:          %.1f" % stats["median_strokes"],
		"",
		"Score distribution:",
	]
	for label in ["Hole-in-one", "Eagle", "Birdie", "Par", "Bogey", "Double+", "DNF"]:
		var count: int = stats["par_distribution"].get(label, 0)
		if count > 0:
			var pct: float = count * 100.0 / stats["total_rounds"]
			lines.append("  %-14s %4d  (%5.1f%%)" % [label + ":", count, pct])
	return "\n".join(lines)

# ── Internals ─────────────────────────────────────────────────────────────────

static func _mean(values: Array) -> float:
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())

static func _std_dev(values: Array, mean: float) -> float:
	if values.size() < 2:
		return 0.0
	var variance := 0.0
	for v in values:
		variance += (float(v) - mean) * (float(v) - mean)
	return sqrt(variance / float(values.size() - 1))

static func _median(sorted_values: Array) -> float:
	var n := sorted_values.size()
	if n % 2 == 1:
		return float(sorted_values[n / 2])
	return (float(sorted_values[n / 2 - 1]) + float(sorted_values[n / 2])) * 0.5

static func _par_label(diff: int) -> String:
	match diff:
		-1: return "Hole-in-one" # handled separately above, but catch -1 from par 2
		0 - 1: return "Hole-in-one"
	match diff:
		-2: return "Eagle"
		-1: return "Birdie"
		0:  return "Par"
		1:  return "Bogey"
		_:
			if diff <= -3:
				return "Eagle"   # albatross etc — simplify
			return "Double+"
