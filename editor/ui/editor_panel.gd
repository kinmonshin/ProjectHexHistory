# res://view/ui/editor_panel.gd
class_name EditorPanel
extends PanelContainer

# 绑定 UI 控件
@onready var input_name: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/InputName
@onready var option_type: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/OptionType
@onready var input_desc: TextEdit = $PanelContainer/MarginContainer/VBoxContainer/InputDesc
@onready var btn_color_pick: ColorPickerButton = $PanelContainer/MarginContainer/VBoxContainer/BtnColorPick

# 当前正在编辑的数据引用
var current_data: RegionData

signal data_modified # 新信号

func _ready():
	# 初始化下拉菜单
	option_type.clear()
	# 对应 RegionData.Type 枚举的顺序
	var types = [
		"TYPE_WORLD", "TYPE_CONTINENT", "TYPE_NATION", 
		"TYPE_PROVINCE", "TYPE_CITY", "TYPE_HEXCELL"
	]
	# 注意：option_type.add_item 存的是显示文本
	# 我们在 add 之前调用 tr()
	for t in types:
		option_type.add_item(tr(t)) # tr() 是 Godot 全局翻译函数
	
	# 绑定 UI 事件
	input_name.text_changed.connect(_on_name_changed)
	input_desc.text_changed.connect(_on_desc_changed)
	option_type.item_selected.connect(_on_type_selected)
	btn_color_pick.color_changed.connect(_on_color_changed) # 监听颜色改变
	
	SignalBus.selection_updated.connect(_on_selection_updated)
	SignalBus.navigation_view_changed.connect(_on_view_changed)

# --- 外部调用接口 ---

# 当 ViewStackController 切换视图时调用此函数
func bind_data(data: RegionData):
	current_data = data
	refresh_ui()

func _on_selection_updated(items: Array):
	if items.size() > 0:
		visible = true
		bind_data(items[0])
				# 动画效果 (可选)：从右侧滑入
		# var tween = create_tween()
	else:
		visible = false # 没选中就隐藏

func _on_view_changed(new_region: RegionData):
	# 当切换地图层级时，默认显示当前地图本身的属性
	# 或者选择隐藏面板，等待用户点击
	bind_data(new_region)
	visible = true


# --- 内部逻辑 ---

func refresh_ui():
	if not current_data:
		return
	
	# 避免在设置 UI 时触发 changed 信号导致循环更新
	# 这里使用 set_text_no_signal 如果有的话，或者简单设置即可，
	# 因为 text_changed 只有用户输入才触发，代码设置通常不触发（取决于Godot版本，通常安全）
	input_name.text = current_data.name
	input_desc.text = current_data.description
	option_type.selected = current_data.type
	
	# 设置颜色按钮的显示颜色
	btn_color_pick.color = current_data.map_color

# --- 信号回调 ---

func _on_name_changed(new_text: String):
	if current_data:
		current_data.name = new_text

func _on_desc_changed():
	if current_data:
		current_data.description = input_desc.text

func _on_type_selected(index: int):
	if current_data:
		current_data.type = index as RegionData.Type

func _on_view_stack_controller_view_changed(current_region: RegionData) -> void:
	pass # Replace with function body.

# 回调函数
func _on_color_changed(new_color: Color):
	if current_data:
		current_data.map_color = new_color
		data_modified.emit() # 发射信号

func _on_lang_changed(index: int):
	if index == 0:
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("zh")
	_refresh_dynamic_text() # 刷新 EditorPanel 自己的 Type 下拉框
	# ✅ 修改：通过总线通知全世界 (LensBar 会收到)
	SignalBus.locale_changed.emit()

func _refresh_dynamic_text():
	# 重新填充 Type 下拉框
	option_type.clear()
	var types = ["TYPE_WORLD", "TYPE_CONTINENT", "TYPE_NATION", "TYPE_PROVINCE", "TYPE_CITY", "TYPE_HEXCELL"]
	for t in types:
		option_type.add_item(tr(t))
	# 恢复之前的选中状态
	if current_data:
		option_type.selected = current_data.type
