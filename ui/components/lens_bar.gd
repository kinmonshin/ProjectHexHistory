extends PanelContainer

# 请务必检查场景树里节点的真实名称和路径！
# 比如这里假设您的结构是 MarginContainer/HBoxContainer/Btn...
@onready var btn_view_phy = $MarginContainer/HBoxContainer/BtnViewPhysical
@onready var btn_view_pol = $MarginContainer/HBoxContainer/BtnViewPolitical
@onready var btn_select = $MarginContainer/HBoxContainer/BtnToolSelect
@onready var btn_paint = $MarginContainer/HBoxContainer/BtnToolPaint
@onready var btn_river = $MarginContainer/HBoxContainer/BtnToolRiver
@onready var opt_terrain = $MarginContainer/HBoxContainer/OptionTerrain
@onready var btn_gen = $MarginContainer/HBoxContainer/BtnGen
@onready var btn_move_to = $MarginContainer/HBoxContainer/BtnMoveTo
@onready var btn_create = $MarginContainer/HBoxContainer/BtnCreate

func _ready():
	# 初始化地形
	_init_terrain_options()
	
	# 连接视图模式
	btn_view_phy.pressed.connect(func(): SignalBus.view_mode_changed.emit(0))
	btn_view_pol.pressed.connect(func(): SignalBus.view_mode_changed.emit(1))
	
	# 连接工具
	btn_select.toggled.connect(func(p): if p: SignalBus.tool_changed.emit("select"))
	btn_paint.toggled.connect(func(p): if p: SignalBus.tool_changed.emit("paint"))
	btn_river.toggled.connect(func(p): SignalBus.river_mode_toggled.emit(p))
	
	# 连接地形
	opt_terrain.item_selected.connect(func(idx): SignalBus.paint_terrain_selected.emit(idx))
	
	# 连接生成
	btn_gen.pressed.connect(func(): SignalBus.request_generate_map.emit())
	
	# 连接新建按钮
	btn_create.pressed.connect(func(): SignalBus.request_create_region.emit())
	
	# 连接移动按钮
	btn_move_to.pressed.connect(func(): SignalBus.request_move_dialog.emit())
	# 监听语言切换
	SignalBus.locale_changed.connect(_init_terrain_options)

func _init_terrain_options():
	# 记录当前选中的索引，防止刷新后跳回第一个
	var prev_selected = opt_terrain.selected
	
	opt_terrain.clear()
	var keys = [
		"TERRAIN_OCEAN", "TERRAIN_COAST", "TERRAIN_PLAINS", 
		"TERRAIN_FOREST", "TERRAIN_HILLS", "TERRAIN_MOUNTAIN", 
		"TERRAIN_DESERT", "TERRAIN_SNOW"
	]
	for i in range(keys.size()):
		opt_terrain.add_item(tr(keys[i]), i)
		
	# 恢复选中状态
	if prev_selected >= 0:
		opt_terrain.selected = prev_selected
	else:
		# 默认设为平原 (Index 2)
		opt_terrain.selected = 2
