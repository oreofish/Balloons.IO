
# Module dependencies

parent = module.parent.exports 
app = parent.app
server = parent.server
express = require('express')
client = parent.client
sessionStore = parent.sessionStore
sio = require('socket.io')
parseCookies = require('connect').utils.parseSignedCookies
cookie = require('cookie')
config = require('./config.json')
fs = require('fs')


io = sio.listen(server)
io.set('authorization', (hsData, accept) ->
  if(hsData.headers.cookie)
    cookies = parseCookies(cookie.parse(hsData.headers.cookie), config.session.secret)
    sid = cookies['balloons']

    sessionStore.load(sid, (err, session) ->
      if (err || !session)
        return accept('Error retrieving session!', false)

      hsData.balloons = {
        user: session.passport.user,
        room: /\/(?:([^\/]+?))\/?$/g.exec(hsData.headers.referer)[1]
      }

      return accept(null, true)
      
    )
  else
    return accept('No cookie transmitted.', false)
)

io.configure(() ->
  io.set('store', new sio.RedisStore)
  io.enable('browser client minification')
  io.enable('browser client gzip')
)


io.sockets.on('connection', (socket) ->
  hs = socket.handshake
  nickname = hs.balloons.user.username
  provider = hs.balloons.user.provider
  userKey = provider + ":" + nickname
  room_id = hs.balloons.room
  now = new Date()
  # Chat Log handler
  chatlogFileName = './chats/' + room_id + (now.getFullYear()) + (now.getMonth() + 1) + (now.getDate()) + ".txt"
  chatlogWriteStream = fs.createWriteStream(chatlogFileName, {'flags': 'a'})

  socket.join(room_id)

  client.sadd('sockets:for:' + userKey + ':at:' + room_id, socket.id, (err, socketAdded) ->
    if(socketAdded)
      client.sadd('socketio:sockets', socket.id)
      client.sadd('rooms:' + room_id + ':online', userKey, (err, userAdded) ->
        if(userAdded)
          client.hincrby('rooms:' + room_id + ':info', 'online', 1)
          client.get('users:' + userKey + ':status', (err, status) ->
            io.sockets.in(room_id).emit('new user', {
              nickname: nickname,
              provider: provider,
              status: status || 'available'
            })
          )
      )
  )

  socket.on('my msg', (data) ->
    no_empty = data.msg.replace("\n","")
    if(no_empty.length > 0)
      chatlogRegistry = {
        type: 'message',
        from: userKey,
        atTime: new Date(),
        withData: data.msg
      }

      chatlogWriteStream.write(JSON.stringify(chatlogRegistry) + "\n")
      
      io.sockets.in(room_id).emit('new msg', {
        nickname: nickname,
        provider: provider,
        msg: data.msg
      })
  )

  socket.on('set status', (data) ->
    status = data.status

    client.set('users:' + userKey + ':status', status, (err, statusSet) ->
      io.sockets.emit('user-info update', {
        username: nickname,
        provider: provider,
        status: status
      })
    )
  )

  socket.on('history request', () ->
    history = []
    tail = require('child_process').spawn('tail', ['-n', 5, chatlogFileName])
    tail.stdout.on('data', (data) ->
      lines = data.toString('utf-8').split("\n")
      
      lines.forEach((line, index) ->
        if(line.length)
          historyLine = JSON.parse(line)
          history.push(historyLine)
      )

      socket.emit('history response', {
        history: history
      })
    )
  )

  socket.on('disconnect', () ->
    # 'sockets:at:' + room_id + ':for:' + userKey
    client.srem('sockets:for:' + userKey + ':at:' + room_id, socket.id, (err, removed) ->
      if(removed)
        client.srem('socketio:sockets', socket.id)
        client.scard('sockets:for:' + userKey + ':at:' + room_id, (err, members_no) ->
          if(!members_no)
            client.srem('rooms:' + room_id + ':online', userKey, (err, removed) ->
              if (removed)
                client.hincrby('rooms:' + room_id + ':info', 'online', -1)
                chatlogWriteStream.destroySoon()
                io.sockets.in(room_id).emit('user leave', {
                  nickname: nickname,
                  provider: provider
                })
            )
        )
    )
  )
)
