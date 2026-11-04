class_name Projectiles

extends Node2D

## Hold the bullets, the rockets, the pickups and the poofs of the current
## level.
##
## We keep them in the level, not in the spaceships or the enemies, so that they
## fly on independently of whoever fired them, and vanish with the level.

const _GROUP: String = "projectiles"


func _enter_tree() -> void:
    add_to_group(_GROUP)


## Return the projectiles of the current level, or null if there is no level.
static func of(node: Node) -> Projectiles:
    if not node.is_inside_tree():
        return null
    return node.get_tree().get_first_node_in_group(_GROUP) as Projectiles


## Add the projectile at the given global position.
func launch(projectile: Node2D, global_pos: Vector2) -> void:
    # NOTE (mristin):
    # We place the projectile before adding it, so that it already knows where
    # it starts in its _ready.
    #
    # We add it deferred, since we are often called from a physics callback
    # (e.g., an enemy hit by a bullet drops a pickup), where Godot forbids
    # adding new areas.
    projectile.position = to_local(global_pos)
    add_child.call_deferred(projectile)
