http = require 'http'
express = require 'express'
WS = require('ws').Server


PUBLIC = __dirname + '/public/'
PORT = process.env.PORT || 3000


app = express()
server = http.createServer app
#wss = new WS( { server: server, perMessageDeflate: false } )
wss = new WS
    server: server
    perMessageDeflate: false


app.use express.static PUBLIC


wss.on 'connection', (ws) ->
    console.log 'Connected ' + ws.upgradeReq.url
    
    ws.onmessage = (event) ->
        console.log event.data
    
    ws.onerror = (error) ->
        console.log error
    
    ws.send 'Logged'


server.listen PORT, process.env.IP || "0.0.0.0", () ->
    console.log "Server started"
    
    

_on_time = () ->
    msg = new Date().toString()
    wss.clients.forEach (client) =>
        try
            client.send msg
        catch err
            err

setInterval _on_time, 3000
