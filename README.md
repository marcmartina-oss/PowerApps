# Maze Keep (working title)

A portrait, one-handed maze-building tower defense for iPhone, built in Godot 4.6.
Players shape the path monsters walk, then defend it. Design: [`docs/design_doc_v2.md`](docs/design_doc_v2.md).

## Status

Build-plan **Milestones 1 and 2 are done** with placeholder shapes, ready for the first on-phone playtest:

- 9x14 grid with rocks, a gate and the keep
- Walls (5g), drag-to-paint walls, Archer (50g) and Stone Thrower (80g, splash, can't hit flyers)
- Ghost route preview before every placement; invalid placements show red and cost nothing
- Live mid-wave rerouting, with the anti-exploit rules: no reversals, a tile-revisit cap and a 1 s edit cooldown
- Gold, 20 lives, wave clear bonuses, 70% refunds, stars, win/lose, retry
- Targeting modes (First / Strongest / Fastest / Flyers), 1x/2x/3x speed, pause
- Level 1: 5 waves of Goblins, Wolf Riders and Orc Brutes
- 34 automated tests, including a bot that plays level 1 end to end

Next up is **Milestone 3 (fun check)**: the other 4 towers, more enemy types, upgrades with tier-3 specializations, then a 3–5 person playtest.

## Run it

1. Install [Godot 4.6](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` and press Play (F5). Mouse clicks and drags stand in for touch.

Tests:
```
godot --headless --import
godot --headless --fixed-fps 60 -s res://tests/run_tests.gd
```

## Getting it onto an iPhone

iOS builds require a Mac with Xcode. They cannot be made on Windows or Linux.

**One-time setup**
1. Join the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year). Decide which entity publishes it first (NeuralSeek, TechD or a new studio). That's an open question in the design doc, and changing it later means an app transfer.
2. Install Xcode from the Mac App Store and open it once to accept the license.
3. In Godot, run **Editor → Manage Export Templates → Download and Install**.
4. Note your **Team ID** (developer.apple.com → Account → Membership).

**Export and run on your phone**
1. In Godot open **Project → Export → iOS** (the preset already exists).
2. Set **App Store Team ID** and a real **Bundle Identifier**, such as `com.neuralseek.mazekeep`. It's currently the placeholder `com.example.mazekeep`.
3. For a quick device test, check **Export Project Only**, export, open the generated `.xcodeproj` in Xcode, plug in your iPhone and press Run.
4. For TestFlight, set the release export method to App Store, then in Xcode use **Product → Archive → Distribute App → App Store Connect**. In [App Store Connect](https://appstoreconnect.apple.com), create the app record with the same bundle ID and add testers.

**Before App Store submission (Milestones 5–8)**
- Non-consumable IAP "Full Game" ($4.99) in App Store Connect with Family Sharing on; StoreKit plugin plus **Restore Purchases** in Settings
- Enroll in the App Store Small Business Program (15% commission)
- Privacy labels: "Data Not Collected" fits if there's no analytics; Game Center for Endless high scores
- Final 1024x1024 icon (`assets/icons/icon.png` is a placeholder), screenshots for 6.9" and 6.5" iPhones, and a privacy policy URL

## Project layout
```
scenes/    level, enemies, towers (text .tscn)
scripts/   managers/, components/, data/, ui/
data/      towers/*.tres, enemies/*.tres, levels/*.tres
assets/    icons (art and audio arrive in Milestone 6)
tests/     run_tests.gd + test_*.gd
docs/      design doc
```
