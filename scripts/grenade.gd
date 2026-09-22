class_name Grenade
extends CharacterBody2D
# 手雷：抛物线投掷，落地后 1.5s 引信闪烁，然后 AOE 爆炸（半径 80，伤害 8）。

const GRAVITY := 980.0
const THROW_X := 400.0
const THROW_UP := 300.0
const FUSE_TIME := 1.5
const BLAST_RADIUS := 80.0
const BLAST_DAMAGE := 8.0

var _fuse_timer := 0.0
var _fuse_started := false
var _blink_timer := 0.0
var _exploded := false

@onready var body_rect: ColorRect = $Body


func setup(d: Vector2) -> void:
	velocity = d.normalized() * THROW_X + Vector2.UP * THROW_UP


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

	# 落地 → 启动引信
	if not _fuse_started and is_on_floor():
		_fuse_started = true
		_fuse_timer = FUSE_TIME

	if _fuse_started:
		_fuse_timer -= delta
		# 引信闪烁警告
		_blink_timer += delta
		body_rect.visible = fmod(_blink_timer, 0.2) < 0.1
		if _fuse_timer <= 0.0:
			_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	body_rect.visible = false
	# AOE 伤害：对半径内所有丧尸
	for z in get_tree().get_nodes_in_group("zombies"):
		if z is Zombie and not z.is_queued_for_deletion():
			if global_position.distance_to(z.global_position) <= BLAST_RADIUS:
				z.take_damage(int(BLAST_DAMAGE))
	# 爆炸视觉：快速放大的色块 + 淡出
	var fx := ColorRect.new()
	fx.color = Color(1.0, 0.6, 0.15, 0.9)
	fx.offset_left = -BLAST_RADIUS
	fx.offset_top = -BLAST_RADIUS
	fx.offset_right = BLAST_RADIUS
	fx.offset_bottom = BLAST_RADIUS
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	parent_node.add_child(fx)
	fx.global_position = global_position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.6, 1.6), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
	)
	queue_free()
