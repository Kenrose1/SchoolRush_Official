class_name Hud
extends Control
## Drives the HUD nodes that live in scenes/hud.tscn. Layout, fonts and colours
## are all editable in the editor; this script only fills in the values.

var game: Game
var impact := 0.0
var prompt_time := 0.0
var banner_time := 0.0

@onready var hearts: HBoxContainer = $Hearts
@onready var speed_bar: ProgressBar = $SpeedBar
@onready var speed_value: Label = $SpeedValue
@onready var score_value: Label = $ScoreValue
@onready var combo_value: Label = $ComboValue
@onready var pursuer_label: Label = $PursuerLabel
@onready var progress: Control = $Progress
@onready var progress_bar: ProgressBar = $Progress/Bar
@onready var bell_label: Label = $Progress/Bell
@onready var mode_label: Label = $ModeLabel
@onready var prompt: Label = $Prompt
@onready var banner: Label = $Banner
@onready var vignette: TextureRect = $Vignette

var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.modulate.a = 0.0
	banner.modulate.a = 0.0
	vignette.modulate.a = 0.0
	pursuer_label.visible = false


func _process(delta: float) -> void:
	_pulse += delta
	impact = maxf(0.0, impact - delta * 1.6)
	prompt_time = maxf(0.0, prompt_time - delta)
	banner_time = maxf(0.0, banner_time - delta)
	vignette.modulate.a = impact * 0.9
	prompt.modulate.a = minf(1.0, prompt_time * 3.0)
	banner.modulate.a = minf(1.0, banner_time * 1.4)
	if game == null:
		return
	_update_hearts()
	_update_speed()
	_update_score()
	_update_progress()


func flash_impact() -> void:
	impact = 1.0


func show_prompt(text: String, hold := 0.45) -> void:
	prompt.text = text
	prompt_time = hold


func show_banner(text: String) -> void:
	banner.text = text
	banner_time = 2.4


func _update_hearts() -> void:
	for i in hearts.get_child_count():
		var heart := hearts.get_child(i) as TextureRect
		heart.visible = i < game.max_hearts
		heart.modulate = Pal.RED if i < game.hearts else Color(0.22, 0.28, 0.36, 1)


func _update_speed() -> void:
	var ratio := clampf(game.speed_ratio(), 0.0, 1.0)
	speed_bar.value = ratio * 100.0
	speed_value.text = "%d km/h" % int(round(game.speed * 0.045))


func _update_score() -> void:
	score_value.text = "%06d" % int(game.score)
	var combo_color := Pal.YELLOW if game.combo > 1 else Pal.MUTED
	combo_value.text = "ITEMS %d   COMBO x%d" % [game.items, game.combo]
	combo_value.modulate = combo_color
	pursuer_label.visible = game.pursuer_threat
	if game.pursuer_threat:
		var blink := 0.55 + 0.45 * sin(_pulse * 14.0)
		pursuer_label.modulate.a = blink


func _update_progress() -> void:
	var is_campaign := game.mode == "campaign"
	progress.visible = is_campaign
	mode_label.visible = not is_campaign
	mode_label.text = game.mode_label()
	if not is_campaign:
		return
	progress_bar.value = clampf(game.progress(), 0.0, 1.0) * 100.0
	var bell := game.bell_left
	bell_label.text = "BELL %d:%02d" % [int(bell) / 60, int(bell) % 60]
	bell_label.modulate = Pal.WHITE if bell > 20.0 else Pal.RED
