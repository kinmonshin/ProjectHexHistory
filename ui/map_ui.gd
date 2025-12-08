# res://view/ui/map_ui.gd
class_name MapUI
extends CanvasLayer

signal back_requested
signal create_region_requested # 新信号
signal view_mode_changed(mode_id: int)
signal generate_requested # 新信号
signal river_mode_toggled(is_on: bool) # 新信号
signal move_to_requested(target_index: int) # 发出信号：移动到第几个子节点

# 新增：工具切换信号
signal tool_changed(tool_name: String) # "select" or "paint"
signal terrain_selected(terrain_id: int) # 新信号

@onready var lbl_path = $Panel/HBoxContainer/LblPath
@onready var btn_back = $Panel/HBoxContainer/BtnBack
@onready var btn_tool_select = $Panel/HBoxContainer/BtnToolSelect
@onready var btn_tool_paint = $Panel/HBoxContainer/BtnToolPaint
@onready var btn_create = $Panel/HBoxContainer/BtnCreateRegion
@onready var option_terrain = $Panel/HBoxContainer/OptionTerrain 
@onready var option_view_mode = $Panel/HBoxContainer/OptionViewMode
@onready var btn_generate = $Panel/HBoxContainer/BtnGenerate
@onready var btn_river_mode = $Panel/HBoxContainer/BtnRiverMode

@onready var btn_move_to = $Panel/HBoxContainer/BtnMoveTo # 路径自调
@onready var move_dialog = $MoveDialog
@onready var option_target = $MoveDialog/OptionTargetRegion

func _ready():
	btn_back.pressed.connect(func(): back_requested.emit())
	
	# 连接工具按钮信号
	btn_tool_select.toggled.connect(_on_tool_toggled.bind("select"))
	btn_tool_paint.toggled.connect(_on_tool_toggled.bind("paint"))
	btn_create.pressed.connect(func(): create_region_requested.emit())
	btn_tool_select.button_pressed = true
	
	# 初始化下拉框 (如果没有在编辑器里手动加)
	if option_terrain.item_count == 0:
		var types = ["Ocean", "Coast", "Plains", "Forest", "Hills", "Mountain", "Desert", "Snow"]
		for i in range(types.size()):
			option_terrain.add_item(types[i], i)
	
	option_terrain.item_selected.connect(func(idx): terrain_selected.emit(idx))
	option_view_mode.item_selected.connect(func(idx): view_mode_changed.emit(idx))
	option_view_mode.item_selected.connect(func(idx): view_mode_changed.emit(idx))
	btn_generate.pressed.connect(func(): generate_requested.emit())
	btn_river_mode.toggled.connect(func(pressed): river_mode_toggled.emit(pressed))
	btn_move_to.pressed.connect(_on_btn_move_pressed)
	move_dialog.confirmed.connect(_on_move_confirmed)
	
	# 初始化地形下拉框
	_init_terrain_options()
	
	_init_view_mode_options() # 新增初始化函数

# 封装成函数，方便语言切换时刷新
func _init_terrain_options():
	option_terrain.clear()
	
	# 定义地形类型对应的 Key 列表
	# 顺序必须严格对应 HexCell.TerrainType Enum 的顺序 (0, 1, 2...)
	var terrain_keys = [
		"TERRAIN_OCEAN", 
		"TERRAIN_COAST", 
		"TERRAIN_PLAINS", 
		"TERRAIN_FOREST", 
		"TERRAIN_HILLS", 
		"TERRAIN_MOUNTAIN", 
		"TERRAIN_DESERT", 
		"TERRAIN_SNOW"
	]
	
	# 遍历添加，同时进行翻译
	for i in range(terrain_keys.size()):
		var key = terrain_keys[i]
		var text = tr(key) # <--- 核心：这里会把 TERRAIN_OCEAN 变成 "海洋"
		option_terrain.add_item(text, i)
		
	# --- 修复 ---
	# 假设默认逻辑是 PLAINS (Index 2)
	# 我们把 UI 设为 2
	option_terrain.selected = HexCell.TerrainType.PLAINS
	
	# 或者，不仅设 UI，还顺便通知 Viewer 确保一致
	terrain_selected.emit(HexCell.TerrainType.PLAINS)

func _on_move_confirmed():
	var idx = option_target.selected
	if idx != -1:
		move_to_requested.emit(idx)

# 供 Main 调用：填充目标列表
func setup_move_options(region_names: Array[String]):
	option_target.clear()
	for n in region_names:
		option_target.add_item(n)
	
	# 如果没有子区域，禁用确认键
	move_dialog.get_ok_button().disabled = region_names.is_empty()

# 点击移动按钮：填充列表并弹窗
func _on_btn_move_pressed():
	# 我们需要获取当前的子区域列表。
	# 这里 MapUI 不直接持有数据，可以发信号问 Main，或者由 Main 调用 MapUI 的一个 setup 函数。
	# 为了解耦，我们发一个信号 "request_child_list"，或者 Main 在 update selection 时就把数据传过来？
	
	# 简单方案：在 Main 里连接 btn_move_to 的 pressed 信号来填充数据。
	# 所以这里只负责弹窗，数据填充交给外部。
	move_dialog.popup_centered()

# 公开函数：刷新所有动态文本
func refresh_locale():
	# 重新初始化视图模式下拉框
	_init_view_mode_options()
	
	# 重新初始化地形下拉框
	_init_terrain_options()
	
	# 如果还有其他动态生成的 Label，也在这里刷新
	# btn_paint.text = tr("UI_BTN_PAINT") # 这种如果 Inspector 没绑定好，也可以代码刷

func _init_view_mode_options():
	option_view_mode.clear()
	var modes = ["VIEW_PHYSICAL", "VIEW_POLITICAL", "VIEW_RELIGIOUS"] # 定义 Keys
	for i in range(modes.size()):
		option_view_mode.add_item(tr(modes[i]), i)
	
	# 设置默认选中为 0 (Physical)
	# 注意：这只是 UI 显示选中，并不会自动触发 item_selected 信号
	option_view_mode.selected = 0

# 外部调用：更新按钮状态
func update_create_button(has_selection: bool):
	btn_create.disabled = not has_selection
	btn_move_to.disabled = not has_selection # 移动按钮同理

func _on_tool_toggled(is_pressed: bool, tool_name: String):
	if is_pressed:
		tool_changed.emit(tool_name)

# 更新面包屑文字
func update_breadcrumbs(stack: Array[RegionData]):
	var names = []
	for region in stack:
		names.append(region.name)
	# 用 " > " 连接数组
	lbl_path.text = " > ".join(names)

# 控制返回按钮是否可用
func set_back_enabled(enabled: bool):
	btn_back.disabled = not enabled

func reset_tool_to_select():
	# 将 Select 按钮设为按下状态
	# 因为它们在 ButtonGroup 里，Paint 按钮会自动弹起
	# 这会触发 toggled 信号，从而自动调用 _on_tool_toggled -> 发射 signal -> Main 通知 Viewer
	# 所以我们只要改 UI 状态，逻辑链就会自动执行
	btn_tool_select.button_pressed = true
