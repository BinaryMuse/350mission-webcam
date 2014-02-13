crypto = require 'crypto'
path = require 'path'
http = require 'http'

bytewise = require 'bytewise'
request = require 'request'
levelup = require 'levelup'
express = require 'express'
harp = require 'harp'

imgUrl = 'http://server2.varcsystems.com/on-site-archive/recent/4FCBC3436A64B26C7E/4F59A559082743F625.jpg'

db = levelup './data/db', keyEncoding: bytewise

addToDb = (buffer, digest, date) ->
  record =
    time: date.getTime()
    digest: digest
  db.batch [
    { type: 'put', key: ['digest', digest], value: "1" }
    { type: 'put', key: ['record', date], value: record, valueEncoding: 'json' }
    { type: 'put', key: ['image', date], value: buffer, valueEncoding: 'binary' }
  ], (err) ->
    if (err)
      console.error "ERROR:", err
    else
      console.log "Successfully saved #{digest} (#{date})"

update = (buffer, date) ->
  sha256 = crypto.createHash('sha256')
  sha256.update buffer
  digest = sha256.digest('hex')

  db.get ['digest', digest], fillCache: false, (err, value) ->
    if err && err.notFound
      addToDb buffer, digest, date
    else if err
      console.error "ERROR:", err
    else
      console.log "Image already added (digest: #{digest})"

fetch = ->
  date = new Date()
  opts =
    url: imgUrl
    timeout: 60 * 1000
    encoding: 'binary'
  request opts, (err, resp, body) ->
    if err?
      console.error "ERROR:", err
    else if !resp.statusCode.toString().match(/^2/)
      console.error "ERROR: Status of #{resp.statusCode}"
    else
      update body, date

setInterval fetch, 2 * 60 * 1000
fetch()

app = express()

app.configure ->
  app.use harp.mount path.join(__dirname, 'public')

app.get '/records', (req, res) ->
  keys = []
  db.createKeyStream(start: ['record', null], end: ['record', undefined])
    .on 'data', (key) ->
      key = key[1]
      keys.push(key.getTime())
    .on 'end', ->
      res.json records: keys.map (key) ->
        { url: "/records/#{key}", time: key }

app.get '/records/:id', (req, res) ->
  date = new Date(parseInt(req.params.id, 10))
  db.get ['image', date], valueEncoding: 'binary', (err, data) ->
    if (err)
      res.status 404
    else
      res.set 'Last-Modified', date.toUTCString()
      if req.fresh
        res.status(304)
      else
        res.set 'Content-Type', 'image/jpeg'
        res.send data

server = http.createServer(app)
port = process.env.PORT || 8133
server.listen port, ->
  console.log "Listening on port #{port}"
