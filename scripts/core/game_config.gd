class_name GameConfig
extends RefCounted
## Single source of truth for School Rush tuning values.
##
## Nothing gameplay-relevant may be hardcoded outside this file: speeds,
## timings, lane geometry, and score rules all live here so they can be tuned
## (and asserted by the headless suite) in one place.
##
## Units: pixels and seconds, expressed in the 1920x1080 design space.
## Positive Y points down, so "up" lanes have smaller Y values.

# --- Display -----------------------------------------------------------------

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const DESIGN_WIDTH := 1920.0
const DESIGN_HEIGHT := 1080.0

# --- Lanes -------------------------------------------------------------------

const LANE_COUNT := 3
const LANE_TOP := 0
const LANE_MIDDLE := 1
const LANE_BOTTOM := 2

## Baseline Y (the player's feet) for each lane tier, top to bottom.
const LANE_Y := [680.0, 820.0, 960.0]
const LANE_SPACING := 140.0
const LANE_HALF_HEIGHT := LANE_SPACING * 0.5

## Time to travel one lane, and the constant speed derived from it.
const LANE_SWITCH_TIME := 0.16
const LANE_SWITCH_SPEED := LANE_SPACING / LANE_SWITCH_TIME

## Visual lean while switching lanes (presentation only).
const LANE_LEAN_DEGREES := 6.0
const LANE_LEAN_SMOOTHING := 16.0

# --- Player ------------------------------------------------------------------

const PLAYER_START_LANE := LANE_MIDDLE
const PLAYER_X := 400.0
const PLAYER_SCALE := 0.6

## Source sprite dimensions, used to keep the feet planted while squashing.
const PLAYER_SPRITE_WIDTH := 123.0
const PLAYER_SPRITE_HEIGHT := 189.0

# --- Jump --------------------------------------------------------------------

## Initial upward speed (px/s) and downward acceleration (px/s^2).
## With these values the arc peaks at ~118 px and lasts ~0.54 s.
const JUMP_SPEED := 870.0
const GRAVITY := 3200.0
const JUMP_APEX := JUMP_SPEED * JUMP_SPEED / (2.0 * GRAVITY)
const JUMP_AIRTIME := 2.0 * JUMP_SPEED / GRAVITY

# --- Slide -------------------------------------------------------------------

const SLIDE_DURATION := 0.55

# --- Run ---------------------------------------------------------------------

## Base forward speed. Zone steps and Continuous Mode ramping arrive in M5.
const RUN_SPEED := 420.0

## Scrolling ground ticks, used to make speed readable in the M1 gray box.
const GROUND_TICK_LENGTH := 64.0
const GROUND_TICK_GAP := 96.0

# --- Health ------------------------------------------------------------------

const MAX_HEARTS := 3

## Post-hit invulnerability window, in seconds (Section VI of the design doc).
const I_FRAME_TIME := 1.5

## How long the hurt animation overrides the movement animation.
const HURT_ANIM_TIME := 0.35

## How many times the sprite blinks per second while invulnerable.
const I_FRAME_BLINK_HZ := 7.0

# --- Collision ---------------------------------------------------------------

const LAYER_PLAYER := 1
const LAYER_HAZARD := 2
const LAYER_COLLECTIBLE := 4
const LAYER_FX := 8

const PLAYER_MASK := LAYER_HAZARD | LAYER_FX

## The hitbox is 10% smaller than the sprite so edge grazes do not count.
const HITBOX_SHRINK := 0.9
const HITBOX_SIZE := Vector2(PLAYER_SPRITE_WIDTH * PLAYER_SCALE * HITBOX_SHRINK, PLAYER_SPRITE_HEIGHT * PLAYER_SCALE * HITBOX_SHRINK)
## Sliding roughly halves the box so overhead hazards pass above it.
const SLIDE_HITBOX_HEIGHT_FACTOR := 0.5

# --- Hazards -----------------------------------------------------------------

enum HazardKind { MANHOLE, DEBRIS, SIGN, GANTRY, DOG }

## Per-kind art and hitbox data.
##   clearance    bottom edge sits this far above the lane baseline (overhead)
##   overhead     must be slid under; otherwise it is jumped or dodged
##   frames       0 = single image, >0 = horizontal sprite sheet frame count
##   extra_speed  added leftward speed for moving hazards
const HAZARD_DATA := {
	HazardKind.MANHOLE: {
		"texture": "res://assets/hazards/haz_manhole.png",
		"scale": 1.6, "hitbox_w": 76.0, "hitbox_h": 42.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	HazardKind.DEBRIS: {
		"texture": "res://assets/hazards/haz_debris.png",
		"scale": 1.0, "hitbox_w": 86.0, "hitbox_h": 52.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	HazardKind.SIGN: {
		"texture": "res://assets/hazards/haz_sign.png",
		"scale": 0.8, "hitbox_w": 38.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	HazardKind.GANTRY: {
		"texture": "res://assets/hazards/haz_gantry.png",
		"scale": 0.8, "hitbox_w": 150.0, "hitbox_h": 56.0,
		"clearance": 62.0, "overhead": true, "frames": 0, "extra_speed": 0.0,
	},
	HazardKind.DOG: {
		"texture": "res://assets/characters/dog1/Walk.png",
		"scale": 1.0, "hitbox_w": 40.0, "hitbox_h": 40.0,
		"clearance": 0.0, "overhead": false, "frames": 6, "extra_speed": 120.0,
	},
}

## Distance (px) after which each kind starts appearing.
const HAZARD_UNLOCK := {
	HazardKind.MANHOLE: 0.0,
	HazardKind.DEBRIS: 0.0,
	HazardKind.GANTRY: 8000.0,
	HazardKind.SIGN: 12000.0,
	HazardKind.DOG: 20000.0,
}

## Relative spawn weight of each kind once unlocked.
const HAZARD_WEIGHT := {
	HazardKind.MANHOLE: 3.0,
	HazardKind.DEBRIS: 3.0,
	HazardKind.GANTRY: 2.5,
	HazardKind.SIGN: 1.5,
	HazardKind.DOG: 1.5,
}

# --- Spawning ----------------------------------------------------------------

## Distance between hazard rows, easing from start toward the floor.
const ROW_GAP_START := 620.0
const ROW_GAP_MIN := 320.0
const ROW_GAP_RAMP_DISTANCE := 60000.0

## Chance that a row blocks two lanes instead of one, easing upward with
## distance. Two lanes is the maximum: one lane must always stay open.
const TWO_LANE_CHANCE_START := 0.15
const TWO_LANE_CHANCE_MAX := 0.6

const SPAWN_X := 2140.0
const DESPAWN_X := -400.0

# --- HUD ---------------------------------------------------------------------

const HEART_SIZE := 48.0
const HEART_GAP := 8.0
const HUD_MARGIN := Vector2(28.0, 24.0)

# --- Debug -------------------------------------------------------------------

## F3 toggles a read-only tuning overlay. Keep off for release builds.
const DEBUG_OVERLAY := true

# --- Pure helpers ------------------------------------------------------------

## Clamp a lane index into the valid range.
static func clamp_lane(lane: int) -> int:
	return clampi(lane, LANE_TOP, LANE_BOTTOM)


## Lane index after one step in [param direction] (-1 = up, +1 = down).
static func step_lane(lane: int, direction: int) -> int:
	return clamp_lane(lane + direction)


## Baseline Y for a lane index, clamped to the valid range.
static func lane_y(lane: int) -> float:
	return float(LANE_Y[clamp_lane(lane)])


## Distance between hazard rows after travelling [param distance] pixels,
## easing from ROW_GAP_START down to ROW_GAP_MIN.
static func row_gap(distance: float) -> float:
	var t := clampf(distance / ROW_GAP_RAMP_DISTANCE, 0.0, 1.0)
	return lerpf(ROW_GAP_START, ROW_GAP_MIN, t)
