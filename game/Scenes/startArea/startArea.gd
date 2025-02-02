"""
* Programmer Name - Freeman Spray, Ben Moeller
* Description - Code for controlling what happens in the start area scene
* Date Created - 10/3/2022
* Date Revisions:
	10/4/2022 - Added ability to move into cave and exit scene
	10/8/2022 - Added boundaries to cave, sky, and fire
	3/12/2023 - New transition scene
"""
extends Control


# Member Variables:
const STARS_BUFFER = 3
var in_cave = false
onready var player_one = $Player
onready var instructions: Label = $enterCaveArea/enterDirections
onready var textBox = $GUI/textBox

var other_player = "res://Scenes/player/other_players/other_players.tscn"


"""
/*
* @pre Called when the node enters the scene tree for the first time
* @post runs all statements to initialize the scene (once)
* @param None
* @return None
*/
"""
func _ready():
	#Play stars animation from last frame in main menu
	$Stars.frame = Global.stars_last_frame + STARS_BUFFER
	$Stars.play()
	#If there is a server connection, spawn all players
	if ServerConnection.match_exists() and ServerConnection.get_server_status():
		spawn_players()
	#This is how you queue text to the textbox queue
	textBox.queue_text("If you're ready to begin your challenge, press enter")

"""
/*
* @pre Called for every frame
* @post changes scenes if player presses enter and is in the zone
* @param _delta -> time variable that can be optionally used
* @return None
*/
"""
func _process(_delta): #change to delta if using it
	if in_cave:
		if Input.is_action_just_pressed("ui_accept",false) and not Input.is_action_just_pressed("ui_enter_chat"):
			in_cave = false
			# warning-ignore:return_value_discarded
			$Enter.play()
			#change scene to cave area after Bush Transition finished playing
			BushTrans.change_scene(Global.scenes.CAVE)

"""
/*
* @pre Called when player enters the Ares2D zone
* @post shows instructions on screen and sets in_cave to true
* @param _body -> body of the player
* @return None
*/
"""
func _on_Area2D_body_entered(_body: PhysicsBody2D): #change to body if want to use
	instructions.show()
	in_cave = true

"""
/*
* @pre Called when player exits the Ares2D zone
* @post hides instructions on screen and sets in_cave to false
* @param _body -> body of the player
* @return None
*/
"""
func _on_Area2D_body_exited(_body: PhysicsBody2D): #change to body if want to use
	in_cave = false
	instructions.hide()

"""
/*
* @pre called when players need to be spawned in (assuming server is online)
* @post Spawns players that move with server input and sets position regular player
* @param None
* @return None
*/
"""
func spawn_players():
	for num_str in Global.player_positions:
		#Add animated player to scene
		var num = int(num_str)
		if num == ServerConnection._player_num:
			player_one.position = Global.player_positions[str(num)]
			player_one.set_color(num)
		else:
			var new_player:KinematicBody2D = load(other_player).instance()
			new_player.set_player_id(num)
			new_player.set_color(num)
			new_player.scale = Vector2(0.798, 0.813)
			#Change size and pos of sprite
			new_player.position = Global.player_positions[str(num)]
			#Add child to the scene
			add_child(new_player)
		#Set initial input vectors to zero
		Global.player_input_vectors[str(num)] = Vector2.ZERO
