extends KinematicBody2D

onready var character = $position/animated_sprite
onready var char_pos = $position
onready var hitbox_imposter = $Area2D/playerHitbox
onready var area2d = $Area2D
onready var collisionbox = $CollisionShape2D
onready var timer = $Timer
var player_color = "imposter"
var imposter_color
var rng
var is_hit
var pos_arr:Array = [Vector2(0,3000), 
					Vector2(3000,3000), 
					Vector2(1000,1000), 
					Vector2(-3500,3000),
					Vector2(-7500,3000),
					Vector2(-10000, 5500)
]
# Global velocity
var velocity = Vector2.ZERO
var BASE_SPEED = 250
var BASE_ACCELERATION = 500

func _ready():
	is_hit = false
	randomize()
	rng = randi() % 4
	if rng == 0:
		imposter_color = "green"
	elif rng == 1:
		imposter_color = "blue"
	elif rng == 2:
		imposter_color = "orange"
	else:
		imposter_color = "red"
	
func _physics_process(_delta):
	var player_pos = null

	#if not get_parent()._player_dead:
	player_pos = get_parent().get_node("Player").position
	velocity = position.direction_to(player_pos)* BASE_SPEED
	velocity = move_and_slide(velocity)
	control_animations(velocity)
	#else:
	
	#control_animations(velocity)


"""
/*
* @pre None
* @post Changes imposter position to one of the already defined positions in array
* @param player_pos -> Vector2
* @return None
*/
"""	
func setup_pos(player_pos):
	randomize()
	var num = 0
	var new_arr:Array = []
	for i in range(6):
		position = pos_arr[i]
		if sqrt(pow(player_pos.x - position.x, 2) +  pow(player_pos.y - position.y, 2) )> 800:
			new_arr.append(position)
			num+=1
	rng = randi() % num
	position = new_arr[rng]
	

"""
/*
* @pre None
* @post updates the character's animations
* @param vel -> Vector2
* @return None
*/
"""
func control_animations(vel:Vector2):
	
	#Character moves NorthEast
	if vel.y < 0 and vel.x > 0:
		char_pos.scale.x = -1
		character.play("roll_northwest_" + imposter_color)
	#Character moves NorthWest
	elif vel.y < 0 and vel.x < 0:
		char_pos.scale.x = 1
		character.play("roll_northwest_" + imposter_color)
	#Character moves East or SouthEast
	elif vel.x > 0:
		char_pos.scale.x = 1
		character.play("roll_southeast_" + imposter_color)
	#Character moves West or SoutWest
	elif vel.x < 0:
		char_pos.scale.x = -1
		character.play("roll_southeast_" + imposter_color)
	#Character moves North
	elif vel.y < 0:
		character.play("roll_north_" + imposter_color)
	#Character moves South
	elif vel.y > 0:
		character.play("roll_south_" + imposter_color)
	#Character not moving (idle)
	else:
		character.play("idle_" + imposter_color)



func _on_Area2D_body_entered(body):
	if "Player" in body.name:
		is_hit = true
		var Player = get_parent().get_node("Player")
		Player.isInverted = true
		set_physics_process(false)
		area2d.queue_free()
		collisionbox.queue_free()
		character.play("explosion")
		#enter health bar stuff here
		Player.take_damage(10)
		print("player got exploded 10 dmg")
		yield(character, "animation_finished")
		print("invert the controls")
		
		
		
		
		queue_free()



func _on_Timer_timeout():
	if !is_hit:
		set_physics_process(false)
		area2d.queue_free()
		collisionbox.queue_free()
		character.play("explosion")
		yield(character, "animation_finished")
		queue_free() # Replace with function body.
	return
