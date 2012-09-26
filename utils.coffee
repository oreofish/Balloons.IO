crypto = require('crypto')

# Restrict paths

exports.restrict = (req, res, next) ->
  if(req.isAuthenticated())
    next()
  else
    res.redirect('/')

# Generates a URI Like key for a room

exports.genRoomKey = () ->
  shasum = crypto.createHash('sha1')
  shasum.update(Date.now().toString())
  return shasum.digest('hex').substr(0,6)

# Room name is valid

exports.validRoomName = (req, res, fn) ->
  req.body.room_name = req.body.room_name.trim()
  nameLen = req.body.room_name.length

  if(nameLen < 255 && nameLen >0) 
    fn()
  else
    res.redirect('back')

# Checks if room exists
exports.roomExists = (req, res, client, fn) ->
  client.hget 'balloons:rooms:keys', encodeURIComponent(req.body.room_name), (err, roomKey) ->
    if(!err && roomKey)
      res.redirect( '/' + roomKey )
    else
      fn()


# Creates a room
exports.createRoom = (req, res, client) ->
  roomKey = exports.genRoomKey()
  room = {
    key: roomKey,
    name: req.body.room_name,
    admin: req.user.provider + ":" + req.user.username,
    locked: 0,
    online: 0
  }

  client.hmset 'rooms:' + roomKey + ':info', room, (err, ok) ->
    if(!err && ok)
      client.hset('balloons:rooms:keys', encodeURIComponent(req.body.room_name), roomKey)
      client.sadd('balloons:public:rooms', roomKey)
      res.redirect('/' + roomKey)
    else
      res.send(500)

# Get Room Info

exports.getRoomInfo = (req, res, client, fn) ->
  client.hgetall 'rooms:' + req.params.id + ':info', (err, room) ->
    if(!err && room && Object.keys(room).length)
      fn(room)
    else
      res.redirect('back')

exports.getPublicRoomsInfo = (client, fn) ->
  client.smembers 'balloons:public:rooms', (err, publicRooms) ->
    rooms = []
    len = publicRooms.length
    if(!len)
      fn([])

    publicRooms.sort(exports.caseInsensitiveSort)

    publicRooms.forEach (roomKey, index) ->
      client.hgetall 'rooms:' + roomKey + ':info', (err, room) ->
        # prevent for a room info deleted before this check
        if(!err && room && Object.keys(room).length) 
          # add room info
          rooms.push({
            key: room.key || room.name, # temp
            name: room.name,
            online: room.online || 0
          })

          # check if last room
          if(rooms.length == len)
            fn(rooms)
        else
          # reduce check length
          len -= 1

# Get connected users at room

exports.getUsersInRoom = (req, res, client, room, fn) ->
  client.smembers 'rooms:' + req.params.id + ':online', (err, online_users) ->
    users = []

    online_users.forEach (userKey, index) ->
      client.get 'users:' + userKey + ':status', (err, status) ->
        msnData = userKey.split(':')
        username = if msnData.length > 1 then msnData[1] else msnData[0]
        provider = if msnData.length > 1 then msnData[0] else "twitter"

        users.push({
          username: username,
          provider: provider,
          status: status || 'available'
        })

    fn(users)

# Get public rooms

exports.getPublicRooms = (client, fn) ->
  client.smembers "balloons:public:rooms", (err, rooms) ->
    if (!err && rooms)
      fn(rooms)
    else
      fn([])

# Get User status

exports.getUserStatus = (user, client, fn) ->
  client.get 'users:' + user.provider + ":" + user.username + ':status', (err, status) ->
    if (!err && status)
      fn(status)
    else
      fn('available')

# Enter to a room

exports.enterRoom = (req, res, room, users, rooms, status) ->
  res.locals({
    room: room,
    rooms: rooms,
    user: {
      nickname: req.user.username,
      provider: req.user.provider,
      status: status
    },
    users_list: users
  })
  res.render('room')

# Sort Case Insensitive

exports.caseInsensitiveSort = (a, b) ->
  ret = 0

  b = b.toLowerCase()

  if(a > b)
    ret = 1
  if(a < b)
    ret = -1

  return ret
