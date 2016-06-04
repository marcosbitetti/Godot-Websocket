# Godot-Websocket
**A full GDScript Websocket implementation**

I make it for my personal experiments, but it shows useful for other game developers.


## Usage

```gdscript
extends Node2D # or another class of you scene

# instance
var websocket

# handler to text messages
func _on_message(msg):
	print(msg)

# handler to some button on you scene
func _on_some_button_released():
	websocket.send("Some short message here")

# entry point
func _ready():
	websocket = preload('...path.../websocket.gd').new(self)
	websocket.start('some root of any web server',80)
	websocket.set_reciever(self,'_on_message')


```

## Performance

This library is made on native GDScript, unecessary to compile modules or install plugins.

However it can result in performance sacrifice if you use large amount of data. Well websockets is made to pass imediate messages, huge data can transite with other and appropriated ways.

To pass huge blocks of binary data some techiniques are used.
