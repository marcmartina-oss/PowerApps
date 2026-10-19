#!/usr/bin/env python3
"""Generates every data resource for Maze Keep: towers, enemies, the 30-level
campaign, endless maps, challenges and the campaign index.

Run from the project root:  python3 tools/gen_content.py
Then re-import:             godot --headless --import

Deterministic: the same script always writes the same files, so balance
changes are plain diffs. Map layouts are validated here (every gate must reach
the keep around the terrain) so the game never loads a broken level.
"""
from __future__ import annotations

import os
import random
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
W, H = 9, 14

# --------------------------------------------------------------------------
# Towers
# --------------------------------------------------------------------------

SPECS = {
    "longbow": ("Longbow", "+1.5 range", "LONGBOW", 1.5),
    "volley": ("Volley", "Fires 3 arrows", "VOLLEY", 3),
    "boulder": ("Boulder", "Bigger, harder splash", "BOULDER", 1.4),
    "quake": ("Quake", "Splash stuns 1s", "QUAKE", 1.0),
    "blizzard": ("Blizzard", "Slows all in range", "BLIZZARD", 1.0),
    "shatter": ("Shatter", "x2.5 dmg to slowed", "SHATTER", 2.5),
    "inferno": ("Inferno", "Wider burning cone", "INFERNO", 0.8),
    "wildfire": ("Wildfire", "Burn spreads", "WILDFIRE", 1.0),
    "lightning": ("Lightning", "Chains to 3 more", "LIGHTNING", 3),
    "void": ("Void", "True damage x1.5", "VOID", 1.5),
    "rally": ("Rally", "+45% attack speed", "RALLY", 0.45),
    "bounty": ("Bounty", "+50% gold on kills", "BOUNTY", 0.5),
}

TOWERS = {
    # id: (name, description, cost, dmg, dmg_type, range, interval, proj_speed, splash, flyers, look, color,
    #      effect, eff_strength, eff_duration, up_costs, up_mult, up_range, spec_a, spec_b)
    "archer": ("Archer", "Fast single shots. Hits flyers.", 50, 10, 0, 2.6, 0.5, 14, 0.0, True, 0, "0.35, 0.75, 0.35",
               0, 0, 0, [60, 110], 1.5, 0.3, "longbow", "volley"),
    "stone_thrower": ("Stone", "Slow boulders that splash groups. Can't hit flyers.", 80, 22, 0, 3.0, 1.6, 9, 0.9, False, 1, "0.7, 0.6, 0.45",
                      0, 0, 0, [90, 160], 1.5, 0.3, "boulder", "quake"),
    "frost_mage": ("Frost", "Slows enemies it hits. Hits flyers.", 90, 6, 1, 2.5, 0.8, 12, 0.0, True, 2, "0.55, 0.85, 1.0",
                   1, 0.5, 2.0, [100, 170], 1.45, 0.3, "blizzard", "shatter"),
    "flame_brazier": ("Flame", "Short range burn over time. Slowed + burning = Thermal Shock.", 100, 4, 0, 1.6, 0.7, 10, 0.5, False, 3, "1.0, 0.5, 0.15",
                      2, 12, 3.0, [110, 180], 1.5, 0.2, "inferno", "wildfire"),
    "arcane_spire": ("Arcane", "Heavy magic bolts that pierce armor. Hits flyers.", 140, 40, 1, 3.0, 1.4, 16, 0.0, True, 4, "0.75, 0.45, 1.0",
                     0, 0, 0, [150, 240], 1.55, 0.3, "lightning", "void"),
    "war_banner": ("Banner", "No attack. Adjacent towers fire 12% faster per tier.", 120, 0, 0, 1.5, 1.0, 1, 0.0, False, 5, "0.9, 0.25, 0.25",
                   3, 0.12, 0, [100, 160], 1.0, 0.0, "rally", "bounty"),
}


def spec_block(sid: str, key: str) -> str:
    name, desc, kind, value = SPECS[sid]
    kind_index = ["LONGBOW", "VOLLEY", "BOULDER", "QUAKE", "BLIZZARD", "SHATTER", "INFERNO", "WILDFIRE", "LIGHTNING", "VOID", "RALLY", "BOUNTY"].index(kind)
    return f"""[sub_resource type="Resource" id="{key}"]
script = ExtResource("2_spec")
id = &"{sid}"
display_name = "{name}"
description = "{desc}"
kind = {kind_index}
value = {float(value)}
"""


def write_towers() -> None:
    (DATA / "towers").mkdir(parents=True, exist_ok=True)
    for tid, t in TOWERS.items():
        (name, desc, cost, dmg, dtype, rng, interval, pspeed, splash, flyers, look, color,
         effect, es, ed, up_costs, up_mult, up_range, sa, sb) = t
        body = f"""[gd_resource type="Resource" script_class="TowerData" format=3]

[ext_resource type="Script" path="res://scripts/data/tower_data.gd" id="1_tower"]
[ext_resource type="Script" path="res://scripts/data/tower_spec.gd" id="2_spec"]

{spec_block(sa, "spec_a")}
{spec_block(sb, "spec_b")}
[resource]
script = ExtResource("1_tower")
id = &"{tid}"
display_name = "{name}"
description = "{desc}"
cost = {cost}
damage = {float(dmg)}
damage_type = {dtype}
attack_range = {rng}
fire_interval = {interval}
projectile_speed = {float(pspeed)}
splash_radius = {splash}
hits_flyers = {str(flyers).lower()}
look = {look}
color = Color({color}, 1)
effect = {effect}
effect_strength = {float(es)}
effect_duration = {float(ed)}
upgrade_costs = Array[int]([{up_costs[0]}, {up_costs[1]}])
upgrade_damage_mult = {up_mult}
upgrade_range_add = {up_range}
spec_a = SubResource("spec_a")
spec_b = SubResource("spec_b")
"""
        (DATA / "towers" / f"{tid}.tres").write_text(body)


# --------------------------------------------------------------------------
# Enemies
# --------------------------------------------------------------------------

ENEMIES = {
    # id: dict of fields
    "goblin": dict(name="Goblin", hp=26, speed=1.6, armor=0.0, lives=1, gold=3, radius=0.22, look=0, color="0.55, 0.85, 0.3"),
    "wolf_rider": dict(name="Wolf Rider", hp=24, speed=3.0, armor=0.0, lives=1, gold=4, radius=0.26, look=1, color="0.75, 0.75, 0.8"),
    "orc_brute": dict(name="Orc Brute", hp=150, speed=0.9, armor=0.25, lives=1, gold=10, radius=0.34, look=2, color="0.35, 0.55, 0.25"),
    "armored_knight": dict(name="Armored Knight", hp=110, speed=1.1, armor=0.6, lives=1, gold=9, radius=0.3, look=3, color="0.7, 0.72, 0.78"),
    "bat_swarm": dict(name="Bat Swarm", hp=18, speed=2.2, armor=0.0, lives=1, gold=3, radius=0.22, look=4, color="0.4, 0.3, 0.5", flying=True),
    "sapper": dict(name="Sapper", hp=60, speed=1.4, armor=0.0, lives=1, gold=7, radius=0.26, look=5, color="0.8, 0.55, 0.3", breaks_walls=True, smash_time=2.0),
    "slime_small": dict(name="Slimeling", hp=25, speed=1.4, armor=0.0, lives=1, gold=2, radius=0.18, look=6, color="0.4, 0.9, 0.6"),
    "slime": dict(name="Slime", hp=70, speed=1.0, armor=0.0, lives=1, gold=5, radius=0.32, look=6, color="0.3, 0.85, 0.5", split_into="slime_small", split_count=2),
    "shaman": dict(name="Shaman", hp=55, speed=1.2, armor=0.0, lives=1, gold=8, radius=0.26, look=7, color="0.5, 0.35, 0.6", heal=8, heal_radius=1.5, heal_interval=2.0),
    "ghost": dict(name="Ghost", hp=45, speed=1.3, armor=0.0, lives=1, gold=7, radius=0.26, look=8, color="0.8, 0.9, 1.0", phases_walls=True, phase_interval=4.0),
    "troll_king": dict(name="Troll King", hp=1800, speed=0.6, armor=0.3, lives=5, gold=120, radius=0.45, look=9, color="0.45, 0.6, 0.35", boss=True, breaks_walls=True, smash_time=1.0),
    "dragon": dict(name="Dragon", hp=2200, speed=0.9, armor=0.2, lives=5, gold=150, radius=0.5, look=10, color="0.85, 0.25, 0.2", boss=True, flying=True),
    "lich": dict(name="Lich", hp=2600, speed=0.7, armor=0.2, lives=5, gold=200, radius=0.42, look=11, color="0.3, 0.25, 0.45", boss=True, phases_walls=True, phase_interval=3.0, heal=25, heal_radius=2.5, heal_interval=1.5),
}


def write_enemies() -> None:
    (DATA / "enemies").mkdir(parents=True, exist_ok=True)
    for eid, e in ENEMIES.items():
        ext = ['[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1_enemy"]']
        split = ""
        if "split_into" in e:
            ext.append(f'[ext_resource type="Resource" path="res://data/enemies/{e["split_into"]}.tres" id="2_split"]')
            split = f'split_into = ExtResource("2_split")\nsplit_count = {e.get("split_count", 2)}\n'
        body = "[gd_resource type=\"Resource\" script_class=\"EnemyData\" format=3]\n\n" + "\n".join(ext) + f"""

[resource]
script = ExtResource("1_enemy")
id = &"{eid}"
display_name = "{e['name']}"
max_health = {float(e['hp'])}
speed = {e['speed']}
armor = {e['armor']}
lives_cost = {e['lives']}
gold_reward = {e['gold']}
radius = {e['radius']}
look = {e['look']}
color = Color({e['color']}, 1)
is_boss = {str(e.get('boss', False)).lower()}
flying = {str(e.get('flying', False)).lower()}
breaks_walls = {str(e.get('breaks_walls', False)).lower()}
smash_time = {float(e.get('smash_time', 2.0))}
phases_walls = {str(e.get('phases_walls', False)).lower()}
phase_interval = {float(e.get('phase_interval', 4.0))}
heal_amount = {float(e.get('heal', 0))}
heal_radius = {float(e.get('heal_radius', 1.5))}
heal_interval = {float(e.get('heal_interval', 2.0))}
{split}"""
        (DATA / "enemies" / f"{eid}.tres").write_text(body)


# --------------------------------------------------------------------------
# Maps
# --------------------------------------------------------------------------

def reachable(blocked: set, start: tuple, goal: tuple) -> bool:
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        if (x, y) == goal:
            return True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in blocked and n not in seen:
                seen.add(n)
                q.append(n)
    return False


def make_map(seed: int, gates: list, keep: tuple, rock_n: int, water_n: int, ruin_n: int, alt_gates=()) -> dict:
    """Scatter terrain so that every gate still reaches the keep and the map
    keeps plenty of open tiles to build on. Terrain comes in short clumps so
    maps read as rock outcrops, ponds and old walls rather than noise."""
    rng = random.Random(seed)
    protected = set(gates) | set(alt_gates) | {keep}
    # Keep the tiles right in front of gates and the keep open.
    for gx, gy in list(gates) + list(alt_gates):
        for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1), (1, 1), (-1, 1)):
            protected.add((gx + dx, gy + dy))
    for dx, dy in ((0, -1), (1, 0), (-1, 0), (1, -1), (-1, -1)):
        protected.add((keep[0] + dx, keep[1] + dy))
    layers = {"rocks": [], "water": [], "ruins": []}
    for kind, n in (("rocks", rock_n), ("water", water_n), ("ruins", ruin_n)):
        placed = 0
        tries = 0
        while placed < n and tries < 400:
            tries += 1
            x, y = rng.randrange(W), rng.randrange(1, H - 1)
            clump = [(x, y)]
            if rng.random() < 0.6:
                dx, dy = rng.choice(((1, 0), (0, 1)))
                clump.append((x + dx, y + dy))
            ok = True
            blocked = {c for layer in layers.values() for c in layer}
            for c in clump:
                if not (0 <= c[0] < W and 0 <= c[1] < H) or c in protected or c in blocked:
                    ok = False
            if not ok:
                continue
            trial = blocked | set(clump)
            if all(reachable(trial, g, keep) for g in list(gates) + list(alt_gates)):
                layers[kind].extend(clump)
                placed += len(clump)
    return layers


# --------------------------------------------------------------------------
# Waves
# --------------------------------------------------------------------------

# Level at which each enemy first appears in the campaign.
INTRO = {
    "goblin": 1, "wolf_rider": 3, "orc_brute": 4, "bat_swarm": 5, "sapper": 6, "armored_knight": 7,
    "slime": 8, "shaman": 9, "ghost": 12, "troll_king": 10, "dragon": 20, "lich": 30,
}
BOSSES = {10: "troll_king", 20: "dragon", 30: "lich"}
# Rough "threat" per enemy, used to spend a wave's budget.
THREAT = {"goblin": 1.0, "wolf_rider": 1.3, "orc_brute": 4.0, "bat_swarm": 1.0, "sapper": 2.2, "armored_knight": 3.5,
          "slime": 3.0, "shaman": 2.5, "ghost": 2.2}

# Towers available from each level on.
TOWER_UNLOCK = {"archer": 1, "stone_thrower": 1, "frost_mage": 5, "flame_brazier": 8, "arcane_spire": 14, "war_banner": 23}


def waves_for(level: int, count: int, gates: int, rng: random.Random) -> list:
    roster = [e for e, intro in INTRO.items() if intro <= level and e not in BOSSES.values()]
    newest = max(roster, key=lambda e: INTRO[e])
    waves = []
    for w in range(count):
        budget = (6 + level * 0.9) * (1 + 0.28 * w)
        groups = []
        picks = [newest] if w in (1, count - 1) or (newest == "goblin") else []
        extra = rng.sample(roster, k=min(len(roster), 1 + (w % 3 == 2)))
        for e in extra:
            if e not in picks:
                picks.append(e)
        if w == 0 and level > 2:
            picks = ["goblin"] if "goblin" in roster else picks[:1]
        per = budget / len(picks)
        delay = 0.0
        for i, e in enumerate(picks):
            n = max(2, min(30, round(per / THREAT[e])))
            if e == "shaman":
                n = max(1, min(4, n // 3))
            interval = round(max(0.35, 1.3 - level * 0.025 - w * 0.03), 2)
            groups.append(dict(enemy=e, count=n, interval=interval, delay=round(delay, 1), gate=i % gates))
            delay += n * interval * 0.5
        if w == count - 1 and level in BOSSES:
            groups.append(dict(enemy=BOSSES[level], count=1, interval=4.0, delay=round(delay + 2, 1), gate=0))
            if level == 30:
                groups.append(dict(enemy="troll_king", count=2, interval=6.0, delay=round(delay + 10, 1), gate=0))
        waves.append(dict(groups=groups, bonus=20 + level * 3 + w * 4))
    return waves


# --------------------------------------------------------------------------
# Levels
# --------------------------------------------------------------------------

LEVEL_NAMES = [
    "The Old Road", "Miller's Field", "Fox Hollow", "Orchard Gate", "Bat Belfry",
    "The Breach", "Knight's Crossing", "Slime Bog", "Shaman's Rise", "The Troll King",
    "Marsh Edge", "Will-o'-Wisp", "Twin Fords", "Drowned Chapel", "Reed Maze",
    "Ghost Light", "The Sunken Road", "Heron Watch", "Mire of Bones", "The Dragon's Nest",
    "Foothills", "Scree Pass", "Shifting Gates", "Lava Run", "Stone Rations",
    "Eagle Ledge", "The Crucible", "Narrow Spine", "Last Rampart", "The Lich's Throne",
]

TUTORIAL = {
    1: [
        ("LEVEL_START", "Welcome, Keeper! Goblins will march from the GATE to your KEEP. Tap the glowing tile and build an Archer there.", (4, 3), 0),
        ("TOWER_BUILT", "Your Archer's range is shown as a circle. The white line is the monsters' route. Tap START WAVE when ready.", (-1, -1), 0),
        ("WAVE_CLEARED", "Each kill earns gold (◆). Each monster that reaches the keep costs a life (♥). Lose all 20 and the keep falls.", (-1, -1), 1),
    ],
    2: [
        ("LEVEL_START", "Walls cost only 5 gold. Tap a tile and build a Wall, or DRAG your finger to paint a whole line of walls.", (-1, -1), 0),
        ("WALL_BUILT", "See how the yellow preview showed the new route before you built? Longer routes mean more time under fire. Try to make the monsters zig-zag.", (-1, -1), 0),
        ("INVALID_PLACEMENT", "You can never block the path completely. A red tile means that build is refused, and nothing is charged.", (-1, -1), 0),
    ],
    3: [
        ("LEVEL_START", "The Stone tower splashes groups but can't hit flyers. Tap any tower to UPGRADE it, change targeting, or SELL it for 70% back.", (-1, -1), 0),
        ("WAVE_STARTED", "You can still build during a wave! Monsters re-route live, but edits need 1 second between them, and they can never be forced to double back.", (-1, -1), 1),
        ("WAVE_CLEARED", "Check the NEXT wave preview at the top: flyers ignore your maze and sappers smash walls, so no single maze wins everything.", (-1, -1), 1),
    ],
}


def tutorial_blocks(level: int) -> tuple:
    steps = TUTORIAL.get(level, [])
    subs = []
    ids = []
    triggers = ["LEVEL_START", "TOWER_BUILT", "WALL_BUILT", "WAVE_STARTED", "WAVE_CLEARED", "INVALID_PLACEMENT", "STRUCTURE_SOLD", "TOWER_UPGRADED"]
    for i, (trigger, text, hl, wave) in enumerate(steps):
        sid = f"tut_{i}"
        ids.append(sid)
        subs.append(f"""[sub_resource type="Resource" id="{sid}"]
script = ExtResource("4_tut")
text = "{text}"
trigger = {triggers.index(trigger)}
highlight = Vector2i({hl[0]}, {hl[1]})
wave = {wave}
""")
    return "\n".join(subs), ids


def vec_array(cells) -> str:
    return "Array[Vector2i]([" + ", ".join(f"Vector2i({x}, {y})" for x, y in cells) + "])"


def level_resource(spec: dict) -> str:
    """Builds the .tres text for one LevelData from a plain dict."""
    enemies_used = sorted({g["enemy"] for w in spec["waves"] for g in w["groups"]} | set(spec.get("pool", [])))
    towers = spec["towers"]
    ext = [
        '[ext_resource type="Script" path="res://scripts/data/level_data.gd" id="1_level"]',
        '[ext_resource type="Script" path="res://scripts/data/wave_data.gd" id="2_wave"]',
        '[ext_resource type="Script" path="res://scripts/data/spawn_group.gd" id="3_group"]',
        '[ext_resource type="Script" path="res://scripts/data/tutorial_step.gd" id="4_tut"]',
        '[ext_resource type="Script" path="res://scripts/data/tower_data.gd" id="5_tower"]',
        '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="6_enemy"]',
    ]
    for e in enemies_used:
        ext.append(f'[ext_resource type="Resource" path="res://data/enemies/{e}.tres" id="e_{e}"]')
    for t in sorted(set(towers) | set(spec.get("unlocks", []))):
        ext.append(f'[ext_resource type="Resource" path="res://data/towers/{t}.tres" id="t_{t}"]')
    subs = []
    wave_ids = []
    for wi, w in enumerate(spec["waves"]):
        gids = []
        for gi, g in enumerate(w["groups"]):
            gid = f"w{wi}_g{gi}"
            gids.append(gid)
            subs.append(f"""[sub_resource type="Resource" id="{gid}"]
script = ExtResource("3_group")
enemy = ExtResource("e_{g['enemy']}")
count = {g['count']}
interval = {g['interval']}
start_delay = {g['delay']}
gate_index = {g['gate']}
""")
        wid = f"wave_{wi}"
        wave_ids.append(wid)
        subs.append(f"""[sub_resource type="Resource" id="{wid}"]
script = ExtResource("2_wave")
groups = Array[ExtResource("3_group")]([{", ".join(f'SubResource("{g}")' for g in gids)}])
clear_bonus = {w['bonus']}
""")
    tut_text, tut_ids = tutorial_blocks(spec.get("tutorial_level", 0))
    if tut_text:
        subs.append(tut_text)
    body = "[gd_resource type=\"Resource\" script_class=\"LevelData\" format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(subs)
    body += f"""
[resource]
script = ExtResource("1_level")
id = &"{spec['id']}"
display_name = "{spec['name']}"
description = "{spec.get('description', '')}"
mode = {spec.get('mode', 0)}
world = {spec['world']}
number = {spec.get('number', 0)}
grid_size = Vector2i({W}, {H})
gates = {vec_array(spec['gates'])}
alt_gates = {vec_array(spec.get('alt_gates', []))}
shifting_gates = {str(bool(spec.get('alt_gates'))).lower()}
keep = Vector2i({spec['keep'][0]}, {spec['keep'][1]})
rocks = {vec_array(spec['rocks'])}
water = {vec_array(spec['water'])}
ruins = {vec_array(spec['ruins'])}
starting_gold = {spec['gold']}
starting_lives = 20
wall_cost = 5
wall_budget = {spec.get('wall_budget', -1)}
walls_allowed = {str(spec.get('walls_allowed', True)).lower()}
speed_multiplier = {float(spec.get('speed', 1.0))}
available_towers = Array[ExtResource("5_tower")]([{", ".join(f'ExtResource("t_{t}")' for t in towers)}])
waves = Array[ExtResource("2_wave")]([{", ".join(f'SubResource("{w}")' for w in wave_ids)}])
endless_pool = Array[ExtResource("6_enemy")]([{", ".join(f'ExtResource("e_{e}")' for e in spec.get('pool', []))}])
tutorial = Array[ExtResource("4_tut")]([{", ".join(f'SubResource("{t}")' for t in tut_ids)}])
unlocks_towers = Array[ExtResource("5_tower")]([{", ".join(f'ExtResource("t_{t}")' for t in spec.get('unlocks', []))}])
"""
    return body


def campaign_levels() -> list:
    specs = []
    for n in range(1, 31):
        world = (n - 1) // 10 + 1
        rng = random.Random(1000 + n)
        keep = (4, 13)
        gates = [(4, 0)]
        alt_gates = []
        if world == 2 and n >= 13:
            gates = [(1, 0), (7, 0)]
        if world == 3:
            gates = [(rng.choice([2, 4, 6]), 0)]
            if n >= 23:
                alt_gates = [(0, rng.choice([3, 4, 5])) if n % 2 else (8, rng.choice([3, 4, 5]))]
        if world == 1:
            terrain = make_map(n, gates, keep, rock_n=min(2 + n, 10), water_n=0, ruin_n=2 if n > 4 else 0, alt_gates=alt_gates)
        elif world == 2:
            terrain = make_map(n, gates, keep, rock_n=3, water_n=min(4 + (n - 10) * 2, 14), ruin_n=4, alt_gates=alt_gates)
        else:
            terrain = make_map(n, gates, keep, rock_n=min(6 + (n - 20), 14), water_n=min(2 + (n - 20) // 2, 8), ruin_n=2, alt_gates=alt_gates)
        wave_count = 5 + (n - 1) // 4
        if n in BOSSES:
            wave_count += 2
        towers = [t for t, lv in TOWER_UNLOCK.items() if lv <= n]
        unlocks = [t for t, lv in TOWER_UNLOCK.items() if lv == n + 1]
        spec = dict(
            id=f"level_{n:02d}", name=LEVEL_NAMES[n - 1], world=world, number=n, gates=gates, alt_gates=alt_gates, keep=keep,
            gold=150 + n * 10 + (60 if n in BOSSES else 0), towers=towers, unlocks=unlocks,
            waves=waves_for(n, wave_count, len(gates), rng), tutorial_level=n if n <= 3 else 0, **terrain,
        )
        if n in (25, 28):
            spec["wall_budget"] = 18 if n == 25 else 12
            spec["description"] = "Limited walls"
        specs.append(spec)
    return specs


def endless_maps() -> list:
    pool = ["goblin", "wolf_rider", "bat_swarm", "orc_brute", "sapper", "armored_knight", "slime", "shaman", "ghost", "troll_king"]
    maps = []
    for i, (name, world, gates) in enumerate((("Endless: Borderlands", 1, [(4, 0)]), ("Endless: Marsh", 2, [(1, 0), (7, 0)]), ("Endless: Peaks", 3, [(4, 0)]))):
        rng = random.Random(5000 + i)
        keep = (4, 13)
        terrain = make_map(5000 + i, gates, keep, rock_n=6, water_n=6 if world == 2 else 2, ruin_n=3)
        waves = waves_for(8 + i * 6, 3, len(gates), rng)
        maps.append(dict(id=f"endless_{i + 1}", name=name, mode=1, world=world, gates=gates, keep=keep, gold=220, towers=list(TOWERS), waves=waves, pool=pool, **terrain))
    return maps


def challenges() -> list:
    specs = []
    rng = random.Random(7000)
    base = dict(keep=(4, 13), gold=260)
    terrain1 = make_map(7001, [(4, 0)], (4, 13), 6, 0, 2)
    specs.append(dict(id="challenge_archers", name="Archers Only", description="Only Archer Posts", mode=2, world=1, gates=[(4, 0)],
                      towers=["archer"], waves=waves_for(9, 7, 1, rng), **base, **terrain1))
    terrain2 = make_map(7002, [(1, 0), (7, 0)], (4, 13), 3, 8, 4)
    specs.append(dict(id="challenge_nowalls", name="No Walls", description="Towers are your only walls", mode=2, world=2, gates=[(1, 0), (7, 0)],
                      towers=list(TOWERS), walls_allowed=False, waves=waves_for(14, 7, 2, rng), **base, **terrain2))
    terrain3 = make_map(7003, [(4, 0)], (4, 13), 8, 4, 2)
    specs.append(dict(id="challenge_speed", name="Double Speed", description="Everything moves twice as fast", mode=2, world=3, gates=[(4, 0)],
                      towers=list(TOWERS), speed=2.0, waves=waves_for(18, 7, 1, rng), **base, **terrain3))
    return specs


def write_levels() -> None:
    (DATA / "levels").mkdir(parents=True, exist_ok=True)
    for old in (DATA / "levels").glob("*.tres"):
        old.unlink()
    all_specs = campaign_levels() + endless_maps() + challenges()
    for spec in all_specs:
        (DATA / "levels" / f"{spec['id']}.tres").write_text(level_resource(spec))
    camp = campaign_levels()
    ends = endless_maps()
    chal = challenges()
    ext = ['[ext_resource type="Script" path="res://scripts/data/campaign_data.gd" id="1_campaign"]',
           '[ext_resource type="Script" path="res://scripts/data/level_data.gd" id="2_level"]']
    for spec in camp + ends + chal:
        ext.append(f'[ext_resource type="Resource" path="res://data/levels/{spec["id"]}.tres" id="{spec["id"]}"]')
    body = "[gd_resource type=\"Resource\" script_class=\"CampaignData\" format=3]\n\n" + "\n".join(ext) + f"""

[resource]
script = ExtResource("1_campaign")
levels = Array[ExtResource("2_level")]([{", ".join(f'ExtResource("{s["id"]}")' for s in camp)}])
endless_maps = Array[ExtResource("2_level")]([{", ".join(f'ExtResource("{s["id"]}")' for s in ends)}])
challenges = Array[ExtResource("2_level")]([{", ".join(f'ExtResource("{s["id"]}")' for s in chal)}])
challenge_star_costs = Array[int]([10, 25, 45])
"""
    (DATA / "campaign.tres").write_text(body)


if __name__ == "__main__":
    os.chdir(ROOT)
    write_towers()
    write_enemies()
    write_levels()
    print("wrote", len(list((DATA / "towers").glob("*.tres"))), "towers,",
          len(list((DATA / "enemies").glob("*.tres"))), "enemies,",
          len(list((DATA / "levels").glob("*.tres"))), "levels")
