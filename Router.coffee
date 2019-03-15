global.Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'

humanize = require 'underscore.string/humanize'

DefaultView = require './views/DefaultView'
QuestionSetView = require './views/QuestionSetView'

class Router extends Backbone.Router

  applications:
    "Ceshhar": "http://ceshhar.cococloud.co/ceshhar"
    "Coconut Surveillance Development": "https://zanzibar.cococloud.co/zanzibar-development"
    "Shokishoki": "https://zanzibar.cococloud.co/shokishoki"
    "Local Shokishoki": "http://localhost:5984/shokishoki"

  routes:
    "application/:applicationName": "application"
    ":applicationName/questionSet/:questionSetDocId": "questionSet"
    ":applicationName/questionSet/:questionSetDocId/:question": "questionSet"
    "logout": "logout"
    "": "default"

  logout: =>
    Jackfruit.database = null
    Cookie.remove("username")
    Cookie.remove("password")
    @navigate("#", {trigger:true})

  default: () =>
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

  questionSet: (applicationName, questionSetDocId, question) =>
    @setupDatabase(applicationName).then =>
      @questionSetView ?= new QuestionSetView()
      @questionSetView.setElement $("#content")
      @questionSetView.questionSet = await QuestionSet.fetch(questionSetDocId)
      @questionSetView.activeQuestionLabel = question
      @questionSetView.render()
    .catch (error) =>
      console.error error
      @#navigate "application/#{applicationName}", {trigger: true}
      throw error


module.exports = Router
