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

@onready var map_viewer = $HexMapViewer # 确保节点路径正确
@onready var fog_layer = $FogLayer # 确保场景里有这个节点，且名字一致
@onready var label_hp: Label = $HUD/MarginContainer/LeftSidebar/StatsPanel/HBoxContainer/LabelHP
@onready var label_supplies: Label = $HUD/MarginContainer/LeftSidebar/StatsPanel/HBoxContainer/LabelSupplies
@onready var result_window: CanvasLayer = $ResultWindow
@onready var system_menu = $HUD/SaveLoadMenu
@onready var inventory_list: VBoxContainer = $HUD/MarginContainer/LeftSidebar/InventoryList

# 绑定窗口
@onready var event_window: EventWindow = $HUD/EventWindow

var player: Player
var current_region: RegionData
var is_input_locked: bool = false # 输入锁，防止移动中连点
var current_supplies = 50 # 初始补给
var current_hp = 3        # 初始生命

# 物品清单 (简单的字符串数组)
var inventory: Array[String] = []

# 记录当前触发的事件，方便结算
var active_event: GameEvent

func _ready():
	randomize() # <--- 核心修复：初始化随机数种子
	_init_test_level() # 1. 先造地
	_spawn_poi()       # 2. 再造终点 (金色)
	_spawn_loot()      # 3. 再造物资 (蓝色)
	_init_fog()        # 4. 最后盖雾
	_spawn_player()    # 5. 放人
	
	# 3. 连接地图点击信号 (HexMapViewer 自带的信号)
	map_viewer.hex_clicked.connect(_on_hex_clicked)
	# 监听玩家移动完成，更新迷雾
	player.movement_finished.connect(_on_player_moved)

	SignalBus.locale_changed.connect(_update_ui)
	event_window.option_selected.connect(_on_event_option_selected)
	result_window.restart_requested.connect(_on_restart_game)
	
	_update_ui() # 初始化 UI

# --- 核心：处理游戏结束 ---
func _check_game_over_condition():
	# 失败判定：体力耗尽
	if current_supplies <= 0:
		_trigger_game_over(false, "体力耗尽，你倒在了荒野中...")

# 添加道具
func add_item(item_key: String):
	# ✅ 直接添加 (允许重复，这样才能堆叠)
	inventory.append(item_key)
	_update_inventory_ui()
	print("获得道具: ", item_key)

# --- 新增：战利品生成函数 ---
func _spawn_loot():
	# 1. 筛选合法格子 (非海，且无其他事件)
	var valid_cells = current_region.hex_cells.filter(func(c): 
		return c.terrain != HexCell.TerrainType.OCEAN and c.linked_event == null
	)
	
	if valid_cells.size() < 3: return
	
	# 定义掉落池 (资源路径)
	var loot_pool = [
		"res://game/events/event_loot_pickaxe.tres",
		"res://game/events/event_loot_raft.tres"
	]
	
	# 循环生成 3 个
	for i in range(3):
		var target_cell = valid_cells.pick_random()
		
		# 实例化 Marker
		var marker = load("res://game/objects/marker.tscn").instantiate()
		add_child(marker)
		marker.position = map_viewer.get_cell_center(target_cell.q, target_cell.r)
		
		# ✅ 修复 1: 设置颜色 (蓝色代表物资)
		marker.modulate = Color(0.2, 0.6, 1.0) 
		
		# 随机选一个事件
		var event_path = loot_pool.pick_random()
		target_cell.linked_event = load(event_path)
		
		# ✅ 修复 2: 绑定视觉对象 (至关重要)
		target_cell.visual_marker = marker
		
		# 从池子里移除已用的格子，防止重叠 (进阶优化)
		valid_cells.erase(target_cell)
		
		print("生成蓝色物资于: (%d, %d)" % [target_cell.q, target_cell.r])

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

# 触发结局
func _trigger_game_over(is_victory: bool, msg: String):
	is_input_locked = true # 锁住操作
	result_window.show_result(is_victory, msg)

func _spawn_poi():
	# 1. 筛选合法格子 (非海洋)
	# 矩形地图生成后，current_region.hex_cells 里应该已经剔除了边缘深渊
	# 但为了保险，还是 filter 一下
	var valid_cells = current_region.hex_cells.filter(func(c): 
		return c.terrain != HexCell.TerrainType.OCEAN
	)
	
	if valid_cells.size() < 2: return
	
	# 2. 随机选取终点 (离起点远一点更好，这里先随机)
	var target_cell = valid_cells.pick_random()
	
	# 3. 实例化 Marker
	var marker_scene = load("res://game/objects/marker.tscn")
	var marker = marker_scene.instantiate()
	add_child(marker) # 加到 GameMain 下，和 MapViewer 平级或更下
	
	# 4. 设置位置
	marker.position = map_viewer.get_cell_center(target_cell.q, target_cell.r)
	
	# 5. 绑定胜利事件
	target_cell.linked_event = load("res://game/events/event_victory.tres")
	
	# 🟢 新增：建立视觉绑定
	target_cell.visual_marker = marker
	print("DEBUG: Marker 已绑定到格子 (%d, %d), 对象: %s" % [target_cell.q, target_cell.r, marker])
	
	print("终点已生成于: ", Vector2i(target_cell.q, target_cell.r))

# 重开逻辑
func _on_restart_game():
	# 最简单的重开：重新加载当前场景
	get_tree().reload_current_scene()

# --- 核心：UI 更新 (使用 i18n) ---
func _update_ui():
	# RimWorld 风格：图标 + 数值
	# 注意：这里我们不需要 "补给: 50"，直接 "🍖 50" 更直观
	# 如果您坚持要文字，可以用 tr("GAME_STAT_SUPPLIES")
	
	label_supplies.text = "🍖 %d" % current_supplies
	label_hp.text = "❤️ %d" % current_hp
	
	# 视觉警示 (变红)
	if current_supplies <= 10:
		label_supplies.modulate = Color(1, 0.3, 0.3)
	else:
		label_supplies.modulate = Color.WHITE

# --- 新增：迷雾初始化 ---
func _init_fog():
	fog_layer.clear()
	
	# 简单粗暴：填满一个足够大的矩形区域
	# 或者只填满 current_region.hex_cells 涉及的区域
	# 这里我们只填满有数据的区域，更精准
	for cell in current_region.hex_cells:
		var tile_pos = map_viewer.axial_to_tilemap(cell.q, cell.r)
		fog_layer.set_cell(tile_pos, FOG_SOURCE_ID, FOG_ATLAS_COORD)

# --- 新增：玩家移动回调 ---
func _on_player_moved(new_coords: Vector2i):
	print("玩家到达: ", new_coords)
	_update_fog(new_coords)

# --- 新增：更新迷雾 (擦除) ---
func _update_fog(center_hex: Vector2i):
	# 定义视野半径 (Radius)
	var vision_radius = 1
	
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
		# --- 特殊地形判断 ---
	# 1. 河流/深水 (原本不可通过，现在有木筏可过)
	# 假设我们在生成器里把一部分水域标记为了可通行的浅水，或者就是 OCEAN
	# 注意：之前 _on_hex_clicked 里有个拦截 "if terrain == OCEAN: return"
	# 我们需要去改那里，或者在这里处理消耗
	
	# 2. 山脉 (有镐子减耗)
	if cell.terrain == HexCell.TerrainType.MOUNTAIN:
		if "item_pickaxe" in inventory:
			return 1 # 有镐子，如履平地
		else:
			return 3 # 没镐子，爬死你
			
	# 3. 森林 (有砍刀减耗)
	if cell.terrain == HexCell.TerrainType.FOREST:
		if "item_machete" in inventory:
			return 1
		else:
			return 2

	if cell.terrain == HexCell.TerrainType.OCEAN:
		return 2 # 4. 划船也挺累

	match cell.terrain:
		HexCell.TerrainType.PLAINS: return 1
		HexCell.TerrainType.FOREST: return 2
		HexCell.TerrainType.HILLS: return 2
		HexCell.TerrainType.MOUNTAIN: return 3
		HexCell.TerrainType.DESERT: return 3
		HexCell.TerrainType.SNOW: return 3
		_: return 1

# --- 核心：点击处理 ---
func _on_hex_clicked(target_hex: Vector2i):
	if is_input_locked: return
	
	var p_hex = player.hex_coords
	var a = HexCell.new(); a.q = p_hex.x; a.r = p_hex.y
	var b = HexCell.new(); b.q = target_hex.x; b.r = target_hex.y
	var dist = HexMath.get_distance(a, b)
	
	if dist != 1:
		print(tr("GAME_MSG_TOO_FAR"))
		return

	var cell = current_region.get_hex(target_hex.x, target_hex.y)
	if not cell: return
	
	if cell.terrain == HexCell.TerrainType.OCEAN:
		# 简单判断：如果有木筏则通过，没有则阻挡
		if "item_raft" in inventory:
			pass
		else:
			print(tr("GAME_MSG_OCEAN"))
			return
	
	var cost = _get_move_cost(cell)
	
	if current_supplies >= cost:
		is_input_locked = true
		current_supplies -= cost
		_update_ui()
		
		_update_fog(target_hex)
		var target_pos = map_viewer.get_cell_center(target_hex.x, target_hex.y)
		
		player.move_to(target_hex, target_pos)
		
		await player.movement_finished
		is_input_locked = false
		
		# --- 事件与销毁逻辑 ---
		if cell.linked_event:
			print("!!! 触发事件，开始清理流程 !!!")
			
			# 1. 先销毁视觉对象 (最优先执行)
			if cell.visual_marker:
				print("!!! 正在销毁 Marker: ", cell.visual_marker)
				cell.visual_marker.queue_free()
				cell.visual_marker = null # 断开引用
			else:
				print("!!! 警告: 格子有事件，但 visual_marker 为空 (可能是隐形事件) !!!")
			
			# 2. 触发弹窗
			_trigger_event(cell.linked_event)
			
			# 3. 清空数据链接
			cell.linked_event = null
			
	else:
		# 补给耗尽逻辑
		if current_hp > 0:
			print(tr("GAME_MSG_NO_SUPPLIES") + " HP -1")
			current_supplies = 0
			current_hp -= 1
			_update_ui()
			if current_hp <= 0:
				_trigger_game_over(false, tr("GAME_MSG_DEFEAT")) # 确保 CSV 有这个 Key
		else:
			_trigger_game_over(false, tr("GAME_MSG_DEFEAT"))

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
	current_supplies -= cost_ap
	# current_hp -= cost_hp
	
	# 5. 执行发奖 (✅ 在清空之前执行)
	if item_to_give != "":
		add_item(item_to_give)
	
	# 6. 刷新 UI
	_update_ui()
	
	if current_supplies < 0: 
		current_supplies = 0
		print("因为事件导致体力透支！")
	
	# 7. 收尾：恢复操作并清空缓存 (✅ 必须放在最后)
	is_input_locked = false
	active_event = null
