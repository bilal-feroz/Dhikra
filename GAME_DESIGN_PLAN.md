# Dhikra: Complete Game Design & Build Plan

> A desert survival exploration game with environmental puzzles, asynchronous social mechanics, and the theme of memory/legacy.

---

## Part 1: MVP Recommendation

### The Core Loop (10-15 Minutes of Gameplay)

**Selected MVP Mechanics (5 total):**

| Mechanic | Why It's Essential |
|----------|-------------------|
| **1. Shadow Path Puzzle** | Creates immediate tension + teaches resource management. Uses existing shade system. |
| **2. Day/Night Cycle** | Gives rhythm to gameplay. Night = navigation challenge, Day = heat challenge. Already have time variable. |
| **3. Sandstorm Events** | Creates dramatic moments. Forces decisions (shelter vs. push forward). Reuses shade mechanics. |
| **4. Basic Inscriptions + Ghost Trails** | The soul of your game. Async help without complex infrastructure. |
| **5. Archaeological Dig Patterns** | Uses existing shovel/dig system. Rewards exploration + observation. |

### Why This Slice?

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE MVP LOOP                             │
│                                                                 │
│   START ──► Cross shadow paths (day) ──► Find dig site         │
│     ▲                                         │                 │
│     │                                         ▼                 │
│     │                              Uncover map fragment         │
│     │                                         │                 │
│     │       ◄── Survive storm ◄──────────────┘                 │
│     │              │                                            │
│     │              ▼                                            │
│   OASIS ◄── Night navigation (ghost trails help) ◄── Read      │
│     │              inscriptions from dead players               │
│     │                                                           │
│     └──────────────► REACH NEXT OASIS ──► WIN                  │
└─────────────────────────────────────────────────────────────────┘
```

**This creates:**
- **Tension**: Water drains, storms hit, shade moves
- **Discovery**: Dig patterns reveal secrets
- **Connection**: Ghost trails and inscriptions from other players
- **Mastery**: Learn shadow timing, storm patterns, dig locations

---

## Part 2: Step-by-Step Build Plan

### Phase 1: Core Systems (Week 1-2)

#### 1.1 Day/Night Cycle System

**Player-Facing Behavior:**
- Sky color shifts from orange (dawn) → white (noon) → orange (dusk) → dark blue (night)
- Sun position affects shadow directions
- Water drain rate changes: Day = -3/tick, Night = -1/tick
- Visibility range shrinks at night

**Data Needed:**
```
time_of_day: float        # 0.0 = midnight, 0.5 = noon, 1.0 = midnight again
day_length_seconds: 300   # 5 real minutes = 1 game day
sun_angle: float          # Derived from time_of_day (0-360 degrees)
current_period: enum      # DAWN, DAY, DUSK, NIGHT
```

**State Transitions:**
```
NIGHT (0.0 - 0.20)  → water_drain = BASE * 0.33, visibility = 40%
DAWN  (0.20 - 0.30) → water_drain = BASE * 0.66, visibility = 70%
DAY   (0.30 - 0.70) → water_drain = BASE * 1.0,  visibility = 100%
DUSK  (0.70 - 0.80) → water_drain = BASE * 0.66, visibility = 70%
NIGHT (0.80 - 1.0)  → water_drain = BASE * 0.33, visibility = 40%
```

**Edge Cases & Anti-Frustration:**
- If player is mid-puzzle when night falls, puzzle elements glow faintly
- Oases always have a small light source visible from 50 units away
- Death during transition periods shows "the desert is harsh at twilight" (not unfair)

---

#### 1.2 Enhanced Water/Survival System

**Player-Facing Behavior:**
- Water gauge depletes based on: time period + shade status + movement + events
- Visual feedback: screen edges tint red at <30%, pulse at <15%
- Audio: heartbeat sounds at critical levels
- Death = slow fade to white + "Your journey ends here. Others will follow your path."

**Data Needed:**
```
water: float              # 0-100 per flask
flasks: int               # Number of flasks owned
max_water: int            # flasks * 100
drain_modifiers: Dictionary {
    "base": 3.0,
    "shade": -2.0,        # Reduces drain
    "moving": 0.5,        # Slight increase when walking
    "storm": 4.0,         # Big increase during storms
    "night": -2.0         # Reduction at night
}
```

**Drain Calculation (per tick):**
```
final_drain = base_drain
if in_shade: final_drain += shade_modifier
if is_moving: final_drain += moving_modifier
if storm_active: final_drain += storm_modifier
if time_period == NIGHT: final_drain += night_modifier
final_drain = max(0.5, final_drain)  # Always some drain outside oasis
```

---

### Phase 2: Puzzle Systems (Week 3-4)

#### 2.1 Shadow Path System

**Player-Facing Behavior:**
- Certain zones marked as "sun scorched" (visible heat shimmer)
- Walking in scorched zones = 5x water drain
- Shade patches move with sun angle
- Player must time movement between shade spots

**Data Needed:**
```
# Per shadow-casting object:
shadow_length: float      # Based on sun_angle
shadow_direction: Vector2 # Opposite of sun position
shadow_polygon: Polygon2D # Generated each frame

# Per danger zone:
zone_bounds: Rect2
heat_multiplier: 5.0
is_shaded: bool           # Recalculated each frame
```

**Implementation:**
```
func update_shadows():
    var sun_height = sin(time_of_day * PI)  # 0 at night, 1 at noon
    var sun_x = cos(time_of_day * TAU)

    for caster in shadow_casters:
        # Long shadows at dawn/dusk, short at noon
        caster.shadow_length = caster.height / max(sun_height, 0.1)
        caster.shadow_direction = Vector2(-sun_x, 1).normalized()
        caster.update_shadow_polygon()

func check_shade(player_pos: Vector2) -> bool:
    for shadow in all_shadows:
        if shadow.polygon.contains_point(player_pos):
            return true
    return false
```

**Puzzle Scaling:**
| Tier | Description | Challenge |
|------|-------------|-----------|
| 1 | Single gap, slow shadow movement | Learn mechanic |
| 2 | Multiple gaps, must wait for shadows to align | Timing |
| 3 | Shadows from moving clouds, unpredictable | Observation + reaction |

**Visual/Audio Cues:**
- Heat shimmer particles on danger zones
- Shade has subtle blue tint
- Audio: sizzling sound intensifies in sun
- Player character wipes brow animation in heat

---

#### 2.2 Archaeological Dig Patterns

**Player-Facing Behavior:**
- Certain areas have faint markings in sand (only visible when close)
- Digging in correct pattern reveals: map fragments, water caches, ancient symbols
- Wrong digs just make empty holes (no punishment, but wastes time)
- Discovered patterns can be left as inscriptions for others

**Data Needed:**
```
# Per dig site:
site_id: String
pattern_shape: Array[Vector2]  # Relative positions to dig
required_digs: int             # How many correct spots
current_digs: Array[Vector2]   # Player's dig locations
reward_type: enum              # MAP_FRAGMENT, WATER_CACHE, SYMBOL, TOOL
is_discovered: bool
hint_inscription_ids: Array    # Which inscriptions give clues

# Saved data (persists):
discovered_sites: Array[String]
```

**Pattern Examples:**
```
TRIANGLE:       CROSS:          CONSTELLATION:
    *             *                 *
   * *          * * *             *   *
  *   *           *              *  *  *
```

**Implementation:**
```
func on_player_dig(dig_position: Vector2):
    var site = get_nearest_dig_site(dig_position)
    if site == null:
        spawn_empty_hole(dig_position)
        return

    var local_pos = dig_position - site.position
    var matches_pattern = false

    for pattern_point in site.pattern_shape:
        if local_pos.distance_to(pattern_point) < DIG_TOLERANCE:
            matches_pattern = true
            site.current_digs.append(pattern_point)
            break

    if matches_pattern:
        spawn_progress_hole(dig_position)  # Glows slightly
        play_sound("dig_correct")

        if site.current_digs.size() >= site.required_digs:
            reveal_reward(site)
    else:
        spawn_empty_hole(dig_position)
        play_sound("dig_empty")
```

**Anti-Frustration Rules:**
- Faint wind patterns blow toward dig sites
- After 3 wrong digs near a site, hint glyph appears briefly
- Correct digs glow, so player sees progress
- Sites don't reset until player leaves area (can take breaks)

---

### Phase 3: Survival Events (Week 4-5)

#### 3.1 Sandstorm System

**Player-Facing Behavior:**
- Warning: wind picks up 30 seconds before storm
- Storm lasts 45-90 seconds
- During storm: visibility drops to 20%, water drain +4/tick, movement slowed 30%
- Shelter (rocks, ruins, oasis structures) negates effects
- Storms can shift sand dunes, changing pathways

**Data Needed:**
```
storm_state: enum         # CALM, WARNING, ACTIVE, CLEARING
storm_timer: float
storm_duration: float     # Randomized 45-90
next_storm_time: float    # Randomized based on area danger level
shelter_zones: Array[Area2D]

# For dune shifting:
dune_positions: Array[Vector2]
dune_shift_amount: Vector2
```

**State Machine:**
```
CALM:
    - Countdown to next storm
    - Check random trigger (more likely in open desert)
    - Transition: timer expires → WARNING

WARNING (30 sec):
    - Wind particles increase
    - Audio: rising wind sound
    - UI: "A storm approaches" fades in
    - Transition: timer expires → ACTIVE

ACTIVE (45-90 sec):
    - Full particle effects
    - Apply all storm penalties
    - Every 15 sec: chance to shift dunes
    - Transition: timer expires → CLEARING

CLEARING (10 sec):
    - Particles fade
    - Penalties gradually reduce
    - Transition: timer expires → CALM, schedule next storm
```

**Dune Shifting Logic:**
```
func maybe_shift_dunes():
    if randf() < 0.3:  # 30% chance per interval
        var shift = Vector2(randf_range(-20, 20), randf_range(-20, 20))
        for dune in shiftable_dunes:
            var tween = create_tween()
            tween.tween_property(dune, "position", dune.position + shift, 2.0)

        # Invalidate player's memorized paths
        emit_signal("dunes_shifted")
```

---

#### 3.2 Night Dangers

**Player-Facing Behavior:**
- At night, visibility reduced but water drain lower
- Navigation harder: familiar landmarks less visible
- Rare: distant creature sounds (psychological, not combat)
- Stars visible: needed for star navigation puzzles (future feature)
- Ghost trails glow brighter at night (helping mechanic)

**Data Needed:**
```
night_visibility_radius: 150  # pixels
creature_sound_cooldown: float
ambient_fear_level: float     # 0-1, affects audio mix
```

**Implementation:**
```
func update_night_atmosphere():
    if current_period != NIGHT:
        return

    # Visibility mask
    player.visibility_mask.radius = night_visibility_radius

    # Random distant sounds
    if creature_sound_cooldown <= 0:
        if randf() < 0.1:  # 10% chance per check
            play_distant_sound(pick_random(["howl", "screech", "rumble"]))
            creature_sound_cooldown = randf_range(30, 120)

    # Ghost trails glow brighter
    for trail in ghost_trails:
        trail.modulate.a = 0.7  # More visible than day (0.3)
```

---

### Phase 4: Social/Async Systems (Week 5-6)

#### 4.1 Ghost Trails System

**Player-Facing Behavior:**
- Faint footprints appear showing paths of players who died nearby
- More deaths = more visible trail
- Trails fade over time (or after X new deaths)
- Player can follow trails to find: resources, danger, or mystery

**Data Needed:**
```
# Stored per trail (lightweight):
trail_id: String
path_points: Array[Vector2]  # Simplified to key waypoints
death_position: Vector2
death_cause: String          # "thirst", "storm", "heat"
player_name: String
timestamp: int
visit_count: int             # How many players have seen it

# Local cache:
visible_trails: Array[GhostTrail]
```

**Implementation:**
```
# On player death:
func record_death_trail():
    var trail_data = {
        "path": simplify_path(player.footprint_history),
        "death_pos": player.position,
        "cause": determine_death_cause(),
        "name": player.name,
        "time": Time.get_unix_time_from_system()
    }
    Playroom.send_trail(trail_data)

# On game load / entering area:
func load_ghost_trails(area_id: String):
    var trails = await Playroom.get_trails(area_id, limit=20)
    for trail_data in trails:
        spawn_ghost_trail(trail_data)

# Path simplification (reduce data):
func simplify_path(points: Array) -> Array:
    var simplified = [points[0]]
    var last_dir = Vector2.ZERO

    for i in range(1, points.size()):
        var dir = (points[i] - points[i-1]).normalized()
        if dir.dot(last_dir) < 0.95:  # Direction changed significantly
            simplified.append(points[i])
            last_dir = dir

    simplified.append(points[-1])  # Always include death point
    return simplified
```

**Visual Representation:**
```
# Ghost trail shader (simplified):
shader_type canvas_item;

uniform float time;
uniform float visibility = 0.3;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float flicker = sin(time * 2.0 + UV.x * 10.0) * 0.1 + 0.9;
    COLOR = vec4(0.7, 0.8, 1.0, tex.a * visibility * flicker);
}
```

---

#### 4.2 Enhanced Inscription System

**Player-Facing Behavior:**
- Existing phrase+noun system stays
- NEW: Inscriptions have trust indicators based on player reputation
- NEW: Helpful inscriptions glow gold, suspicious ones shimmer (mirage effect)
- Players can "confirm" or "doubt" inscriptions after testing them

**Data Needed:**
```
# Per inscription:
inscription_id: String
phrase: String
noun: String
position: Vector2
author_id: String
author_reputation: float    # 0-100
helpful_votes: int
doubt_votes: int
is_verified: bool           # Majority helpful votes

# Reputation formula:
trust_score = (helpful_votes - doubt_votes) / total_votes
visual_style = "gold" if trust_score > 0.7 else "normal" if trust_score > 0.3 else "shimmer"
```

**Implementation:**
```
func render_inscription(inscription: Dictionary):
    var label = InscriptionLabel.instantiate()
    label.text = inscription.phrase + " " + inscription.noun
    label.position = inscription.position

    # Visual trust indicator
    var trust = calculate_trust(inscription)
    if trust > 0.7:
        label.add_shader(GOLD_GLOW_SHADER)
        label.add_particles(SPARKLE_PARTICLES)
    elif trust < 0.3:
        label.add_shader(MIRAGE_SHIMMER_SHADER)

    return label

func on_inscription_interaction(inscription_id: String, action: String):
    # After player tests the inscription
    match action:
        "helpful":
            Playroom.vote_inscription(inscription_id, +1)
            increase_author_reputation(inscription.author_id, 5)
        "misleading":
            Playroom.vote_inscription(inscription_id, -1)
            decrease_author_reputation(inscription.author_id, 3)
```

---

#### 4.3 Offering System

**Player-Facing Behavior:**
- At oases, player can "offer" one flask (sacrifice resource)
- Offering becomes a collectible for another player
- Offering shows donor's name + short message
- Collecting an offering triggers reputation boost for donor

**Data Needed:**
```
# Per offering:
offering_id: String
oasis_id: String
donor_id: String
donor_name: String
message: String           # Optional short text (max 20 chars)
timestamp: int
is_collected: bool
collector_id: String
```

**Implementation:**
```
func create_offering():
    if player.flasks < 2:  # Must have at least 1 remaining
        show_message("You cannot spare a flask.")
        return

    player.flasks -= 1

    var offering = {
        "oasis": current_oasis.id,
        "donor": player.id,
        "donor_name": player.name,
        "message": await prompt_short_message(),
        "time": Time.get_unix_time_from_system()
    }

    Playroom.create_offering(offering)
    spawn_offering_visual(offering)
    show_message("Your offering awaits a weary traveler.")

func collect_offering(offering_id: String):
    var offering = get_offering(offering_id)
    if offering.donor_id == player.id:
        show_message("This is your own offering.")
        return

    player.flasks += 1
    show_message(offering.donor_name + " left this for you: \"" + offering.message + "\"")

    Playroom.collect_offering(offering_id, player.id)
    Playroom.boost_reputation(offering.donor_id, 20)  # Big reputation boost
```

---

#### 4.4 Reputation System

**Player-Facing Behavior:**
- Reputation earned by: helpful inscriptions confirmed, offerings collected by others
- High reputation = golden aura visible to other players
- Reputation shown on death markers
- Top contributors shown on "Wall of Guides" at starting oasis

**Data Needed:**
```
# Per player (stored server-side):
player_id: String
reputation_score: int      # Starts at 0
inscriptions_created: int
inscriptions_confirmed: int
offerings_made: int
offerings_collected: int   # By others

# Reputation tiers:
WANDERER:   0-49      # No visual
GUIDE:      50-149    # Faint gold outline
SAGE:       150-299   # Gold aura
LEGEND:     300+      # Gold aura + particles
```

---

### Phase 5: UI/UX & Feedback (Week 6-7)

#### 5.1 HUD Elements

```
┌─────────────────────────────────────────────────────────────┐
│  [WATER ████████░░] 73%     [TIME: ☀ DAY]     [FLASK: ⚱⚱⚱] │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                     (GAME VIEW)                             │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│  [E] DIG    [R] SENSE    [T] INSCRIBE                      │
│                                                             │
│  ⚠ STORM APPROACHING (25s)                                 │
└─────────────────────────────────────────────────────────────┘
```

#### 5.2 Feedback Juice

| Event | Visual | Audio | Haptic (if supported) |
|-------|--------|-------|----------------------|
| Enter shade | Screen tint cools | Soft relief sigh | Light pulse |
| Leave shade | Heat shimmer edge | Sizzle starts | - |
| Find dig spot | Ground glows faint | Wind chime | - |
| Complete dig pattern | Golden burst | Achievement chord | Strong pulse |
| Storm warning | Edge particles | Rising wind | Rumble |
| Storm active | Full screen particles | Howling wind | Constant rumble |
| See ghost trail | Trail fades in | Whisper sound | - |
| Read inscription | Text animates in | Stone scrape | - |
| Water critical | Red pulse edges | Heartbeat | Rapid pulse |
| Death | White fade | Breath fades | Long fade |

---

### Phase 6: Content Building (Week 7-8)

#### 6.1 Level Layout Philosophy

```
                    ┌─────────────────┐
                    │  NORTHERN OASIS │ (END GOAL)
                    │   (Sanctuary)   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐
        │  RUINS    │  │  CANYON   │  │  DUNES    │
        │ (Dig area)│  │(Shadow puz)│  │ (Storms) │
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────┴────────┐
                    │ STARTING OASIS  │
                    │   (Tutorial)    │
                    └─────────────────┘
```

#### 6.2 Spawning Rules

```
# Dig sites:
- 1 guaranteed near starting oasis (tutorial)
- 2-3 per zone, randomized positions within valid areas
- At least 1 must be reachable without puzzles (beginner path)

# Shade objects:
- Placed to create puzzle gauntlets
- Always a safe path exists (may be longer)
- Moving clouds add randomness but follow patterns

# Storm triggers:
- Never in first 2 minutes of a new game
- Higher chance in open areas
- Never 2 storms within 3 minutes

# Ghost trails:
- Load 20 most recent deaths in current zone
- Prioritize deaths near player's current position
- Fade trails older than 24 hours
```

---

## Part 3: Puzzle Bible

### Shadow Path Puzzles

**Purpose:** Teaches timing, observation, and patience. Tests resource management (is it worth waiting vs. pushing through?).

| Tier | Layout | Challenge | Clue Fairness |
|------|--------|-----------|---------------|
| 1 | Single rock casting shadow across path | Wait for shadow to cover gap | Heat shimmer clearly shows danger zone |
| 2 | Multiple rocks, shadows don't always overlap | Chain movements between safe spots | Wind particles blow toward safe zones |
| 3 | Moving clouds + stationary objects | Predict cloud shadow timing | Clouds have consistent speed, visible approach |

**Reset/Change Behavior:**
- Sun angle changes shadows over time
- Sandstorms can move smaller shade objects
- Night makes puzzle trivial (no heat penalty) but navigation harder

**Integration with Other Systems:**
- Inscriptions can mark "SAFE PATH" or warn "BEWARE SUN"
- Ghost trails show where others died trying
- Storm forces player to abandon puzzle mid-attempt

---

### Archaeological Dig Puzzles

**Purpose:** Rewards exploration and observation. Tests pattern recognition and memory.

| Tier | Pattern | Hints Available | Reward |
|------|---------|-----------------|--------|
| 1 | Triangle (3 digs) | Faint sand mounds visible | Water cache (+30) |
| 2 | Cross (5 digs) | Ancient pillar points direction | Map fragment |
| 3 | Constellation (7 digs) | Requires night + star observation | Tool or relic |

**Visual/Audio Cues:**
- Faint wind spirals near dig sites
- Correct digs produce "thunk" sound, wrong digs produce "scrape"
- Progress glows remain for 60 seconds

**Reset Behavior:**
- Sites don't reset during a session
- Sandstorms can partially cover completed digs (re-dig to confirm)
- Each game run randomizes site positions within zones

**Inscription Integration:**
- Players can inscribe "DIG HERE" or pattern hints
- Ancient inscriptions (NPC-placed) give cryptic clues
- Multi-part clues require visiting multiple locations

---

### Cipher Message Puzzles (Post-MVP)

**Purpose:** Encourages exploration and connects distant locations. Tests memory and note-taking.

**Structure:**
```
Location A: "The path opens when..."
Location B: "...the sun meets..."
Location C: "...the third stone."

Combined = Go to third stone at noon to reveal hidden path
```

| Tier | Fragments | Distance | Clue Type |
|------|-----------|----------|-----------|
| 1 | 2 pieces | Same zone | Direct text |
| 2 | 3 pieces | Adjacent zones | Symbolic (sun = noon) |
| 3 | 4 pieces | Any zones | Requires tool to read |

---

### Trust Puzzles (Post-MVP)

**Purpose:** Teaches critical evaluation. Creates social gameplay depth.

**Mirage Tells (How Players Detect Lies):**
- Low-reputation inscriptions shimmer like mirages
- "PRAISE AQUA" pointing to empty sand has no wind spiral
- Inscriptions near death markers are often traps
- Helpful inscriptions have faint gold tint

**Anti-Grief Design:**
- Lies can't block the main path (alternate routes exist)
- After being misled, player gets "Desert Wisdom" buff (temporary lie detection)
- Repeated liars get "Trickster" reputation (visible warning)

---

## Part 4: Technical Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GAME MANAGER                            │
│  - Manages global state, save/load, scene transitions          │
└─────────────────────────────────────────────────────────────────┘
        │              │              │              │
        ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ TimeManager │ │SurvivalMgr  │ │ PuzzleMgr   │ │ AsyncMgr    │
│ - Day/night │ │ - Water     │ │ - Shadows   │ │ - Trails    │
│ - Sun angle │ │ - Storms    │ │ - Dig sites │ │ - Inscript. │
│ - Period    │ │ - Death     │ │ - Rewards   │ │ - Offerings │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

### Core Manager Pseudo-Code

```gdscript
# TimeManager.gd
extends Node

signal period_changed(new_period)
signal sun_angle_changed(angle)

var time_of_day: float = 0.25  # Start at dawn
var day_length: float = 300.0  # 5 minutes
var sun_angle: float = 0.0

enum Period { NIGHT, DAWN, DAY, DUSK }
var current_period: Period = Period.DAWN

func _process(delta):
    time_of_day += delta / day_length
    if time_of_day >= 1.0:
        time_of_day -= 1.0

    update_sun_angle()
    check_period_change()

func update_sun_angle():
    # Sun rises in east (0°), peaks at noon (90°), sets in west (180°)
    sun_angle = time_of_day * 360.0
    sun_angle_changed.emit(sun_angle)

func check_period_change():
    var new_period = calculate_period()
    if new_period != current_period:
        current_period = new_period
        period_changed.emit(new_period)

func calculate_period() -> Period:
    if time_of_day < 0.20 or time_of_day >= 0.80:
        return Period.NIGHT
    elif time_of_day < 0.30:
        return Period.DAWN
    elif time_of_day < 0.70:
        return Period.DAY
    else:
        return Period.DUSK

func get_drain_multiplier() -> float:
    match current_period:
        Period.NIGHT: return 0.33
        Period.DAWN, Period.DUSK: return 0.66
        Period.DAY: return 1.0
```

```gdscript
# SurvivalManager.gd
extends Node

signal water_changed(current, max_water)
signal water_critical()
signal player_died(cause)

var water: float = 100.0
var flasks: int = 1
var base_drain: float = 3.0
var drain_tick: float = 20.0  # Every 20 seconds

var _drain_timer: float = 0.0
var _is_in_shade: bool = false
var _is_in_storm: bool = false
var _is_in_oasis: bool = false

func _process(delta):
    _drain_timer += delta
    if _drain_timer >= drain_tick:
        _drain_timer = 0.0
        apply_drain()

func apply_drain():
    if _is_in_oasis:
        water = min(water + 3.0, flasks * 100.0)  # Regenerate in oasis
        water_changed.emit(water, flasks * 100)
        return

    var drain = base_drain * TimeManager.get_drain_multiplier()

    if _is_in_shade:
        drain = max(0.5, drain - 2.0)

    if _is_in_storm:
        drain += 4.0

    water -= drain
    water_changed.emit(water, flasks * 100)

    if water <= 15:
        water_critical.emit()

    if water <= 0:
        die("thirst")

func die(cause: String):
    player_died.emit(cause)
    AsyncManager.record_death_trail(cause)
```

```gdscript
# ShadowCaster.gd
extends Node2D

@export var caster_height: float = 50.0
@export var shadow_color: Color = Color(0, 0, 0, 0.3)

var shadow_polygon: PackedVector2Array

func _process(_delta):
    update_shadow()
    queue_redraw()

func update_shadow():
    var sun_angle = TimeManager.sun_angle
    var sun_height = sin(TimeManager.time_of_day * PI)

    # No shadow at night
    if TimeManager.current_period == TimeManager.Period.NIGHT:
        shadow_polygon = PackedVector2Array()
        return

    # Calculate shadow length (longer at dawn/dusk)
    var shadow_length = caster_height / max(sun_height, 0.2)

    # Calculate shadow direction (opposite of sun)
    var sun_dir = Vector2(cos(deg_to_rad(sun_angle)), 0.5).normalized()
    var shadow_dir = -sun_dir

    # Build shadow polygon (simplified rectangle)
    var half_width = 20  # Width of caster
    shadow_polygon = PackedVector2Array([
        Vector2(-half_width, 0),
        Vector2(half_width, 0),
        Vector2(half_width, 0) + shadow_dir * shadow_length,
        Vector2(-half_width, 0) + shadow_dir * shadow_length
    ])

func _draw():
    if shadow_polygon.size() > 0:
        draw_colored_polygon(shadow_polygon, shadow_color)

func point_in_shadow(point: Vector2) -> bool:
    return Geometry2D.is_point_in_polygon(to_local(point), shadow_polygon)
```

```gdscript
# DigSite.gd
extends Area2D

signal pattern_completed(reward)

@export var pattern: Array[Vector2] = []  # Relative dig positions
@export var reward_type: String = "water"
@export var dig_tolerance: float = 15.0

var completed_digs: Array[Vector2] = []
var is_complete: bool = false

func try_dig(world_pos: Vector2) -> bool:
    if is_complete:
        return false

    var local_pos = to_local(world_pos)

    for pattern_point in pattern:
        if pattern_point in completed_digs:
            continue

        if local_pos.distance_to(pattern_point) <= dig_tolerance:
            completed_digs.append(pattern_point)
            spawn_dig_marker(pattern_point, true)  # Glowing marker

            if completed_digs.size() >= pattern.size():
                complete_pattern()

            return true

    return false  # No pattern match

func complete_pattern():
    is_complete = true
    pattern_completed.emit(reward_type)
    play_completion_effects()
    spawn_reward()
```

```gdscript
# StormManager.gd
extends Node

signal storm_state_changed(state)
signal dunes_shifted()

enum State { CALM, WARNING, ACTIVE, CLEARING }
var current_state: State = State.CALM

var storm_timer: float = 0.0
var next_storm_in: float = 120.0  # First storm after 2 minutes

const WARNING_DURATION = 30.0
const CLEARING_DURATION = 10.0

func _process(delta):
    storm_timer += delta

    match current_state:
        State.CALM:
            if storm_timer >= next_storm_in:
                transition_to(State.WARNING)

        State.WARNING:
            if storm_timer >= WARNING_DURATION:
                transition_to(State.ACTIVE)

        State.ACTIVE:
            if storm_timer >= randf_range(45, 90):
                transition_to(State.CLEARING)
            elif fmod(storm_timer, 15.0) < delta:  # Every 15 seconds
                maybe_shift_dunes()

        State.CLEARING:
            if storm_timer >= CLEARING_DURATION:
                transition_to(State.CALM)

func transition_to(new_state: State):
    current_state = new_state
    storm_timer = 0.0
    storm_state_changed.emit(new_state)

    match new_state:
        State.CALM:
            SurvivalManager._is_in_storm = false
            next_storm_in = randf_range(90, 180)
        State.WARNING:
            show_storm_warning()
        State.ACTIVE:
            SurvivalManager._is_in_storm = true
            start_storm_effects()
        State.CLEARING:
            SurvivalManager._is_in_storm = false

func maybe_shift_dunes():
    if randf() < 0.3:
        var shift = Vector2(randf_range(-30, 30), randf_range(-30, 30))
        for dune in get_tree().get_nodes_in_group("shiftable_dunes"):
            var tween = create_tween()
            tween.tween_property(dune, "position", dune.position + shift, 3.0)
        dunes_shifted.emit()
```

```gdscript
# AsyncManager.gd (interfaces with Playroom)
extends Node

var ghost_trails: Array = []
var inscriptions: Array = []
var offerings: Array = []

func _ready():
    Playroom.connect("trails_received", _on_trails_received)
    Playroom.connect("inscriptions_received", _on_inscriptions_received)

func load_area_data(area_id: String):
    Playroom.request_trails(area_id, 20)
    Playroom.request_inscriptions(area_id, 50)
    Playroom.request_offerings(area_id)

func record_death_trail(cause: String):
    var trail_data = {
        "path": simplify_footprints(Player.footprint_history),
        "death_pos": Player.global_position,
        "cause": cause,
        "name": Player.display_name,
        "time": Time.get_unix_time_from_system()
    }
    Playroom.send_trail(trail_data)

func simplify_footprints(points: Array) -> Array:
    if points.size() < 3:
        return points

    var result = [points[0]]
    var last_dir = Vector2.ZERO

    for i in range(1, points.size()):
        var dir = (points[i] - points[i-1]).normalized()
        if last_dir == Vector2.ZERO or dir.dot(last_dir) < 0.9:
            result.append(points[i])
            last_dir = dir

    # Always include final position
    if result[-1] != points[-1]:
        result.append(points[-1])

    return result

func _on_trails_received(trails: Array):
    ghost_trails = trails
    for trail in trails:
        spawn_ghost_trail(trail)

func spawn_ghost_trail(data: Dictionary):
    var trail_node = GhostTrail.instantiate()
    trail_node.set_path(data.path)
    trail_node.death_position = data.death_pos
    trail_node.death_cause = data.cause
    trail_node.player_name = data.name
    get_tree().current_scene.add_child(trail_node)
```

### Speech-Based Digging (Using Existing speech_detector.gd)

```gdscript
# SpeechDigController.gd
extends Node

# Connects to your existing speech_detector.gd
@onready var speech_detector = $"/root/SpeechDetector"

var humming_duration: float = 0.0
var required_hum_time: float = 3.0
var detection_radius: float = 100.0

func _ready():
    speech_detector.connect("voice_detected", _on_voice_detected)
    speech_detector.connect("voice_ended", _on_voice_ended)

func _on_voice_detected():
    humming_duration = 0.0
    start_detection_visuals()

func _process(delta):
    if speech_detector.is_detecting:
        humming_duration += delta
        update_detection_visuals(humming_duration / required_hum_time)

        if humming_duration >= required_hum_time:
            reveal_nearby_secrets()
            humming_duration = 0.0

func _on_voice_ended():
    humming_duration = 0.0
    stop_detection_visuals()

func reveal_nearby_secrets():
    var player_pos = Player.global_position

    for secret in get_tree().get_nodes_in_group("hidden_treasures"):
        if player_pos.distance_to(secret.global_position) <= detection_radius:
            secret.reveal()
            spawn_discovery_effect(secret.global_position)

func start_detection_visuals():
    # Show ripple effect emanating from player
    Player.show_sensing_aura(true)

func update_detection_visuals(progress: float):
    # Ripple grows with progress
    Player.set_sensing_progress(progress)

func stop_detection_visuals():
    Player.show_sensing_aura(false)
```

---

## Part 5: Progression System

### Tool Unlocks

| Tool | How Obtained | Ability | Balance |
|------|--------------|---------|---------|
| **Shovel** | Tutorial (existing) | Dig holes | Required for dig puzzles |
| **Mirror Shard** | Complete first dig pattern | Reveal sun angle precisely | Helps with shadow puzzles, doesn't solve them |
| **Desert Compass** | Survive first storm | Points to nearest oasis | Shows direction, not distance |
| **Star Chart** | Complete night crossing | Identifies constellations | Required for Tier 3 dig puzzles |
| **Ancient Vessel** | Find hidden oasis | +1 flask capacity | Powerful but hidden |

### Long-Term Goals

```
RUN 1:  Tutorial → Learn mechanics → Probably die → Leave trail for others
        ↓
RUN 2:  Follow your old trail → Get further → Find shovel → Die to storm
        ↓
RUN 3:  Know storm signs → Find dig site → Uncover map fragment → Die at night
        ↓
RUN 4:  Use map → Find hidden oasis → Get extra flask → Reach northern oasis!
        ↓
RUNS 5+: Explore alternate paths → Find all relics → Maximize reputation
```

### Relics (Collectibles)

| Relic | Location | Effect When Carried |
|-------|----------|---------------------|
| Tear of the Sun | Shadow puzzle zone | Shade lasts 10% longer around you |
| Sandstone Heart | Storm zone | 20% less water drain in storms |
| Nightwalker's Eye | Night crossing area | 20% larger visibility at night |
| Oasis Blessing | Hidden oasis | Water regenerates 20% faster |

---

## Part 6: Anti-Grief Design

### Inscription Rules

```
CANNOT BLOCK PROGRESSION:
✗ Inscriptions cannot be placed directly on paths (minimum 20 unit offset)
✗ Cannot place more than 1 inscription within 50 units
✗ Obscene filter on freeform text (if allowing)

TRUST DETECTION:
✓ New inscriptions (< 1 hour old) have "fresh" visual marker
✓ Inscriptions with negative votes have mirage shimmer
✓ Author reputation visible on hover
✓ After being misled, player gets temporary "lie detection" (sparkles on bad inscriptions)

REPUTATION CONSEQUENCES:
- Reputation < 0: All inscriptions have warning shimmer
- Reputation < -20: Inscriptions greyed out, less visible
- Reputation < -50: Inscriptions hidden by default (toggle to see)
```

### Offering Protection

```
✓ Cannot collect your own offerings (no exploits)
✓ Offerings despawn after 48 hours if uncollected (cleanup)
✓ Maximum 1 offering per player per oasis (no spam)
✓ Collecting grants notification to donor (warm feeling)
```

### Ghost Trail Integrity

```
✓ Trails are read-only (cannot be edited)
✓ Trails auto-expire after 7 days (fresh data)
✓ Death cause shown prevents fake "safe path" trails
✓ Trails from low-reputation players are fainter
```

---

## Part 7: Sprint Checklist

### Milestone 1: Core Loop (2 weeks)
**Done Criteria:** Player can walk, drain water, die, and respawn at oasis.

- [ ] Implement TimeManager with day/night cycle
- [ ] Implement SurvivalManager with water drain
- [ ] Connect time period to drain multiplier
- [ ] Add death sequence and respawn
- [ ] Basic HUD (water bar, time indicator)
- [ ] Test: Survive from dawn to dusk in shade, die in open sun

### Milestone 2: Shade Mechanics (1 week)
**Done Criteria:** Shadows move with sun, player gains/loses shade status.

- [ ] Implement ShadowCaster component
- [ ] Create ShadeZone detection
- [ ] Connect shade status to SurvivalManager
- [ ] Add visual feedback (heat shimmer, blue tint)
- [ ] Test: Wait for shadow, cross danger zone safely

### Milestone 3: First Puzzle Zone (1 week)
**Done Criteria:** Player can complete a shadow path puzzle.

- [ ] Create shadow path level layout
- [ ] Place danger zones with heat multiplier
- [ ] Place shadow casters that create solvable puzzle
- [ ] Add audio feedback (sizzle, relief)
- [ ] Test: Multiple solutions, increasing difficulty

### Milestone 4: Dig System (1 week)
**Done Criteria:** Player can dig patterns to reveal rewards.

- [ ] Implement DigSite component
- [ ] Create 3 pattern types (triangle, cross, constellation)
- [ ] Add dig visuals (hole, glow for correct)
- [ ] Spawn rewards on completion
- [ ] Test: Find site, complete pattern, get water cache

### Milestone 5: Storms (1 week)
**Done Criteria:** Sandstorms occur, affect gameplay, shift dunes.

- [ ] Implement StormManager state machine
- [ ] Add storm particles and visibility reduction
- [ ] Connect storm to water drain increase
- [ ] Implement dune shifting
- [ ] Add shelter zones that negate storm
- [ ] Test: Survive storm in shelter, die in open

### Milestone 6: Night Cycle (1 week)
**Done Criteria:** Night has reduced visibility, reduced drain, atmosphere.

- [ ] Implement night visibility mask
- [ ] Add ambient night sounds
- [ ] Reduce water drain at night
- [ ] Add glowing elements for navigation
- [ ] Test: Navigate from sunset to sunrise

### Milestone 7: Ghost Trails (1 week)
**Done Criteria:** Deaths create trails, trails persist and display.

- [ ] Implement trail recording on death
- [ ] Implement trail simplification
- [ ] Connect to Playroom for persistence
- [ ] Create ghost trail visual shader
- [ ] Trails glow brighter at night
- [ ] Test: Die, restart, see your own trail

### Milestone 8: Enhanced Inscriptions (1 week)
**Done Criteria:** Inscriptions have trust indicators, voting works.

- [ ] Add reputation to inscription data
- [ ] Implement trust score calculation
- [ ] Add gold glow / shimmer visuals
- [ ] Implement helpful/misleading voting
- [ ] Update author reputation on votes
- [ ] Test: Create inscription, have it voted helpful, see gold glow

### Milestone 9: Offerings (1 week)
**Done Criteria:** Players can leave/collect flasks at oases.

- [ ] Implement offering creation
- [ ] Store offerings in Playroom
- [ ] Display offerings at oases
- [ ] Implement collection + donor notification
- [ ] Reputation boost for donors
- [ ] Test: Leave offering, collect different player's offering

### Milestone 10: Polish & Juice (1 week)
**Done Criteria:** Game feels satisfying to play.

- [ ] Screen shake on death
- [ ] Particles for all major events
- [ ] Sound design pass
- [ ] Transition animations
- [ ] Tutorial hints for new players
- [ ] Test: Full playthrough feels smooth

---

## Part 8: Unique Differentiators

### 1. **Asynchronous Kindness**
Unlike survival games focused on competition or isolation, Dhikra builds a world where players who never meet directly help each other. Your death becomes someone else's guidance. Your inscriptions become someone else's salvation.

### 2. **Time-Aware Environment Puzzles**
The sun isn't just cosmetic—it's a puzzle element. Shadows move, heat zones shift, and the same path that kills you at noon might save you at dusk. This creates replay value without procedural generation.

### 3. **Sound as Gameplay**
Using the player's actual voice (humming, singing) to reveal secrets is unusual and memorable. It creates intimate moments alone in the desert, calling out to find hidden water.

### 4. **Trust as Emergent Gameplay**
The inscription system creates a social trust layer without direct interaction. Players learn to read "tells" on inscriptions—fresh vs. old, high-rep vs. low-rep, near death markers or not. This is detective work, not just reading signs.

### 5. **Sacrifice as Connection**
The offering system asks players to give up resources permanently for strangers. This subverts the hoarding instinct of survival games. The "thank you" notification when someone collects your flask creates genuine emotional moments.

---

## Appendix: Quick Reference Tables

### Water Drain Matrix
| Condition | Modifier |
|-----------|----------|
| Base (day, moving, no shade) | 3.0 |
| In shade | -2.0 |
| Night time | -2.0 |
| In storm | +4.0 |
| Standing still | -0.5 |
| In danger zone (no shade) | +12.0 |
| In oasis | +3.0 (heal) |

### Reputation Thresholds
| Score | Title | Visual |
|-------|-------|--------|
| 0-49 | Wanderer | None |
| 50-149 | Guide | Faint gold outline |
| 150-299 | Sage | Gold aura |
| 300+ | Legend | Gold aura + particles |
| < 0 | Trickster | Red shimmer (warning) |

### Storm Timing
| Phase | Duration | Effects |
|-------|----------|---------|
| Calm | 90-180s | Normal gameplay |
| Warning | 30s | Wind particles, audio |
| Active | 45-90s | Full effects, dune shifts |
| Clearing | 10s | Effects fade |

---

*This document is your complete blueprint. Follow the milestones in order, and you'll have a playable prototype in 10 weeks. Good luck, desert guide.*
