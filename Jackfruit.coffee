Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $
global.Cookie = require 'js-cookie'

Router = require './Router'

global.Jackfruit =

  knownDatabaseServers:
    Zanzibar: "https://zanzibar.cococloud.co"
    Kigelia: "https://kigelia.cococloud.co"
    Ceshhar: "https://ceshhar.cococloud.co"
    Local: "http://localhost:5984"

  setupNewCoconutDatabase: =>
    Jackfruit.database.bulkDocs [
      {
        _id: "client encryption key"
        key: null
      }
      {
        _id: '_design/questions',
        language: "coffeescript",
        views:
          questions:
            map: "(doc) ->\n  if doc.collection and doc.collection is \"question\"\n    emit doc._id\n"
      }
      {
        _id: "_design/docIDsForUpdating",
        language: "coffeescript",
        views:
          docIDsForUpdating:
            map: "(doc) ->\n  emit(doc._id, null) if doc.collection is \"user\" or doc.collection is \"question\"\n  emit(doc._id, null) if doc.isApplicationDoc is true\n"
      }
    ]

Jackfruit.serverCredentials = {}
for name, url of Jackfruit.knownDatabaseServers
  credentials = Cookie.get("#{name}-credentials")
  Jackfruit.serverCredentials[name] = credentials if credentials

global.router = new Router()

Backbone.history.start()
