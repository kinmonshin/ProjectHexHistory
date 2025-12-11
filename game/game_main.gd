# res://game/game_main.gd
extends Node2D

# 迷雾图块的 Source ID 和 Atlas Coords
# 请根据您的 fog_tileset.tres 实际情况修改！
# 通常 ID 是 0，坐标是 (0,0)
const FOG_SOURCE_ID = 0 
const FOG_ATLAS_COORD = Vector2i(0, 0)

# --- 玩家属性配置 ---
const MAX_AP = 10      # 最大体力 (Action Points)
const MOVE_COST = 1    # 移动消耗

@onready var map_viewer = $HexMapViewer # 确保节点路径正确
@onready var fog_layer = $FogLayer # 确保场景里有这个节点，且名字一致
@onready var ap_bar = $HUD/StatusBar/MarginContainer/HBoxContainer/ProgressBar
@onready var ap_label = $HUD/StatusBar/MarginContainer/HBoxContainer/LabelValue
# 绑定窗口
@onready var event_window: EventWindow = $HUD/EventWindow

@onready var result_window: CanvasLayer = $ResultWindow

var player: Player
var current_region: RegionData
var is_input_locked: bool = false

# 记录当前触发的事件，方便结算
var active_event: GameEvent

# 当前属性
var current_ap: int = MAX_AP

func _ready():
	# 1. 初始化游戏数据 (临时生成一张地图)
	_init_test_level()
	_init_fog() # <--- 新增：初始化迷雾
	# 2. 生成玩家
	_spawn_player()
	
	# 3. 连接地图点击信号 (HexMapViewer 自带的信号)
	map_viewer.hex_clicked.connect(_on_hex_clicked)
	# 监听玩家移动完成，更新迷雾
	player.movement_finished.connect(_on_player_moved)

	event_window.option_selected.connect(_on_event_option_selected)
	result_window.restart_requested.connect(_on_restart_game)
	
	_update_ui() # 初始化 UI

# --- 核心：处理游戏结束 ---
func _check_game_over_condition():
	# 失败判定：体力耗尽
	if current_ap <= 0:
		_trigger_game_over(false, "体力耗尽，你倒在了荒野中...")

# 触发结局
func _trigger_game_over(is_victory: bool, msg: String):
	is_input_locked = true # 锁住操作
	result_window.show_result(is_victory, msg)

# 重开逻辑
func _on_restart_game():
	# 最简单的重开：重新加载当前场景
	get_tree().reload_current_scene()

func _update_ui():
	# 更新条
	ap_bar.max_value = MAX_AP
	ap_bar.value = current_ap
	
	# 更新文字
	ap_label.text = "%d / %d" % [current_ap, MAX_AP]
	
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
	# 创建一个临时世界用于测试
	var world = RegionData.new()
	world.name = "Test Level"
	# 生成一个小岛
	MapGenerator.generate_island(world, 6, randi())
	
	current_region = world
	
	# 让地图显示出来 (强制设为自然视图)
	map_viewer.set_view_mode(HexMapViewer.ViewMode.PHYSICAL)
	map_viewer._on_world_loaded(world)
	
	# 手动在 (1, 0) 这个位置放一个事件
	var cell = world.get_hex(1, 0)
	if cell:
		# 加载刚才写的剧本
		cell.linked_event = load("res://game/events/event_ruins.tres")
		# 视觉调试：把这个格子变色，方便测试
		# (注意：这是数据变色，如果用 TileMapLayer 可能看不到，除非改 _draw 逻辑)
		# 暂时先盲测，或者看控制台
		
	# 在 (5, 2) 这个坐标埋下胜利事件
	var win_cell = world.get_hex(3, 2) # 找一个离起点(0,0)有点距离的格子
	if win_cell:
		win_cell.linked_event = load("res://game/events/event_victory.tres")
		print("胜利点已设置在: (3, 2)")

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

# 核心：处理移动请求
func _on_hex_clicked(target_hex: Vector2i):
	# 1. 正在移动中吗？(简单防连点)
	if player.is_moving: return 

	# 2. 距离判断
	var current_hex = player.hex_coords
	var a = HexCell.new(); a.q = current_hex.x; a.r = current_hex.y
	var b = HexCell.new(); b.q = target_hex.x; b.r = target_hex.y
	
	var dist = HexMath.get_distance(a, b)
	
	# --- 逻辑分层开始 ---
	
	if dist == 1:
		# [第一层判断通过：距离合适]
		
		# --- 新增的 AP 判断 ---
		if current_ap >= MOVE_COST:
			# [第二层判断通过：体力足够] -> 这里的所有代码都要多缩进一次！
			
			# A. 扣费
			current_ap -= MOVE_COST
			_update_ui()
			
			# B. 开视野
			_update_fog(target_hex)
			
			# C. 移动
			var target_pos = map_viewer.get_cell_center(target_hex.x, target_hex.y)
			player.move_to(target_hex, target_pos)
			
			# D. 检查耗尽
			if current_ap <= 0:
				_trigger_game_over(false, "体力耗尽...")
				return
				
			await player.movement_finished # 等玩家走到！
			
			# --- 新增：检查事件 ---
			var cell = current_region.get_hex(target_hex.x, target_hex.y)
			if cell and cell.linked_event:
				print("触发事件: ", cell.linked_event.title)
				# 暂时暂停游戏
				_trigger_event(cell.linked_event)
				# 消费掉事件 (变成 null)，避免重复触发
				cell.linked_event = null
		else:
			# [第二层判断失败：体力不足]
			print("体力不足，无法移动！")
			
	else:
		# [第一层判断失败：太远]
		print("太远了！只能移动一格。")
		
	_check_game_over_condition()

# --- 修改事件触发逻辑 (支持胜利事件) ---
func _trigger_event(event_res: GameEvent):
	print(">>> 弹出事件窗口: ", event_res.title)
	
	active_event = event_res # 暂存一下，结算时要用
	
	# 暂停玩家操作 (简单做法：设置一个标志位)
	is_input_locked = true #(需要在 _on_hex_clicked 开头检查这个变量)
	
	# 检查是否是特殊事件
	if event_res.event_type == GameEvent.Type.VICTORY:
		_trigger_game_over(true, event_res.description)
		return
		
	# 显示窗口
	event_window.show_event(event_res)

# 处理玩家选择结果
func _on_event_option_selected(index: int):
	if not active_event: return
	
	print("玩家选择了选项: ", index)
	
	# 结算逻辑
	var cost_ap = 0
	var cost_hp = 0 # 暂时还没做HP，先预留
	
	if index == 0: # Option A
		cost_ap = active_event.option_a_cost_ap
		cost_hp = active_event.option_a_cost_hp
		# 这里还可以处理获得物品/Flag
	elif index == 1: # Option B
		cost_ap = active_event.option_b_cost_ap
		cost_hp = active_event.option_b_cost_hp
		
	# 扣除资源
	current_ap -= cost_ap
	# current_hp -= cost_hp
	
	# 刷新 UI
	_update_ui()
	
	# 检查是否死亡/耗尽
	if current_ap < 0: 
		current_ap = 0
		print("因为事件导致体力透支！")
	
	# 恢复玩家操作
	is_input_locked = false
	
	# 清空暂存
	active_event = null
