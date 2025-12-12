# res://core/data/game_event.gd
class_name GameEvent
extends Resource

enum Type { NORMAL, VICTORY, INSTANT_DEATH }

@export var event_type: Type = Type.NORMAL

@export var title: String = "未命名事件"
@export_multiline var description: String = "这里发生了一些事情..."
@export var image: Texture2D # 事件配图

# 选项 A
@export_group("Option A")
@export var option_a_give_item: String = "" # 填 "item_pickaxe"
@export var option_a_text: String = "继续前进"
@export var option_a_cost_ap: int = 0
@export var option_a_cost_hp: int = 0

# 选项 B
@export_group("Option B")
@export var option_b_give_item: String = ""
@export var option_b_text: String = "" # 为空则不显示
@export var option_b_cost_ap: int = 0
@export var option_b_cost_hp: int = 0
