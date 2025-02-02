"""
* Programmer Name - Freeman Spray, Ben Moeller
* Description - Code for controlling what happens in the entry space scene
* Date Created - 10/3/2022
* Date Revisions:
	10/8/2022 - Added the ability to go into settings from scene with enter key
	11/5/2022 - Added ability to transition to further minigames after the first
* Citations: https://godotengine.org/qa/33196/how-are-you-supposed-to-handle-null-objects
	for handling deleted tiles
"""

extends Control

# Member Variables
const PLAYER_HEALTH = 150
const CAVE_TIME = 90 #how much time players spend in the cave
var in_exit = false #variable to track if character is by the exit
var in_menu = false #variable to track if character is in options menu
var in_well = false #variable to track if character is by well
var in_shop = false #variable to track if character is by shop
var steam_active = false #variable to tell if steam in passage is active
var stop_steam_control = false #variable to tell whether process function needs to check steam
var steam_modulate:float = 0 #modualte value that is gradually added to modulate of steam
var at_lever = false #variable to track if player is at the lever
var at_ladder = false #variable to track if player is at the ladder
var _shield_spawns: Array = [] #array that holds all shield objects
var _shields_available: Array = [] #array that holds if each shield is available or not
var _game_started = false #variable to tell if all players are in scene
var _player_dead = false #variable to track if main player is dead or not
var _enemies: Array = [] #Array of enemy objects
var _imposter_timer: Timer = null #Timer for when imposters will spawn
var dummyBoss #variable to hold the boss when needed
var _besier_arr: Array = [] #array to hold besiers for easy access
var server_players: Array = [] #array to hold all OTHER players in cave (not you)
var other_player = "res://Scenes/player/arena_player/arena_player.tscn" #class for other player's body objects
var imposter = preload("res://Scenes/Mobs/imposter.tscn") #imposter enemies class
var sword = null #sword for the player
var _has_ladder = false
var at_chasm = false

# Scene Objects
onready var confuzzed = $Player/confuzzle
onready var myTimer: Timer = $GUI/Timer
onready var timerText: Label = $GUI/Timer/timerText
onready var textBox = $GUI/textBox
onready var steamAnimations = $steamControl/steamAnimations
onready var secretPanel = $worldMap/Node2D_1/Wall3x3_6
onready var secretPanelCollider1 = $worldMap/Node2D_1/colliders/secretDoor
onready var secretPanelCollider2 = $worldMap/Node2D_1/colliders/secretDoor2
onready var ladder = $worldMap/Node2D_1/Ladder1x1
onready var chasmSpan = $worldMap/Node2D_1/ChasmWithLadder
onready var chasmBarrier = $worldMap/Node2D_1/colliders/ChasmCollider2
onready var pitfall = $worldMap/Node2D_1/Pitfall1x1_2
onready var pitfall2 = $worldMap/Node2D_1/Pitfall1x1_1
onready var wellLabeled = $well/Label
onready var shopLabeled = $shop/Label
onready var wellLabeled2 = $well2/Label
onready var spectate_text = $GUI/spectate_mode
onready var player = $Player
onready var voidLight = $voidLight

onready var storeDisplay = load("res://Scenes/StoreElements/StoreVars.tscn")

"""
/*
* @pre Called when the node enters the scene tree for the first time.
* @post updates starts the timer
* @param None
* @return None
*/
"""
func _ready():
	set_physics_process(false) #turn off physics until game should start
	# Place player in front of shop if they are leaving from it.
	if Global.lastPos == "shop":
		$Player.position = Vector2(-10700, 5150)
		Global.lastPos == "cave"
	#If a player died in an earlier phase, delete their object
	if Global._player_died_final_boss:
		if is_instance_valid(player):
			player.queue_free()
	else:
		player.set_physics_process(false)
		# warning-ignore:return_value_discarded
		player.connect("p1_died", self, "_p1_died")
	$fogSprite.modulate.a8 = 0
	GlobalSignals.emit_signal("toggleHotbar", true)
	wellLabeled.visible = false
	shopLabeled.visible = false
	wellLabeled2.visible = false
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("openChatbox", self, "chatbox_use")
	# warning-ignore:return_value_discarded
	Global.connect("all_players_arrived", self, "_can_start_game")
	# warning-ignore:return_value_discarded
	ServerConnection.connect("minigame_can_start", self, "_can_start_game_other")
	if ServerConnection.match_exists() and ServerConnection.get_server_status():
		ServerConnection.send_spawn_notif()
		spawn_players()
		if ServerConnection._player_num == 1:
			#in case p1 is last player to get to minigame
			if Global.get_minigame_players() == Global.get_num_players() - 1:
				ServerConnection.send_minigame_can_start()
				_game_started = true
				start_cave()
		else:
			#Set a five second timer to wait for other players to spawn in
			var wait_for_start: Timer = Timer.new()
			add_child(wait_for_start)
			wait_for_start.wait_time = Global.WAIT_FOR_PLAYERS_TIME
			wait_for_start.one_shot = true
			wait_for_start.start()
			# warning-ignore:return_value_discarded
			wait_for_start.connect("timeout",self, "_start_timer_expired", [wait_for_start])
	#Start cave scene if single player
	else:
		start_cave()

"""
/*
* @pre Called for every frame
* @post updates timer and changes scenes if player presses enter and is in the zone
* @param _delta -> time variable that can be optionally used
* @return None
*/
"""
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta): #change to delta if used
	if is_instance_valid(myTimer):
		timerText.text = convert_time(myTimer.time_left)
	if not stop_steam_control:
		control_steam()
	#if not in final boss (aka normal cave b4 minigame, don't do rest)
	if not Global._in_final_boss:
		return
	handle_swords()
	#Check if players have lost the game or not
	if check_everyone_dead():
		Global.state = Global.scenes.END_SCREEN
	# Check for completion of boss stage 1
	if Global.progress == 4:
		#besier tracker not needed anymore
		Global.state = Global.scenes.DILEMMA
	if Global.progress == 5:
		load_boss(2)
	if Global.progress == 7:
		load_boss(3)
	#Put all player related code after this, checks if still alive or not
	if not is_instance_valid(player):
		return
	if player.isInverted == true:
		confuzzed.visible = true
	else:
		confuzzed.visible = false

"""
/*
* @pre None
* @post updates the sword positions of ALL players in game
* @param None
* @return None
*/
"""
func handle_swords():
	#Server player's swords
	for p in server_players:
		var p_obj = p.get('player_obj')
		if is_instance_valid(p_obj):
			var x = 60 if p['sword_dir'] == "right" else -60
			p_obj._pivot.position = Vector2(x,0)
	#Check whether player or sword are invalid
	if not is_instance_valid(player):
		return
	if not is_instance_valid(sword):
		return
	#main player's sword
	if sword.direction == "right":
		sword.get_node("pivot").position = player.position + Vector2(60,0)
	elif sword.direction == "left":
		sword.get_node("pivot").position = player.position + Vector2(-60,0)

"""
/*
* @pre An input of any sort
* @post None
* @param Takes in an event
* @return None
*/
"""
func _input(_ev):
	if in_well and is_instance_valid(dummyBoss):
		if Input.is_action_just_pressed("ui_press_e",false) and dummyBoss.get_vulnerable_status():
			dummyBoss._set_invulnerability(false)
			ServerConnection.send_boss_vulnerability()
			var wait_for_start: Timer = Timer.new()
			add_child(wait_for_start)
			wait_for_start.wait_time = 20
			wait_for_start.one_shot = true
			wait_for_start.start()
			# warning-ignore:return_value_discarded
			wait_for_start.connect("timeout",self, "_shield_up_boss",[wait_for_start])
	if in_exit:
		if Input.is_action_just_pressed("ui_accept",false) and not Input.is_action_just_pressed("ui_enter_chat"):
			# warning-ignore:return_value_discarded
			Global.state = Global.scenes.MAIN_MENU #change scene to main menu
	if at_lever:
		if Input.is_action_just_pressed("ui_accept",false) and not Input.is_action_just_pressed("ui_enter_chat"):
			if is_instance_valid(secretPanel):
				secretPanel.queue_free()
			if is_instance_valid(secretPanelCollider1):
				secretPanelCollider1.queue_free()
			if is_instance_valid(secretPanelCollider2):
				secretPanelCollider2.queue_free()
	if at_ladder and is_instance_valid(ladder):
		if Input.is_action_just_pressed("ui_accept",false) and not Input.is_action_just_pressed("ui_enter_chat"):
			ladder.texture = $root/Assets/tiles/TilesCorrected/WallTile_Tilt_Horiz
			_has_ladder = true
	if at_chasm and _has_ladder:
		if Input.is_action_just_pressed("ui_accept",false) and not Input.is_action_just_pressed("ui_enter_chat"):
			print("got chasm")
			if is_instance_valid(chasmBarrier):
				chasmBarrier.queue_free()
			chasmSpan.show()
			_has_ladder = false
	if in_shop:
		if Input.is_action_just_pressed("ui_press_e",false):
			Global.lastPos = "shop"
			Global.state = Global.scenes.MARKET_CAVE
	#Spectator mode stuff
	if _player_dead and len(server_players) > 0:
		if Input.is_action_just_pressed("jump",false):
			change_spectator()

"""
/*
* @pre Called once start time expires (happens once)
* @post deletes timer and starts game if necessary
* @param timer -> Timer
* @return None
*/
"""
func _start_timer_expired(timer):
	timer.queue_free()
	if not _game_started:
		_game_started = true
		start_cave()

"""
/*
* @pre Called once all players have spawned into the minigame
* 	only run by PLAYER 1
* @post sends signal to other players to start, and start game
* @param None
* @return None
*/
"""
func _can_start_game():
	_game_started = true
	ServerConnection.send_minigame_can_start()
	start_cave()

"""
/*
* @pre Called when non-player 1 player receives signal to start game
* @post starts the game if timer hasn't already done it for it
* @param None
* @return None
*/
"""
func _can_start_game_other():
	if not _game_started:
		_game_started = true
		start_cave()

"""
* @pre all conditions have been met to start cave section
* @post starts time and sets other variables
* @param None
* @return None
"""
func start_cave():
	set_physics_process(true)
	#Start timer if not inside of the final boss
	if Global.minigame < 4:
		myTimer.start(CAVE_TIME)
	else:
		myTimer.queue_free()
	#Check if main player is alive, send to spectate mode if not
	if is_instance_valid(player):
		player.set_physics_process(true)
	else:
		spectate_mode()
	Global.reset_minigame_players() #Reset player trackers for next game
	$GUI/wait_on_players.hide() #Hide waiting for players text

"""
* @post sets in_cave to true
* @param _body -> body of the player
* @return None
"""
func _on_exitCaveArea_body_entered(_body: PhysicsBody2D): #change to body if want to use
	in_exit = true
	
"""
/*
* @pre Called when player exits the Area2D zone
* @post sets in_cave to false
* @param _body -> body of the player
* @return None
*/
"""
func _on_exitCaveArea_body_exited(_body: PhysicsBody2D): #change to body if want to use
	in_exit = false
	
"""
/*
* @pre Called when need to convert seconds to MIN:SEC format
* @post Returns string of current time
* @param time_in -> float 
* @return String (text of current time left)
*/
"""
func convert_time(time_in:float) -> String:
	var rounded_time = int(time_in)
	var minutes: int = rounded_time/60
	var seconds = rounded_time - (minutes*60)
	if seconds < 10:
		seconds = str(0) + str(seconds)
	return str(minutes,":",seconds)

"""
/*
* @pre Called when the timer hits 0
* @post Changes scene to minigame
* @param None
* @return String (text of current time left)
*/
"""
func _on_Timer_timeout():
	#change scene to riddler minigame
	if Global.minigame == 0:
		Global.minigame = 1
		Global.state = Global.scenes.RIDDLER_MINIGAME
	#change scene to arena minigame
	elif Global.minigame == 1:
		Global.minigame = 2
		Global.state = Global.scenes.ARENA_MINIGAME
	#change scene to rhythm minigame
	elif Global.minigame == 2:
		Global.minigame = 3
		Global.state = Global.scenes.RHYTHM_INTRO
	elif Global.minigame == 3:
		Global.minigame = 4
		load_boss(1)
		myTimer.queue_free() #timer not needed for final boss

"""
/*
* @pre None
* @post Sets in_menu to true
* @param value
* @return None
*/
"""
func chatbox_use(value):
	if value:
		in_menu = true

"""
/*
* @pre Fog is enterred from the right side of the passage
* @post activates/deactivates steam based on side entered from
* @param _area -> Area2D node
* @return None
*/
"""
func _on_right_side_area_entered(area):
	if not area.is_in_group("player") or (not is_instance_valid(player)):
		return
	var pos = player.position
	if pos.x > -1200.0:
		steam_area_activated()
	else:
		steam_area_deactivated()

"""
/*
* @pre Fog is enterred from the left side of the passage
* @post activates/deactivates steam based on side entered from
* @param _area -> Area2D node
* @return None
*/
"""
func _on_left_side_area_entered(area):
	if not area.is_in_group("player") or (not is_instance_valid(player)):
		return
	var pos = player.position
	if pos.x < -5800:
		steam_area_activated()
	else:
		steam_area_deactivated()

"""
/*
* @pre None
* @post turns on and shows animations
* @param None
* @return None
*/
"""
func steam_area_activated():
	$fogSprite.show()
	steam_active = true
	stop_steam_control = false
	steam_modulate = 0.0
	for object in steamAnimations.get_children():
		object.frame = 0
		object.show()
		object.play("mist")

"""
/*
* @pre None
* @post turns off and hides animations
* @param None
* @return None
*/
"""
func steam_area_deactivated():
	steam_active = false
	for object in steamAnimations.get_children():
		object.hide()
		object.stop()

"""
/*
* @pre There is a match with other players
* @post spawn all players that are not your character
* @param None
* @return None
*/
"""
func spawn_players():
	#set initial position the players should be on spawn
	set_init_player_pos()
	#num_str is the player number (1,2,3,4)
	for num_str in Global.player_positions:
		#Add animated player to scene
		var num = int(num_str)
		#if player is YOUR player (aka player you control), and you are alive ^_
		if num == ServerConnection._player_num and is_instance_valid(player):
			player.position = Global.player_positions[str(num)]
			player.set_color(num)
		#if the player is another online player
		else:
			var new_player:KinematicBody2D = load(other_player).instance()
			new_player.set_player_id(num)
			new_player.set_color(num)
			new_player.sword_visibility(false)
			new_player.healthbar_visibility(false)
			#Change size and pos of sprite
			new_player.position = Global.player_positions[str(num)]
			#Add child to the scene
			add_child(new_player)
			server_players.append({
				'num': num,
				'player_obj': new_player,
				'sword_dir': "right"
			})
		#Set initial input vectors to zero
		Global.player_input_vectors[str(num)] = Vector2.ZERO

"""
/*
* @pre None
* @post function to gradually make fog come into view
* @param None
* @return None
*/
"""
func control_steam():
	var fog_modulate = $fogSprite.modulate.a8
	if steam_active and fog_modulate != 128:
		steam_modulate += 0.5
		if int(steam_modulate) % 2 == 0:
			$fogSprite.modulate.a8 = steam_modulate
	elif not steam_active and fog_modulate != 0:
		steam_modulate -= 0.5
		if int(steam_modulate) % 2 == 0:
			$fogSprite.modulate.a8 = steam_modulate
	elif fog_modulate == 0 and not steam_active:
		$fogSprite.hide()
		stop_steam_control = true
		
"""	
* @pre Called when player enters the lever's Area2D zone
* @post sets at_lever to true (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""
func _on_leverArea_body_entered(_body: PhysicsBody2D): #change to body if want to use
	at_lever = true

"""
/*
* @pre Called when player exits the lever's Area2D zone
* @post sets at_lever to false (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""
func _on_leverArea_body_exited(_body: PhysicsBody2D): #change to body if want to use
	at_lever = false

"""
/*
* @pre Called when player enters the ladder's Area2D zone
* @post sets at_ladder to true (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""
func _on_ladderArea_body_entered(_body: PhysicsBody2D): #change to body if want to use
	at_ladder = true

"""
/*
* @pre Called when player exits the ladder's Area2D zone
* @post sets at_ladder to false (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""
func _on_ladderArea_body_exited(_body: PhysicsBody2D): #change to body if want to use
	at_ladder = false

"""
/*
* @pre Called when player enters the chasm's Area2D zone
* @post sets at_chasm to true (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""	
func _on_chasmArea_body_entered(_body: PhysicsBody2D):
	at_chasm = true

"""
/*
* @pre Called when player exits the chasm's Area2D zone
* @post sets at_chasm to false (for interactability purposes)
* @param _body -> body of the player
* @return None
*/
"""
func _on_chasmArea_body_exited(_body: PhysicsBody2D):
	at_chasm = false

"""
/*
* @pre Called when player enters the pitfall's Area2D zone
* @post replaces the tile with a pit of spikes
* @param _body -> body of the player
* @return None
*/
"""
func _on_pitfallArea_body_entered(_body: PhysicsBody2D): #change to body if want to use
	if Global._in_final_boss:
		pitfall.texture = load("res://Assets/tiles/TilesCorrected/SpikesPixelated.png")
		player.take_damage(30)

"""
/*
* @pre Called when player enters the pitfall's Area2D zone
* @post replaces the tile with a pit of spikes
* @param _body -> body of the player
* @return None
*/
"""	
func _on_pitfallArea2_body_entered(_body: PhysicsBody2D): #change to body if want to use
	if Global._in_final_boss:
		pitfall2.texture = load("res://Assets/tiles/TilesCorrected/SpikesPixelated.png")
		player.take_damage(30)

"""
/*
* @pre None
* @post update the global player positions for player spawn positions
* @param None
* @return None
*/
"""
func set_init_player_pos():
	#num_str is the player number (1,2,3,4)
	for num_str in Global.player_positions:
		var num = int(num_str)
		match num:
			1: Global._player_positions_updated(num,Vector2(800,1550))
			2: Global._player_positions_updated(num,Vector2(880,1550))
			3: Global._player_positions_updated(num,Vector2(800,1450))
			4: Global._player_positions_updated(num,Vector2(880,1450))
			_: printerr("THERE ARE MORE THAN 4 PLAYERS TRYING TO BE SPAWNED IN EntrySpace.gd")

"""
/*
* @pre Called by the timer after it reaches 0 when all minigames have been completed.
* @post begins the final boss fight
* @param None
* @return Currently, timer stops and four bezier objects spawn
*/
"""
func load_boss(stage_num:int):
	Global._in_final_boss = true
	var boss = preload("res://Scenes/FinalBoss/Boss.tscn").instance()
	_enemies.append(boss)
	dummyBoss = boss #global variable that holds boss obj, use if desired
	# warning-ignore:return_value_discarded
	ServerConnection.connect("arena_enemy_hit",self,"_someone_hit_enemy")
	# warning-ignore:return_value_discarded
	ServerConnection.connect("arena_player_lost_health",self,"_other_player_hit")
	# warning-ignore:return_value_discarded
	ServerConnection.connect("arena_player_swung_sword",self,"_other_player_swung_sword")
	#What to do for each stage
	if stage_num == 1:
		stage_1()
	elif stage_num == 2:
		stage_2()
	elif stage_num == 3:
		stage_3(boss)
	spawn_shields() #shield spawns now show up in 3 places
	give_players_combat_power() #Unhide player swords, and show ONLY your own healthbar
	# Initialize, place, and spawn boss
	boss.set("position", Vector2(-4250, 2160))
	add_child_below_node($worldMap, boss)
	if is_instance_valid(player):
		# Zoom out camera so player can view Mendax in all his glory
		player.get_node("Camera2D").set("zoom", Vector2(2, 2))

"""
/*
* @pre None
* @post sets everything for stage 1
* @param None
* @return None
*/
"""
func stage_1() -> void:
	#Intro dialogue for stage 1
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: Well done on your efforts in the games")
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: The finale starts now")
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: You must first light up the cave before challenging me")
	ServerConnection.connect("final_boss_besier_lit", self, "_besier_was_lit")
	# Generate beziers
	var bez1 = preload("res://Scenes/FinalBoss/Bezier.tscn").instance()
	var bez2 = preload("res://Scenes/FinalBoss/Bezier.tscn").instance()
	var bez3 = preload("res://Scenes/FinalBoss/Bezier.tscn").instance()
	var bez4 = preload("res://Scenes/FinalBoss/Bezier.tscn").instance()
	_besier_arr = [bez1, bez2, bez3, bez4]
	# Assign ids (for the purpose of differentiating signals)
	bez1._id = 1
	bez2._id = 2
	bez3._id = 3
	bez4._id = 4
	# Place beziers
	bez1.set("position", Vector2(2750, 2000))
	bez2.set("position", Vector2(1500, 0))
	bez3.set("position", Vector2(-10000, 4000))
	bez4.set("position", Vector2(-7750, 3250))
	# Add beziers to scene
	add_child_below_node($Darkness, bez1)
	add_child_below_node($Darkness, bez2)
	add_child_below_node($Darkness, bez3)
	add_child_below_node($Darkness, bez4)
	add_player_sword()

"""
/*
* @pre None
* @post sets everything for stage 2
* @param None
* @return None
*/
"""
func stage_2() -> void:
	# Light up the cave
	$Darkness.hide()
	# Hide light from cave entrance
	$Light2D.hide()
	# Hide player torch light
	Global.progress = 6
	if not is_instance_valid(player):
		return
	#Intro dialogue for stage 2
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: Welcome back to the cave")
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: Your decisions have been noted, continue the fight")
	player.get_node("light/Torch1").hide()
	add_player_sword()
	#imposter spawns
	_imposter_timer = Timer.new()
	add_child(_imposter_timer)
	_imposter_timer.wait_time = 5
	_imposter_timer.one_shot = false
	_imposter_timer.start()
	# warning-ignore:return_value_discarded
	_imposter_timer.connect("timeout",self, "_imposter_spawn")

"""
/*
* @pre None
* @post sets everything for stage 3
* @param None
* @return None
*/
"""
func stage_3(boss) -> void:
	# Light up the cave
	$Darkness.hide()
	# Hide light from cave entrance
	$Light2D.hide()
	spawn_stage_three_enemies() #spawn enemies from arena
	boss._set_invulnerability(true)
	Global.progress = 8
	#Don't setup player stuff if they are already dead
	if not is_instance_valid(player):
		return
	#Intro dialogue for stage 3
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: I have gained immortality")
	textBox.queue_text("[color=#c71e1e]Mendax[/color]: There might be a way to cleanse it, or not, who knows?")
	player.get_node("light/Torch1").hide() # Hide player torch light
	add_player_sword()
	#imposter spawns
	var wait_for_start: Timer = Timer.new()
	add_child(wait_for_start)
	wait_for_start.wait_time = 5
	wait_for_start.one_shot = false
	wait_for_start.start()
	# warning-ignore:return_value_discarded
	wait_for_start.connect("timeout",self, "_imposter_spawn")

"""
/*
* @pre None
* @post adds the player's sword to the scene
* @param None
* @return None
*/
"""
func add_player_sword():
	# Give player a sword
	sword = preload("res://Scenes/player/Sword/Sword.tscn").instance()
	sword.direction = "right"
	sword.get_node("pivot").position = player.position + Vector2(60,20)
	add_child_below_node(player, sword)
	sword.add_to_group("sword")

"""
/*
* @pre Inside of combat phase in final boss
* @post Turns on healthbars and swords for players
* @param None
* @return None
*/
"""
func give_players_combat_power():
	if is_instance_valid(player):
		$Player/ProgressBar.value = PLAYER_HEALTH
		player.healthbar_visibility(true)
	for o_player in server_players:
		var p_obj = o_player.get('player_obj')
		if is_instance_valid(p_obj):
			p_obj.sword_visibility(true) #always show swords
			#Show other players health bars if you are spectating
			if not is_instance_valid(player):
				p_obj.healthbar_visibility(true)

"""
/*
* @pre None
* @post Shields are spawned in the game
* @param None
* @return None
*/
"""
func spawn_shields():
	# warning-ignore:return_value_discarded
	ServerConnection.connect("character_took_shield",self,"someone_took_shield")
	var shield_positions = [
		Vector2(-4000,3000), #In middle by boss
		Vector2(-7850, 5250), #In bottom left
		Vector2(750, 3000) #On the right side
	]
	var inc = 0
	for pos in shield_positions:
	# Generate shild spawn
		create_shield(pos, inc)
		inc += 1

"""
/*
* @pre None
* @post Helper function to place a shield for a certain position
* @param None
* @return None
*/
"""
func create_shield(spawn_pos: Vector2, shield_id: int):
	var shield_spawn = Area2D.new()
	var col_2d = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.set_radius(80)
	col_2d.set_shape(shape)
	shield_spawn.position = spawn_pos
	var shield_sprite = Sprite.new()
	var spawn_sprite = Sprite.new()
	shield_sprite.texture = load("res://Assets/shieldFull.png")
	shield_sprite.scale = Vector2(1.5,1.5)
	shield_sprite.position = spawn_pos
	shield_sprite.set_name("shield_sprite" + str(shield_id))
	spawn_sprite.texture = load("res://Assets/shield_spawn.png")
	spawn_sprite.scale = Vector2(4,4)
	spawn_sprite.position = spawn_pos
	add_child(shield_spawn)
	shield_spawn.add_child(col_2d)
	add_child_below_node(shield_spawn,shield_sprite)
	add_child_below_node(shield_spawn,spawn_sprite)
	shield_spawn.connect("area_entered",self,"give_shield", [shield_id])
	_shield_spawns.append(shield_spawn)
	_shields_available.append(true)
	
"""
/*
* @pre Called when a player grabs a shield from spawn
* @post give player shield and let server know its taken
* @param area
* @return None
*/
"""
func give_shield(area, s_id):
	if area.is_in_group("player") and _shields_available[s_id]:
		if not is_instance_valid(player):
			return
		ServerConnection.send_shield_notif(s_id)
		_shields_available[s_id] = false
		player.shield.giveShield()
		get_node("shield_sprite" + str(s_id)).hide()
		start_shield_timer(s_id)

"""
/*
* @pre Shield was stepped on
* @post start timer to respawn shield when done
* @param None
* @return None
*/
"""
func start_shield_timer(shield_id):
	var s_tmr: Timer = Timer.new()
	add_child(s_tmr)
	s_tmr.wait_time = 15
	s_tmr.one_shot = true
	s_tmr.start()
	# warning-ignore:return_value_discarded
	s_tmr.connect("timeout",self, "_respawn_shield", [s_tmr, shield_id])

"""
* @pre Called when server says someone stepped on shield
* @post Shield becomes unavailable for a time period
* @param p_id -> int (player who stepped on it)
*		 shield_num -> int (which spawn it was)
* @return None
"""
func someone_took_shield(player_id,_shield_num):
	_shields_available[_shield_num] = false
	get_node("shield_sprite" + str(_shield_num)).hide()
	start_shield_timer(_shield_num)
	for o_player in server_players:
		var p_obj = o_player.get('player_obj')
		if player_id == o_player.get('num') and is_instance_valid(p_obj):
			p_obj.shield.giveShield()
			break

"""
/*
* @pre Timer went off
* @post respawn the shield
* @param tmr (timer to get rid of)
* @return None
*/
"""
func _respawn_shield(tmr:Timer, shield_id:int):
	tmr.queue_free()
	_shields_available[shield_id] = true
	get_node("shield_sprite" + str(shield_id)).show()

"""
/*
* @pre Called once start time expires (happens once)
* @post deletes timer and starts game if necessary
* @param timer -> Timer
* @return None
*/
"""
func _imposter_spawn():
	if not is_instance_valid(player):
		return
	var new_imposter = imposter.instance()
	new_imposter.setup_pos(player.position)
	add_child(new_imposter)

"""
* @pre Stage 3 of final boss has started
* @post spawns extra enemies to make the stage harder
* @param None
* @return None
"""
func spawn_stage_three_enemies():
	var slow_enemy = load("res://Scenes/minigames/arena/littleGuy.tscn")
	var slow_en_proerties = [
		[Vector2(-6000,3000), 600, 3500],
		[Vector2(-500, 1000), 300, 6000],
		[Vector2(0, 3000), 500, 4500],
		[Vector2(-10000, 5000), 500, 4000],
		[Vector2(-8500, 3000), 400, 3800],
		[Vector2(-10000, 6200), 250, 3900],
	]
	for prop_arr in slow_en_proerties:
		var slow_en = slow_enemy.instance()
		slow_en.position = prop_arr[0]
		slow_en.set_max_dir(prop_arr[1])
		slow_en.ACCELERATION = prop_arr[2]
		add_child(slow_en)

func _on_well_body_entered(body):
	if Global.progress == 8:
		if "Player" in body.name:
			if player.position.x > -3700:
				wellLabeled.visible = true
			else:
				wellLabeled2.visible = true
			in_well = true

func _on_well_body_exited(body):
	if Global.progress == 8:
		if "Player" in body.name:
			if player.position.x > -3700:
				wellLabeled.visible = false
			else:
				wellLabeled2.visible = false
			in_well = false

func _shield_up_boss(timer):
	timer.queue_free()
	if is_instance_valid(dummyBoss):
		dummyBoss._set_invulnerability(true)

"""
* @pre Someone else lit up a besier
* @post light the besier and emit message
* @param who -> int (player num of who lit it)
* 		 besier_id -> int (id of besier lit)
* @return None
"""
func _besier_was_lit(who: int, besier_id: int):
	for bes in _besier_arr:
		if bes._id == besier_id:
			#if besier is already lit get out
			if bes._lit == 2:
				break
			#else light up besier
			bes._lit = 1
			bes.someone_lit_besier() #function to light it
			var who_did_it: String = Global.get_player_name(who)
			#Add message to chat on who did it
			GlobalSignals.emit_signal(
				"exportEventMessage",
				who_did_it + " lit up besier " + str(besier_id),
				"blue"
			)
			break

"""
* @pre Someone else hit an enemy
* @post lower the enemy's health
* @param enemy_id (id of enemy aka where to index)
*		 dmg_taken (amount of health to subtract)
*		 player_id (who hit the enemy)
*		 enemy_type (type of enemy represented as a String)
* @return None
"""
func _someone_hit_enemy(enemy_id: int, dmg_taken: int, _player_id: int,enemy_type:String):
	if enemy_type == "Boss":
		_enemies[enemy_id].take_damage_server(dmg_taken)

"""
/*
* @pre received update from server
* @post updates the health of player that was hit
* @param player_id -> int (id of player hit), player_health -> int (new health value)
* @return None
*/
"""
func _other_player_hit(player_id: int, player_health: int):
	for o_player in server_players:
		if player_id == o_player.get('num'):
			var p_obj = o_player.get('player_obj')
			if is_instance_valid(p_obj):
				p_obj.take_damage(player_health)
			Global.player_health[str(player_id)]=player_health
			break

"""
/*
* @pre received update from server
* @post game sets player who swung to swing their sword
* @param player_id -> int (number of player to be updated)
* @return None
*/
"""
func _other_player_swung_sword(player_id: int, direction: String):
	for o_player in server_players:
		var p_obj = o_player.get('player_obj')
		if player_id == o_player.get('num') and is_instance_valid(p_obj):
			o_player['sword_dir'] = direction
			p_obj.swing_sword(direction)
			break

"""
/*
* @pre main player died
* @post turns on spectate mode and checks if game over
* @param None
* @return None
*/
"""
func _p1_died():
	$fogSprite.hide()
	if is_instance_valid(sword):
		sword.queue_free()
	_player_dead = true
	Global._player_died_final_boss = true
	#No more imposter spawns
	if is_instance_valid(_imposter_timer):
		_imposter_timer.disconnect("timeout",self, "_imposter_spawn")
		_imposter_timer.queue_free()
	spectate_mode()
	if check_everyone_dead():
		Global.state = Global.scenes.END_SCREEN

"""
/*
* @pre player died
* @post turns on spectate mode where you can swap to other players
* @param None
* @return None
*/
"""
func spectate_mode():
	spectate_text.show()
	$GUI/spectate_instructions.show()
	var spec_one = true
	for p in server_players:
		var p_obj = p.get('player_obj')
		if not is_instance_valid(p_obj):
			continue
		var spec_cam = Camera2D.new()
		p_obj.add_child(spec_cam)
		p['camera'] = spec_cam
		p['current_camera'] = false
		if spec_one:
			p['current_camera'] = true
			var p_name = Global.get_player_name(p.get('num'))
			change_spectate_text(p_name)
			spec_cam.clear_current()
			spec_cam.make_current()
			spec_one = false

"""
/*
* @pre None
* @post checks if game over, returns bools for answer
* @param None
* @return bool (true = game over, false otherwise)
*/
"""
func check_everyone_dead() -> bool:
	var server_players_dead = true
	for p in server_players:
		if is_instance_valid(p.get('player_obj')):
			server_players_dead = false
	return (_player_dead and server_players_dead)

"""
/*
* @pre None
* @post changes the text that says who you are watching
* @param new_player (who you are watching now)
* @return None
*/
"""
func change_spectate_text(new_player:String):
	spectate_text.text = "Spectating " + new_player

"""
/*
* @pre None
* @post changes who you are watching
* @param None
* @return None
*/
"""
func change_spectator():
	var next = false
	#Iterate through all of the players
	for p in server_players:
		var p_obj = p.get('player_obj')
		if not is_instance_valid(p_obj):
			continue
		if p['current_camera'] == true:
			p['current_camera'] = false
			next = true
		elif next:
			next = false
			p['current_camera'] = true
			p['camera'].clear_current()
			p['camera'].make_current()
			var p_name = Global.get_player_name(p.get('num'))
			change_spectate_text(p_name)
			break
	#If last player was the one who had the camera
	if next:
		for p in server_players:
			var p_obj = p.get('player_obj')
			if not is_instance_valid(p_obj):
				continue
			else:
				p['current_camera'] = true
				p['camera'].clear_current()
				p['camera'].make_current()
				var p_name = Global.get_player_name(p.get('num'))
				change_spectate_text(p_name)
				break

"""
/*
* @pre Called when player enters the shop's Area2D zone
* @post allows player to interact with the shop
* @param body -> body of the player
* @return None
*/
"""
func _on_shop_body_entered(body):
	if "Player" in body.name:
		shopLabeled.visible = true
		in_shop = true

"""
/*
* @pre Called when player exits the shop's Area2D zone
* @post removes ability of player to interact with the shop
* @param body -> body of the player
* @return None
*/
"""
func _on_shop_body_exited(body):
	if "Player" in body.name:
		shopLabeled.visible = false
		in_shop = false

"""
/*
* @pre Called when player enters the shop's Area2D zone
* @post destroys the void and applies the Cloak of Darkness to the player that entered it
* @param body -> body of the player
* @return None
*/
"""
func _on_void_body_entered(body):
	if "Player" in body.name:
		body.get_node("CloakOfDarkness").show()
		Global.isCloaked = true
		voidLight.queue_free()
