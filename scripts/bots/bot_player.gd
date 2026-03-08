## BotPlayer
## Executes shots for a bot with a given profile (skill × style).
## Each call to decide_shot() returns a shot dict for use by the sim runner
## or the visual ball controller.
class_name BotPlayer
extends RefCounted

var profile: Dictionary
var rng: RandomNumberGenerator

# ── Construction ──────────────────────────────────────────────────────────────

## Create a bot from a skill name and style name.
static func create(skill: String, style: String) -> BotPlayer:
	var bot := BotPlayer.new()
	bot.profile = BotProfiles.get_profile(skill, style)
	bot.rng     = RandomNumberGenerator.new()
	bot.rng.randomize()
	return bot

## Create a bot directly from a profile dictionary.
static func from_profile(p: Dictionary) -> BotPlayer:
	var bot := BotPlayer.new()
	bot.profile = p
	bot.rng     = RandomNumberGenerator.new()
	bot.rng.randomize()
	return bot

# ── Public API ────────────────────────────────────────────────────────────────

## Decide a shot given the current hole state.
## Returns dict { "direction": Vector3, "power": float }
## direction is in the XZ plane (Y = 0), normalised.
func decide_shot(hole: HoleData, ball_pos: Vector3) -> Dictionary:
	# 1. Plan intended aim
	var planned := ShotPlanner.plan_shot(
		hole,
		ball_pos,
		hole.cup_position,
		profile["planning"],
		profile["direct_bias"]
	)

	var intended_dir   : Vector2 = planned["direction"]
	var intended_power : float   = planned["power"]

	# 2. Apply style power factor
	intended_power *= profile["power_factor"]

	# 3. Apply style angle randomisation
	if profile["randomise_angle"] > 0.0:
		var style_noise := rng.randfn(0.0, profile["randomise_angle"])
		intended_dir = intended_dir.rotated(style_noise)

	# 4. Apply skill noise (execution error)
	var angle_err := rng.randfn(0.0, profile["angle_sigma"])
	var power_err := rng.randfn(0.0, profile["power_sigma"])

	var actual_dir   := intended_dir.rotated(angle_err)
	var actual_power := clampf(intended_power + power_err, 0.05, 1.0)

	return {
		"direction": Vector3(actual_dir.x, 0.0, actual_dir.y),
		"power":     actual_power,
	}

# ── Display ───────────────────────────────────────────────────────────────────

func display_name() -> String:
	return "%s %s" % [profile["skill"].capitalize(), profile["style"].capitalize()]
