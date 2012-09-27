
# Module dependencies
express = require('express')
http = require('http')
passport = require('passport')
config = require('./config.json')
init = require('./init')
redis = require('redis')
RedisStore = require('connect-redis')(express)

# Instantiate redis
if (process.env.REDISTOGO_URL)
  rtg   = require('url').parse(process.env.REDISTOGO_URL)
  client = exports.client  = redis.createClient(rtg.port, rtg.hostname)
  client.auth(rtg.auth.split(':')[1]); # auth 1st part is username and 2nd is password separated by ":"
else
  client = exports.client  = redis.createClient()

sessionStore = exports.sessionStore = new RedisStore({client: client})

# Clean db and create folder
init(client)

# Passportjs auth strategy
require('./strategy')

# Create and config server
app = exports.app = express()

app.configure () ->
  app.set('port', process.env.PORT || config.app.port || 6789)
  app.set('view engine', 'jade')
  app.set('views', __dirname + '/views/themes/' + config.theme.name)
  app.use(express.static(__dirname + '/public'))
  app.use(express.bodyParser())
  app.use(express.cookieParser(config.session.secret))
  app.use(express.session({
    key: "balloons",
    store: sessionStore
  }))
  app.use(passport.initialize())
  app.use(passport.session())
  app.use(app.router)

# Routes
require('./routes')

# Web server
exports.server = http.createServer(app).listen app.get('port'), () ->
  console.log('Balloons.io started on port %d', app.get('port'))

# Socket.io
require('./sockets')

# Catch uncaught exceptions
process.on 'uncaughtException', (err) ->
  console.log('Exception: ' + err.stack)
