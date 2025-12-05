# res://view/ui/map_ui.gd
class_name MapUI
extends CanvasLayer

signal back_requested
signal create_region_requested # 新信号
signal view_mode_changed(mode_id: int)
signal generate_requested # 新信号
signal river_mode_toggled(is_on: bool) # 新信号

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

func _ready():
	btn_back.pressed.connect(func(): back_requested.emit())
	
	# 连接工具按钮信号
	btn_tool_select.toggled.connect(_on_tool_toggled.bind("select"))
	btn_tool_paint.toggled.connect(_on_tool_toggled.bind("paint"))
	btn_create.pressed.connect(func(): create_region_requested.emit())
	
	# 默认选中 Select
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

func _init_view_mode_options():
	option_view_mode.clear()
	var modes = ["VIEW_PHYSICAL", "VIEW_POLITICAL", "VIEW_RELIGIOUS"] # 定义 Keys
	for i in range(modes.size()):
		option_view_mode.add_item(tr(modes[i]), i)
	
	# 设置默认选中为 0 (Physical)
	# 注意：这只是 UI 显示选中，并不会自动触发 item_selected 信号
	option_view_mode.selected = 0

# 供外部调用：更新按钮状态
func update_create_button(has_selection: bool):
	btn_create.disabled = not has_selection

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
