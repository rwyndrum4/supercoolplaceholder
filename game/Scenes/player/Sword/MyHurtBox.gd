"""
* Programmer Name - Jason Truong
* Description - Code for player's sword
* Date Created - 11/20/2022
			
"""
class_name MyHurtBox

extends Area2D

var dmgMod = 0

"""
/*
* @pre Called when made
* @post Initializes the collision layer and mask
* @param None
* @return void
*/
"""
func _init() -> void:
	collision_layer = 0
	collision_mask = 19

"""
/*
* @pre Called once when mob is initialized
* @post Connects the "area_entered" signal for hitboxes
* @param None
* @return None
*/
"""
func _ready() -> void:
	# warning-ignore:return_value_discarded
	connect("area_entered", self, "_on_area_entered")

"""
/*
* @pre Called when area is entered
* @post Player/mob takes damage
* @param Takes in type MyHitBox
* @return void
*/
"""
func _on_area_entered(hitbox: MyHitBox) -> void:
	if hitbox == null:
		return
	#Checks to see if owner is an Arena Enemy (BoD, Skeleton, Chandelier)
	#Also checks if the hitbox is from the sword and not another enemy
	if owner.has_meta("enemy_name") and hitbox.is_in_group("sword"):
		owner.take_damage(hitbox.damage)
	#Player should take damage no matter what hits them
	elif owner.has_meta("player_name"):
		owner.take_damage(hitbox.damage)
	elif owner.has_meta("boss"):
		owner.take_damage(hitbox.damage)
