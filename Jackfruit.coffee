Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $

Router = require './Router'

global.Jackfruit =

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
            map: "(doc) ->\n  if doc.collection and doc.collection is \"question\"\n    emit doc.id\n"
      }
      {
        _id: "_design/docIDsForUpdating",
        language: "coffeescript",
        views:
          docIDsForUpdating:
            map: "(doc) ->\n  emit(doc._id, null) if doc.collection is \"user\" or doc.collection is \"question\"\n  emit(doc._id, null) if doc.isApplicationDoc is true\n"
      }
    ]

global.router = new Router()

Backbone.history.start()
