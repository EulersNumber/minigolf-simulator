# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

**Godot 4.2+ / GDScript.** Open the project in Godot: `File → Open Project → select this folder`, then press **F5** to run. There is no CLI build step.

## Architecture

### Scene tree
`scenes/main.tscn` → `Main` (Node3D) owns two child CanvasLayers (`HUD`, `SimResults`) and a `HoleScene` Node3D. `Main.gd` wires signals between them.

### Data flow
1. `SaveLoad.load_hole()` reads a JSON file → `HoleData.from_dict()` → `HoleData` resource (pure data, no nodes)
2. `HoleScene.load_hole(HoleData)` calls `HoleBuilder` to instantiate `StaticBody3D` meshes, then positions the ball
3. For interactive play: `BallController` (wraps `RigidBody3D`) handles shot impulses and emits `stroke_ended` / `ball_holed`
4. For simulation: `SimRunner.run(bot, hole, n)` calls `FastPhysics.simulate_stroke()` in a loop (pure GDScript, no Godot physics, ~1000× real-time)

### Dual physics model
| Mode | Class | When used |
|------|-------|-----------|
| Visual | `BallController` (`RigidBody3D`) | Interactive play |
| Headless | `FastPhysics` (2.5D XZ point-mass) | Monte Carlo via `SimRunner` |

`FastPhysics` constants (`FRICTION`, `RESTITUTION`, `MAX_POWER`) must stay in sync with `BallController` tuning for simulation results to be meaningful.

### Bot system
`BotProfiles` defines stat tables for 3 skills × 3 styles = 9 combinations. `ShotPlanner` converts a `HoleData` + bot profile into a `(direction, power)` pair. `BotPlayer` wraps both and is the object passed to `SimRunner`.

### Hole data format
`HoleData` is a `Resource` with `floor_segments`, `obstacles`, and `boundary_walls` arrays of Dictionaries (keys: `center`/`pos`, `size`, `rot_y`). Templates live in `data/templates/*.json`. Custom holes save to `user://holes/` via `SaveLoad.save_hole()`.

## Key keyboard shortcuts (runtime)

| Key | Action |
|-----|--------|
| `1–4` | Load built-in template hole |
| `G` | Generate procedural hole |
| `R` | Reset ball to tee |

Drag on the viewport to aim and set power; release to fire.
