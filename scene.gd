
extends Node

#var peer = StreamPeerTCP.new()
var websocket = preload('websocket.gd').new()

var run_time = 0

func _process(delta):
	#print(peer.is_connected())
	#print(peer.get_status())
	run_time += delta
	get_node("time").set_text(str(run_time).pad_decimals(2))
	

func _ready():
	#peer.connect('127.0.0.1',3001)
	
	set_process(true)
	
	websocket.start('godot-websocket-tutorial-marcosbitetti.c9users.io',80)



func _on_Button_pressed():
	websocket.send("Hi server")
	print('cl')
