## BotProfiles
## Defines the 3×3 skill × style matrix.
## Each profile is a Dictionary of named parameters consumed by BotPlayer.
class_name BotProfiles
extends RefCounted

# ── Skill levels ──────────────────────────────────────────────────────────────
## angle_sigma:  standard deviation of aiming error (radians)
## power_sigma:  standard deviation of power error (fraction of intended power)
## planning:     ability to detect and avoid obstacles (0.0 = none, 1.0 = full)

const SKILL := {
	"beginner": {
		"angle_sigma": 0.28,   # ~16 degrees typical error
		"power_sigma": 0.25,
		"planning":    0.0,
	},
	"intermediate": {
		"angle_sigma": 0.12,   # ~7 degrees
		"power_sigma": 0.12,
		"planning":    0.5,
	},
	"expert": {
		"angle_sigma": 0.04,   # ~2 degrees
		"power_sigma": 0.05,
		"planning":    1.0,
	},
}

# ── Playing styles ────────────────────────────────────────────────────────────
## power_factor:       multiplier on intended power (>1 = hits harder)
## direct_bias:        0.0 = always aims directly, 1.0 = always tries safe route
## randomise_angle:    extra random variation in direction (style noise, radians)

const STYLE := {
	"aggressive": {
		"power_factor":    1.15,
		"direct_bias":     0.1,
		"randomise_angle": 0.0,
	},
	"conservative": {
		"power_factor":    0.85,
		"direct_bias":     0.8,
		"randomise_angle": 0.0,
	},
	"random": {
		"power_factor":    1.0,
		"direct_bias":     0.5,
		"randomise_angle": 0.20,   # extra style noise
	},
}

# ── Combined profile ──────────────────────────────────────────────────────────

static func get_profile(skill: String, style: String) -> Dictionary:
	var sk := SKILL.get(skill, SKILL["intermediate"])
	var st := STYLE.get(style, STYLE["aggressive"])
	return {
		"skill": skill,
		"style": style,
		"angle_sigma":     sk["angle_sigma"],
		"power_sigma":     sk["power_sigma"],
		"planning":        sk["planning"],
		"power_factor":    st["power_factor"],
		"direct_bias":     st["direct_bias"],
		"randomise_angle": st["randomise_angle"],
	}

static func all_skill_names() -> Array[String]:
	return ["beginner", "intermediate", "expert"]

static func all_style_names() -> Array[String]:
	return ["aggressive", "conservative", "random"]
