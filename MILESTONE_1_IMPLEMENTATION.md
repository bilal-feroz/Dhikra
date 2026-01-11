# Milestone 1: Implementation Package

> **IMPORTANT**: This package integrates with your existing systems. You already have working water drain, shade, and oasis mechanics. We're adding the **day/night cycle** layer on top.

---

## 1. ASSUMPTIONS

| Decision | Choice | Reason |
|----------|--------|--------|
| **Dimension** | 2D | Your project is already 2D (CharacterBody2D, Sprite2D, y-sorting) |
| **Godot Version** | 4.x (4.2+) | Your code uses `@onready`, `@export`, typed signals |
| **Integration** | Additive | Your water drain in `player.gd` works. We add TimeManager as a multiplier source |
| **Player Controller** | Keep existing | Your `player.gd` is comprehensive. We modify ~10 lines only |

---

## 2. MILESTONE 1 EXECUTION PLAN

### Checklist (Execute in Order)

```
[ ] 1. Create TimeManager.gd autoload
[ ] 2. Register TimeManager in Project Settings → Autoload
[ ] 3. Create TimeDisplay.tscn UI component
[ ] 4. Add TimeDisplay to your existing UI
[ ] 5. Modify player.gd to use TimeManager.get_drain_multiplier()
[ ] 6. Add WorldManager signals for time events
[ ] 7. Create test scene to verify day/night cycle
[ ] 8. Balance tuning pass
```

### Detailed Steps

**Step 1-2: TimeManager Autoload**
- Create `autoloads/time_manager.gd`
- Add to Project Settings → Autoload as `TimeManager`

**Step 3-4: Time Display UI**
- Create `ui/time_display.tscn` (small sun/moon icon + period label)
- Instance it in your existing HUD (probably in `game.tscn` UI layer)

**Step 5: Player Integration**
- In `player.gd` `_process_water_drain()`, multiply base intensity by `TimeManager.get_drain_multiplier()`
- This is ~3 lines of code change

**Step 6: WorldManager Signals**
- Add `time_period_changed(period: int)` signal
- TimeManager emits through WorldManager for UI binding

**Step 7: Test Scene**
- Create `test/test_day_night.tscn` with player + oasis
- Set `day_length_seconds = 30` for fast testing

**Step 8: Balance**
- Adjust multipliers until survival feels right

---

## 3. PROJECT STRUCTURE

Your existing structure is good. Add these files:

```
Dhikra/
├── autoloads/
│   ├── playroom.gd          (existing)
│   ├── sound_manager.gd     (existing)
│   ├── world_manager.gd     (existing - MODIFY)
│   └── time_manager.gd      (NEW)
│
├── ui/
│   ├── water_gauge.gd       (existing)
│   ├── flask_bar.gd         (existing)
│   └── time_display/        (NEW folder)
│       ├── time_display.tscn
│       └── time_display.gd
│
├── test/                    (NEW folder)
│   └── test_day_night.tscn
│
└── shaders/                 (NEW folder - for later)
    └── (empty for now)
```

### Autoload Registration Order

In Project Settings → Autoload:
```
1. Playroom      → autoloads/playroom.gd
2. WorldManager  → autoloads/world_manager.gd
3. SoundManager  → autoloads/sound_manager.gd
4. TimeManager   → autoloads/time_manager.gd  (NEW)
```

---

## 4. GODOT SCENE TREES

### TimeDisplay.tscn (NEW)

```
TimeDisplay (Control)
├── HBoxContainer
│   ├── TimeIcon (TextureRect)
│   │   └── [sun.png or moon.png - swap based on period]
│   └── PeriodLabel (Label)
│       └── text: "DAY" / "NIGHT" / "DAWN" / "DUSK"
└── (optional) ProgressBar for visual time-of-day
```

### Test Scene: test_day_night.tscn (NEW)

```
TestDayNight (Node2D)
├── Player (instance of player.tscn)
├── TestOasis (Node2D)
│   ├── Sprite2D [oasis visual]
│   └── OasisArea (Area2D) [Dhikra class]
│       └── CollisionShape2D
├── CanvasLayer
│   └── TestHUD (Control)
│       ├── TimeDisplay (instance)
│       ├── WaterGauge (instance)
│       └── DebugLabel (Label) [shows raw values]
└── CanvasModulate [for day/night tinting - optional]
```

### Your Existing game.tscn (MODIFY)

Add TimeDisplay as sibling to existing UI elements:
```
game.tscn
└── UI (CanvasLayer)
    ├── ... existing elements ...
    └── TimeDisplay (instance of time_display.tscn)  (ADD THIS)
```

---

## 5. CODE SKELETONS (PASTEABLE)

### 5.1 TimeManager.gd (NEW FILE)

```gdscript
# autoloads/time_manager.gd
extends Node
class_name TimeManagerClass

## Day/Night cycle manager. Tracks time and provides drain multipliers.
## Register as autoload: TimeManager

signal period_changed(new_period: int)
signal time_tick(time_of_day: float)

enum Period { NIGHT, DAWN, DAY, DUSK }

## Time of day as float: 0.0 = midnight, 0.5 = noon, 1.0 = next midnight
var time_of_day: float = 0.30:  # Start at early morning
	set(value):
		time_of_day = wrapf(value, 0.0, 1.0)

## Real seconds for one full day cycle (5 min default)
@export var day_length_seconds: float = 300.0

## Current time period (cached, updates on change)
var current_period: Period = Period.DAY

## Whether time is paused (for menus, cutscenes)
var time_paused: bool = false

## Drain multipliers per period
const DRAIN_MULTIPLIERS := {
	Period.NIGHT: 0.33,
	Period.DAWN: 0.66,
	Period.DAY: 1.0,
	Period.DUSK: 0.66,
}

## Period time boundaries (time_of_day ranges)
const PERIOD_BOUNDS := {
	Period.NIGHT: [0.0, 0.20],   # 00:00 - 04:48
	Period.DAWN:  [0.20, 0.30],  # 04:48 - 07:12
	Period.DAY:   [0.30, 0.70],  # 07:12 - 16:48
	Period.DUSK:  [0.70, 0.80],  # 16:48 - 19:12
	# NIGHT again: [0.80, 1.0]  # 19:12 - 00:00
}


func _ready() -> void:
	# Connect to UI pause events if needed
	if WorldManager:
		WorldManager.ui_active.connect(_on_ui_active)

	# Initialize period
	current_period = _calculate_period()


func _process(delta: float) -> void:
	if time_paused:
		return

	# Advance time
	var time_delta := delta / day_length_seconds
	time_of_day += time_delta

	# Check for period change
	var new_period := _calculate_period()
	if new_period != current_period:
		current_period = new_period
		period_changed.emit(current_period)

		# Also emit through WorldManager for consistency
		if WorldManager:
			WorldManager.time_period_changed.emit(current_period)

	# Emit time tick (throttled to ~10 times per second for UI)
	# Full emit every frame is fine for smooth progress bars
	time_tick.emit(time_of_day)


func _calculate_period() -> Period:
	# Check each period's bounds
	if time_of_day < 0.20 or time_of_day >= 0.80:
		return Period.NIGHT
	elif time_of_day < 0.30:
		return Period.DAWN
	elif time_of_day < 0.70:
		return Period.DAY
	else:
		return Period.DUSK


## Returns multiplier for water drain based on current time period.
## DAY = 1.0 (full drain), NIGHT = 0.33 (reduced drain)
func get_drain_multiplier() -> float:
	return DRAIN_MULTIPLIERS.get(current_period, 1.0)


## Returns sun angle in degrees (0 = midnight, 180 = noon, 360 = midnight)
## Useful for shadow casting in Milestone 2
func get_sun_angle() -> float:
	return time_of_day * 360.0


## Returns sun height (0.0 at night, 1.0 at noon)
## Useful for shadow length calculations
func get_sun_height() -> float:
	# Use sine curve: 0 at midnight, 1 at noon
	return maxf(0.0, sin(time_of_day * PI))


## Returns normalized time within current period (0.0 = start, 1.0 = end)
## Useful for transition effects
func get_period_progress() -> float:
	match current_period:
		Period.NIGHT:
			if time_of_day < 0.20:
				return time_of_day / 0.20
			else:
				return (time_of_day - 0.80) / 0.20
		Period.DAWN:
			return (time_of_day - 0.20) / 0.10
		Period.DAY:
			return (time_of_day - 0.30) / 0.40
		Period.DUSK:
			return (time_of_day - 0.70) / 0.10
	return 0.0


## Set time directly (for testing or story events)
func set_time(new_time: float) -> void:
	time_of_day = new_time
	current_period = _calculate_period()
	period_changed.emit(current_period)


## Skip to a specific period (jumps to middle of that period)
func skip_to_period(period: Period) -> void:
	match period:
		Period.NIGHT:
			set_time(0.10)
		Period.DAWN:
			set_time(0.25)
		Period.DAY:
			set_time(0.50)
		Period.DUSK:
			set_time(0.75)


## Pause/unpause time progression
func set_paused(paused: bool) -> void:
	time_paused = paused


func _on_ui_active(showing: bool) -> void:
	# Optionally pause time during UI
	# Comment out if you want time to continue during menus
	# time_paused = showing
	pass


## Get human-readable time string (for debug)
func get_time_string() -> String:
	var hours := int(time_of_day * 24)
	var minutes := int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]


## Get period name as string
func get_period_name() -> String:
	match current_period:
		Period.NIGHT: return "NIGHT"
		Period.DAWN: return "DAWN"
		Period.DAY: return "DAY"
		Period.DUSK: return "DUSK"
	return "UNKNOWN"
```

---

### 5.2 WorldManager.gd Additions (MODIFY EXISTING)

Add these lines to your existing `world_manager.gd`:

```gdscript
# Add this signal near the top with other signals (around line 26)
signal time_period_changed(period: int)

# Add these variables in the variables section (around line 38)
var current_time_period: int = 2  # TimeManager.Period.DAY
```

**Full diff - add after line 26:**
```gdscript
signal time_period_changed(period: int)
```

**Add after line 39:**
```gdscript
var current_time_period: int = 2  # Default to DAY (matches TimeManager.Period.DAY)
```

---

### 5.3 Player.gd Modification (MODIFY EXISTING)

In your existing `player.gd`, modify the `_process_water_drain()` function.

**Find this section (around line 356-377):**
```gdscript
func _process_water_drain(delta: float) -> void:
	if is_remote_player:
		return

	# Useful when in escape menu or dialogs
	if invulnerable or infinite_water:
		return

	# Start with a base of -3 for the heat burning you
	var intensity := -3

	if in_oasis > 0:
		intensity = 3
```

**Replace with:**
```gdscript
func _process_water_drain(delta: float) -> void:
	if is_remote_player:
		return

	# Useful when in escape menu or dialogs
	if invulnerable or infinite_water:
		return

	# Start with a base of -3 for the heat burning you
	# MILESTONE 1: Apply time-of-day multiplier
	var time_multiplier := 1.0
	if TimeManager:
		time_multiplier = TimeManager.get_drain_multiplier()

	var intensity := int(-3 * time_multiplier)

	if in_oasis > 0:
		intensity = 3  # Oasis always heals at full rate
```

**That's the only change needed to player.gd!**

The rest of your drain logic (shade, storm, etc.) already works correctly because it adds/subtracts from the base intensity.

---

### 5.4 TimeDisplay.gd (NEW FILE)

```gdscript
# ui/time_display/time_display.gd
extends Control
class_name TimeDisplay

## Displays current time period and optional time-of-day indicator

@export var sun_texture: Texture2D
@export var moon_texture: Texture2D
@export var dawn_color: Color = Color("ff9966")
@export var day_color: Color = Color("ffff99")
@export var dusk_color: Color = Color("ff6633")
@export var night_color: Color = Color("6666cc")

@onready var time_icon: TextureRect = $HBoxContainer/TimeIcon
@onready var period_label: Label = $HBoxContainer/PeriodLabel

var current_period: int = -1


func _ready() -> void:
	# Connect to TimeManager signals
	if TimeManager:
		TimeManager.period_changed.connect(_on_period_changed)
		# Initialize with current period
		_on_period_changed(TimeManager.current_period)
	else:
		push_warning("TimeDisplay: TimeManager autoload not found")


func _on_period_changed(period: int) -> void:
	if period == current_period:
		return

	current_period = period

	# Update icon
	match period:
		TimeManager.Period.NIGHT:
			if moon_texture:
				time_icon.texture = moon_texture
			period_label.text = "NIGHT"
			period_label.modulate = night_color
		TimeManager.Period.DAWN:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DAWN"
			period_label.modulate = dawn_color
		TimeManager.Period.DAY:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DAY"
			period_label.modulate = day_color
		TimeManager.Period.DUSK:
			if sun_texture:
				time_icon.texture = sun_texture
			period_label.text = "DUSK"
			period_label.modulate = dusk_color


## Optional: Show exact time (for debug)
func _process(_delta: float) -> void:
	# Uncomment for debug time display:
	# if TimeManager:
	#     period_label.text = TimeManager.get_period_name() + " " + TimeManager.get_time_string()
	pass
```

---

### 5.5 TimeDisplay.tscn (NEW SCENE)

Create this scene at `ui/time_display/time_display.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/time_display/time_display.gd" id="1"]

[node name="TimeDisplay" type="Control"]
custom_minimum_size = Vector2(120, 32)
anchors_preset = 0
offset_right = 120.0
offset_bottom = 32.0
script = ExtResource("1")

[node name="HBoxContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="TimeIcon" type="TextureRect" parent="HBoxContainer"]
custom_minimum_size = Vector2(24, 24)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="PeriodLabel" type="Label" parent="HBoxContainer"]
layout_mode = 2
size_flags_vertical = 1
text = "DAY"
```

---

### 5.6 Test Scene Script (NEW FILE)

```gdscript
# test/test_day_night.gd
extends Node2D

## Test scene for day/night cycle
## Accelerated time for testing: 30 second days

@onready var debug_label: Label = $CanvasLayer/DebugLabel
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.3, 0.3, 0.5, 1.0)
const DAWN_COLOR := Color(0.8, 0.7, 0.6, 1.0)
const DUSK_COLOR := Color(0.7, 0.5, 0.4, 1.0)


func _ready() -> void:
	# Set fast time for testing
	if TimeManager:
		TimeManager.day_length_seconds = 30.0  # 30 second full cycle
		TimeManager.period_changed.connect(_on_period_changed)
		_on_period_changed(TimeManager.current_period)

	print("=== DAY/NIGHT TEST ===")
	print("Press F1 to skip to DAWN")
	print("Press F2 to skip to DAY")
	print("Press F3 to skip to DUSK")
	print("Press F4 to skip to NIGHT")
	print("Press P to pause/unpause time")


func _process(_delta: float) -> void:
	# Update debug display
	if TimeManager and debug_label:
		debug_label.text = "Time: %s\nPeriod: %s\nDrain Mult: %.2f\nSun Height: %.2f" % [
			TimeManager.get_time_string(),
			TimeManager.get_period_name(),
			TimeManager.get_drain_multiplier(),
			TimeManager.get_sun_height()
		]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home") or (event is InputEventKey and event.keycode == KEY_F1):
		TimeManager.skip_to_period(TimeManager.Period.DAWN)
	elif event is InputEventKey and event.keycode == KEY_F2:
		TimeManager.skip_to_period(TimeManager.Period.DAY)
	elif event is InputEventKey and event.keycode == KEY_F3:
		TimeManager.skip_to_period(TimeManager.Period.DUSK)
	elif event is InputEventKey and event.keycode == KEY_F4:
		TimeManager.skip_to_period(TimeManager.Period.NIGHT)
	elif event is InputEventKey and event.keycode == KEY_P:
		TimeManager.set_paused(not TimeManager.time_paused)
		print("Time paused: ", TimeManager.time_paused)


func _on_period_changed(period: int) -> void:
	print("Period changed to: ", TimeManager.get_period_name())

	# Tint the screen based on period (simple visual feedback)
	if canvas_modulate:
		var target_color: Color
		match period:
			TimeManager.Period.NIGHT:
				target_color = NIGHT_COLOR
			TimeManager.Period.DAWN:
				target_color = DAWN_COLOR
			TimeManager.Period.DAY:
				target_color = DAY_COLOR
			TimeManager.Period.DUSK:
				target_color = DUSK_COLOR

		var tween := create_tween()
		tween.tween_property(canvas_modulate, "color", target_color, 2.0)
```

---

## 6. BALANCING DEFAULTS

### Recommended Starting Values

| Variable | Value | Effect |
|----------|-------|--------|
| `day_length_seconds` | **300** (5 min) | Full cycle = 5 real minutes |
| `base_drain` | **-3** | ~33 seconds per 100 water at DAY |
| `DRAIN_TIME_PER_FLASK` | existing | One flask = ~20 sec at DAY, ~60 sec at NIGHT |
| `time_multiplier (DAY)` | **1.0** | Full drain speed |
| `time_multiplier (NIGHT)` | **0.33** | 3x longer survival |
| `time_multiplier (DAWN/DUSK)` | **0.66** | Transition periods |

### Survival Time Estimates

With your current drain rate (`-3 intensity * delta * DRAIN_TIME_PER_FLASK`):

| Period | ~Survival Time (100 water, no shade) |
|--------|--------------------------------------|
| DAY | ~20-25 seconds |
| DAWN/DUSK | ~35-40 seconds |
| NIGHT | ~60-70 seconds |

**Tuning tips:**
- If too easy: Increase `base_drain` or reduce NIGHT multiplier
- If too hard: Decrease `base_drain` or increase dawn/dusk multipliers
- For testing: Set `day_length_seconds = 30` to see full cycle quickly

---

## 7. QUICK "NEXT MILESTONE" HOOKS

### Milestone 2: Shade Mechanics

**Changes needed:**

1. **New ShadeZone scene** - Already partially exists (`utils/shade.gd` with `ShadeValue` class)
   - Enhance to calculate dynamic shadows based on `TimeManager.get_sun_angle()` and `get_sun_height()`
   - Shadow length = object_height / sun_height
   - Shadow direction = opposite of sun angle

2. **SurvivalManager shade integration** - Already works!
   - Your `in_shade` counter in `player.gd` already handles shade
   - For dynamic shadows, shade zones will enter/exit automatically as shadows move

3. **Heat zone multipliers**
   - Create `HeatZone.gd` extending Area2D
   - On enter: Set a `heat_zone_multiplier` variable on player
   - In `_process_water_drain()`: `intensity *= heat_zone_multiplier`
   - Default = 1.0, danger zones = 3.0-5.0

4. **Dynamic shadow shader** (optional visual)
   - Create `shaders/dynamic_shadow.gdshader`
   - Takes `sun_angle` uniform from TimeManager
   - Stretches shadow sprite based on sun height

**Pseudocode for dynamic shadow:**
```gdscript
# In a ShadowCaster.gd component:
func _process(_delta):
    var sun_height = TimeManager.get_sun_height()
    if sun_height < 0.1:
        shadow_sprite.visible = false  # No shadows at night
        return

    shadow_sprite.visible = true
    shadow_sprite.scale.y = base_height / sun_height
    shadow_sprite.rotation = deg_to_rad(TimeManager.get_sun_angle() + 180)
```

---

## 8. DONE CRITERIA & TEST PROCEDURE

### Milestone 1 Complete When:

- [ ] TimeManager autoload registered and running
- [ ] `TimeManager.get_period_name()` returns correct period
- [ ] Period changes emit signals correctly
- [ ] Player water drain is slower at night (visible in debug)
- [ ] Player water drain is faster at day
- [ ] Oasis regeneration is NOT affected by time (always full speed)
- [ ] TimeDisplay UI shows current period
- [ ] Game doesn't crash when TimeManager is missing (graceful fallback)

### Test Procedure

1. **Run test scene** (`test/test_day_night.tscn`)
2. **Verify time display** - Should show "DAY" and update periodically
3. **Press F4** - Jump to NIGHT
   - Water should drain ~3x slower
   - Screen should tint blue (if CanvasModulate added)
4. **Press F2** - Jump to DAY
   - Water should drain at normal rate
   - Screen should be normal brightness
5. **Walk into oasis** - Regen should work at full speed regardless of time
6. **Let time run** - Full cycle in 30 seconds (test mode)
   - Should see: NIGHT → DAWN → DAY → DUSK → NIGHT
7. **Check main game** - Run your normal game.tscn
   - TimeDisplay should appear in HUD
   - Drain rates should vary by time period

### Debug Commands (Test Scene Only)

| Key | Action |
|-----|--------|
| F1 | Skip to DAWN |
| F2 | Skip to DAY |
| F3 | Skip to DUSK |
| F4 | Skip to NIGHT |
| P | Pause/unpause time |

---

## Quick Start Checklist

```
□ 1. Create file: autoloads/time_manager.gd (copy Section 5.1)
□ 2. Project Settings → Autoload → Add TimeManager
□ 3. Add signal to world_manager.gd (Section 5.2)
□ 4. Create folder: ui/time_display/
□ 5. Create file: ui/time_display/time_display.gd (copy Section 5.4)
□ 6. Create scene: ui/time_display/time_display.tscn (Section 5.5)
□ 7. Modify player.gd lines 356-365 (Section 5.3)
□ 8. Create folder: test/
□ 9. Create test scene with player + oasis + CanvasModulate
□ 10. Run test, verify drain rates change with time period
□ 11. Add TimeDisplay instance to game.tscn UI layer
□ 12. Set day_length_seconds back to 300 for real gameplay
```

---

## Appendix: File Locations Summary

| File | Path | Action |
|------|------|--------|
| TimeManager | `autoloads/time_manager.gd` | CREATE |
| WorldManager | `autoloads/world_manager.gd` | MODIFY (add 1 signal) |
| Player | `player.gd` | MODIFY (change ~5 lines) |
| TimeDisplay script | `ui/time_display/time_display.gd` | CREATE |
| TimeDisplay scene | `ui/time_display/time_display.tscn` | CREATE |
| Test scene | `test/test_day_night.tscn` | CREATE |
| Test script | `test/test_day_night.gd` | CREATE |

**Total new files:** 4
**Total modified files:** 2
**Estimated implementation time:** 1-2 hours

---

*This implementation is minimal, integrates cleanly with your existing systems, and sets up the foundation for Milestone 2 (dynamic shadows).*
