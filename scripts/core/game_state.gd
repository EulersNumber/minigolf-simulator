## GameState
## Autoload singleton — persists game configuration across scene changes.
extends Node

enum GameMode { NONE, PRACTICE, VS_BOTS, LOCAL_MULTI }

var mode: GameMode = GameMode.NONE
var players: Array[Dictionary] = []
var current_player_index: int = 0

func reset() -> void:
	mode = GameMode.NONE
	players.clear()
	current_player_index = 0

func setup_practice() -> void:
	reset()
	mode = GameMode.PRACTICE
	players.append({"name": "Player", "is_bot": false, "bot_profile": {}, "score": -1})

func setup_vs_bots(bot_configs: Array[Dictionary]) -> void:
	reset()
	mode = GameMode.VS_BOTS
	players.append({"name": "Player", "is_bot": false, "bot_profile": {}, "score": -1})
	for cfg in bot_configs:
		var profile := BotProfiles.get_profile(cfg["skill"], cfg["style"])
		players.append({
			"name": "%s %s" % [cfg["skill"].capitalize(), cfg["style"].capitalize()],
			"is_bot": true,
			"bot_profile": profile,
			"score": -1,
		})

func setup_local_multi(player_names: Array[String]) -> void:
	reset()
	mode = GameMode.LOCAL_MULTI
	for n in player_names:
		players.append({"name": n, "is_bot": false, "bot_profile": {}, "score": -1})

func current_player() -> Dictionary:
	if players.is_empty():
		return {}
	return players[current_player_index]

## Record strokes for the current player and advance to the next.
## Returns true when all players have finished (wrapped around).
func record_score_and_advance(strokes: int) -> bool:
	players[current_player_index]["score"] = strokes
	current_player_index += 1
	if current_player_index >= players.size():
		current_player_index = 0
		return true
	return false

func all_scores_summary(par: int) -> String:
	var lines: Array[String] = []
	for p in players:
		var s: int = p["score"]
		if s < 0:
			lines.append("%s: —" % p["name"])
		else:
			var diff := s - par
			lines.append("%s: %d (%s)" % [p["name"], s, _diff_label(diff)])
	return "\n".join(lines)

static func _diff_label(diff: int) -> String:
	match diff:
		-3: return "Albatross"
		-2: return "Eagle"
		-1: return "Birdie"
		0:  return "Par"
		1:  return "Bogey"
		2:  return "Double Bogey"
		_:  return ("+" if diff > 0 else "") + str(diff)
