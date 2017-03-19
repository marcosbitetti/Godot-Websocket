extends StreamPeerTCP

const MAGIC_STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const USER_AGENT = "Godot-client"


const MESSAGE_RECEIVED = "msg_received"
const BINARY_RECEIVED = "binary_received"

var thread = Thread.new()
var host = '127.0.0.1'
var host_only = host
var path = null
var port = 80
var TIMEOUT = 30
var error = ''
var messages = []
var receiver = null
var receiver_f = null
var receiver_binary = null
var receiver_binary_f = null

var close_listener = Node.new()
var dispatcher = Reference.new()

func _run(_self):
	###
	# Handshake
	###
	var tm = 0.0
	
	# connect
	while true:
		if get_status()==STATUS_ERROR:
			error = 'Connection fail'
			return
		if get_status()==STATUS_CONNECTED:
			break
		tm += 0.1
		if tm>TIMEOUT:
			error = 'Connection timeout'
			return
		OS.delay_msec(100)
	
	var _host = self.host
	if self.port != 80:
		_host += ':' + str(self.port)
	var header = ''
	var data = ''
	
	
	header  = "GET /"+self.path+" HTTP/1.1\r\n"
	header += "Host: "+self.host_only+"\r\n"
	header += "Connection: Upgrade\r\n"
	header += "Pragma: no-cache\r\n"
	header += "Cache-Control: no-cache\r\n"
	header += "Upgrade: websocket\r\n"
	#header += "Origin: http://127.0.0.1:3001\r\n"
	header += "Sec-WebSocket-Version: 13\r\n"
	header += "User-Agent: "+USER_AGENT+"\r\n"
	header += "Accept-Encoding: gzip, deflate, sdch\r\n"
	header += "Accept-Language: "+str(OS.get_locale())+";q=0.8,en-US;q=0.6,en;q=0.4\r\n"
	#header += "Sec-WebSocket-Key: "+send_secure+"\r\n"
	header += "Sec-WebSocket-Key: 6Aw8vTgcG5EvXdQywVvbh_3fMxvd4Q7dcL2caAHAFjV\r\n"
	header += "Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits\r\n"
	header += "\r\n"
	#print(header)
	
	if OK!=put_data( header.to_ascii() ):
		print('error sending handshake headers')
		return

	data = ''
	tm = 0.0
	var start_read = false
	while true:
		if get_available_bytes()>0 and not start_read:
			data += get_string(get_available_bytes())
			start_read = true
		elif get_available_bytes()==0 and start_read:
			break
		
		OS.delay_msec(100)
		tm += 0.1
		if tm>TIMEOUT:
			print('timeout')
			return
	#print(data)

	var connection_ok = false
	for lin in data.split("\n"):
		if lin.find("HTTP/1.1 101")>-1:
			connection_ok = true
		# other headers can by cheched here
	
	if not connection_ok:
		#print(data)
		print("Not connection ok")
		return
	
	data = ''
	var is_reading_frame = false
	var size = 0
	var byte = 0
	var fin = 0
	var opcode = 0
	while is_connected():
		if get_available_bytes()>0:
			if not is_reading_frame:
				# frame
				byte = get_8()
				fin = byte & 0x80
				opcode = byte & 0x0F
				byte = get_8()
				var mskd = byte & 0x80
				var payload = byte & 0x7F
				#printt('length', get_available_bytes())
				#printt(fin,mskd,opcode,payload)
				#if fin:
				#data += get_string(get_available_bytes())
				if payload<126:
					# size of data = payload
					data += get_string(payload)
					if fin:
						if receiver:
							dispatcher.emit_signal(MESSAGE_RECEIVED, data)
						data = ''
				else:
					size = 0
					if payload==126:
						# 16-bit size
						size = get_u16()
						#printt(size,'of data')
					if get_available_bytes()<size:
						is_reading_frame = true
						size -= get_available_bytes()
						data += get_string(get_available_bytes())
					else:
						size = 0
						data += get_string(get_available_bytes())
						if fin:
							if receiver:
								dispatcher.emit_signal(MESSAGE_RECEIVED, data)
							data = ''
			else:
				if size<=get_available_bytes():
					size = 0
					data += get_string(get_available_bytes())
					is_reading_frame = false
					if fin:
						if receiver:
							dispatcher.emit_signal(MESSAGE_RECEIVED, data)
						data = ''
				else:
					size -= get_available_bytes()
					data += get_string(get_available_bytes())
		
		# message to send?
		while messages.size()>0:
			var msg = messages[0]
			messages.pop_front()
			
			# mount frame
			var byte = 0x80 # fin
			byte = byte | 0x01 # text frame
			put_8(byte)
			byte = 0x80 | msg.length() # mask flag and payload size
			put_u8(byte)
			byte = randi() # mask 32 bit int
			put_32(byte)
			var masked = _mask(byte,msg)
			for i in range(masked.size()):
				put_u8(masked[i])
			print(msg+" sent")
			
		OS.delay_msec(3)
	

func send(msg):
	messages.append(msg)


func start(host,port,path=null):
	self.host_only = host
	if path == null:
		self.host = host
		path = ''
	else:
		self.host = host+"/"+path
	self.path = path
	self.port = port
	set_big_endian(true)
	print(IP.get_local_addresses())
	if OK==connect(IP.resolve_hostname(host),port):
		thread.start(self,'_run', self)
	else:
		print('no')

func set_receiver(o,f):
	if receiver:
		unset_receiver()
	receiver = o
	receiver_f = f
	dispatcher.connect( MESSAGE_RECEIVED, receiver, receiver_f)

func set_binary_receiver(o,f):
	if receiver_binary:
		unset_binary_receiver()
	receiver_binary = o
	receiver_binary_f = f
	dispatcher.connect( MESSAGE_RECEIVED, receiver_binary, receiver_binary_f)

func unset_receiver():
	dispatcher.disconnect( MESSAGE_RECEIVED, receiver, receiver_f)
	receiver = null
	receiver_f = null

func unset_binary_receiver():
	dispatcher.disconnect( MESSAGE_RECEIVED, receiver_binary, receiver_binary_f)
	receiver_binary = null
	receiver_binary_f = null
	
func _init(reference).():
	dispatcher.add_user_signal(MESSAGE_RECEIVED)
	dispatcher.add_user_signal(BINARY_RECEIVED)

func _mask(_m, _d):
	_m = int_to_hex(_m)
	_d=_d.to_utf8()
	var ret = []
	for i in range(_d.size()):
		ret.append(_d[i] ^ _m[i % 4])
	return ret

func int_to_hex(n):
	n = var2bytes(n)
	n.invert()
	n.resize(n.size()-4)
	return n
