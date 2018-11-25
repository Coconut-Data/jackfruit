Backbone = require 'backbone'
Backbone.$  = $

QuestionSetView = require './views/QuestionSetView'

class Router extends Backbone.Router

  routes:
    ":httpType/:databaseUrl/:databaseName/:questionSetDocId": "questionSet"

  questionSet: (httpType, databaseUrl, databaseName, questionSetDocId) =>
    @questionSetView ?= new QuestionSetView()
    @questionSetView.setElement $("#content")
    @questionSetView.target =
      httpType: httpType
      databaseUrl: databaseUrl
      databaseName: databaseName
      questionSetDocId: questionSetDocId
    @questionSetView.fetchAndRender()

module.exports = Router
