# res://main.gd
extends Node2D

const SAVE_PATH = "user://my_hex_world.tres"

@onready var editor_panel = $EditorPanel
@onready var view_controller = $ViewStackController
@onready var map_ui = $MapUI # 确保节点路径正确
@onready var map_viewer = $HexMapViewer # 需要能访问到 map_viewer

func _ready():
	# 1. World
	var world = RegionData.new()
	world.name = "Azeroth"
	world.type = RegionData.Type.WORLD
	
	# 2. Nation (Khaz Modan) - 位于左侧
	var nation_a = RegionData.new()
	nation_a.name = "Khaz Modan"
	nation_a.type = RegionData.Type.NATION
	nation_a.map_color = Color.RED
	
	# 给 Nation A 加点格子 (左边的一团)
	for q in range(-4, -1):
		for r in range(-2, 2):
			nation_a.add_hex(q, r)
			
	world.add_child(nation_a)
	
	# 3. Nation (Lordaeron) - 位于右侧
	var nation_b = RegionData.new()
	nation_b.name = "Lordaeron"
	nation_b.type = RegionData.Type.NATION
	nation_b.map_color = Color.BLUE
	
	# 给 Nation B 加点格子 (右边的一团)
	for q in range(2, 5):
		for r in range(-2, 2):
			nation_b.add_hex(q, r)
			
	world.add_child(nation_b)
	
		# --- 新增连接逻辑 ---
	# 1. 连接编辑器
	view_controller.view_changed.connect(editor_panel.bind_data)
	
	# 2. 连接工具栏 (UI -> Viewer)
	# 当 UI 切换工具时，告诉 Viewer 改变模式
	map_ui.tool_changed.connect(map_viewer.set_tool)
	
	# 启动！
	SessionManager.current_world = world
	SessionManager.world_loaded.emit(world)
	
	# --- 新增连接 ---
		# 1. 当地图选中项变化 -> 更新 UI 按钮
	map_viewer.selection_changed.connect(func(count): 
		map_ui.update_create_button(count > 0)
	)
		# 2. 当点击“创建区域” -> 执行数据操作
	map_ui.create_region_requested.connect(_on_create_region)
	
	# 连接编辑器的修改信号 -> 触发地图重绘
	editor_panel.data_modified.connect(func(): map_viewer.queue_redraw())
	
	# 连接 UI 地形选择 -> Viewer
	map_ui.terrain_selected.connect(map_viewer.set_paint_terrain)
	
	map_ui.view_mode_changed.connect(map_viewer.set_view_mode)
	
	# 连接生成按钮	
	map_ui.generate_requested.connect(_on_generate_requested)
	
	# 连接河流模式开关
	map_ui.river_mode_toggled.connect(map_viewer.set_river_mode)
	
	# 1. 尝试加载存档
	if FileAccess.file_exists(SAVE_PATH):
		print("发现存档，正在加载...")
		SessionManager.load_world(SAVE_PATH)
	else:
		print("未发现存档，初始化新世界...")
		_init_new_world()

# 把之前的测试数据生成逻辑封装到这里
func _init_new_world():
	var world = RegionData.new()
	world.name = "New World"
	world.type = RegionData.Type.WORLD
	
	# (可选) 可以在这里生成一点初始数据，比如一个空的 World
	
	SessionManager.current_world = world
	SessionManager.world_loaded.emit(world)

# 生成回调
func _on_generate_requested():
	# 1. 获取当前所在的区域层级
	# (注意：我们应该生成在当前层级，还是只允许在 World 层级生成？)
	# 目前逻辑：生成在当前你看到的这一层
	var current_region = view_controller.stack.back()
	
	if not current_region: return
	
	# --- 新增限制 ---
	# 只允许在宏观层级生成
	if current_region.type == RegionData.Type.PROVINCE or \
	   current_region.type == RegionData.Type.CITY or \
	   current_region.type == RegionData.Type.HEX_CELL:
		print("当前层级不支持生成大陆地形。")
		# 可以在这里弹出一个 AcceptDialog 提示用户
		return
	
	# 2. 确认弹窗 (可选，防止误删)
	# 暂时略过，直接生成
	
	# 3. 调用生成器
	# 半径设为 15 (约 700 个格子)，种子随机
	var radius = 15
	var seed_val = randi()
	
	print("开始在区域 [%s] 生成地形..." % current_region.name)
	MapGenerator.generate_island(current_region, radius, seed_val)
	
	# 4. 刷新视图
	# 如果当前在看 Political 模式，可能看不出地形变化，强切到 Physical
	map_viewer.set_view_mode(HexMapViewer.ViewMode.PHYSICAL)
	# 如果 UI 下拉框没变，这里可能会导致 UI 和 实际模式 不一致，严格来说应该更新 UI 状态
	# 简单起见，只刷新画面
	map_viewer.queue_redraw()
	
	# 5. 提示保存
	print("生成完毕！")

# --- 核心：创建新区域逻辑 ---
func _on_create_region():
	var current_region = SessionManager.current_world # 这是一个 Bug，需要获取当前 ViewStack 的栈顶
	# 修正：我们需要从 ViewController 获取当前所在层级
	current_region = view_controller.stack.back()
	
	var selected_coords = map_viewer.get_selected_cells()
	if selected_coords.is_empty(): return
	
	print("正在从 %d 个格子创建新区域..." % selected_coords.size())
	
	# 1. 创建新区域对象
	var new_region = RegionData.new()
	new_region.name = "New Region " + str(randi() % 100)
	# 自动判断类型：如果是 World 层级，创建 Nation；如果是 Nation，创建 Province
	new_region.type = _get_next_type(current_region.type)
	new_region.map_color = Color(randf(), randf(), randf()) # 随机颜色
	
	# 2. 迁移格子数据
	for coord in selected_coords:
		# 2.1 从原区域找到那个具体的 HexCell 对象
		var original_cell = current_region.get_hex(coord.x, coord.y) # 需要去 RegionData 加这个 helper
	
		if original_cell:
			# 2.2 从原区域移除引用
			current_region.remove_hex(coord.x, coord.y)
			
			# 2.3 添加到新区域 (直接添加对象，而不是 new)
			new_region.hex_cells.append(original_cell)
	
	# 3. 建立层级关系
	current_region.add_child(new_region)
	
	# 4. 收尾
	map_viewer.clear_selection()
	map_viewer.region_modified.emit() # 通知重绘
	
	# 5. 自动进入新区域编辑 (可选)
	# view_controller._push_view(new_region) # 这一步需要把 _push_view 公开，或者不跳转

# 辅助：获取下一级类型
func _get_next_type(current: RegionData.Type) -> RegionData.Type:
	match current:
		RegionData.Type.WORLD: return RegionData.Type.NATION
		RegionData.Type.NATION: return RegionData.Type.PROVINCE
		RegionData.Type.PROVINCE: return RegionData.Type.CITY
		_: return RegionData.Type.PROVINCE
