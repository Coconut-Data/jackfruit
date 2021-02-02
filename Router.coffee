global.Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'

humanize = require 'underscore.string/humanize'

DefaultView = require './views/DefaultView'
QuestionSetView = require './views/QuestionSetView'
ResultsView = require './views/ResultsView'
SelectServerView = require './views/SelectServerView'
ServerView = require './views/ServerView'
DatabaseView = require './views/DatabaseView'

class Router extends Backbone.Router

  applications:
    "Ceshhar": "https://ceshhar.cococloud.co/ceshhar"
    "Coconut Surveillance Development": "https://zanzibar.cococloud.co/zanzibar-development"
    "Shokishoki": "https://zanzibar.cococloud.co/shokishoki"
    "Local Shokishoki": "http://localhost:5984/shokishoki"
    "Local Kigelia": "http://localhost:5984/kigelia"
    "Entomological Surveillance": "https://zanzibar.cococloud.co/entomological-surveillance"

  routes:
    "select/server": "selectServer"
    "server/:serverName": "showServer"
    "database/:serverName/:databaseName": "showDatabase"
    "results/:serverName/:databaseName/:questionSetDocId": "results"
    "questionSet/:serverName/:databaseName/:questionSetDocId": "questionSet"
    "questionSet/:serverName/:databaseName/:questionSetDocId/:question": "questionSet"
    "logout": "logout"
    "": "default"

  selectServer: =>
    @selectServerView ?= new SelectServerView()
    @selectServerView.setElement $("#content")
    @selectServerView.render()

  showServer: (serverName) =>
    Jackfruit.serverName = serverName
    @serverView ?= new ServerView()
    @serverView.setElement $("#content")
    @serverView.render()

  showDatabase: (serverName, databaseName) =>
    await @setupDatabase(serverName, databaseName)
    @databaseView ?= new DatabaseView()
    @databaseView.serverName = serverName
    @databaseView.databaseName = databaseName
    @databaseView.setElement $("#content")
    @databaseView.render()

  questionSet: (serverName, databaseName, questionSetDocId, question) =>
    await @setupDatabase(serverName, databaseName)
    @questionSetView ?= new QuestionSetView()
    @questionSetView.serverName = serverName
    @questionSetView.databaseName = databaseName
    @questionSetView.setElement $("#content")
    @questionSetView.questionSet = await QuestionSet.fetch(questionSetDocId)
    @questionSetView.activeQuestionLabel = question
    @questionSetView.render()

  results: (serverName, databaseName, questionSetDocId, question) =>
    await @setupDatabase(serverName, databaseName)
    @resultsView ?= new ResultsView()
    @resultsView.serverName = serverName
    @resultsView.databaseName = databaseName
    @resultsView.setElement $("#content")
    @resultsView.questionSet = await QuestionSet.fetch(questionSetDocId)
    @resultsView.activeQuestionLabel = question
    @resultsView.render()


  setupDatabase: (serverName, databaseName) =>
    Jackfruit.serverName = serverName
    @username = Cookie.get("username")
    @password = Cookie.get("password")
    console.log @username
    serverUrlWithCredentials = "#{Jackfruit.knownDatabaseServers[serverName]}".replace(/:\/\//, "://#{@username}:#{@password}@")
    console.log serverUrlWithCredentials
    Jackfruit.database = new PouchDB("#{serverUrlWithCredentials}/#{databaseName}")
    Jackfruit.databaseName = databaseName
    Jackfruit.databasePlugins = await Jackfruit.database.allDocs
      startkey: "_design/plugin-"
      endkey: "_design/plugin-\uf000"
      include_docs: true
    .then (result) =>
      Promise.resolve(_(result?.rows).pluck "doc")

    Jackfruit.database.info()
    .catch =>
      @showServer()

  logout: =>
    Jackfruit.database = null
    Cookie.remove("username")
    Cookie.remove("password")
    @navigate("#", {trigger:true})

  default: () =>
    @selectServer()

module.exports = Router
