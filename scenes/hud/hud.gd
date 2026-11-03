class_name Hud

extends CanvasLayer

## Display the state of the game. The HUD only displays; it decides nothing.
##
## NOTE (mristin):
## We keep the HUD hidden, since the counts only clutter the screen for
## the children. It still keeps the counts, e.g., for the tests; set it visible
## when debugging.

@onready var player_count: Label = $PlayerCount
@onready var enemy_count: Label = $EnemyCount


func on_player_count_changed(count: int) -> void:
    player_count.text = "Players: %d" % count


func on_enemy_count_changed(count: int) -> void:
    enemy_count.text = "Aliens: %d" % count
