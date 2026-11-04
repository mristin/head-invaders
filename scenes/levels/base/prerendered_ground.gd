class_name PrerenderedGround

extends SubViewport

## Render a tall tile of a level's ground once, when the level starts, and hand
## it to the shader of the target, which then only slides the tile down.
##
## A small tile of something which moves, e.g., the shimmer of the sea, can
## also be rendered on every frame instead.
##
## NOTE (mristin):
## The detailed grounds, e.g., the forest with its trees, are too heavy to
## draw from scratch on every frame on the weaker laptops. The ground repeats
## itself vertically after the height of the tile, so that the target can wrap
## the tile around while it slides.

## The shader which draws the tile once; it receives the pixel coordinates of
## the tile in VERTEX.
@export var tile_shader: Shader

## The canvas item whose shader material slides the tile, e.g., the stars of
## the level.
@export var target: CanvasItem

## The name of the target shader's sampler which receives the tile.
@export var parameter: StringName = &"tile"

## Keep the alpha which the tile shader writes, e.g., where the ponds are, so
## that the target can use it. The tile shader then also has to disable
## the blending.
@export var keeps_alpha: bool = false

## Render the tile on every frame instead of only once, e.g., for the shimmer
## of the sea, which moves.
@export var keeps_updating: bool = false


func _ready() -> void:
    disable_3d = true
    transparent_bg = keeps_alpha
    render_target_update_mode = (
        SubViewport.UPDATE_ALWAYS if keeps_updating else SubViewport.UPDATE_ONCE
    )

    var canvas := ColorRect.new()
    canvas.size = Vector2(size)
    canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = tile_shader
    canvas.material = material
    add_child(canvas)

    var target_material := target.material as ShaderMaterial
    if target_material != null:
        target_material.set_shader_parameter(parameter, get_texture())
