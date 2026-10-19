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
python3 tools/gen_content.py                                # regenerate data/*.tres from one script
godot --headless --import                                   # after adding/renaming class_name scripts or data
godot --headless --fixed-fps 60 -s res://tests/run_tests.gd # all tests; TEST_FILTER=name to narrow
godot --headless -s res://tools/make_icon.gd                # app icon
xvfb-run -a -s "-screen 0 1080x2400x24" godot --rendering-driver opengl3 --resolution 720x1560 \
  --fixed-fps 60 -s res://tools/screenshots.gd -- /tmp/shots  # every screen as PNG
```
`--fixed-fps 60` matters: integration tests simulate whole waves faster than real time.
`BOT_DEBUG=1` prints per-wave results for the bot playthrough tests (a balance smoke test).

## Content is generated
`tools/gen_content.py` writes every tower, enemy, level (30 campaign + 3 endless + 3 challenge)
and `data/campaign.tres`. Edit numbers there, not in the .tres files, then regenerate and re-import.
Map layouts are validated in the generator (every gate reaches the keep).

## Layout
- `scripts/data/` — resource classes: TowerData (+TowerSpec), EnemyData, WaveData/SpawnGroup, LevelData, TutorialStep, CampaignData.
- `scripts/managers/` — GridManager (placement validation + live-maze rules), Pathfinding (two AStarGrid2Ds: normal and wall-permissive), Economy, WaveManager (incl. endless generation), Level (wires everything), autoloads Save / IAP / Audio / Game.
- `scripts/components/` — GroundWalker (pure movement state), Enemy, Tower, Projectile, Board (ground texture + input, Overlay child for animated routes), Effects (one-node particle/text layer).
- `scripts/ui/` — HUD and every screen, built in code on `UITheme`; `EnemyArt`/`TowerArt` draw the procedural sprites; `Palette` holds colours per world.
- `tests/` — tiny GUT-style runner. `test_level.gd` runs the real scene including bot playthroughs of levels 1, 13 and 24.

## Routing invariants worth keeping
- Every build/sell is validated against every gate (active AND inactive shifting gates) and every live ground enemy before it is applied.
- Walkers finish their current tile step before adopting a new route (`route[0] == cell_to`).
- Edits that make a walker reverse onto the tile it just left, or re-enter a tile it has entered
  `MAX_TILE_VISITS` times, are rejected. This bounds path-length farming.
- 1 s game-time cooldown between maze edits during a wave; none in the build phase.
- Wall-breakers and ghosts route on the permissive grid (walls cost `WALL_WEIGHT`, towers and terrain solid)
  and stop at a wall via `GroundWalker.blocker` until they smash it or their phase cooldown is ready.

## Autoloads in scripts run with `-s`
A SceneTree script passed with `-s` compiles before autoloads exist, so it can't reference `Game`/`Save`
directly. Load the real logic at runtime (see `tools/screenshots.gd` → `screenshots_body.gd`, and
`tests/run_tests.gd` loading `test_*.gd`).
