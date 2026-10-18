# Maze Tower Defense: Game Design Doc

Oct 17, 2026 · Marc

## Overview

A fantasy maze building tower defense game for iOS and Android: players shape the path monsters walk, then defend it. Fair monetization: free to try, one time unlock, no ads ever.

| Item | Decision |
| --- | --- |
| Working title | TBD (placeholder: Maze Keep) |
| Genre | Maze building tower defense |
| Theme | Fantasy: castles, monsters, magic |
| Platforms | iOS first, Android second |
| Engine | Godot 4 (GDScript) |
| Orientation | Portrait, one handed play |
| Session length | 3 to 6 minutes per level |
| Business model | Free download, first 5 levels free, single unlock for the full game |
| Ads | None |

**Pitch:** Build the labyrinth. Hold the keep. Every wall you place changes how the horde moves.

**Differentiators:** player built mazes instead of fixed paths, enemies that counter lazy mazes, everything earned by playing, no ads or pay to win.

## Core gameplay loop

Each level is a grid with one or more monster gates and the castle keep. The player builds a maze between them, then survives a set number of waves.

1. **Build phase.** Before each wave, place walls and towers on the grid using gold. Time pauses until the player taps Start Wave.
2. **Wave phase.** Monsters spawn at gates and path to the keep. Towers fire automatically. The player can still build during waves (adds pressure and skill expression).
3. **Reward.** Killing monsters earns gold. Clearing a wave earns a bonus.
4. **Repeat** until all waves are cleared (win) or the keep loses all lives (lose).

### Maze rules

- Grid of square tiles, roughly 9 columns by 14 rows in portrait.
- **Walls** are cheap (5 gold) and only block. **Towers** cost more and also block.
- The path from every gate to the keep can never be fully blocked. Every placement runs a pathfinding check; an invalid placement shows red and is rejected.
- Monsters recalculate their path live when the maze changes, including mid wave.
- Selling a wall or tower refunds 70% of its cost.
- Some tiles are unbuildable (rock, water, ruins) to shape each map.

### Enemy routing specification

Ground enemies use deterministic shortest traversable paths on the square grid, computed with Godot 4 AStarGrid2D from their current tile to the keep. Walls, towers, and unbuildable terrain are impassable. Equal-cost routes use a stable tie-breaking order so previews and movement agree.

Before confirming any build, validate that every monster gate retains a route to the keep. Show the proposed new route as a ghost preview; reject invalid placements in red without spending gold. Never place a structure on a tile currently occupied by an enemy.

After a valid placement or sale, recalculate affected ground-enemy routes from their current positions. Enemies finish movement to their next tile before adopting the updated route; they never teleport. Flying enemies retain their documented direct route, while Sappers, Ghosts, and bosses use their special movement rules.

### Anti-exploit rules for live maze editing

A placement cannot force an active ground enemy to reverse onto the tile it just left merely to repeat a corridor. If an edit would create a repeated back-and-forth route for an active enemy, reject that edit and show a clear warning.

Apply a brief cooldown of 1 second between maze-changing actions during a wave (initial balancing value). Wall painting validates each tile separately; invalid tiles are skipped without charge. Selling still refunds 70%, and the same routing validation applies after each change.

Track repeated tile transitions for each enemy and detect stalled movement; resolve legitimate reroutes without allowing indefinite path-length farming. Add automated tests for rapid build/sell cycles, multiple gates, occupied tiles, and mid-wave rerouting.

### Scoring

- 3 stars: keep loses no lives. 2 stars: loses up to half. 1 star: survives.
- Lives: 20 per level by default. Most monsters cost 1 life; bosses cost more.

## Towers

Six towers at launch, each with 3 upgrade tiers. Tier 3 offers a choice of two specializations, so players build differently on the same map. Numbers are starting values for balancing.

| Tower | Cost (gold) | Role | Hits flyers | Tier 3 choices |
| --- | --- | --- | --- | --- |
| Archer Post | 50 | Fast single target, cheap | Yes | Longbow (range) or Volley (multi shot) |
| Stone Thrower | 80 | Slow splash damage vs groups | No | Boulder (big splash) or Quake (stun) |
| Frost Mage | 90 | Slows enemies in range | Yes | Blizzard (area slow) or Shatter (bonus damage to slowed) |
| Flame Brazier | 100 | Short range burn over time | No | Inferno (wider cone) or Wildfire (burn spreads) |
| Arcane Spire | 140 | High damage, pierces armor | Yes | Lightning (chains) or Void (true damage beam) |
| War Banner | 120 | No attack; buffs adjacent towers | n/a | Rally (attack speed) or Bounty (extra gold) |

### Synergy rules

- Frost slows plus Flame burn on the same enemy deals bonus damage (Thermal Shock).
- Towers placed at maze corners get more time on target, which is the core skill of the game.
- War Banner rewards compact layouts and makes placement a real puzzle.

Unlock order: Archer and Stone at start, the rest unlock through the campaign (see Levels).

## Enemies

Enemy variety is what stops one perfect maze from winning every level. Each type pressures a different weakness.

| Enemy | Behavior | Counters |
| --- | --- | --- |
| Goblin | Basic walker, low health | Anything |
| Wolf Rider | Very fast | Long mazes, Frost |
| Orc Brute | High health, slow | Arcane, Flame |
| Armored Knight | Reduces physical damage | Arcane, Frost Shatter |
| Bat Swarm | Flies straight to the keep, ignores maze | Archer, Frost, Arcane |
| Sapper | Attacks and destroys walls in its way | Kill fast, protect walls with towers |
| Slime | Splits into 2 smaller slimes on death | Stone, Flame splash |
| Shaman | Heals nearby monsters | Priority targeting, Lightning |
| Ghost | Phases through one wall every few seconds | Dense tower coverage |
| Boss: Troll King | Huge health, smashes walls, costs 5 lives | Everything combined |

Additional bosses (Dragon, Lich) appear at the end of each world. Each wave preview shows which enemies are coming so players can adapt their maze.

## Levels, maps and progression

Version 1 ships with 30 campaign levels across 3 worlds, plus Endless and Challenge modes. All progression is earned by playing.

| World | Levels | Setting | New mechanics | Unlocks |
| --- | --- | --- | --- | --- |
| 1. The Borderlands | 1 to 10 | Farmland, villages | Basics, flyers, sappers | Frost Mage, Flame Brazier |
| 2. The Haunted Marsh | 11 to 20 | Swamp, ruins | Water tiles, ghosts, two gates | Arcane Spire |
| 3. The Dragon Peaks | 21 to 30 | Mountains, lava | Shifting gates, limited walls | War Banner |

### Map constraints used across levels

- Unbuildable tiles (rock, water, ruins)
- Multiple gates feeding one keep
- Limited wall budget on some levels
- Gates that move between waves in World 3

### Modes

- **Campaign:** 30 levels, 3 stars each, 90 stars total.
- **Endless:** waves scale forever on a set of 3 maps; global high score via Game Center.
- **Challenges:** fixed rule levels (only Archers, no walls, double speed) unlocked by stars.

### Meta progression

- Stars unlock a skill tree of permanent small bonuses (starting gold, wall cost, tower range).
- Everything is earnable. No currency, no store beyond the one unlock.

## Monetization

Free download with levels 1 to 5 playable, then one non consumable in app purchase unlocks the full game forever. No ads, no consumables, no subscriptions.

- **Price:** $4.99 at launch (test $3.99 to $6.99 later).
- **Unlock prompt:** shown once after beating level 5, with a clear "one price, everything included, no ads" message. Never nag mid level.
- **Restore Purchases** button in Settings (required by Apple).
- **Family Sharing** enabled for the unlock.
- **Future content:** free updates with new levels keep reviews strong. Paid expansions can be considered later.
- **Apple Small Business Program:** enroll so Apple's commission is 15% instead of 30%.
- **Apple Arcade:** pitch once the game is polished; it fits their no ads, premium criteria.

## UI, controls, art and audio

Portrait, one thumb controls, readable at a glance on a phone.

### Onboarding and first-play tutorial

Levels 1 to 3 are interactive tutorials integrated into the campaign, not a separate wall of instructions. Keep instructions brief, skippable for returning players, and replayable from Settings.

**Level 1: Build and defend.** Highlight a buildable tile, teach placement of an Archer Post, show its range, preview the enemy route, and prompt Start Wave. Explain gold and keep lives after the first encounter.

**Level 2: Shape the maze.** Teach cheap wall placement and drag-to-paint. Show the old and new monster routes before confirmation. Ask the player to create a longer valid route, then demonstrate an attempted full blockage with a red invalid-placement message.

**Level 3: Adapt and upgrade.** Introduce Stone Thrower, tower upgrade, selling/refunds, and the next-wave enemy preview. Demonstrate a safe mid-wave reroute and explain that flyers and special enemies can counter simple mazes.

Tutorial prompts use one highlighted action at a time, large touch targets, and concise text. Do not require perfect execution; provide a retry hint if a player gets stuck. Persist tutorial completion in SaveManager.

### Controls

- Tap an empty tile to open a build menu (wall plus available towers).
- Drag to paint a line of walls quickly.
- Tap a tower to upgrade, choose a specialization, set targeting (first, strongest, fastest, flyers), or sell.
- Ghost preview shows the new monster path before confirming a placement.
- Speed toggle: 1x, 2x, 3x. Pause anytime.

### Screens

- Title, World map, Level select, In game HUD, Pause, Win/Lose, Skill tree, Settings, Unlock screen.
- HUD: gold, lives, wave counter, next wave preview, speed and pause buttons.

### Art direction

- Clean top down 2D, storybook fantasy style with bold readable silhouettes.
- All art must be original. No visual resemblance to Kingdom Rush, Bloons, or any other existing game.
- Use AI image tools or a freelance artist; keep a consistent palette per world.
- Placeholder colored shapes during development until gameplay is fun.

### Audio

- One music track per world plus a boss theme.
- Distinct sound per tower attack and enemy death; satisfying build and upgrade sounds.
- Royalty free or commissioned audio only.

## Technical architecture (Godot 4)

Data driven design: towers, enemies, waves, and levels are defined in resource files, so new content needs no new code.

### Key systems

| System | Responsibility |
| --- | --- |
| GridManager | Tile grid, buildable tiles, placement validation |
| Pathfinding | AStarGrid2D from each gate to the keep; recompute on change; reject placements that block all paths |
| WaveManager | Reads wave definitions, spawns enemies on schedule |
| Enemy (base scene) | Follows current path, handles health, armor, status effects; subclasses for special behaviors |
| Tower (base scene) | Targeting modes, firing, upgrades, specializations |
| Projectile | Movement, hit detection, damage and effects |
| Economy | Gold, lives, refunds, wave bonuses |
| SaveManager | Stars, unlocks, skill tree, settings saved to user:// |
| IAPManager | StoreKit purchase and restore via a Godot iOS plugin; Google Play Billing for Android |
| UI | HUD, menus, build menu, tower panel |

### Project structure

```
res://
  scenes/   (main, level, ui, towers, enemies)
  scripts/  (managers, components)
  data/     (towers/*.tres, enemies/*.tres, levels/*.tres)
  assets/   (art, audio, fonts)
  tests/    (GUT unit tests for pathfinding, economy, waves)
```

### Rules for Claude Code

- Keep everything as text based scenes (.tscn) and resources (.tres) so they can be edited directly.
- Typed GDScript throughout. Signals for communication between systems.
- Write unit tests for pathfinding and placement validation before building on them.
- Target 60 fps on an iPhone 11 with 150 enemies on screen.

## Build plan for Claude Code

Build in this order and playtest on a real phone after each milestone. Do not start art until Milestone 3 feels fun.

1. **Prototype the maze.** Grid, wall placement, path validation, one Goblin walking the live path. Shapes only.
2. **Core combat.** Archer and Stone towers, gold, lives, 5 waves on one map, win/lose.
3. **Fun check.** All 6 towers, 6 enemy types, upgrades, speed controls. Playtest with 3 to 5 people.
4. **Content.** World 1 (10 levels), level select, stars, save system.
5. **Monetization.** Free trial gate after level 5, IAP unlock, restore purchases, TestFlight beta.
6. **Art and audio.** Replace placeholders, polish effects and UI.
7. **Worlds 2 and 3.** Remaining 20 levels, bosses, Endless and Challenge modes, skill tree.
8. **Launch.** App Store assets, privacy labels, submission. Android build follows.

### Open questions

- [ ] Final game name (check App Store and trademark availability)
- [ ] Art source: AI generated or freelance artist
- [ ] Publish under NeuralSeek, TechD, or a new studio entity
- [ ] Launch price: $4.99 or test lower
