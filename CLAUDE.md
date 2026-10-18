# Maze Keep — notes for Claude Code

Design doc: `docs/design_doc_v2.md` (source of truth for gameplay rules and the build plan).

## Rules (from the design doc)
- Godot 4.6, typed GDScript throughout. Signals for communication between systems.
- Text scenes (.tscn) and resources (.tres) only, so they can be edited directly.
- Data driven: towers, enemies, waves and levels live in `data/*.tres`. New content should not need new code.
- Test pathfinding and placement validation before building on them.
- Target 60 fps on an iPhone 11 with 150 enemies on screen.

## Commands
```
godot --headless --import                                   # after adding/renaming class_name scripts
godot --headless --fixed-fps 60 -s res://tests/run_tests.gd # all tests; TEST_FILTER=name to narrow
```
`--fixed-fps 60` matters: integration tests simulate whole waves faster than real time.
`BOT_DEBUG=1` prints per-wave results for the level bot test (a balance smoke test).

## Layout
- `scripts/managers/` — GridManager (placement validation + live-maze rules), Pathfinding (AStarGrid2D), Economy, WaveManager, Level (wires everything).
- `scripts/components/` — GroundWalker (pure movement state), Enemy, Tower, Projectile, Board (drawing + input).
- `scripts/ui/hud.gd` — HUD built in code; emits intent signals, the Level acts on them.
- `tests/` — tiny GUT-style runner (GUT download was unavailable when this was set up; swapping to GUT later is straightforward).

## Routing invariants worth keeping
- Every build/sell is validated against every gate and every live ground enemy before it is applied.
- Walkers finish their current tile step before adopting a new route (`route[0] == cell_to`).
- Edits that make a walker reverse onto the tile it just left, or re-enter a tile it has entered
  `MAX_TILE_VISITS` times, are rejected. This bounds path-length farming.
- 1 s game-time cooldown between maze edits during a wave; none in the build phase.
