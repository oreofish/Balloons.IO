
# Initialize the application

# Module dependencies
fs = require('fs')


# Initialize the 
#
# @param {Object} Redis client instance
# API @public
module.exports = (client)->
  # Clean all forgoten sockets in Redis.io

  # Delete all users sockets from their lists
  client.keys 'sockets:for:*', (err, keys) ->
    if(keys.length)
      client.del(keys)
    console.log('Deletion of sockets reference for each user >> ', err || "Done!")

  # No one is online when starting up
  client.keys 'rooms:*:online', (err, keys) ->
    roomNames = []
    
    if(keys.length)
      roomNames = roomNames.concat(keys)
      client.del(keys)

    roomNames.forEach (roomName, index) ->
      key = roomName.replace(':online', ':info')
      client.hset(key, 'online', 0)

    console.log('Deletion of online users from rooms >> ', err || "Done!")

  # Delete all socket.io's sockets data from Redis
  client.smembers 'socketio:sockets', (err, sockets) ->
    if(sockets.length)
      client.del(sockets);
    console.log('Deletion of socket.io stored sockets data >> ', err || "Done!")

  # Create 'chats' dir
  fs.mkdir('./chats')


