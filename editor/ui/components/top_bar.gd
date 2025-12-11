# res://view/ui/components/top_bar.gd
extends PanelContainer

@onready var lbl_path = $MarginContainer/HBoxContainer/LblBreadcrumbs
@onready var btn_back = $MarginContainer/HBoxContainer/BtnBack
@onready var btn_system = $MarginContainer/HBoxContainer/BtnSystem

func _ready():
	# 发送请求
	btn_back.pressed.connect(func(): SignalBus.request_navigate_back.emit())
	btn_system.pressed.connect(func(): SignalBus.request_system_menu.emit())
	
	# ✅ 接收信号 (拼写必须和 signal_bus.gd 里的一模一样)
	SignalBus.breadcrumbs_updated.connect(_update_labels)

func _update_labels(names: Array):
	# 注意：Array 类型转换在连接时通常自动处理，但在参数里写 Array[String] 可能会有类型兼容警告，写 Array 最稳
	lbl_path.text = " > ".join(names)
	btn_back.disabled = names.size() <= 1
