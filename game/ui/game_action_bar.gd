extends PanelContainer

@onready var btn_camp = $MarginContainer/HBoxContainer/BtnCamp

func _ready():
	# 连接信号到总线
	btn_camp.pressed.connect(func(): SignalBus.request_camp.emit())
