# res://game/ui/event_window.gd
class_name EventWindow
extends CanvasLayer

# 定义信号：玩家做出了选择
# option_index: 0 代表 A, 1 代表 B...
signal option_selected(option_index: int)

@onready var lbl_title = $PanelContainer/MarginContainer/VBoxContainer/LblTitle
@onready var txt_desc = $PanelContainer/MarginContainer/VBoxContainer/TxtDescription
@onready var img_event = $PanelContainer/MarginContainer/VBoxContainer/ImgEvent
@onready var btn_container = $PanelContainer/MarginContainer/VBoxContainer/BtnContainer

# 当前处理的事件数据
var current_event: GameEvent

func _ready():
	visible = false

# 公开方法：显示事件
func show_event(event: GameEvent):
	current_event = event
	
	# 1. 填充文本
	lbl_title.text = event.title
	txt_desc.text = event.description
	
	# 2. 填充图片 (如果有)
	if event.image:
		img_event.texture = event.image
		img_event.visible = true
	else:
		img_event.visible = false
	
	# 3. 动态生成按钮
	_generate_buttons(event)
	
	# 4. 显示窗口
	visible = true

func _generate_buttons(event: GameEvent):
	# 先清空旧按钮
	for child in btn_container.get_children():
		child.queue_free()
	
	# 选项 A (必须有)
	_add_button(event.option_a_text, 0, event.option_a_cost_ap)
	
	# 选项 B (可能有)
	if event.option_b_text != "":
		_add_button(event.option_b_text, 1, event.option_b_cost_ap)

func _add_button(text: String, index: int, cost: int):
	var btn = Button.new()
	
	# 拼接文本： "搜寻废墟 (-2 AP)"
	var display_text = text
	if cost > 0:
		display_text += " (-%d AP)" % cost
	
	btn.text = display_text
	
	# 连接点击信号
	btn.pressed.connect(func(): _on_button_pressed(index))
	
	# 添加到容器
	btn_container.add_child(btn)

func _on_button_pressed(index: int):
	# 关闭窗口
	visible = false
	# 发送信号给 Main
	option_selected.emit(index)
