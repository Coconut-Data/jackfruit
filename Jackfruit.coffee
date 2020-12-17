Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $
global.Cookie = require 'js-cookie'
global.moment = require 'moment'
global._ = require 'underscore'

global.PouchDB = require('pouchdb-core')
PouchDB
  .plugin(require 'pouchdb-adapter-http')
  .plugin(require 'pouchdb-mapreduce')
  .plugin(require 'pouchdb-replication')
  .plugin(require 'pouchdb-upsert')

Router = require './Router'

global.Jackfruit =

  knownDatabaseServers:
    Zanzibar: "https://zanzibar.cococloud.co"
    Kigelia: "https://kigelia.cococloud.co"
    Ceshhar: "https://ceshhar.cococloud.co"
    Keep: "https://keep.cococloud.co"
    Local: "http://localhost:5984"


Jackfruit.serverCredentials = {}
for name, url of Jackfruit.knownDatabaseServers
  credentials = Cookie.get("#{name}-credentials")
  Jackfruit.serverCredentials[name] = credentials if credentials

global.router = new Router()

Backbone.history.start()
