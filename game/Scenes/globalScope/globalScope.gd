"""
* Programmer Name - Ben Moeller, Jason Truong
* Description - File for controlling swapping out scenes and controlling network and chatbox
* 	This is the scnene that will ALWAYS be a part of the game
*	If you want to know how to load a scene, checkout instructions in Loader/Global.gd
* Date Created - 10/9/2022
* Date Revisions:
	10/12/2022 - Start of adding network functionality
	10/14/2022 - Got general chat working for player
	10/22/2022 - Adding scene changer functionality
"""
extends Node

#Member Variables
onready var chat_box = $GUI/chatbox
onready var settings_menu = $GUI/SettingsMenu
onready var credits = $GUI/credits
onready var world_env = $WorldEnvironment
onready var fps_label = $GUI/fpsLabel
onready var menu_button = $GUI/SettingsMenu/SettingsTabs/Exit/exitSettings/GridContainer/mainMenuButton
onready var current_song = $BGM/mainmenu
onready var market = $GUI/Market

#Scene Paths
var main_menu = "res://Scenes/mainMenu/mainMenu.tscn"
var start_area = "res://Scenes/startArea/startArea.tscn"
var cave = "res://Scenes/startArea/EntrySpace.tscn"
var riddler_minigame = "res://Scenes/minigames/riddler/riddleGame.tscn"
var arena_minigame = "res://Scenes/minigames/arena/arenaGame.tscn"
var rhythm_intro = "res://Scenes/minigames/rhythm/introScene.tscn"
var rhythm_minigame = "res://Scenes/minigames/rhythm/rhythm.tscn"
var gameover = "res://Scenes/mainMenu/gameOver.tscn"
var quiz="res://Scenes/FinalBoss/Quiz.tscn"
var dilemma = "res://Scenes/FinalBoss/Dilemma.tscn"
var endscreen = "res://Scenes/EndScene/EndScene.tscn"
var tutorial = "res://Scenes/Tutorial/tutorial.tscn"

#Current scene running
var current_scene = null
#State to compare to the global state to see if anything changes
var local_state = null
#Bool to tell if in a popup or not
var in_popup: bool = false
#Bool to tell if in market
var in_market: bool = false
#Bools to tell if in chatbox or not, work like a locking mechanism
var in_chatbox: bool = false
#Bools to tell if you can open the settings or not
var can_open_settings: bool = false

"""
/*
* @pre called once when scene is called
* @post authenticates, connects to server, and joins general chat
* @param None
* @return None
*/
"""
func _ready():
	# warning-ignore:return_value_discarded
	ServerConnection.connect("chat_message_received",self,"_on_ServerConnection_chat_message_received")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("openChatbox",self,"_chatbox_use")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("exportEventMessage", self, "_event_chatbox_msg")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("toggleHotbar", self, "toggle_hotbar")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("show_money_text", self, "show_money")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("money_screen_val", self, "change_money")
	# warning-ignore:return_value_discarded
	GlobalSignals.connect("reset_server", self, "server_checks")
	#Initialize the options menu and world environment
	initialize_settings()
	initialize_world_env()
	initialize_fps_label()
	PlayerInventory.add_item("Coin", Save.game_data.money) #add players coins to inventory
	#Load initial scene (main menu)
	current_scene = load(main_menu).instance()
	add_child(current_scene)
	Global.state = Global.scenes.MAIN_MENU
	local_state = Global.scenes.MAIN_MENU
	$BGM/mainmenu.play()
	#Connect to Server and join world
	yield(server_checks(), "completed")

func toggle_hotbar(en: bool):
	pass
	# hotbar.visible = en

"""
/*
* @pre called for every frame in the game
* @post checks if state has changed, frees current scene and
* 	calls function to switch scenes if so
* @param _delta -> time thing
* @return None
*/
"""
func _process(_delta): #if you want to use _delta, remove _
	#Change scene
	if local_state != Global.state:
		#free up memory from the current scene if not a popup scene (example: settings menu)
		if not_popup(Global.state):
			current_scene.queue_free()
		#change the scene
		_change_scene_to(Global.state)
	if Input.is_action_just_pressed("ui_cancel",false) and local_state != Global.scenes.MAIN_MENU:
		if in_market:
			in_market = false
		elif in_popup:
			settings_menu.hide()
			in_popup = false
		elif can_open_settings:
			menu_button.show()
			settings_menu.popup_centered_ratio()
			in_popup = true
	set_popup_locks()

"""
/*
* @pre called when global wants to change scenes
* @post changes scene and adds it as a child to global scene
* @param state -> int
* @return None
*/
"""
func _change_scene_to(state):
	#Load the correct scene
	if state == Global.scenes.MAIN_MENU:
		current_scene = load(main_menu).instance()
	elif state == Global.scenes.OPTIONS_FROM_MAIN:
		menu_button.hide()
		settings_menu.popup_centered_ratio()
		Global.state = Global.scenes.MAIN_MENU
		return
	elif state == Global.scenes.MARKET:
		market.popup_centered()
		market.show_balance()
		Global.state = Global.scenes.MAIN_MENU
		return
	elif state == Global.scenes.MARKET_CAVE:
		in_market = true
		market.popup_centered()
		Global.state = Global.scenes.CAVE
		return
	elif state == Global.scenes.CREDITS:
		credits.popup_centered()
		Global.state = Global.scenes.MAIN_MENU
		return
	elif state == Global.scenes.START_AREA:
		current_scene = load(start_area).instance()
	elif state == Global.scenes.CAVE:
		stopall()
		$BGM/cave.play()
		current_scene = load(cave).instance()
	elif state == Global.scenes.RIDDLER_MINIGAME:
		stopall()
		$BGM/riddler.play()
		current_scene = load(riddler_minigame).instance()
	elif state == Global.scenes.ARENA_MINIGAME:
		stopall()
		$BGM/arena.play()
		current_scene = load(arena_minigame).instance()
	elif state == Global.scenes.RHYTHM_INTRO:
		stopall()
		current_scene = load(rhythm_intro).instance()
	elif state == Global.scenes.TUTORIAL:
		stopall()
		current_scene = load(tutorial).instance()
	elif state == Global.scenes.RHYTHM_MINIGAME:
		stopall()
		current_scene = load(rhythm_minigame).instance()
	elif state == Global.scenes.GAMEOVER:
		stopall()
		$BGM/gameover.play()
		current_song = "$BGM/gameover"
		current_scene = load(gameover).instance()
	elif state==Global.scenes.QUIZ:
		current_scene=load(quiz).instance()
	elif state == Global.scenes.DILEMMA:
		stopall()
		current_scene = load(dilemma).instance()
	elif state == Global.scenes.END_SCREEN:
		stopall()
		current_scene = load(endscreen).instance()
	#add scene to tree and revise local state
	add_child(current_scene)
	local_state = Global.state

func stopall():
	$BGM/mainmenu.stop()
	$BGM/cave.stop()
	$BGM/riddler.stop()
	$BGM/arena.stop()
	$BGM/gameover.stop()
"""
/*
* @pre called once in _ready function
* @post authenticates, connects to server, and joins general chat
* 	if there were no errors along the way
* @param None
* @return bool
*/
"""
func server_checks():
	ServerConnection.set_server_status(false)
	var result = yield(request_authentication(), "completed")
	if result == OK:
		result = yield(connect_to_server(), "completed")
		if result == OK:
			result = yield(ServerConnection.join_chat_async_general(), "completed")
			if result == OK:
				ServerConnection.set_server_status(true)

"""
/*
* @pre called in _ready
* @post calls authentication function
* @param None
* @return int
*/
"""
func request_authentication() -> int:
	var user: String = Save.game_data.username
	
	var result: int = yield(ServerConnection.authenticate_async(), "completed")
	if result == OK:
		print("Authenticated user %s successfully" % user)
	else:
		print("Could not authenticate user %s" % user)
	return result

"""
/*
* @pre called once in _ready
* @post calls connection to server function
* @param None
* @return int
*/
"""
func connect_to_server() -> int:
	var result: int = yield(ServerConnection.connect_to_server_async(), "completed")
	if result == OK:
		print("Connected to the server")
	elif ERR_CANT_CONNECT:
		print("Could not connect to server")
	else:
		print("Unexpected error received")
	return result

"""
/*
* @pre called once to authenticate user
* @post connects to the server
* @param username -> String, text -> String
* @return None
*/
"""
func _on_ServerConnection_chat_message_received(msg,type,user_sent,from_user):
	#add message from server to chatbox
	chat_box.add_message(msg,type,user_sent,from_user)
	GlobalSignals.emit_signal("answer_received",msg,from_user)

"""
/*
* @pre called when user submits message to chatbox
* @post sends message to send_text_async function
* @param msg -> String
* @return None
*/
"""
func _on_chatbox_message_sent(msg,is_whisper,username_to_send_to):
	#If not connected to server, don't send message
	if not ServerConnection.get_server_status():
		chat_box.add_err_message()
		return
	#Else send message corresponding to whisper or general
	if is_whisper:
		yield(ServerConnection.join_chat_async_whisper(username_to_send_to,false), "completed")
		#Set a timer to give time for connection to form between players
		var t = Timer.new()
		t.set_wait_time(0.5)
		t.set_one_shot(true)
		self.add_child(t)
		t.start()
		yield(t, "timeout")
		t.queue_free()
		#end of timer, send whisper
		yield(ServerConnection.send_text_async_whisper(msg,username_to_send_to), "completed")
	else:
		#send message to general
		ServerConnection.send_chat_message(msg)

"""
/*
* @pre called in the _ready func
* @post initializes the settings menu for values look same
* @param None
* @return None
*/
"""
func initialize_settings():
	#Call functions to sync audio settings with user save
	settings_menu._on_MasterVolSlider_value_changed(Save.game_data.master_vol)
	settings_menu._on_MusicVolSlider_value_changed(Save.game_data.music_vol)
	settings_menu._on_SfxVolSlider_value_changed(Save.game_data.sfx_vol)

func initialize_world_env():
	#Call functions to use user saved brightness and bloom values
	world_env._on_brightness_toggled(Save.game_data.brightness)
	world_env._on_bloom_toggled(Save.game_data.bloom_on)


func initialize_fps_label():
	#Call function to use user saved fps
	fps_label._on_fps_displayed(Save.game_data.display_fps)

"""
/*
* @pre None
* @post tells if the scene is a popup scene or not
* @param state -> Global.scenes
* @return bool
*/
"""
func not_popup(state) -> bool:
	match state:
		Global.scenes.OPTIONS_FROM_MAIN:
			return false
		Global.scenes.CREDITS:
			return false
		Global.scenes.MARKET:
			return false
		Global.scenes.MARKET_CAVE:
			return false
		_:
			return true

"""
/*
* @pre called when chatbox is opened
* @post sets in_chatbox to true so game knows chat is being used
* @param value -> bool 
* @return None
*/
"""
func _chatbox_use(value):
	in_chatbox = value

"""
/*
* @pre None
* @post sets locks for if settings menu can be opened or not
* @param None
* @return None
*/
"""
func set_popup_locks():
	if not in_chatbox and not can_open_settings:
		can_open_settings = true
	elif in_chatbox and can_open_settings:
		can_open_settings = false

"""
/*
* @pre None
* @post show the total coin of player
* @param None
* @return None
*/
"""
func show_money(should_show:bool) -> void:
	if should_show:
		$GUI/money.show()
	else:
		$GUI/money.hide()

"""
/*
* @post change coin value of money label
* @param value (value of money to show)
* @return None
*/
"""
func change_money() -> void:
	$GUI/money.change_total(Save.game_data.money)

"""
/*
* @post adds an event message to the chatbox
* @param msg -> String, color -> String
* @return None
*/
"""
func _event_chatbox_msg(msg:String, color:String):
	chat_box.chat_event_message(msg, color)
