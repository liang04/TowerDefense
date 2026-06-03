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
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var overlay: Control = $Overlay
@onready var start_panel: PanelContainer = $Overlay/StartPanel
@onready var pause_panel: PanelContainer = $Overlay/PausePanel
@onready var result_panel: PanelContainer = $Overlay/ResultPanel
@onready var result_title: Label = $Overlay/ResultPanel/ResultBox/ResultTitle
@onready var result_stats: Label = $Overlay/ResultPanel/ResultBox/ResultStats
@onready var start_button: Button = $Overlay/StartPanel/StartBox/StartButton
@onready var resume_button: Button = $Overlay/PausePanel/PauseBox/ResumeButton
@onready var restart_pause_button: Button = $Overlay/PausePanel/PauseBox/RestartPauseButton
@onready var restart_result_button: Button = $Overlay/ResultPanel/ResultBox/RestartResultButton

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

	start_button.pressed.connect(_on_start_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_pause_button.pressed.connect(_on_restart_pressed)
	restart_result_button.pressed.connect(_on_restart_pressed)

	# 初始化显示
	_update_all()
	hide_overlay()

func _make_gameplay_hud_click_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_gameplay_hud_click_through(child)

## ---- 更新方法 ----

func _update_all() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	lives_label.text = "生命: %d" % GameManager.lives
	wave_label.text = "波次: 0"
	_update_selected_tower_text()
	message_label.text = "1/2/3 选塔，左键建造或选中塔，U 升级，X 出售，右键/空格开始"

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "金币: %d" % new_gold

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

func _update_selected_tower_text() -> void:
	var config := GameManager.get_tower_config(GameManager.selected_tower_type)
	info_label.text = "当前: %s | 费用: %d | %s" % [
		String(config["name"]),
		GameManager.get_tower_cost(GameManager.selected_tower_type),
		String(config["description"]),
	]

func show_tower_details(tower: Node) -> void:
	if not tower or not is_instance_valid(tower):
		_update_selected_tower_text()
		return

	var upgrade_text := "满级"
	if tower.call("can_upgrade"):
		upgrade_text = "升级: %d 金币" % int(tower.call("get_upgrade_cost"))

	info_label.text = "选中: %s | %s | 出售: %d 金币" % [
		String(tower.call("get_display_name")),
		upgrade_text,
		int(tower.call("get_sell_value")),
	]

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
	result_panel.visible = false

func hide_overlay() -> void:
	overlay.visible = false
	start_panel.visible = false
	pause_panel.visible = false
	result_panel.visible = false

func show_pause_screen() -> void:
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = true
	result_panel.visible = false

func hide_pause_screen() -> void:
	if pause_panel.visible:
		hide_overlay()

func show_result_screen(won: bool) -> void:
	overlay.visible = true
	start_panel.visible = false
	pause_panel.visible = false
	result_panel.visible = true
	result_title.text = "胜利" if won else "失败"
	result_stats.text = "到达波次: %d\n击杀敌人: %d\n漏掉敌人: %d\n剩余生命: %d\n剩余金币: %d" % [
		GameManager.current_wave,
		GameManager.enemies_killed,
		GameManager.enemies_leaked,
		GameManager.lives,
		GameManager.gold,
	]

func _on_start_pressed() -> void:
	hide_overlay()
	get_parent().call("_start_game")

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide_overlay()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_parent().call("_restart_game")
