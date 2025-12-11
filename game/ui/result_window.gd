extends CanvasLayer

signal restart_requested
signal quit_requested


@onready var lbl_title = $PanelContainer/MarginContainer/VBoxContainer/LblTitle
@onready var lbl_message = $PanelContainer/MarginContainer/VBoxContainer/LblMessage
@onready var btn_restart = $PanelContainer/MarginContainer/VBoxContainer/BtnRestart
@onready var btn_quit = $PanelContainer/MarginContainer/VBoxContainer/BtnQuit

func _ready():
	visible = false
	btn_restart.pressed.connect(func(): restart_requested.emit())
	btn_quit.pressed.connect(func(): get_tree().quit())

func show_result(is_victory: bool, message: String = ""):
	visible = true
	
	if is_victory:
		lbl_title.text = "MISSION ACCOMPLISHED"
		lbl_title.label_settings.font_color = Color.GOLD
		if message == "": message = "你成功抵达了目的地。"
	else:
		lbl_title.text = "MISSION FAILED"
		lbl_title.label_settings.font_color = Color.RED
		if message == "": message = "你的旅途在这里终结了。"
		
	lbl_message.text = message
