Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $
global.Cookie = require 'js-cookie'
global.moment = require 'moment'
global._ = require 'underscore'
Encryptor = require('simple-encryptor')

global.PouchDB = require('pouchdb-core')
PouchDB
  .plugin(require 'pouchdb-adapter-http')
  .plugin(require 'pouchdb-adapter-idb')
  .plugin(require 'pouchdb-mapreduce')
  .plugin(require 'pouchdb-replication')
  .plugin(require 'pouchdb-upsert')

Router = require './Router'
AppConfig = require './config.json'

global.Jackfruit =
  knownDatabaseServers:
    Zanzibar: "https://#{AppConfig.targetUrl}"
    Local: "http://localhost:5984"

Jackfruit.serverCredentials = {}
for name, url of Jackfruit.knownDatabaseServers
  credentials = Cookie.get("#{name}-credentials")
  Jackfruit.serverCredentials[name] = credentials if credentials



## GLOBAL FUNCTIONS ##
#
Jackfruit.canCreateDesignDoc = =>
  Jackfruit.database.put {_id:"_design/test"}
  .then (result) =>
    Jackfruit.database.remove 
      _id: result.id
      _rev: result.rev
    Promise.resolve(true)
  .catch (error) => 
    if error.status is 403
      Promise.resolve(false)


Jackfruit.setupDatabase = (serverName, databaseOrGatewayName) =>
  Jackfruit.serverName = serverName

  username = Cookie.get("username")
  password = Cookie.get("password")
  unless username and password
    console.log "CHANGING"
    Jackfruit.targetUrl = document.location.hash.replace(/#/,"")
    return router.navigate "server/#{Jackfruit.serverName}", trigger:true
  serverUrlWithCredentials = "#{Jackfruit.knownDatabaseServers[serverName]}".replace(/:\/\//, "://#{username}:#{password}@")
  Jackfruit.database = new PouchDB("#{serverUrlWithCredentials}/#{databaseOrGatewayName}")
  Jackfruit.databaseName = databaseOrGatewayName
  Jackfruit.databasePlugins = await Jackfruit.database.allDocs
    startkey: "_design/plugin-"
    endkey: "_design/plugin-\uf000"
    include_docs: true
  .then (result) =>
    Promise.resolve(_(result?.rows).pluck "doc")

global.router = new Router()
Backbone.history.start()
