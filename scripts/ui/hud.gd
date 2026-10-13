class_name Hud
extends CanvasLayer
## In-level HUD: hearts, coin count, Lost Sprites (x/3) and the boss health bar.
## Everything is driven by GameState signals.

const HEART_SIZE: Vector2 = Vector2(42, 38)

@onready var _hearts_row: HBoxContainer = $Root/TopLeft/Hearts
@onready var _coin_label: Label = $Root/TopLeft/Coins/Label
@onready var _sprite_label: Label = $Root/TopLeft/Sprites/Label
@onready var _sprite_icon: HudIcon = $Root/TopLeft/Sprites/Icon
@onready var _boss_panel: Control = $Root/BossPanel
@onready var _boss_name: Label = $Root/BossPanel/Name
@onready var _boss_bar: ProgressBar = $Root/BossPanel/Bar

var _hearts: Array[HudIcon] = []
var _shown_health: int = -1


func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.sprites_changed.connect(_on_sprites_changed)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.boss_ended.connect(_on_boss_ended)
	_boss_panel.visible = false
	_on_health_changed(GameState.health, GameState.max_health)
	_on_coins_changed(GameState.coins)
	_on_sprites_changed(GameState.sprite_count(), GameState.sprites_total)
	for label: Label in [_coin_label, _sprite_label]:
		label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)


func get_heart_count() -> int:
	return _hearts.size()


func get_filled_hearts() -> int:
	return _hearts.filter(func(h: HudIcon) -> bool: return h.filled).size()


func _on_health_changed(current: int, maximum: int) -> void:
	while _hearts.size() < maximum:
		var heart: HudIcon = HudIcon.new()
		heart.custom_minimum_size = HEART_SIZE
		_hearts_row.add_child(heart)
		_hearts.append(heart)
	while _hearts.size() > maximum:
		_hearts.pop_back().queue_free()
	for i: int in _hearts.size():
		var was_filled: bool = _hearts[i].filled
		_hearts[i].filled = i < current
		if was_filled != _hearts[i].filled and _shown_health >= 0:
			_pop(_hearts[i], 1.35 if _hearts[i].filled else 0.6)
	_shown_health = current


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "%d" % total
	_pop(_coin_label, 1.3)


func _on_sprites_changed(count: int, total: int) -> void:
	_sprite_label.text = "%d/%d" % [count, total]
	_sprite_icon.filled = count > 0
	_pop(_sprite_label, 1.4)


func _on_boss_started(boss_name: String, max_health: int) -> void:
	_boss_name.text = boss_name
	_boss_bar.max_value = max_health
	_boss_bar.value = max_health
	_boss_panel.visible = true
	_boss_panel.modulate.a = 0.0
	create_tween().tween_property(_boss_panel, "modulate:a", 1.0, 0.4)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_bar.max_value = maximum
	create_tween().tween_property(_boss_bar, "value", float(current), 0.25)


func _on_boss_ended(_defeated: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_boss_panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _boss_panel.visible = false)


func _pop(control: Control, peak: float) -> void:
	if not is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	control.scale = Vector2(peak, peak)
	tween.tween_property(control, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
