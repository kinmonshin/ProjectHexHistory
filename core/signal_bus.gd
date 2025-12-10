# res://core/signal_bus.gd
extends Node

# --- A. 工具与交互信号 ---
signal tool_changed(tool_name: String)
signal river_mode_toggled(is_on: bool)
signal paint_terrain_selected(terrain_id: int)
signal request_clear_layer()

# 请求打开“移动到...”弹窗 (Move To)
signal request_move_dialog() 

# --- B. 视图与导航信号 ---
signal view_mode_changed(mode_id: int)
signal navigation_view_changed(current_region: Resource) 
signal request_navigate_to(target_region: Resource)
# ✅ 务必确认这两行存在且拼写完全一致：
signal request_navigate_back()
signal breadcrumbs_updated(stack_names: Array[String])

# --- C. 数据操作信号 ---
signal map_data_modified()
signal hex_hovered(coord: Vector2i)
signal selection_updated(selected_items: Array) 
signal request_create_region()
signal request_move_to_dialog(target_names: Array)

# --- D. 系统与流程信号 ---
signal request_system_menu()
signal locale_changed()
signal request_generate_map()
