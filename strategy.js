
/*
 * Module dependencies
 */

var passport = require('passport')
  , TwitterStrategy = require('passport-twitter').Strategy
  , FacebookStrategy = require('passport-facebook').Strategy 
  , LocalStrategy = require('passport-local').Strategy 
  , config = require('./config.json');

/*
 * Auth strategy
 */

passport.serializeUser(function(user, done) {
  done(null, user);
});

passport.deserializeUser(function(user, done) {
  done(null, user);
});

if(config.auth.twitter.consumerkey.length) {
  passport.use(new TwitterStrategy({
      consumerKey: config.auth.twitter.consumerkey,
      consumerSecret: config.auth.twitter.consumersecret,
      callbackURL: config.auth.twitter.callback
    },
    function(token, tokenSecret, profile, done) {
      return done(null, profile);
    }
  ));
} 

if(config.auth.facebook.clientid.length) {
  passport.use(new FacebookStrategy({
      clientID: config.auth.facebook.clientid,
      clientSecret: config.auth.facebook.clientsecret,
      callbackURL: config.auth.facebook.callback
    },
    function(accessToken, refreshToken, profile, done) {
      return done(null, profile);
    }
  ));
} 

var users = [
    { id: 1, username: 'bob', password: 'bob', email: 'bob@example.com' }
  , { id: 2, username: 'ada', password: 'ada', email: 'joe@example.com' }
];

function findById(id, fn) {
  var idx = id - 1;
  if (users[idx]) {
    fn(null, users[idx]);
  } else {
    fn(new Error('User ' + id + ' does not exist'));
  }
}

function findByUsername(username, fn) {
  for (var i = 0, len = users.length; i < len; i++) {
    var user = users[i];
    if (user.username === username) {
      return fn(null, user);
    }
  }
  return fn(null, null);
}

passport.use(new LocalStrategy(
  function(username, password, done) {
    // Find the user by username.  If there is no user with the given
    // username, or the password is not correct, set the user to `false` to
    // indicate failure and set a flash message.  Otherwise, return the
    // authenticated `user`.
    findByUsername(username, function(err, user) {
      if (err) { return done(err); }
      if (!user) { return done(null, false, { message: 'Unknown user ' + username }); }
      if (user.password != password) { return done(null, false, { message: 'Invalid password' }); }
      return done(null, user);
    })
  }
));
