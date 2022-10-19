extends Node

signal chat_message_received(username, text)

const KEY := "nakama_mendax"

var _session: NakamaSession

#my server: 3.143.142.232
#jasons server: 52.205.252.95
var _client := Nakama.create_client(KEY, "52.205.252.95", 7350, "http")
var _socket : NakamaSocket

var _general_chat_id = ""
var _current_whisper_id = ""

var room_players:Array = []

"""
/*
* @pre called once to authenticate user
* @post authenticates to the server using device id
* @param None
* @return None
*/
"""
func authenticate_async() -> int:
	var result := OK
	var deviceid = OS.get_unique_id()
	
	var new_session: NakamaSession = yield(_client.authenticate_device_async(deviceid), "completed")
	
	if not new_session.is_exception():
		_session = new_session
	else:
		result = new_session.get_exception().status_code
	
	return result

"""
/*
* @pre called once to connect user to server
* @post connects to server using ip set by server
* @param None
* @return None
*/
"""
func connect_to_server_async() -> int:
	_socket = Nakama.create_socket_from(_client)
	var result: NakamaAsyncResult = yield(_socket.connect_async(_session), "completed")
	if not result.is_exception():
		#connect to closed signal, called when connection is closed to free memory
		_socket.connect("closed", self, "_on_NakamaSocket_closed")
		#connect 
		_socket.connect("received_channel_message", self, "_on_Nakama_Socket_received_channel_message")
		#get user who joins
		_socket.connect("received_channel_presence", self, "_on_channel_presence")
		#get a notification
		_socket.connect("received_notification", self, "_on_notification")
		return OK
	return ERR_CANT_CONNECT

"""
/*
* @pre called when Nakama Socket is closed
* @post sets _socket to null to close socket
* @param None
* @return None
*/
"""
func _on_NakamaSocket_closed() -> void:
	print("Disconnected from socket")
	_socket = null

"""
/*
* @pre called once to join the general chat
* @post joins the general chat server, can now send messages
* @param None
* @return None
*/
"""
func join_chat_async_general() -> int:
	var chat_join_result = yield(
		_socket.join_chat_async("general", NakamaSocket.ChannelType.Room, false, false), "completed"
	)
	if not chat_join_result.is_exception():
		_general_chat_id = chat_join_result.id
		print("Chat joined")
		return OK
	else:
		print("Chat NOT joined")
		return ERR_CONNECTION_ERROR


func join_chat_async_whisper(user_id:String) -> int:
	user_id = get_player_from_list(user_id)
	if user_id == "ERROR":
		return ERR_CONNECTION_ERROR
	var type = NakamaSocket.ChannelType.DirectMessage
	var persistence = true
	var hidden = false
	var channel : NakamaRTAPI.Channel = yield(_socket.join_chat_async(user_id, type, persistence, hidden), "completed")
	_current_whisper_id = channel.id

	if channel.is_exception():
		return ERR_CONNECTION_ERROR
	else:
		return OK


"""
/*
* @pre called when sending message to server
* @post sends chat message packaged with the username
* @param text -> String
* @return None
*/
"""
func send_text_async_general(text: String) -> int:
	if not _socket:
		return ERR_UNAVAILABLE
	
	if _general_chat_id == "":
		printerr("Can't send a message to chat: _channel_id is missing")
	
	var msg_result = yield(
		_socket.write_chat_message_async(_general_chat_id, {"msg": text, "user": Save.game_data.username}), "completed"
	)
	return ERR_CONNECTION_ERROR if msg_result.is_exception() else OK

func send_text_async_whisper(text: String) -> int:
	if not _socket:
		return ERR_UNAVAILABLE
	
	if _general_chat_id == "":
		printerr("Can't send a message to chat: _channel_id is missing")
	
	var msg_result = yield(
		_socket.write_chat_message_async(_current_whisper_id, {"msg": text, "user": Save.game_data.username}), "completed"
	)
	return ERR_CONNECTION_ERROR if msg_result.is_exception() else OK

"""
/*
* @pre called when a message is received from Nakama server
* @post emits signal that the message has been received
* @param message -> NakamaAPI.APIChannelMessage
* @return None
*/
"""
func _on_Nakama_Socket_received_channel_message(message: NakamaAPI.ApiChannelMessage) -> void:
	if message.code != 0:
		return
	
	var content: Dictionary = JSON.parse(message.content).result
	if not {content.user : message._get_sender_id()} in room_players:
		room_players.append({'user' : content.user, 'id' : message._get_sender_id()})
	emit_signal("chat_message_received", content.user, content.msg)

func _on_channel_presence(p_presence : NakamaRTAPI.ChannelPresenceEvent):
#	var x=0
#	for p in p_presence.joins:
#		var user:String = get_player_using_id(p.user_id)
#		if user != Save.game_data.username:
#			print("user: ", user)
#			print("players: ", room_players)
#			join_chat_async_whisper(user)
	pass

func get_player_from_list(user:String):
	for dict in room_players:
		if dict['user'] == user:
			return dict['id']
	return "ERROR"
	
func get_player_using_id(id:String):
	for dict in room_players:
		if dict['id'] == id:
			return dict['user']
	return "ERROR"

func _on_notification(p_notification : NakamaAPI.ApiNotification):
	var user = get_player_using_id(p_notification._get_sender_id())
	if user == "ERROR":
		print("there was an error in the direct message")
		return
	join_chat_async_whisper(user)
