## HUD 界面脚本
## 显示阳光、生命、波次信息，处理植物选择
class_name GameHUD
extends CanvasLayer

## ---- 常量 ----
const MESSAGE_TIME := 3.0

## ---- 节点引用 ----
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var lives_label: Label = $MarginContainer/VBoxContainer/TopBar/LivesLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopBar/WaveLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/TopBar/LevelLabel
@onready var wave_preview_label: Label = $MarginContainer/VBoxContainer/WavePreviewLabel
@onready var enemy_legend_label: Label = $MarginContainer/VBoxContainer/BottomBar/EnemyLegendLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var overlay: Control = $Overlay
@onready var start_panel: PanelContainer = $Overlay/StartPanel
@onready var pause_panel: PanelContainer = $Overlay/PausePanel
@onready var level_select_panel: PanelContainer = $Overlay/LevelSelectPanel
@onready var result_panel: PanelContainer = $Overlay/ResultPanel
@onready var result_title: Label = $Overlay/ResultPanel/ResultBox/ResultTitle
@onready var result_stats: Label = $Overlay/ResultPanel/ResultBox/ResultStats
@onready var start_button: Button = $Overlay/StartPanel/StartBox/StartButton
@onready var level_select_button: Button = $MarginContainer/VBoxContainer/TopBar/LevelSelectButton
@onready var start_wave_button: Button = $MarginContainer/VBoxContainer/TopBar/StartWaveButton
@onready var pause_button: Button = $MarginContainer/VBoxContainer/TopBar/PauseButton
@onready var speed_button: Button = $MarginContainer/VBoxContainer/TopBar/SpeedButton
@onready var restart_button: Button = $MarginContainer/VBoxContainer/TopBar/RestartButton
@onready var resume_button: Button = $Overlay/PausePanel/PauseBox/ResumeButton
@onready var restart_pause_button: Button = $Overlay/PausePanel/PauseBox/RestartPauseButton
@onready var volume_slider: HSlider = $Overlay/PausePanel/PauseBox/VolumeRow/VolumeSlider
@onready var mute_button: Button = $Overlay/PausePanel/PauseBox/MuteButton
@onready var prev_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectControls/PrevLevelButton
@onready var next_select_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectControls/NextSelectLevelButton
@onready var confirm_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/ConfirmLevelButton
@onready var difficulty_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/DifficultyButton
@onready var cancel_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/CancelLevelButton
@onready var level_select_title: Label = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectTitle
@onready var level_select_description: Label = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectDescription
@onready var next_level_button: Button = $Overlay/ResultPanel/ResultBox/NextLevelButton
@onready var restart_result_button: Button = $Overlay/ResultPanel/ResultBox/RestartResultButton
@onready var arrow_tower_button: Button = $MarginContainer/VBoxContainer/BottomBar/ArrowTowerButton
@onready var cannon_tower_button: Button = $MarginContainer/VBoxContainer/BottomBar/CannonTowerButton
@onready var frost_tower_button: Button = $MarginContainer/VBoxContainer/BottomBar/FrostTowerButton
@onready var priority_button: Button = $MarginContainer/VBoxContainer/BottomBar/PriorityButton
@onready var upgrade_button: Button = $MarginContainer/VBoxContainer/BottomBar/UpgradeButton
@onready var sell_button: Button = $MarginContainer/VBoxContainer/BottomBar/SellButton

var _pending_level_index: int = 0
var _tower_buttons: Dictionary = {}
var _selected_tower_for_actions: Tower = null

## 主场景（HUD 的父节点），用于回调游戏流程方法
@onready var _main: GameMain = get_parent() as GameMain

## 漏怪时的全屏红闪（覆盖游戏世界、位于 HUD 文本与遮罩之下）
var _damage_flash: ColorRect = null
var _damage_flash_tween: Tween = null

## ---- 生命周期 ----
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_gameplay_hud_click_through($MarginContainer)

	# 连接 GameManager 信号
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.wave_countdown.connect(_on_wave_countdown)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.tower_selection_changed.connect(_on_tower_selection_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.game_speed_changed.connect(_on_game_speed_changed)
	GameManager.audio_settings_changed.connect(_on_audio_settings_changed)

	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_pause_button.pressed.connect(_on_restart_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	mute_button.pressed.connect(_on_mute_pressed)
	prev_level_button.pressed.connect(_on_prev_level_pressed)
	next_select_level_button.pressed.connect(_on_next_select_level_pressed)
	confirm_level_button.pressed.connect(_on_confirm_level_pressed)
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)
	cancel_level_button.pressed.connect(_on_cancel_level_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)
	restart_result_button.pressed.connect(_on_restart_pressed)
	arrow_tower_button.pressed.connect(_on_tower_button_pressed.bind("arrow"))
	cannon_tower_button.pressed.connect(_on_tower_button_pressed.bind("cannon"))
	frost_tower_button.pressed.connect(_on_tower_button_pressed.bind("frost"))
	priority_button.pressed.connect(_on_priority_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	_tower_buttons = {
		"arrow": arrow_tower_button,
		"cannon": cannon_tower_button,
		"frost": frost_tower_button,
	}

	_setup_damage_flash()

	# 初始化显示
	_update_all()
	_on_audio_settings_changed(GameManager.sound_volume, GameManager.is_muted)
	hide_overlay()

## 创建全屏红闪层，并下移到 HUD 最底层（盖住游戏世界，但在文本/遮罩之下）
func _setup_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_flash)
	move_child(_damage_flash, 0)

## 漏怪反馈：屏幕红闪一下并淡出
func flash_damage() -> void:
	if _damage_flash == null:
		return
	if _damage_flash_tween and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()
	_damage_flash.color = Color(0.9, 0.1, 0.1, 0.32)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.45)

func _make_gameplay_hud_click_through(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if control is BaseButton:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_gameplay_hud_click_through(child)

## ---- 更新方法 ----

func _update_all() -> void:
	gold_label.text = "阳光: %d" % GameManager.gold
	lives_label.text = "生命: %d" % GameManager.lives
	_update_wave_text(0)
	_update_wave_preview(1, "下一波")
	_update_enemy_legend()
	_update_level_text()
	_update_selected_tower_text()
	_update_speed_button(GameManager.get_game_speed())
	set_start_wave_available(true)
	message_label.text = "1/2/3 选植物，左键种植/选中，空格催下一波，T 切目标，F 快进，M 静音，F11 全屏"

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "阳光: %d" % new_gold
	_update_tower_buttons()
	_update_action_buttons()

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "生命: %d" % new_lives

func _on_wave_started(wave_num: int) -> void:
	_update_wave_text(wave_num)
	_update_wave_preview(wave_num, "本波")
	set_can_call_next_wave(false)
	show_message("第 %d/%d 波来袭！" % [wave_num, GameManager.get_wave_count()])

func _on_wave_completed(wave_num: int) -> void:
	var next_wave := wave_num + 1
	if next_wave <= GameManager.get_wave_count():
		_update_wave_preview(next_wave, "下一波")
		set_can_call_next_wave(true)
		show_message("第 %d 波已清理，准备：%s（可点击催下一波）" % [wave_num, GameManager.get_wave_preview_text(next_wave, "下一波")])
	else:
		wave_preview_label.text = "所有波次已清理"
		show_message("第 %d 波已清理" % wave_num)

func _on_wave_countdown(seconds_left: int) -> void:
	var next_wave := GameManager.current_wave + 1
	_update_wave_preview(next_wave, "下一波")
	show_message("%s，%d 秒后开始" % [GameManager.get_wave_preview_text(next_wave, "下一波"), seconds_left])

func _on_game_over() -> void:
	show_result_screen(false)

func _on_game_won() -> void:
	show_result_screen(true)

func _on_tower_selection_changed(_tower_type: String) -> void:
	_update_selected_tower_text()
	_update_tower_buttons()

func _on_level_changed(_level_index: int, _level_name: String) -> void:
	_update_level_text()
	_update_wave_text(0)
	_update_wave_preview(1, "下一波")
	_update_selected_tower_text()
	_selected_tower_for_actions = null
	_update_action_buttons()

func _update_level_text() -> void:
	level_label.text = "关卡: %d/%d %s · %s" % [
		GameManager.current_level_index + 1,
		GameManager.get_level_count(),
		GameManager.get_current_level_name(),
		GameManager.get_difficulty_name(),
	]

func _update_wave_text(wave_num: int) -> void:
	wave_label.text = "波次: %d/%d" % [wave_num, GameManager.get_wave_count()]

func _update_wave_preview(wave_num: int, prefix: String) -> void:
	wave_preview_label.text = GameManager.get_wave_preview_text(wave_num, prefix)

func _update_enemy_legend() -> void:
	enemy_legend_label.text = "僵尸：普通 | 疾跑 | 铁桶"

func _update_selected_tower_text() -> void:
	_selected_tower_for_actions = null
	var config := GameManager.get_tower_config(GameManager.selected_tower_type)
	info_label.text = "当前: %s | 费用: %d | %s" % [
		String(config["name"]),
		GameManager.get_tower_cost(GameManager.selected_tower_type),
		GameManager.get_tower_stats_text(GameManager.selected_tower_type),
	]
	_update_tower_buttons()
	_update_action_buttons()

func _update_tower_buttons() -> void:
	if _tower_buttons.is_empty():
		return

	for tower_type in _tower_buttons.keys():
		var button: Button = _tower_buttons[tower_type]
		var config := GameManager.get_tower_config(tower_type)
		var cost := GameManager.get_tower_cost(tower_type)
		var is_selected: bool = tower_type == GameManager.selected_tower_type
		var prefix := "✓ " if is_selected else ""
		button.text = "%s%s %d" % [prefix, String(config["name"]), cost]
		button.disabled = not is_selected and not GameManager.can_afford(cost)

func show_tower_details(tower: Tower) -> void:
	if not tower or not is_instance_valid(tower):
		_update_selected_tower_text()
		return

	_selected_tower_for_actions = tower
	var upgrade_text := "满级"
	if tower.can_upgrade():
		upgrade_text = "升级: %d 阳光" % tower.get_upgrade_cost()

	info_label.text = "选中: %s | %s | 目标: %s | 铲除返还: %d 阳光" % [
		tower.get_display_name(),
		tower.get_stats_text() + " | " + upgrade_text,
		tower.get_target_priority_label(),
		tower.get_sell_value(),
	]
	_update_action_buttons()

func _update_action_buttons() -> void:
	var has_tower := _selected_tower_for_actions != null and is_instance_valid(_selected_tower_for_actions)
	if not has_tower:
		priority_button.text = "目标"
		priority_button.disabled = true
		upgrade_button.text = "升级"
		upgrade_button.disabled = true
		sell_button.text = "铲除"
		sell_button.disabled = true
		return

	priority_button.text = "目标: %s" % _selected_tower_for_actions.get_target_priority_label()
	priority_button.disabled = false

	var can_upgrade := _selected_tower_for_actions.can_upgrade()
	var upgrade_cost := _selected_tower_for_actions.get_upgrade_cost()
	upgrade_button.text = "升级 %d" % upgrade_cost if can_upgrade else "已满级"
	upgrade_button.disabled = not can_upgrade or not GameManager.can_afford(upgrade_cost)
	sell_button.text = "铲除 %d" % _selected_tower_for_actions.get_sell_value()
	sell_button.disabled = false

func set_start_wave_available(available: bool) -> void:
	start_wave_button.disabled = not available
	start_wave_button.text = "开始" if available else "进行中"
	pause_button.disabled = available

## 波间窗口：把"开始"按钮复用为"催下一波"
func set_can_call_next_wave(can: bool) -> void:
	start_wave_button.disabled = not can
	start_wave_button.text = "催下一波" if can else "进行中"

func set_pause_button_paused(paused: bool) -> void:
	pause_button.text = "继续" if paused else "暂停"

func show_message(text: String, persistent: bool = false) -> void:
	message_label.text = text
	if persistent:
		return

	if not is_inside_tree():
		return
	var tree := get_tree()
	await tree.create_timer(MESSAGE_TIME).timeout
	if not is_inside_tree():
		return
	if message_label.text == text:
		message_label.text = ""

func show_start_screen() -> void:
	overlay.visible = true
	start_panel.visible = true
	pause_panel.visible = false
	level_select_panel.visible = false
	result_panel.visible = false

func hide_overlay() -> void:
	overlay.visible = false
	start_panel.visible = false
	pause_panel.visible = false
	level_select_panel.visible = false
	result_panel.visible = false

func show_pause_screen() -> void:
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = true
	level_select_panel.visible = false
	result_panel.visible = false
	set_pause_button_paused(true)

func hide_pause_screen() -> void:
	if pause_panel.visible:
		hide_overlay()
	set_pause_button_paused(false)

func show_result_screen(won: bool) -> void:
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = false
	level_select_panel.visible = false
	result_panel.visible = true
	pause_button.disabled = true
	set_pause_button_paused(false)
	result_title.text = "胜利" if won else "失败"
	next_level_button.visible = won and GameManager.has_next_level()
	result_stats.text = "关卡: %s\n到达波次: %d\n击退僵尸: %d\n漏掉僵尸: %d\n剩余生命: %d\n剩余阳光: %d" % [
		GameManager.get_current_level_name(),
		GameManager.current_wave,
		GameManager.enemies_killed,
		GameManager.enemies_leaked,
		GameManager.lives,
		GameManager.gold,
	]

func _on_start_pressed() -> void:
	hide_overlay()
	_main._start_game()

func _on_start_wave_pressed() -> void:
	_main._on_start_wave_button()

func _on_tower_button_pressed(tower_type: String) -> void:
	_main._select_tower_type(tower_type)

func _on_priority_pressed() -> void:
	_main._cycle_selected_tower_priority()

func _on_upgrade_pressed() -> void:
	_main._upgrade_selected_tower()

func _on_sell_pressed() -> void:
	_main._sell_selected_tower()

func _on_pause_pressed() -> void:
	_main._toggle_pause()

func _on_speed_pressed() -> void:
	GameManager.cycle_game_speed()

func _on_volume_changed(value: float) -> void:
	GameManager.set_volume(value)

func _on_mute_pressed() -> void:
	GameManager.toggle_mute()

func _on_audio_settings_changed(volume: float, muted: bool) -> void:
	volume_slider.set_value_no_signal(volume)
	mute_button.text = "音效: 关" if muted else "音效: 开"

func _on_game_speed_changed(speed: float) -> void:
	_update_speed_button(speed)

func _update_speed_button(speed: float) -> void:
	speed_button.text = "速度 x%d" % int(speed)

func _on_level_select_pressed() -> void:
	_pending_level_index = GameManager.current_level_index
	_update_level_select_text()
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = false
	level_select_panel.visible = true
	result_panel.visible = false

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide_overlay()
	set_pause_button_paused(false)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	_main._restart_game()

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	if GameManager.advance_to_next_level():
		_main._reload_scene_for_level()

func _on_prev_level_pressed() -> void:
	_pending_level_index = max(_pending_level_index - 1, 0)
	_update_level_select_text()

func _on_next_select_level_pressed() -> void:
	_pending_level_index = min(_pending_level_index + 1, GameManager.get_level_count() - 1)
	_update_level_select_text()

func _on_confirm_level_pressed() -> void:
	get_tree().paused = false
	if GameManager.set_level(_pending_level_index):
		_main._reload_scene_for_level()

func _on_cancel_level_pressed() -> void:
	hide_overlay()

func _on_difficulty_pressed() -> void:
	GameManager.cycle_difficulty()

func _on_difficulty_changed(_index: int, _difficulty_name: String) -> void:
	# 难度变化时刷新选关面板与顶部关卡标签
	_update_level_select_text()
	_update_level_text()

func _update_level_select_text() -> void:
	var levels: Array = GameManager.levels
	if levels.is_empty():
		level_select_title.text = "没有关卡"
		level_select_description.text = ""
		return

	var level: Dictionary = levels[_pending_level_index]
	var unlocked := GameManager.is_level_unlocked(_pending_level_index)
	level_select_title.text = "关卡 %d/%d: %s%s" % [
		_pending_level_index + 1,
		GameManager.get_level_count(),
		String(level.get("name", "未命名关卡")),
		"" if unlocked else "（未解锁）",
	]
	var lock_hint := "" if unlocked else "\n通关上一关后解锁"
	# 描述里显示按当前难度换算后的初始阳光/生命
	var diff := GameManager.get_difficulty()
	var shown_gold := int(round(float(level.get("starting_gold", 0)) * float(diff["gold_mult"])))
	var shown_lives := maxi(1, int(round(float(level.get("starting_lives", 0)) * float(diff["lives_mult"]))))
	level_select_description.text = "%s\n初始阳光: %d | 初始生命: %d | 波次: %d%s" % [
		String(level.get("description", "")),
		shown_gold,
		shown_lives,
		(level.get("waves", []) as Array).size(),
		lock_hint,
	]
	difficulty_button.text = "难度: %s" % GameManager.get_difficulty_name()
	prev_level_button.disabled = _pending_level_index <= 0
	next_select_level_button.disabled = _pending_level_index >= GameManager.get_level_count() - 1
	confirm_level_button.disabled = not unlocked
	confirm_level_button.text = "使用此关卡" if unlocked else "未解锁"
