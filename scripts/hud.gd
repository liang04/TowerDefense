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
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel

## ---- 生命周期 ----
func _ready() -> void:
	# 连接 GameManager 信号
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.game_over.connect(_on_game_over)

	# 初始化显示
	_update_all()

## ---- 更新方法 ----

func _update_all() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	lives_label.text = "生命: %d" % GameManager.lives
	wave_label.text = "波次: 0"
	message_label.text = "左键放塔（%d 金币），右键或空格开始，R 重开" % GameManager.TOWER_COST

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "金币: %d" % new_gold

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "生命: %d" % new_lives

func _on_wave_started(wave_num: int) -> void:
	wave_label.text = "波次: %d" % wave_num
	show_message("第 %d 波来袭！" % wave_num)

func _on_wave_completed(wave_num: int) -> void:
	show_message("第 %d 波已清理，下一波即将开始" % wave_num)

func _on_game_over() -> void:
	show_message("游戏结束！按 R 重开", true)

func show_message(text: String, persistent: bool = false) -> void:
	message_label.text = text
	if persistent:
		return

	await get_tree().create_timer(MESSAGE_TIME).timeout
	if message_label.text == text:
		message_label.text = ""
