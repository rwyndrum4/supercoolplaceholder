"""
* Programmer Name - Ben Moeller, Freeman Spray, Jason Truong, Mohit Garg, Will Wyndrum
* Description - File for controlling the what happens with actions within the main menu
* Date Created - 9/16/2022
* Date Revisions:
	9/17/2022 - Added options menu functionality
	9/18/2022 - Added join code functionality
	9/21/2022 - Fixing issue with fps label not working correctly
	10/1/2022 - Added the ability to move with keyboard in settings menu
	10/1/2022 - Fixed options menu movment
	11/4/2022 - Adding server functionality 
	11/13/2022 - add test functionality
	12/19/2022 - fixed bugs dealing with players spawning
	1/10/2022 - Adding ability to swap to match chat
	1/29/2023 - added sfx for buttons
	4/22/2023 - Added textbox for tutorial
"""
extends Control

# Member Variables
onready var startButton = $menuButtons/Start
onready var code_line_edit = $joinLobby/enterLobbyCode
onready var textbox = $textBox
onready var blink = $"Blink(#Blackpink_Fan)/AnimationPlayer"
onready var canvasVis = $"Blink(#Blackpink_Fan)"
#### Variables for showing players on rocks ###
#array for holding player objects that are created
var player_objects: Array = [] 
#scene that holds the idle player animation
var idle_player = "res://Scenes/player/idle_player/idle_player.tscn"
#array that holds the animation names
var animation_names: Array = ["blue_idle","red_idle","green_idle","orange_idle"]
#current number of players in menu
var num_players: int = 0
#max players allowed
const MAX_PLAYERS: int = 4
#value to scale up animated sprites
const SCALE_VAL = Vector2(3,3)


### Member Variables ###
#popup that is displayed when creating a new game
var game_init_popup:AcceptDialog
#popup that is displayed need to get user's username
var get_user_input:AcceptDialog
#bool to let menu know if player is typing code
var typing_code: bool = false
#code for multiplayer match
var _match_code: String = ""

"""
/*
* @pre called when main menu is loaded in (run once)
* @post runs preliminary code to help user functionality
* @param None
* @return None
*/
"""
func _ready():
	canvasVis.visible = false
	initialize_menu()
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("textbox_empty", self, "tutorial_textbox")
	GlobalSignals.emit_signal("toggleHotbar", false)
	# warning-ignore:return_value_discarded
	ServerConnection.connect("character_spawned",self,"spawn_character")
	# warning-ignore:return_value_discarded
	ServerConnection.connect("character_despawned",self,"despawn_character")
	for button in get_tree().get_nodes_in_group("my_buttons"):
		button.connect("mouse_entered", self, "_mouse_button_entered")
		button.connect("focus_entered", self, "_mouse_button_entered")
		button.connect("button_down", self, "_button_down")
	#after getting out of tutorial
	if Global.anim_id == 2:
		canvasVis.visible = true
		blink.play("BLIIIINK_BLIIIIIINK")
		yield(blink, "animation_finished")
		textbox.queue_text("How did I get here?")
		startButton.release_focus()
		canvasVis.visible = false

"""
/*
* @pre called for every frame inside of the game
* @post detects user input
* @param delta -> float (time)
* @return None
*/
"""
func _process(_delta): #if you want to use delta, then change it to delta
	if typing_code and Input.is_action_just_pressed("ui_cancel"):
		startButton.grab_focus()
		code_line_edit.hide()
	if Input.is_action_just_pressed("ui_cancel"):
		startButton.grab_focus()


"""
/*
* @pre Start Button is pressed
* @post Scene change to start of game
* @param None
* @return None
*/
"""
func _on_Start_pressed():
	#delete player objects
	for player in player_objects:
		delete_player_obj(player['player_obj'],player['text_obj'])
	if ServerConnection.match_exists() and ServerConnection.get_server_status():
		if num_players == 1:
			ServerConnection._player_num = 1
			GlobalSignals.emit_signal(
				"exportEventMessage",
				"Disconnecting from match, single player mode started",
				"white"
			)
			yield(ServerConnection.leave_match(ServerConnection._match_id), "completed")
			yield(ServerConnection.leave_match_group(), "completed")
			yield(ServerConnection.leave_match_group_chat(), "completed")
			ServerConnection.switch_chat_methods() #switch back to using global chat
			yield(ServerConnection.join_chat_async_general(), "completed") #rejoin global chat
		else:
			yield(ServerConnection.leave_general_chat(), "completed")
	else:
		ServerConnection._player_num = 1
		Global.player_names["1"] = Save.game_data.username
	#change scene to start area
	GlobalSignals.emit_signal("show_money_text", true)
	GlobalSignals.emit_signal("money_screen_val")
	GameLoot.init_players(len(Global.player_names))
	Global.stars_last_frame = $Stars.frame
	SceneTrans.change_scene(Global.scenes.START_AREA)

"""
/*
* @pre Options Button is pressed
* @post Scene change to options menu
* @param None
* @return None
* @knownFaults pop-up size and location depends not only on whether the screen is windowed or fullscreen,
*   but also whether the market has been entered in the current iteration of the game
* @knownFaults animated fire does not anchor to its position when the screen is adjusted
*/
"""
func _on_Options_pressed():
	#Open the options pop-up menu
	Global.state = Global.scenes.OPTIONS_FROM_MAIN

"""
/*
* @pre Market Button is pressed
* @post Scene change to store scene
* @param None
* @return None
* @knownFaults resets join code to default (XXXX)
*/
"""
func _on_Market_pressed():
	#When button pressed switches to Store scene
	Global.state = Global.scenes.MARKET

"""
/*
* @pre Tutorial Button is pressed
* @post load tutorial
* @param None
* @return None
*/
"""
func _on_Tutorial_pressed():
	#Global.state = Global.scenes.CAVE
	SceneTrans.change_scene(Global.scenes.TUTORIAL)

"""
/*
* @pre Credits Button is pressed
* @post Load a window with credits
* @param None
* @return None
*/
"""
func _on_Credits_pressed():
	#Tell globalScope to open credits popup
	Global.state = Global.scenes.CREDITS

"""
/*
* @pre Quit Button is pressed
* @post Application is closed
* @param None
* @return None
*/
"""
func _on_Quit_pressed():
	#If player was in a lobby, force them to leave
	if ServerConnection.match_exists():
		ServerConnection.leave_match(ServerConnection._match_id)
		ServerConnection.leave_match_group()
	#Quit out of the game
	get_tree().quit()

"""
/*
* @pre "Get Code" Button is pressed
* @post Generate and display string of four random letters in the "code" RichTextLabel
* @param None
* @return None
*/
"""
func generate_random_code() -> String:
	var letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 
				   'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 
				   'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',]
	var rng = RandomNumberGenerator.new()
	var index1 = getRandAlphInd(rng)
	var index2 = getRandAlphInd(rng)
	var index3 = getRandAlphInd(rng)
	var index4 = getRandAlphInd(rng)
	return letters[index1] + letters[index2] + letters[index3] + letters[index4]
	
"""
/*
* @pre Helper function to _on_GetCode_button_up(). Only called within the context of the function
* @post Generate a random number between 1 and 26 (inclusive)
* @param rng, a RandomNumberGenerator class object
* @return randomAlphabetIndex, the random number generated using rng.
*/
"""
func getRandAlphInd(rng):
		rng.randomize()
		var randomAlphabetIndex = rng.randi_range(0, 25)
		return randomAlphabetIndex

"""
/*
* @pre Called in ready func
* @post Initialize necessary components in menu
* @param None
* @return None
*/
"""
func initialize_menu():
	$Stars.play("default")
	GlobalSignals.emit_signal("show_money_text", false)
	#Grab focus on start button so keys can be used to navigate buttons
	if Global.anim_id != 2:
		startButton.grab_focus()
	#reset any online stuff if they came from a previous game
	reset_multiplayer()
	#If chat has not been swapped back from previous game 
	if not ServerConnection._is_global_chat:
		Global.reset() #reset all global variables needed for next game if played
		ServerConnection.switch_chat_methods() #switch back to using global chat
		ServerConnection.join_chat_async_general() #rejoin global chat
		GlobalSignals.emit_signal(
			"exportEventMessage",
			"Swapped back to global chat, please create a new game if desired",
			"pink"
		)
		GlobalSignals.emit_signal(
			"exportEventMessage",
			"Match list cleared, please create or join a newly created match",
			"blue"
		)
	#check if there is a username
	if Save.game_data.username == "":
		var win_text = "Welcome to Mendax!"
		var d_text = "Username required!\nPlease enter username:\n"
		d_text += "(Single word, you can change it afterward in settings)"
		create_get_user_window(win_text,d_text)

"""
/*
* @pre Called on main menu initialization
* @post Resets any of the multiplayer parts of the game
* @param None
* @return None
*/
"""
func reset_multiplayer():
	#Reset multiplayer match
	if ServerConnection.match_exists():
		yield(ServerConnection.leave_match(ServerConnection._match_id), "completed")
		yield(ServerConnection.leave_match_group(), "completed")
		yield(ServerConnection.leave_match_group_chat(), "completed")
	_match_code = ""
	#Delete any leftover objects
	for player in player_objects:
		delete_player_obj(player['player_obj'],player['text_obj'])
	#Reset player trackers
	player_objects = []
	num_players = 0

"""
/*
* @pre called when received that you have spawned back from server
* @post loads your player and all other players into scene
* @param player_name -> String
* @return None
*/
"""
func spawn_character(player_name:String):
	#Only allow 4 players
	if num_players == MAX_PLAYERS:
		return
	#Add animated player to scene
	var char_pos = get_char_pos(len(player_objects))
	var obj_arr = create_spawn_player(char_pos,player_name)
	var spawned_player = obj_arr[0]
	var text_name = obj_arr[1]
	#Add data to array
	player_objects.append({
		'name': player_name,
		'player_obj': spawned_player,
		'text_obj': text_name
	})
	Global.player_positions[str(num_players+1)] = Vector2(char_pos.x*3,char_pos.y*3)
	Global.player_names[str(num_players+1)] = player_name
	num_players += 1
	if player_name == Save.game_data.username:
		ServerConnection._player_num = num_players

"""
/*
* @pre called when received that someone has left the match
* @post loads your player and all other players into scene
* @param player_name -> String
* @return None
*/
"""
func despawn_character(player_name:String):
	Global.remove_player_from_match(player_name) #reset global player trackers
	num_players = 0 #reset num_player, will get fixed in spawn_character var num times
	var player_names_copy:Array = []
	#Save the names of the players that are still in the game
	for dict in player_objects:
		if dict['name'] != player_name:
			player_names_copy.append(dict['name'])
	#respawn players again with the one deleted
	for player in player_objects:
		delete_player_obj(player['player_obj'],player['text_obj'])
	player_objects = []
	for _name in player_names_copy:
		spawn_character(_name)

"""
/*
* @pre called when create game button is pressed
* @post creates a game code and joins the game
* @param None
* @return None
*/
"""
func _on_createGameButton_pressed():
	startButton.grab_focus()
	if ServerConnection.match_exists():
		#leave the match if the game is alredy created
		game_already_created()
	else:
		#create a match if there is no matche yet
		no_game_created()

func no_game_created():
	var code: String = generate_random_code()
	_match_code = code
	if not ServerConnection.get_server_status():
		GlobalSignals.emit_signal(
			"exportEventMessage",
			"Server not available",
			"red"
		)
	else:
		yield(ServerConnection.create_match_group(code), "completed") #create new group
		yield(ServerConnection.join_chat_async_group(), "completed") #join group chat
		yield(ServerConnection.create_match(code), "completed")
		ServerConnection.switch_chat_methods() #switch from using glabal to match chat
		GlobalSignals.emit_signal("exportEventMessage","New game created!","white")
		GlobalSignals.emit_signal("exportEventMessage","Switched from global chat to match chat","pink")
		$showLobbyCode/code.text = code
		$createGameButton.text = "Leave match"

func game_already_created():
	num_players = 0
	reset_multiplayer()
	ServerConnection.switch_chat_methods() #switch back to using global chat
	ServerConnection.join_chat_async_general() #rejoin global chat
	GlobalSignals.emit_signal("exportEventMessage","Switched from match chat to global chat","blue")
	$createGameButton.text = "Create match"
	$showLobbyCode/code.text = "XXXX"

"""
/*
* @pre called when joinGame button is pressed
* @post shows the input field to enter match code
* @param None
* @return None
*/
"""
func _on_joinGame_pressed():
	code_line_edit.show()
	code_line_edit.grab_focus()
	code_line_edit.placeholder_text = "Enter Lobby Code Here"

"""
/*
* @pre called when focus of typing code is entered
* @post sets typing code to true (used in process func)
* @param None
* @return None
*/
"""
func _on_enterLobbyCode_focus_entered():
	typing_code = true

"""
/*
* @pre whenver the match code is entered
* @post if code is valid, joins the given match, displays error otherwise
* @param None
* @return None
*/
"""
func _on_enterLobbyCode_text_entered(new_text):
	startButton.grab_focus()
	var code = new_text.to_upper()
	if len(code) != 4:
		GlobalSignals.emit_signal("exportEventMessage","Invalid code","pink")
	else:
		if ServerConnection.get_server_status():
			if Global.match_exists(code) and not ServerConnection.match_exists():
				#yield(ServerConnection.leave_match(ServerConnection._match_id), "completed")
				var long_code = Global.get_match(code) #code of match in server
				var users_in_menu = yield(ServerConnection.join_match(long_code), "completed")
				ServerConnection._group_id = Global.get_match_group_id(code)
				#Spawn users that are currently in game and you
				for user in users_in_menu:
					spawn_character(user.username)
				$showLobbyCode/code.text = code
				$createGameButton.text = "Leave match"
				_match_code = code
				yield(ServerConnection.join_match_group(), "completed") #join group
				yield(ServerConnection.join_chat_async_group(), "completed") #join general group chat
				ServerConnection.switch_chat_methods() #switch chat id to new general id
				GlobalSignals.emit_signal("exportEventMessage","Joined match and swapped to match chat","pink")
			else:
				GlobalSignals.emit_signal("exportEventMessage","Match not available","red")
		else:
			GlobalSignals.emit_signal("exportEventMessage","Server not available","red")
			code_line_edit.text = ""
			code_line_edit.hide()

"""
/*
* @pre called when server notices a player has left
* @post deletes player from the scene
* @param 
* @return None
*/
"""
func delete_player_obj(player:AnimatedSprite, text:Label):
	if player != null:
		player.queue_free()
	if text != null:
		text.queue_free()

"""
/*
* @pre None
* @post returns Vector2 of where a character position should be 
* @param sizeof_arr -> int
* @return Vector2
*/
"""
func get_char_pos(sizeof_arr: int) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	if sizeof_arr == 0:
		result.x = 820 / 3
		result.y = 425 / 3
	elif sizeof_arr == 1:
		result.x = 955 / 3
		result.y = 425 / 3
	elif sizeof_arr == 2:
		result.x = 765 / 3
		result.y = 495 / 3
	elif sizeof_arr == 3:
		result.x = 935 / 3
		result.y = 485 / 3
	return result

"""
/*
* @pre None
* @post creates the acceptDialog for getting player's username
* @param window_text -> String, dialog_text -> String
* @return None
*/
"""
func create_get_user_window(window_text, dialog_text):
	get_user_input = AcceptDialog.new()
	get_user_input.window_title = window_text
	get_user_input.dialog_text = dialog_text
	get_user_input.dialog_autowrap = true
	get_user_input.rect_min_size = Vector2(250,220)
	# warning-ignore:return_value_discarded
	get_user_input.connect("confirmed",self,"_delete_get_user_input_obj")
	var input_field = LineEdit.new()
	input_field.rect_min_size = Vector2(30,20)
	get_user_input.add_child(input_field)
	add_child(get_user_input)
	get_user_input.popup()

"""
/*
* @pre None
* @post creates the acceptDialog for setting game_init_obj
* @param window_text -> String, dialog_text -> String
* @return None
*/
"""
func create_game_init_window(window_text,dialog_text):
	game_init_popup = AcceptDialog.new()
	game_init_popup.window_title = window_text
	game_init_popup.dialog_text = dialog_text
	# warning-ignore:return_value_discarded
	game_init_popup.connect("confirmed",self,"_delete_game_init_obj")
	add_child(game_init_popup)
	game_init_popup.popup_centered()

"""
/*
* @pre None
* @post creates players that show up on rocks
* @param char_pos -> Vector2, player_name -> String
* @return None
*/
"""
func create_spawn_player(char_pos:Vector2, player_name:String) -> Array:
	var spawned_player:AnimatedSprite = load(idle_player).instance()
	#Change size and pos of sprite
	spawned_player.offset = char_pos
	spawned_player.scale = SCALE_VAL
	spawned_player.play_animation(animation_names[num_players])
	#Create text and add it as a child of the new player obj
	var player_title: Label = Label.new()
	player_title.text = player_name
	player_title.rect_position = Vector2(char_pos.x * 2.95, char_pos.y * 2.6)
	player_title.add_font_override("font",load("res://Assets/ARIALBD.TTF"))
	add_child(player_title)
	#Add child to the scene
	add_child(spawned_player)
	return [spawned_player,player_title]

"""
/*
* @pre None
* @post deltes the game_init_popup object
* @param None
* @return None
*/
"""
func _delete_game_init_obj():
	game_init_popup.queue_free()
	startButton.grab_focus()

"""
/*
* @pre None
* @post deltes the get_user_input object and sends username data to settings
* @param None
* @return None
*/
"""
func _delete_get_user_input_obj():
	#get username from the LineEdit
	var given_username = get_user_input.get_child(3).text
	get_user_input.queue_free()
	if " " in given_username:
		var win_text = "Invalid username, please try again"
		var d_text = "Username can be one word, no spaces"
		create_get_user_window(win_text, d_text)
	else:
		GlobalSettings.update_username(given_username)
		startButton.grab_focus()

func tutorial_textbox():
	startButton.grab_focus()


"""
/*
* @pre None
* @post None
* @param None
* @return None
*/
"""
#plays sound
func _mouse_button_entered():
	$click.play()

func _button_down():
	$button_down.play()

func _on_lobbyCode_mouse_entered():
	pass # Replace with function body.

func _on_HighScores_pressed():
	var h_scn = load("res://Scenes/mainMenu/HighScores.tscn").instance()
	add_child(h_scn)
	h_scn.popup_centered()
	$HighScores.release_focus()
