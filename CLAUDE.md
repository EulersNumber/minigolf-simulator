# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

**Godot 4.2+ / GDScript.** Open the project in Godot: `File → Open Project → select this folder`, then press **F5** to run. No CLI build step.

## Architecture

### Scene flow
`main_menu.tscn` (startup) → `game_setup.tscn` (New Game) or direct → `main.tscn` (game).
`GameState` autoload (`scripts/core/game_state.gd`) carries mode + player list between scenes.

### main.tscn scene tree
`Main` (Node3D, `main.gd`) owns:
- `HoleScene` — 3D world: geometry, ball, cameras
- `HUD` (CanvasLayer) — player name, stroke count, power bar, buttons
- `HoleComplete` (CanvasLayer, layer 30) — post-hole score overlay
- `HelpOverlay` (CanvasLayer, layer 25) — ? popup

### Data flow
1. `SaveLoad.load_hole("res://data/templates/hawaii.json")` → `HoleData.from_dict()` → `HoleData`
2. `HoleScene.load_hole(HoleData)` → `HoleBuilder.build()` instantiates StaticBody3D geometry
3. Human turn: drag input in `HudController` → `shot_requested` signal → `HoleScene.fire_shot()` → `BallController`
4. Bot turn: `SimRunner.run_detailed(bot, hole, 1)` (headless, instant) → `_finish_turn(strokes)`
5. On hole: `BallController.ball_holed` → `HoleScene.hole_completed` → `Main._finish_turn()` → `HoleComplete` overlay

### Dual physics model
| Mode | Class | When used |
|------|-------|-----------|
| Visual | `BallController` (`RigidBody3D`, `linear_damp=2.0`) | Interactive play |
| Headless | `FastPhysics` (2.5D XZ point-mass) | Bot simulation via `SimRunner` |

`MAX_POWER` (5.0 m/s) and `FRICTION`/`RESTITUTION` must stay in sync across both.

### Obstacle types (HoleData + HoleBuilder)
- `"wall"` — box (keys: `pos`, `size`, `rot_y`)
- `"cylinder"` — for volcano etc. (keys: `pos`, `radius`, `height`, `role`)
  - Roles: `"volcano_base"`, `"volcano_peak"` — controls colour in HoleBuilder
  - In FastPhysics: approximated as circle collision in 2D

### Camera system
Two cameras in `hole_scene.tscn`: `OverviewCamera` (default, top-down angled) and `FollowCamera` (low behind-ball, updated each frame in `_process`). Toggle with `C`.

### Turn management (multi-player)
`GameState` holds `players` array and `current_player_index`. `Main._start_current_turn()` reads the current player; if `is_bot=true` it runs `SimRunner` instantly; otherwise waits for human input. After hole, `GameState.record_score_and_advance()` steps to next player.

### Active course
Only `hawaii.json` ("Volcanic Approach", par 4) is used. Other templates remain in `data/templates/` but are not loaded.

## Key runtime controls
| Key | Action |
|-----|--------|
| Drag + release | Aim and fire |
| `R` | Reset ball |
| `C` | Toggle overview / follow camera |
| `ESC` | Main menu |
