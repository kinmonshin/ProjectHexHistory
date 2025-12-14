# res://game/game_main.gd
extends Node2D

# 迷雾图块的 Source ID 和 Atlas Coords
# 请根据您的 fog_tileset.tres 实际情况修改！
# 通常 ID 是 0，坐标是 (0,0)
const FOG_SOURCE_ID = 0 
const FOG_ATLAS_COORD = Vector2i(0, 0)

# --- 属性 ---
const MAX_SUPPLIES = 100

# 定义战利品池 (路径列表)
const LOOT_EVENTS = [
	"res://game/events/event_loot_pickaxe.tres",
	"res://game/events/event_loot_raft.tres"
]

const MAX_DAYS: int = 30      # 死亡倒计时

@onready var map_viewer = $HexMapViewer # 确保节点路径正确
@onready var fog_layer = $FogLayer # 确保场景里有这个节点，且名字一致
@onready var val_energy: Label = $HUD/MarginContainer/LeftSidebar/StatsPanel/HBoxContainer/EnergyGroup/ValEnergy
@onready var val_hp: Label = $HUD/MarginContainer/LeftSidebar/StatsPanel/HBoxContainer/LifeGroup/ValHP
@onready var val_day: Label = $HUD/MarginContainer/LeftSidebar/StatsPanel/HBoxContainer/DayGroup/ValDay
@onready var result_window: CanvasLayer = $ResultWindow
@onready var system_menu = $HUD/SaveLoadMenu
@onready var inventory_list: VBoxContainer = $HUD/MarginContainer/LeftSidebar/InventoryList

# 绑定窗口
@onready var event_window: EventWindow = $HUD/EventWindow

var current_energy: int = 50  # 能量 (原 Supplies)
var current_hp: int = 3       # 生命
var current_day: int = 1      # 当前天数
var player: Player
var current_region: RegionData
var is_input_locked: bool = false # 输入锁，防止移动中连点
var active_pois: Array[Node2D] = [] # 存储所有生成的 Marker
var astar: AStar2D # 寻路核心
var hex_to_id = {} # 映射字典：Hex坐标字符串 "q,r" -> AStar ID (int)
# 物品清单 (简单的字符串数组)
var inventory: Array[String] = []
# 记录当前触发的事件，方便结算
var active_event: GameEvent
# 世界状态
var global_cost_modifier: int = 0 # 恶化系数 (0 = 正常, 1 = 困难)

func _ready():
	randomize() # <--- 核心修复：初始化随机数种子
	_init_test_level() # 1. 先造地
	_spawn_poi()       # 2. 再造终点 (金色)
	_spawn_loot()      # 3. 再造物资 (蓝色)
	_init_fog()        # 4. 最后盖雾
	_spawn_player()    # 5. 放人
	_init_pathfinding()
	# 3. 连接地图点击信号 (HexMapViewer 自带的信号)
	map_viewer.hex_clicked.connect(_on_hex_clicked)
	# 监听玩家移动完成，更新迷雾
	player.movement_finished.connect(_on_player_moved)

	SignalBus.locale_changed.connect(_update_ui)
	SignalBus.request_camp.connect(_on_camp_pressed)
	event_window.option_selected.connect(_on_event_option_selected)
	result_window.restart_requested.connect(_on_restart_game)

	_update_ui() # 初始化 UI

	# --- G1: 开局目标提示 ---
	var dialog = AcceptDialog.new()
	dialog.title = "任务"
	dialog.dialog_text = "远方的灯塔正在呼唤你...\n\n你必须在 30 天内抵达。\n每走一步消耗能量，能量耗尽会受伤。\n扎营可以恢复能量，但会消耗宝贵的 5 天时间。"
	add_child(dialog)
	dialog.popup_centered()

# --- 核心：处理游戏结束 ---
func _check_game_over_condition():
	# 失败判定：体力耗尽
	if current_energy <= 0:
		_trigger_game_over(false, "体力耗尽，你倒在了荒野中...")

func _on_camp_pressed():
	if is_input_locked: return
	
	# 简单的扎营逻辑
	print("扎营休息... (Day +5, Energy Refilled)")
	
	current_day += 5
	current_energy = 50 # 回满
	
	_update_ui()
	
	# G5: 检查超时
	if current_day > MAX_DAYS:
		_trigger_game_over(false, "时间耗尽，灯塔熄灭了...\n你迷失在了永恒的黑夜中。")

# 添加道具
func add_item(item_key: String):
	# ✅ 直接添加 (允许重复，这样才能堆叠)
	inventory.append(item_key)
	_update_inventory_ui()
	print("获得道具: ", item_key)

func _init_pathfinding():
	astar = AStar2D.new()
	hex_to_id.clear()
	
	print("正在构建导航网格...")
	
	var cells = current_region.hex_cells
	
	# 1. 添加所有点 (Points)
	for i in range(cells.size()):
		var cell = cells[i]
		
		# 跳过深渊 (不可通行)
		if cell.terrain == HexCell.TerrainType.OCEAN:
			continue
			
		# 注册点：ID 使用数组索引 i
		# 权重 (Weight Scale)：根据地形消耗决定
		# 这样寻路算法会自动避开高消耗的山地，哪怕路程短
		var weight = _get_move_cost(cell)
		
		# AStar2D 需要 Vector2 类型的 position，我们用像素位置方便调试
		# 但其实逻辑上它不关心 position，只关心连接关系
		var pos = map_viewer.get_cell_center(cell.q, cell.r)
		
		astar.add_point(i, pos, weight)
		
		# 建立映射方便查找
		var key = "%d,%d" % [cell.q, cell.r]
		hex_to_id[key] = i

	# 2. 连接点 (Connections)
	for i in range(cells.size()):
		var cell = cells[i]
		
		# 如果这个点没加进去（比如是深渊），跳过
		if not astar.has_point(i): continue
		
		# 检查 6 个方向的邻居
		for dir in range(6):
			var n_coords = HexMath.get_neighbor(cell, dir)
			var n_key = "%d,%d" % [n_coords.x, n_coords.y]
			
			if hex_to_id.has(n_key):
				var n_id = hex_to_id[n_key]
				# 建立双向连接
				astar.connect_points(i, n_id)
	
	print("导航网格构建完成。节点数: ", astar.get_point_count())

# --- 新增：战利品生成函数 ---
func _spawn_loot():
	# 1. 筛选合法格子
	var valid_cells = current_region.hex_cells.filter(func(c): 
		return c.terrain != HexCell.TerrainType.OCEAN and c.linked_event == null
	)
	
	if valid_cells.size() < 3: return
	
	var loot_pool = [
		"res://game/events/event_loot_pickaxe.tres",
		"res://game/events/event_loot_raft.tres"
	]
	
	for i in range(3):
		var target_cell = valid_cells.pick_random()
		
		# 🟢 修改 1: 加载 loot.tscn (而不是 marker.tscn)
		var marker = load("res://game/objects/loot.tscn").instantiate()
		add_child(marker)
		
		# 设置位置
		marker.position = map_viewer.get_cell_center(target_cell.q, target_cell.r)
		marker.hex_coords = Vector2i(target_cell.q, target_cell.r) 
		
		# 🟢 修改 2: 默认隐藏，并加入管理列表
		# 我们把“是否显示”的权力完全交给 _update_fog 函数（如果您希望终点一开始就可见，可以不加这两行，或者单独处理)
		# marker.visible = false # 这是代码强制隐藏，注释后，则改回检查器开关
		active_pois.append(marker)  # 保持加入列表，以便后续被迷雾逻辑管理

	
		# 绑定事件
		var event_path = loot_pool.pick_random()
		target_cell.linked_event = load(event_path)
		
		# 绑定视觉对象 (用于拾取后销毁)
		target_cell.visual_marker = marker
		
		# 防止重叠
		valid_cells.erase(target_cell)
		
		print("生成物资于: (%d, %d)" % [target_cell.q, target_cell.r])

# 刷新 UI (RimWorld 风格：竖向列表)
func _update_inventory_ui():
	print("DEBUG: 刷新物品栏，当前 inventory: ", inventory)
	
	# 1. 确认节点存在
	if not inventory_list:
		print("DEBUG: 错误！找不到 InventoryList 节点")
		return

	# 2. 清空旧列表
	for child in inventory_list.get_children():
		child.queue_free()
	
	# 3. 统计数量 (使用更稳健的写法)
	var item_counts = {}
	for item_key in inventory:
		var current_count = item_counts.get(item_key, 0) # 获取当前值，没有则返0
		item_counts[item_key] = current_count + 1
	
	print("DEBUG: 统计结果: ", item_counts)

	# 4. 生成 UI
	for item_key in item_counts.keys():
		var count = item_counts[item_key]
		var label = Label.new()
		
		# 翻译: item_raft -> ITEM_RAFT
		var tr_key = item_key.to_upper()
		var item_name = tr(tr_key)
		
		# 如果翻译失败（key没找到），tr会返回key本身。
		# 我们可以做个美化：如果是英文 Key，把下划线去掉
		if item_name == tr_key:
			item_name = item_key.replace("item_", "").capitalize()
		
		# 格式化
		if count > 1:
			label.text = "%s x%d" % [item_name, count]
		else:
			label.text = item_name
			
		# 样式
		label.label_settings = LabelSettings.new()
		label.label_settings.shadow_size = 2
		label.label_settings.shadow_color = Color.BLACK
		
		inventory_list.add_child(label)

# 检查物品
func has_item(item_id: String) -> bool:
	return item_id in inventory

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"): # ESC键
		if system_menu.visible:
			system_menu.close_menu()
		else:
			system_menu.open_menu()
			
	# 按 T 键触发世界恶化 (测试用)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		global_cost_modifier += 1
		print("【系统】世界开始崩塌，移动消耗 +1 (当前加成: %d)" % global_cost_modifier)

# 触发结局
func _trigger_game_over(is_victory: bool, msg: String):
	is_input_locked = true # 锁住操作
	result_window.show_result(is_victory, msg)

func _spawn_poi():
	# 1. 筛选合法格子
	var valid_cells = current_region.hex_cells.filter(func(c): 
		return c.terrain != HexCell.TerrainType.OCEAN
	)
	if valid_cells.size() < 2: return
	
	# 2. 随机选取
	var target_cell = valid_cells.pick_random()
	
	# 3. 实例化
	# 终点依然使用 marker.tscn (金色/高亮)
	var marker_scene = load("res://game/objects/marker.tscn")
	var marker = marker_scene.instantiate()
	add_child(marker)
	
	marker.position = map_viewer.get_cell_center(target_cell.q, target_cell.r)
	marker.hex_coords = Vector2i(target_cell.q, target_cell.r)
	
	# 🟢 统一管理：默认也隐藏，加入列表
	# (如果您希望终点一开始就可见，可以不加这两行，或者单独处理)
	# marker.visible = false # 这是代码强制隐藏，注释后，则改回检查器开关
	active_pois.append(marker) # 保持加入列表，以便后续被迷雾逻辑管理
	
	target_cell.linked_event = load("res://game/events/event_victory.tres")
	target_cell.visual_marker = marker

# 重开逻辑
func _on_restart_game():
	# 最简单的重开：重新加载当前场景
	get_tree().reload_current_scene()

# --- 核心：UI 更新 (使用 i18n) ---
func _update_ui():
	# RimWorld 风格：图标 + 数值
	# 只要更新数字即可，图标已经由 TextureRect 处理了
	if val_energy:
		# 也可以加上 /30 的上限显示
		val_energy.text = "%d / %d" % [current_energy, 50]
		
	if val_hp:
		val_hp.text = "%d" % current_hp
		
	# 更新日期
	if val_day:
		# 格式化字符串： "第 1 / 30 天"
		val_day.text = tr("GAME_STAT_DAY") % [current_day, MAX_DAYS]
		
		# 视觉反馈：如果只剩最后 5 天，变红警示
		if current_day >= MAX_DAYS - 5:
			val_day.modulate = Color(1, 0.3, 0.3)
		else:
			val_day.modulate = Color.WHITE
	
	# 视觉警示 (变红)
	if current_energy <= 10:
		val_energy.modulate = Color(1, 0.3, 0.3)
	else:
		val_energy.modulate = Color.WHITE

# --- 新增：迷雾初始化 ---
func _init_fog():
	fog_layer.clear()
	
	# 简单粗暴：填满一个足够大的矩形区域
	# 或者只填满 current_region.hex_cells 涉及的区域
	# 这里我们只填满有数据的区域，更精准
	for cell in current_region.hex_cells:
		var tile_pos = map_viewer.axial_to_tilemap(cell.q, cell.r)
		fog_layer.set_cell(tile_pos, FOG_SOURCE_ID, FOG_ATLAS_COORD)

# --- 新增：更新迷雾 (擦除) ---
func _update_fog(center_hex: Vector2i, vision_radius: int = 2):
	# 遍历周围格子
	for q in range(-vision_radius, vision_radius + 1):
		for r in range(-vision_radius, vision_radius + 1):
			if abs(-q-r) <= vision_radius:
				# 计算实际坐标
				var target_q = center_hex.x + q
				var target_r = center_hex.y + r
				
				# 1. 擦除迷雾 (TileMap)
				var tile_pos = map_viewer.axial_to_tilemap(target_q, target_r)
				fog_layer.erase_cell(tile_pos)
				
				# 2. 更新数据 (HexCell) -> 标记为已探索 (为未来存盘做准备)
				var cell = current_region.get_hex(target_q, target_r) # 需确保 RegionData 有 get_hex
				if cell:
					cell.is_explored = true
					
	# --- 🟢 修改：刷新 POI 可见性 ---
	# 逻辑变更为：如果 POI 所在的格子被探索了 (is_explored == true)，则显示 POI
	for poi in active_pois:
		if poi.visible: continue # 已经显示的就不管了
		
		# 获取 POI 所在的格子数据
		var cell = current_region.get_hex(poi.hex_coords.x, poi.hex_coords.y)
		
		# 只要格子被探索过，图标就显示
		# 这完美符合“迷雾散去即见”的直觉
		if cell and cell.is_explored:
			poi.visible = true
			print("发现了物体！在: ", poi.hex_coords) # 可以在这里播放一个“发现”音效

# 玩家移动完成后的回调
func _on_player_moved(new_coords: Vector2i):
	# print("玩家到达: ", new_coords)
	
	# 获取当前地形
	var cell = current_region.get_hex(new_coords.x, new_coords.y)
	if not cell: return
	
	# ✅ 使用基于地形的更新函数
	# 它内部会判断地形，然后决定传 2 还是 5 给 _update_fog
	_update_fog_based_on_terrain(new_coords, cell.terrain)

func _init_test_level():
	var world = RegionData.new()
	world.name = "Unknown World"
	
	# 生成地图
	MapGenerator.generate_rectangular_map(world, 20, 20, randi())
	
	current_region = world
	map_viewer.set_view_mode(HexMapViewer.ViewMode.PHYSICAL)
	map_viewer._on_world_loaded(world)

func _spawn_player():
	# 实例化玩家
	var player_scene = load("res://game/player.tscn")
	player = player_scene.instantiate()
	
	# 添加到场景 (必须加在 map_viewer 之后，或者 fog_layer 之下)
	# 建议加一个专门的 EntityLayer 节点来放单位，这里直接 add_child
	add_child(player)
	
	# 设置初始位置：(0, 0)
	var start_hex = Vector2i(0, 0)
	# 这一步很关键：我们需要问 map_viewer (0,0) 的像素位置在哪
	# 注意：_get_cell_center 是私有函数吗？如果是，建议改成公有 get_cell_center
	# 或者我们先临时用 HexMath 算，只要之前对齐做好了就没问题
	# 最佳实践：去 HexMapViewer 把 _get_cell_center 改名为 get_cell_center (去掉下划线)
	var start_pos = map_viewer.get_cell_center(start_hex.x, start_hex.y)
	
	player.setup(start_hex, start_pos)
	
	# 立即更新一次迷雾
	_update_fog(start_hex)

# --- 核心：获取移动消耗 ---
func _get_move_cost(cell: HexCell) -> int:
	var base_cost = 1
	
	# 地形差异
	if cell.terrain == HexCell.TerrainType.MOUNTAIN:
		base_cost = 3
	elif cell.terrain == HexCell.TerrainType.FOREST:
		base_cost = 2
	elif cell.terrain == HexCell.TerrainType.OCEAN:
		return 999 # 不可通行
		
	# G4: 叠加世界恶化 (如果世界崩塌了，走路变累)
	return base_cost + global_cost_modifier

# --- 核心：点击处理 ---
func _on_hex_clicked(target_hex: Vector2i):
	if is_input_locked: return
	
	# 1. 获取起点和终点的 ID
	var start_key = "%d,%d" % [player.hex_coords.x, player.hex_coords.y]
	var end_key = "%d,%d" % [target_hex.x, target_hex.y]
	
	if not hex_to_id.has(start_key) or not hex_to_id.has(end_key):
		print(tr("GAME_MSG_OCEAN")) # 点击了不可通行区域
		return
		
	var start_id = hex_to_id[start_key]
	var end_id = hex_to_id[end_key]
	
	# 2. 计算路径
	# get_id_path 会返回经过的所有点的 ID 数组 (包括起点)
	var path_ids = astar.get_id_path(start_id, end_id)
	
	if path_ids.size() <= 1:
		return # 点了自己，或者无路可走
	
	# 3. 开始沿路径移动 (协程)
	_execute_path_movement(path_ids)

# --- 新增：分步移动协程 ---
func _execute_path_movement(path_ids: PackedInt64Array):
	is_input_locked = true
	
	# 从索引 1 开始移动
	for i in range(1, path_ids.size()):
		var next_id = path_ids[i]
		var target_cell = current_region.hex_cells[next_id]
		var target_hex = Vector2i(target_cell.q, target_cell.r)
		
		# 1. 计算消耗
		var cost = _get_move_cost(target_cell)
		
		# 2. 检查能量
		if current_energy >= cost:
			current_energy -= cost
			_update_ui()
			
			# 执行移动动画
			var target_pos = map_viewer.get_cell_center(target_hex.x, target_hex.y)
			_update_fog_based_on_terrain(target_hex, target_cell.terrain) # 开视野
			
			player.move_to(target_hex, target_pos)
			await player.movement_finished
			
			
			
			# 检查事件
			if target_cell.linked_event:
				_trigger_event(target_cell.linked_event)
				target_cell.linked_event = null
				break
		else:
			# 能量耗尽：扣血机制
			if current_hp > 0:
				print("能量耗尽！强行移动 (HP -1)")
				current_hp -= 1
				current_energy = 0 # 保持为0
				_update_ui()
				
				# 即使没能量也让走一步(带惩罚)
				var target_pos = map_viewer.get_cell_center(target_hex.x, target_hex.y)
				_update_fog_based_on_terrain(target_hex, target_cell.terrain)
				player.move_to(target_hex, target_pos)
				await player.movement_finished
				
				if current_hp <= 0:
					_trigger_game_over(false, "你累死在了半路...")
					break
			else:
				break # 彻底死了
				
	is_input_locked = false

# 基于地形更新迷雾
func _update_fog_based_on_terrain(center_hex: Vector2i, terrain_type: int):
	var radius = 3 # 基础视野扩大到 3
	
	# 高地优势
	if terrain_type == HexCell.TerrainType.MOUNTAIN:
		radius = 5 # 登上高山，视野大开
		print("高地视野！")
	elif terrain_type == HexCell.TerrainType.FOREST:
		radius = 2 # 森林里视野受限
		
	# 调用通用的更新函数
	_update_fog(center_hex, radius)

# 触发事件的主入口
func _trigger_event(event_res: GameEvent):
	print(">>> 触发事件: ", event_res.title)
	
	# 1. 特殊事件处理 (胜利/失败)
	if "event_type" in event_res and event_res.event_type == GameEvent.Type.VICTORY:
		_trigger_game_over(true, event_res.description)
		return

	# 2. 🔴 关键修复：必须先赋值给全局变量！
	active_event = event_res 
	
	# 3. 锁定玩家输入
	is_input_locked = true
	
	# 4. 弹出窗口
	if event_window:
		event_window.show_event(event_res)
	else:
		print("错误：EventWindow 未连接！")

# 处理玩家选择结果
func _on_event_option_selected(index: int):
	# 1. 卫兵检查
	if active_event == null:
		print("⚠️ 警告：active_event 为空！结算中止。")
		is_input_locked = false 
		return

	print("玩家选择了选项: ", index)
	
	# 2. 准备变量
	var cost_ap = 0
	var cost_hp = 0
	var item_to_give = "" # 提前定义
	
	# 3. 读取数据 (此时 active_event 还是有效的)
	if index == 0: # Option A
		cost_ap = active_event.option_a_cost_ap
		cost_hp = active_event.option_a_cost_hp
		# ✅ 关键：在这里读取奖励
		item_to_give = active_event.option_a_give_item
		
	elif index == 1: # Option B
		cost_ap = active_event.option_b_cost_ap
		cost_hp = active_event.option_b_cost_hp
		item_to_give = active_event.option_b_give_item
		
	# 4. 执行扣费
	current_energy -= cost_ap
	# current_hp -= cost_hp
	
	# 5. 执行发奖 (✅ 在清空之前执行)
	if item_to_give != "":
		add_item(item_to_give)
	
	# 🔴 核心修复：销毁地图上的图标
		# 获取玩家当前所在的格子 (因为事件是踩上去触发的)
		var current_cell = current_region.get_hex(player.hex_coords.x, player.hex_coords.y)
		
		if current_cell and current_cell.visual_marker:
			# 从 active_pois 列表中移除 (如果有的话)，防止报错
			if active_pois.has(current_cell.visual_marker):
				active_pois.erase(current_cell.visual_marker)
			
			# 销毁节点
			current_cell.visual_marker.queue_free()
			current_cell.visual_marker = null
			
			print("地图物资图标已销毁")
			
	# 6. 刷新 UI
	_update_ui()
	
	if current_energy < 0: 
		current_energy = 0
		print("因为事件导致体力透支！")
	
	# 7. 收尾：恢复操作并清空缓存 (✅ 必须放在最后)
	is_input_locked = false
	active_event = null
