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
