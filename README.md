# Minigolf Course Design Simulator

A **design sandbox** for prototyping and analysing minigolf holes in 3D.
Built with **Godot 4** and GDScript.

---

## Goals

- Design holes in 3D (floor segments + walls + obstacles)
- Simulate ball physics (visual + headless)
- Run bot players across a skill × style matrix
- Produce per-hole difficulty metrics via Monte Carlo simulation

---

## Quick Start

1. Install [Godot 4.2+](https://godotengine.org/download)
2. Open the project: `File → Open Project → select this folder`
3. Press **F5** (or the Play button) to run

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `1` | Load Straight Classic |
| `2` | Load Dog-Leg Left |
| `3` | Load S-Bend |
| `4` | Load Island Green |
| `G` | Generate a new procedural hole |
| `R` | Reset ball to tee |

### Playing a shot

Click and drag on the viewport: drag **direction** sets aim, drag **length** sets power.
Release to fire.

### Running simulations

Set the round count in the HUD panel, then click **Run Simulation**.
Results compare all 9 bot types (3 skills × 3 styles).

---

## Architecture

```
scripts/
  core/         HoleData, HoleBuilder, HoleGenerator, SaveLoad, HoleScene, Main
  physics/      BallController (Godot physics), FastPhysics (headless sim)
  bots/         BotProfiles, ShotPlanner, BotPlayer
  simulation/   SimRunner, SimStats
  ui/           HudController, ResultsDisplay

data/templates/ Four built-in hole JSON files
```

### Dual physics model

| Mode | Engine | Use |
|------|--------|-----|
| Visual | Godot `RigidBody3D` | Interactive play, full rendering |
| Headless | `FastPhysics.gd` (pure GDScript) | Monte Carlo — 1000+ rounds/second |

### Bot matrix

3 skill levels × 3 styles = 9 bot types.

|           | Aggressive | Conservative | Random |
|-----------|-----------|--------------|--------|
| Beginner  | ✓ | ✓ | ✓ |
| Intermediate | ✓ | ✓ | ✓ |
| Expert    | ✓ | ✓ | ✓ |

---

## Hole Data Format (JSON)

```json
{
  "name": "My Hole",
  "par": 3,
  "tee_position": [0, 0.15, 0],
  "cup_position": [0, 0.05, 10],
  "floor_segments": [
    { "center": [0, 0, 5], "size": [2.5, 0.2, 10], "rot_y": 0 }
  ],
  "obstacles": [
    { "type": "wall", "pos": [0.6, 0.25, 5.5], "size": [0.2, 0.4, 1.8], "rot_y": 25 }
  ],
  "boundary_walls": []
}
```

Save custom holes to `user://holes/` via `SaveLoad.save_hole()`.

---

## Roadmap

- [x] Ramp / slope support (Phase 2) — `"ramp"` obstacle type with visual tilt + headless gravity acceleration
- [ ] In-engine hole editor (Phase 2)
- [ ] Heatmap overlay from simulation paths (Phase 3)
- [ ] Multiple-hole course layout (Phase 3)
- [ ] Commentary bots with personality (Phase 4)
