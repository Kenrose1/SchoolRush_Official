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
const LANE_Y := [650.0, 790.0, 930.0]
const LANE_SPACING := 140.0
const LANE_HALF_HEIGHT := LANE_SPACING * 0.5

## Time to travel one lane, and the constant speed derived from it.
const LANE_SWITCH_TIME := 0.16
const LANE_SWITCH_SPEED := LANE_SPACING / LANE_SWITCH_TIME

## Visual lean while switching lanes (presentation only).
const LANE_LEAN_DEGREES := 6.0
const LANE_LEAN_SMOOTHING := 16.0

# --- Zones -------------------------------------------------------------------

## The run starts at home, reaches the street, then finishes at school.
## SCHOOL is terminal, so only HOME and STREET have durations.
enum Zone { HOME, STREET, SCHOOL }

const ZONE_ORDER := [Zone.HOME, Zone.STREET, Zone.SCHOOL]

## How long the home zone lasts, in seconds. Extend this to keep Elias indoors
## longer.
const ZONE_HOME_DURATION_SECONDS := 14.0

## Floor for the home duration, so the boundary can never collapse.
const ZONE_HOME_MIN_SECONDS := 5.0

## How long the street zone lasts before Elias reaches the school corridor.
const ZONE_STREET_DURATION_SECONDS := 25.0

## Floor for the street duration, so the school boundary can never collapse.
const ZONE_STREET_MIN_SECONDS := 5.0

## How long the school corridor lasts before the endgame hallway and the dash
## to the exit door.
const ZONE_SCHOOL_DURATION_SECONDS := 18.0

## Floor for the school duration, so the endgame can never arrive instantly.
const ZONE_SCHOOL_MIN_SECONDS := 5.0

## Cross-fade length when the zone changes (seconds).
const ZONE_FADE_TIME := 0.25

## Y (in the original house source) where the wall ends and the floor begins.
const HOUSE_FLOOR_SPLIT_Y := 1125.0
## Height of the original house source. Kept so the split can be expressed as a
## ratio and survive any import-time downscale of the texture.
const HOUSE_SOURCE_HEIGHT := 2048.0
const HOUSE_FLOOR_SPLIT_RATIO := HOUSE_FLOOR_SPLIT_Y / HOUSE_SOURCE_HEIGHT

## Y (in the original school hallway source) where the corridor wall ends and
## the reflective floor begins.
const SCHOOL_FLOOR_SPLIT_Y := 378.0
## Y where the drawn wall starts. The new hallway art is fully opaque and
## carries its own ceiling, so the slice starts at the very top of the source
## instead of cropping a transparent band.
const SCHOOL_WALL_START_Y := 0.0
## Height of the original hallway source, kept so the split survives any
## import-time downscale of the texture.
const SCHOOL_SOURCE_HEIGHT := 724.0
const SCHOOL_FLOOR_SPLIT_RATIO := SCHOOL_FLOOR_SPLIT_Y / SCHOOL_SOURCE_HEIGHT
const SCHOOL_WALL_START_RATIO := SCHOOL_WALL_START_Y / SCHOOL_SOURCE_HEIGHT

## The endgame hallway is the last screen of the run: it slides in as the
## corridor ends, the scroll stops on it, and Elias dashes to its exit door.
const SCHOOL_END_TEXTURE := "res://assets/backgrounds/Pixel-Art School Hallway ENDGAME.png"
## Y (in the endgame source) where its wall ends and the glossy floor begins.
const SCHOOL_END_FLOOR_SPLIT_Y := 366.0
const SCHOOL_END_FLOOR_SPLIT_RATIO := SCHOOL_END_FLOOR_SPLIT_Y / SCHOOL_SOURCE_HEIGHT
## Where the exit door stands across the endgame art (0..1), so the closing dash
## can aim at it instead of at a magic pixel.
const SCHOOL_EXIT_X_FRACTION := 0.945
## Elias' own speed during the closing dash, in px/s.
const FINALE_RUN_SPEED := 520.0
## How small Elias gets by the time he stands in the exit door. The door sits on
## the far wall, so the dash into it has to recede to read as depth.
const FINALE_DEPTH_SCALE := 0.72

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

## Base forward speed, used by every zone.
const RUN_SPEED := 420.0

## Pace multiplier per zone, in ZONE_ORDER order. Every zone change steps the
## run up, so the street and the school corridor are faster than home.
const ZONE_SPEED_FACTOR := [1.0, 1.15, 1.3]

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

const PLAYER_MASK := LAYER_HAZARD | LAYER_COLLECTIBLE | LAYER_FX

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
		"scale": 1.6, "hitbox_w": 70.0, "hitbox_h": 40.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	HazardKind.DEBRIS: {
		"texture": "res://assets/hazards/haz_debris.png",
		"scale": 1.0, "hitbox_w": 80.0, "hitbox_h": 52.0,
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
	## Dog is parked for M4 (re-adds in M6 with a proper pass).
	HazardKind.DOG: 0.0,
}

# --- School Items ------------------------------------------------------------

enum ItemKind { PENCIL, ERASER, BOOK, BAG }

## Per-kind art. All items float at the same hover height and share one hitbox.
const ITEM_DATA := {
	ItemKind.PENCIL: {"texture": "res://assets/props/item_pencil.png", "scale": 0.44},
	ItemKind.ERASER: {"texture": "res://assets/props/item_eraser.png", "scale": 0.42},
	ItemKind.BOOK: {"texture": "res://assets/props/item_book.png", "scale": 0.55},
	ItemKind.BAG: {"texture": "res://assets/props/item_bag.png", "scale": 0.50},
}

## School Items run on their own distance clock, between hazard rows.
const PICKUP_GAP_MIN := 1200.0
const PICKUP_GAP_MAX := 1800.0

## An item never spawns in a lane with a hazard within this x distance.
const PICKUP_LANE_CLEARANCE := 200.0

const ITEM_HOVER_HEIGHT := 62.0
const ITEM_HITBOX_SIZE := Vector2(44.0, 44.0)
const ITEM_BOB_HEIGHT := 6.0
const ITEM_BOB_SPEED := 4.0

# --- Score -------------------------------------------------------------------

const SCORE_DISTANCE_DIVISOR := 10.0
const SCORE_PER_HAZARD := 10
const SCORE_PER_ITEM := 50

## Pickup chain thresholds. The combo is built only by School Items and resets
## when the player is hit or lets an item scroll past.
const COMBO_THRESHOLD_2 := 3
const COMBO_THRESHOLD_3 := 6
const COMBO_THRESHOLD_5 := 10

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

# --- Pursuer (tanod) ---------------------------------------------------------

## Chase speed as a fraction of RUN_SPEED. 0.95 = 399 px/s at base speed.
const PURSUER_CHASE_FACTOR := 0.95
## Eases toward full speed if a chase drags on (seconds to reach 1.0x).
const PURSUER_CHASE_RAMP_TIME := 10.0
## Gap (px behind the player) at which the tanod catches Elias.
const PURSUER_CATCH_DISTANCE := 60.0
## Gap (px) when the tanod wakes up (slides in visible behind the player).
const PURSUER_WAKE_GAP := 300.0
## Dormant gap (px behind the player, off-screen left).
const PURSUER_DORMANT_GAP := 1000.0
## Seconds of chase survived before the tanod gives up and fades.
const PURSUER_FADE_AFTER := 8.0
## Fade-out time (seconds).
const PURSUER_FADE_TIME := 0.6
## Lunge (death animation) duration (seconds).
const PURSUER_LUNGE_TIME := 0.4
## Tanod sprite scale (source 104x166, Elias is 0.6).
const PURSUER_SCALE := 0.45
const PURSUER_SPRITE_HEIGHT := 260.0
## Arrest (combined grab) sprite scale + source height (380 px frames).
const ARREST_SCALE := 0.50
const ARREST_SPRITE_HEIGHT := 380.0
## Time spent playing the arrest before the overlay (12f would be 1.2 s @ 10fps).
const ARREST_TIME := 0.7

## On damage, speed dips for this long (seconds).
const MOMENTUM_DIP_TIME := 1.0
## Speed multiplier while the dip is active (0.75 = 315 px/s at base).
const MOMENTUM_DIP_FACTOR := 0.75
## After the hold, speed eases back to full over this long (seconds).
const MOMENTUM_RECOVER_TIME := 1.5

# --- HUD ---------------------------------------------------------------------

const HEART_SIZE := 48.0
const HEART_GAP := 8.0
const HUD_MARGIN := Vector2(28.0, 24.0)

# --- UI atlas ----------------------------------------------------------------

## Rounded-button icon atlas: a 12x12 grid of 16x16 tiles. Each row is one
## colour family and each column is one glyph, so a tile is picked by
## (column, row). Used by the game-over retry button.
const UI_BUTTON_TEXTURE := "res://assets/ui/button UI.png"
const UI_BUTTON_TILE := 16
## Tile (column, row) holding the plain green button face.
const UI_BUTTON_FACE_TILE := Vector2i(0, 0)
## Tile (column, row) holding the circular "retry" arrow.
const UI_RETRY_TILE := Vector2i(3, 0)
## Tile (column, row) holding the pause glyph (two vertical bars), used by the
## in-game pause button.
const UI_PAUSE_TILE := Vector2i(5, 0)
## Tile (column, row) holding the cross glyph, used by the quit button of the
## in-game control rail.
const UI_QUIT_TILE := Vector2i(4, 1)

## Tile (column, row) holding the play glyph, shown by the pause button while
## the run is frozen.
const UI_PLAY_TILE := Vector2i(1, 0)
## Tile (column, row) holding the speaker glyph, shown by the mute button while
## sound is on.
const UI_SOUND_ON_TILE := Vector2i(0, 1)
## Tile (column, row) holding the crossed-out speaker glyph, shown while muted.
const UI_SOUND_OFF_TILE := Vector2i(1, 1)
## Tile (column, row) holding the gear glyph, used by the settings button.
const UI_SETTINGS_TILE := Vector2i(2, 0)
## Tile (column, row) holding the check glyph, used by the fullscreen toggle.
const UI_CHECK_TILE := Vector2i(5, 1)

## Loading-bar art, reused as the distance meter (track, fill, frame, glow).
const UI_LOADING_TRACK := "res://assets/ui/loading_track.png"
const UI_LOADING_FILL := "res://assets/ui/loading_fill.png"
const UI_LOADING_OVERLAY := "res://assets/ui/loading_overlay.png"
const UI_LOADING_GLOW := "res://assets/ui/loading_glow.png"

## Bar art (648x121), one file per fill level: UI-111..UI-115 is the blue set
## and UI-88..UI-92 the orange set, from empty to full. The speed meter stretches
## the empty frame as its track and clips the full frame as its fill.
const UI_SPEED_BAR_BACK := "res://assets/ui/Bar/UI-111.png"
const UI_SPEED_BAR_FILL := "res://assets/ui/Bar/UI-115.png"


## Slice one glyph/face tile out of the button atlas, for buttons built in code.
static func ui_tile(tile: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(UI_BUTTON_TEXTURE) as Texture2D
	atlas.region = Rect2(
		float(tile.x * UI_BUTTON_TILE), float(tile.y * UI_BUTTON_TILE),
		float(UI_BUTTON_TILE), float(UI_BUTTON_TILE),
	)
	return atlas


# --- Debug -------------------------------------------------------------------

## F3 toggles a read-only tuning overlay. Keep off for release builds.
const DEBUG_OVERLAY := true

## Item icon for HUD display.
const UI_ITEM_ICON := "res://assets/props/item_pencil.png"

# --- Pure helpers ------------------------------------------------------------

## Clamp a lane index into the valid range.
static func clamp_lane(lane: int) -> int:
	return clampi(lane, LANE_TOP, LANE_BOTTOM)


## HUD text for travelled [param distance] in pixels, shown in metres.
static func format_distance(distance: float) -> String:
	return "%.1f m" % (distance / 100.0)


## HUD text for the current world [param speed] in pixels per second.
static func format_speed(speed: float) -> String:
	return "%.0f px/s" % speed


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


## Score multiplier for a pickup chain length.
static func combo_multiplier(chain: int) -> int:
	if chain >= COMBO_THRESHOLD_5:
		return 5
	if chain >= COMBO_THRESHOLD_3:
		return 3
	if chain >= COMBO_THRESHOLD_2:
		return 2
	return 1


## Distance (px) the home zone lasts for [param seconds] at the base run speed,
## clamped to ZONE_HOME_MIN_SECONDS.
static func zone_home_length(seconds: float = ZONE_HOME_DURATION_SECONDS) -> float:
	return maxf(seconds, ZONE_HOME_MIN_SECONDS) * RUN_SPEED


## Distance (px) the street zone lasts for [param seconds] at the base run
## speed, clamped to ZONE_STREET_MIN_SECONDS.
static func zone_street_length(seconds: float = ZONE_STREET_DURATION_SECONDS) -> float:
	return maxf(seconds, ZONE_STREET_MIN_SECONDS) * RUN_SPEED


## Distance (px) the school corridor lasts for [param seconds] at the base run
## speed, clamped to ZONE_SCHOOL_MIN_SECONDS. The endgame hallway begins where
## this ends.
static func zone_school_length(seconds: float = ZONE_SCHOOL_DURATION_SECONDS) -> float:
	return maxf(seconds, ZONE_SCHOOL_MIN_SECONDS) * RUN_SPEED


## Screen x of the endgame exit door for a [param width] px wide viewport.
static func school_exit_x(width: float = DESIGN_WIDTH) -> float:
	return width * SCHOOL_EXIT_X_FRACTION


## Pace multiplier for [param zone].
static func zone_speed_factor(zone: Zone) -> float:
	return float(ZONE_SPEED_FACTOR[clampi(zone, 0, ZONE_SPEED_FACTOR.size() - 1)])


## Base run speed (px/s) for [param zone], before any momentum dip.
static func zone_run_speed(zone: Zone) -> float:
	return RUN_SPEED * zone_speed_factor(zone)


## Fastest base speed in a run. The speed meter fills against this.
static func max_run_speed() -> float:
	return RUN_SPEED * float(ZONE_SPEED_FACTOR.max())


## Zone that applies at [param distance]. Pass [param home_length] and
## [param street_length] to use per-run overrides; non-positive values fall back
## to the configured defaults. SCHOOL is terminal.
static func zone_for_distance(distance: float, home_length: float = -1.0,
		street_length: float = -1.0) -> Zone:
	var home := home_length
	if home <= 0.0:
		home = zone_home_length()
	var street := street_length
	if street <= 0.0:
		street = zone_street_length()
	if distance < home:
		return Zone.HOME
	return Zone.STREET if distance < home + street else Zone.SCHOOL
