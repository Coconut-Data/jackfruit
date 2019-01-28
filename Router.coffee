Backbone = require 'backbone'
Backbone.$  = $

humanize = require 'underscore.string/humanize'

DefaultView = require './views/DefaultView'
QuestionSetView = require './views/QuestionSetView'

class Router extends Backbone.Router

  applications:
    "Ceshhar": "http://ceshhar.cococloud.co/ceshhar"
    "Coconut Surveillance": "https://zanzibar.cococloud.co/zanzibar"
    "Shokishoki": "https://zanzibar.cococloud.co/shokishoki"
    "Local Shokishoki": "http://localhost:5984/shokishoki"

  routes:
    "application/:applicationName": "application"
    ":applicationName/questionSet/:questionSetDocId": "questionSet"
    "": "default"

  default: () =>
    Jackfruit.database = null
    @defaultView ?= new DefaultView()
    @defaultView.setElement $("#content")
    @defaultView.render()

  application: (applicationName) =>
    @setupDatabase(applicationName).then =>
      @defaultView ?= new DefaultView()
      @defaultView.setElement $("#content")
      @defaultView.render()

  setupDatabase: (applicationName) =>
    Jackfruit.application = applicationName
    database = new PouchDB @applications[Jackfruit.application], 
      auth:
        username: Cookie.get("username") or ""
        password: Cookie.get("password") or ""
    database.info().then =>
      Jackfruit.database = database
      Promise.resolve()

  questionSet: (applicationName, questionSetDocId) =>
    @setupDatabase(applicationName).then =>
      @questionSetView ?= new QuestionSetView()
      @questionSetView.setElement $("#content")
      @questionSetView.questionSet = await QuestionSet.fetch(questionSetDocId)
      @questionSetView.render()
    .catch (error) =>
      console.error error
      @#navigate "application/#{applicationName}", {trigger: true}
      throw error


module.exports = Router
