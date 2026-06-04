## HUD 界面脚本
## 显示金币、生命、波次信息，处理塔选择
extends CanvasLayer

## ---- 常量 ----
const MESSAGE_TIME := 3.0

## ---- 状态 ----
var selected_tower_type: String = "basic"

## ---- 节点引用 ----
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var lives_label: Label = $MarginContainer/VBoxContainer/TopBar/LivesLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopBar/WaveLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/TopBar/LevelLabel
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
@onready var resume_button: Button = $Overlay/PausePanel/PauseBox/ResumeButton
@onready var restart_pause_button: Button = $Overlay/PausePanel/PauseBox/RestartPauseButton
@onready var prev_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectControls/PrevLevelButton
@onready var next_select_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectControls/NextSelectLevelButton
@onready var confirm_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/ConfirmLevelButton
@onready var cancel_level_button: Button = $Overlay/LevelSelectPanel/LevelSelectBox/CancelLevelButton
@onready var level_select_title: Label = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectTitle
@onready var level_select_description: Label = $Overlay/LevelSelectPanel/LevelSelectBox/LevelSelectDescription
@onready var next_level_button: Button = $Overlay/ResultPanel/ResultBox/NextLevelButton
@onready var restart_result_button: Button = $Overlay/ResultPanel/ResultBox/RestartResultButton
@onready var arrow_tower_button: Button = $MarginContainer/VBoxContainer/TowerBar/ArrowTowerButton
@onready var cannon_tower_button: Button = $MarginContainer/VBoxContainer/TowerBar/CannonTowerButton
@onready var frost_tower_button: Button = $MarginContainer/VBoxContainer/TowerBar/FrostTowerButton
@onready var upgrade_button: Button = $MarginContainer/VBoxContainer/ActionBar/UpgradeButton
@onready var sell_button: Button = $MarginContainer/VBoxContainer/ActionBar/SellButton

var _pending_level_index: int = 0
var _tower_buttons: Dictionary = {}
var _selected_tower_for_actions: Node = null

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

	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_pause_button.pressed.connect(_on_restart_pressed)
	prev_level_button.pressed.connect(_on_prev_level_pressed)
	next_select_level_button.pressed.connect(_on_next_select_level_pressed)
	confirm_level_button.pressed.connect(_on_confirm_level_pressed)
	cancel_level_button.pressed.connect(_on_cancel_level_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)
	restart_result_button.pressed.connect(_on_restart_pressed)
	arrow_tower_button.pressed.connect(_on_tower_button_pressed.bind("arrow"))
	cannon_tower_button.pressed.connect(_on_tower_button_pressed.bind("cannon"))
	frost_tower_button.pressed.connect(_on_tower_button_pressed.bind("frost"))
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	_tower_buttons = {
		"arrow": arrow_tower_button,
		"cannon": cannon_tower_button,
		"frost": frost_tower_button,
	}

	# 初始化显示
	_update_all()
	hide_overlay()

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
	gold_label.text = "金币: %d" % GameManager.gold
	lives_label.text = "生命: %d" % GameManager.lives
	wave_label.text = "波次: 0"
	_update_level_text()
	_update_selected_tower_text()
	message_label.text = "点击按钮或 1/2/3 选塔，左键建造或选中塔，可点按钮升级/出售"

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "金币: %d" % new_gold
	_update_tower_buttons()
	_update_action_buttons()

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "生命: %d" % new_lives

func _on_wave_started(wave_num: int) -> void:
	wave_label.text = "波次: %d" % wave_num
	show_message("第 %d 波来袭！" % wave_num)

func _on_wave_completed(wave_num: int) -> void:
	show_message("第 %d 波已清理，下一波即将开始" % wave_num)

func _on_wave_countdown(seconds_left: int) -> void:
	show_message("下一波 %d 秒后开始" % seconds_left)

func _on_game_over() -> void:
	show_result_screen(false)

func _on_game_won() -> void:
	show_result_screen(true)

func _on_tower_selection_changed(_tower_type: String) -> void:
	_update_selected_tower_text()
	_update_tower_buttons()

func _on_level_changed(_level_index: int, _level_name: String) -> void:
	_update_level_text()
	wave_label.text = "波次: 0"
	_update_selected_tower_text()
	_selected_tower_for_actions = null
	_update_action_buttons()

func _update_level_text() -> void:
	level_label.text = "关卡: %d/%d %s" % [
		GameManager.current_level_index + 1,
		GameManager.get_level_count(),
		GameManager.get_current_level_name(),
	]

func _update_selected_tower_text() -> void:
	_selected_tower_for_actions = null
	var config := GameManager.get_tower_config(GameManager.selected_tower_type)
	info_label.text = "当前: %s | 费用: %d | %s" % [
		String(config["name"]),
		GameManager.get_tower_cost(GameManager.selected_tower_type),
		String(config["description"]),
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

func show_tower_details(tower: Node) -> void:
	if not tower or not is_instance_valid(tower):
		_update_selected_tower_text()
		return

	_selected_tower_for_actions = tower
	var upgrade_text := "满级"
	if tower.call("can_upgrade"):
		upgrade_text = "升级: %d 金币" % int(tower.call("get_upgrade_cost"))

	info_label.text = "选中: %s | %s | 出售: %d 金币" % [
		String(tower.call("get_display_name")),
		upgrade_text,
		int(tower.call("get_sell_value")),
	]
	_update_action_buttons()

func _update_action_buttons() -> void:
	var has_tower := _selected_tower_for_actions != null and is_instance_valid(_selected_tower_for_actions)
	if not has_tower:
		upgrade_button.text = "升级"
		upgrade_button.disabled = true
		sell_button.text = "出售"
		sell_button.disabled = true
		return

	var can_upgrade: bool = _selected_tower_for_actions.call("can_upgrade")
	var upgrade_cost := int(_selected_tower_for_actions.call("get_upgrade_cost"))
	upgrade_button.text = "升级 %d" % upgrade_cost if can_upgrade else "已满级"
	upgrade_button.disabled = not can_upgrade or not GameManager.can_afford(upgrade_cost)
	sell_button.text = "出售 %d" % int(_selected_tower_for_actions.call("get_sell_value"))
	sell_button.disabled = false

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

func hide_pause_screen() -> void:
	if pause_panel.visible:
		hide_overlay()

func show_result_screen(won: bool) -> void:
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = false
	level_select_panel.visible = false
	result_panel.visible = true
	result_title.text = "胜利" if won else "失败"
	next_level_button.visible = won and GameManager.has_next_level()
	result_stats.text = "关卡: %s\n到达波次: %d\n击杀敌人: %d\n漏掉敌人: %d\n剩余生命: %d\n剩余金币: %d" % [
		GameManager.get_current_level_name(),
		GameManager.current_wave,
		GameManager.enemies_killed,
		GameManager.enemies_leaked,
		GameManager.lives,
		GameManager.gold,
	]

func _on_start_pressed() -> void:
	hide_overlay()
	get_parent().call("_start_game")

func _on_tower_button_pressed(tower_type: String) -> void:
	get_parent().call("_select_tower_type", tower_type)

func _on_upgrade_pressed() -> void:
	get_parent().call("_upgrade_selected_tower")

func _on_sell_pressed() -> void:
	get_parent().call("_sell_selected_tower")

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

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_parent().call("_restart_game")

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	if GameManager.advance_to_next_level():
		get_parent().call("_reload_scene_for_level")

func _on_prev_level_pressed() -> void:
	_pending_level_index = max(_pending_level_index - 1, 0)
	_update_level_select_text()

func _on_next_select_level_pressed() -> void:
	_pending_level_index = min(_pending_level_index + 1, GameManager.get_level_count() - 1)
	_update_level_select_text()

func _on_confirm_level_pressed() -> void:
	get_tree().paused = false
	if GameManager.set_level(_pending_level_index):
		get_parent().call("_reload_scene_for_level")

func _on_cancel_level_pressed() -> void:
	hide_overlay()

func _update_level_select_text() -> void:
	var levels: Array = GameManager.levels
	if levels.is_empty():
		level_select_title.text = "没有关卡"
		level_select_description.text = ""
		return

	var level: Dictionary = levels[_pending_level_index]
	level_select_title.text = "关卡 %d/%d: %s" % [
		_pending_level_index + 1,
		GameManager.get_level_count(),
		String(level.get("name", "未命名关卡")),
	]
	level_select_description.text = "%s\n初始金币: %d | 初始生命: %d | 波次: %d" % [
		String(level.get("description", "")),
		int(level.get("starting_gold", 0)),
		int(level.get("starting_lives", 0)),
		(level.get("waves", []) as Array).size(),
	]
	prev_level_button.disabled = _pending_level_index <= 0
	next_select_level_button.disabled = _pending_level_index >= GameManager.get_level_count() - 1
