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

## The run starts at home, moves to the street, and finishes at school. The
## school never ends in endless play; campaign runs bound it with a timer.
enum Zone { HOME, STREET, SCHOOL }

## How a run is bounded. CAMPAIGN ends in a victory at the finish line;
## ENDLESS keeps the school hallway scrolling until Elias falls.
enum RunMode { CAMPAIGN, ENDLESS }

const ZONE_ORDER := [Zone.HOME, Zone.STREET, Zone.SCHOOL]

## How long the home zone lasts, in seconds. Extend this to keep Elias indoors
## longer; HOME and STREET are timed, SCHOOL runs forever.
const ZONE_HOME_DURATION_SECONDS := 20.0

## Floor for the home duration, so the boundary can never collapse.
const ZONE_HOME_MIN_SECONDS := 5.0

## How long the street zone lasts, in seconds. SCHOOL takes over when it ends.
const ZONE_STREET_DURATION_SECONDS := 40.0

## Floor for the street duration, so the boundary can never collapse.
const ZONE_STREET_MIN_SECONDS := 5.0

## Campaign only: how long the school hallway runs before the finish line.
## Endless play ignores this - its school zone is terminal.
const CAMPAIGN_SCHOOL_SECONDS := 20.0

## Campaign only: stop spawning this many pixels before the finish line so the
## last stretch is a clean sprint instead of a hazard wall.
const CAMPAIGN_SPAWN_CUTOFF_PX := 400.0

## Campaign victory run-off: once the finish line is crossed the world stops and
## Elias keeps running forward - right, the way he already faces - until he is
## fully off the right edge. The results card only appears after that. The exit
## point clears the viewport width plus the sprite's half-width and a margin.
const FINISH_RUN_OFF_EXIT_X := 2000.0
## He sprints off at this multiple of his run speed so the lap stays short. The
## run cycle playback is scaled by the same factor, so his feet keep the ground
## instead of skating.
const FINISH_RUN_OFF_SPEED_FACTOR := 2.5
## Never run off slower than this, even if the last frame's speed was odd.
const FINISH_RUN_OFF_MIN_SPEED := 300.0
## Leftover obstacles fade over this long rather than let Elias ghost through
## frozen cars on his way out.
const FINISH_RUN_OFF_FADE_TIME := 0.25

## Zone swaps are instant: the art changes on the crossing frame. Only hazards
## this close ahead of the player are cleared with it, so nothing lands on him
## during the frame the world changes underneath.
const ZONE_SWAP_CLEAR_PX := 80.0

## Y (in the original house source) where the wall ends and the floor begins.
const HOUSE_FLOOR_SPLIT_Y := 1125.0
## Height of the original house source. Kept so the split can be expressed as a
## ratio and survive any import-time downscale of the texture.
const HOUSE_SOURCE_HEIGHT := 2048.0
const HOUSE_FLOOR_SPLIT_RATIO := HOUSE_FLOOR_SPLIT_Y / HOUSE_SOURCE_HEIGHT

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

## Endless speed ramp: a linear multiplier on RUN_SPEED that starts at 1.0 and
## reaches ENDLESS_RAMP_MAX_MULTIPLIER once ENDLESS_RAMP_DISTANCE px of road
## have been travelled. Campaign runs never ramp.
const ENDLESS_RAMP_MAX_MULTIPLIER := 1.5
const ENDLESS_RAMP_DISTANCE := 40000.0

## Speed multiplier at [param distance_px] for the endless ramp. Monotonic,
## capped at ENDLESS_RAMP_MAX_MULTIPLIER; distance-based so it is deterministic
## and testable headless.
static func endless_speed_multiplier(distance_px: float) -> float:
	return 1.0 + (ENDLESS_RAMP_MAX_MULTIPLIER - 1.0) * clampf(
		distance_px / ENDLESS_RAMP_DISTANCE, 0.0, 1.0)

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

## Declaration order matters: first_zone_kind() returns the first kind a zone
## allows, so MANHOLE stays first to keep the street and school fallbacks
## unchanged. The street props sit after the car; the living-room furniture
## stays last.
enum HazardKind {
	MANHOLE, DEBRIS, SIGN, GANTRY, DOG, CAR,
	BARRICADE, BRICKS, CONE, DUMPSTER,
	NIGHTSTAND, ARMCHAIR, COFFEE_TABLE, CUSHION, BOOKSHELF, BOXES,
}

const DOG_TEXTURES: Array[String] = [
	"res://assets/characters/dog1/Walk.png",
	"res://assets/characters/dog2/Walk.png",
]
const DOG_FIRST_DISTANCE := 12000.0
const DOG_GAP_MIN := 8000.0
const DOG_GAP_MAX := 14000.0
const DOG_WARNING_DURATION := 0.8
const DOG_WARNING_X := DESIGN_WIDTH - 120.0
const DOG_WARNING_Y_OFFSET := 92.0
const DOG_LANE_ENTRY_CLEARANCE := 520.0

## Screen x where the dog barks on its way in. The last is the player's own x,
## so the "move now" bark lands the frame it reaches you, and a RUN_SPEED or
## upgrade change shifts the barks with the picture instead of against it.
const DOG_BARK_X: Array[float] = [1160.0, PLAYER_X]
## Per-variant bark pitch: dog2 is the yappier one.
const DOG_BARK_PITCH: Array[float] = [1.0, 1.06]
## Extra per-bark pitch jitter so repeated barks never sound like one sample.
const DOG_BARK_PITCH_JITTER := 0.04

## Street-only car. The sheets use different cell sizes and car heights, so each
## variant carries its own scale; both read ~105 px tall on the road (with
## CAR_SCALE_MULT applied) and share one hitbox. Art faces right, so it is
## flipped to drive left toward the player.
const CAR_TEXTURES: Array[String] = [
	"res://assets/characters/car/Ride1.png",
	"res://assets/characters/car/Ride2.png",
]
const CAR_VARIANTS := [
	{"texture": CAR_TEXTURES[0], "scale": 1.20},
	{"texture": CAR_TEXTURES[1], "scale": 1.38},
]
## Visual size multiplier for every car variant. 1.0 = the original sheet fit.
const CAR_SCALE_MULT := 1.15
const CAR_WARNING_DURATION := 0.6
const CAR_WARNING_X := DESIGN_WIDTH - 120.0
const CAR_WARNING_Y_OFFSET := 92.0
const CAR_WARNING_TEXTURE := "res://assets/signs/exclamation/Exclamation Mark 2nd Outline 64px.png"
## Cooldown between two car warnings, measured in travelled distance so the
## spacing stays identical if RUN_SPEED changes. 3000-4800 px is about
## 7-11 s at RUN_SPEED 420, i.e. roughly 2-3 cars per street zone.
const CAR_FIRST_DISTANCE := 1500.0
const CAR_GAP_MIN := 3000.0
const CAR_GAP_MAX := 4800.0

## Per-variant honk pitch, indexed by CAR_VARIANTS: Ride1 at 1.0, Ride2 a
## slightly bigger, lower-sounding vehicle at 0.93.
const CAR_HONK_PITCH: Array[float] = [1.0, 0.93]

## Per-variant engine pitch for the pass-by one-shot: the bigger Ride2 idles
## lower. Same variant order as CAR_VARIANTS.
const CAR_ENGINE_PITCH: Array[float] = [1.0, 0.9]

## Per-kind art and hitbox data.
##   clearance    bottom edge sits this far above the lane baseline (overhead)
##   overhead     must be slid under; otherwise it is jumped or dodged
##   frames       0 = single image, >0 = horizontal sprite sheet frame count
##   extra_speed  added leftward speed for moving hazards
##   flip_h       art faces right; flip it so the hazard travels leftward
##   zone         street-only kinds skip every zone but Zone.STREET
const HAZARD_DATA := {
	HazardKind.MANHOLE: {
		"texture": "res://assets/hazards/haz_manhole.png",
		"scale": 1.3, "hitbox_w": 70.0, "hitbox_h": 40.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	## Debris is shared by the street and the school (no "zones" list). Its art
	## is scaled to read in the same ~100 px band as the street props.
	HazardKind.DEBRIS: {
		"texture": "res://assets/hazards/haz_debris.png",
		"scale": 1, "hitbox_w": 96.0, "hitbox_h": 67.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
	},
	## SIGN and GANTRY are school-hallway props now: the street keeps its own
	## six street props instead. GANTRY stays the one overhead hazard, so the
	## slide still matters in the school.
	HazardKind.SIGN: {
		"texture": "res://assets/hazards/haz_sign.png",
		"scale": 0.8, "hitbox_w": 38.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.SCHOOL],
	},
	HazardKind.GANTRY: {
		"texture": "res://assets/hazards/haz_gantry.png",
		"scale": 0.8, "hitbox_w": 150.0, "hitbox_h": 56.0,
		"clearance": 62.0, "overhead": true, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.SCHOOL],
	},
	HazardKind.DOG: {
		"texture": DOG_TEXTURES[0],
		"scale": 3.0, "hitbox_w": 40.0, "hitbox_h": 40.0,
		"clearance": 0.0, "overhead": false, "frames": 6, "extra_speed": 200.0,
		"flip_h": true, "zones": [Zone.STREET],
	},
	## Dodge-only until SPRING SHOES 3: at extra_speed 700 the car sweeps past
	## in (280 + player hitbox) / 1120 ≈ 0.31 s, which fits inside the
	## level-3+ jump-clear window above the 100 px hitbox but outlasts the
	## level-2 window, so switching lanes is the only dodge below level 3.
	HazardKind.CAR: {
		"texture": CAR_TEXTURES[0],
		"scale": 1.20, "hitbox_w": 280.0, "hitbox_h": 100.0,
		"clearance": 0.0, "overhead": false, "frames": 8, "extra_speed": 700.0,
		"flip_h": true, "zones": [Zone.STREET],
	},
	## Street-only props: the street zone's non-moving hazards. All stand on the
	## road (clearance 0, jumped like the debris), scaled to read ~96-105 px
	## tall - the same band as the living-room props, visibly under the 118 px
	## jump apex - with a uniform 64 px hitbox so one jump timing clears them.
	HazardKind.BARRICADE: {
		"texture": "res://assets/hazards/haz_barricade.png",
		"scale": 0.40, "hitbox_w": 70.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.STREET],
	},
	HazardKind.BRICKS: {
		"texture": "res://assets/hazards/haz_bricks.png",
		"scale": 0.30, "hitbox_w": 100.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.STREET],
	},
	HazardKind.CONE: {
		"texture": "res://assets/hazards/haz_cone.png",
		"scale": 0.49, "hitbox_w": 50.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.STREET],
	},
	HazardKind.DUMPSTER: {
		"texture": "res://assets/hazards/haz_dumpster.png",
		"scale": 0.45, "hitbox_w": 90.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.STREET],
	},
	## Living-room furniture: HOME-only hazards, available from the house's
	## first pixel (the unlock fractions all sit at 0.00). All stand on the
	## floor (clearance 0, jumped like the debris) and the art is scaled to
	## read ~97-107 px tall, visibly under the 118 px jump apex. The hitboxes
	## stay 64 px tall so the bigger art changes nothing about jump timing.
	HazardKind.NIGHTSTAND: {
		"texture": "res://assets/hazards/haz_nightstand.png",
		"scale": 0.39, "hitbox_w": 48.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
	HazardKind.ARMCHAIR: {
		"texture": "res://assets/hazards/haz_armchair.png",
		"scale": 0.39, "hitbox_w": 62.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
	HazardKind.COFFEE_TABLE: {
		"texture": "res://assets/hazards/haz_coffee_table.png",
		"scale": 0.49, "hitbox_w": 84.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
	HazardKind.CUSHION: {
		"texture": "res://assets/hazards/haz_cushion.png",
		"scale": 0.42, "hitbox_w": 48.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
	HazardKind.BOOKSHELF: {
		"texture": "res://assets/hazards/haz_bookshelf.png",
		"scale": 0.38, "hitbox_w": 54.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
	HazardKind.BOXES: {
		"texture": "res://assets/hazards/haz_boxes.png",
		"scale": 0.45, "hitbox_w": 70.0, "hitbox_h": 64.0,
		"clearance": 0.0, "overhead": false, "frames": 0, "extra_speed": 0.0,
		"zones": [Zone.HOME],
	},
}

## Distance (px) after which each kind starts appearing. The street props ramp
## in across the street's first ~25 s rather than the run's: the street does
## not begin until the house ends (~8 400 px at base speed), so a street 0 is
## "street start", not "run start".
const HAZARD_UNLOCK := {
	HazardKind.MANHOLE: 0.0,
	HazardKind.DEBRIS: 0.0,
	HazardKind.BARRICADE: 0.0,
	HazardKind.CONE: 10000.0,
	HazardKind.BRICKS: 14000.0,
	HazardKind.DUMPSTER: 18000.0,
	HazardKind.GANTRY: 8000.0,
	HazardKind.SIGN: 12000.0,
	HazardKind.DOG: DOG_FIRST_DISTANCE,
	HazardKind.CAR: 0.0,
}

## Relative spawn weight of each kind once unlocked.
const HAZARD_WEIGHT := {
	HazardKind.MANHOLE: 3.0,
	HazardKind.DEBRIS: 3.0,
	HazardKind.BARRICADE: 3.0,
	HazardKind.CONE: 2.5,
	HazardKind.BRICKS: 2.0,
	HazardKind.DUMPSTER: 2.0,
	HazardKind.GANTRY: 2.5,
	HazardKind.SIGN: 1.5,
	## Dogs use the dedicated warned encounter clock, not random hazard rows.
	HazardKind.DOG: 0.0,
	## Cars warn first (like the dog), so their row weight is meaningful only
	## in the street zone where the kind is allowed at all.
	HazardKind.CAR: 2.0,
	## Living-room furniture. HOME-only, flat weights: every prop is equally
	## likely on a home row, and no outdoor kind competes with them.
	HazardKind.NIGHTSTAND: 2.0,
	HazardKind.ARMCHAIR: 2.0,
	HazardKind.COFFEE_TABLE: 2.0,
	HazardKind.CUSHION: 2.0,
	HazardKind.BOOKSHELF: 2.0,
	HazardKind.BOXES: 2.0,
}

## Home props unlock as a fraction of the home zone's length. All zero means
## the whole living room is available from the house's first pixel; raise a
## value to stagger that prop again (scaled to the house length), while every
## kind stays active until the home zone ends.
const HOME_HAZARD_UNLOCK_FRACTION := {
	HazardKind.NIGHTSTAND: 0.00,
	HazardKind.ARMCHAIR: 0.00,
	HazardKind.CUSHION: 0.00,
	HazardKind.COFFEE_TABLE: 0.00,
	HazardKind.BOXES: 0.00,
	HazardKind.BOOKSHELF: 0.00,
}

## Distance (px) after which [param kind] starts appearing. Home kinds are
## available from the start of the house (fractions 0.00 by default, scaled to
## the home zone's length - pass the run's real value; -1 falls back to the
## configured default); every other kind keeps its fixed pixel value.
static func hazard_unlock(kind: int, home_length: float = -1.0) -> float:
	if HOME_HAZARD_UNLOCK_FRACTION.has(kind):
		var home_len := home_length if home_length > 0.0 else zone_home_length()
		return float(HOME_HAZARD_UNLOCK_FRACTION[kind]) * home_len
	return float(HAZARD_UNLOCK.get(kind, 0.0))


## True when [param kind] may appear in [param zone]. Kinds with an explicit
## "zones" list are restricted to it; kinds without one are outdoor/agnostic
## and never appear in the house, which is furniture-only. zone == -1 (tests
## and pattern rolls) matches the pre-zones behavior exactly: ungated kinds
## only.
static func hazard_allows_zone(kind: int, zone: int) -> bool:
	var data: Dictionary = HAZARD_DATA[kind]
	if data.has("zones"):
		return (data["zones"] as Array).has(zone)
	return zone != Zone.HOME


## First kind by declaration order that [param zone] allows, used as the
## zone-legal fallback when no kind qualifies at a distance. HOME yields the
## nightstand (unlocked at 0), so indoor rows can never fall back to street
## art; STREET and SCHOOL resolve to the manhole, the same value the old
## hardcoded fallback returned there.
static func first_zone_kind(zone: int) -> int:
	for kind: int in HAZARD_DATA:
		if hazard_allows_zone(kind, zone):
			return kind
	return HazardKind.MANHOLE

# --- School Items ------------------------------------------------------------

enum ItemKind { PENCIL, ERASER, BOOK, BAG, COIN }

## Per-kind art. All items float at the same hover height and share one hitbox.
## Currency kinds carry "currency": true - they route to the coin wallet
## instead of the score, and never break the pickup combo when missed.
const ITEM_DATA := {
	ItemKind.PENCIL: {"texture": "res://assets/props/item_pencil.png", "scale": 0.44},
	ItemKind.ERASER: {"texture": "res://assets/props/item_eraser.png", "scale": 0.42},
	ItemKind.BOOK: {"texture": "res://assets/props/item_book.png", "scale": 0.55},
	ItemKind.BAG: {"texture": "res://assets/props/item_bag.png", "scale": 0.50},
	ItemKind.COIN: {
		"texture": "res://assets/icon/coin/Golden Coin 2nd Outline 64px.png",
		"scale": 0.62,
		"currency": true,
	},
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

## Coins run on their own distance clock, like School Items but rarer. A run
## drops COIN_RUN_MIN..COIN_RUN_MAX coins at once, all in one clear lane,
## spaced COIN_SPACING px apart so Elias collects them in a trail.
const COIN_RUN_GAP_MIN := 2400.0
const COIN_RUN_GAP_MAX := 4200.0
const COIN_RUN_MIN := 3
const COIN_RUN_MAX := 5
const COIN_SPACING := 160.0

## Currency added to the persistent wallet per coin collected.
const COIN_VALUE := 1

# --- Shop upgrades -----------------------------------------------------------

## Purchasable upgrades. DASH is reserved (its icon exists on the sheet) and
## stays out of SHOP_UPGRADES until the dash mechanic ships.
enum ShopUpgrade { SPEED, LUCK, JUMP, HEARTS, SHIELD }

## Per-upgrade tuning: display name, per-level effect blurb, level cap, and the
## cost curve (level 1 costs base_cost; level N costs base_cost * growth^(N-1)).
const SHOP_UPGRADES := {
	ShopUpgrade.SPEED: {
		"name": "RUN SPEED", "desc": "+3% world speed per level",
		"max_level": 5, "base_cost": 40, "cost_growth": 1.65,
	},
	ShopUpgrade.LUCK: {
		"name": "LUCKY CHARM", "desc": "Pickups and coins appear more often",
		"max_level": 5, "base_cost": 50, "cost_growth": 1.70,
	},
	ShopUpgrade.JUMP: {
		"name": "SPRING SHOES", "desc": "+8% jump height per level",
		"max_level": 5, "base_cost": 40, "cost_growth": 1.65,
	},
	ShopUpgrade.HEARTS: {
		"name": "EXTRA HEART", "desc": "+1 max heart per level",
		"max_level": 3, "base_cost": 80, "cost_growth": 1.80,
	},
	ShopUpgrade.SHIELD: {
		"name": "GUARDIAN SHIELD", "desc": "Blocks one hit per run, per level",
		"max_level": 2, "base_cost": 120, "cost_growth": 1.90,
	},
}

## Where to buy effects apply. Speed multiplies _base_speed, Luck multiplies
## the pickup and coin-run spawn gaps, Jump scales JUMP_SPEED, Hearts extends
## MAX_HEARTS, Shield grants per-run charges that absorb hazard hits.

## World speed multiplier for a speed level (level 0 = untouched).
static func shop_speed_multiplier(level: int) -> float:
	return 1.0 + 0.03 * clampi(level, 0, 5)

## Spawn-gap multiplier for a luck level (level 0 = 1.0; higher = denser).
static func shop_luck_gap_factor(level: int) -> float:
	return pow(0.92, clampi(level, 0, 5))

## Jump launch speed for a jump level, so the apex grows ~8% per level
## (apex scales with the square of launch speed).
static func shop_jump_speed(level: int) -> float:
	return JUMP_SPEED * sqrt(1.0 + 0.08 * clampi(level, 0, 5))


## Seconds the player's hitbox stays above [param height] for a jump launch at
## [param level]. 0.0 when the apex never reaches the height. A hazard of that
## hitbox height is jumpable at [param level] iff this window exceeds the time
## the hazard spends sweeping horizontally past the player's hitbox.
static func jump_clear_window(height: float, level: int) -> float:
	var v := shop_jump_speed(level)
	var disc := v * v - 2.0 * GRAVITY * height
	return 0.0 if disc <= 0.0 else 2.0 * sqrt(disc) / GRAVITY

## Max hearts for a hearts level (base MAX_HEARTS plus the bought extras).
static func shop_max_hearts(level: int) -> int:
	return MAX_HEARTS + clampi(level, 0, 3)

## Per-run shield charges for a shield level.
static func shop_shield_charges(level: int) -> int:
	return clampi(level, 0, 2)

## Coin cost of raising an upgrade from its current [param level].
static func shop_cost(kind: int, level: int) -> int:
	var data: Dictionary = SHOP_UPGRADES[kind]
	var current := clampi(level, 0, int(data["max_level"]))
	return int(round(
		float(data["base_cost"]) * pow(float(data["cost_growth"]), current)))

# --- Score -------------------------------------------------------------------

const SCORE_DISTANCE_DIVISOR := 10.0
const SCORE_PER_HAZARD := 10
const SCORE_PER_ITEM := 50

## Pickup chain thresholds. The combo is built only by School Items and resets
## when the player is hit or lets an item scroll past. Four rungs so the climb
## is 2/3/4/5 rather than a jump from 3 to 5; every rung lasts at least two
## items at the pickup cadence (~3-4 s apart).
const COMBO_THRESHOLD_2 := 3
const COMBO_THRESHOLD_3 := 6
const COMBO_THRESHOLD_4 := 8
const COMBO_THRESHOLD_5 := 10

## One-time coin bonus per rung, paid once per tier per run (ScoreSystem tracks
## the paid set). Bounded on purpose: a perfect chain adds +8 coins to a run
## that collects 50-70, so the combo feeds progression without inflating the
## shop's exponential price curve.
const COMBO_TIER_COIN_BONUS := {2: 1, 3: 2, 4: 2, 5: 3}

## --- Result medals -----------------------------------------------------------
## Endless runs medal by distance reached; campaign runs medal by finishing and
## then by score against the session best. Both rules live here so thresholds
## stay tunable.

enum Medal { BLACK, SILVER, GOLD }

## Distance (m) needed for the endless-run silver and gold medals.
const MEDAL_DISTANCE_SILVER := 500.0
const MEDAL_DISTANCE_GOLD := 1000.0

## Endless rule: how far Elias got before the run ended.
static func medal_for_distance(distance_m: float) -> int:
	if distance_m >= MEDAL_DISTANCE_GOLD:
		return Medal.GOLD
	if distance_m >= MEDAL_DISTANCE_SILVER:
		return Medal.SILVER
	return Medal.BLACK


## Campaign rule (finish-gated score): reaching the school is the floor for any
## medal, and the score against the best recorded BEFORE this run decides gold.
## A first clear is silver - gold has to be earned against a real record.
static func campaign_medal(finished: bool, score: int, previous_best: int) -> int:
	if not finished:
		return Medal.BLACK
	if previous_best > 0 and score > previous_best:
		return Medal.GOLD
	return Medal.SILVER

## --- Progress bar ------------------------------------------------------------

## Campaign course progress as a 0..1 fraction of the finish line. Uses the
## per-run zone lengths, so retuned durations re-proportion the bar for free.
static func campaign_progress(
	distance: float,
	home_length: float,
	street_length: float,
	finish_distance: float,
) -> float:
	if finish_distance <= 0.0:
		return 0.0
	return clampf(distance / finish_distance, 0.0, 1.0)


## Campaign bar segment widths as fractions of the whole track, in
## (home, street, school) order. Each zone gets its real share of the course.
static func campaign_segment_fractions(
	home_length: float,
	street_length: float,
	finish_distance: float,
) -> Vector3:
	if finish_distance <= 0.0:
		return Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
	var school_length := maxf(finish_distance - home_length - street_length, 0.0)
	return Vector3(
		home_length / finish_distance,
		street_length / finish_distance,
		school_length / finish_distance,
	)


## Endless bar progress as a 0..1 fraction toward the gold medal distance.
## Distances arrive in px (world distance); medals are measured in metres.
static func endless_progress(distance_px: float) -> float:
	return clampf(distance_px / (MEDAL_DISTANCE_GOLD * 100.0), 0.0, 1.0)


## Endless silver-tick position as a 0..1 fraction of the track.
static func endless_silver_fraction() -> float:
	return MEDAL_DISTANCE_SILVER / MEDAL_DISTANCE_GOLD


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
## Applied to the faster of the current world speed and RUN_SPEED, so the
## tanod keeps up with the endless speed ramp while a momentum dip (world
## below RUN_SPEED) still lets him close the gap.
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
## Arrest (combined grab) sprite scale + frame height (340x311 frames sliced
## from NewArrest.png). 0.65 keeps the pair at the same ~190 px the old 380 px
## frames read at 0.50, so the grab sits on Elias exactly as before.
const ARREST_SCALE := 0.65
const ARREST_SPRITE_HEIGHT := 311.0
## Arrest playback length: 5 frames at 6.5 fps, the last held twice (~0.77 s).
const ARREST_TIME := 0.77

## On damage, speed dips for this long (seconds).
const MOMENTUM_DIP_TIME := 1.0
## Speed multiplier while the dip is active (0.75 = 315 px/s at base).
const MOMENTUM_DIP_FACTOR := 0.75
## After the hold, speed eases back to full over this long (seconds).
const MOMENTUM_RECOVER_TIME := 1.5

# --- Audio --------------------------------------------------------------------

## Run music bed. The track is mastered hot (-13.7 LUFS integrated), so -10 dB
## lands it near the -24 LUFS game target and ~6 dB under the barks (-4) and
## car engine (-6). The menu sits at -8 dB on an even hotter master.
const MUSIC_VOLUME_DB := -10.0
## Duck while the tanod chases, so the barks read over the bed.
const MUSIC_DUCK_DB := -16.0
## -inf would break the fade maths; -40 dB is inaudible.
const MUSIC_SILENT_DB := -40.0
const MUSIC_FADE_IN_TIME := 0.6
const MUSIC_DUCK_TIME := 0.25
const MUSIC_FADE_OUT_TIME := 0.7

## Failure cue: a sting and a looping bed, played together on the reveal.
## Victory stays silent by design.
const FAIL_STING_DB := -4.0
## Sits under the sting's -4 so the sting still reads on top of the bed.
const FAIL_MUSIC_DB := -12.0
const FAIL_MUSIC_FADE_IN := 0.6

# --- Countdown ---------------------------------------------------------------

## 3-2-1-GO beats before every run start: a fresh launch, a retry and a
## pause-menu restart all come through the same RunWorld._ready.
const START_COUNTDOWN_BEATS := 3
## Seconds each number holds. One second is the arcade convention and the
## slowest pace that still reads at TV distance.
const START_COUNTDOWN_BEAT_TIME := 1.0
## The GO beat is shorter: it only has to cover the input-unlock pop, and the
## world is already running by then.
const START_COUNTDOWN_GO_TIME := 0.6
## Any input after this long fast-forwards straight to GO, so a death -> retry
## loop is never held hostage by the countdown.
const START_COUNTDOWN_SKIP_DELAY := 0.4
## Ticks and the GO blip. The samples peak near -4 dBFS, so this lands them
## around -10 dBFS: present, never loud enough to mask a honk on the first note.
const COUNTDOWN_SFX_DB := -6.0
## Pitch ladder for 3/2/1: a rising perfect fourth (~660 / 832 / 1048 Hz). GO
## is its own brighter sample (~1320 Hz) rather than a fourth step.
const COUNTDOWN_TICK_PITCH_STEP := 1.26
## Spoken 3-2-1-GO layered under the beeps. Its cues peak near -0.4 dBFS, so it
## sits a couple of dB below the ticks: the voice carries the count while the
## short beeps keep the beat crisp.
const COUNTDOWN_CUE_DB := -8.0

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


## Score multiplier for a pickup chain length.
static func combo_multiplier(chain: int) -> int:
	if chain >= COMBO_THRESHOLD_5:
		return 5
	if chain >= COMBO_THRESHOLD_4:
		return 4
	if chain >= COMBO_THRESHOLD_3:
		return 3
	if chain >= COMBO_THRESHOLD_2:
		return 2
	return 1


## Chain length needed for the next multiplier rung, or 0 when the ladder is
## already maxed. Drives the HUD's "x3 · 6/8" readout.
static func combo_next_threshold(chain: int) -> int:
	if chain < COMBO_THRESHOLD_2:
		return COMBO_THRESHOLD_2
	if chain < COMBO_THRESHOLD_3:
		return COMBO_THRESHOLD_3
	if chain < COMBO_THRESHOLD_4:
		return COMBO_THRESHOLD_4
	if chain < COMBO_THRESHOLD_5:
		return COMBO_THRESHOLD_5
	return 0


## One-time coins for reaching [param tier] (0 for an unknown rung).
static func combo_tier_coin_bonus(tier: int) -> int:
	return int(COMBO_TIER_COIN_BONUS.get(tier, 0))


## Distance (px) the home zone lasts for [param seconds] at the base run speed,
## clamped to ZONE_HOME_MIN_SECONDS.
static func zone_home_length(seconds: float = ZONE_HOME_DURATION_SECONDS) -> float:
	return maxf(seconds, ZONE_HOME_MIN_SECONDS) * RUN_SPEED


## Distance (px) the street zone lasts for [param seconds] at the base run speed,
## clamped to ZONE_STREET_MIN_SECONDS.
static func zone_street_length(seconds: float = ZONE_STREET_DURATION_SECONDS) -> float:
	return maxf(seconds, ZONE_STREET_MIN_SECONDS) * RUN_SPEED


## Distance (px) the school zone lasts for [param seconds] at the base run
## speed. Only the campaign bounds the school; endless play passes no cap.
static func zone_school_length(seconds: float = CAMPAIGN_SCHOOL_SECONDS) -> float:
	return maxf(seconds, 0.0) * RUN_SPEED


## Zone that applies at [param distance] for [param mode]. Pass
## [param home_length] and [param street_length] to use per-run overrides; a
## non-positive value falls back to the configured default.
##
## CAMPAIGN maps HOME -> STREET -> SCHOOL; ENDLESS maps HOME -> STREET and stays
## in the street forever - the school zone is never reached, so its art is
## never drawn and its hallway never scrolls.
static func zone_for_distance(
	distance: float,
	home_length: float = -1.0,
	street_length: float = -1.0,
	mode: int = RunMode.CAMPAIGN,
) -> Zone:
	var home_end := home_length
	if home_end <= 0.0:
		home_end = zone_home_length()
	var street_len := street_length
	if street_len <= 0.0:
		street_len = zone_street_length()
	if distance < home_end:
		return Zone.HOME
	if mode == RunMode.ENDLESS:
		return Zone.STREET
	if distance < home_end + street_len:
		return Zone.STREET
	return Zone.SCHOOL


## Distance (px) at which a campaign run reaches the finish line: one timed
## pass of every zone. Endless runs have no finish.
static func campaign_finish_distance(
	home_length: float = -1.0,
	street_length: float = -1.0,
	school_length: float = -1.0,
) -> float:
	var home_len := home_length if home_length > 0.0 else zone_home_length()
	var street_len := street_length if street_length > 0.0 else zone_street_length()
	var school_len := school_length if school_length > 0.0 else zone_school_length()
	return home_len + street_len + school_len
