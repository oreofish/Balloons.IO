
# Module dependencies

app = module.parent.exports.app
passport = require('passport')
client = module.parent.exports.client
config = require('../config')
utils = require('../utils')

# Homepage

app.get '/', (req, res, next) ->
  if(req.isAuthenticated())
    client.hmset(
      'users:' + req.user.provider + ":" + req.user.username,
      req.user
    )
    res.redirect('/rooms')
  else
    res.render('index')

# Authentication routes

if(config.auth.twitter.consumerkey.length)
  app.get('/auth/twitter', passport.authenticate('twitter'))

  app.get '/auth/twitter/callback', 
    passport.authenticate('twitter', {
      successRedirect: '/',
      failureRedirect: '/'
    })

if(config.auth.facebook.clientid.length)
  app.get('/auth/facebook', passport.authenticate('facebook'))

  app.get '/auth/facebook/callback', 
    passport.authenticate('facebook', {
      successRedirect: '/',
      failureRedirect: '/'
    })

app.post '/login', 
  passport.authenticate('local', {
    successRedirect: '/',
    failureRedirect: '/',
    failureFlash: true
  })

app.get '/logout', (req, res) ->
  req.logout()
  res.redirect('/')

# Rooms list

app.get '/rooms', utils.restrict, (req, res) ->
  utils.getPublicRoomsInfo client, (rooms) ->
    res.render('room_list', { rooms: rooms })

# Create a rooom

app.post '/create', utils.restrict, (req, res) ->
  utils.validRoomName req, res, (roomKey) ->
    utils.roomExists req, res, client, () ->
      utils.createRoom(req, res, client)

# Join a room

app.get '/:id', utils.restrict, (req, res) ->
  utils.getRoomInfo req, res, client, (room) ->
    utils.getUsersInRoom req, res, client, room, (users) ->
      utils.getPublicRoomsInfo client, (rooms) ->
        utils.getUserStatus req.user, client, (status) ->
          utils.enterRoom(req, res, room, users, rooms, status)


