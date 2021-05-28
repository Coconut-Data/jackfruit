global.Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'

humanize = require 'underscore.string/humanize'

QuestionSetView = require './views/QuestionSetView'
ResultsView = require './views/ResultsView'
SelectServerView = require './views/SelectServerView'
ServerView = require './views/ServerView'
DatabaseView = require './views/DatabaseView'
GatewayView = require './views/GatewayView'
MessagingView = require './views/MessagingView'

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
    "gateway/:serverName/:gatewayName": "showGateway"
    "results/:serverName/:databaseName/:questionSetDocId": "results"
    "questionSet/:serverName/:databaseOrGatewayName/:questionSetDocId": "questionSet"
    "questionSet/:serverName/:databaseOrGatewayName/:questionSetDocId/:question": "questionSet"
    "messaging/:serverName/:databaseOrGatewayName/:questionSetDocId": "messaging"
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
    await Jackfruit.setupDatabase(serverName, databaseName)
    @databaseView ?= new DatabaseView()
    @databaseView.serverName = serverName
    @databaseView.databaseName = databaseName
    @databaseView.setElement $("#content")
    @databaseView.render()

  showGateway: (serverName, gatewayName) =>
    await Jackfruit.setupDatabase(serverName, gatewayName)
    @gatewayView ?= new GatewayView()
    @gatewayView.serverName = serverName
    @gatewayView.gatewayName = gatewayName
    @gatewayView.setElement $("#content")
    @gatewayView.render()

  questionSet: (serverName, databaseOrGatewayName, questionSetDocId, question) =>
    await Jackfruit.setupDatabase(serverName, databaseOrGatewayName)
    @questionSetView ?= new QuestionSetView()
    @questionSetView.serverName = serverName
    @questionSetView.databaseOrGatewayName = databaseOrGatewayName
    @questionSetView.setElement $("#content")
    @questionSetView.questionSet = await QuestionSet.fetch(questionSetDocId)
    @questionSetView.activeQuestionLabel = question
    @questionSetView.render()

  messaging: (serverName, databaseOrGatewayName, questionSetDocId) =>
    await Jackfruit.setupDatabase(serverName, databaseOrGatewayName)
    @messagingView ?= new MessagingView()
    @messagingView.serverName = serverName
    @messagingView.databaseOrGatewayName = databaseOrGatewayName
    @messagingView.setElement $("#content")
    @messagingView.questionSet = await QuestionSet.fetch(questionSetDocId)
    @messagingView.render()

  results: (serverName, databaseName, questionSetDocId, question) =>
    await Jackfruit.setupDatabase(serverName, databaseName)
    @resultsView ?= new ResultsView()
    @resultsView.serverName = serverName
    @resultsView.databaseName = databaseName
    @resultsView.setElement $("#content")
    @resultsView.questionSet = await QuestionSet.fetch(questionSetDocId)
    @resultsView.activeQuestionLabel = question
    @resultsView.render()


  logout: =>
    Jackfruit.database = null
    Cookie.remove("username")
    Cookie.remove("password")
    @navigate("#", {trigger:true})

  default: () =>
    @selectServer()

module.exports = Router
