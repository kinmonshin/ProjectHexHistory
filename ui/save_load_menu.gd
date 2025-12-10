class_name SaveLoadMenu
extends CanvasLayer

@onready var file_list = $PanelContainer/HBoxContainer/FileList
@onready var input_name = $PanelContainer/HBoxContainer/VBoxContainer/InputName
@onready var btn_save = $PanelContainer/HBoxContainer/VBoxContainer/BtnSave
@onready var btn_load = $PanelContainer/HBoxContainer/VBoxContainer/BtnLoad
@onready var btn_delete = $PanelContainer/HBoxContainer/VBoxContainer/BtnDelete
@onready var btn_close = $PanelContainer/HBoxContainer/VBoxContainer/BtnClose
@onready var confirm_dialog = $ConfirmOverwrite
@onready var btn_lang = $PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/BtnLang

func _ready():
	# 初始隐藏
	visible = false
	
	# 连接信号
	btn_close.pressed.connect(close_menu)
	btn_load.pressed.connect(_on_load_pressed)
	btn_delete.pressed.connect(_on_delete_pressed)
	file_list.item_selected.connect(_on_file_selected)
	file_list.item_activated.connect(_on_file_double_clicked) # 双击
	
	btn_save.pressed.connect(_on_save_pressed)
	if confirm_dialog:
		confirm_dialog.confirmed.connect(_perform_save)
	
	_init_language_options()
	# 2. 连接信号
	btn_lang.item_selected.connect(_on_lang_changed)
	# 3. 监听语言变化信号 (用于刷新菜单自己的文本)
	SignalBus.locale_changed.connect(_refresh_menu_text)

func _init_language_options():
	btn_lang.clear()
	# 添加选项 (ID 0 = English, ID 1 = 中文)
	btn_lang.add_item("English", 0)
	btn_lang.add_item("中文", 1)
	
	# 根据当前系统语言设置选中项
	var current_locale = TranslationServer.get_locale()
	if current_locale.begins_with("zh"):
		btn_lang.selected = 1
	else:
		btn_lang.selected = 0

func _on_lang_changed(index: int):
	# 1. 切换引擎语言
	if index == 0:
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("zh")
	
	# 2. 通知全世界 (包括自己)
	SignalBus.locale_changed.emit()

# 刷新菜单自己的动态文本 (如果有的话)
# 注意：Godot 4 对于 Inspector 设置的 Key 会自动刷新，
# 但如果是代码生成的文本（比如列表里的时间格式），可能需要手动刷新。
# 这里主要是个保险。
func _refresh_menu_text():
	# 刷新文件列表（因为里面的 "刚刚", "昨天" 等时间描述可能需要翻译）
	refresh_list()

# 打开菜单
func open_menu():
	refresh_list()
	visible = true
	# 可以在这里暂停游戏逻辑：get_tree().paused = true

# 关闭菜单
func close_menu():
	visible = false
	# get_tree().paused = false

# 刷新文件列表
func refresh_list():
	file_list.clear()
	var saves = SessionManager.get_save_list()
	
	for save in saves:
		# 显示格式: "MyWorld.tres (2023-10-01 12:00)"
		var display_text = "%s\n%s" % [save.filename, save.time_str]
		file_list.add_item(display_text)
		# 把文件名存到 metadata 里方便取用
		file_list.set_item_metadata(file_list.item_count - 1, save.filename)

# 选中文件
func _on_file_selected(index):
	var filename = file_list.get_item_metadata(index)
	input_name.text = filename.replace(".tres", "") # 填入输入框

# 双击文件 -> 直接读取
func _on_file_double_clicked(index):
	_on_load_pressed()

# 点击“保存”按钮的逻辑
func _on_save_pressed():
	var name = input_name.text.strip_edges()
	
	if name == "":
		print("文件名为空，无法保存")
		return
	
	var filename = name + ".tres"
	
	# 检查是否覆盖
	var saves = SessionManager.get_save_list()
	for s in saves:
		if s.filename == filename:
			# 发现重名，弹出确认框
			if confirm_dialog:
				confirm_dialog.dialog_text = "Overwrite existing save file?"
				confirm_dialog.popup_centered()
			return
			
	# 没有重名，直接保存
	_perform_save()

# 执行实际保存
func _perform_save():
	var name = input_name.text.strip_edges()
	print("菜单请求保存: ", name)
	
	# 调用 SessionManager 存盘
	SessionManager.save_world_as(name)
	
	# 刷新列表显示新存档
	refresh_list()

func _on_load_pressed():
	if not file_list.is_anything_selected(): return
	var idx = file_list.get_selected_items()[0]
	var filename = file_list.get_item_metadata(idx)
	
	SessionManager.load_world(SessionManager.SAVE_DIR + filename)
	close_menu()

func _on_delete_pressed():
	if not file_list.is_anything_selected(): return
	var idx = file_list.get_selected_items()[0]
	var filename = file_list.get_item_metadata(idx)
	
	SessionManager.delete_save(filename)
	input_name.text = "" # 清空输入框
	refresh_list()
	
	# --- 新增：监听键盘输入 ---
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		# 如果菜单当前是显示的 -> 关闭它
		if visible:
			close_menu()
			# 标记输入已处理，防止向后传递（比如取消了地图上的选择）
			get_viewport().set_input_as_handled()
			
		# 如果菜单当前是隐藏的 -> 打开它
		else:
			open_menu()
			get_viewport().set_input_as_handled()
