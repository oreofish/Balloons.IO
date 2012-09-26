
# Module dependencies

passport = require('passport')
TwitterStrategy = require('passport-twitter').Strategy
FacebookStrategy = require('passport-facebook').Strategy 
LocalStrategy = require('passport-local').Strategy 
config = require('./config.json')

# Auth strategy

passport.serializeUser((user, done) ->
  done(null, user)
)

passport.deserializeUser((user, done) ->
  done(null, user)
)

if(config.auth.twitter.consumerkey.length)
  passport.use(new TwitterStrategy({
      consumerKey: config.auth.twitter.consumerkey,
      consumerSecret: config.auth.twitter.consumersecret,
      callbackURL: config.auth.twitter.callback
    },
    (token, tokenSecret, profile, done) ->
      return done(null, profile)
  ))

if(config.auth.facebook.clientid.length)
  passport.use(new FacebookStrategy({
      clientID: config.auth.facebook.clientid,
      clientSecret: config.auth.facebook.clientsecret,
      callbackURL: config.auth.facebook.callback
    },
    (accessToken, refreshToken, profile, done) ->
      return done(null, profile)
  ))

users = [
    { id: 1, username: 'bob', password: 'bob', email: 'bob@example.com' }
  , { id: 2, username: 'ada', password: 'ada', email: 'joe@example.com' }
]

findById = (id, fn) ->
  idx = id - 1
  if (users[idx])
    fn(null, users[idx])
  else
    fn(new Error('User ' + id + ' does not exist'))

findByUsername = (username, fn) ->
  for user in users
    if (user.username == username)
      return fn(null, user)
  return fn(null, null)

passport.use(new LocalStrategy(
  (username, password, done) ->
    # Find the user by username.  If there is no user with the given
    # username, or the password is not correct, set the user to `false` to
    # indicate failure and set a flash message.  Otherwise, return the
    # authenticated `user`.
    findByUsername(username, (err, user) ->
      if (err)
        return done(err)
      if (!user)
        return done(null, false, { message: 'Unknown user ' + username })
      if (user.password != password)
        return done(null, false, { message: 'Invalid password' })
      return done(null, user);
    )
))
